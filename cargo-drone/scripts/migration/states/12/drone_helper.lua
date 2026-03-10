
local ep = require("entity_property")

local drone_helper = {}

function drone_helper.get_docked_mooring(drone)
    return ep.get_entity_property(drone, "docked_mooring")
end
function drone_helper.get_docking_mooring(drone)
    return ep.get_entity_property(drone, "docking_mooring")
end
function drone_helper.get_queuing_mooring(drone)
    return ep.get_entity_property(drone, "queuing_mooring")
end
function drone_helper.get_parked_depot(drone)
    return ep.get_entity_property(drone, "parked_depot")
end

return drone_helper
