module Cashflows
using Roots, BinaryTraits
using BinaryTraits.Prefix: Is

# Functions:
# prospective(zipped_times_and_payments, t) = filter(x -> x[1] >= t, zipped_times_and_payments)
# retrospective(zipped_times_and_payments, t) = filter(x -> x[1] < t, zipped_times_and_payments)
# translate_time(times, t) = map(time -> time - t, times)
# function discount_factors(times, discount_pcts)
#     time_incr = append!([times[begin]], diff(times |> collect)) 
#     return exp.(cumsum(-discount_pcts .* time_incr))
# end 
# time_value(times, payments, discount_pcts, t) = sum(payments .* discount_factors(translate_time(times, t), discount_pcts))
# internal_rate_of_return(times::Vector{<:Real}, amounts::Vector{<:Real}; guess = 0.1) = find_zero(r -> npv(r, times, amounts), guess, Order1()) 
# # present_value(times, payments, discount_pcts) = time_value(times, payments, discount_pcts, 0)
# # net_present_value(times, payments, discount_pcts) = present_value(times, payments, discount_pcts)

# @trait Cashflow
# @implement Is{Cashflow} by times(_)
# @implement Is{Cashflow} by payments(_)

# struct CashDrop 
#     time::Real
#     amt::Real
# end 
# @assign CashDrop with Is{Cashflow}

# struct CashStream
#     cashdrops
# end 
# @assign CashStream with Is{Cashflow}

# struct Account
#     dict{Symbol, <:AbstractCashflow}
# end
# @assign Account with Is{Cashflow}

# transact(from::Account, to::Account, cf::Cashflow) = (push!(from, cf); push!(to, -cf))


# @trait DiscountFlow
# @implement Is{Cashflow} by times(_)
# @implement Is{Cashflow} by payments(_)

# struct DiscountDrop
#     time::Real
#     pct::Real
# end 
# @assign DiscountDrop with Is{DiscountFlow}

# struct DiscountStream
#     discountdrops
# end 
# @assign DiscountStream with Is{DiscountFlow}

# # value(cf::Cashflow, t) = value(Val(cf), t)



# abstract type AbstractCashflow end

# struct Cashflow
#     time::Vector{<:Real}
#     pmts::Vector{<:Real}
# end

# struct InfiniteCashflow
#     time::Function
#     pmts::Function
# end

# mutable struct Account
#     name::String
#     cashflows::Dict{String, AbstractCashflow}
# end


end  # module Cashflows

