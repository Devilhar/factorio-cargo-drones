local hit_effects	= require("__base__.prototypes.entity.hit-effects")
local sounds		= require("__base__.prototypes.entity.sounds")
local item_sounds	= require("__base__.prototypes.item_sounds")

local util			= require("util")

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
