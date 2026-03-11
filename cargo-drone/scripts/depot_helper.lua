
local ep        = require("entity_property")
local fh        = require("filter_helper")

local signal_id_drone_limit     = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_priority        = { type = "virtual", name = "signal-P", quality = "normal" }
local signal_id_drone_count     = { type = "virtual", name = "signal-C", quality = "normal" }

local setting_names = {
    drone_limit                     = "drone_limit",
    drone_limit_circuit             = "drone_limit_circuit",
    drone_limit_circuit_signal_id   = "drone_limit_circuit_signal_id",
    priority                        = "priority",
    priority_circuit                = "priority_circuit",
    priority_circuit_signal_id      = "priority_circuit_signal_id",
    drone_count_circuit             = "drone_count_circuit",
    drone_count_signal_id           = "drone_count_signal_id",
}

local settings_filter_name = {
    [setting_names.drone_limit]                     = "signal-A",
    [setting_names.drone_limit_circuit]             = "signal-B",
    [setting_names.drone_limit_circuit_signal_id]   = "signal-C",
    [setting_names.priority]                        = "signal-D",
    [setting_names.priority_circuit]                = "signal-E",
    [setting_names.priority_circuit_signal_id]      = "signal-F",
    [setting_names.drone_count_circuit]             = "signal-G",
    [setting_names.drone_count_signal_id]           = "signal-H",
}

local section_index = {
    settings                        = 1,
    output                          = 2,
    drone_limit                     = 3,
    priority_circuit                = 4,
    drone_count                     = 5,
}
local output_index = {
    drone_count                     = 1,
}

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

local function get_settings_section(depot)
    local cb = depot.get_control_behavior()

    return cb.get_section(section_index.settings)
end

local function set_settings_value(depot, setting_name, value)
    fh.set_filter_value(get_settings_section(depot), settings_filter_name[setting_name], value)
end
local function get_settings_value(depot, setting_name)
    return fh.get_filter_value(get_settings_section(depot), settings_filter_name[setting_name])
end

local function set_signal_id(depot, index, signal_id)
    local section = depot.get_control_behavior().get_section(index)

    if signal_id ~= nil then
        section.set_slot(1, {
            value = {
                type = signal_id.type,
                name = signal_id.name,
                quality = signal_id.quality or "normal",
            },
            min = 0
        })
    else
        section.clear_slot(1)
    end
end

local function set_drone_limit(depot, limit)
    set_settings_value(depot, setting_names.drone_limit, limit)
end
local function get_drone_limit(depot)
    local limit = get_settings_value(depot, setting_names.drone_limit)

    if limit == nil then
        return nil
    end

    if limit < 0 then
        limit = 0
    end

    return limit
end

local function get_drone_limit_circuit(depot)
    return get_settings_value(depot, setting_names.drone_limit_circuit) ~= nil
end
local function set_drone_limit_circuit(depot, flag)
    if flag then
        set_settings_value(depot, setting_names.drone_limit_circuit, 0)
    else
        set_settings_value(depot, setting_names.drone_limit_circuit, nil)
    end
end

local function get_drone_limit_circuit_signal_id(depot)
    if get_settings_value(depot, setting_names.drone_limit_circuit_signal_id) == nil then
        return signal_id_drone_limit
    end

    local section = depot.get_control_behavior().get_section(section_index.drone_limit)

    return section.get_slot(1).value
end
local function set_drone_limit_circuit_signal_id(depot, signal_id)
    set_settings_value(depot, setting_names.drone_limit_circuit_signal_id, 0)
    set_signal_id(depot, section_index.drone_limit, signal_id)
end

local function get_priority(depot)
    local priority = get_settings_value(depot, setting_names.priority) or 50

    if priority < 0 then
        priority = 0
    elseif priority > 255 then
        priority = 255
    end

    return priority
end
local function set_priority(depot, limit)
    set_settings_value(depot, setting_names.priority, limit)
end

local function get_priority_circuit(depot)
    return get_settings_value(depot, setting_names.priority_circuit) ~= nil
end
local function set_priority_circuit(depot, flag)
    if flag then
        set_settings_value(depot, setting_names.priority_circuit, 0)
    else
        set_settings_value(depot, setting_names.priority_circuit, nil)
    end
end

local function get_priority_circuit_signal_id(depot)
    if get_settings_value(depot, setting_names.priority_circuit_signal_id) == nil then
        return signal_id_priority
    end

    local section = depot.get_control_behavior().get_section(section_index.priority_circuit)

    return section.get_slot(1).value
end
local function set_priority_circuit_signal_id(depot, signal_id)
    set_settings_value(depot, setting_names.priority_circuit_signal_id, 0)
    set_signal_id(depot, section_index.priority_circuit, signal_id)
end

local function get_drone_count(depot)
    return ep.get_entity_property(depot, "drone_count") or 0
end
local function set_drone_count(depot, count)
    if count <= 0 then
        count = nil
    end

    ep.set_entity_property(depot, "drone_count", count)
end

local function get_drone_count_circuit(depot)
    return get_settings_value(depot, setting_names.drone_count_circuit) ~= nil
end
local function set_drone_count_circuit(depot, flag)
    if flag then
        set_settings_value(depot, setting_names.drone_count_circuit, 0)
    else
        set_settings_value(depot, setting_names.drone_count_circuit, nil)
    end
end

