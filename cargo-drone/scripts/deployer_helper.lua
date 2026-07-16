
local ep = require("entity_property")
local fh = require("filter_helper")

local signal_id_drone_limit             = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_drone_count             = { type = "virtual", name = "signal-C", quality = "normal" }
local signal_id_available_drone_count   = { type = "virtual", name = "signal-A", quality = "normal" }

local section_index = {
    settings                = 1,
    drone_limit             = 2,
    drone_count             = 3,
    available_drone_count   = 4,
}

local setting_names = {
    drone_limit                             = "drone_limit",
    drone_limit_circuit                     = "drone_limit_circuit",
    drone_limit_circuit_signal_id           = "drone_limit_circuit_signal_id",
    drone_count_circuit                     = "drone_count_circuit",
    drone_count_circuit_signal_id           = "drone_count_circuit_signal_id",
    available_drone_count_circuit           = "available_drone_count_circuit",
    available_drone_count_circuit_signal_id = "available_drone_count_circuit_signal_id",
}
local settings_filters = {
    [setting_names.drone_limit]                             = "signal-A",
    [setting_names.drone_limit_circuit]                     = "signal-B",
    [setting_names.drone_limit_circuit_signal_id]           = "signal-C",
    [setting_names.drone_count_circuit]                     = "signal-D",
    [setting_names.drone_count_circuit_signal_id]           = "signal-E",
    [setting_names.available_drone_count_circuit]           = "signal-F",
    [setting_names.available_drone_count_circuit_signal_id] = "signal-G",
}

local function get_settings_section(deployer)
    local cb = deployer.get_control_behavior()

    return cb.get_section(section_index.settings)
end

local function set_settings_value(deployer, setting_name, value)
    fh.set_filter_value(get_settings_section(deployer), settings_filters[setting_name], value)
end
local function get_settings_value(deployer, setting_name)
    return fh.get_filter_value(get_settings_section(deployer), settings_filters[setting_name])
end

local function set_signal_id(deployer, index, signal_id, value)
    local section = deployer.get_control_behavior().get_section(index)

    fh.set_signal_id_value(section, signal_id, value)
end

local function set_drone_limit(deployer, limit)
    set_settings_value(deployer, setting_names.drone_limit, limit)
end
local function get_drone_limit(deployer)
    local limit = get_settings_value(deployer, setting_names.drone_limit)

    if limit == nil then
        return nil
    end

    if limit < 0 then
        limit = 0
    end

    return limit
end

local function get_drone_limit_circuit(deployer)
    return get_settings_value(deployer, setting_names.drone_limit_circuit) ~= nil
end
local function set_drone_limit_circuit(deployer, flag)
    if flag then
        set_settings_value(deployer, setting_names.drone_limit_circuit, 0)
    else
        set_settings_value(deployer, setting_names.drone_limit_circuit, nil)
    end
end

local function get_drone_limit_circuit_signal_id(deployer)
    if get_settings_value(deployer, setting_names.drone_limit_circuit_signal_id) == nil then
        return signal_id_drone_limit
    end

    local section = deployer.get_control_behavior().get_section(section_index.drone_limit)

    return section.get_slot(1).value
end
local function set_drone_limit_circuit_signal_id(deployer, signal_id)
    set_settings_value(deployer, setting_names.drone_limit_circuit_signal_id, 0)
    set_signal_id(deployer, section_index.drone_limit, signal_id, 0)
end

local function get_drone_count_circuit(deployer)
    return get_settings_value(deployer, setting_names.drone_count_circuit) ~= nil
end
local function set_drone_count_circuit(deployer, flag)
    if flag then
        set_settings_value(deployer, setting_names.drone_count_circuit, 0)
    else
        set_settings_value(deployer, setting_names.drone_count_circuit, nil)
    end
end

local function get_drone_count_circuit_signal_id(deployer)
    if get_settings_value(deployer, setting_names.drone_count_circuit_signal_id) == nil then
        return signal_id_drone_count
    end

    local section = deployer.get_control_behavior().get_section(section_index.drone_count)

    return section.get_slot(1).value
end
local function set_drone_count_circuit_signal_id(deployer, signal_id)
    set_settings_value(deployer, setting_names.drone_count_circuit_signal_id, 0)
    set_signal_id(deployer, section_index.drone_count, signal_id, 0)
end

local function get_drone_count(deployer)
    return ep.get_entity_property(deployer, "drone_count") or 0
end
local function get_drone_count_output(deployer)
    if not get_drone_count_circuit(deployer) then
        return 0
    end

    return get_drone_count(deployer)
end

local function update_drone_count_output(deployer)
    local cb = deployer.get_control_behavior()

    local section = cb.get_section(section_index.drone_count)

    local signal_id = get_drone_count_circuit_signal_id(deployer)

    if not signal_id then
        return
    end

    local count = get_drone_count_output(deployer)

    section.filters = {
        {
            value = signal_id,
            min = count
        }
    }
end

local function get_available_drone_count_circuit(deployer)
    return get_settings_value(deployer, setting_names.available_drone_count_circuit) ~= nil
end
local function set_available_drone_count_circuit(deployer, flag)
    if flag then
        set_settings_value(deployer, setting_names.available_drone_count_circuit, 0)
    else
        set_settings_value(deployer, setting_names.available_drone_count_circuit, nil)
    end
