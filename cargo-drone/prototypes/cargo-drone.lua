
local item_sounds	= require("__base__.prototypes.item_sounds")

local util			= require("util")

local drone_flight_height = util.by_pixel(0, 265)[2]
local drone_shift = util.by_pixel(0, -284)
local drone_shadow_shift = util.by_pixel(383, -16)

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
cargo_drone.selection_priority = selection_priorities.resource + 2
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
		height = drone_flight_height
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

cargo_drone.drawing_box_vertical_extension = drone_flight_height
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
			shift = drone_shift,
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
			shift = drone_shadow_shift,
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

cargo_drone.driving_sound_volume_modifier = 0
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

local drone_data = {
	version = 1,
	type = "cargo-drone",
	cable = {
		attachment_offset = { x = 0, y = -9 },
		attachment_shadow_offset = { x = 14, y = 0 },
	},
	deployer = {
		body = {
			spawn_offset = { 0, -drone_shift[2] + 3.4 },
			prepare_offset = { 0, -drone_shift[2] + 0.4 },

			filename = "__cargo-drone__/graphics/cargo-drone.png",
			width = 502,
			-- Make shorter to cut away empty space. Makes it more compact so it doesn't clip outside of the deployer
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

data.raw["mod-data"]["cargo-drone-prototypes"].data["cargo-drone"] = drone_data

data:extend({
	cargo_drone,
	cargo_drone_sound_docking,
	{
		type = "item-with-entity-data",
		name = "cargo-drone",
		icon = "__cargo-drone__/graphics/cargo-drone-icon.png",
		subgroup = "cargo-drone",
		order = "a[cargo-drone]",
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
})
