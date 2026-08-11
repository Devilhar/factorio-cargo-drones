
local ep    = require("entity_property")
local th    = require("target_helper")

local task_types = {
    cargo   = 1,
    refuel  = 2,
    depot   = 3,
}

local task_data = {
    -- override = Is prepended to the list of tasks rather than appended
    [task_types.cargo] = {
        override            = false,
    },
    [task_types.refuel] = {
        override            = true,
    },
    [task_types.depot] = {
        override            = false,
    },
}

local callback_idle_drone_count_changed = function (_surface_index) end

local function generate_next_id()
    local id = storage.drone_tasks.next_id

    storage.drone_tasks.next_id = id + 1

    return id
end
local function get_tasks()
    return storage.drone_tasks.tasks
end

local function register_idle_drone(drone)
    local surface_index = drone.surface.index

    local surface_buffer = storage.drone_tasks.surfaces[drone.surface.index]

    if not surface_buffer then
        surface_buffer = {
            idle_drones = {},
            idle_drone_count = 0,
        }

        storage.drone_tasks.surfaces[drone.surface.index] = surface_buffer
    end

    surface_buffer.idle_drones[drone.unit_number] = drone

    surface_buffer.idle_drone_count = table_size(surface_buffer.idle_drones)

    callback_idle_drone_count_changed(surface_index)
end
local function unregister_idle_drone(drone_unit_number, surface_index)
    local surface_buffer = storage.drone_tasks.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    surface_buffer.idle_drones[drone_unit_number] = nil

    surface_buffer.idle_drone_count = table_size(surface_buffer.idle_drones)

    if next(surface_buffer.idle_drones) == nil then
        storage.drone_tasks.surfaces[surface_index] = nil
    end

    callback_idle_drone_count_changed(surface_index)
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
                register_idle_drone(entity)
            end
        end
    end
end

local function get_drone_count(task_ids)
    local drone_count = 0

    for task_id, _ in pairs(task_ids) do
        drone_count = drone_count + 1
    end

    return drone_count
end

local function assign_task_target(mooring, task)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        properties.task_ids = {}
    end

    properties.task_ids[task.id] = true

    local drone_count = get_drone_count(properties.task_ids)

    th.set_drone_count(mooring, drone_count)
end
local function unassign_task_target(mooring, task)
    local properties = ep.get_entity_properties(mooring)

    if not properties.task_ids then
        return
    end

    properties.task_ids[task.id] = nil

    if next(properties.task_ids) == nil then
        properties.task_ids = nil
        th.set_drone_count(mooring, 0)
    else
        local drone_count = get_drone_count(properties.task_ids)

        th.set_drone_count(mooring, drone_count)
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
        local drone = ep.get_managed_entity(task.drone_unit_number)

        if drone and drone.valid then
            unassign_task_drone(task.drone_unit_number, task_id, mark_drone_as_idle)
        end
    end
    if task.provider_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.provider_unit_number)

        if mooring and mooring.valid then
            unassign_task_target(mooring, task)
        end
    end
    if task.requester_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.requester_unit_number)

        if mooring and mooring.valid then
            unassign_task_target(mooring, task)
        end
    end
    if task.refueler_unit_number ~= nil then
        local mooring = ep.get_managed_entity(task.refueler_unit_number)

        if mooring and mooring.valid then
            unassign_task_target(mooring, task)
        end
    end
    if task.depot_unit_number ~= nil then
        local depot = ep.get_managed_entity(task.depot_unit_number)

        if depot and depot.valid then
            unassign_task_target(depot, task)
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

local function remove_tasks_with_invalid_entities()
    local invalid_tasks = {}

    local function is_drone_valid(unit_number)
        local entity = ep.get_managed_entity(unit_number)

        return entity and entity.valid
    end
    local function is_valid(unit_number)
        local entity = ep.get_managed_entity(unit_number)

        return not entity or entity.valid
    end

    for task_id, task in pairs(get_tasks()) do
        if not is_drone_valid(task.drone_unit_number)
            or not is_valid(task.provider_unit_number)
            or not is_valid(task.requester_unit_number)
            or not is_valid(task.refueler_unit_number)
            or not is_valid(task.depot_unit_number) then
            table.insert(invalid_tasks, task_id)
        end
    end

    for _, task_id in ipairs(invalid_tasks) do
        remove_and_cleanup_task(task_id)
    end
