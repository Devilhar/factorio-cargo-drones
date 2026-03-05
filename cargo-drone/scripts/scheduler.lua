
local util      = require("util")

local constants = require("scripts.constants")
local ep        = require("scripts.entity_property")
local mh	    = require("scripts.mooring_helper")
local rc        = require("scripts.requester_cooldown")
local dt        = require("scripts.drone_tasks")
local ir	    = require("scripts.item_requests")

local mooring_scan_interval = 300

local reset_state = {}
-- These values can't change
local states = {
    begin_frame                     = 0,

    collect_idle_drones             = 1,
    collect_requester_moorings      = 2,
    collect_provider_moorings       = 3,

    scan_providers                  = 10,
    scan_requesters                 = 11,

    sort_idle_drone                 = 4,

    collect_requester_items         = 5,
    collect_provider_items          = 6,

    assign_task_to_drone_with_cargo = 7,
    process_next_item_request       = 8,

    assign_depot_task               = 12,

    wait_for_next_interval          = 9,
}

local function try_create_and_get_surface_buffer(surface_index)
    if not storage.scheduler.surface_buffer[surface_index] then
        storage.scheduler.surface_buffer[surface_index] = ir.create_surface_buffer()
    end

    return storage.scheduler.surface_buffer[surface_index]
end

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

local function begin_frame()
    storage.scheduler.update_stage = 0

    storage.scheduler.should_perform_mooring_scan = storage.scheduler.last_mooring_scan_tick + mooring_scan_interval < storage.scheduler.last_schedule_tick

    storage.scheduler.idling_cargo_drones = {}
    storage.scheduler.idling_cargo_drones_empty = {}
    storage.scheduler.idling_cargo_drones_with_cargo = {}

    storage.scheduler.surface_buffer = {}
    storage.scheduler.provider_buffer = {}
    storage.scheduler.requester_buffer = {}

    storage.scheduler.mooring_key = nil

    if storage.scheduler.should_perform_mooring_scan then
        storage.scheduler.last_mooring_scan_tick = storage.scheduler.last_schedule_tick
    end
end

local function collect_idle_drones()
    for surface_index, drones in pairs(dt.get_idle_drones_per_surface()) do
        for _, drone in pairs(drones) do
            if not storage.scheduler.idling_cargo_drones[surface_index] then
                storage.scheduler.idling_cargo_drones[surface_index] = {}
            end

            table.insert(storage.scheduler.idling_cargo_drones[surface_index], drone)
        end
    end
end
local function collect_requester_moorings()
    local requesters = ep.get_cargo_drone_requester_moorings()

    for requester_id, requester_data in pairs(requesters) do
        storage.scheduler.requester_buffer[requester_id] = requester_data.entity
    end
end
local function collect_provider_moorings()
    local providers = ep.get_cargo_drone_provider_moorings()

    for provider_id, provider_data in pairs(providers) do
        storage.scheduler.provider_buffer[provider_id] = provider_data.entity
    end
end

local function scan_moorings(moorings)
    local mooring = nil

    storage.scheduler.mooring_key, mooring = next(moorings, storage.scheduler.mooring_key)

    if storage.scheduler.mooring_key == nil then
        return true
    end

    if not mooring.valid then
        return false
    end

    if mooring.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil
        or mooring.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil then
        return false
    end

    for i = 1, #game.players do
        game.players[i].add_custom_alert(mooring, { type = "virtual", name = "signal-alert" }, { "cargo-drone-alerts.mooring-no-wire-connection" }, true)
    end

    return false
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

local function collect_requester_items()
    local requester = nil

    storage.scheduler.mooring_key, requester = next(storage.scheduler.requester_buffer, storage.scheduler.mooring_key)

    if storage.scheduler.mooring_key == nil then
        return true
    end

    if not requester.valid then
        return false
    end

    if rc.is_on_cooldown(storage.scheduler.mooring_key) then
        return false
    end

    local surface_buffer = try_create_and_get_surface_buffer(requester.surface.index)

    ir.add_items_to_requester(requester, surface_buffer.requester_items, surface_buffer.item_requester_lookup, surface_buffer.sorted_requesters)

    return false
end
local function collect_provider_items()
    local provider = nil

    storage.scheduler.mooring_key, provider = next(storage.scheduler.provider_buffer, storage.scheduler.mooring_key)

    if storage.scheduler.mooring_key == nil then
        return true
    end

    if not provider.valid then
        return false
    end

    local surface_buffer = try_create_and_get_surface_buffer(provider.surface.index)

    ir.add_items_to_provider(provider, surface_buffer.provider_items, surface_buffer.item_provider_lookup)

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

    local surface_buffer = storage.scheduler.surface_buffer[storage.scheduler.key_surface]

    if not surface_buffer then
        return false
    end

    ir.assign_to_request_with_items(surface_buffer, drone)
    storage.scheduler.tickrate_buffer[drone.unit_number] = constants.drones_tickrates.every

    return false
