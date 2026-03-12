
module Supports 
using SumTypes, Chain, Dates


"""
	# AbstractSupport

An abstract type in case someone wants to extend this concept
"""
abstract type AbstractSupport end 

###################################################################
# Define RangePoints
###################################################################

"""
	# RangePoint

Either an open or a closed side. 
"""
@sum_type RangePoint{T} begin
	Open{T}(::T)
	Closed{T}(::T)
end

"""
	isopen(rangepoint::RangePoint)

Returns true for an open rangepoint and false otherwise. 
"""
isopen(rangepoint::RangePoint) = @cases rangepoint begin
	Open(t) => true 
	Closed(t) => false
end

"""
	isclosed(rangepoint::RangePoint)

Returns true for a closed rangepoint and false otherwise. 
"""
isclosed(rangepoint::RangePoint) = !isopen(rangepoint)


"""
	invert(rangepoint::RangePoint)

Switches an open rangepoint to a closed and vice versa.
"""
invert(rangepoint::RangePoint) = @cases rangepoint begin
	Open(t) => Closed(t)
	Closed(t) => Open(t)
end 

"""
	unwrap(rangepoint::RangePoint)

Unwraps and gives you the value inside a rangepoint
"""
unwrap(rangepoint::RangePoint) = @cases rangepoint begin
	Open(t) => t
	Closed(t) => t
end

"""
	rangeify(x)

An idempotent function which converts something to a RangePoint
"""
rangeify(x::RangePoint) = x 
rangeify(x) = Closed(x) 

# Equal if the points are identical 
Base.:(==)(x::RangePoint, y::RangePoint) = unwrap(x) == unwrap(y) && isopen(x) == isopen(y)

# Use the minimum value (left-left bound)
Base.isless(a::RangePoint, b::RangePoint) = isless(unwrap(a), unwrap(b)) || (unwrap(a) == unwrap(b) && isclosed(a) && isopen(b))
Base.isless(a::RangePoint, b) = isless(a, Open(b))

# Use the maximum value (right-hand bound)
Base.isless(a, b::RangePoint) = isless(a, unwrap(b)) || (a == unwrap(b) && isclosed(b))

Base.promote_rule(::Type{RangePoint{A}}, ::Type{RangePoint{B}}) where A where B = RangePoint{promote_type(A, B)}
Base.convert(::Type{RangePoint{A}}, x::RangePoint{B}) where A where B = isopen(x) ? Open{A}(convert(A, unwrap(x))) : Closed{A}(convert(A, unwrap(x)))

Base.promote_rule(::Type{RangePoint{T}}, ::Type{RangePoint{S}}) where {T, S} = RangePoint{promote_type(T, S)}


Base.eltype(::RangePoint{T}) where T = T

leftstring(rangepoint::RangePoint) = @cases rangepoint begin
	Open(t) => "($t"
	Closed(t) => "[$t"
end

rightstring(rangepoint::RangePoint) = @cases rangepoint begin
	Open(t) => "$t)"
	Closed(t) => "$t]"
end

###################################################################
# Compactify
###################################################################

# Ensure sorting order is preserved and that any overlaps are eliminated
function compactify(starts::Vector{<:RangePoint{T}}, stops::Vector{<:RangePoint{T}}) where T
	reordered = @chain starts begin
		zip(stops)
		collect
		sort(by = x -> x[begin])
	end
	new_starts, new_stops = RangePoint{T}[], RangePoint{T}[]
	for (start, stop) in reordered
		if start > stop continue end 
		if !isempty(new_stops) && stop <= new_stops[end] continue end 
		if !isempty(new_stops) && start <= new_stops[end] && new_stops[end] <= stop
			pop!(new_stops)
			push!(new_stops, stop)
			continue 
		end 
		push!(new_starts, start)
		push!(new_stops, stop)
	end
	return new_starts, new_stops
end

###################################################################
# Define Support
###################################################################

"""
	# Support

A set of ranges that you can iterate over. 
"""
struct Support{T} <: AbstractSupport
	starts::Vector{RangePoint{T}}
	stops::Vector{RangePoint{T}}
	function Support(starts::Vector{RangePoint{A}}, stops::Vector{RangePoint{B}}) where A where B
		if length(starts) != length(stops) error(DimensionMismatch, "Mismatched sizes for start and stop vectors passed to the Support constructor") end 
		starts, stops = promote(starts, stops)
		return new{promote_type(A, B)}(compactify(starts, stops)...)
	end
end 

function Support(starts::Vector, stops::Vector) 
	starts, stops = promote(starts, stops)
	Support(rangeify.(starts), rangeify.(stops))
end 

