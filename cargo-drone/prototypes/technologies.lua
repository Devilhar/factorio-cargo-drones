
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
				recipe = "cargo-drone-mooring-constant-combinator-provider"
			},
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-mooring-constant-combinator-requester"
			},
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-mooring-constant-combinator-refueler"
			},
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-depot-constant-combinator"
			},
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
	},
	{
		type = "technology",
		name = "cargo-drone-deployer",
		icon = "__cargo-drone__/graphics/cargo-drone-deployer-icon-256x256.png",
		icon_size = 256,
		effects = {
			{
				type = "unlock-recipe",
				recipe = "cargo-drone-deployer-constant-combinator"
			},
		},
		prerequisites = {
			"cargo-drones",
			"concrete",
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
	},
})
