
local util      = require("util")

local constants = require("constants")
local ep        = require("entity_property")
local th        = require("target_helper")
local mh        = require("mooring_helper")
local dt        = require("drone_tasks")
local rc        = require("requester_cooldown")

-- Shamelessly stolen from AAI Programmable Vehicles, because I couldn't be bothered doing it myself
-- Begin steal mode
local function vector_to_orientation_xy(x, y)
    if x == 0 then
        if y > 0 then
            return 0.5
        end

        return 0
    end

    if y == 0 then
        if x < 0 then
            return 0.75
        end

        return 0.25
    end

    if y < 0 then
        if x > 0 then
            return math.atan(x / -y) / math.pi / 2
        end

        return 1 + math.atan(x / -y) / math.pi / 2
    end

    return 0.5 + math.atan(x / -y) / math.pi / 2
end
local function orientation_from_to(a, b)
    return vector_to_orientation_xy(b.x - a.x, b.y - a.y)
end
local function orientation_delta_from_to(a, b)
    local da = b - a

	if da < -0.5 then
        da = da + 1
    elseif da > 0.5 then
        da = da - 1
    end

    return da
end
-- End steal mode

local function get_closest_depot_attachment_offset(delta)
    local closest_offset = { 0, 0 }
    local closest_distance = 100
    local closest_height = 0

    for i, offset in pairs(constants.depot_cable_attachment_offsets) do
        local distance = util.distance(delta, offset)

        if distance < closest_distance then
            closest_offset = offset
            closest_distance = distance
            closest_height = constants.depot_cable_attachment_heights[i]
        end
    end

    return closest_offset, closest_height
end

local function calculate_depot_cable_render_params(drone, depot, drone_offset, is_shadow)
    local position_drone = drone.position
    local position_depot = depot.position

    local delta = { position_drone.x - position_depot.x, position_drone.y - position_depot.y }

    local depot_offset, depot_offset_height = get_closest_depot_attachment_offset(delta)

    local should_flip = is_shadow and position_drone.y < position_depot.y

    position_drone.x = position_drone.x + drone_offset.x
    position_drone.y = position_drone.y + drone_offset.y
    position_depot.x = position_depot.x + depot_offset[1]
    position_depot.y = position_depot.y + depot_offset[2]

    if not is_shadow then
        position_depot.y = position_depot.y - depot_offset_height
    else
        position_depot.x = position_depot.x + depot_offset_height
    end

    local distance = util.distance(position_drone, position_depot)
    local delta_offset = { position_drone.x - position_depot.x, position_drone.y - position_depot.y }

    local orientation = vector_to_orientation_xy(delta_offset[1], delta_offset[2])

    local offset = {
        -delta[1] / 2 + drone_offset.x / 2 + depot_offset[1] / 2,
        -delta[2] / 2 + drone_offset.y / 2 + depot_offset[2] / 2
    }

    local cable_sprite_half_height = constants.depot_cable_sprite_size[2] / 2

    if orientation < 0.5 then
        orientation = orientation + 0.25
    else
        orientation = orientation - 0.25
    end

    orientation = orientation % 1

    local tau = math.pi * 2

    local rad = orientation * tau

    local x_scale = -distance / constants.depot_cable_sprite_size[1]

    local y_scale = -math.max(math.min(1, math.abs(x_scale)), 0.75)

    if is_shadow then
        x_scale = -x_scale
    end

    if should_flip then
        offset[1] = offset[1] - math.sin(rad) * cable_sprite_half_height * math.abs(y_scale)
        offset[2] = offset[2] + math.cos(rad) * cable_sprite_half_height * math.abs(y_scale)

        y_scale = -y_scale
    else
        offset[1] = offset[1] + math.sin(rad) * cable_sprite_half_height * math.abs(y_scale)
        offset[2] = offset[2] - math.cos(rad) * cable_sprite_half_height * math.abs(y_scale)
    end

    return offset, x_scale, y_scale, orientation
end

