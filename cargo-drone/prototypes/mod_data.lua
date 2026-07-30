
local mod_data = {
	type = "mod-data",
	name = "cargo-drone-data",
	data_type = "string",
	data = {
		drones = {
            --[[
			{
				name = "cargo-drone",
				-- Sprite used by the deployer to represent this drone
				deployer_sprites = {
					sprite = "__cargo-drone__/graphics/cargo-drone.png",
					shadow = "__cargo-drone__/graphics/cargo-drone-shadow.png",
				},
			},
            ]]
		},
	},
}

data:extend{
    mod_data
}