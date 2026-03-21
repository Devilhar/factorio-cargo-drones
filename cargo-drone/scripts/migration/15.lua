
local function migrate_mooring(mooring)
    local cb = mooring.get_control_behavior()

    cb.add_section()
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
