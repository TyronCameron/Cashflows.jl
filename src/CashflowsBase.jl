
# rate -> an instanteous rate that is going to be exponentiated 
# factor -> a directly multiplicative value 

# flow -> a set of rates combined with WHEN they apply 
# drop -> a single rate combined with WHEN it applies  

# schedule -> a FACTOR along with WHEN they apply 

module Discount
using ForwardDiff: derivative
using QuadGK
export discountfactor, discountrate

function cumquadgk(f, knots)
    begin_knots = vcat([0], knots[begin:end-1])
    end_knots = knots
    cumsum(quadgk.(f, begin_knots, end_knots))
end

# export these
# consider do syntax for this one ... ? 
discountschedule(t, δ::Function)::Vector = exp.(-cumquadgk(t, δ.(t))) 
discountfactor(δ::Function)::Function = (start, stop) -> exp(-quadgk(δ, start, stop)[1]) 
discountrate(discountfactor::Function)::Function = t -> derivative(t -> -log(discountfactor(0, t)), t) 

# Just obviousness functions
forward_to_discount_rate(i) = log(1 + i)
backward_to_discount_rate(d) = log(1 + d / (1 - d))
forward_to_backward_rate(i) = i / (1 + i)
backward_to_forward_rate(d) = d / (1 - d)
discount_to_forward_rate(δ) = exp(δ) - 1 
discount_to_backward_rate(δ) = forward_to_backward_rate(discount_to_forward_rate(δ))

# because this annoying thing happens from time to time
nominal_to_effective_forward_rate(nominal_rate, compounding_frequency) = (1 + nominal_rate / compounding_frequency) ^ compounding_frequency - 1 
effective_to_nominal_forward_rate(effective_rate, compounding_frequency) = ((1 + effective_rate) ^ (1 / compounding_frequency) - 1) * compounding_frequency 

end 

module Cashflows


timevalue(t, support, cashrate, discountrate::Function) = presentvalue(support, cashrate, discountrate) / discountfactor(discountrate)(0, t)
presentvalue(support, cashrate::Function, discountrate::Function) = presentvalue(support, cashrate.(support), discountrate)
presentvalue(support, cashrate, discountrate::Function) = presentvalue(support, cashrate, discountschedule(support, discountrate)) 
presentvalue(support, cashrate, discountfactors) = sum(support .* discountfactors)

# internal_rate_of_return
# prospective_value 
# retrospective_value 

# Definitely want to start being able to create the same thing in multiple ways:
    # DiscountRate(value; type = :central/:forward/:backward)
        # to forward 
        # to backward 
        # to central 

    # DiscountDrop(time, value)
        # 
    # DiscountFlow(function)
        # 
        # get single factor 


end 