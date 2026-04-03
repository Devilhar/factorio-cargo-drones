
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
local function remove_depot(depot)
    local surface_buffer = storage.depot_helper.depots[depot.surface.index]

    if not surface_buffer then
        return
    end

    surface_buffer[depot.unit_number] = nil

    if next(surface_buffer) == nil then
        storage.depot_helper.depots[depot.surface.index] = nil
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
	ep.entity_manage(depot)

    clean_settings(depot)

    add_depot(depot)
end
function depot_helper.destroyed(depot)
    remove_depot(depot)
end

function depot_helper.clean_settings(depot)
    clean_settings(depot)
end

function depot_helper.get_depots(surface_index)
	return storage.depot_helper.depots[surface_index]
end

return depot_helper
