
local ep    = require("scripts.entity_property")

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

local function assign_task_drone(drone, task_id)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    table.insert(properties.task_ids, 1, task_id)
end
local function unassign_task_drone(drone, task_id)
    local properties = ep.get_entity_properties(drone)

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
    end
end

local function assign_task_mooring(mooring, task_id)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    properties.task_ids[task_id] = true
end
local function unassign_task_mooring(mooring, task_id)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        return
    end

    properties.task_ids[task_id] = nil

    if next(properties.task_ids) == nil then
        properties.task_ids = nil
    end
end

local function remove_and_cleanup_task(task_id)
    local tasks = get_tasks()

    local task = tasks[task_id]

    if not task then
        return
    end

    if task.drone then
        unassign_task_drone(task.drone, task_id)
    end
    if task.provider then
        unassign_task_mooring(task.provider, task_id)
    end
    if task.requester then
        unassign_task_mooring(task.requester, task_id)
    end
    if task.refueler then
        unassign_task_mooring(task.refueler, task_id)
    end
end

local drone_tasks = {}

drone_tasks.task_types = task_types

function drone_tasks.is_valid(id)
    return get_tasks()[id] ~= nil
end

function drone_tasks.get(id)
    return get_tasks()[id]
end

function drone_tasks.assign_cargo(drone, provider, requester, items)
    local id = generate_next_id()

    get_tasks()[id] = {
        id = id,
        type = task_types.cargo,
        drone = drone,
        provider = provider,
        requester = requester,
        items = items
    }

    assign_task_drone(drone, id)
    assign_task_mooring(provider, id)
    assign_task_mooring(requester, id)

    return id
end
function drone_tasks.assign_refuel(drone, refueler)
    local id = generate_next_id()

    get_tasks()[id] = {
        id = id,
        type = task_types.refuel,
        drone = drone,
        refueler = refueler
    }

    assign_task_drone(drone, id)
    assign_task_mooring(refueler, id)

    return id
end

function drone_tasks.get_current_drone_task_id(drone)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return nil
    end

    return task_ids[1]
end

function drone_tasks.destroy(id)
    remove_and_cleanup_task(id)
end

function drone_tasks.drone_destroyed(drone)
    local properties = ep.get_entity_properties(drone)

    if not properties.task_ids then
        return
    end

    local task_ids = properties.task_ids

    properties.task_ids = nil

    for i, task_id in ipairs(task_ids) do
        remove_and_cleanup_task(task_id)
    end
end

function drone_tasks.mooring_destroyed(mooring)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        return
    end

    local task_ids = properties.task_ids

    properties.task_ids = nil

    for task_id, _ in pairs(task_ids) do
        remove_and_cleanup_task(task_id)
    end
end

return drone_tasks
