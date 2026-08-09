
local constants	= require("scripts.constants")
local ps		= require("scripts.player_storage")
local ep		= require("scripts.entity_property")
local th		= require("scripts.target_helper")
local deh		= require("scripts.depot_helper")
local dlc		= require("scripts.deployer_controller")
local dlh		= require("scripts.deployer_helper")
local rc    	= require("scripts.requester_cooldown")
local mh		= require("scripts.mooring_helper")
local dt		= require("scripts.drone_tasks")
local mc		= require("scripts.mooring_controller")
local dc		= require("scripts.drone_controller")
local gm		= require("scripts.gui_mooring")
local gd		= require("scripts.gui_deployer")
local gcd		= require("scripts.gui_cargo_drone")
local scheduler	= require("scripts.scheduler")
local migration	= require("scripts.migration")

require("scripts.debug_interface")

local function on_drone_count_changed(surface_index)
	dlc.drone_count_changed(surface_index)
end
local function on_idle_drone_count_changed(surface_index)
	dlc.idle_drone_count_changed(surface_index)
end

dc.set_on_drone_count_changed(on_drone_count_changed)
dt.set_on_drone_count_changed(on_idle_drone_count_changed)

local undo_redo_ghost_name_array = {
	"cargo-drone-mooring-constant-combinator-provider",
	"cargo-drone-mooring-constant-combinator-requester",
	"cargo-drone-mooring-constant-combinator-refueler",
	"cargo-drone-depot-constant-combinator",
}
local undo_redo_entity_filter = {
	["cargo-drone-mooring-constant-combinator-provider"] = true,
	["cargo-drone-mooring-constant-combinator-requester"] = true,
	["cargo-drone-mooring-constant-combinator-refueler"] = true,
	["cargo-drone-depot-constant-combinator"] = true,
	["entity-ghost"] = true,
}

local function undo_redo_copy_settings(action)
	if not undo_redo_entity_filter[action.target.name] then
		return
	end

	local filter = {
		name		= action.target.name,
		position	= action.target.position,
		limit		= 1,
	}

	local function run_on_entities()
		local entities = game.get_surface(action.surface_index).find_entities_filtered(filter)

		for _, entity in ipairs(entities) do
			if not ep.is_managed(entity.unit_number) then
				return
			end

			th.reload_name(entity)
		end
	end

	local entity_is_ghost = action.target.name == "entity-ghost"

	-- When running redo, and the entity is a ghost, it will give the name as the ghost_name instead.
	-- So run on all colliding entities of the correct types. There's no harm in updating the wrong
	-- target anyway.

	if not entity_is_ghost then
		run_on_entities()
	end

	filter.name = "entity-ghost"
	filter.ghost_name = undo_redo_ghost_name_array

	run_on_entities()
end

local undo_actions = {
	["copy-entity-settings"] = undo_redo_copy_settings
}
local redo_actions = {
	["copy-entity-settings"] = undo_redo_copy_settings
}

function on_init()
	storage.mod_state = constants.current_mod_state

	ps.init()

	ep.init()

	mc.init()

	dc.init()

	deh.init()
	dlc.init()

	rc.init()

	mh.init()

	dt.init()

	gm.create_player_storage()
	gd.create_player_storage()
	gcd.create_player_storage()

	scheduler.init()
end
function on_configuration_changed(event)
	migration.run_migration()
end
function on_tick(event)
	rc.tick()

	scheduler.tick(event.tick)

	dlc.tick(event.tick)

	dc.tick(event.tick)

	mc.tick()

	gm.tick()
	gd.tick()
	gcd.tick()
end
function on_input_toggle_map_overlay(event)
	ps.toggle_player_map_overlay(event.player_index)

	mc.update_map_name_visibility()
	deh.update_map_name_visibility()
end

function on_player_removed(event)
	ps.player_removed(event.player_index)
	gm.on_player_removed(event)
	gd.on_player_removed(event)
	gcd.on_player_removed(event)
end

local function on_built_entity_drone(entity)
	script.register_on_object_destroyed(entity)

	dc.created(entity)

	dt.drone_created(entity)
end
local function on_built_entity_mooring_proc(entity)
	mc.created(entity)
end
local function on_destroyed_entity_drone(entity)
	dc.destroyed(entity)

	dt.drone_destroyed(entity)
end
local function on_destroyed_entity_mooring_proc(entity)
	mc.destroyed(entity)

	dt.target_destroyed(entity)
end

