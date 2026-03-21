
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

    cb.add_section()

	-- The drone count was not migrated correctly, causing it to output the count even when not enabled. So migrate again.
    local section_settings = cb.get_section(1)
    local section_drone_count = cb.get_section(4)

    local drone_count_circuit = get_filter_value(section_settings, "signal-G")
    local drone_signal_set = get_filter_value(section_settings, "signal-H")
    local drone_filter = section_drone_count.filters[1]
    local drone_count = 0

    if drone_count_circuit then
        drone_count = storage.managed_entities[mooring.unit_number].properties["drone_count"]
    end

    if drone_filter then
        drone_filter.min = drone_count
    elseif drone_signal_set == nil then
        drone_filter = {
            value = { type = "virtual", name = "signal-C", quality = "normal" },
            min = drone_count
        }
    end

    section_drone_count.filters = { drone_filter }
end

return function()
	-- The docked_drone was never set during previous migrations.
	for unit_number, entity_data in pairs(storage.cargo_drones) do
		local docked_mooring = storage.managed_entities[unit_number].properties["docked_mooring"]

        if docked_mooring then
            local mooring_data = storage.managed_entities[docked_mooring.unit_number]

            if mooring_data then
                mooring_data.properties["docked_drone"] = entity_data.entity
            end
        end
	end

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
