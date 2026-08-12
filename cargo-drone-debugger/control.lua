
local drone_types = {}
local acceleration_names = {
	[defines.riding.acceleration.accelerating]	= "Accelerating",
	[defines.riding.acceleration.braking]		= "Braking",
	[defines.riding.acceleration.nothing]		= "Nothing",
}

local scheduler_state_names = {
    [0] = "begin_frame",

    [1] = "collect_idle_drones",
    [2] = "collect_requester_moorings",
    [3] = "collect_provider_moorings",

    [10] = "scan_providers",
    [11] = "scan_requesters",

    [4] = "sort_idle_drone",

    [5] = "collect_requester_items",
    [6] = "collect_provider_items",

    [7] = "assign_task_to_drone_with_cargo",
    [8] = "process_next_item_request",

    [12] = "assign_depot_task",

    [9] = "wait_for_next_interval",
}


local function get_tick_countdown(unit_number)
	local next_tick = remote.call("cargo-drone-debug", "get_next_tick", unit_number)

	if next_tick == 0 then
		return "0"
	end

	return tostring(next_tick - game.tick)
end
local function get_drone_text(drone)
	local riding_state = drone.riding_state

	return get_tick_countdown(drone.unit_number) .. " " .. acceleration_names[riding_state.acceleration]
end

local function set_drone(drone)
	if storage.drones[drone.unit_number] then
		return
	end

	local text = rendering.draw_text{
		text = get_drone_text(drone),
		color = { 1, 1, 1 },
		target = drone,
		surface = drone.surface,
	}

	storage.drones[drone.unit_number] = {
		drone = drone,
		text = text,
	}
end
local function reset_drone(drone)
	if not storage.drones[drone.unit_number] then
		return
	end

	storage.drones[drone.unit_number].text.destroy()

	storage.drones[drone.unit_number] = nil
end
local function clean_drones()
	local removed_drones = {}

	for unit_number, data in pairs(storage.drones) do
		if not data.drone.valid then
			table.insert(removed_drones, unit_number)
		end
	end

	for _, unit_number in ipairs(removed_drones) do
		storage.drones[unit_number] = nil
	end
end

local function update_window_info(player)
	local window = player.gui.screen["cargo-drone-debugger-window"]

	if not window then
		return
	end

	local label = window["debug-label"]
	local storage_info = remote.call("cargo-drone-debug", "get_storage_info")
	local drones_info = remote.call("cargo-drone-debug", "get_drones_info")
	local scheduler_info = remote.call("cargo-drone-debug", "get_scheduler_info")

	label.caption = "Storage values: "		.. storage_info.value_count
			   .. "\nDrones"
			   .. "\n    Total: "			.. drones_info.count
			   .. "\n    Idle: "			.. drones_info.idle_count
			   .. "\n    Docked: "			.. drones_info.docked
			   .. "\n    Queuing: "			.. drones_info.queuing
			   .. "\n    Parked: "			.. drones_info.parked
			   .. "\nScheduler"
			   .. "\n    Next State: "		.. scheduler_state_names[scheduler_info.state]
			   .. "\n    Next Interval: "	.. scheduler_info.next_interval
end

local function init_drones()
	storage.drones = storage.drones or {}

	for _, surface in pairs(game.surfaces) do
		for _, name in ipairs(drone_types) do
			for _, drone in ipairs(surface.find_entities_filtered{ name = name }) do
				set_drone(drone)
			end
		end
	end
end

local function open_window(player)
	local window = player.gui.screen.add{
        type = "frame",
        name = "cargo-drone-debugger-window",
        direction = "vertical",
    }

	window.style.minimal_width = 250

	local label = window.add{
        type = "label",
        name = "debug-label",
    }

	label.drag_target = window
	label.style.single_line = false

	update_window_info(player)
end
local function close_window(player)
	player.gui.screen["cargo-drone-debugger-window"].destroy()
end
local function toggle_window(player)
	if player.gui.screen["cargo-drone-debugger-window"] then
		close_window(player)
	else
		open_window(player)
	end
end

local function on_init()
	init_drones()
end
local function on_configuration_changed(event)
	clean_drones()

	init_drones()
end
local function on_tick(_event)
	for unit_number, data in pairs(storage.drones) do
		if data.text.valid then
			data.text.text = get_drone_text(data.drone)
		end
	end

	for _, player in pairs(game.players) do
		update_window_info(player)
	end
end

local function on_surface_deleted(_event)
	clean_drones()
end
local function on_surface_cleared(_event)
	clean_drones()
end
local function on_built_entity(event)
	set_drone(event.entity)
end
local function on_destroyed_entity(event)
	reset_drone(event.entity)
end
local function script_raised_teleported(event)
	if event.old_surface_index == event.entity.surface.index then
		return
	end

	local text = rendering.draw_text{
		text = get_drone_text(event.entity),
		color = { 1, 1, 1 },
		target = event.entity,
		surface = event.entity.surface,
	}

	storage.drones[event.entity.unit_number].text = text
end

local function on_input_toggle_window(event)
	toggle_window(game.get_player(event.player_index))
end

local build_event_filters = {
	{ filter = "name", name = "cargo-drone" },
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
}
local destroy_events = {
	defines.events.on_entity_died,
	defines.events.on_player_mined_entity,
	defines.events.on_robot_mined_entity,
	defines.events.script_raised_destroy,
}
local script_raised_teleported_filters = {}

for name, _ in pairs(prototypes.mod_data["cargo-drone-prototypes"].data) do
	table.insert(drone_types, name)
	table.insert(build_event_filters, { filter = "name", name = name })
	table.insert(destroy_event_filters, { filter = "name", name = name })
	table.insert(script_raised_teleported_filters, { filter = "name", name = name })
end

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)

script.on_event(defines.events.on_surface_deleted, on_surface_deleted)
script.on_event(defines.events.on_surface_cleared, on_surface_cleared)
script.on_event(build_events, on_built_entity)
script.on_event(destroy_events, on_destroyed_entity)
script.on_event(defines.events.script_raised_teleported, script_raised_teleported)

script.on_event("cargo-drone-debugger-toggle-window", on_input_toggle_window)

for _, event in ipairs(build_events) do
	script.set_event_filter(event, build_event_filters)
end
for _, event in ipairs(destroy_events) do
	script.set_event_filter(event, destroy_event_filters)
end
script.set_event_filter(defines.events.script_raised_teleported, script_raised_teleported_filters)