local function move_to_position(drone_position, drone_orientation, drone_speed, state, target_position)
    local distance_to_target = util.distance(drone_position, target_position)

    if distance_to_target < 1 then
        if drone_speed == 0 or distance_to_target < 0.2 then
            state.riding_state = { acceleration = defines.riding.acceleration.nothing, direction = defines.riding.direction.straight }

            return true
        end

        state.riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight }

        return false
    end

    local function orientation_closest_64_cardinal(orientation)
        return math.floor(orientation * 64 + 0.5) / 64
    end

    local target_speed = distance_to_target / 60 / 2.5
    local target_orientation = orientation_from_to(drone_position, target_position)

    target_orientation = orientation_closest_64_cardinal(target_orientation)

    local direction = defines.riding.direction.straight
    local acceleration = defines.riding.acceleration.nothing

    local orientation_delta = orientation_delta_from_to(drone_orientation, target_orientation)
    local min_orientation_delta = math.max(math.min(distance_to_target / 2000 , 0.05), 0.01)

    min_orientation_delta = orientation_closest_64_cardinal(min_orientation_delta)
    local quater_64_cardinal = 1 / 256

    if distance_to_target >= 100 or math.abs(orientation_delta) <= min_orientation_delta + quater_64_cardinal then
        if drone_speed < target_speed then
            acceleration = defines.riding.acceleration.accelerating
        elseif drone_speed > target_speed + (1 / 60) then
            acceleration = defines.riding.acceleration.braking
        end
    end

    if orientation_delta < -min_orientation_delta then
        direction = defines.riding.direction.left
    elseif orientation_delta > min_orientation_delta then
        direction = defines.riding.direction.right
    elseif drone_speed == 0 and acceleration == defines.riding.acceleration.accelerating then
        -- For some reason the drone can't accelerate without ever turning. So just turn for a frame if standing still
        direction = defines.riding.direction.left
    end

    state.riding_state = { acceleration = acceleration, direction = direction }

    if direction == defines.riding.direction.straight then
        if distance_to_target >= 50 then
            state.tickrate = constants.drones_tickrates.reduced
        elseif distance_to_target >= 200 then
            state.tickrate = constants.drones_tickrates.minimal
        end
    elseif math.abs(orientation_delta) > 0.1 then
        state.tickrate = constants.drones_tickrates.reduced
    end

    return false
end

local function send_alert(drone, name, loc_id)
    for i = 1, #game.players do
        game.players[i].add_custom_alert(drone, { type = "virtual", name = name }, { loc_id }, true)
    end
end

local function get_closest_valid_refueler(mooring_table, entity)
    local highest_priority = -1
    local closest_entity = nil
    local closest_distance = constants.max_distance

    for _, refueler in pairs(mooring_table) do
        if not th.is_at_drone_limit(refueler) then
            local priority = th.get_priority(refueler)

            if highest_priority <= priority then
                local distance = util.distance(entity.position, refueler.position)

                if highest_priority < priority or distance < closest_distance then
                    highest_priority = priority
                    closest_entity = refueler
                    closest_distance = distance
                end
            end
        end
    end

    return closest_entity
end

local function complete_task(drone, task_id)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return
    end

    dt.destroy(task_id)
end

local function check_refuel(drone, state)
    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    local fuel_inventory_size = #fuel_inventory

    local fuel_level = 0

    for i = 1, fuel_inventory_size do
        local stack = fuel_inventory[i]

        if stack.valid_for_read then
            fuel_level = fuel_level + stack.count / stack.prototype.stack_size
        end
    end

    if fuel_level > fuel_inventory_size * (settings.global["cargo-drone-fuel-interrupt-percentage"].value / 100) then
        return false
    end

    local mooring_surface_buffer = storage.mooring_controller.surfaces[drone.surface.index]

    if not mooring_surface_buffer then
        return false
    end

    local refueler = get_closest_valid_refueler(mooring_surface_buffer[mh.mooring_types.refueler], drone)

    if not refueler then
        return false
    end

    dt.assign_refuel(drone, refueler)
    state.tickrate = constants.drones_tickrates.every

    return true
end

local function has_requested_items(inventory, requested_items)
    local inventory_item_lookup = {}

    for i, item in pairs(inventory.get_contents()) do
        if not inventory_item_lookup[item.name] then
            inventory_item_lookup[item.name] = {}
        end

        inventory_item_lookup[item.name][item.quality] = item.count
    end

    for _, item in ipairs(requested_items) do
        if not inventory_item_lookup[item.name]
            or not inventory_item_lookup[item.name][item.quality]
            or inventory_item_lookup[item.name][item.quality] < item.count then
            return false
        end
    end

    return true
