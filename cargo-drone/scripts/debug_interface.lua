
if not settings.startup["cargo-drone-debug-mode"].value then
    return
end

local ep = require("scripts.entity_property")

-- This interface is used for debugging and is incredibly volatile.
-- Any function here may change in any update for any reason and without warning.
remote.add_interface("cargo-drone-debug", {
    get_tickrate = function(unit_number)
        return ep.get_entity_property_from_unit_number(unit_number, "tickrate")
    end,
})
