
local ep        = require("entity_property")
local fh        = require("filter_helper")

local signal_id_drone_limit     = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_priority        = { type = "virtual", name = "signal-P", quality = "normal" }
local signal_id_drone_count     = { type = "virtual", name = "signal-C", quality = "normal" }

local section_index = {
    settings                        = 1,
    output                          = 2,
    drone_limit                     = 3,
    priority_circuit                = 4,
    drone_count                     = 5,
}

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
local settings_filters = {
    [setting_names.drone_limit]                     = "signal-A",
    [setting_names.drone_limit_circuit]             = "signal-B",
    [setting_names.drone_limit_circuit_signal_id]   = "signal-C",
    [setting_names.priority]                        = "signal-D",
    [setting_names.priority_circuit]                = "signal-E",
    [setting_names.priority_circuit_signal_id]      = "signal-F",
    [setting_names.drone_count_circuit]             = "signal-G",
    [setting_names.drone_count_signal_id]           = "signal-H",
}

-- NOTE: Some mods like "Sort me" causes filters to be condensed and sorted. Meaning this will break should there be more than one output index.
-- Also note that if two outputs has the same signal id, this implementation will also break.
-- The fix would be to keep track of what is being outputted by what, and update the signal id rather than the index. But this would be overcomplex for now.
local output_index = {
    drone_count                     = 1,
}

local function get_settings_section(target)
    local cb = target.get_control_behavior()

    return cb.get_section(section_index.settings)
end

local function set_settings_value(target, setting_name, value)
    fh.set_filter_value(get_settings_section(target), settings_filters[setting_name], value)
end
local function get_settings_value(target, setting_name)
    return fh.get_filter_value(get_settings_section(target), settings_filters[setting_name])
end

local function set_signal_id(target, index, signal_id)
    local section = target.get_control_behavior().get_section(index)

    if signal_id == nil then
        section.filters = {}

        return
    end

    section.filters = {
        {
            value = {
                type = signal_id.type,
                name = signal_id.name,
                quality = signal_id.quality or "normal",
            },
            min = 0
        }
    }
end

local function set_drone_limit(target, limit)
    set_settings_value(target, setting_names.drone_limit, limit)
end
local function get_drone_limit(target)
    local limit = get_settings_value(target, setting_names.drone_limit)

    if limit == nil then
        return nil
    end

    if limit < 0 then
        limit = 0
    end

    return limit
end

local function get_drone_limit_circuit(target)
    return get_settings_value(target, setting_names.drone_limit_circuit) ~= nil
end
local function set_drone_limit_circuit(target, flag)
    if flag then
        set_settings_value(target, setting_names.drone_limit_circuit, 0)
    else
        set_settings_value(target, setting_names.drone_limit_circuit, nil)
    end
end

local function get_drone_limit_circuit_signal_id(target)
    if get_settings_value(target, setting_names.drone_limit_circuit_signal_id) == nil then
        return signal_id_drone_limit
    end

    local section = target.get_control_behavior().get_section(section_index.drone_limit)

    return section.get_slot(1).value
end
local function set_drone_limit_circuit_signal_id(target, signal_id)
    set_settings_value(target, setting_names.drone_limit_circuit_signal_id, 0)
    set_signal_id(target, section_index.drone_limit, signal_id)
end

local function get_priority(target)
    local priority = get_settings_value(target, setting_names.priority) or 50

    if priority < 0 then
        priority = 0
    elseif priority > 255 then
        priority = 255
    end

    return priority
end
local function set_priority(target, limit)
    set_settings_value(target, setting_names.priority, limit)
end

local function get_priority_circuit(target)
    return get_settings_value(target, setting_names.priority_circuit) ~= nil
end
local function set_priority_circuit(target, flag)
    if flag then
        set_settings_value(target, setting_names.priority_circuit, 0)
    else
        set_settings_value(target, setting_names.priority_circuit, nil)
    end
end

local function get_priority_circuit_signal_id(target)
    if get_settings_value(target, setting_names.priority_circuit_signal_id) == nil then
        return signal_id_priority
    end

    local section = target.get_control_behavior().get_section(section_index.priority_circuit)

    return section.get_slot(1).value
end
local function set_priority_circuit_signal_id(target, signal_id)
    set_settings_value(target, setting_names.priority_circuit_signal_id, 0)
    set_signal_id(target, section_index.priority_circuit, signal_id)
end

local function get_drone_count(target)
    return ep.get_entity_property(target, "drone_count") or 0
end
local function set_drone_count(target, count)
    if count <= 0 then
        count = nil
    end

    ep.set_entity_property(target, "drone_count", count)
end

local function get_drone_count_circuit(target)
    return get_settings_value(target, setting_names.drone_count_circuit) ~= nil
end
local function set_drone_count_circuit(target, flag)
    if flag then
        set_settings_value(target, setting_names.drone_count_circuit, 0)
    else
        set_settings_value(target, setting_names.drone_count_circuit, nil)
    end
end

