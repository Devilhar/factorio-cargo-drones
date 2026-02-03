
local util  = require("util")

local ep    = require("scripts.entity_property")
local mh    = require("scripts.mooring_helper")
local dt    = require("scripts.drone_tasks")
local ir	= require("scripts.item_requests")
local rc    = require("scripts.requester_cooldown")

local drone_queue_distance = 20
local random_tick_interval = 60
local min_task_assign_interval = 60

local update_state = 0
local last_assign_tick = 0

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

local function move_to_position(car_entity, state, target_position)
    local distance_to_target = util.distance(car_entity.position, target_position)

    if distance_to_target < 1 then
        if car_entity.speed == 0 then
            state.riding_state = { acceleration = defines.riding.acceleration.nothing, direction = defines.riding.direction.straight }

            return true
        end

        state.riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight }

        return false
    end

    local function orientation_closest_64_cardinal(orientation)
        return math.floor(orientation * 64 + 0.5) / 64
    end

    local target_speed = distance_to_target / 60 / 2
    local target_orientation = orientation_from_to(car_entity.position, target_position)

    target_orientation = orientation_closest_64_cardinal(target_orientation)

    local direction = defines.riding.direction.straight
    local acceleration = defines.riding.acceleration.nothing

    local orientation_delta = orientation_delta_from_to(car_entity.orientation, target_orientation)
    local min_orientation_delta = math.max(math.min(distance_to_target / 2000 , 0.05), 0.01)

    min_orientation_delta = orientation_closest_64_cardinal(min_orientation_delta)
    local quater_64_cardinal = 1 / 256

    if distance_to_target >= 100 or math.abs(orientation_delta) <= min_orientation_delta + quater_64_cardinal then
        if car_entity.speed < target_speed then
            acceleration = defines.riding.acceleration.accelerating
        elseif car_entity.speed > target_speed + (1 / 60) then
            acceleration = defines.riding.acceleration.braking
        end
    end

    if orientation_delta < -min_orientation_delta then
        direction = defines.riding.direction.left
    elseif orientation_delta > min_orientation_delta then
        direction = defines.riding.direction.right
    elseif car_entity.speed == 0 and acceleration == defines.riding.acceleration.accelerating then
        -- For some reason the drone can't accelerate without ever turning. So just turn for a frame if standing still
        direction = defines.riding.direction.left
    end

    state.riding_state = { acceleration = acceleration, direction = direction }

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
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for id, data in pairs(mooring_table) do
        if entity.surface.index == data.entity.surface.index and not dt.is_at_target_limit(data.entity) then
            local priority = mh.get_priority(data.entity)

            if highest_priority <= priority then
                local distance = util.distance(entity.position, data.entity.position)

                if highest_priority < priority or distance < closest_distance then
                    highest_priority = priority
                    closest_entity = data.entity
                    closest_distance = distance
                end
            end
        end
    end

    return closest_entity
end

local function get_closest_drone_to_mooring(drones, mooring)
    local closest_index = nil
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for i, drone in ipairs(drones) do
		local distance = util.distance(drone.position, mooring.position)

		if distance < closest_distance then
			closest_index = i
			closest_distance = distance
		end
    end

    return closest_index
end

local function complete_task(drone, task_id)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return
    end

    dt.destroy(task_id)
end

local function check_refuel(drone)
    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.count_empty_stacks() == 0 then
        return false
    end

    local refueler = get_closest_valid_refueler(ep.get_cargo_drone_refuel_moorings(), drone)

    if not refueler then
        return false
    end

    dt.assign_refuel(drone, refueler)

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

local function drone_goto_and_dock_with_mooring(drone, state, mooring, inventory)
    if util.distance(drone.position, mooring.position) <= drone_queue_distance then
        local docking_drone = ep.get_entity_property(mooring, "docking_drone")

        if docking_drone and docking_drone.valid and docking_drone ~= drone then
            return
        else
            state.docking_mooring = mooring
        end
    end

    local completed = move_to_position(drone, state, mooring.position)

    if not completed then
        return
    end

    state.docked_mooring.target_entity = mooring
    state.docked_mooring.inventory = inventory
end

local function perform_task_none(drone, state, game_tick)
    if game_tick % random_tick_interval == drone.unit_number % random_tick_interval then
        local inventory = drone.get_inventory(defines.inventory.car_trunk)

        for i = 1, #inventory do
            inventory.set_filter(i, nil)
        end

        if not inventory.is_empty() then
            send_alert(drone, "signal-lock", "cargo-drone-alerts.invalid-items")
        end

        if drone.burner.remaining_burning_fuel > 0 or not drone.burner.inventory.is_empty() then
            check_refuel(drone)
        end
    end
