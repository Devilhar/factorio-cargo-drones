
local constants = {}

-- Mods
constants.current_mod_state = 12

-- Settings
constants.drone_has_burnt_result = prototypes.entity["cargo-drone"].burner_prototype.burnt_inventory_size > 0

-- Cargo drones
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

-- Utils

-- Longer than moving from one corner to the other, and then multiplied by 10 for good measure
constants.max_distance = 30000000

return constants
