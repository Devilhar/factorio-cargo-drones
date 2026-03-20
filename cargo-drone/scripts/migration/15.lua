
local function migrate_mooring(mooring)
    local cb = mooring.get_control_behavior()

    cb.add_section()
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