end

local function drone_goto_and_dock_with_mooring(drone, state, mooring)
    local drone_position = drone.position
    local mooring_position = mooring.position

    if util.distance(drone_position, mooring_position) <= constants.drone_queue_distance then
        local docking_drone = ep.get_entity_property(mooring, "docking_drone")

        if docking_drone and docking_drone.valid and docking_drone ~= drone then
            state.tickrate = constants.drones_tickrates.reduced
            state.queuing_mooring = mooring

            return
        else
            state.docking_mooring = mooring
        end
    end

    local drone_orientation = drone.orientation
    local drone_speed = drone.speed

    local completed = move_to_position(drone_position, drone_orientation, drone_speed, state, mooring_position)

    if not completed then
        return
    end

    drone.speed = 0
    state.docked_mooring = mooring
end

local function perform_task_none(drone, state, game_tick)
    state.tickrate = constants.drones_tickrates.minimal

    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        local inventory = drone.get_inventory(defines.inventory.car_trunk)

        for i = 1, #inventory do
            inventory.set_filter(i, nil)
        end

        if not inventory.is_empty() then
            send_alert(drone, "signal-lock", "cargo-drone-alerts.invalid-items")
        end

        if drone.burner.remaining_burning_fuel > 0 or not drone.burner.inventory.is_empty() then
            check_refuel(drone, state)
        end
    end
end
local function perform_task_cargo(drone, state, task, game_tick)
    local inventory = drone.get_inventory(defines.inventory.car_trunk)

    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        if drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
            send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
        end

        for slot_index = 1, #inventory do
            local filter = task.inventory_filters[slot_index]

            if filter ~= nil then
                inventory.set_filter(slot_index, filter)
            else
                inventory.set_filter(slot_index, { name = "red-wire", quality = "normal" })
            end
        end
    end

    if task.provider_unit_number ~= nil then
        if has_requested_items(inventory, task.items) then
            dt.cargo_unassign_provider(task.id)
        end
    elseif inventory.is_empty() then
        rc.flag_for_cooldown(task.requester_unit_number)

        return true
    end

    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        if check_refuel(drone, state) then
            return false
        end
    end

    local mooring_target = nil

    if task.provider_unit_number ~= nil then
        mooring_target = ep.get_managed_entity(task.provider_unit_number)
    else
        mooring_target = ep.get_managed_entity(task.requester_unit_number)
    end

    drone_goto_and_dock_with_mooring(drone, state, mooring_target)

    return false
end
local function perform_task_refuel(drone, state, task, game_tick)
    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        if drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
            send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
        end
    end

    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.is_full() then
        if not constants.drone_has_burnt_result then
            return true
        end

        local burnt_result_inventory = drone.get_inventory(defines.inventory.burnt_result)

        if burnt_result_inventory.is_empty() then
            return true
        end
    end

    local refueler = ep.get_managed_entity(task.refueler_unit_number)

    drone_goto_and_dock_with_mooring(drone, state, refueler)

    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        local docked_game_tick = ep.get_entity_property(drone, "docked_game_tick")

        if docked_game_tick ~= nil then
            local timeout = settings.global["cargo-drone-stuck-at-refueler-seconds-alert"].value * 60

            if timeout ~= 0 and docked_game_tick + timeout < game_tick then
                send_alert(drone, "signal-alert", "cargo-drone-alerts.stuck-at-refueler")
            end
        end
    end

    return false
