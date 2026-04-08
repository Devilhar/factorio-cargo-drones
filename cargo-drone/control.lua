
local constants	= require("scripts.constants")
local ep		= require("scripts.entity_property")
local th		= require("scripts.target_helper")
local deh		= require("scripts.depot_helper")
local rc    	= require("scripts.requester_cooldown")
local mh		= require("scripts.mooring_helper")
local dt		= require("scripts.drone_tasks")
local mc		= require("scripts.mooring_controller")
local dc		= require("scripts.drone_controller")
local gm		= require("scripts.gui_mooring")
local gcd		= require("scripts.gui_cargo_drone")
local scheduler	= require("scripts.scheduler")
local migration	= require("scripts.migration")

local function unmanage_entity(entity)
	local unit_number = entity.unit_number

	if ep.is_cargo_drone(unit_number) then
		dc.drone_destroyed(unit_number)

		dt.drone_destroyed(entity)

		scheduler.drone_destroyed(unit_number)
	elseif mh.is_mooring(unit_number) then
		dt.target_destroyed(entity)
	elseif entity.name == "cargo-drone-depot-constant-combinator" then
		dt.target_destroyed(entity)
	end

	ep.entity_unmanage(unit_number)
end

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

	ep.init()

	deh.init()

	rc.init()

	mh.init()

	dt.init()

	gm.create_player_storage()
	gcd.create_player_storage()

	scheduler.init()
end
function on_configuration_changed(event)
	migration.run_migration()
end
function on_tick(event)
	rc.tick()

	scheduler.tick(event.tick)

	dc.tick(event.tick)

	mc.tick()

	gm.tick()
	gcd.tick()
end

function on_player_removed(event)
	gm.on_player_removed(event)
	gcd.on_player_removed(event)
end

function on_surface_deleted(event)
	ep.remove_invalid_entities()

	dt.surface_deleted(event.surface_index)
end
function on_surface_cleared(event)
	ep.remove_invalid_entities()

	dt.surface_cleared(event.surface_index)
end
function on_built_entity(event)
	local entity = event.entity

	if entity.name == "entity-ghost" then
		ep.entity_manage(entity)

		mh.clean_settings_ghost(entity)

		return
	end

	if entity.name == "cargo-drone" then
		ep.entity_manage(entity)

		script.register_on_object_destroyed(entity)

		ep.add_cargo_drone(entity)

		dt.drone_created(entity)

		return
	end

	if entity.name == "cargo-drone-depot-constant-combinator" then
		deh.created(entity)

		script.register_on_object_destroyed(entity)

		return
	end

	if not mh.try_setup_mooring(entity) then
		entity.destroy()
	end
end
function on_destroyed_entity(event)
	gm.on_destroyed_entity(event)

	local entity = event.entity

	if not ep.is_managed(entity.unit_number) then
		return
	end

	if entity.name == "cargo-drone-depot-constant-combinator" then
		deh.destroyed(entity)
	end

	mc.on_destroyed_entity(entity)

	unmanage_entity(entity)
end
function on_player_rotated_entity(event)
	if not event.entity or not event.entity.valid then
		return
	end

	local entity_name = event.entity.name

	if entity_name == "entity-ghost" then
		entity_name = event.entity.ghost_name
	end

	if mh.is_name_mooring(entity_name) then
		mh.on_rotate(event.entity)
	end
end
function on_player_flipped_entity(event)
	if not event.entity or not event.entity.valid then
		return
	end

	local entity_name = event.entity.name

	if entity_name == "entity-ghost" then
		entity_name = event.entity.ghost_name
	end

	if mh.is_name_mooring(entity_name) then
		mh.on_flip(event.entity)
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

	dt.drone_surface_change(event.entity, event.old_surface_index)
end

function on_gui_opened(event)
	gm.on_gui_opened(event)
	gcd.on_gui_opened(event)
end
function on_gui_closed(event)
	gm.on_gui_closed(event)
	gcd.on_gui_closed(event)
end
function on_gui_click(event)
    gm.on_gui_click(event)
    gcd.on_gui_click(event)
end
function on_gui_checked_state_changed(event)
	gm.on_gui_checked_state_changed(event)
end
function on_gui_value_changed(event)
	gm.on_gui_value_changed(event)
end
function on_gui_text_changed(event)
	gm.on_gui_text_changed(event)
end
function on_gui_elem_changed(event)
	gm.on_gui_elem_changed(event)
end
function on_gui_selection_state_changed(event)
	gm.on_gui_selection_state_changed(event)
end
function on_gui_confirmed(event)
	gm.on_gui_confirmed(event)
end

local build_event_filters = {
	{ filter = "name", name = "cargo-drone" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "name", name = "cargo-drone-depot-constant-combinator" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "ghost_name", name = "cargo-drone-depot-constant-combinator" },
}
local build_events = {
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
	defines.events.on_entity_cloned,
}
local destroy_event_filters = {
	{ filter = "name", name = "cargo-drone" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "name", name = "cargo-drone-depot-constant-combinator" },
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
local script_raised_teleported_filters = {
	{ filter = "name", name = "cargo-drone" },
}

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)

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