local function get_drone_count_circuit_signal_id(target)
    if get_settings_value(target, setting_names.drone_count_signal_id) == nil then
        return signal_id_drone_count
    end

    local section = target.get_control_behavior().get_section(section_index.drone_count)

    return section.get_slot(1).value
end
local function set_drone_count_circuit_signal_id(target, signal_id)
    set_settings_value(target, setting_names.drone_count_signal_id, 0)
    set_signal_id(target, section_index.drone_count, signal_id)
end

local function update_drone_count_output(target)
    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.output)

    if not get_drone_count_circuit(target) then
        section.clear_slot(output_index.drone_count)

        return
    end

    local signal_id = get_drone_count_circuit_signal_id(target)
    local count = get_drone_count(target)

    if signal_id == nil or count == 0 then
        section.clear_slot(output_index.drone_count)

        return
    end

    section.set_slot(output_index.drone_count, {
        value = signal_id,
        min = count
    })
end

local function clean_sections(control_behavior)
    for i = 1, 5 do
        local section = control_behavior.get_section(i)

        section.active = false
        section.group = ""
    end

    control_behavior.get_section(section_index.output).active = true
end
local function clear_all_outputs(target)
    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.output)

    section.filters = {}
end
local function clean_settings(target)
    local cb = target.get_control_behavior()

    clean_sections(cb)

    clear_all_outputs(target)

    update_drone_count_output(target)
end

local target_helper = {}

function target_helper.clean_settings(target)
    clean_settings(target)
end
function target_helper.clear_all_outputs(target)
    clear_all_outputs(target)
end

function target_helper.is_drone_limit_enabled(target)
    return get_drone_limit(target) ~= nil
end
function target_helper.set_drone_limit_enabled(target, flag)
    if flag then
        set_drone_limit(target, 0)
    else
        set_drone_limit(target, nil)
    end
end

function target_helper.get_drone_limit_value(target)
    return get_drone_limit(target) or 0
end
function target_helper.set_drone_limit_value(target, value)
    set_drone_limit(target, value)
end

function target_helper.is_drone_limit_circuit(target)
    return get_drone_limit_circuit(target)
end
function target_helper.set_drone_limit_circuit(target, flag)
    if flag then
        set_drone_limit(target, 0)
        set_drone_limit_circuit(target, true)
    else
        set_drone_limit_circuit(target, false)
    end
end

function target_helper.get_drone_limit_circuit_signal_id(target)
    return get_drone_limit_circuit_signal_id(target)
end
function target_helper.set_drone_limit_circuit_signal_id(target, signal_id)
    set_drone_limit_circuit_signal_id(target, signal_id)
end

function target_helper.get_drone_limit(target)
    if not get_drone_limit_circuit(target) then
        return get_drone_limit(target)
    end

    local signal_id = get_drone_limit_circuit_signal_id(target)

    if signal_id == nil then
        return 0
    end

    local limit_signal = target.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function target_helper.get_priority_value(target)
    return get_priority(target)
end
function target_helper.set_priority_value(target, value)
    if value < 0 then
        value = 0
    elseif value > 255 then
        value = 255
    end

    set_priority(target, value)
end

function target_helper.is_priority_circuit(target)
    return get_priority_circuit(target)
end
function target_helper.set_priority_circuit(target, flag)
    if flag then
        set_priority(target, nil)
        set_priority_circuit(target, true)
    else
        set_priority_circuit(target, false)
    end
end

function target_helper.get_priority_circuit_signal_id(target)
    return get_priority_circuit_signal_id(target)
end
function target_helper.set_priority_circuit_signal_id(target, signal_id)
    set_priority_circuit_signal_id(target, signal_id)
end

function target_helper.get_priority(target)
    if not get_priority_circuit(target) then
        return get_priority(target)
    end

    local signal_id = get_priority_circuit_signal_id(target)

    if signal_id == nil then
        return 0
    end

    local priority = target.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if priority < 0 then
        return 0
    end

    if priority >= 256 then
        return 255
    end

    return priority
end

function target_helper.get_drone_count(target)
    return get_drone_count(target)
end
function target_helper.set_drone_count(target, value)
    if value < 0 then
        value = 0
    end

    set_drone_count(target, value)

    update_drone_count_output(target)
end

function target_helper.is_drone_count_circuit(target)
    return get_drone_count_circuit(target)
end
function target_helper.set_drone_count_circuit(target, flag)
    set_drone_count_circuit(target, flag)

    update_drone_count_output(target)
end

function target_helper.get_drone_count_circuit_signal_id(target)
    return get_drone_count_circuit_signal_id(target)
end
function target_helper.set_drone_count_circuit_signal_id(target, signal_id)
    set_drone_count_circuit_signal_id(target, signal_id)

    update_drone_count_output(target)
end

function target_helper.is_at_drone_limit(target)
    local drone_limit = target_helper.get_drone_limit(target)

    if drone_limit == nil then
        return false
    end

    local target_count = get_drone_count(target)

    return target_count >= drone_limit
end

return target_helper
