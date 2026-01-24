
local util			= require("util")
local hit_effects	= require("__base__.prototypes.entity.hit-effects")
local sounds		= require("__base__.prototypes.entity.sounds")
local item_sounds	= require("__base__.prototypes.item_sounds")

require ("__base__.prototypes.entity.entity-util")

local flight_height_pixels = 265

local flight_height_tiles = util.by_pixel(0, flight_height_pixels)[2]

local cargo_drone = table.deepcopy(data.raw.car.car)
cargo_drone.name = "cargo-drone"
cargo_drone.icon = "__cargo-drone__/graphics/cargo-drone-icon.png"
cargo_drone.flags = {
	"placeable-neutral",
	"player-creation",
	"placeable-off-grid",
	"not-flammable",
	"no-automated-item-removal",
	"no-automated-item-insertion"
}
cargo_drone.is_military_target = false
cargo_drone.corpse = ""
cargo_drone.braking_power = "200kW"
cargo_drone.consumption = "50kW"
cargo_drone.collision_box = {{0, 0}, {0, 0}}
cargo_drone.selection_box = {{-1.5, -1.4}, {1.5, 1.4}}
cargo_drone.selection_priority = selection_priorities.resource + 1
cargo_drone.effectivity = 1.3
cargo_drone.max_health = 500
cargo_drone.inventory_size = 10
cargo_drone.allow_passengers = false
cargo_drone.guns = {}
cargo_drone.terrain_friction_modifier = 0
cargo_drone.friction = 0.002
cargo_drone.energy_source.fuel_inventory_size = 2
cargo_drone.energy_source.effectivity = 0.25
cargo_drone.energy_source.smoke = {
	{
		name = "car-smoke",
		deviation = {0.25, 0.25},
		frequency = 200,
		position = {0, 0.98},
		starting_frame = 0,
		starting_frame_deviation = 60,
		height = flight_height_tiles
	}
}
cargo_drone.rotation_speed = 0.0010
cargo_drone.tank_driving = true
cargo_drone.weight = 40000
cargo_drone.minable = { mining_time = 0.4, result = "cargo-drone" }
cargo_drone.has_belt_immunity = true
cargo_drone.allow_remote_driving = false
cargo_drone.collision_mask = { layers={}, colliding_with_tiles_only = true }
cargo_drone.resistances = {
	{ type = "fire",		decrease = 0,	percent = 30 },
	{ type = "physical",	decrease = 10,	percent = 30 },
	{ type = "impact",		decrease = 10,	percent = 65 },
	{ type = "explosion",	decrease = 0,	percent = 35 },
	{ type = "acid",		decrease = 0,	percent = 35 }
}
cargo_drone.stop_trigger = {
	{ type = "play-sound", sound = { { filename = "__base__/sound/car-breaks.ogg", volume = 0.0 } } }
}
cargo_drone.alert_icon_shift = { 0, 0 }

cargo_drone.drawing_box_vertical_extension = flight_height_tiles
cargo_drone.render_layer = "air-object"
cargo_drone.light_animation = nil
cargo_drone.animation =
{
	layers = {
		{
			priority = "low",
			width = 502,
			height = 502,
			frame_count = 1,
			scale = 0.5,
			direction_count = 64,
			shift = util.by_pixel(0+2, -11.5+8.5-16-flight_height_pixels),
			animation_speed = 8,
			max_advance = 0.2,
			stripes =
			{
				{
					filename = "__cargo-drone__/graphics/cargo-drone.png",
					width_in_frames = 8,
					height_in_frames = 8
				}
			}
		},
		{
			priority = "low",
			width = 502,
			height = 502,
			frame_count = 1,
			scale = 0.5,
			draw_as_shadow = true,
			direction_count = 64,
			shift = { flight_height_tiles + 4 - 0.25, -0.5 },
			max_advance = 0.2,
			stripes = util.multiplystripes(2,
			{
				{
					filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",
					width_in_frames = 8,
					height_in_frames = 8
				}
			})
		},
		{
			priority = "low",
			width = 502,
			height = 502,
			frame_count = 1,
			scale = 0.5,
			draw_as_shadow = true,
			direction_count = 64,
			shift = util.by_pixel(0, -16),
			max_advance = 0.2,
			stripes = util.multiplystripes(2,
			{
				{
					filename = "__cargo-drone__/graphics/cargo-drone-topdown-shadow.png",
					width_in_frames = 8,
					height_in_frames = 8
				}
			})
		}
	}
}
cargo_drone.turret_animation = nil
cargo_drone.track_particle_triggers = nil
cargo_drone.minimap_representation = {
	filename = "__cargo-drone__/graphics/cargo-drone-map.png",
	flags = { "icon" },
	size = { 128, 128 },
	scale = 0.5,
}

