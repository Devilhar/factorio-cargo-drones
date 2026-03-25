
local function add_top_sprites(mooring, top_sprite)
    rendering.draw_sprite{
        sprite = top_sprite,
        target = mooring,
        surface = mooring.surface,
        render_layer = "elevated-higher-object",
    }
    rendering.draw_sprite{
        sprite = "cargo-drone-mooring-top-shadow-sprite",
        target = mooring,
        surface = mooring.surface,
        render_layer = "object",
    }
end

return function()
	for _, entity_data in pairs(storage.cargo_drone_provider_mooring) do
		add_top_sprites(entity_data.entity, "cargo-drone-mooring-top-sprite-provider")
	end
	for _, entity_data in pairs(storage.cargo_drone_requester_mooring) do
		add_top_sprites(entity_data.entity, "cargo-drone-mooring-top-sprite-requester")
	end
	for _, entity_data in pairs(storage.cargo_drone_refuel_mooring) do
		add_top_sprites(entity_data.entity, "cargo-drone-mooring-top-sprite-refueler")
	end
end
