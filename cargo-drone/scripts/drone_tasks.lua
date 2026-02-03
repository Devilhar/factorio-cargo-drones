
local ep    = require("scripts.entity_property")

local task_types = {
    cargo   = 1,
    refuel  = 2
}

local target_limit_signal_id = { type = "virtual", name = "signal-L" }

local function generate_next_id()
    local id = storage.tasks_next_id or 1

    storage.tasks_next_id = id + 1

    return id
end
local function get_tasks()
    if not storage.drone_tasks then
        storage.drone_tasks = {}
    end

    return storage.drone_tasks
end

local function get_element_count(table)
    local count = 0

    for _, _ in pairs(table) do
        count = count + 1
    end

    return count
end

local function set_drone_as_idle(drone)
    if not storage.idle_drones then
        storage.idle_drones = {}
    end

    local surface_index = drone.surface.index

    if not storage.idle_drones[surface_index] then
        storage.idle_drones[surface_index] = {}
    end

    storage.idle_drones[surface_index][drone.unit_number] = drone
end
local function reset_drone_as_idle(drone_unit_number, surface_index)
    if not storage.idle_drones or not storage.idle_drones[surface_index] then
        return
    end

    storage.idle_drones[surface_index][drone_unit_number] = nil

    if next(storage.idle_drones[surface_index]) == nil then
        storage.idle_drones[surface_index] = nil
    end
end

local function assign_task_drone(drone_unit_number, surface_index, task_id)
    local properties = ep.get_entity_properties_from_unit_number(drone_unit_number)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    table.insert(properties.task_ids, 1, task_id)
    reset_drone_as_idle(drone_unit_number, surface_index)
end
local function unassign_task_drone(drone_unit_number, task_id)
    local properties = ep.get_entity_properties_from_unit_number(drone_unit_number)

    if not properties.task_ids then
        return
    end

    local index = #properties.task_ids

    for i = #properties.task_ids, 1, -1 do
        if properties.task_ids[index] == task_id then
            table.remove(properties.task_ids, index)
        end

        index = index - 1
    end

    if not properties.task_ids[1] then
        properties.task_ids = nil

        local entity = ep.get_managed_entity(drone_unit_number)

        if entity and entity.valid then
            set_drone_as_idle(ep.get_managed_entity(drone_unit_number))
        end
    end
end

local function assign_task_mooring(mooring_unit_number, task_id)
    local properties = ep.get_entity_properties_from_unit_number(mooring_unit_number)

    if not properties.task_ids then
        properties.task_ids = {}
    end
    if not properties.task_target_count then
        properties.task_target_count = 0
    end

    properties.task_ids[task_id] = true
    properties.task_target_count = properties.task_target_count + 1
end
local function unassign_task_mooring(mooring_unit_number, task_id)
    local properties = ep.get_entity_properties_from_unit_number(mooring_unit_number)

    if not properties.task_ids then
        return
    end

    properties.task_ids[task_id] = nil
    properties.task_target_count = properties.task_target_count - 1

    if next(properties.task_ids) == nil then
        properties.task_ids = nil
        properties.task_target_count = nil
    end
end

local function recount_mooring_targets(mooring_unit_number)
    local properties = ep.get_entity_properties_from_unit_number(mooring_unit_number)

    if not properties.task_ids then
        return
    end

    properties.task_target_count = get_element_count(properties.task_ids)
end

local function remove_and_cleanup_task(task_id)
    local tasks = get_tasks()

    local task = tasks[task_id]

    if not task then
        return
    end

    tasks[task_id] = nil

    if task.drone_unit_number ~= nil then
        unassign_task_drone(task.drone_unit_number, task_id)
    end
    if task.provider_unit_number ~= nil then
        unassign_task_mooring(task.provider_unit_number, task_id)
    end
    if task.requester_unit_number ~= nil then
        unassign_task_mooring(task.requester_unit_number, task_id)
    end
    if task.refueler_unit_number ~= nil then
        unassign_task_mooring(task.refueler_unit_number, task_id)
    end
end

local drone_tasks = {}

drone_tasks.task_types = task_types

