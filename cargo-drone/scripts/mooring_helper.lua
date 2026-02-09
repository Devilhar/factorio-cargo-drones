
local signal_id_drone_limit = { type = "virtual", name = "signal-L" }
local signal_id_priority    = { type = "virtual", name = "signal-P" }

local settings_index = {
    drone_limit = 1,
    priority = 2,
    priority_circuit = 3,
}

local function get_section(mooring)
    local cb = mooring.get_control_behavior()

    return cb.get_section(1)
end

local function set_filter_value(index, filter_name, mooring, limit)
    local section = get_section(mooring)

    if limit ~= nil then
        section.set_slot(index, {
            value = {
                type = "virtual",
                name = filter_name,
                quality = "normal",
            },
            min = limit
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
    set_filter_value(settings_index.drone_limit, "signal-L", mooring, limit)
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

local function set_priority(mooring, limit)
    set_filter_value(settings_index.priority, "signal-P", mooring, limit)
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

local function set_priority_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.priority_circuit, "signal-C", mooring, 0)
    else
        set_filter_value(settings_index.priority_circuit, "signal-C", mooring, nil)
    end
end
local function get_priority_circuit(mooring)
    return get_filter_value(settings_index.priority_circuit, mooring) ~= nil
end

local mooring_helper = {}

function mooring_helper.clean_settings(mooring)
    local cb = mooring.get_control_behavior()

    if cb.sections_count < 1 then
        cb.add_section()
    elseif cb.sections_count > 1 then
        while cb.sections_count > 1 do
            cb.remove_section(2)
        end
    end

    local section = cb.get_section(1)

    section.active = false
    section.group = ""
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

function mooring_helper.get_drone_limit(mooring)
    local drone_limit = get_drone_limit(mooring)

    if drone_limit ~= nil then
        return drone_limit
    end

    local limit_signal = mooring.get_signal(signal_id_drone_limit, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal == 0 then
        return nil
    end

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function mooring_helper.get_priority_value(mooring)
    return get_priority(mooring) or 50
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
        set_priority(mooring, 50)
        set_priority_circuit(mooring, false)
    end
end

function mooring_helper.get_priority(mooring)
    if not get_priority_circuit(mooring) then
        return get_priority(mooring)
    end

    local priority = mooring.get_signal(signal_id_priority, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if priority < 0 then
        return 0
    end

    if priority >= 256 then
        return 255
    end

    return priority
end

return mooring_helper
