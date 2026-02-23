
local constants = {}

-- Mods
constants.current_mod_state = 6

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

return constants
