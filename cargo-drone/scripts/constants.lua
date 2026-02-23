
local constants = {}

-- Mods
constants.current_mod_state = 7

-- Settings
constants.drone_has_burnt_result = prototypes.entity["cargo-drone"].burner_prototype.burnt_inventory_size > 0

-- Cargo drones
constants.drone_queue_distance = 20
constants.random_tick_interval = 60
constants.min_task_assign_interval = 60
constants.heuristic_target_count_cost = 50

-- Scheduling
constants.max_actions = 10
constants.max_scans_per_tick = 10
constants.cooldown_ticks = 30

-- Tickrates need to either be divisible by random_tick_interval, or random_tick_interval need to be divisible by the tickrate
constants.drones_tickrates = {
    every = 1,
    reduced = 60,
    minimal = 60 * 5,
}

return constants
