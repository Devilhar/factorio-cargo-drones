
local signal_id_drone_limit = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_priority    = { type = "virtual", name = "signal-P", quality = "normal" }

local settings_index = {
    drone_limit                     = 1,
    drone_limit_circuit             = 2,
    drone_limit_circuit_signal_id   = 3,
    priority                        = 4,
    priority_circuit                = 5,
    priority_circuit_signal_id      = 6
}
local settings_filter_name = {
    drone_limit                     = "signal-A",
    drone_limit_circuit             = "signal-B",
    drone_limit_circuit_signal_id   = "signal-C",
    priority                        = "signal-D",
    priority_circuit                = "signal-E",
    priority_circuit_signal_id      = "signal-F",
}

local function get_section(mooring)
    local cb = mooring.get_control_behavior()

    return cb.get_section(1)
end

local function set_filter_value(index, filter_name, mooring, value)
    local section = get_section(mooring)

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
    local section = get_section(mooring)

    local filter = section.get_slot(index)

    if not filter then
        return nil
    end

    return filter.min
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

    local section = mooring.get_control_behavior().get_section(2)

    return section.get_slot(1).value
end
local function set_drone_limit_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.drone_limit_circuit_signal_id, settings_filter_name.drone_limit_circuit_signal_id, mooring, 0)
    local section = mooring.get_control_behavior().get_section(2)

    if signal_id ~= nil then
        section.set_slot(1, {
            value = signal_id,
            min = 0
        })
    else
        section.clear_slot(1)
    end
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

    local section = mooring.get_control_behavior().get_section(3)

    return section.get_slot(1).value
end
local function set_priority_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.priority_circuit_signal_id, settings_filter_name.priority_circuit_signal_id, mooring, 0)
    local section = mooring.get_control_behavior().get_section(3)

    if signal_id ~= nil then
        section.set_slot(1, {
            value = signal_id,
            min = 0
        })
    else
        section.clear_slot(1)
    end
end

local mooring_helper = {}

function mooring_helper.clean_settings(mooring)
    local cb = mooring.get_control_behavior()

    while cb.sections_count < 3 do
        cb.add_section()
    end
    while cb.sections_count > 3 do
        cb.remove_section(4)
    end

    for i = 1, 3 do
        local section = cb.get_section(i)

        section.active = false
        section.group = ""
    end
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

return mooring_helper
