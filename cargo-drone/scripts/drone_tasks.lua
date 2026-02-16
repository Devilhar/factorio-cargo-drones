
local ep    = require("scripts.entity_property")
local mh    = require("scripts.mooring_helper")

local task_types = {
    cargo   = 1,
    refuel  = 2
}

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

local function assign_task_mooring(mooring, task_id)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    properties.task_ids[task_id] = true

    local drone_count = 0

    for _, _ in pairs(properties.task_ids) do
        drone_count = drone_count + 1
    end

    mh.set_drone_count_value(mooring, drone_count)
end
local function unassign_task_mooring(mooring, task_id)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        return
    end

    properties.task_ids[task_id] = nil

    if next(properties.task_ids) == nil then
        properties.task_ids = nil
        mh.set_drone_count_value(mooring, 0)
    else
        local drone_count = 0

        for _, _ in pairs(properties.task_ids) do
            drone_count = drone_count + 1
        end

        mh.set_drone_count_value(mooring, drone_count)
    end
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
        local mooring = ep.get_managed_entity(task.provider_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task_id)
        end
    end
    if task.requester_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.requester_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task_id)
        end
    end
    if task.refueler_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.refueler_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task_id)
        end
    end
end

local drone_tasks = {}

drone_tasks.task_types = task_types

function drone_tasks.migration_remove_all_tasks()
    storage.idle_drones = nil
    
    for _, drone_data in pairs(ep.get_cargo_drones()) do
        local task_ids = ep.set_entity_property(drone_data.entity, "task_ids", nil)

        set_drone_as_idle(drone_data.entity)
    end

    storage.drone_tasks = {}
    storage.tasks_next_id = nil
end

function drone_tasks.is_valid(id)
    return get_tasks()[id] ~= nil
end

function drone_tasks.get(id)
    return get_tasks()[id]
end
function drone_tasks.get_entity_task_ids(entity)
    return ep.get_entity_property(entity, "task_ids")
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
        assign_task_mooring(provider, id)
    end
    assign_task_mooring(requester, id)

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
    assign_task_mooring(refueler, id)

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

    local mooring = ep.get_managed_entity(task.provider_unit_number)

    if mooring then
        unassign_task_mooring(mooring, task_id)
    end

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
