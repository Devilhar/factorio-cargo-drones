
local ep		= require("states.12.entity_property")
local rc		= require("states.12.requester_cooldown")
local mh		= require("states.12.mooring_helper")
local dt		= require("states.12.drone_tasks")

return function()
	rc.init()

	mh.init()

	dt.init()

	for _, entity_data in pairs(ep.get_cargo_drone_provider_moorings()) do
		mh.clean_settings(entity_data.entity)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_requester_moorings()) do
		mh.clean_settings(entity_data.entity)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_refuel_moorings()) do
		mh.clean_settings(entity_data.entity)
	end
end