Base.eltype(::Support{T}) where T = T
Base.isempty(support::Support) = isempty(support.starts)
function Base.in(val, support::Support)
	first = searchsortedfirst(support.stops, start)
	last = searchsortedlast(support.starts, stop)
	any(support.starts[first:last] .<= val .<= support.stops[first:last])
end 

function Base.show(io::IO, ::MIME"text/plain", support::Support)
	if isempty(support) 
		print(io, "ϕ") 
		return 
	end 
    if get(io, :compact, false)
		first_start = leftstring(support.starts[1])
		last_stop = rightstring(support.stops[end])
		if length(support.starts) == 1 
			print(io, "$first_start, $last_stop")
		else 
        	print(io, "$first_start, ..., $last_stop")
		end 
    else
		@chain support.starts begin 
			zip(support.stops)
			map(t -> "$(leftstring(t[begin])), $(rightstring(t[end]))", _)
			join(" U ")
			print(io, _)
		end 
    end
end

Base.union(x::Support, y::Support) = Support(vcat(x.starts, y.starts), vcat(x.stops, y.stops))

function Base.intersect(x::Support, y::Support)
	T = promote_type(eltype(x), eltype(y))
	new_starts, new_stops = RangePoint{T}[], RangePoint{T}[]
	for (x_start, x_stop) in zip(x.starts, x.stops)
		first = searchsortedfirst(y.stops, x_start)
		last = searchsortedlast(y.starts, x_stop)
		@info first
		@info last
		for (y_start, y_stop) in zip(y.starts[first:last], y.stops[first:last])
			if x_start <= y_stop && y_start <= x_stop
				push!(new_starts, max(x_start, y_start))
				push!(new_stops, min(x_stop, y_stop))
			end 
		end 
	end 
	Support(new_starts, new_stops)
end 

function setminus(x::Support, y::Support)
	T = promote_type(eltype(x), eltype(y))
	new_starts, new_stops = RangePoint{T}[], RangePoint{T}[]
	for (x_start, x_stop) in zip(x.starts, x.stops)
		first = searchsortedfirst(y.stops, x_start)
		last = searchsortedlast(y.starts, x_stop)
		for (y_start, y_stop) in zip(y.starts[first:last], y.stops[first:last])
			if y_start <= x_start && x_stop <= y_stop continue end # x inside y 
			if x_start < y_start && y_stop <= x_stop # y inside x
				push!(new_starts, x_start)
				push!(new_stops, invert(y_start))
				push!(new_starts, invert(y_stop))
				push!(new_stops, x_stop)
				continue
			end 
			if x_start <= y_stop <= x_stop # y left overlap x
				push!(new_starts, invert(y_stop))
				push!(new_stops, x_stop)
				continue 
			end 
			if x_start <= y_start <= x_stop # y right overlap x
				push!(new_starts, x_start)
				push!(new_stops, invert(y_start))
				continue 
			end 
			# no overlap
			push!(new_starts, x_start)
			push!(new_stops, x_stop)
		end 
	end 
	Support(new_starts, new_stops)
end

"""
	prospective(support::Support, t)

Filter the support to only include the support from t (including t) onwards. 
"""
function prospective(support::Support, t; include = true) 
	first = searchsortedlast(support.starts, t)
	starts, stops = support.starts[first:end], support.stops[first:end]
	if !isempty(starts) starts[begin] = include ? Closed(t) : Open(t) end
	Support(starts, stops)
end 

"""
	retrospective(support::Support, t)

Filter the support to only include the support before t (excluding t). 
"""
function retrospective(support::Support, t; include = false) 
	last = searchsortedfirst(support.stops, t)
	starts, stops = support.starts[begin:last], support.stops[begin:last]
	if !empty(stops) stops[end] = include ? Closed(t) : Open(t) end 
	Support(starts, stops)
end 

"""
	body(support::Support{T}, thresholds::Pair{T,T})

Get the "main body" of the ranges, ignoring any INFINITE ranges outside the thresholds
"""
function body(support::Support{T}, thresholds::Pair{T, T}) where T 
	lowerthreshold = isinf(unwrap(support.starts[begin])) ? thresholds.first : unwrap(support.starts[begin])
	upperthreshold = isinf(unwrap(support.stops[end])) ? thresholds.second : unwrap(support.stops[end])
	@assert lowerthreshold < upperthreshold "Lower threshold is not below upperthreshold"
	intersect(support, interval(lowerthreshold, upperthreshold))
end

"""
	tails(support::Support{T}, thresholds::Pair{T,T})

Get the INFINITE "tails" of the support. 
"""
tails(support::Support{T}, thresholds::Pair{T, T}) where T = setminus(support, body(support, thresholds))