function drone_tasks.remove_invalid_tasks()
    local function is_drone_valid(unit_number, task_id)
        if unit_number == nil then
            return false
        end

        local entity = ep.get_managed_entity(unit_number)

        if not entity or not entity.valid then
            return false
        end

        local task_ids = ep.get_entity_property(entity, "task_ids")

        if not task_ids then
            return false
        end

        for _, id in ipairs(task_ids) do
            if id == task_id then
                return true
            end
        end

        return false
    end
    local function is_mooring_valid(unit_number, task_id)
        if unit_number == nil then
            return true
        end

        local entity = ep.get_managed_entity(unit_number)

        if not entity or not entity.valid then
            return false
        end

        local task_ids = ep.get_entity_property(entity, "task_ids")

        if not task_ids or not task_ids[task_id] then
            return false
        end

        return true
    end

    local tasks = get_tasks()
    local removal = {}
    local remove_count = 0

    for task_id, task in pairs(get_tasks()) do
        if not is_drone_valid(task.drone_unit_number, task_id)
            or not is_mooring_valid(task.provider_unit_number, task_id)
            or not is_mooring_valid(task.requester_unit_number, task_id)
            or not is_mooring_valid(task.refueler_unit_number, task_id) then
            table.insert(removal, task_id)
            remove_count = remove_count + 1
        end
    end

    for _, task_id in ipairs(removal) do
        tasks[task_id] = nil
    end
    
    log("Removed " .. remove_count .. " invalid Cargo drone tasks")
end
function drone_tasks.recount_task_targets()
    for _, task in pairs(get_tasks()) do
        if task.provider_unit_number ~= nil then
            recount_mooring_targets(task.provider_unit_number)
        end
        if task.requester_unit_number ~= nil then
            recount_mooring_targets(task.requester_unit_number)
        end
        if task.refueler_unit_number ~= nil then
            recount_mooring_targets(task.refueler_unit_number)
        end
    end
end
function drone_tasks.recreate_idle_drones()
    storage.idle_drones = nil

    for unit_number, drone_data in pairs(ep.get_cargo_drones()) do
        local task_ids = ep.get_entity_property_from_unit_number(unit_number, "task_ids")

        if not task_ids or not task_ids[1] then
            set_drone_as_idle(drone_data.entity)
        end
    end
end

function drone_tasks.is_valid(id)
    return get_tasks()[id] ~= nil
end

function drone_tasks.get(id)
    return get_tasks()[id]
end

function drone_tasks.is_at_target_limit(mooring)
    local limit_signal = mooring.get_signal(target_limit_signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal == 0 then
        return false
    end

    local target_count = ep.get_entity_property(mooring, "task_target_count") or 0

    return target_count >= limit_signal
end

function drone_tasks.assign_cargo(drone, provider, requester, items, inventory_filters)
    local id = generate_next_id()

    get_tasks()[id] = {
        id = id,
        type = task_types.cargo,
        drone_unit_number = drone.unit_number,
        provider_unit_number = provider and provider.unit_number or nil,
        requester_unit_number = requester.unit_number,
        items = items,
        inventory_filters = inventory_filters
    }

    assign_task_drone(drone.unit_number, drone.surface.index, id)
    if provider then
        assign_task_mooring(provider.unit_number, id)
    end
    assign_task_mooring(requester.unit_number, id)

    return id
end
function drone_tasks.assign_refuel(drone, refueler)
    local id = generate_next_id()

    get_tasks()[id] = {
        id = id,
        type = task_types.refuel,
        drone_unit_number = drone.unit_number,
        refueler_unit_number = refueler.unit_number
    }

    assign_task_drone(drone.unit_number, drone.surface.index, id)
    assign_task_mooring(refueler.unit_number, id)

    return id
end

function drone_tasks.get_current_drone_task_id(drone)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return nil
    end

    return properties.task_ids[1]
end

function drone_tasks.cargo_unassign_provider(task_id)
    local tasks = get_tasks()

    local task = tasks[task_id]

    if not task then
        return
    end

    unassign_task_mooring(task.provider_unit_number, task_id)

    task.provider_unit_number = nil
end

function drone_tasks.get_idle_drones_per_surface()
    return storage.idle_drones or {}
end

function drone_tasks.destroy(id)
    remove_and_cleanup_task(id)
end

function drone_tasks.drone_created(drone)
    set_drone_as_idle(drone)
end
function drone_tasks.drone_destroyed(unit_number)
    local properties = ep.get_entity_properties_from_unit_number(unit_number)
    local surface_index = ep.get_managed_entity_surface_index(unit_number)

    reset_drone_as_idle(unit_number, surface_index)

    if not properties.task_ids then
        return
    end

    local task_ids = properties.task_ids

    properties.task_ids = nil

    for i, task_id in ipairs(task_ids) do
        remove_and_cleanup_task(task_id)
    end
end
function drone_tasks.mooring_destroyed(unit_number)
    local properties = ep.get_entity_properties_from_unit_number(unit_number)

    if not properties.task_ids then
        return
    end

    local task_ids = properties.task_ids

    properties.task_ids = nil
    properties.task_target_count = nil

    for task_id, _ in pairs(task_ids) do
        remove_and_cleanup_task(task_id)
    end
end

return drone_tasks
