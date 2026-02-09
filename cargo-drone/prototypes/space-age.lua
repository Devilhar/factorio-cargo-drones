if not mods["space-age"] then return end

local function one_pressure_condition()
    return
    {
        {
            property = "pressure",
            min = 1
        }
    }
end

data.raw["car"]["cargo-drone"].surface_conditions = one_pressure_condition()
data.raw["constant-combinator"]["cargo-drone-mooring-constant-combinator-provider"].surface_conditions = one_pressure_condition()
data.raw["constant-combinator"]["cargo-drone-mooring-constant-combinator-requester"].surface_conditions = one_pressure_condition()
data.raw["constant-combinator"]["cargo-drone-mooring-constant-combinator-refueler"].surface_conditions = one_pressure_condition()