end
local function process_next_item_request(heuristic_target_count_cost)
    if storage.scheduler.key_surface == nil then
        storage.scheduler.key_surface = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        if storage.scheduler.key_surface == nil then
            return true
        end
    end

    local drones = storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface]

    if next(drones) == nil then
        storage.scheduler.key_surface = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        return storage.scheduler.key_surface == nil
    end

    local surface_buffer = storage.scheduler.surface_buffer[storage.scheduler.key_surface]

    if not surface_buffer then
        storage.scheduler.key_surface = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        return storage.scheduler.key_surface == nil
    end

    local item_request = ir.get_next_item_request(surface_buffer, heuristic_target_count_cost)

    if not item_request then
        storage.scheduler.key_surface = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        return storage.scheduler.key_surface == nil
    end

    local closest_index = get_closest_drone_to_mooring(drones, item_request.provider)

    if closest_index == nil then
        storage.scheduler.key_surface = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        return storage.scheduler.key_surface == nil
    end

    local drone = drones[closest_index]

    table.remove(drones, closest_index)

    ir.assign_item_request(surface_buffer, drone, item_request)
    storage.scheduler.tickrate_buffer[drone.unit_number] = constants.drones_tickrates.every

    return false
end

local function assign_depot_task()
    local drones = nil

    if storage.scheduler.key_drone == nil then
        storage.scheduler.key_surface, drones = next(storage.scheduler.idling_cargo_drones_empty, storage.scheduler.key_surface)

        if storage.scheduler.key_surface == nil then
            return true
        end
    else
        drones = storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface]
    end

    local drone = nil

    storage.scheduler.key_drone, drone = next(drones, storage.scheduler.key_drone)

    if storage.scheduler.key_drone == nil or not drone.valid then
        return false
    end

    if dt.get_current_drone_task_id(drone) ~= nil then
        return false
    end

    local function get_closest_depot()
        local depots = mh.get_depots(drone.surface.index)

        if depots == nil then
            return nil
        end

        local closest_depot = nil
        local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure
        local lowest_drone_count = 10000000

        for _, depot in pairs(depots) do
            if mh.is_depot_enabled(depot) then
                local distance = util.distance(drone.position, depot.position)
                local drone_count = mh.get_depot_drone_count(depot.unit_number)

                if drone_count <= lowest_drone_count then
                    if drone_count < lowest_drone_count or distance < closest_distance then
                        closest_depot = depot
                        closest_distance = distance
                        lowest_drone_count = drone_count
                    end
                end
            end
        end

        return closest_depot
    end

    local closest_depot = get_closest_depot()

    if closest_depot then
        dt.assign_depot(drone, get_closest_depot())
        storage.scheduler.tickrate_buffer[drone.unit_number] = constants.drones_tickrates.every
    end

    return false
end

local scheduler = {}

function scheduler.init()
    storage.scheduler = storage.scheduler or {}

    storage.scheduler.update_state = storage.scheduler.update_state or 0
    storage.scheduler.last_schedule_tick = storage.scheduler.last_schedule_tick or 0

    storage.scheduler.tickrate_buffer = storage.scheduler.tickrate_buffer or {}

    storage.scheduler.last_mooring_scan_tick = storage.scheduler.last_mooring_scan_tick or 0
    storage.scheduler.should_perform_mooring_scan = storage.scheduler.should_perform_mooring_scan or false

    storage.scheduler.key_surface = storage.scheduler.key_surface or nil
    storage.scheduler.key_drone = storage.scheduler.key_drone or nil

    storage.scheduler.idling_cargo_drones = storage.scheduler.idling_cargo_drones or {}
    storage.scheduler.idling_cargo_drones_empty = storage.scheduler.idling_cargo_drones_empty or {}
    storage.scheduler.idling_cargo_drones_with_cargo = storage.scheduler.idling_cargo_drones_with_cargo or {}

    storage.scheduler.surface_buffer = storage.scheduler.surface_buffer or {}
    storage.scheduler.provider_buffer = storage.scheduler.provider_buffer or {}
    storage.scheduler.requester_buffer = storage.scheduler.requester_buffer or {}

    storage.scheduler.mooring_key = storage.scheduler.mooring_key or nil
