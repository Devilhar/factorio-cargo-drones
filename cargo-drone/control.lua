
require("scripts.cargo_drone_control")

local ep = require("scripts.entity_property")

local function safe_call(func)
	local result, err = pcall(func)

	if result then
		return
	end

	game.print(err)
end

function on_init()
	safe_call(function()
		ep.init()
	end)
end

function on_tick(event)
	safe_call(function()
		ep.remove_invalid_entities()

		for entity_id, entity_data in pairs(ep.get_cargo_drones()) do
			tick_cargo_drone(entity_data.entity, event.tick)
		end
	end)
end

function on_built_entity(event)
	safe_call(function()
		ep.entity_manage(event.entity)

		if event.entity.name == "cargo-drone" then
			ep.add_cargo_drone(event.entity)
		elseif event.entity.name == "cargo-drone-provider-mooring" then
			if not event.entity.get_control_behavior() then
				event.entity.get_or_create_control_behavior().read_contents = false
			end
			ep.add_cargo_drone_provider_mooring(event.entity)
		elseif event.entity.name == "cargo-drone-requester-mooring" then
			if not event.entity.get_control_behavior() then
				event.entity.get_or_create_control_behavior().read_contents = false
			end
			ep.add_cargo_drone_requester_mooring(event.entity)
			ep.set_entity_property(event.entity, "next_free_gametick", 0)
		elseif event.entity.name == "cargo-drone-refuel-mooring" then
			ep.add_cargo_drone_refuel_mooring(event.entity)
		end
	end)
end

script.on_init(on_init)
script.on_event(defines.events.on_tick, on_tick)

local build_events = {
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
	defines.events.on_entity_cloned,
}
local build_event_filters = {
	{ filter = "name", name = "cargo-drone" },
	{ filter = "name", name = "cargo-drone-provider-mooring" },
	{ filter = "name", name = "cargo-drone-requester-mooring" },
	{ filter = "name", name = "cargo-drone-refuel-mooring" }
}
script.on_event(build_events, on_built_entity)

for _, event in ipairs(build_events) do
	script.set_event_filter(event, build_event_filters)
end
