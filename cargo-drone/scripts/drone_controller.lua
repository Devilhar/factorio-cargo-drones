
local util      = require("util")

local constants = require("constants")
local ep        = require("entity_property")
local th        = require("target_helper")
local mh        = require("mooring_helper")
local dt        = require("drone_tasks")
local rc        = require("requester_cooldown")

local callback_drone_count_changed = function (_surface_index) end

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

local function get_rotation_speed(drone)
    if not drone.burner or not drone.burner.currently_burning then
        return drone.prototype.rotation_speed
    end

    local fuel_prototype = drone.burner.currently_burning.name
    local fuel_quality = drone.burner.currently_burning.quality

    local acc_mult = fuel_prototype.fuel_acceleration_multiplier

    if fuel_quality then
        acc_mult = acc_mult + fuel_prototype.fuel_acceleration_multiplier_quality_bonus * fuel_quality.level

        -- Legendary has the double effect
        if fuel_quality.level == 5 then
            acc_mult = acc_mult + fuel_prototype.fuel_acceleration_multiplier_quality_bonus
        end
    end

    local rotation_speed = drone.prototype.rotation_speed

    -- From testing, it appears that the rotation speed follows this formula:
    -- f(a,b) = 0.25ab + 0.75a
    -- Where a is the rotation_speed, and b is the fuel's acceleration multiplier
    return (0.25 * rotation_speed * acc_mult) + (0.75 * rotation_speed)
end
local function get_top_speed(drone)
    if not drone.burner or not drone.burner.currently_burning then
        return drone.prototype.rotation_speed
    end

    local fuel_prototype = drone.burner.currently_burning.name
    local fuel_quality = drone.burner.currently_burning.quality

    local top_speed_mult = fuel_prototype.fuel_top_speed_multiplier

    if fuel_quality then
        top_speed_mult = top_speed_mult + fuel_prototype.fuel_top_speed_multiplier_quality_bonus * fuel_quality.level

        -- Legendary has the double effect
        if fuel_quality.level == 5 then
            top_speed_mult = top_speed_mult + fuel_prototype.fuel_top_speed_multiplier_quality_bonus
        end
    end

    -- This formula was stolen from https://github.com/yalov/factorio-mods/blob/master/StatsGui-MovementSpeed/control.lua
    local vehicle_weight = drone.prototype.weight
    local friction_force = drone.prototype.friction_force
    local terrain_friction_modifier = drone.prototype.terrain_friction_modifier
    local average_tile_friction_modifier = 1.6 -- Average of tile Friction is a calc of all tiles the bounding box of the vehicle resides over
    local car_friction_modifier = 1
    local sticker_friction_modifier = 1
    local combined_friction = 1 - friction_force *
                            (1 + terrain_friction_modifier * (average_tile_friction_modifier - 1)) *
                            car_friction_modifier * sticker_friction_modifier

    local combined_friction_square = combined_friction * combined_friction

    local vehicle_consumption = drone.prototype.consumption
    local vehicle_consumption_modifier = 1
    local vehicle_effectivity = drone.prototype.effectivity
    local speed_bonus = 1
    local sticker_bonus = 1

    local energy_per_tick = vehicle_consumption * vehicle_consumption_modifier * vehicle_effectivity *
                            top_speed_mult * speed_bonus *
                            sticker_bonus

    local max_energy = energy_per_tick * combined_friction_square / (1 - combined_friction_square)

    local kmph = (max_energy * 2 / vehicle_weight) ^ 0.5 * 3.6
    -- End steal mode

    return (((kmph * 1000) / 60) / 60) / 60
end

local function schedule_next_tick(drone, ticks_delay)
    local next_tick = game.tick + ticks_delay
    local next_random_tick = game.tick - game.tick % constants.random_tick_interval + (drone.unit_number % constants.random_tick_interval)

    if next_random_tick <= game.tick then
        next_random_tick = next_random_tick + constants.random_tick_interval
    end

    if next_tick > next_random_tick then
        next_tick = next_random_tick
    end

    local surface_buffer = storage.drone_controller.surfaces[drone.surface.index]

    local tickrate_buffer = surface_buffer.scheduled_ticks[next_tick]

    if not tickrate_buffer then
        tickrate_buffer = {}

        surface_buffer.scheduled_ticks[next_tick] = tickrate_buffer
    end

    surface_buffer.scheduled_every[drone.unit_number] = nil
    tickrate_buffer[drone.unit_number] = drone
    ep.set_entity_property(drone, "next_tick", next_tick)
