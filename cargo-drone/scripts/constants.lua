
local constants = {}

-- Mods
constants.current_mod_state = 13

-- Settings
constants.drone_has_burnt_result = prototypes.entity["cargo-drone"].burner_prototype.burnt_inventory_size > 0

-- Cargo drones
constants.drone_sprite_offset = { x = 0, y = -9 }
constants.drone_sprite_shadow_offset = { x = 14, y = 0 }
constants.drone_queue_distance = 20
constants.random_tick_interval = 60

-- Scheduling
constants.requester_cooldown_ticks = 30

-- Tickrates need to either be divisible by random_tick_interval, or random_tick_interval need to be divisible by the tickrate
constants.drones_tickrates = {
    every = 1,
    reduced = 60,
    minimal = 60 * 5,
}

-- Depots
constants.depot_cable_sprite_size = { 8, 2 }
constants.depot_cable_attachment_offsets = {
    { -0.98, -0.2 },
    { 0.98, -0.2 },
    { -0.85, 0.8 },
    { 0.85, 0.8 },
}
constants.depot_cable_attachment_heights = {
    0.3,
    0.3,
    0.6,
    0.6,
}

-- Utils

-- Longer than moving from one corner to the other, and then multiplied by 10 for good measure
constants.max_distance = 30000000

return constants
