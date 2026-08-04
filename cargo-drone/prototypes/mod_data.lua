
local drones = {
	type = "mod-data",
	name = "cargo-drone-drones",
	data_type = "{String, DroneData}",
	data = {},
}

local cargo_drone_data = {
	type = "mod-data",
	name = "cargo-drone-mod-data",
	data_type = "string",
	data = {
		-- The following values exist after data-final-fixes has run.

		-- Array[string] of all items with a place_result for a drone.
		-- All items are automatically found, no need to add it manually.
		-- items = {},

		-- The inventory size of all drones.
		-- inventory_size = 10,

		-- If any drone has burnt results inventory size larger than 0.
		-- burnt_results_enabled = false,
	},
}

data:extend{
    drones,
	cargo_drone_data,
}
