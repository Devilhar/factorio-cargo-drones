
local util      = require("util")

local constants = require("constants")
local sf        = require("stack_frame")
local th        = require("target_helper")
local deh       = require("depot_helper")
local mh	    = require("mooring_helper")
local rc        = require("requester_cooldown")
local dt        = require("drone_tasks")
local dc        = require("drone_controller")
local ir	    = require("item_requests")

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

local function create_quadtree_grid(size, depth)
    return {
        size = size,
        depth = depth,
        quadtrees = {},
    }
end
local function add_to_quadtree_grid(grid, position, key, element)
    local grid_x = math.floor(position.x / grid.size)
    local grid_y = math.floor(position.y / grid.size)

    if not grid.quadtrees[grid_x] then
        grid.quadtrees[grid_x] = {}
    end

    if not grid.quadtrees[grid_x][grid_y] then
        grid.quadtrees[grid_x][grid_y] = {}
    end

    local quad = grid.quadtrees[grid_x][grid_y]

    local pos_x = position.x - grid_x * grid.size
    local pos_y = position.y - grid_y * grid.size
    local size = grid.size

    for _ = 1, grid.depth do
        size = size / 2

        local index = math.floor(pos_y / size) * 2 + math.floor(pos_x / size) + 1

        pos_x = pos_x - math.floor(pos_x / size) * size
        pos_y = pos_y - math.floor(pos_y / size) * size

        if not quad[index] then
            quad[index] = {}
        end

        quad = quad[index]
    end

    quad[key] = { position = position , element = element }
end
local function remove_from_quadtree_grid(grid, position, key)
    local grid_x = math.floor(position.x / grid.size)
    local grid_y = math.floor(position.y / grid.size)

    if not grid.quadtrees[grid_x] or not grid.quadtrees[grid_x][grid_y] then
        return
    end

    local function remove(quad, size, remaining, pos_x, pos_y)
        size = size / 2

        local index = math.floor(pos_y / size) * 2 + math.floor(pos_x / size) + 1

        if not quad[index] then
            return
        end

        if remaining > 1 then
            pos_x = pos_x - math.floor(pos_x / size) * size
            pos_y = pos_y - math.floor(pos_y / size) * size

            remove(quad[index], size, remaining - 1, pos_x, pos_y)
        else
            quad[index][key] = nil
        end

        if not next(quad[index]) then
            quad[index] = nil
        end
    end

    local pos_x = position.x - grid_x * grid.size
    local pos_y = position.y - grid_y * grid.size
    local size = grid.size

    remove(grid.quadtrees[grid_x][grid_y], size, grid.depth, pos_x, pos_y)

    if not next(grid.quadtrees[grid_x][grid_y]) then
        grid.quadtrees[grid_x][grid_y] = nil
    end
end

local function try_create_and_get_surface_buffer(surface_index)
    if not storage.scheduler.surface_buffer[surface_index] then
        storage.scheduler.surface_buffer[surface_index] = ir.create_surface_buffer()
    end

    return storage.scheduler.surface_buffer[surface_index]
end

local function begin_frame()
    storage.scheduler.update_stage = 0

    storage.scheduler.frame_buffer = sf.create_buffer()

    storage.scheduler.should_perform_mooring_scan =
        (settings.global["cargo-drone-mooring-no-wire-connection-alert"].value
            or settings.global["cargo-drone-mooring-mooring-depot-alert"].value)
        and storage.scheduler.last_mooring_scan_tick + mooring_scan_interval < storage.scheduler.last_schedule_tick

    storage.scheduler.idling_cargo_drones = {}
    storage.scheduler.idling_cargo_drones_empty = {}
    storage.scheduler.idling_cargo_drones_with_cargo = {}
    storage.scheduler.idling_cargo_drones_quadtree = {}

    storage.scheduler.surface_buffer = {}
    storage.scheduler.provider_buffer = {}
    storage.scheduler.requester_buffer = {}

    storage.scheduler.mooring_key = nil

    if storage.scheduler.should_perform_mooring_scan then
        storage.scheduler.last_mooring_scan_tick = storage.scheduler.last_schedule_tick
    end
