
local util      = require("util")

local constants = require("scripts.constants")
local dt        = require("scripts.drone_tasks")
local ir	    = require("scripts.item_requests")

local function get_closest_drone_to_mooring(drones, mooring)
    local closest_index = nil
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for i, drone in ipairs(drones) do
        if drone.valid then
            local distance = util.distance(drone.position, mooring.position)

            if distance < closest_distance then
                closest_index = i
                closest_distance = distance
            end
        end
    end

    return closest_index
end

local function collect_idle_drones()
    storage.scheduler.idling_cargo_drones = {}
    storage.scheduler.idling_cargo_drones_empty = {}
    storage.scheduler.idling_cargo_drones_with_cargo = {}

    for surface_index, drones in pairs(dt.get_idle_drones_per_surface()) do
        for _, drone in pairs(drones) do
            if not storage.scheduler.idling_cargo_drones[surface_index] then
                storage.scheduler.idling_cargo_drones[surface_index] = {}
            end

            table.insert(storage.scheduler.idling_cargo_drones[surface_index], drone)
        end
    end
end

local function sort_idle_drone()
    local drones = nil

    if storage.scheduler.key_drone == nil then
        storage.scheduler.key_surface, drones = next(storage.scheduler.idling_cargo_drones, storage.scheduler.key_surface)

        if storage.scheduler.key_surface == nil then
            return true
        end
    else
        drones = storage.scheduler.idling_cargo_drones[storage.scheduler.key_surface]
    end

    local drone = nil

    storage.scheduler.key_drone, drone = next(drones, storage.scheduler.key_drone)

    if storage.scheduler.key_drone == nil or not drone.valid then
        return false
    end

    local inventory = drone.get_inventory(defines.inventory.car_trunk)

    if inventory.is_empty() then
        if not storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface] then
            storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface] = {}
        end

        table.insert(storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface], drone)
    else
        if not storage.scheduler.idling_cargo_drones_with_cargo[storage.scheduler.key_surface] then
            storage.scheduler.idling_cargo_drones_with_cargo[storage.scheduler.key_surface] = {}
        end

        table.insert(storage.scheduler.idling_cargo_drones_with_cargo[storage.scheduler.key_surface], drone)
    end

    return false
end

local function assign_task_to_drone_with_cargo()
    local drones = nil

    if storage.scheduler.key_drone == nil then
        storage.scheduler.key_surface, drones = next(storage.scheduler.idling_cargo_drones_with_cargo, storage.scheduler.key_surface)

        if storage.scheduler.key_surface == nil then
            return true
        end
    else
        drones = storage.scheduler.idling_cargo_drones_with_cargo[storage.scheduler.key_surface]
    end

    local drone = nil

    storage.scheduler.key_drone, drone = next(drones, storage.scheduler.key_drone)

    if storage.scheduler.key_drone == nil or not drone.valid then
        return false
    end

    ir.assign_to_request_with_items(drone)
    storage.scheduler.tickrate_buffer[drone.unit_number] = constants.drones_tickrates.every

    return false
end

local function process_next_item_request()
    local drones = nil

    if storage.scheduler.key_drone == nil then
        storage.scheduler.key_surface, drones = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        if storage.scheduler.key_surface == nil then
            return true
        end
    else
        drones = storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface]
    end

    local item_request = ir.get_next_item_request(storage.scheduler.key_surface)

    if not item_request then
        return false
    end

    local closest_index = get_closest_drone_to_mooring(drones, item_request.provider)

    if closest_index ~= nil then
        local drone = drones[closest_index]

        table.remove(drones, closest_index)

        ir.assign_item_request(drone, item_request)
        storage.scheduler.tickrate_buffer[drone.unit_number] = constants.drones_tickrates.every
    end

    return false
end

local scheduler = {}

function scheduler.init()
    storage.scheduler = storage.scheduler or {}

    storage.scheduler.update_state = storage.scheduler.update_state or 0
    storage.scheduler.last_assign_tick = storage.scheduler.last_assign_tick or 0

    storage.scheduler.tickrate_buffer = storage.scheduler.tickrate_buffer or {}

    storage.scheduler.key_surface = storage.scheduler.key_surface or nil
    storage.scheduler.key_drone = storage.scheduler.key_drone or nil

    storage.scheduler.idling_cargo_drones = storage.scheduler.idling_cargo_drones or {}
    storage.scheduler.idling_cargo_drones_empty = storage.scheduler.idling_cargo_drones_empty or {}
    storage.scheduler.idling_cargo_drones_with_cargo = storage.scheduler.idling_cargo_drones_with_cargo or {}
end

function scheduler.drone_destroyed(unit_number)
    storage.scheduler.tickrate_buffer[unit_number] = nil
end

function scheduler.tick(game_tick)
    if storage.scheduler.update_state == 0 then
        storage.scheduler.update_state = 1
        ir.begin_update()
    end

    local current_action = 0

    if storage.scheduler.update_state == 2 then
        for _ = 1, constants.max_actions - current_action do
            if sort_idle_drone() then
                storage.scheduler.update_state = 3
                storage.scheduler.key_surface = nil
                storage.scheduler.key_drone = nil

                break
            end

            current_action = current_action + 1
        end
    end

    if storage.scheduler.update_state == 3 and game_tick >= storage.scheduler.last_assign_tick + constants.min_task_assign_interval then
        for _ = 1, constants.max_actions - current_action do
            if assign_task_to_drone_with_cargo() then
                storage.scheduler.update_state = 4
                storage.scheduler.key_surface = nil
                storage.scheduler.key_drone = nil

                break
            end

            current_action = current_action + 1
        end
    end

    if storage.scheduler.update_state == 4 then
        for _ = 1, constants.max_actions - current_action do
            if process_next_item_request() then
                storage.scheduler.last_assign_tick = game_tick
                storage.scheduler.update_state = 0
                storage.scheduler.key_surface = nil
                storage.scheduler.key_drone = nil

                break
            end

            current_action = current_action + 1
        end
    end

    if storage.scheduler.update_state == 1 then
        if ir.run_update() then
            collect_idle_drones()

            storage.scheduler.update_state = 2
        end
    end
end

return scheduler
