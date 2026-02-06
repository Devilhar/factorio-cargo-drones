
local ep	= require("scripts.entity_property")
local dc	= require("scripts.drone_controller")
local dt	= require("scripts.drone_tasks")
local rc    = require("scripts.requester_cooldown")

local current_mod_state = 5

local function safe_call(func)
	local result, err = pcall(func)

	if result then
		return
	end

	game.print(err)
end

local function unmanage_entity(unit_number)
	if ep.is_cargo_drone(unit_number) then
		dc.drone_destroyed(unit_number)

		dt.drone_destroyed(unit_number)
	elseif ep.is_provider_mooring(unit_number)
		or ep.is_requester_mooring(unit_number)
		or ep.is_refueler_mooring(unit_number) then
		dt.mooring_destroyed(unit_number)
	end

	ep.entity_unmanage(unit_number)
end

local function resetup_object_events()
	local removal = {}

	for unit_number, entity_data in pairs(ep.get_managed_entities()) do
		if entity_data.entity.valid then
			script.register_on_object_destroyed(entity_data.entity)
		else
			table.insert(removal, unit_number)
		end
	end

	for _, unit_number in ipairs(removal) do
		unmanage_entity(unit_number)
	end
end

local function migrate_state()
	log("Migrating cargo-drone state...")

	local old_mod_state = storage.mod_state or 0

	storage.mod_state = current_mod_state

	if old_mod_state < 1 then
		resetup_object_events()
	end
	
	if old_mod_state < 2 then
		dt.remove_invalid_tasks()
	end

	if old_mod_state < 3 then
		dt.recount_task_targets()
	end

	if old_mod_state < 4 then
		ep.reset_surface_indices()

		dt.recreate_idle_drones()
	end

	if old_mod_state < 5 then
		dt.fix_task_zero_count_item()
	end

	log("cargo-drone state migration complete")
end

function on_init()
	safe_call(function()
		ep.init()
	end)
end

function on_configuration_changed(event)
	if storage.mod_state == current_mod_state then
		return
	end

	migrate_state()
end

function on_tick(event)
	safe_call(function()
		rc.tick()

		dc.tick(event.tick)
	end)
end

function on_object_destroyed(event)
	if not ep.is_managed(event.useful_id) then
		return
	end

	unmanage_entity(event.useful_id)
end

function on_built_entity(event)
	safe_call(function()
		ep.entity_manage(event.entity)

		script.register_on_object_destroyed(event.entity)
		if event.entity.name == "cargo-drone" then
			ep.add_cargo_drone(event.entity)

			dt.drone_created(event.entity)
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
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_object_destroyed, on_object_destroyed)

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
