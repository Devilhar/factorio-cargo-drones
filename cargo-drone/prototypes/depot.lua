
local hit_effects	= require("__base__.prototypes.entity.hit-effects")
local sounds		= require("__base__.prototypes.entity.sounds")
local item_sounds	= require("__base__.prototypes.item_sounds")

local util			= require("util")

local function merge_tables(placeholder, overwrite_table)
	for k, v in pairs(overwrite_table) do
		placeholder[k] = v
	end

	return placeholder
end

local depot_circuit_wire_connection_point = {
	shadow = {
		red = util.by_pixel(12, 15),
		green = util.by_pixel(14, 15)
	},
	wire = {
		red = util.by_pixel(8, -17),
		green = util.by_pixel(10, -12)
	}
}

local depot_entity = merge_tables(table.deepcopy(data.raw["constant-combinator"]["constant-combinator"]), {
	name = "cargo-drone-depot-constant-combinator",
	icon = "__cargo-drone__/graphics/cargo-drone-depot-icon.png",
	minable = { mining_time = 2, result = "cargo-drone-depot-constant-combinator" },
	flags = { "hide-alt-info", "not-upgradable", "placeable-neutral", "player-creation" },
	max_health = 350,
	collision_box = {{-0.85, -0.85}, {0.85, 0.85}},
	selection_box = {{-1.0, -1.0}, {1.0, 1.0}},
	impact_category = "metal",
	icon_draw_specification = {scale = 0.7},
	corpse = "steel-chest-remnants",
	dying_explosion = "steel-chest-explosion",
	open_sound = sounds.metallic_chest_open,
	close_sound = sounds.metallic_chest_close,
	resistances = {
		{
			type = "fire",
			percent = 90
		},
		{
			type = "impact",
			percent = 60
		}
	},
	sprites = {
		layers = {
			{
				filename = "__cargo-drone__/graphics/cargo-drone-depot.png",
				priority = "low",
				width = 128,
				height = 128,
				shift = util.by_pixel(0, 0),
				scale = 0.5
			},
			{
				filename = "__cargo-drone__/graphics/cargo-drone-depot-shadow.png",
				priority = "low",
				width = 192,
				height = 128,
				shift = util.by_pixel(17, 4),
				draw_as_shadow = true,
				scale = 0.475
			}
		}
	},
	circuit_wire_connection_points = {
		depot_circuit_wire_connection_point,
		depot_circuit_wire_connection_point,
		depot_circuit_wire_connection_point,
		depot_circuit_wire_connection_point
	},
	circuit_connector = circuit_connector_definitions["chest"],
	circuit_wire_max_distance = default_circuit_wire_max_distance
})

local depot_item = {
	type = "item",
	name = "cargo-drone-depot-constant-combinator",
	icon = "__cargo-drone__/graphics/cargo-drone-depot-icon.png",
	subgroup = "logistic-network",
	order = "g[cargo-drone]-e[cargo-drone-depot-constant-combinator]",
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = "cargo-drone-depot-constant-combinator",
	stack_size = 50
}
local depot_recipe = {
	type = "recipe",
	name = "cargo-drone-depot-constant-combinator",
	enabled = false,
	ingredients = {
		{ type = "item", name = "steel-plate", amount = 20 },
		{ type = "item", name = "radar", amount = 1 }
	},
	results = {{type="item", name="cargo-drone-depot-constant-combinator", amount=1}}
}

local depot_cable_sprite = {
	type = "sprite",
	name = "cargo-drone-depot-cable",
	filename = "__cargo-drone__/graphics/cargo-drone-depot-cable.png",
	priority = "very-low",
	width = 256,
	height = 64,
	mipmap_count = 2,
}
local depot_cable_shadow_sprite = {
	type = "sprite",
	name = "cargo-drone-depot-cable-shadow",
	filename = "__cargo-drone__/graphics/cargo-drone-depot-cable.png",
	priority = "very-low",
	draw_as_shadow = true,
	width = 256,
	height = 64,
	mipmap_count = 2,
}

data:extend({
	depot_entity,
	depot_item,
	depot_recipe,
	depot_cable_sprite,
	depot_cable_shadow_sprite,
})