end
local function perform_task_depot(drone, state, task, game_tick)
    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        local inventory = drone.get_inventory(defines.inventory.car_trunk)

        for i = 1, #inventory do
            inventory.set_filter(i, nil)
        end

        check_refuel(drone, state)
    end

    local mooring = ep.get_managed_entity(task.depot_unit_number)

    local drone_position = drone.position
    local mooring_position = mooring.position

    local offset_orientation = ((drone.unit_number * 281) % 100) / 200
    local offset_distance = ((drone.unit_number * 13) % 100) / (100 / 8) + 7

    if offset_orientation >= 0.375 then
        offset_orientation = offset_orientation + 0.4375
    elseif offset_orientation >= 0.25 then
        offset_orientation = offset_orientation + 0.3125
    elseif offset_orientation >= 0.125 then
        offset_orientation = offset_orientation + 0.1875
    else
        offset_orientation = offset_orientation + 0.0625
    end

    local offset = util.rotate_position({ offset_distance, 0 }, offset_orientation)

    local target_position = { x = mooring_position.x + offset.x, y = mooring_position.y + offset.y }

    if util.distance(drone_position, target_position) < 1 then
        state.parked_depot = mooring
        state.tickrate = constants.drones_tickrates.minimal
        drone.speed = 0

        return false
    end

    local drone_orientation = drone.orientation
    local drone_speed = drone.speed

    local completed = move_to_position(drone_position, drone_orientation, drone_speed, state, target_position)

    if completed then
        state.tickrate = constants.drones_tickrates.minimal
    end

    return false
end

local function get_current_task(drone)
    local current_task_id = dt.get_current_drone_task_id(drone)

    if not current_task_id then
        return nil
    end

    return dt.get(current_task_id)
end

local function register_drone(drone)
    local surface_buffer = storage.drone_controller.surfaces[drone.surface.index]

    if not surface_buffer then
        surface_buffer = {}

        storage.drone_controller.surfaces[drone.surface.index] = surface_buffer
    end

    surface_buffer[drone.unit_number] = drone
end
local function unregister_drone(drone, surface_index)
    local surface_buffer = storage.drone_controller.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    surface_buffer[drone.unit_number] = nil

    if next(surface_buffer) == nil then
        storage.drone_controller.surfaces[surface_index] = nil
    end
end

local state = {
    tickrate = constants.drones_tickrates.every,
    riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight },
    docked_mooring = nil,
    docking_mooring = nil,
    queuing_mooring = nil,
    parked_depot = nil,
}

local function tick_drone(drone, game_tick)
    local current_task = get_current_task(drone)
    state.tickrate = constants.drones_tickrates.every
    state.riding_state.acceleration = defines.riding.acceleration.braking
    state.riding_state.direction = defines.riding.direction.straight
    state.docked_mooring = nil
    state.docking_mooring = nil
    state.queuing_mooring = nil
    state.parked_depot = nil

    if not current_task then
        perform_task_none(drone, state, game_tick)
    elseif current_task.type == dt.task_types.cargo then
        local completed = perform_task_cargo(drone, state, current_task, game_tick)

        if completed then
            complete_task(drone, current_task.id)
        end
    elseif current_task.type == dt.task_types.refuel then
        local completed = perform_task_refuel(drone, state, current_task, game_tick)

        if completed then
            complete_task(drone, current_task.id)
        end
    elseif current_task.type == dt.task_types.depot then
        perform_task_depot(drone, state, current_task, game_tick)
    end

    drone.riding_state = state.riding_state

    local old_docked_mooring = ep.get_entity_property(drone, "docked_mooring")
    local old_docking_mooring = ep.get_entity_property(drone, "docking_mooring")

    if old_docked_mooring and old_docked_mooring ~= state.docked_mooring then
        if old_docked_mooring.valid then
            local proxy_containers = ep.get_entity_property(old_docked_mooring, "proxy_containers")

            for _, proxy_container in ipairs(proxy_containers) do
                if proxy_container.proxy_target_entity == drone then
                    proxy_container.proxy_target_entity = nil
                end
            end

            mh.set_docked_drone(old_docked_mooring, nil)
            mh.unset_request_reader(old_docked_mooring)
        end

        ep.set_entity_property(drone, "docked_mooring", nil)
        ep.set_entity_property(drone, "docked_game_tick", nil)
    end

    if state.docked_mooring and state.docked_mooring ~= old_docked_mooring then
        local proxy_containers = ep.get_entity_property(state.docked_mooring, "proxy_containers")
        drone.surface.play_sound({ path = "cargo-drone-sound-docking", position = drone.position })

        for _, proxy_container in ipairs(proxy_containers) do
            proxy_container.proxy_target_entity = drone
        end
        ep.set_entity_property(drone, "docked_mooring", state.docked_mooring)
        ep.set_entity_property(drone, "docked_game_tick", game_tick)
        mh.set_docked_drone(state.docked_mooring, drone)

        if mh.get_read_requests(state.docked_mooring) then
            mh.set_request_reader(state.docked_mooring, drone)
        end
    end

    if old_docking_mooring and old_docking_mooring ~= state.docking_mooring then
        if old_docking_mooring.valid and ep.get_entity_property(old_docking_mooring, "docking_drone") == drone then
            ep.set_entity_property(old_docking_mooring, "docking_drone", nil)
        end

        ep.set_entity_property(drone, "docking_mooring", nil)
    end

    if state.docking_mooring then
        ep.set_entity_property(drone, "docking_mooring", state.docking_mooring)
        ep.set_entity_property(state.docking_mooring, "docking_drone", drone)
    end

    local old_parked_depot = ep.get_entity_property(drone, "parked_depot")

    if old_parked_depot ~= state.parked_depot then
        local cable_renderer = ep.get_entity_property(drone, "cable_renderer")
        local cable_shadow_renderer = ep.get_entity_property(drone, "cable_shadow_renderer")

        if cable_renderer and cable_renderer.valid then
            cable_renderer.destroy()

            cable_renderer = nil
        end
        if cable_shadow_renderer and cable_shadow_renderer.valid then
            cable_shadow_renderer.destroy()

            cable_shadow_renderer = nil
        end

        if state.parked_depot then
            local offset, x_scale, y_scale, orientation = calculate_depot_cable_render_params(drone, state.parked_depot, constants.drone_sprite_offset, false)

            cable_renderer = rendering.draw_sprite{
                sprite = "cargo-drone-depot-cable",
                target = { entity = drone, offset = offset },
                surface = drone.surface,
                render_layer = "wires",
                x_scale = x_scale,
                y_scale = y_scale,
                orientation = orientation
            }

            offset, x_scale, y_scale, orientation = calculate_depot_cable_render_params(drone, state.parked_depot, constants.drone_sprite_shadow_offset, true)

            cable_shadow_renderer = rendering.draw_sprite{
                sprite = "cargo-drone-depot-cable-shadow",
                target = { entity = drone, offset = offset },
                surface = drone.surface,
                x_scale = x_scale,
                y_scale = y_scale,
                orientation = orientation
            }
        end

        ep.set_entity_property(drone, "cable_renderer", cable_renderer)
        ep.set_entity_property(drone, "cable_shadow_renderer", cable_shadow_renderer)
        ep.set_entity_property(drone, "parked_depot", state.parked_depot)
    end

    ep.set_entity_property(drone, "queuing_mooring", state.queuing_mooring)

    return state.tickrate