end

function scheduler.drone_destroyed(unit_number)
    storage.scheduler.tickrate_buffer[unit_number] = nil
end

local state_procs = {
    [states.begin_frame] = function()
        begin_frame()

        return states.collect_idle_drones
    end,

    [states.collect_idle_drones] = function()
        collect_idle_drones()

        if next(storage.scheduler.idling_cargo_drones) == nil and not storage.scheduler.should_perform_mooring_scan then
            return reset_state
        end

        return states.collect_requester_moorings
    end,
    [states.collect_requester_moorings] = function()
        collect_requester_moorings()

        if next(storage.scheduler.requester_buffer) == nil and not storage.scheduler.should_perform_mooring_scan then
            return reset_state
        end

        return states.collect_provider_moorings
    end,
    [states.collect_provider_moorings] = function()
        collect_provider_moorings()

        if storage.scheduler.should_perform_mooring_scan then
            storage.scheduler.mooring_key = nil

            return states.scan_providers
        end

        return states.sort_idle_drone
    end,

    [states.scan_providers] = function()
        for _ = 1, settings.global["cargo-drone-max-scanned-moorings"].value do
            if scan_moorings(storage.scheduler.provider_buffer) then
                return states.scan_requesters
            end
        end

        return nil
    end,
    [states.scan_requesters] = function()
        for _ = 1, settings.global["cargo-drone-max-scanned-moorings"].value do
            if scan_moorings(storage.scheduler.requester_buffer) then
                return states.sort_idle_drone
            end
        end

        return nil
    end,

    [states.sort_idle_drone] = function()
        for _ = 1, settings.global["cargo-drone-max-sort-idle-drones"].value do
            if sort_idle_drone() then
                storage.scheduler.key_surface = nil
                storage.scheduler.key_drone = nil

                if next(storage.scheduler.idling_cargo_drones) == nil or next(storage.scheduler.requester_buffer) == nil then
                    return states.assign_depot_task
                end

                return states.collect_requester_items
            end
        end

        return nil
    end,

    [states.collect_requester_items] = function()
        for _ = 1, settings.global["cargo-drone-max-collect-requester-items"].value do
            if collect_requester_items() then
                storage.scheduler.mooring_key = nil

                if next(storage.scheduler.idling_cargo_drones_empty) == nil then
                    return states.assign_task_to_drone_with_cargo
                end

                return states.collect_provider_items
            end
        end

        return nil
    end,
    [states.collect_provider_items] = function()
        for _ = 1, settings.global["cargo-drone-max-collect-provider-items"].value do
            if collect_provider_items() then
                storage.scheduler.mooring_key = nil

                return states.assign_task_to_drone_with_cargo
            end
        end

        return nil
    end,

    [states.assign_task_to_drone_with_cargo] = function()
        for _ = 1, settings.global["cargo-drone-max-assign-task-to-non-empty-drones"].value do
            if assign_task_to_drone_with_cargo() then
                storage.scheduler.key_surface = nil
                storage.scheduler.key_drone = nil

                if next(storage.scheduler.idling_cargo_drones_empty) == nil then
                    return reset_state
                end

                return states.process_next_item_request
            end
        end

        return nil
    end,
    [states.process_next_item_request] = function()
        local heuristic_target_count_cost = settings.global["cargo-drone-heuristic-target-count-cost"].value

        for _ = 1, settings.global["cargo-drone-max-processed-item-requests"].value do
            if process_next_item_request(heuristic_target_count_cost) then
                storage.scheduler.key_surface = nil
                storage.scheduler.key_drone = nil

                return states.assign_depot_task
            end
        end

        return nil
    end,
    [states.assign_depot_task] = function()
        for _ = 1, settings.global["cargo-drone-max-processed-item-requests"].value do -- FIXME: Unique setting
            if assign_depot_task() then
                return reset_state
            end
        end

        return nil
    end,
}

function scheduler.tick(game_tick)
    local current_state = storage.scheduler.update_state

    if current_state == states.wait_for_next_interval then
        if game_tick < storage.scheduler.last_schedule_tick + settings.global["cargo-drone-min-schedule-interval"].value then
            return
        end

        storage.scheduler.last_schedule_tick = game_tick
        storage.scheduler.update_state = states.begin_frame

        return
    end

    local next_state = state_procs[current_state]()

    if next_state == nil then
        return
    end

    if next_state ~= reset_state then
        storage.scheduler.update_state = next_state

        return
    end

    storage.scheduler.update_state = states.wait_for_next_interval
end

return scheduler
