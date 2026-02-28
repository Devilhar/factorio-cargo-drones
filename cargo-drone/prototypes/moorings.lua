
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

local mooring_circuit_wire_connection_point = {
	shadow = {
		red = util.by_pixel(12, 15),
		green = util.by_pixel(14, 15)
	},
	wire = {
		red = util.by_pixel(8, 4),
		green = util.by_pixel(10, 12)
	}
}

local mooring_entity_cc = merge_tables(table.deepcopy(data.raw["constant-combinator"]["constant-combinator"]), {
	name = "cargo-drone-mooring-constant-combinator-{NAME}",
	icon = "__cargo-drone__/graphics/cargo-drone-mooring-{NAME}-icon.png",
	minable = { mining_time = 0.2, result = "cargo-drone-mooring-constant-combinator-{NAME}" },
	flags = { "hide-alt-info", "not-upgradable", "placeable-neutral", "player-creation" },
	max_health = 350,
	collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
	selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
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
	circuit_wire_connection_points = {
		mooring_circuit_wire_connection_point,
		mooring_circuit_wire_connection_point,
		mooring_circuit_wire_connection_point,
		mooring_circuit_wire_connection_point
	},
	circuit_connector = circuit_connector_definitions["chest"],
	circuit_wire_max_distance = default_circuit_wire_max_distance
})
local mooring_entity_pc = {
	type = "proxy-container",
	name = "cargo-drone-mooring-proxy-container-{NAME}-{OFFSET}",
	icon = "__cargo-drone__/graphics/cargo-drone-mooring-{NAME}-icon.png",
	flags = { "hide-alt-info", "not-upgradable", "not-deconstructable", "player-creation", "not-blueprintable", "not-repairable", "not-in-kill-statistics" },
	hidden = true,
	selectable_in_game = false,
	minable = { mining_time = 0.1 },
	max_health = 350,
	collision_mask = { layers = {} },
	collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
	selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
	selection_priority = selection_priorities.editor_only,
	damaged_trigger_effect = hit_effects.entity(),
	picture = util.empty_sprite(),
}
local mooring_item = {
	type = "item",
	name = "cargo-drone-mooring-constant-combinator-{NAME}",
	icon = "__cargo-drone__/graphics/cargo-drone-mooring-{NAME}-icon.png",
	subgroup = "logistic-network",
	order = "g[cargo-drone]-{ORDER_CHAR}[cargo-drone-mooring-constant-combinator-{NAME}]",
	inventory_move_sound = item_sounds.metal_chest_inventory_move,
	pick_sound = item_sounds.metal_chest_inventory_pickup,
	drop_sound = item_sounds.metal_chest_inventory_move,
	place_result = "cargo-drone-mooring-constant-combinator-{NAME}",
	stack_size = 50
}
local mooring_recipe = {
	type = "recipe",
	name = "cargo-drone-mooring-constant-combinator-{NAME}",
	enabled = false,
	ingredients = {
		{ type = "item", name = "steel-plate", amount = 20 },
		{ type = "item", name = "radar", amount = 1 }
	},
	results = {{type="item", name="cargo-drone-mooring-constant-combinator-{NAME}", amount=1}}
}

local function make_mooring(placeholder, name, selection_offset)
	local scan = nil
	local selection_name = ""

	if selection_offset then
		selection_name = (selection_offset[1] + 1) .. "_" .. (selection_offset[2] + 1)
	end

	scan = function(current_table)
		for key, element in pairs(current_table) do
			if type(element) == "string" then
				current_table[key] = element:gsub("{NAME}", name)

				if selection_offset then
					current_table[key] = current_table[key]:gsub("{OFFSET}", selection_name)
				end
			elseif type(element) == "table" then
				scan(element)
			end
		end
	end

	local mooring = table.deepcopy(placeholder)

	if selection_offset then
		mooring.selection_box[1][1] = mooring.selection_box[1][1] - selection_offset[1]
		mooring.selection_box[1][2] = mooring.selection_box[1][2] - selection_offset[2]
		mooring.selection_box[2][1] = mooring.selection_box[2][1] - selection_offset[1]
		mooring.selection_box[2][2] = mooring.selection_box[2][2] - selection_offset[2]
	end

	scan(mooring)

	return mooring
end

local mooring_item_provider		= make_mooring(mooring_item, "provider")
local mooring_item_requester	= make_mooring(mooring_item, "requester")
local mooring_item_refuel		= make_mooring(mooring_item, "refueler")

mooring_item_provider.order		= mooring_item_provider.order:gsub("{ORDER_CHAR}", "b")
mooring_item_requester.order	= mooring_item_requester.order:gsub("{ORDER_CHAR}", "c")
mooring_item_refuel.order		= mooring_item_refuel.order:gsub("{ORDER_CHAR}", "d")

data:extend({
	make_mooring(mooring_entity_cc,	"provider"),
	mooring_item_provider,
	make_mooring(mooring_recipe,	"provider"),

	make_mooring(mooring_entity_cc,	"requester"),
	mooring_item_requester,
	make_mooring(mooring_recipe,	"requester"),

	make_mooring(mooring_entity_cc,	"refueler"),
	mooring_item_refuel,
	make_mooring(mooring_recipe,	"refueler"),
})

for x = -1, 1 do
	for y = -1, 1 do
		data:extend({
			make_mooring(mooring_entity_pc,	"provider",		{ x, y }),
			make_mooring(mooring_entity_pc,	"requester",	{ x, y }),
			make_mooring(mooring_entity_pc,	"refueler",		{ x, y }),
		})
	end
end
