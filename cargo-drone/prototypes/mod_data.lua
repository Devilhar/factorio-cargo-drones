
local mod_data = {
	type = "mod-data",
	name = "cargo-drone-data",
	data_type = "string",
	data = {
		drones = {},
		items = {}
	},
}

data:extend{
    mod_data
}