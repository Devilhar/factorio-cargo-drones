
-- This code was supposed to be run in patch 13
-- But it was misplaced and placed inside its mooring migration meaning it was not run if there were no moorings placed anywhere
return function()
	storage.depots = nil

    storage.depot_helper = storage.depot_helper or {}

    storage.depot_helper.depots = storage.depot_helper.depots or {}
end