end

local drone_controller = {}

function drone_controller.init()
    storage.drone_controller = storage.drone_controller or {}

    storage.drone_controller.surfaces = storage.drone_controller.surfaces or {}
end

function drone_controller.surface_deleted(surface_index)
    storage.drone_controller.surfaces[surface_index] = nil
end
function drone_controller.surface_cleared(surface_index)
    storage.drone_controller.surfaces[surface_index] = nil
end

function drone_controller.created(drone)
    register_drone(drone)
end
function drone_controller.destroyed(drone)
    local old_docked_mooring = ep.get_entity_property(drone, "docked_mooring")

    if old_docked_mooring and old_docked_mooring.valid then
        local proxy_containers = ep.get_entity_property(old_docked_mooring, "proxy_containers")

        for _, proxy_container in ipairs(proxy_containers) do
            proxy_container.proxy_target_entity = nil
        end

        mh.set_docked_drone(old_docked_mooring, nil)
    end

    unregister_drone(drone, drone.surface.index)
end

function drone_controller.surface_change(drone, old_surface_index)
    unregister_drone(drone, old_surface_index)

    register_drone(drone)
end

function drone_controller.tick(game_tick)
    local tickrate_drone = 0
    local tickrate_new = 0

    for _, drones in pairs(storage.drone_controller.surfaces) do
        for unit_number, drone in pairs(drones) do
            tickrate_drone = ep.get_entity_property(drone, "tickrate") or constants.drones_tickrates.every

            if unit_number % tickrate_drone == game_tick % tickrate_drone then
                tickrate_new = tick_drone(drone, game_tick)

                if tickrate_new ~= tickrate_drone then
                    ep.set_entity_property(drone, "tickrate", tickrate_new)
                end
            end
        end
    end
end

return drone_controller