end

local function get_available_drone_count_circuit_signal_id(deployer)
    if get_settings_value(deployer, setting_names.available_drone_count_circuit_signal_id) == nil then
        return signal_id_available_drone_count
    end

    local section = deployer.get_control_behavior().get_section(section_index.available_drone_count)

    return section.get_slot(1).value
end
local function set_available_drone_count_circuit_signal_id(deployer, signal_id)
    set_settings_value(deployer, setting_names.available_drone_count_circuit_signal_id, 0)
    set_signal_id(deployer, section_index.available_drone_count, signal_id, 0)
end

local function get_available_drone_count(deployer)
    return ep.get_entity_property(deployer, "available_drone_count") or 0
end
local function get_available_drone_count_output(deployer)
    if not get_available_drone_count_circuit(deployer) then
        return 0
    end

    return get_available_drone_count(deployer)
end

local function update_available_drone_count_output(deployer)
    local cb = deployer.get_control_behavior()

    local section = cb.get_section(section_index.available_drone_count)

    local signal_id = get_available_drone_count_circuit_signal_id(deployer)

    if not signal_id then
        return
    end

    local count = get_available_drone_count_output(deployer)

    section.filters = {
        {
            value = signal_id,
            min = count
        }
    }
end

local function clear_all_outputs(deployer)
    local cb = deployer.get_control_behavior()

    local section = cb.get_section(section_index.drone_count)

    local signal_filter = section.filters[1]

    if signal_filter and signal_filter.value then
        section.filters = {
            {
                value = signal_filter.value,
                min = 0
            }
        }
    end

    section = cb.get_section(section_index.available_drone_count)

    signal_filter = section.filters[1]

    if signal_filter and signal_filter.value then
        section.filters = {
            {
                value = signal_filter.value,
                min = 0
            }
        }
    end
end

local function clean_settings(deployer)
    local cb = deployer.get_control_behavior()

    while cb.sections_count < 4 do
        cb.add_section()
    end
    while cb.sections_count > 4 do
        cb.remove_section(5)
    end

    for i = 1, 4 do
        local section = cb.get_section(i)

        section.active = false
        section.group = ""
    end

    clear_all_outputs(deployer)

    cb.get_section(section_index.drone_count).active = true
    cb.get_section(section_index.available_drone_count).active = true

    update_drone_count_output(deployer)
    update_available_drone_count_output(deployer)
end

local deployer_helper = {}

function deployer_helper.clean_settings(deployer)
    clean_settings(deployer)
end

function deployer_helper.get_drone_limit_value(deployer)
    return get_drone_limit(deployer) or 10
end
function deployer_helper.set_drone_limit_value(deployer, value)
    set_drone_limit(deployer, value)
end

function deployer_helper.is_drone_limit_circuit(deployer)
    return get_drone_limit_circuit(deployer)
end
function deployer_helper.set_drone_limit_circuit(deployer, flag)
    if flag then
        set_drone_limit(deployer, 0)
        set_drone_limit_circuit(deployer, true)
    else
        set_drone_limit_circuit(deployer, false)
    end
end

function deployer_helper.get_drone_limit_circuit_signal_id(deployer)
    return get_drone_limit_circuit_signal_id(deployer)
end
function deployer_helper.set_drone_limit_circuit_signal_id(deployer, signal_id)
    set_drone_limit_circuit_signal_id(deployer, signal_id)
end

function deployer_helper.get_drone_limit(deployer)
    if not get_drone_limit_circuit(deployer) then
        return get_drone_limit(deployer) or 10
    end

    local signal_id = get_drone_limit_circuit_signal_id(deployer)

    if signal_id == nil then
        return 10
    end

    local limit_signal = deployer.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function deployer_helper.is_drone_count_circuit(deployer)
    return get_drone_count_circuit(deployer)
end
function deployer_helper.set_drone_count_circuit(deployer, flag)
    set_drone_count_circuit(deployer, flag)

    update_drone_count_output(deployer)
end

function deployer_helper.get_drone_count_circuit_signal_id(deployer)
    return get_drone_count_circuit_signal_id(deployer)
end
function deployer_helper.set_drone_count_circuit_signal_id(deployer, signal_id)
    set_drone_count_circuit_signal_id(deployer, signal_id)

    update_drone_count_output(deployer)
end

function deployer_helper.set_drone_count(deployer, drone_count)
    ep.set_entity_property(deployer, "drone_count", drone_count)

    update_drone_count_output(deployer)
end

function deployer_helper.is_available_drone_count_circuit(deployer)
    return get_available_drone_count_circuit(deployer)
end
function deployer_helper.set_available_drone_count_circuit(deployer, flag)
    set_available_drone_count_circuit(deployer, flag)

    update_available_drone_count_output(deployer)
end

function deployer_helper.get_available_drone_count_circuit_signal_id(deployer)
    return get_drone_count_circuit_signal_id(deployer)
end
function deployer_helper.set_available_drone_count_circuit_signal_id(deployer, signal_id)
    set_available_drone_count_circuit_signal_id(deployer, signal_id)

    update_available_drone_count_output(deployer)
end

function deployer_helper.set_available_drone_count(deployer, drone_count)
    ep.set_entity_property(deployer, "available_drone_count", drone_count)

    update_available_drone_count_output(deployer)
end

return deployer_helper
