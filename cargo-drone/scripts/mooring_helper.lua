
local signal_id_drone_limit = { type = "virtual", name = "signal-L" }

local mooring_helper = {}

function mooring_helper.get_drone_limit(mooring)
    local limit_signal = mooring.get_signal(signal_id_drone_limit, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal == 0 then
        -- Do you really need more? Think about it, do you really?
        return 1000000000
    end

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

return mooring_helper
