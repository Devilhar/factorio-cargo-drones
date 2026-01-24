
data:extend({
	{
		type = "technology",
		name = "cargo-drones",
		icon = "__cargo-drone__/graphics/cargo-drone-icon-256x256.png",
		icon_size = 256,
		effects = {
			{
				type = "unlock-recipe",
				recipe = "cargo-drone"
			},
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-provider-mooring"
			},
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-requester-mooring"
			},
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-refuel-mooring"
			}
		},
		prerequisites = {
			"radar",
			"logistics-2",
			"low-density-structure"
		},
		unit =
		{
			count = 75,
			ingredients =
			{
				{"automation-science-pack", 1},
				{"logistic-science-pack", 1},
        		{"chemical-science-pack", 1}
			},
			time = 30
		}
	}
})
