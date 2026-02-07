
local signal_id_drone_limit = { type = "virtual", name = "signal-L" }
local signal_id_priority    = { type = "virtual", name = "signal-P" }

local mooring_helper = {}

function mooring_helper.get_drone_limit(mooring)
    local limit_signal = mooring.get_signal(signal_id_drone_limit, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal == 0 then
        return nil
    end

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function mooring_helper.get_priority(mooring)
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