data:extend({
	cargo_drone,
	{
		type = "item-with-entity-data",
		name = "cargo-drone",
		icon = "__cargo-drone__/graphics/cargo-drone-icon.png",
		subgroup = "logistic-network",
		order = "g[cargo-drone]-a[cargo-drone]",
		inventory_move_sound = item_sounds.vehicle_inventory_move,
		pick_sound = item_sounds.vehicle_inventory_pickup,
		drop_sound = item_sounds.vehicle_inventory_move,
		place_result = "cargo-drone",
		stack_size = 1
	},
	{
		type = "recipe",
		name = "cargo-drone",
		enabled = false,
		energy_required = 2,
		ingredients =
		{
			{ type = "item", name = "engine-unit", amount = 20 },
			{ type = "item", name = "low-density-structure", amount = 40 },
			{ type = "item", name = "radar", amount = 1 }
		},
		results = { { type = "item", name = "cargo-drone", amount = 1 } }
	}
})

local mooring_entity = {
	type = "proxy-container",
	name = "cargo-drone-{NAME}-mooring",
	icon = "__cargo-drone__/graphics/cargo-drone-mooring-{NAME}-icon.png",
	flags = {"placeable-neutral", "player-creation"},
	minable = { mining_time = 0.2, result = "cargo-drone-{NAME}-mooring" },
	max_health = 350,
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
	collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
	selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
	damaged_trigger_effect = hit_effects.entity(),
	fast_replaceable_group = "container",
	impact_category = "metal",
	icon_draw_specification = {scale = 0.7},
	picture = {
		layers = {
			{
				filename = "__cargo-drone__/graphics/cargo-drone-mooring-{NAME}.png",
				priority = "low",
				width = 270,
				height = 800,
				shift = util.by_pixel(0, -200+64),
				scale = 0.44
			},
			{
				filename = "__cargo-drone__/graphics/cargo-drone-mooring-shadow.png",
				priority = "low",
				width = 1000,
				height = 200,
				shift = util.by_pixel(194, 2),
				draw_as_shadow = true,
				scale = 0.5016
			}
		}
	},
	circuit_connector = circuit_connector_definitions["chest"],
	circuit_wire_max_distance = default_circuit_wire_max_distance
}
local mooring_item = {
	type = "item",
	name = "cargo-drone-{NAME}-mooring",
	icon = "__cargo-drone__/graphics/cargo-drone-mooring-{NAME}-icon.png",
	subgroup = "logistic-network",
	order = "g[cargo-drone]-{ORDER_CHAR}[cargo-drone-{NAME}-mooring]",
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = "cargo-drone-{NAME}-mooring",
	stack_size = 50
}
local mooring_recipe = {
	type = "recipe",
	name = "cargo-drone-{NAME}-mooring",
	enabled = false,
	ingredients = {
		{ type = "item", name = "steel-plate", amount = 20 },
		{ type = "item", name = "radar", amount = 1 }
	},
	results = {{type="item", name="cargo-drone-{NAME}-mooring", amount=1}}
}

function make_mooring(placeholder, name)
	local scan = nil

	scan = function(current_table)
		for key, element in pairs(current_table) do
			if type(element) == "string" then
				current_table[key] = element:gsub("{NAME}", name)
			elseif type(element) == "table" then
				scan(element)
			end
		end
	end

	local mooring = table.deepcopy(placeholder)

	scan(mooring)

	return mooring
end

local mooring_item_provider		= make_mooring(mooring_item, "provider")
local mooring_item_requester	= make_mooring(mooring_item, "requester")
local mooring_item_refuel		= make_mooring(mooring_item, "refuel")

mooring_item_provider.order		= mooring_item_provider.order:gsub("{ORDER_CHAR}", "b")
mooring_item_requester.order	= mooring_item_requester.order:gsub("{ORDER_CHAR}", "c")
mooring_item_refuel.order		= mooring_item_refuel.order:gsub("{ORDER_CHAR}", "d")

data:extend({
	make_mooring(mooring_entity,	"provider"),
	mooring_item_provider,
	make_mooring(mooring_recipe,	"provider"),

	make_mooring(mooring_entity,	"requester"),
	mooring_item_requester,
	make_mooring(mooring_recipe,	"requester"),

	make_mooring(mooring_entity,	"refuel"),
	mooring_item_refuel,
	make_mooring(mooring_recipe,	"refuel")
})

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
