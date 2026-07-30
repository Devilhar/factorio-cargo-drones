local item_sounds	= require("__base__.prototypes.item_sounds")

local function merge_tables(placeholder, overwrite_table)
	for k, v in pairs(overwrite_table) do
		placeholder[k] = v
	end

	return placeholder
end

local deployer_circuit_wire_connection_point = {
	shadow = {
		red = util.by_pixel(152 * 0.75, 162 * 0.75),
		green = util.by_pixel(146 * 0.75, 165 * 0.75)
	},
	wire = {
		red = util.by_pixel(148 * 0.5, 171 * 0.5),
		green = util.by_pixel(136 * 0.5, 176 * 0.5)
	}
}
local deployer_activity_light_sprite = util.draw_as_glow{
	scale = 0.5,
	filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-S.png",
	width = 14,
	height = 16,
	shift = util.by_pixel(132 * 0.5, 195 * 0.5),
}

local deployer_entity = merge_tables(table.deepcopy(data.raw["constant-combinator"]["constant-combinator"]), {
	name = "cargo-drone-deployer-constant-combinator",
	sprites = make_4way_animation_from_spritesheet({
		layers = {
			{
				filename = "__cargo-drone__/graphics/cargo-drone-deployer.png",
				width = 512,
				height = 512,
				scale = 0.5,
			},
			{
				filename = "__cargo-drone__/graphics/cargo-drone-deployer-shadow.png",
				width = 512,
				height = 512,
				scale = 0.75,
				draw_as_shadow = true,
			}
		},
	}),
	activity_led_sprites = {
		north = deployer_activity_light_sprite,
		east = deployer_activity_light_sprite,
		south = deployer_activity_light_sprite,
		west = deployer_activity_light_sprite,
	},
	collision_mask = { layers = { item = true, object = true, player = true, water_tile = true, is_object = true, is_lower_object = true, elevated_rail = true } },
	collision_box = {{-3.85, -3.85}, {3.85, 3.85}},
	selection_box = {{-4, -4}, {4, 4}},
	minable = { mining_time = 0.2, result = "cargo-drone-deployer-constant-combinator" },
	flags = { "hide-alt-info", "not-upgradable", "placeable-neutral", "player-creation" },
	circuit_wire_connection_points = {
		deployer_circuit_wire_connection_point,
		deployer_circuit_wire_connection_point,
		deployer_circuit_wire_connection_point,
		deployer_circuit_wire_connection_point
	},
	circuit_wire_max_distance = default_circuit_wire_max_distance
})

local deployer_item = {
	type = "item",
	name = "cargo-drone-deployer-constant-combinator",
	icon = "__cargo-drone__/graphics/cargo-drone-deployer-icon.png",
	subgroup = "logistic-network",
	order = "g[cargo-drone]-f[cargo-drone-deployer-constant-combinator]",
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = "cargo-drone-deployer-constant-combinator",
	stack_size = 50
}
local deployer_recipe = {
	type = "recipe",
	name = "cargo-drone-deployer-constant-combinator",
	enabled = false,
	ingredients = {
		{ type = "item", name = "steel-plate", amount = 50 },
		{ type = "item", name = "engine-unit", amount = 25 },
		{ type = "item", name = "concrete", amount = 100 },
	},
	results = {{type="item", name="cargo-drone-deployer-constant-combinator", amount=1}}
}

local function make_overlap_sprite(direction, x)
	return {
		type = "sprite",
		name = "deployer-overlap-" .. direction,
		filename = "__cargo-drone__/graphics/cargo-drone-deployer-overlap.png",
		priority = "very-low",
		x = x,
		width = 512,
		height = 512,
		scale = 0.5,
		mipmap_count = 2,
	}
end

local deployer_overlap_sprite_north	= make_overlap_sprite("north",	0)
local deployer_overlap_sprite_east	= make_overlap_sprite("east",	512)
local deployer_overlap_sprite_south	= make_overlap_sprite("south",	1024)
local deployer_overlap_sprite_west	= make_overlap_sprite("west",	1536)

local deployer_raise_drone_sound = {
	type = "sound",
	name = "cargo-drone-deployer-raise-drone",
	filename = "__cargo-drone__/sound/cargo-drone-deployer-raise-drone.ogg",
}
local deployer_raise_drone_stop_sound = {
	type = "sound",
	name = "cargo-drone-deployer-raise-drone-stop",
	filename = "__base__/sound/car-metal-impact-2.ogg",
	speed = 0.5
}
local deployer_drone_release_sound = {
	type = "sound",
	name = "cargo-drone-deployer-drone-release",
	filename = "__cargo-drone__/sound/cargo-drone-deployer-drone-release.ogg",
}

local deployer_proxy_container = {
	type = "proxy-container",
	name = "cargo-drone-deployer-proxy-container",
	flags = {
		"hide-alt-info",
		"not-upgradable",
		"not-deconstructable",
		"player-creation",
		"not-blueprintable",
		"not-repairable",
		"not-in-kill-statistics",
		"no-automated-item-removal",
	},
	hidden = true,
	selectable_in_game = false,
	collision_mask = { layers = {} },
	collision_box = {{-3.85, -3.85}, {3.85, 3.85}},
	selection_box = {{-4, -4}, {4, 4}},
	selection_priority = selection_priorities.editor_only,
}
local deployer_drone_container = {
	type = "container",
	name = "cargo-drone-deployer-drone-container",
	flags = {
		"hide-alt-info",
		"not-upgradable",
		"not-deconstructable",
		"player-creation",
		"not-blueprintable",
		"not-repairable",
		"not-in-kill-statistics",
		"no-automated-item-removal",
	},
	hidden = true,
	selectable_in_game = false,
	collision_mask = { layers = {} },
	selection_priority = selection_priorities.editor_only,
	inventory_size = 1,
	inventory_type = "with_filters_and_bar",
}

data:extend({
	deployer_entity,
	deployer_item,
	deployer_recipe,

	deployer_overlap_sprite_north,
	deployer_overlap_sprite_east,
	deployer_overlap_sprite_south,
	deployer_overlap_sprite_west,

	deployer_raise_drone_sound,
	deployer_raise_drone_stop_sound,
	deployer_drone_release_sound,

	deployer_proxy_container,
	deployer_drone_container,
})
