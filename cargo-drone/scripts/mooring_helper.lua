
local ep = require("scripts.entity_property")

local signal_id_drone_limit = { type = "virtual", name = "signal-L" }
local signal_id_priority    = { type = "virtual", name = "signal-P" }

local mooring_helper = {}

function mooring_helper.is_drone_limit_enabled(mooring)
    return ep.get_entity_property(mooring, "drone_limit_enabled") == true
end
function mooring_helper.set_drone_limit_enabled(mooring, flag)
    ep.set_entity_property(mooring, "drone_limit_enabled", flag)

    if not flag then
        ep.set_entity_property(mooring, "drone_limit_value", nil)
    end
end

function mooring_helper.get_drone_limit_value(mooring)
    return ep.get_entity_property(mooring, "drone_limit_value") or 0
end
function mooring_helper.set_drone_limit_value(mooring, value)
    ep.set_entity_property(mooring, "drone_limit_value", value)
end

function mooring_helper.get_drone_limit(mooring)
    if ep.get_entity_property(mooring, "drone_limit_enabled") then
        return ep.get_entity_property(mooring, "drone_limit_value") or 0
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
    return ep.get_entity_property(mooring, "priority_value") or 50
end
function mooring_helper.set_priority_value(mooring, value)
    if value < 0 then
        value = 0
    elseif value > 255 then
        value = 255
    end

    return ep.set_entity_property(mooring, "priority_value", value)
end

function mooring_helper.is_priority_circuit(mooring)
    return ep.get_entity_property(mooring, "priority_circuit") == true
end
function mooring_helper.set_priority_circuit(mooring, flag)
    ep.set_entity_property(mooring, "priority_circuit", flag)

    if flag then
        ep.set_entity_property(mooring, "priority_value", nil)
    end
end

function mooring_helper.get_priority(mooring)
    if not ep.get_entity_property(mooring, "priority_circuit") then
        return ep.get_entity_property(mooring, "priority_value") or 50
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