end

local function collect_idle_drones()
    for surface_index, surface_buffer in pairs(dt.get_idle_drones_per_surface()) do
        for _, drone in pairs(surface_buffer.idle_drones) do
            if drone.valid then
                if not storage.scheduler.idling_cargo_drones[surface_index] then
                    storage.scheduler.idling_cargo_drones[surface_index] = {}
                end

                table.insert(storage.scheduler.idling_cargo_drones[surface_index], drone)
            else
                storage.invalid_entity_detected = true
            end
        end
    end
end
local function collect_requester_moorings()
    for _, surface_buffer in pairs(storage.mooring_controller.surfaces) do
        for _, mooring in pairs(surface_buffer[mh.mooring_types.requester]) do
            if mooring.valid then
                storage.scheduler.requester_buffer[mooring.unit_number] = mooring
            else
                storage.invalid_entity_detected = true
            end
        end
    end
end
local function collect_provider_moorings()
    for _, surface_buffer in pairs(storage.mooring_controller.surfaces) do
        for _, mooring in pairs(surface_buffer[mh.mooring_types.provider]) do
            if mooring.valid then
                storage.scheduler.provider_buffer[mooring.unit_number] = mooring
            else
                storage.invalid_entity_detected = true
            end
        end
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

    if settings.global["cargo-drone-mooring-no-wire-connection-alert"].value
        and mooring.get_circuit_network(defines.wire_connector_id.circuit_red) == nil
        and mooring.get_circuit_network(defines.wire_connector_id.circuit_green) == nil then
        for i = 1, #game.players do
            game.players[i].add_custom_alert(mooring, { type = "virtual", name = "signal-alert" }, { "cargo-drone-alerts.mooring-no-wire-connection" }, true)
        end
    end

    if settings.global["cargo-drone-mooring-mooring-depot-alert"].value
        and mh.has_depot_flag(mooring) then
        for i = 1, #game.players do
            game.players[i].add_custom_alert(mooring, { type = "virtual", name = "signal-alert" }, { "cargo-drone-alerts.mooring-depot-flag" }, true)
        end
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
        if not storage.scheduler.idling_cargo_drones_quadtree[storage.scheduler.key_surface] then
            storage.scheduler.idling_cargo_drones_quadtree[storage.scheduler.key_surface] = create_quadtree_grid(32 * 2^5, 5)
        end

        storage.scheduler.idling_cargo_drones_empty[storage.scheduler.key_surface][drone.unit_number] = { drone = drone, position = drone.position }
        add_to_quadtree_grid(storage.scheduler.idling_cargo_drones_quadtree[storage.scheduler.key_surface], drone.position, drone.unit_number, drone)
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
    dc.interrupt_drone(drone)

    return false
end

local function sort_into_quad_list(quad_list, quad, quad_size, pos_x, pos_y, distance)
    if distance > quad_list[1].d + quad_size then
        return
    end

    for i = 1, 4 do
        if distance < quad_list[i].d then
            for j = 4, i + 1, -1 do
                if quad_list[j - 1].d > quad_list[1].d + quad_size then
                    quad_list[j].q = nil
                else
                quad_list[j].q = quad_list[j - 1].q
                quad_list[j].d = quad_list[j - 1].d
                quad_list[j].x = quad_list[j - 1].x
                quad_list[j].y = quad_list[j - 1].y
                end
            end

            quad_list[i].q = quad
            quad_list[i].d = distance
            quad_list[i].x = pos_x
            quad_list[i].y = pos_y

            return
        end
    end
end

