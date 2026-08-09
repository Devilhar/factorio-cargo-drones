
local drone_types = {}

local function get_tick_countdown(unit_number)
	local next_tick = remote.call("cargo-drone-debug", "get_next_tick", unit_number)

	if next_tick == 0 then
		return "0"
	end

	return tostring(next_tick - game.tick)
end

local function set_drone(drone)
	if storage.drones[drone.unit_number] then
		return
	end

	local text = rendering.draw_text{
		text = get_tick_countdown(drone.unit_number),
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
			data.text.text = get_tick_countdown(unit_number)
		end
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
		text = get_tick_countdown(event.entity.unit_number),
		color = { 1, 1, 1 },
		target = event.entity,
		surface = event.entity.surface,
	}

	storage.drones[event.entity.unit_number].text = text
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

for _, event in ipairs(build_events) do
	script.set_event_filter(event, build_event_filters)
end
for _, event in ipairs(destroy_events) do
	script.set_event_filter(event, destroy_event_filters)
end
script.set_event_filter(defines.events.script_raised_teleported, script_raised_teleported_filters)
