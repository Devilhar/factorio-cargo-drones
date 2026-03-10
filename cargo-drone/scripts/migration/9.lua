
local constants	= require("states.12.constants")
local ep		= require("states.12.entity_property")
local mh		= require("states.12.mooring_helper")

return function()
	mh.init()

	local function migrate_proxy_containers(mooring)
		ep.set_entity_property(mooring, "proxy_container", nil)
		if ep.get_entity_property(mooring, "proxy_containers") == nil then
			mh.migration_create_proxy_containers(mooring)
		end
	end

	for _, entity_data in pairs(ep.get_cargo_drones()) do
		ep.set_entity_property(entity_data.entity, "docked_mooring", nil)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_provider_moorings()) do
		migrate_proxy_containers(entity_data.entity)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_requester_moorings()) do
		migrate_proxy_containers(entity_data.entity)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_refuel_moorings()) do
		migrate_proxy_containers(entity_data.entity)
	end

	if constants.drone_has_burnt_result then
		game.print({ "cargo-drone-migration.warning-read-inventory-output-removed" })
	end
end