local function process_next_item_request(heuristic_target_count_cost)
    return not sf.iterate(storage.scheduler.idling_cargo_drones_empty, nil, storage.scheduler.frame_buffer, function(top_fb, surface_index, drones)
        -- FIXME: drones is currently not changed
        if not next(drones) then
            return sf.continue_and_yield
        end

        return sf.sequence(top_fb, {
            function()
                top_fb.surface_buffer = storage.scheduler.surface_buffer[surface_index]

                if not top_fb.surface_buffer then
                    return true, sf.continue_and_yield
                end
            end,
            sf.sequence_call(top_fb, ir.get_next_item_request, function() return top_fb.surface_buffer, heuristic_target_count_cost end),
            function()
                top_fb.item_request = sf.ret_val

                if not top_fb.item_request then
                    return true, sf.continue_and_yield
                end

                top_fb.mooring = top_fb.item_request.provider
                top_fb.closest_quad = nil
                top_fb.closest_distance = constants.max_distance
            end,
            function()
                top_fb.current_depth = 1
                top_fb.depth_size = storage.scheduler.idling_cargo_drones_quadtree[surface_index].size
                top_fb.closest_quads = {
                    { d = constants.max_distance },
                    { d = constants.max_distance },
                    { d = constants.max_distance },
                    { d = constants.max_distance },
                }
            end,
            sf.sequence_iterator(function() return storage.scheduler.idling_cargo_drones_quadtree[surface_index].quadtrees, nil end, top_fb, function(fb, grid_x, quads_x)
                if sf.iterate(quads_x, nil, fb, function(_, grid_y, quad)
                    local provider_pos = top_fb.item_request.provider.position
                    local grid_size = top_fb.depth_size

                    local pos_x = grid_x * grid_size
                    local pos_y = grid_y * grid_size

                    sort_into_quad_list(top_fb.closest_quads, quad, grid_size, pos_x, pos_y, util.distance(provider_pos, { pos_x + grid_size / 2, pos_y + grid_size / 2 }))

                    return sf.continue_and_yield
                end) then
                    return sf.status, sf.ret_val
                end
            end),
            function()
                top_fb.current_depth = top_fb.current_depth + 1
                top_fb.depth_size = top_fb.depth_size / 2
                top_fb.prev_quads = top_fb.closest_quads

                top_fb.closest_quads = {
                    { d = constants.max_distance },
                    { d = constants.max_distance },
                    { d = constants.max_distance },
                    { d = constants.max_distance },
                }
            end,
            sf.sequence_iterator(function() return top_fb.prev_quads, nil end, top_fb, function(_, _, entry)
                if not entry.q then
                    return
                end

                for x = 0, 1 do
                    for y = 0, 1 do
                        local index = y * 2 + x + 1

                        if entry.q[index] then
                            local provider_pos = top_fb.item_request.provider.position
                            local quad_size = top_fb.depth_size

                            local pos_x = entry.x + quad_size * x
                            local pos_y = entry.y + quad_size * y

                            sort_into_quad_list(top_fb.closest_quads, entry.q[index], quad_size, pos_x, pos_y, util.distance(provider_pos, { pos_x + quad_size / 2, pos_y + quad_size / 2 }))
                        end
                    end
                end

                return sf.continue_and_yield
            end),
            function()
                if top_fb.current_depth <= storage.scheduler.idling_cargo_drones_quadtree[surface_index].depth then
                    top_fb.sequence_step = 6

                    return true, sf.yield -- FIXME: Should not yield. But stack_frame currently don't support changing step without breaking
                end

                -- FIXME: Final search does not need a list
                top_fb.closest_quad = top_fb.closest_quads[1].q
            end,
            function()
                if top_fb.closest_quad == nil then
                    return true, sf.continue_and_yield
                end

                local selected_entry = nil

                for _, entry in pairs(top_fb.closest_quad) do
                    if entry.element.valid then
                        selected_entry = entry

                        break
                    end
                end

                -- FIXME: Drones were invalid, needs to be removed before continuing
                if not selected_entry then
                    top_fb.sequence_step = 4
                    top_fb.closest_quad = nil
                    top_fb.closest_distance = constants.max_distance
                    return true, sf.yield
                end

                drones[selected_entry.element.unit_number] = nil
                remove_from_quadtree_grid(storage.scheduler.idling_cargo_drones_quadtree[surface_index], selected_entry.position, selected_entry.element.unit_number) -- FIXME: Drone may not be valid

                ir.assign_item_request(top_fb.surface_buffer, selected_entry.element, top_fb.item_request)
                dc.interrupt_drone(selected_entry.element)

                top_fb.sequence_step = 2

                return true, sf.yield
            end,
        })
    end)
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

    local entry = nil

    storage.scheduler.key_drone, entry = next(drones, storage.scheduler.key_drone)

    if storage.scheduler.key_drone == nil or not entry.drone.valid then
        return false
    end

    if dt.get_current_drone_task_id(entry.drone) ~= nil then
        return false
    end

    local depots = deh.get_depots(storage.scheduler.key_surface)

    if depots == nil then
        return false
    end

    local highest_priority = -1
    local closest_depot = nil
    local closest_distance = constants.max_distance
    -- If for some reason, all depots have more drones than this, I don't think anyone will notice the imbalance. And if they do, I want them to pay me to fix it.
    -- Because if they can afford to play Factorio on a NASA computer, they can afford to throw cash my way.
    local lowest_drone_count = 10000000

    for _, depot in pairs(depots) do
        if not depot.valid then
            storage.invalid_entity_detected = true

            goto continue
        end

        if not th.is_at_drone_limit(depot) then
            local priority = th.get_priority(depot)

            if priority >= highest_priority then
                local distance = util.distance(entry.drone.position, depot.position)
                local drone_count = th.get_drone_count(depot)

                if priority == highest_priority then
                    if drone_count > lowest_drone_count then
                        goto continue
                    end

                    if drone_count == lowest_drone_count and distance >= closest_distance then
                        goto continue
                    end
                end

                highest_priority = priority
                closest_depot = depot
                closest_distance = distance
                lowest_drone_count = drone_count
            end
        end

        ::continue::
    end

    if not closest_depot then
        return false
    end

    dt.assign_depot(entry.drone, closest_depot)
    dc.interrupt_drone(entry.drone)

    return false
