
local mod_data = {
	type = "mod-data",
	name = "cargo-drone-data",
	data_type = "string",
	data = {
		drones = {},
		items = {},
		burnt_results_enabled = false,
	},
}

data:extend{
    mod_data
}