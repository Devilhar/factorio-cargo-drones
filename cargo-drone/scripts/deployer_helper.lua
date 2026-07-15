
local fh = require("filter_helper")

local signal_id_drone_limit = { type = "virtual", name = "signal-L", quality = "normal" }

local section_index = {
    settings    = 1,
    drone_limit = 2,
}

local setting_names = {
    drone_limit                     = "drone_limit",
    drone_limit_circuit             = "drone_limit_circuit",
    drone_limit_circuit_signal_id   = "drone_limit_circuit_signal_id",
}
local settings_filters = {
    [setting_names.drone_limit]                     = "signal-A",
    [setting_names.drone_limit_circuit]             = "signal-B",
    [setting_names.drone_limit_circuit_signal_id]   = "signal-C",
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

local function set_signal_id(target, index, signal_id, value)
    local section = target.get_control_behavior().get_section(index)

    fh.set_signal_id_value(section, signal_id, value)
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

local function clean_settings(deployer)
    local cb = deployer.get_control_behavior()

    while cb.sections_count < 2 do
        cb.add_section()
    end
    while cb.sections_count > 2 do
        cb.remove_section(3)
    end


end

local deployer_helper = {}

function deployer_helper.clean_settings(deployer)
    clean_settings(deployer)
end

function deployer_helper.get_drone_limit_value(target)
    return get_drone_limit(target) or 10
end
function deployer_helper.set_drone_limit_value(target, value)
    set_drone_limit(target, value)
end

function deployer_helper.is_drone_limit_circuit(target)
    return get_drone_limit_circuit(target)
end
function deployer_helper.set_drone_limit_circuit(target, flag)
    if flag then
        set_drone_limit(target, 0)
        set_drone_limit_circuit(target, true)
    else
        set_drone_limit_circuit(target, false)
    end
end

function deployer_helper.get_drone_limit_circuit_signal_id(target)
    return get_drone_limit_circuit_signal_id(target)
end
function deployer_helper.set_drone_limit_circuit_signal_id(target, signal_id)
    set_drone_limit_circuit_signal_id(target, signal_id)
end

function deployer_helper.get_drone_limit(target)
    if not get_drone_limit_circuit(target) then
        return get_drone_limit(target) or 10
    end

    local signal_id = get_drone_limit_circuit_signal_id(target)

    if signal_id == nil then
        return 10
    end

    local limit_signal = target.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

return deployer_helper
