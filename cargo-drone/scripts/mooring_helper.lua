
local ep = require("scripts.entity_property")

local signal_id_drone_limit = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_priority    = { type = "virtual", name = "signal-P", quality = "normal" }
local signal_id_drone_count = { type = "virtual", name = "signal-C", quality = "normal" }

local settings_index = {
    drone_limit                     = 1,
    drone_limit_circuit             = 2,
    drone_limit_circuit_signal_id   = 3,
    priority                        = 4,
    priority_circuit                = 5,
    priority_circuit_signal_id      = 6,
    drone_count_circuit             = 7,
    drone_count_signal_id           = 8,
}
local settings_filter_name = {
    drone_limit                     = "signal-A",
    drone_limit_circuit             = "signal-B",
    drone_limit_circuit_signal_id   = "signal-C",
    priority                        = "signal-D",
    priority_circuit                = "signal-E",
    priority_circuit_signal_id      = "signal-F",
    drone_count_circuit             = "signal-G",
    drone_count_signal_id           = "signal-H",
}
local section_index = {
    settings                        = 1,
    drone_limit                     = 2,
    priority_circuit                = 3,
    drone_count                     = 4,
    output                          = 5,
}

local function get_settings_section(mooring)
    local cb = mooring.get_control_behavior()

    return cb.get_section(section_index.settings)
end

local function set_filter_value(index, filter_name, mooring, value)
    local section = get_settings_section(mooring)

    if value ~= nil then
        section.set_slot(index, {
            value = {
                type = "virtual",
                name = filter_name,
                quality = "normal",
            },
            min = value
        })
    else
        section.clear_slot(index)
    end
end
local function get_filter_value(index, mooring)
    local section = get_settings_section(mooring)

    local filter = section.get_slot(index)

    if not filter then
        return nil
    end

    return filter.min
end

local function set_signal_id(mooring, index, signal_id)
    local section = mooring.get_control_behavior().get_section(index)

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

local function set_drone_limit(mooring, limit)
    set_filter_value(settings_index.drone_limit, settings_filter_name.drone_limit, mooring, limit)
end
local function get_drone_limit(mooring)
    local limit = get_filter_value(settings_index.drone_limit, mooring)

    if limit == nil then
        return nil
    end

    if limit < 0 then
        limit = 0
    end

    return limit
end

local function get_drone_limit_circuit(mooring)
    return get_filter_value(settings_index.drone_limit_circuit, mooring) ~= nil
end
local function set_drone_limit_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.drone_limit_circuit, settings_filter_name.drone_limit_circuit, mooring, 0)
    else
        set_filter_value(settings_index.drone_limit_circuit, settings_filter_name.drone_limit_circuit, mooring, nil)
    end
end

local function get_drone_limit_circuit_signal_id(mooring)
    if get_filter_value(settings_index.drone_limit_circuit_signal_id, mooring) == nil then
        return signal_id_drone_limit
    end

    local section = mooring.get_control_behavior().get_section(section_index.drone_limit)

    return section.get_slot(1).value
end
local function set_drone_limit_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.drone_limit_circuit_signal_id, settings_filter_name.drone_limit_circuit_signal_id, mooring, 0)
    set_signal_id(mooring, section_index.drone_limit, signal_id)
end

local function get_priority(mooring)
    local priority = get_filter_value(settings_index.priority, mooring) or 50

    if priority < 0 then
        priority = 0
    elseif priority > 255 then
        priority = 255
    end

    return priority
end
local function set_priority(mooring, limit)
    set_filter_value(settings_index.priority, settings_filter_name.priority, mooring, limit)
end

local function get_priority_circuit(mooring)
    return get_filter_value(settings_index.priority_circuit, mooring) ~= nil
end
local function set_priority_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.priority_circuit, settings_filter_name.priority_circuit, mooring, 0)
    else
        set_filter_value(settings_index.priority_circuit, settings_filter_name.priority_circuit, mooring, nil)
    end
end

local function get_priority_circuit_signal_id(mooring)
    if get_filter_value(settings_index.priority_circuit_signal_id, mooring) == nil then
        return signal_id_priority
    end

    local section = mooring.get_control_behavior().get_section(section_index.priority_circuit)

    return section.get_slot(1).value
end
local function set_priority_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.priority_circuit_signal_id, settings_filter_name.priority_circuit_signal_id, mooring, 0)
    set_signal_id(mooring, section_index.priority_circuit, signal_id)
end

local function get_drone_count(mooring_unit_number)
    return ep.get_entity_property_from_unit_number(mooring_unit_number, "drone_count") or 0
end
local function set_drone_count(mooring, count)
    if count <= 0 then
        count = nil
    end

    ep.set_entity_property(mooring, "drone_count", count)
end

local function get_drone_count_circuit(mooring)
    return get_filter_value(settings_index.drone_count_circuit, mooring) ~= nil
end
local function set_drone_count_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.drone_count_circuit, settings_filter_name.drone_count_circuit, mooring, 0)
    else
        set_filter_value(settings_index.drone_count_circuit, settings_filter_name.drone_count_circuit, mooring, nil)
    end
end