local on_built_entity_procs = {
	["entity-ghost"] = function (entity)
		if entity.ghost_name == "cargo-drone-deployer-constant-combinator" then
			dlh.clean_settings(entity)

			return
		end

		mh.clean_settings_ghost(entity)
	end,
	["cargo-drone-depot-constant-combinator"] = function (entity)
		deh.created(entity)

		script.register_on_object_destroyed(entity)
	end,
	["cargo-drone-deployer-constant-combinator"] = function (entity)
		dlc.created(entity)

		script.register_on_object_destroyed(entity)
	end,
	["cargo-drone-mooring-constant-combinator-provider"] = on_built_entity_mooring_proc,
	["cargo-drone-mooring-constant-combinator-requester"] = on_built_entity_mooring_proc,
	["cargo-drone-mooring-constant-combinator-refueler"] = on_built_entity_mooring_proc,
}
local on_destroyed_entity_procs = {
	["cargo-drone-depot-constant-combinator"] = function (entity)
		deh.destroyed(entity)

		dt.target_destroyed(entity)
	end,
	["cargo-drone-deployer-constant-combinator"] = function (entity)
		dlc.destroyed(entity)
	end,
	["cargo-drone-mooring-constant-combinator-provider"] = on_destroyed_entity_mooring_proc,
	["cargo-drone-mooring-constant-combinator-requester"] = on_destroyed_entity_mooring_proc,
	["cargo-drone-mooring-constant-combinator-refueler"] = on_destroyed_entity_mooring_proc,
}

for name, _ in pairs(prototypes.mod_data["cargo-drone-prototypes"].data) do
	on_built_entity_procs[name] = on_built_entity_drone
	on_destroyed_entity_procs[name] = on_destroyed_entity_drone
end

function on_surface_deleted(event)
	ep.remove_invalid_entities()

	dc.surface_deleted(event.surface_index)
	dt.surface_deleted(event.surface_index)
	dlc.surface_deleted(event.surface_index)
	deh.surface_deleted(event.surface_index)
end
function on_surface_cleared(event)
	ep.remove_invalid_entities()

	dc.surface_cleared(event.surface_index)
	dt.surface_cleared(event.surface_index)
	dlc.surface_cleared(event.surface_index)
	deh.surface_cleared(event.surface_index)
end
function on_built_entity(event)
	local entity = event.entity

	local proc = on_built_entity_procs[entity.name]

	if not proc then
		return
	end

	ep.entity_manage(entity)

	proc(entity)
end
function on_destroyed_entity(event)
	gm.on_destroyed_entity(event)
	gd.on_destroyed_entity(event)

	local entity = event.entity

	if not ep.is_managed(entity.unit_number) then
		return
	end

	mh.on_destroyed_entity(entity)

	local proc = on_destroyed_entity_procs[entity.name]

	if proc then
		proc(entity)
	end

	ep.entity_unmanage(entity.unit_number)
end
function on_player_rotated_entity(event)
	if not event.entity or not event.entity.valid then
		return
	end

	if event.entity.name == "cargo-drone-deployer-constant-combinator" then
		dlc.direction_changed(event.entity)
	end

	local entity_name = event.entity.name

	if entity_name == "entity-ghost" then
		entity_name = event.entity.ghost_name
	end

	if mh.is_name_mooring(entity_name) then
		mc.on_rotate(event.entity)
	end
end
function on_player_flipped_entity(event)
	if not event.entity or not event.entity.valid then
		return
	end

	if event.entity.name == "cargo-drone-deployer-constant-combinator" then
		dlc.direction_changed(event.entity)
	end

	local entity_name = event.entity.name

	if entity_name == "entity-ghost" then
		entity_name = event.entity.ghost_name
	end

	if mh.is_name_mooring(entity_name) then
		mc.on_flip(event.entity)
	end
end
function on_entity_settings_pasted(event)
	if not event.destination or not event.destination.valid then
		return
	end

	local destination_name = event.destination.name

	local destination_is_ghost = destination_name == "entity-ghost"

	if destination_is_ghost then
		destination_name = event.destination.ghost_name
	end

	if mh.is_name_mooring(destination_name) then
		if destination_is_ghost then
			mh.clean_settings_ghost(event.destination)
		else
			mh.clean_settings(event.destination)
		end

		local source_name = event.source.name

		if source_name == "entity-ghost" then
			source_name = event.source.ghost_name
		end

		local is_refueler_destination = destination_name == "cargo-drone-mooring-constant-combinator-refueler"
		local is_refueler_source = source_name == "cargo-drone-mooring-constant-combinator-refueler"

		if is_refueler_destination ~= is_refueler_source then
			for x = 1, 3 do
				for y = 1, 3 do
					mh.set_inventory_target_absolute(event.destination, x, y, mh.get_inventory_target_absolute(event.source, x, y))
				end
			end
		end
	elseif destination_name == "cargo-drone-depot-constant-combinator" then
		deh.clean_settings(event.destination)
	elseif destination_name == "cargo-drone-deployer-constant-combinator" then
		dlh.clean_settings(event.destination)
	end
