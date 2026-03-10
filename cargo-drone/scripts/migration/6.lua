
local ep		= require("states.12.entity_property")
local mh		= require("states.12.mooring_helper")
local dt		= require("states.12.drone_tasks")
local gm		= require("states.12.gui_mooring")
local gcd		= require("states.12.gui_cargo_drone")

return function()
	ep.remove_invalid_entities()

	mh.init()

	gm.create_player_storage()
	gcd.create_player_storage()

	dt.migration_remove_all_tasks()

	for _, surface in pairs(game.surfaces) do
		for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-provider" }) do
			if not mh.try_setup_mooring(entity) then
				entity.destroy()
			end
		end
		for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-requester" }) do
			if not mh.try_setup_mooring(entity) then
				entity.destroy()
			end
		end
		for _, entity in pairs(surface.find_entities_filtered{ name = "cargo-drone-mooring-constant-combinator-refueler" }) do
			if not mh.try_setup_mooring(entity) then
				entity.destroy()
			end
		end
	end

	game.print({ "cargo-drone-migration.warning-wires-removed" })
end
