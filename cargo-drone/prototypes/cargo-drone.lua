
local item_sounds	= require("__base__.prototypes.item_sounds")

local util			= require("util")

local constants		= require("constants")

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
cargo_drone.braking_force = (200 * 1000) / 60
cargo_drone.friction_force = 2e-3
cargo_drone.consumption = "100kW"
cargo_drone.collision_box = {{0, 0}, {0, 0}}
cargo_drone.selection_box = {{-1.5, -1.4}, {1.5, 1.4}}
cargo_drone.selection_priority = selection_priorities.resource + 1
cargo_drone.effectivity = 1
cargo_drone.max_health = 500
cargo_drone.inventory_size = settings.startup["cargo-drone-inventory-size"].value
cargo_drone.allow_passengers = false
cargo_drone.guns = {}
cargo_drone.terrain_friction_modifier = 0
cargo_drone.friction = 0.002
cargo_drone.energy_source.fuel_inventory_size = settings.startup["cargo-drone-fuel-inventory-size"].value
cargo_drone.energy_source.burnt_inventory_size = settings.startup["cargo-drone-burnt-result-inventory-size"].value
cargo_drone.energy_source.effectivity = 0.25
cargo_drone.energy_source.smoke = {
	{
		name = "car-smoke",
		deviation = {0.25, 0.25},
		frequency = 200,
		position = {0, 0.98},
		starting_frame = 0,
		starting_frame_deviation = 60,
		height = constants.drone_flight_height
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

cargo_drone.drawing_box_vertical_extension = constants.drone_flight_height
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
			shift = constants.drone_shift,
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
			shift = constants.drone_shadow_shift,
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
	scale = 0.25,
}

cargo_drone.working_sound =
{
	main_sounds =
	{
		{
			sound = {filename = "__base__/sound/car-engine-driving.ogg", volume = 0.16},
			match_volume_to_activity = true,
			activity_to_volume_modifiers =
			{
				multiplier = 1.8,
				offset = 0.95,
			},
			match_speed_to_activity = true,
			activity_to_speed_modifiers =
			{
				multiplier = 0.8,
				minimum = 1.0,
				maximum = 1.4,
				offset = 0.1,
			}
		},
		{
			sound = { filename = "__base__/sound/car-engine.ogg", volume = 1.2 },
			match_volume_to_activity = true,
			activity_to_volume_modifiers =
			{
				multiplier = 1.8,
				offset = 0.95,
			},
			match_speed_to_activity = true,
			activity_to_speed_modifiers =
			{
				multiplier = 0.8,
				minimum = 1.0,
				maximum = 1.4,
				offset = 0.1,
			}
		},
	},
	activate_sound = { filename = "__base__/sound/car-engine-start.ogg", volume = 0.67 },
	deactivate_sound = { filename = "__base__/sound/car-engine-stop.ogg", volume = 0.67 },
}
local cargo_drone_sound_docking = {
	type = "sound",
	name = "cargo-drone-sound-docking",
	filename = "__base__/sound/car-metal-impact-2.ogg",
	speed = 0.5
}

local function make_directional_sprite(layer)
	layer.type = "sprite"
	layer.priority = "very-low"
	layer.width = 502
	if layer.height == nil then
		layer.height = 502
	end
	layer.scale = 0.5
	layer.mipmap_count = 2

	return layer
end

local function make_directional_quater_sprites(layer)
	local sprites = {}
	local mults = {
		6/32,
		1/8,
		1/16,
		0,
	}

	for i = 1, 4 do
		local height = (252 / 4) * i
		--local shift_height = 252 / 8
		local quater_layer = table.deepcopy(layer)

		quater_layer.y = quater_layer.y + 125
		quater_layer.height = height
		quater_layer.shift = util.by_pixel(0, -252 * mults[i])

		sprites[i] = make_directional_sprite(quater_layer)

		sprites[i].name = sprites[i].name .. "-" .. i
	end

	return sprites
end

local cargo_drone_sprites_north	= make_directional_quater_sprites{ name = "cargo-drone-north",			filename = "__cargo-drone__/graphics/cargo-drone.png", 			y = 0 }
local cargo_drone_sprites_east	= make_directional_quater_sprites{ name = "cargo-drone-east",			filename = "__cargo-drone__/graphics/cargo-drone.png", 			y = 1004 }
local cargo_drone_sprites_south	= make_directional_quater_sprites{ name = "cargo-drone-south",			filename = "__cargo-drone__/graphics/cargo-drone.png", 			y = 2008 }
local cargo_drone_sprites_west	= make_directional_quater_sprites{ name = "cargo-drone-west",			filename = "__cargo-drone__/graphics/cargo-drone.png", 			y = 3012 }

local cargo_drone_shadow_sprite_north	= make_directional_sprite{ name = "cargo-drone-shadow-north",	filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",	y = 0,		draw_as_shadow = true }
local cargo_drone_shadow_sprite_east	= make_directional_sprite{ name = "cargo-drone-shadow-east",	filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",	y = 1004,	draw_as_shadow = true }
local cargo_drone_shadow_sprite_south	= make_directional_sprite{ name = "cargo-drone-shadow-south",	filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",	y = 2008,	draw_as_shadow = true }
local cargo_drone_shadow_sprite_west	= make_directional_sprite{ name = "cargo-drone-shadow-west",	filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",	y = 3012,	draw_as_shadow = true }

data:extend({
	cargo_drone,
	cargo_drone_sound_docking,
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
	},

	cargo_drone_sprites_north[1],
	cargo_drone_sprites_north[2],
	cargo_drone_sprites_north[3],
	cargo_drone_sprites_north[4],
	cargo_drone_sprites_east[1],
	cargo_drone_sprites_east[2],
	cargo_drone_sprites_east[3],
	cargo_drone_sprites_east[4],
	cargo_drone_sprites_south[1],
	cargo_drone_sprites_south[2],
	cargo_drone_sprites_south[3],
	cargo_drone_sprites_south[4],
	cargo_drone_sprites_west[1],
	cargo_drone_sprites_west[2],
	cargo_drone_sprites_west[3],
	cargo_drone_sprites_west[4],
	cargo_drone_shadow_sprite_north,
	cargo_drone_shadow_sprite_east,
	cargo_drone_shadow_sprite_south,
	cargo_drone_shadow_sprite_west,
})