end
local function perform_task_cargo(drone, state, task, game_tick)
    local inventory = drone.get_inventory(defines.inventory.car_trunk)

    if game_tick % random_tick_interval == drone.unit_number % random_tick_interval then
        if drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
            send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
        end

        local inventory = drone.get_inventory(defines.inventory.car_trunk)

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

    if game_tick % random_tick_interval == drone.unit_number % random_tick_interval then
        if check_refuel(drone) then
            return false
        end
    end

    local mooring_target = nil

    if task.provider_unit_number ~= nil then
        mooring_target = ep.get_managed_entity(task.provider_unit_number)
    else
        mooring_target = ep.get_managed_entity(task.requester_unit_number)
    end

    drone_goto_and_dock_with_mooring(drone, state, mooring_target, defines.inventory.car_trunk)

    return false
end
local function perform_task_refuel(drone, state, task, game_tick)
    if game_tick % random_tick_interval == drone.unit_number % random_tick_interval then
        if drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
            send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
        end
    end

    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.is_full() then
        return true
    end

    local refueler = ep.get_managed_entity(task.refueler_unit_number)

    drone_goto_and_dock_with_mooring(drone, state, refueler, defines.inventory.fuel)

    return false
end

local function get_current_task(drone)
    local current_task_id = dt.get_current_drone_task_id(drone)

    if not current_task_id then
        return nil
    end

    return dt.get(current_task_id)
end

local state = {
    riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight },
    docked_mooring = { target_entity = nil, inventory = nil },
    docking_mooring = nil
}

local function tick_drone(drone, game_tick)
    local current_task = get_current_task(drone)
    state.riding_state.acceleration = defines.riding.acceleration.braking
    state.riding_state.direction = defines.riding.direction.straight
    state.docked_mooring.target_entity = nil
    state.docked_mooring.inventory = nil
    state.docking_mooring = nil

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
    end

    drone.riding_state = state.riding_state

    local old_docked_mooring = ep.get_entity_property(drone, "docked_mooring")
    local old_docking_mooring = ep.get_entity_property(drone, "docking_mooring")

    if old_docked_mooring and old_docked_mooring ~= state.docked_mooring.target_entity then
        if old_docked_mooring.valid and old_docked_mooring.proxy_target_entity == drone then
            old_docked_mooring.proxy_target_entity = nil
        end

        ep.set_entity_property(drone, "docked_mooring", nil)
    end

    if state.docked_mooring.target_entity then
        state.docked_mooring.target_entity.proxy_target_entity = drone
        state.docked_mooring.target_entity.proxy_target_inventory = state.docked_mooring.inventory
        ep.set_entity_property(drone, "docked_mooring", state.docked_mooring.target_entity)
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
end

local drone_controller = {}

function drone_controller.tick(game_tick)
    if update_state == 0 then
        update_state = 1
        ir.begin_update()
    end

    if update_state == 1 then
        if ir.run_update() then
            update_state = 2
        end
    end

    if update_state == 2 and game_tick >= last_assign_tick + min_task_assign_interval then
        local idling_cargo_drones = {}
        local idling_cargo_drones_with_cargo = {}
        
        for surface_index, drones in pairs(dt.get_idle_drones_per_surface()) do
            for unit_number, drone in pairs(drones) do
                local inventory = drone.get_inventory(defines.inventory.car_trunk)

                if inventory.is_empty() then
                    if not idling_cargo_drones[surface_index] then
                        idling_cargo_drones[surface_index] = {}
                    end

                    table.insert(idling_cargo_drones[surface_index], drone)
                else
                    if not idling_cargo_drones_with_cargo[surface_index] then
                        idling_cargo_drones_with_cargo[surface_index] = {}
                    end

                    table.insert(idling_cargo_drones_with_cargo[surface_index], drone)
                end
            end
        end

        for _, drones in pairs(idling_cargo_drones_with_cargo) do
            for _, drone in ipairs(drones) do
                ir.assign_to_request_with_items(drone)
            end
        end

        for surface_index, drones in pairs(idling_cargo_drones) do
            while next(drones) ~= nil do
                local item_request = ir.get_next_item_request(surface_index)

                if not item_request then
                    break
                end

                local closest_index = get_closest_drone_to_mooring(drones, item_request.provider)

                if closest_index ~= nil then
                    local drone = drones[closest_index]

                    table.remove(drones, closest_index)

                    ir.assign_item_request(drone, item_request)
                end
            end
        end

        last_assign_tick = game_tick
        update_state = 0
    end

    for unit_number, entity_data in pairs(ep.get_cargo_drones()) do
        tick_drone(entity_data.entity, game_tick)
    end
end

return drone_controller