end
local function schedule_tick_every(drone)
    local surface_buffer = storage.drone_controller.surfaces[drone.surface.index]
    local next_tick = ep.get_entity_property(drone, "next_tick")

    if next_tick ~= nil then
        local tickrate_buffer = surface_buffer.scheduled_ticks[next_tick]

        if tickrate_buffer then
            tickrate_buffer[drone.unit_number] = nil
        end
    end

    surface_buffer.scheduled_every[drone.unit_number] = drone
    ep.set_entity_property(drone, "next_tick", nil)
end

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

    position_drone.x = position_drone.x + (drone_offset.x or drone_offset[1])
    position_drone.y = position_drone.y + (drone_offset.y or drone_offset[2])
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
        -delta[1] / 2 + (drone_offset.x or drone_offset[1]) / 2 + depot_offset[1] / 2,
        -delta[2] / 2 + (drone_offset.y or drone_offset[2]) / 2 + depot_offset[2] / 2
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

local function move_to_position(drone, drone_position, drone_orientation, drone_speed, state, target_position)
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

    if distance_to_target >= constants.drone_target_minimal_distance or math.abs(orientation_delta) <= min_orientation_delta + quater_64_cardinal then
        if drone_speed < target_speed then
            acceleration = defines.riding.acceleration.accelerating
        elseif distance_to_target < 5 then
            if drone_speed > target_speed + (1 / 60) then
                acceleration = defines.riding.acceleration.braking
            end
        elseif drone_speed > target_speed + (5 / 60) then
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

    local next_tick = 1

    if direction == defines.riding.direction.straight then
        if distance_to_target < constants.drone_target_minimal_distance then
            next_tick = math.min(distance_to_target / drone_speed, 20)
        else
            next_tick = (distance_to_target - constants.drone_target_minimal_distance) / get_top_speed(drone)
        end
    else
        next_tick = math.abs(orientation_delta) / get_rotation_speed(drone)
    end

    state.tickrate = math.max(math.floor(next_tick), 1)

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
            state.tickrate = constants.drones_tickrates.minimal
            state.queuing_mooring = mooring

            return
        else
            state.docking_mooring = mooring
        end
    end

    local drone_orientation = drone.orientation
    local drone_speed = drone.speed

    local completed = move_to_position(drone, drone_position, drone_orientation, drone_speed, state, mooring_position)

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

        if drone.burner then
            if drone.burner.remaining_burning_fuel > 0 or not drone.burner.inventory.is_empty() then
                check_refuel(drone, state)
            end
        end
    end
end
local function perform_task_cargo(drone, state, task, game_tick)
    local inventory = drone.get_inventory(defines.inventory.car_trunk)

    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval then
        if drone.burner and drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
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

    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval and drone.burner then
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
        if drone.burner and drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
            send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
        end
    end

    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.is_full() then
        if not constants.burnt_results_enabled then
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
    if game_tick % constants.random_tick_interval == drone.unit_number % constants.random_tick_interval and drone.burner then
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

    local completed = move_to_position(drone, drone_position, drone_orientation, drone_speed, state, target_position)

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
        surface_buffer = {
            drones = {},
            drone_count = 0,
            scheduled_every = {},
            scheduled_ticks = {},
        }

        storage.drone_controller.surfaces[drone.surface.index] = surface_buffer
    end

    surface_buffer.drones[drone.unit_number] = drone

    surface_buffer.drone_count = table_size(surface_buffer.drones)
    surface_buffer.scheduled_every[drone.unit_number] = drone

    callback_drone_count_changed(drone.surface.index)
