module Cashflows
using Trees
export Cashflow, InfiniteCashflow, Account, PV, TV, translatetime, prospective, retrospective, value

abstract type AbstractCashflow end

mutable struct Cashflow <: AbstractCashflow
    time::Vector{<:Real}
    pmts::Vector{<:Real}
    discountrate::Vector{<:Real}
    name::String
end
Cashflow(x...; name = "CF XXX") = Cashflow(collect.(zip(broadcast((x1,x2,x3) -> (x1,x2,x3), x...)...))..., name)
Cashflow(t::Real, p::Real, d::Real; name = "CF XXX") = Cashflow([t], [p], [d], name)
Cashflow() = Cashflow(0, 0, 0; name = "Null CF")

mutable struct InfiniteCashflow <: AbstractCashflow
    time::Function
    pmts::Function
    discountrate::Function
    name::String
end
InfiniteCashflow(x...; name = "CF XXX") = InfiniteCashflow(x..., name)

mutable struct Account <: AbstractCashflow
    cashflows::Vector{<:AbstractCashflow}
    name::String
end
Account(cfs; name = "CF XXX") = Account(cfs, name)

Trees.children(acc::Account) = acc.cashflows
Trees.printnode(cf::AbstractCashflow) = cf.name

unitprices(time::Vector{<:Real}, discountrate::Vector{<:Real}) = return append!([time[begin]], diff(time)) .* -discountrate |> cumsum .|> exp

PV(cf::AbstractCashflow) = TV(cf, 0)
prospective(cf::AbstractCashflow, t::Real) = filter(x -> x[1] >= t, cf)
retrospective(cf::AbstractCashflow, t::Real) = filter(x -> x[1] < t, cf)

# CASHFLOW FUNCTIONS
function Base.filter(f::Function, cf::Cashflow)
    c = filter(f, zip(cf.time, cf.pmts, cf.discountrate) |> collect)
    if isempty(c) return NullCashflow() end
    return Cashflow(collect.(zip(c...))...; name = "$(cf.name) where $f is true")
end

function Base.map(f::Function, cf::Cashflow)
    c = map(f, zip(cf.time, cf.pmts, cf.discountrate) |> collect)
    return Cashflow(collect.(zip(c...))...; name = "$f of $(cf.name)")
end

translatetime(cf::Cashflow, t::Real) = Cashflow(cf.time .- t, cf.pmts, cf.discountrate; name = "$(cf.name) @time $t from inception")
TV(cf::Cashflow, t::Real) = sum(cf.pmts .* unitprices(cf.time .- t, cf.discountrate))
value(cf::Cashflow, t) = value(Val(cf), t)

# ACCOUNT AND INFINITE CASHFLOW FUNCTIONS
perturbate(c::InfiniteCashflow; n = 10) = Cashflow(
        c.time.(1:n),
        c.pmts.(1:n),
        c.discountrate.(1:n);
        name = "$n-Pertubation of $(c.name)"
    )

for func in (:map, :filter)
    @eval Base.$func(f::Function, c::Account) = Account($func.(f, c.cashflows), "$($func)-ed $(c.name)")
    @eval Base.$func(f::Function, c::InfiniteCashflow; n = 10) = $func(f, perturbate(c; n = n))
end

for func in (:TV, :translatetime, :value)
    @eval $func(c::InfiniteCashflow, t::Real; n = 10) = $func(perturbate(c; n = n), t)
    @eval $func(c::Account, t::Real) = sum($func.(c.cashflows, t))
end

Base.append!(acc::Account, vec::Vector{<:AbstractCashflow}) = append!(acc.cashflows, vec)
Base.push!(acc::Account, cf::AbstractCashflow) = push!(acc.cashflows, cf)

Base.:*(c::Real, cf::Cashflow) = map(x -> (x[1], c*x[2], x[3]), cf)
Base.:-(cf::Cashflow) = map(x -> (x[1], -x[2], x[3]), cf)
Base.:*(c::Real, cf::InfiniteCashflow) = InfiniteCashflow(cf.time, x -> c*cf.pmts(x), cf.discountrate, "$c * $(cf.name)")
Base.:-(cf::InfiniteCashflow) = InfiniteCashflow(cf.time, x -> -cf.pmts(x), cf.discountrate, "-$(cf.name)")
Base.:+(cf::AbstractCashflow...) = Account([cf...], "Sum of $((x -> x.name).(cf))")

transact(from::Account, to::Account, cf::Cashflow) = (push!(from, cf); push!(to, -cf))

end  # module Cashflows

