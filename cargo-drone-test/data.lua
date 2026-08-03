
local item_sounds = require("__base__.prototypes.item_sounds")

-- Create new drone

-- Any CarPrototype will do, but the mod makes a few assumptions.
-- If the following values are not set, the drone might not behave correctly:
--	allow_passengers = false
--	tank_driving = true

-- Furthermore, the mod asserts that all drones have the same inventory_size.
-- This is due to how task scheduling is implemented.

-- In this case, for simplicity, let's just copy cargo-drone.
local new_cargo_drone = table.deepcopy(data.raw.car["cargo-drone"])

-- Update values to point at our new drone.
local new_cargo_drone_entity_name = "new-cargo-drone"

new_cargo_drone.name = new_cargo_drone_entity_name
new_cargo_drone.icon =  "__cargo-drone-test__/graphics/cargo-drone-icon.png"
new_cargo_drone.animation.layers[1].stripes[1].filename = "__cargo-drone-test__/graphics/cargo-drone.png"
new_cargo_drone.minable = { mining_time = 0.4, result = new_cargo_drone_entity_name }

-- Let's make this one faster and more efficient than the base drone.
new_cargo_drone.consumption = "400kW"
new_cargo_drone.energy_source.effectivity = 1
new_cargo_drone.rotation_speed = 0.0020

-- Altough we can't increase inventory_size, fuel size can still be changed freely. The fuel inventory size settings only affect the base drone.
new_cargo_drone.energy_source.fuel_inventory_size = 4
new_cargo_drone.energy_source.burnt_inventory_size = 4

-- Standard item, nothing out of the ordinary here.
-- The only thing to bear in mind is that for items to be registered with the mod, they need to have the place_result value set to a drone identifier.
local new_cargo_drone_item = {
	type = "item-with-entity-data",
	name = "new-cargo-drone",
	icon = "__cargo-drone-test__/graphics/cargo-drone-icon.png",
	subgroup = "logistic-network",
	order = "g[cargo-drone]-a[cargo-drone]",
	inventory_move_sound = item_sounds.vehicle_inventory_move,
	pick_sound = item_sounds.vehicle_inventory_pickup,
	drop_sound = item_sounds.vehicle_inventory_move,
	place_result = "new-cargo-drone",
	stack_size = 1
}

-- Let's add what we've created.
data:extend{
	new_cargo_drone,
	new_cargo_drone_item,
}

-- Now we need to register our new drone so the mod knows to manage it.

local drone_shift = util.by_pixel(0, -284)
local drone_shadow_shift = util.by_pixel(383, -16)

-- The data needed. For explanation of what thees values mean, go to docs/modding.md in the cargo-drone Github repository.
local drone_data = {
	version = 1,
	cable = {
		attachment_offset = { x = 0, y = -9 },
		attachment_shadow_offset = { x = 14, y = 0 },
	},
	deployer = {
		body = {
			spawn_offset = { 0, -drone_shift[2] + 3.4 },
			prepare_offset = { 0, -drone_shift[2] + 0.4 },

			filename = "__cargo-drone-test__/graphics/cargo-drone.png",
			width = 502,
			height = 252,
			scale = 0.5,
			shift = drone_shift,
			positions = {
				north	= { 0, 125 },
				east	= { 0, 1004 + 125 },
				south	= { 0, 2008 + 125 },
				west	= { 0, 3012 + 125 },
			},
		},
		shadow = {
			prepare_offset = { -drone_shadow_shift[1], 0 },

			filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",
			width = 502,
			height = 502,
			scale = 0.5,
			shift = drone_shadow_shift,
			positions = {
				north	= { 0, 0 },
				east	= { 0, 1004 },
				south	= { 0, 2008 },
				west	= { 0, 3012 },
			},
		}
	}
}

-- Once created we can register it by adding the table we just created to the drones table using the entity name as key.
data.raw["mod-data"]["cargo-drone-drones"].data["new-cargo-drone"] = drone_data

-- All done. The drone is now ready.



-- As an additional step let's add a recipe. This is not used by the cargo-drone mod, this is just to make testing easier.
data:extend{
	{
		type = "recipe",
		name = "new-cargo-drone",
		enabled = true,
		energy_required = 1,
		ingredients =
		{
			{ type = "item", name = "wood", amount = 1 },
		},
		results = { { type = "item", name = "new-cargo-drone", amount = 1 } }
	}
}
