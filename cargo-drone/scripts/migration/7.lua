
local scheduler	= require("states.12.scheduler")

return function()
	storage.drone_controller = nil

	scheduler.init()
end
