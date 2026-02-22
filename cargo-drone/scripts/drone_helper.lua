
local ep = require("scripts.entity_property")

local drone_helper = {}

function drone_helper.get_docked_mooring(drone)
    return ep.get_entity_property(drone, "docked_mooring")
end
function drone_helper.get_queuing_mooring(drone)
    return ep.get_entity_property(drone, "queuing_mooring")
end

return drone_helper
