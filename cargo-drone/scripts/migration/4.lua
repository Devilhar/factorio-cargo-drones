
local ep		= require("states.12.entity_property")

return function()
	ep.remove_invalid_entities()

	ep.reset_surface_indices()
end
