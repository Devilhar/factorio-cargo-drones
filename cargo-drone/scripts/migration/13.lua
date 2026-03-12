
local function clear_filter_value(section, filter_name)
    local filters = section.filters

    for i, filter in ipairs(filters) do
        if filter.value and filter.value.name == filter_name then
            table.remove(filters, i)

            section.filters = filters

            return
        end
    end
end

local function migrate_mooring(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(1) -- settings

    clear_filter_value(section, "signal-I") -- fuel_inventory
    clear_filter_value(section, "signal-J") -- fuel_inventory_output
    clear_filter_value(section, "signal-K") -- fuel_inventory_signal_id
    clear_filter_value(section, "signal-L") -- depot

    section = cb.get_section(6) -- output

    section.clear_slot(2) -- fuel_inventory

--[[
    fuel_inventory                  = 5 -> nil,
    drone_count                     = 4 -> 5,
    priority_circuit                = 3 -> 4,
    drone_limit                     = 2 -> 3,
    output                          = 6 -> 2,
    inventory_targets               = 7 -> 6,
    output_requests                 = 8 -> 7,
]]
    local sections = cb.sections

    sections[5].filters = sections[4].filters

    sections[4].filters = sections[3].filters

    sections[3].filters = sections[2].filters

    sections[2].filters = sections[6].filters

    sections[6].filters = sections[7].filters

    sections[7].filters = sections[8].filters

    sections[2].active = true
    sections[6].active = false
    sections[7].active = true

    cb.remove_section(8)

    storage.depots = nil

    storage.depot_helper = {}

    storage.depot_helper.depots = {}
end

return function()
	for _, entity_data in pairs(storage.cargo_drone_provider_mooring) do
		migrate_mooring(entity_data.entity)
	end
	for _, entity_data in pairs(storage.cargo_drone_requester_mooring) do
		migrate_mooring(entity_data.entity)
	end
	for _, entity_data in pairs(storage.cargo_drone_refuel_mooring) do
		migrate_mooring(entity_data.entity)
	end
end
