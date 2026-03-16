
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
local function get_filter_value(section, filter_name)
    local filters = section.filters

    for i, filter in ipairs(filters) do
        if filter.value and filter.value.name == filter_name then
            return filter.min
        end
    end

    return nil
end

local function migrate_mooring(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(1) -- settings

    clear_filter_value(section, "signal-I") -- fuel_inventory
    clear_filter_value(section, "signal-J") -- fuel_inventory_output
    clear_filter_value(section, "signal-K") -- fuel_inventory_signal_id

    section = cb.get_section(6) -- output

    section.clear_slot(2) -- fuel_inventory

--[[
    fuel_inventory                  = 5 -> nil,
    output                          = 6 -> nil,
    inventory_targets               = 7 -> 5,
    output_requests                 = 8 -> 6,
]]
    local sections = cb.sections

    local drone_signal_set = get_filter_value(sections[4], "signal-H")
    local drone_filter = sections[4].filters[1]
    local drone_count = storage.managed_entities[mooring.unit_number].properties["drone_count"] or 0

    if drone_filter then
        drone_filter.min = drone_count
    elseif drone_signal_set == nil then
        drone_filter = {
            value = { type = "virtual", name = "signal-C", quality = "normal" },
            min = drone_count
        }
    end

    sections[4].filters = { drone_filter }

    sections[5].filters = sections[7].filters

    sections[6].filters = sections[8].filters

    sections[4].active = true
    sections[6].active = true

    cb.remove_section(8)

    cb.remove_section(7)

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

    game.print({ "cargo-drone-migration.warning-enable-as-depot-removed" })
end