end

local scheduler = {}

function scheduler.init()
    storage.scheduler = storage.scheduler or {}

    storage.scheduler.update_state = storage.scheduler.update_state or 0
    storage.scheduler.last_schedule_tick = storage.scheduler.last_schedule_tick or 0

    storage.scheduler.last_mooring_scan_tick = storage.scheduler.last_mooring_scan_tick or 0
    storage.scheduler.should_perform_mooring_scan = storage.scheduler.should_perform_mooring_scan or false

    storage.scheduler.key_surface = storage.scheduler.key_surface or nil
    storage.scheduler.key_drone = storage.scheduler.key_drone or nil

    storage.scheduler.idling_cargo_drones = storage.scheduler.idling_cargo_drones or {}
    storage.scheduler.idling_cargo_drones_empty = storage.scheduler.idling_cargo_drones_empty or {}
    storage.scheduler.idling_cargo_drones_with_cargo = storage.scheduler.idling_cargo_drones_with_cargo or {}
    storage.scheduler.idling_cargo_drones_quadtree = storage.scheduler.idling_cargo_drones_quadtree or {}

    storage.scheduler.surface_buffer = storage.scheduler.surface_buffer or {}
    storage.scheduler.provider_buffer = storage.scheduler.provider_buffer or {}
    storage.scheduler.requester_buffer = storage.scheduler.requester_buffer or {}

    storage.scheduler.mooring_key = storage.scheduler.mooring_key or nil
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
        for _ = 1, settings.global["cargo-drone-max-assign-depot-tasks"].value do
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
