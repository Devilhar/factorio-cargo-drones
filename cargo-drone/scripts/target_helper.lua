
local name_list = require("name_list")
local ccse      = require("cc_string_encoder")
local ep        = require("entity_property")
local fh        = require("filter_helper")

local signal_id_drone_limit     = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_priority        = { type = "virtual", name = "signal-P", quality = "normal" }
local signal_id_drone_count     = { type = "virtual", name = "signal-C", quality = "normal" }

local section_index = {
    settings                        = 1,
    drone_limit                     = 2,
    priority_circuit                = 3,
    drone_count                     = 4,
    name_filters                    = 5,
    name                            = 6,
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

-- The max bytes, divided by the minimum length of a icon: [item=a]
local max_icons_in_name = 18

-- Offset the bits so that the numbers are less likely to collide with other numbers when altering parameters in blueprints.
local name_icon_instance_offset = 10

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

local function set_signal_id(target, index, signal_id, value)
    local section = target.get_control_behavior().get_section(index)

    fh.set_signal_id_value(section, signal_id, value)
end

local function get_name_from_section(target)
    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.name)

    return ccse.decode(section)
end
local function get_name(target)
    return ep.get_entity_property(target, "target_name") or ""
end
local function set_name(target, name)
    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.name)

    ccse.encode(name, section)

    ep.set_entity_property(target, "target_name", get_name_from_section(target))
end

-- The icons used in names are a bit magical. These functions are here to allow the user to change icons in the name when making changes to blueprint parameters.
local function get_first_filter_instances(name)
    local first_instances = {}
    local last_begin = -1
    local last_assign = -1
    local char = ""
    local instance = 0

    for i = 1, #name do
        char = string.sub(name, i, i)

        if char == "[" then
            last_begin = i
        elseif last_begin ~= -1 and char == "=" then
            if last_assign == -1 then
                last_assign = i
            else
                last_begin = -1
            end
        elseif last_assign ~= -1 and char == "]" then
            local filter = string.sub(name, last_begin, i)
            instance = instance + 1

            if first_instances[filter] == nil then
                first_instances[filter] = { last_begin, last_assign, i, instance }
            end

            last_begin = -1
            last_assign = -1
        end
    end

    return first_instances
end
local function get_filter_instances(name)
    local instances = {}
    local last_begin = -1
    local last_assign = -1
    local instance = 0

    for i = 1, #name do
        local char = string.sub(name, i, i)

        if char == "[" then
            last_begin = i
        elseif last_begin ~= -1 and char == "=" then
            if last_assign == -1 then
                last_assign = i
            else
                last_begin = -1
            end
        elseif last_assign ~= -1 and char == "]" then
            local filter = string.sub(name, last_begin, i)
            instance = instance + 1

            instances[instance] = { filter, last_begin, i }

            last_begin = -1
            last_assign = -1
        end
    end

    return instances
end
local function update_name_filters(target)
    local type_map = {
        ["item"]            = { type = "item",      prototype = "item" },
        ["fluid"]           = { type = "fluid",     prototype = "fluid" },
        ["virtual-signal"]  = { type = "virtual",   prototype = "virtual_signal" },
        ["entity"]          = { type = "entity",    prototype = "entity" },
    }
    local name = get_name(target)

    local first_instances = get_first_filter_instances(name)
    local filters = {}

    for _, indices in pairs(first_instances) do
        local type_data = type_map[string.sub(name, indices[1] + 1, indices[2] - 1)]

        if type_data ~= nil then
            local f_name = string.sub(name, indices[2] + 1, indices[3] - 1)

            if prototypes[type_data.prototype][f_name] ~= nil then
                local shifted_instance = math.pow(2, name_icon_instance_offset)

                for _ = 1, max_icons_in_name - indices[4] do
                    shifted_instance = shifted_instance * 2
                end

                table.insert(filters, {
                    value = {
                        type = type_data.type,
                        name = f_name,
                        quality = "normal",
                    },
                    min = shifted_instance
                })
            end
        end
    end

    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.name_filters)

    section.filters = filters
end
local function get_updated_name_from_filters(section, name)
    local filter_instances = {}

    for _, filter in ipairs(section.filters) do
        if filter.value then
            local shifted_instance = filter.min

            for _ = 1, name_icon_instance_offset do
                shifted_instance = math.floor(shifted_instance / 2)
            end

            for instance = max_icons_in_name, 1, -1 do
                if shifted_instance % 2 == 1 then
                    filter_instances[instance] = "[" .. filter.value.type .. "=" .. filter.value.name .. "]"
                end

                shifted_instance = math.floor(shifted_instance / 2)
            end
        end
    end

    local instances = get_filter_instances(name)
    local replacements = {}

    for instance, filter in pairs(filter_instances) do
        if instances[instance] then
            replacements[instances[instance][1]] = filter
        end
    end

    for instance = max_icons_in_name, 1, -1 do
        if instances[instance] then
            local replacement_filter = replacements[instances[instance][1]]

            if replacement_filter ~= instances[instance][1] then
                local replace_begin = instances[instance][2]
                local replace_end = instances[instance][3]

                if replacement_filter == nil then
                    name = string.sub(name, 1, replace_begin - 1) .. string.sub(name, replace_end + 1)
                else
                    name = string.sub(name, 1, replace_begin - 1) .. replacement_filter .. string.sub(name, replace_end + 1)
                end
            end
        end
    end

    return name
end
local function update_name(target)
    local cb = target.get_control_behavior()

    local section_name = cb.get_section(section_index.name)

    local name = ccse.decode(section_name)

    if name == "" then
        name = name_list[math.random(#name_list)]
    end

    name = get_updated_name_from_filters(cb.get_section(section_index.name_filters), name)

    ccse.encode(name, section_name)
    ep.set_entity_property(target, "target_name", name)

    update_name_filters(target)
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
    set_signal_id(target, section_index.drone_limit, signal_id, 0)
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
    set_signal_id(target, section_index.priority_circuit, signal_id, 0)
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

local function get_drone_count_output(target)
    if not get_drone_count_circuit(target) then
        return 0
    end

    return get_drone_count(target)
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
    set_signal_id(target, section_index.drone_count, signal_id, get_drone_count_output(target))
end

local function update_drone_count_output(target)
    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.drone_count)

    local signal_id = get_drone_count_circuit_signal_id(target)

    if not signal_id then
        return
    end

    local count = get_drone_count_output(target)

    section.filters = {
        {
            value = signal_id,
            min = count
        }
    }
end

local function clean_sections(control_behavior)
    for i = 1, 6 do
        local section = control_behavior.get_section(i)

        section.active = false
        section.group = ""
    end

    control_behavior.get_section(section_index.drone_count).active = true
end
local function clear_all_outputs(target)
    local cb = target.get_control_behavior()

    local section = cb.get_section(section_index.drone_count)

    local signal_filter = section.filters[1]

    if not signal_filter or not signal_filter.value then
        return
    end

    section.filters = {
        {
            value = signal_filter.value,
            min = 0
        }
    }
end
local function clean_settings(target)
    local cb = target.get_control_behavior()

    clean_sections(cb)

    clear_all_outputs(target)

    update_drone_count_output(target)
    update_name(target)
end

local target_helper = {}

function target_helper.clean_settings(target)
    clean_settings(target)
end
function target_helper.clear_all_outputs(target)
    clear_all_outputs(target)
end

function target_helper.get_name(target)
    return get_name(target)
end
function target_helper.set_name(target, name)
    set_name(target, name)

    update_name_filters(target)
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