"""
	discretize(support::Support; δ)

Create an iterator to visit all the points (up to granularity δ) inside the support.
"""
function discretize(support::Support{T}; δ = _delta(T)) where T 
	starts = map(t -> isopen(t) ? unwrap(t) + δ : unwrap(t), support.starts)
	stops = map(t -> isopen(t) ? unwrap(t) - δ : unwrap(t), support.stops)
	Iterators.flatten(map(t -> t[begin]:δ:t[end], zip(starts, stops)))
end 

###################################################################
# Candy
###################################################################

Base.:(+)(x::Support, y::Support) = union(x, y)
Base.:(*)(x::Support, y::Support) = intersect(x, y)
Base.:(-)(x::Support, y::Support) = setminus(x, y)

_shift(x::Support, y) = Support(unwrap.(x.starts) .+ y, unwrap.(x.stops) .+ y)
_scale(x::Support, y) = Support(unwrap.(x.starts) .* y, unwrap.(x.stops) .* y)

Base.:(+)(x::Support{T}, y::T) where T = _shift(x, y)
Base.:(+)(x::T, y::Support{T}) where T = _shift(y, x)

Base.:(-)(x::Support{T}, y::T) where T = _shift(x, -y)

Base.:(*)(x::Support{T}, y::T) where T = _scale(x, y)
Base.:(*)(x::T, y::Support{T}) where T = _scale(y, x)

Base.minimum(support::Support) = unwrap(support.starts[begin])
Base.maximum(support::Support) = unwrap(support.stops[end])

###################################################################
# Interact with other data
###################################################################

"""
	interval(start, stop)
	interval(x)

Attempts to convert whatever you put into it into a meaningful Support (range). 
"""
function interval(x, y; start = :closed, stop = :closed) 
	a, b = promote(x, y)
	Support([start == :open ? Open(a) : Closed(a)], [stop == :open ? Open(b) : Closed(b)])
end 
interval(p::UnitRange; start = :closed, stop = :closed) = interval(p.start, p.stop; start = start, stop = stop)
interval(p::Pair; start = :closed, stop = :closed) = interval(p.first, p.second; start = start, stop = stop)
interval(t::Tuple; start = :closed, stop = :closed) = interval(t[begin], t[end]; start = start, stop = stop)
interval(v::Vector; start = :closed, stop = :closed) = interval(v[begin], v[end]; start = start, stop = stop)
interval(x) = interval(x, x)

# Conversions for niceness
Support(x, y; start = :closed, stop = :closed) = interval(x, y; start = start, stop = stop)
convert(::Support, x::Pair) = interval(x)
convert(::Support, x::Tuple) = interval(x)
convert(::Support, x::UnitRange) = interval(x)
convert(::Support, x::Vector) = Support(x, x)

# Delta
_delta(::Type{Dates.Date}) = Dates.Day(1)
_delta(::Type{Dates.DateTime}) = Dates.Second(1)
_delta(::Type{Dates.Year}) = Dates.Year(1)
_delta(::Type{Dates.Month}) = Dates.Month(1)
_delta(::Type{Dates.Day}) = Dates.Day(1)
_delta(::Type{Dates.Week}) = Dates.Week(1)
_delta(::Type{Dates.Hour}) = Dates.Hour(1)
_delta(::Type{Dates.Minute}) = Dates.Minute(1)
_delta(::Type{Dates.Second}) = Dates.Second(1)
_delta(::Type{<:Number}) = 0.05
_delta(::Type{<:Int}) = 1

_thresholds(::Type{Dates.Date}) = Dates.Date(0, 1 ,1) => Dates.Date(9999, 12, 31)
_thresholds(::Type{Dates.DateTime}) = Dates.DateTime(0, 1 ,1, 0, 0, 0, 0) => Dates.DateTime(9999, 12, 31, 23, 59, 59, 999)
_thresholds(::Type{Dates.Year}) = Dates.Year(0) => Dates.Year(9999)
_thresholds(::Type{Dates.Month}) = Dates.Month(0) => Dates.Year(12)
_thresholds(::Type{Dates.Day}) = Dates.Day(0) => Dates.Day(365)
_thresholds(::Type{Dates.Week}) = Dates.Week(0) => Dates.Week(52)
_thresholds(::Type{Dates.Hour}) = Dates.Hour(0) => Dates.Hour(24)
_thresholds(::Type{Dates.Minute}) = Dates.Minute(0) => Dates.Minute(59)
_thresholds(::Type{Dates.Second}) = Dates.Second(0) => Dates.Second(59)
_thresholds(::Type{<:Number}) = -1000.0 => 1000.0

# @chain c discretize(δ = 0.01) collect
# a = interval(0, 1; start = :closed, stop = :open)
# b = interval([0.5, 5])
# intersect(a, b)

# c = a - b 

# a = Support([1,2,9])

# b = Support([1,2.0], [1,20])

# a * b
# union(a, b)

# Support([Closed(1), Open(1)], [Closed(1), Open(1)])

end 