end

local drone_tasks = {}

drone_tasks.task_types = task_types

function drone_tasks.set_on_drone_count_changed(on_idle_drone_count_changed)
    callback_idle_drone_count_changed = on_idle_drone_count_changed
end

function drone_tasks.init()
    storage.drone_tasks = storage.drone_tasks or {}

    storage.drone_tasks.tasks = storage.drone_tasks.tasks or {}
    storage.drone_tasks.next_id = storage.drone_tasks.next_id or 1
    storage.drone_tasks.surfaces = storage.drone_tasks.surfaces or {}
end

function drone_tasks.drone_surface_change(drone, old_surface)
    local task_ids = ep.get_entity_property(drone, "task_ids")

	if task_ids then
		task_ids = table.deepcopy(task_ids)

        for _, task_id in ipairs(task_ids) do
            remove_and_cleanup_task(task_id)
        end
	end

    unregister_idle_drone(drone.unit_number, old_surface)

    register_idle_drone(drone)
end

function drone_tasks.surface_deleted(surface_index)
    remove_tasks_with_invalid_entities()

    storage.drone_tasks.surfaces[surface_index] = nil
end
function drone_tasks.surface_cleared(surface_index)
    remove_tasks_with_invalid_entities()

    storage.drone_tasks.surfaces[surface_index] = nil
end

function drone_tasks.clean()
    remove_tasks_with_invalid_entities()

    local invalid_idle_drones = {}

    for surface_index, surface_buffer in pairs(storage.drone_tasks.surfaces) do
        for unit_number, drone in pairs(surface_buffer.idle_drones) do
            if not drone.valid then
                table.insert(invalid_idle_drones, {
                    unit_number = unit_number,
                    surface_index = surface_index,
                })
            end
        end
    end

    for _, data in ipairs(invalid_idle_drones) do
        unregister_idle_drone(data.unit_number, data.surface_index)
    end
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
        assign_task_target(provider, task)
    end
    assign_task_target(requester, task)

    unregister_idle_drone(drone.unit_number, drone.surface.index)

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
    assign_task_target(refueler, task)

    unregister_idle_drone(drone.unit_number, drone.surface.index)

    return id
end
function drone_tasks.assign_depot(drone, depot)
    local id = generate_next_id()

    local task = {
        id = id,
        type = task_types.depot,
        drone_unit_number = drone.unit_number,
        depot_unit_number = depot.unit_number
    }

    get_tasks()[id] = task

    assign_task_drone(drone.unit_number, task)
    assign_task_target(depot, task)

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

function drone_tasks.cargo_unassign_provider(task_id)
    local tasks = get_tasks()

    local task = tasks[task_id]

    if not task then
        return
    end

    local mooring = ep.get_managed_entity(task.provider_unit_number)

    if mooring then
        unassign_task_target(mooring, task)
    end

    task.provider_unit_number = nil
end

function drone_tasks.get_idle_drones_per_surface()
    return storage.drone_tasks.surfaces or {}
end

function drone_tasks.destroy(id)
    remove_and_cleanup_task(id)
end

function drone_tasks.drone_created(drone)
    register_idle_drone(drone)
end
function drone_tasks.drone_destroyed(drone)
    local properties = ep.get_entity_properties(drone)

    unregister_idle_drone(drone.unit_number, drone.surface.index)

    if not properties.task_ids then
        return
    end

    local task_ids = properties.task_ids

    properties.task_ids = nil

    for i, task_id in ipairs(task_ids) do
        remove_and_cleanup_task(task_id)
    end
end
function drone_tasks.target_destroyed(target)
    local properties = ep.get_entity_properties(target)

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

function drone_tasks.idle_drone_count(surface_index)
    local surface_buffer = storage.drone_tasks.surfaces[surface_index]

    if not surface_buffer then
        return 0
    end

    return surface_buffer.idle_drone_count
end

return drone_tasks
