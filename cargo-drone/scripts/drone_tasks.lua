
local ep    = require("scripts.entity_property")
local mh    = require("scripts.mooring_helper")

local task_types = {
    cargo   = 1,
    refuel  = 2,
    depot   = 3,
}

local task_data = {
    -- drone_count          = Should this task count towards the drone count?
    -- depot_drone_count    = Should this task count towards the depot drone count?
    -- muted_task           = Is this task considered unimportant to show the player?
    [task_types.cargo] = {
        override            = false,
        drone_count         = true,
        depot_drone_count   = false,
        muted_task          = false,
    },
    [task_types.refuel] = {
        override            = true,
        drone_count         = true,
        depot_drone_count   = false,
        muted_task          = false,
    },
    [task_types.depot] = {
        override            = false,
        drone_count         = false,
        depot_drone_count   = true,
        muted_task          = true,
    },
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

local function assign_task_drone(drone_unit_number, task)
    local properties = ep.get_entity_properties_from_unit_number(drone_unit_number)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    if task_data[task.type].override then
        table.insert(properties.task_ids, 1, task.id)
    else
        table.insert(properties.task_ids, task.id)
    end

end
local function unassign_task_drone(drone_unit_number, task_id, mark_as_idle)
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

        if mark_as_idle then
            local entity = ep.get_managed_entity(drone_unit_number)

            if entity and entity.valid then
                set_drone_as_idle(entity)
            end
        end
    end
end

local function get_drone_count(task_ids)
    local drone_count = 0
    local tasks = get_tasks()

    for task_id, _ in pairs(task_ids) do
        local task = tasks[task_id]

        local type_data = task_data[task.type]

        if type_data.drone_count then
            drone_count = drone_count + 1
        end
    end

    return drone_count
end
local function get_depot_drone_count(task_ids)
    local drone_count = 0
    local tasks = get_tasks()

    for task_id, _ in pairs(task_ids) do
        local task = tasks[task_id]

        local type_data = task_data[task.type]

        if type_data.depot_drone_count then
            drone_count = drone_count + 1
        end
    end

    return drone_count
end

local function assign_task_mooring(mooring, task)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    properties.task_ids[task.id] = true

    local type_data = task_data[task.type]

    if type_data.drone_count then
        local drone_count = get_drone_count(properties.task_ids)

        mh.set_drone_count(mooring, drone_count)
    end
    if type_data.depot_drone_count then
        local drone_count = get_depot_drone_count(properties.task_ids)

        mh.set_depot_drone_count(mooring, drone_count)
    end
end
local function unassign_task_mooring(mooring, task)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        return
    end

    properties.task_ids[task.id] = nil

    local type_data = task_data[task.type]

    if next(properties.task_ids) == nil then
        properties.task_ids = nil
        if type_data.drone_count then
            mh.set_drone_count(mooring, 0)
        end
        if type_data.depot_drone_count then
            mh.set_depot_drone_count(mooring, 0)
        end
    else
        if type_data.drone_count then
            local drone_count = get_drone_count(properties.task_ids)

            mh.set_drone_count(mooring, drone_count)
        end
        if type_data.depot_drone_count then
            local drone_count = get_depot_drone_count(properties.task_ids)

            mh.set_depot_drone_count(mooring, drone_count)
        end
    end
end

local function remove_and_cleanup_task(task_id)
    local tasks = get_tasks()

    local task = tasks[task_id]

    if not task then
        return
    end

    tasks[task_id] = nil

    local mark_drone_as_idle = task.type ~= task_types.depot

    if task.drone_unit_number ~= nil then
        unassign_task_drone(task.drone_unit_number, task_id, mark_drone_as_idle)
    end
    if task.provider_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.provider_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task)
        end
    end
    if task.requester_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.requester_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task)
        end
    end
    if task.refueler_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.refueler_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task)
        end
    end
    if task.depot_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.depot_unit_number)

        if mooring then
            unassign_task_mooring(mooring, task)
        end
    end
end

local function pop_depot_task(drone)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return
    end

    local task_id = properties.task_ids[1]

    if not task_id or get_tasks()[task_id].type ~= task_types.depot then
        return
    end

    remove_and_cleanup_task(task_id)
end

local drone_tasks = {}

drone_tasks.task_types = task_types

function drone_tasks.migration_remove_all_tasks()
    storage.idle_drones = nil

    for _, drone_data in pairs(ep.get_cargo_drones()) do
        ep.set_entity_property(drone_data.entity, "task_ids", nil)

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
    pop_depot_task(drone)

    local id = generate_next_id()

    local task = {
        id = id,
        type = task_types.cargo,
        drone_unit_number = drone.unit_number,
        provider_unit_number = provider and provider.unit_number or nil,
        requester_unit_number = requester.unit_number,
        items = items,
        inventory_filters = inventory_filters
    }

    get_tasks()[id] = task

    assign_task_drone(drone.unit_number, task)
    if provider then
        assign_task_mooring(provider, task)
    end
    assign_task_mooring(requester, task)

    reset_drone_as_idle(drone.unit_number, drone.surface.index)

    return id
end
function drone_tasks.assign_refuel(drone, refueler)
    pop_depot_task(drone)

    local id = generate_next_id()

    local task = {
        id = id,
        type = task_types.refuel,
        drone_unit_number = drone.unit_number,
        refueler_unit_number = refueler.unit_number
    }

    get_tasks()[id] = task

    assign_task_drone(drone.unit_number, task)
    assign_task_mooring(refueler, task)

    reset_drone_as_idle(drone.unit_number, drone.surface.index)

    return id
end
function drone_tasks.assign_depot(drone, mooring)
    local id = generate_next_id()

    local task = {
        id = id,
        type = task_types.depot,
        drone_unit_number = drone.unit_number,
        depot_unit_number = mooring.unit_number
    }

    get_tasks()[id] = task

    assign_task_drone(drone.unit_number, task)
    assign_task_mooring(mooring, task)

    return id
end

function drone_tasks.get_current_drone_task_id(drone)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return nil
    end

    return properties.task_ids[1]
end
function drone_tasks.get_target(task)
    if task.provider_unit_number then
        return ep.get_managed_entity(task.provider_unit_number)
    elseif task.requester_unit_number then
        return ep.get_managed_entity(task.requester_unit_number)
    elseif task.refueler_unit_number then
        return ep.get_managed_entity(task.refueler_unit_number)
    else
        return ep.get_managed_entity(task.depot_unit_number)
    end
end

function drone_tasks.is_muted(task)
    return task_data[task.type].muted_task
end

function drone_tasks.cargo_unassign_provider(task_id)
    local tasks = get_tasks()

    local task = tasks[task_id]

    if not task then
        return
    end

    local mooring = ep.get_managed_entity(task.provider_unit_number)

    if mooring then
        unassign_task_mooring(mooring, task)
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
