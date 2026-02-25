
local constants = require("scripts.constants")
local ep		= require("scripts.entity_property")
local rc    	= require("scripts.requester_cooldown")
local mh		= require("scripts.mooring_helper")
local dt		= require("scripts.drone_tasks")
local dc		= require("scripts.drone_controller")
local gm		= require("scripts.gui_mooring")
local gcd		= require("scripts.gui_cargo_drone")
local scheduler	= require("scripts.scheduler")

local mooring_type = {
	provider = 1,
	requester = 2,
	refueler = 3
}

local moorings_data = {
	["cargo-drone-mooring-constant-combinator-provider"] = {
		type = mooring_type.provider,
		proxy_container_name = "cargo-drone-mooring-proxy-container-provider"
	},
	["cargo-drone-mooring-constant-combinator-requester"] = {
		type = mooring_type.requester,
		proxy_container_name = "cargo-drone-mooring-proxy-container-requester"
	},
	["cargo-drone-mooring-constant-combinator-refueler"] = {
		type = mooring_type.refueler,
		proxy_container_name = "cargo-drone-mooring-proxy-container-refueler"
	},
}

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

		scheduler.drone_destroyed(unit_number)
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

local function try_setup_mooring(mooring)
	local mooring_data = moorings_data[mooring.name]

	if mooring_data == nil then
		return
	end

	local proxy_container = mooring.surface.create_entity({
		name = mooring_data.proxy_container_name,
		position = mooring.position,
		force = mooring.force,
		create_build_effect_smoke = false,
		raise_built = true,
	})

	if not proxy_container then
		mooring.destroy()

		return
	end

	ep.entity_manage(mooring)

	script.register_on_object_destroyed(mooring)

	if mooring_data.type == mooring_type.provider then
		ep.add_cargo_drone_provider_mooring(mooring)
	elseif mooring_data.type == mooring_type.requester then
		ep.add_cargo_drone_requester_mooring(mooring)

		ep.set_entity_property(mooring, "next_free_gametick", 0)
	else
		ep.add_cargo_drone_refuel_mooring(mooring)
	end

	ep.set_entity_property(mooring, "proxy_container", proxy_container)

	mh.clean_settings(mooring)
end

local function migrate_state()
	local old_mod_state = storage.mod_state or 0

	log("Migrating cargo-drone state from " .. old_mod_state .. " to " .. constants.current_mod_state .. "...")

	storage.mod_state = constants.current_mod_state

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
				try_setup_mooring(entity)
			end
			for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-requester" }) do
				try_setup_mooring(entity)
			end
			for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-refueler" }) do
				try_setup_mooring(entity)
			end
		end

		game.print("Warning. Due to a migration issue when updating cargo-drone from a version prior to 1.4.0, all circuit wires connected to moorings have been removed and will need to be replaced. Note that drone limit and priority must now be configured in the moorings. Sorry for the inconvenience.")
	end

	if old_mod_state < 7 then
		storage.drone_controller = nil
	end

	if old_mod_state < 8 then
		scheduler.init()
	end

	log("cargo-drone state migration complete")
end

function on_init()
	safe_call(function()
		ep.init()

		gm.create_player_storage()
		gcd.create_player_storage()

		scheduler.init()
	end)
end
function on_configuration_changed(event)
	if storage.mod_state == constants.current_mod_state then
		return
	end

	migrate_state()
end
function on_tick(event)
	safe_call(function()
		rc.tick()

		scheduler.tick(event.tick)

		dc.tick(event.tick)

		gm.tick()
		gcd.tick()
	end)
end

function on_player_removed(event)
	gm.on_player_removed(event)
	gcd.on_player_removed(event)
end

function on_built_entity(event)
	safe_call(function()
		local entity = event.entity

		if entity.name == "cargo-drone" then
			ep.entity_manage(entity)

			script.register_on_object_destroyed(entity)

			ep.add_cargo_drone(entity)

			dt.drone_created(entity)
		else
			try_setup_mooring(entity)
		end
	end)
end
function on_destroyed_entity(event)
	gm.on_destroyed_entity(event)

	local entity = event.entity

	local unit_number = entity.unit_number

	if not ep.is_managed(unit_number) then
		return
	end

	if ep.is_provider_mooring(unit_number)
		or ep.is_requester_mooring(unit_number)
		or ep.is_refueler_mooring(unit_number) then
		local proxy_container = ep.get_entity_property(entity, "proxy_container")

		proxy_container.destroy({ raise_destroy = true })
	end

	unmanage_entity(unit_number)
end
function on_entity_settings_pasted(event)
	if not event.destination or not event.destination.valid then
		return
	end

	local unit_number = event.destination.unit_number

	if ep.is_provider_mooring(unit_number)
		or ep.is_requester_mooring(unit_number)
		or ep.is_refueler_mooring(unit_number) then
		mh.clean_settings(event.destination)
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

local event_filters = {
	{ filter = "name", name = "cargo-drone" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-provider" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-requester" },
	{ filter = "name", name = "cargo-drone-mooring-constant-combinator-refueler" }
}
local build_events = {
	defines.events.on_built_entity,
	defines.events.on_robot_built_entity,
	defines.events.script_raised_built,
	defines.events.script_raised_revive,
	defines.events.on_entity_cloned,
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
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)

for _, event in ipairs(build_events) do
	script.set_event_filter(event, event_filters)
end
for _, event in ipairs(destroy_events) do
	script.set_event_filter(event, event_filters)
end