local function get_drone_count_circuit_signal_id(depot)
    if get_settings_value(depot, setting_names.drone_count_signal_id) == nil then
        return signal_id_drone_count
    end

    local section = depot.get_control_behavior().get_section(section_index.drone_count)

    return section.get_slot(1).value
end
local function set_drone_count_circuit_signal_id(depot, signal_id)
    set_settings_value(depot, setting_names.drone_count_signal_id, 0)
    set_signal_id(depot, section_index.drone_count, signal_id)
end

local function update_drone_count_output(depot)
    local cb = depot.get_control_behavior()

    local section = cb.get_section(section_index.output)

    if not get_drone_count_circuit(depot) then
        section.clear_slot(output_index.drone_count)

        return
    end

    local signal_id = get_drone_count_circuit_signal_id(depot)
    local count = get_drone_count(depot)

    if signal_id == nil or count == 0 then
        section.clear_slot(output_index.drone_count)

        return
    end

    section.set_slot(output_index.drone_count, {
        value = signal_id,
        min = count
    })
end

local function resize_and_activate_sections(control_behavior)
    while control_behavior.sections_count < 5 do
        control_behavior.add_section()
    end
    while control_behavior.sections_count > 5 do
        control_behavior.remove_section(6)
    end

    for i = 1, 5 do
        local section = control_behavior.get_section(i)

        section.active = false
        section.group = ""
    end

    control_behavior.get_section(section_index.output).active = true
end
local function clear_all_outputs(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.output)

    section.filters = {}
end
local function clean_settings(depot)
    local cb = depot.get_control_behavior()

    resize_and_activate_sections(cb)

    clear_all_outputs(depot)

    update_drone_count_output(depot)
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

function depot_helper.is_drone_limit_enabled(depot)
    return get_drone_limit(depot) ~= nil
end
function depot_helper.set_drone_limit_enabled(depot, flag)
    if flag then
        set_drone_limit(depot, 0)
    else
        set_drone_limit(depot, nil)
    end
end

function depot_helper.get_drone_limit_value(depot)
    return get_drone_limit(depot) or 0
end
function depot_helper.set_drone_limit_value(depot, value)
    set_drone_limit(depot, value)
end

function depot_helper.is_drone_limit_circuit(depot)
    return get_drone_limit_circuit(depot)
end
function depot_helper.set_drone_limit_circuit(depot, flag)
    if flag then
        set_drone_limit(depot, 0)
        set_drone_limit_circuit(depot, true)
    else
        set_drone_limit_circuit(depot, false)
    end
end

function depot_helper.get_drone_limit_circuit_signal_id(depot)
    return get_drone_limit_circuit_signal_id(depot)
end
function depot_helper.set_drone_limit_circuit_signal_id(depot, signal_id)
    set_drone_limit_circuit_signal_id(depot, signal_id)
end

function depot_helper.get_drone_limit(depot)
    if not get_drone_limit_circuit(depot) then
        return get_drone_limit(depot)
    end

    local signal_id = get_drone_limit_circuit_signal_id(depot)

    if signal_id == nil then
        return 0
    end

    local limit_signal = depot.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function depot_helper.get_priority_value(depot)
    return get_priority(depot)
end
function depot_helper.set_priority_value(depot, value)
    if value < 0 then
        value = 0
    elseif value > 255 then
        value = 255
    end

    set_priority(depot, value)
end

function depot_helper.is_priority_circuit(depot)
    return get_priority_circuit(depot)
end
function depot_helper.set_priority_circuit(depot, flag)
    if flag then
        set_priority(depot, nil)
        set_priority_circuit(depot, true)
    else
        set_priority_circuit(depot, false)
    end
end

function depot_helper.get_priority_circuit_signal_id(depot)
    return get_priority_circuit_signal_id(depot)
end
function depot_helper.set_priority_circuit_signal_id(depot, signal_id)
    set_priority_circuit_signal_id(depot, signal_id)
end

function depot_helper.get_priority(depot)
    if not get_priority_circuit(depot) then
        return get_priority(depot)
    end

    local signal_id = get_priority_circuit_signal_id(depot)

    if signal_id == nil then
        return 0
    end

    local priority = depot.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if priority < 0 then
        return 0
    end

    if priority >= 256 then
        return 255
    end

    return priority
end

function depot_helper.get_drone_count(depot)
    return get_drone_count(depot)
end
function depot_helper.set_drone_count(depot, value)
    if value < 0 then
        value = 0
    end

    set_drone_count(depot, value)

    update_drone_count_output(depot)
end

function depot_helper.is_drone_count_circuit(depot)
    return get_drone_count_circuit(depot)
end
function depot_helper.set_drone_count_circuit(depot, flag)
    set_drone_count_circuit(depot, flag)

    update_drone_count_output(depot)
end

function depot_helper.get_drone_count_circuit_signal_id(depot)
    return get_drone_count_circuit_signal_id(depot)
end
function depot_helper.set_drone_count_circuit_signal_id(depot, signal_id)
    set_drone_count_circuit_signal_id(depot, signal_id)

    update_drone_count_output(depot)
end

function depot_helper.is_at_drone_limit(depot)
    local drone_limit = depot_helper.get_drone_limit(depot)

    if drone_limit == nil then
        return false
    end

    local target_count = get_drone_count(depot)

    return target_count >= drone_limit
end

return depot_helper
