
local ep        = require("entity_property")
local th        = require("target_helper")

local function add_depot(depot)
    local surface_buffer = storage.depot_helper.depots[depot.surface.index]

    if not surface_buffer then
        surface_buffer = {}

        storage.depot_helper.depots[depot.surface.index] = surface_buffer
    end

    surface_buffer[depot.unit_number] = depot
end
local function remove_depot(unit_number, surface_index)
    local surface_buffer = storage.depot_helper.depots[surface_index]

    if not surface_buffer then
        return
    end

    surface_buffer[unit_number] = nil

    if next(surface_buffer) == nil then
        storage.depot_helper.depots[surface_index] = nil
    end
end

local function clean_settings(depot)
    local cb = depot.get_control_behavior()

    while cb.sections_count < 6 do
        cb.add_section()
    end
    while cb.sections_count > 6 do
        cb.remove_section(7)
    end

    th.clean_settings(depot)
end

local depot_helper = {}

function depot_helper.init()
    storage.depot_helper = storage.depot_helper or {}

    storage.depot_helper.depots = storage.depot_helper.depots or {}
end

function depot_helper.created(depot)
    clean_settings(depot)

    th.create_name_render_object(depot)

    add_depot(depot)
end
function depot_helper.destroyed(depot)
    remove_depot(depot.unit_number, depot.surface.index)
end

function depot_helper.surface_deleted(surface_index)
    storage.depot_helper.depots[surface_index] = nil
end
function depot_helper.surface_cleared(surface_index)
    storage.depot_helper.depots[surface_index] = nil
end

function depot_helper.clean()
    local invalid_depots = {}

    for surface_index, surface_buffer in pairs(storage.depot_helper.depots) do
        for unit_number, depot in pairs(surface_buffer) do
            if not depot.valid then
                table.insert(invalid_depots, {
                    unit_number = unit_number,
                    surface_index = surface_index,
                })
            end
        end
    end

    for _, data in ipairs(invalid_depots) do
        remove_depot(data.unit_number, data.surface_index)
    end
end

function depot_helper.clean_settings(depot)
    clean_settings(depot)
end

function depot_helper.get_depots(surface_index)
	return storage.depot_helper.depots[surface_index]
end

function depot_helper.update_map_name_visibility()
    for _, surface_buffer in pairs(storage.depot_helper.depots) do
        for _, depot in pairs(surface_buffer) do
            th.update_name_render_object_visibility(depot)
        end
    end
end

return depot_helper
