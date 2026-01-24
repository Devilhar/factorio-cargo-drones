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
data.raw["proxy-container"]["cargo-drone-provider-mooring"].surface_conditions = one_pressure_condition()
data.raw["proxy-container"]["cargo-drone-requester-mooring"].surface_conditions = one_pressure_condition()
data.raw["proxy-container"]["cargo-drone-refuel-mooring"].surface_conditions = one_pressure_condition()
