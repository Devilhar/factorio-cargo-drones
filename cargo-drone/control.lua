
local constants = require("scripts.constants")
local ep		= require("scripts.entity_property")
local rc    	= require("scripts.requester_cooldown")
local mh		= require("scripts.mooring_helper")
local dt		= require("scripts.drone_tasks")
local mc		= require("scripts.mooring_controller")
local dc		= require("scripts.drone_controller")
local gm		= require("scripts.gui_mooring")
local gcd		= require("scripts.gui_cargo_drone")
local scheduler	= require("scripts.scheduler")

local function unmanage_entity(unit_number)
	if ep.is_cargo_drone(unit_number) then
		dc.drone_destroyed(unit_number)

		dt.drone_destroyed(unit_number)

		scheduler.drone_destroyed(unit_number)
	elseif mh.is_mooring(unit_number) then
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
	local old_mod_state = storage.mod_state or 0

	log("Migrating cargo-drone state from " .. old_mod_state .. " to " .. constants.current_mod_state .. "...")

	storage.mod_state = constants.current_mod_state

	mh.init()

	if old_mod_state < 6 then
		ep.remove_invalid_entities()
	end

	if old_mod_state < 1 then
		resetup_object_events()
	end

	if old_mod_state < 4 then
		ep.reset_surface_indices()
	end

	if old_mod_state < 6 then
		gm.create_player_storage()
		gcd.create_player_storage()

		dt.migration_remove_all_tasks()

		for _, surface in pairs(game.surfaces) do
			for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-provider" }) do
				if not mh.try_setup_mooring(entity) then
					entity.destroy()
				end
			end
			for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-requester" }) do
				if not mh.try_setup_mooring(entity) then
					entity.destroy()
				end
			end
			for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-refueler" }) do
				if not mh.try_setup_mooring(entity) then
					entity.destroy()
				end
			end
		end

		game.print({ "cargo-drone-migration.warning-wires-removed" })
	end

	if old_mod_state < 7 then
		storage.drone_controller = nil
	end

	if old_mod_state < 8 then
		scheduler.init()
	end

	if old_mod_state < 9 then
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

	for _, entity_data in pairs(ep.get_cargo_drone_provider_moorings()) do
		mh.clean_settings(entity_data.entity)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_requester_moorings()) do
		mh.clean_settings(entity_data.entity)
	end
	for _, entity_data in pairs(ep.get_cargo_drone_refuel_moorings()) do
		mh.clean_settings(entity_data.entity)
	end

	log("cargo-drone state migration complete")
end

function on_init()
	ep.init()

	mh.init()

	gm.create_player_storage()
	gcd.create_player_storage()

	scheduler.init()
end
function on_configuration_changed(event)
	if storage.mod_state == constants.current_mod_state then
		return
	end

	migrate_state()
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

function on_built_entity(event)
	local entity = event.entity

	if entity.name == "entity-ghost" then
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

	if not mh.try_setup_mooring(entity) then
		entity.destroy()
	end
end
function on_destroyed_entity(event)
	gm.on_destroyed_entity(event)

	local entity = event.entity

	local unit_number = entity.unit_number

	if not ep.is_managed(unit_number) then
		return
	end

	mc.on_destroyed_entity(entity)

	unmanage_entity(unit_number)
end
function on_player_rotated_entity(event)
	if not event.entity or not event.entity.valid then
		return
	end

	local unit_number = event.entity.unit_number

	if mh.is_mooring(unit_number) then
		mh.on_rotate(event.entity)
	end
end
function on_player_flipped_entity(event)
	if not event.entity or not event.entity.valid then
		return
	end

	local unit_number = event.entity.unit_number

	if mh.is_mooring(unit_number) then
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
	end
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

local build_event_filters = {
	{ filter = "name", name = "cargo-drone" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "ghost_name", name = "cargo-drone-mooring-constant-combinator-refueler" }
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
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" }
}
local destroy_events = {
	defines.events.on_entity_died,
	defines.events.on_player_mined_entity,
	defines.events.on_robot_mined_entity,
	defines.events.script_raised_destroy,
}

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)

script.on_event(defines.events.on_player_joined_game, on_player_removed)

script.on_event(build_events, on_built_entity)
script.on_event(destroy_events, on_destroyed_entity)
script.on_event(defines.events.on_player_rotated_entity, on_player_rotated_entity)
script.on_event(defines.events.on_player_flipped_entity, on_player_flipped_entity)
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)

for _, event in ipairs(build_events) do
	script.set_event_filter(event, build_event_filters)
end
for _, event in ipairs(destroy_events) do
	script.set_event_filter(event, destroy_event_filters)
end