end
function on_undo_applied(event)
	for _, action in ipairs(event.actions) do
		local func = undo_actions[action.type]

		if func then
			func(action)
		end
	end
end
function on_redo_applied(event)
	for _, action in ipairs(event.actions) do
		local func = redo_actions[action.type]

		if func then
			func(action)
		end
	end
end
function script_raised_teleported(event)
	if event.old_surface_index == event.entity.surface.index then
		return
	end

	dc.surface_change(event.entity, event.old_surface_index)

	dt.drone_surface_change(event.entity, event.old_surface_index)
end

function on_gui_opened(event)
	gm.on_gui_opened(event)
	gd.on_gui_opened(event)
	gcd.on_gui_opened(event)
end
function on_gui_closed(event)
	gm.on_gui_closed(event)
	gd.on_gui_closed(event)
	gcd.on_gui_closed(event)
end
function on_gui_click(event)
    gm.on_gui_click(event)
    gd.on_gui_click(event)
    gcd.on_gui_click(event)
end
function on_gui_checked_state_changed(event)
	gm.on_gui_checked_state_changed(event)
	gd.on_gui_checked_state_changed(event)
end
function on_gui_value_changed(event)
	gm.on_gui_value_changed(event)
	gd.on_gui_value_changed(event)
end
function on_gui_text_changed(event)
	gm.on_gui_text_changed(event)
	gd.on_gui_text_changed(event)
end
function on_gui_elem_changed(event)
	gm.on_gui_elem_changed(event)
	gd.on_gui_elem_changed(event)
end
function on_gui_selection_state_changed(event)
	gm.on_gui_selection_state_changed(event)
	gd.on_gui_selection_state_changed(event)
end
function on_gui_confirmed(event)
	gm.on_gui_confirmed(event)
	gd.on_gui_confirmed(event)
end

local build_event_filters = {
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "name", name = "cargo-drone-depot-constant-combinator" },
	{ filter = "name", name = "cargo-drone-deployer-constant-combinator" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "ghost_name", name = "cargo-drone-depot-constant-combinator" },
	{ filter = "ghost_name", name = "cargo-drone-deployer-constant-combinator" },
}
local build_events = {
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
	defines.events.on_entity_cloned,
}
local destroy_event_filters = {
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "name", name = "cargo-drone-depot-constant-combinator" },
	{ filter = "name", name = "cargo-drone-deployer-constant-combinator" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "ghost_name", name = "cargo-drone-depot-constant-combinator" },
}
local destroy_events = {
	defines.events.on_entity_died,
	defines.events.on_player_mined_entity,
	defines.events.on_robot_mined_entity,
	defines.events.script_raised_destroy,
}
local script_raised_teleported_filters = {}

for name, _ in pairs(prototypes.mod_data["cargo-drone-prototypes"].data) do
	table.insert(build_event_filters, { filter = "name", name = name })
	table.insert(destroy_event_filters, { filter = "name", name = name })
	table.insert(script_raised_teleported_filters, { filter = "name", name = name })
end

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)
script.on_event("cargo-drone-toggle-map-overlay", on_input_toggle_map_overlay)

script.on_event(defines.events.on_player_joined_game, on_player_removed)

script.on_event(defines.events.on_surface_deleted, on_surface_deleted)
script.on_event(defines.events.on_surface_cleared, on_surface_cleared)
script.on_event(build_events, on_built_entity)
script.on_event(destroy_events, on_destroyed_entity)
script.on_event(defines.events.on_player_rotated_entity, on_player_rotated_entity)
script.on_event(defines.events.on_player_flipped_entity, on_player_flipped_entity)
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)
script.on_event(defines.events.on_undo_applied, on_undo_applied)
script.on_event(defines.events.on_redo_applied, on_redo_applied)
script.on_event(defines.events.script_raised_teleported, script_raised_teleported)

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
script.on_event(defines.events.on_gui_confirmed, on_gui_confirmed)

for _, event in ipairs(build_events) do
	script.set_event_filter(event, build_event_filters)
end
for _, event in ipairs(destroy_events) do
	script.set_event_filter(event, destroy_event_filters)
end
script.set_event_filter(defines.events.script_raised_teleported, script_raised_teleported_filters)