end
local function unregister_drone(drone, surface_index)
    local surface_buffer = storage.drone_controller.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    surface_buffer.drones[drone.unit_number] = nil

    surface_buffer.drone_count = table_size(surface_buffer.drones)

    if next(surface_buffer.drones) == nil then
        storage.drone_controller.surfaces[surface_index] = nil
    else
        local next_tick = ep.get_entity_property(drone, "next_tick")

        if next_tick == nil then
            surface_buffer.scheduled_every[drone.unit_number] = nil
        else
            local tick_buffer = surface_buffer.scheduled_ticks[next_tick]

            if tick_buffer then
                tick_buffer[drone.unit_number] = nil
            end
        end
    end

    callback_drone_count_changed(surface_index)
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

            local task_ids = dt.get_entity_task_ids(old_docking_mooring)

            if task_ids then
                for task_id, _ in pairs(task_ids) do
                    local task = dt.get(task_id)

                    local next_queuing_mooring = ep.get_entity_property_from_unit_number(task.drone_unit_number, "queuing_mooring")

                    if next_queuing_mooring and next_queuing_mooring.unit_number == old_docking_mooring.unit_number then
                        local next_drone = ep.get_managed_entity(task.drone_unit_number)

                        schedule_tick_every(next_drone)

                        break
                    end
                end
            end
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
            local drone_prototype_data = prototypes.mod_data["cargo-drone-prototypes"].data[drone.name]

            local offset, x_scale, y_scale, orientation = calculate_depot_cable_render_params(drone, state.parked_depot, drone_prototype_data.cable.attachment_offset, false)

            cable_renderer = rendering.draw_sprite{
                sprite = "cargo-drone-depot-cable",
                target = { entity = drone, offset = offset },
                surface = drone.surface,
                render_layer = "wires",
                x_scale = x_scale,
                y_scale = y_scale,
                orientation = orientation
            }

            offset, x_scale, y_scale, orientation = calculate_depot_cable_render_params(drone, state.parked_depot, drone_prototype_data.cable.attachment_shadow_offset, true)

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

function drone_controller.set_on_drone_count_changed(on_drone_count_changed)
    callback_drone_count_changed = on_drone_count_changed
end

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

local tick_change_buffer = {}
local tick_change_buffer_size = 0

function drone_controller.tick(game_tick)
    -- Declaring variables early *appears* to have a minor performance benefit.
    local tick_delay = nil
    local expected_buffer_size = 0
    local tick_change_count = 0
    local tick_change_data = nil

    for _, surface_buffer in pairs(storage.drone_controller.surfaces) do
        expected_buffer_size = tick_change_count + surface_buffer.drone_count

        if tick_change_buffer_size < expected_buffer_size then
            for i = tick_change_buffer_size + 1, expected_buffer_size do
                tick_change_buffer[i] = {}
            end

            tick_change_buffer_size = table_size(tick_change_buffer)
        end

        for _, drone in pairs(surface_buffer.scheduled_every) do
            tick_delay = tick_drone(drone, game_tick)

            if tick_delay ~= 1 then
                tick_change_count = tick_change_count + 1

                tick_change_data = tick_change_buffer[tick_change_count]

                tick_change_data[1] = tick_delay
                tick_change_data[2] = drone
            end
        end

        local tick_buffer = surface_buffer.scheduled_ticks[game_tick]

        if tick_buffer then
            for _, drone in pairs(tick_buffer) do
                tick_delay = tick_drone(drone, game_tick)

                tick_change_count = tick_change_count + 1

                tick_change_data = tick_change_buffer[tick_change_count]

                tick_change_data[1] = tick_delay
                tick_change_data[2] = drone
            end
        end

        surface_buffer.scheduled_ticks[game_tick] = nil
    end

    local drone = nil

    for i = 1, tick_change_count do
        tick_change_data = tick_change_buffer[i]

        tick_delay = tick_change_data[1]
        drone = tick_change_data[2]

        if tick_delay == 1 then
            schedule_tick_every(drone)
        else
            schedule_next_tick(drone, tick_delay)
        end
    end
end

function drone_controller.interrupt_drone(drone)
    schedule_tick_every(drone)
end

function drone_controller.drone_count(surface_index)
    local surface_buffer = storage.drone_controller.surfaces[surface_index]

    if not surface_buffer then
        return 0
    end

    return surface_buffer.drone_count
end

return drone_controller