local function get_drone_count_circuit_signal_id(mooring)
    if get_filter_value(settings_index.drone_count_signal_id, mooring) == nil then
        return signal_id_drone_count
    end

    local section = mooring.get_control_behavior().get_section(section_index.drone_count)

    return section.get_slot(1).value
end
local function set_drone_count_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.drone_count_signal_id, settings_filter_name.drone_count_signal_id, mooring, 0)
    set_signal_id(mooring, section_index.drone_count, signal_id)
end

local function update_drone_count_output(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.output)

    if not get_drone_count_circuit(mooring) then
        section.clear_slot(1)

        return
    end

    local signal_id = get_drone_count_circuit_signal_id(mooring)
    local count = get_drone_count(mooring.unit_number)

    if signal_id == nil or count == 0 then
        section.clear_slot(1)

        return
    end

    section.set_slot(1, {
        value = signal_id,
        min = count
    })
end

local mooring_helper = {}

function mooring_helper.clean_settings(mooring)
    local cb = mooring.get_control_behavior()

    while cb.sections_count < 5 do
        cb.add_section()
    end
    while cb.sections_count > 5 do
        cb.remove_section(6)
    end

    for i = 1, 5 do
        local section = cb.get_section(i)

        section.active = false
        section.group = ""
    end

    update_drone_count_output(mooring)

    cb.get_section(section_index.output).active = true
end

function mooring_helper.is_drone_limit_enabled(mooring)
    return get_drone_limit(mooring) ~= nil
end
function mooring_helper.set_drone_limit_enabled(mooring, flag)
    if flag then
        set_drone_limit(mooring, 0)
    else
        set_drone_limit(mooring, nil)
    end
end

function mooring_helper.get_drone_limit_value(mooring)
    return get_drone_limit(mooring) or 0
end
function mooring_helper.set_drone_limit_value(mooring, value)
    set_drone_limit(mooring, value)
end

function mooring_helper.is_drone_limit_circuit(mooring)
    return get_drone_limit_circuit(mooring)
end
function mooring_helper.set_drone_limit_circuit(mooring, flag)
    if flag then
        set_drone_limit(mooring, 0)
        set_drone_limit_circuit(mooring, true)
    else
        set_drone_limit_circuit(mooring, false)
    end
end

function mooring_helper.get_drone_limit_circuit_signal_id(mooring)
    return get_drone_limit_circuit_signal_id(mooring)
end
function mooring_helper.set_drone_limit_circuit_signal_id(mooring, signal_id)
    set_drone_limit_circuit_signal_id(mooring, signal_id)
end

function mooring_helper.get_drone_limit(mooring)
    if not get_drone_limit_circuit(mooring) then
        return get_drone_limit(mooring)
    end

    local signal_id = get_drone_limit_circuit_signal_id(mooring)

    if signal_id == nil then
        return 0
    end

    local limit_signal = mooring.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function mooring_helper.get_priority_value(mooring)
    return get_priority(mooring)
end
function mooring_helper.set_priority_value(mooring, value)
    if value < 0 then
        value = 0
    elseif value > 255 then
        value = 255
    end

    set_priority(mooring, value)
end

function mooring_helper.is_priority_circuit(mooring)
    return get_priority_circuit(mooring)
end
function mooring_helper.set_priority_circuit(mooring, flag)
    if flag then
        set_priority(mooring, nil)
        set_priority_circuit(mooring, true)
    else
        set_priority_circuit(mooring, false)
    end
end

function mooring_helper.get_priority_circuit_signal_id(mooring)
    return get_priority_circuit_signal_id(mooring)
end
function mooring_helper.set_priority_circuit_signal_id(mooring, signal_id)
    set_priority_circuit_signal_id(mooring, signal_id)
end

function mooring_helper.get_priority(mooring)
    if not get_priority_circuit(mooring) then
        return get_priority(mooring)
    end

    local signal_id = get_priority_circuit_signal_id(mooring)

    if signal_id == nil then
        return 0
    end

    local priority = mooring.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if priority < 0 then
        return 0
    end

    if priority >= 256 then
        return 255
    end

    return priority
end

function mooring_helper.get_drone_count_value(mooring_unit_number)
    return get_drone_count(mooring_unit_number)
end
function mooring_helper.set_drone_count_value(mooring, value)
    if value < 0 then
        value = 0
    end

    set_drone_count(mooring, value)

    update_drone_count_output(mooring)
end

function mooring_helper.is_drone_count_circuit(mooring)
    return get_drone_count_circuit(mooring)
end
function mooring_helper.set_drone_count_circuit(mooring, flag)
    set_drone_count_circuit(mooring, flag)

    update_drone_count_output(mooring)
end

function mooring_helper.get_drone_count_circuit_signal_id(mooring)
    return get_drone_count_circuit_signal_id(mooring)
end
function mooring_helper.set_drone_count_circuit_signal_id(mooring, signal_id)
    set_drone_count_circuit_signal_id(mooring, signal_id)

    update_drone_count_output(mooring)
end

function mooring_helper.is_at_drone_limit(mooring)
    local drone_limit = mooring_helper.get_drone_limit(mooring)

    if drone_limit == nil then
        return false
    end

    local target_count = get_drone_count(mooring.unit_number)

    return target_count >= drone_limit
end

return mooring_helper
