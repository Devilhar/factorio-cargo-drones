
local util  = require("util")

local ep    = require("scripts.entity_property")
local dt    = require("scripts.drone_tasks")

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

local function get_closest_to_entity(entity_table, entity)
    local closest_entity = nil
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for id, data in pairs(entity_table) do
        if entity.surface.index == data.entity.surface.index then
            local distance = util.distance(entity.position, data.entity.position)

            if distance < closest_distance then
                closest_entity = data.entity
                closest_distance = distance
            end
        end
    end

    return closest_entity
end

local function get_mutable_task_ids(drone)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    return properties.task_ids
end
local function get_immutable_task_ids(drone)
    return ep.get_entity_properties(drone).task_ids or {}
end

local function complete_task(drone, task_id)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return
    end

    dt.destroy(task_id)

    for i = 1, #properties.task_ids do
        if properties.task_ids[i] == task_id then
            table.remove(properties.task_ids, i)

            break
        end
    end
end

local function check_refuel(drone)
    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.count_empty_stacks() == 0 then
        return false
    end

    local refueler = get_closest_to_entity(ep.get_cargo_drone_refuel_moorings(), drone)

    if not refueler then
        return false
    end

    local refuel_task = dt.assign_refuel(drone, refueler)

    return true
end

local function drone_goto_and_dock_with_mooring(drone, state, mooring, inventory)
    local completed = move_to_position(drone, state, mooring.position)

    if not completed then
        return
    end

    state.mooring = mooring
    mooring.proxy_target_entity = drone
    mooring.proxy_target_inventory = inventory
end

local function perform_task_none(drone, state, game_tick)
    if check_refuel(drone) then
        return
    end

end
local function perform_task_cargo(drone, state, task, game_tick)
    --[[
    if drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
        send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
    end
    ]]--

    if check_refuel(drone) then
        return false
    end

    return false
end
local function perform_task_refuel(drone, state, task, game_tick)
    --[[
    if drone.burner.remaining_burning_fuel <= 0 and drone.burner.inventory.is_empty() then
        send_alert(drone, "signal-fuel", "cargo-drone-alerts.no-fuel")
    end
    ]]--

    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.is_full() then
        return true
    end

    if not task.refueler.valid then
        return true
    end

    drone_goto_and_dock_with_mooring(drone, state, task.refueler, defines.inventory.fuel)

    return false
end

local state_machine = {
    [dt.task_types.cargo]    = perform_task_cargo,
    [dt.task_types.refuel]   = perform_task_refuel
}

local function get_current_task(drone)
    local task_ids = get_immutable_task_ids(drone)

    if not task_ids[1] then
        return nil
    end

    return dt.get(task_ids[1])
end

local drone_controller = {}

function drone_controller.tick(drone, game_tick)
    local current_task = get_current_task(drone)
    local state = {
        riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight },
        docked_mooring = { target_entity = nil, inventory = nil }
    }

    if not current_task then
        perform_task_none(drone, state, game_tick)
    else
        local completed = state_machine[current_task.type](drone, state, current_task, game_tick)

        if completed then
            complete_task(drone, current_task.id)
        end
    end

    local previous_mooring = ep.get_entity_property(drone, "docked_mooring") or {}

    drone.riding_state = state.riding_state

    if previous_mooring.target_entity then
        if previous_mooring.target_entity ~= state.docked_mooring.target_entity
            or previous_mooring.inventory ~= state.docked_mooring.inventory then
            previous_mooring.target_entity.proxy_target_entity = nil
        end
    end

    if state.docked_mooring.target_entity then
        state.docked_mooring.target_entity.proxy_target_entity = drone
        state.docked_mooring.target_entity.proxy_target_inventory = state.docked_mooring.inventory
        ep.set_entity_property(drone, "docked_mooring", state.docked_mooring)
    else
        ep.set_entity_property(drone, "docked_mooring", nil)
    end
end

function drone_controller.destroy(drone)
    -- FIXME: Cleanup tasks
end

return drone_controller
