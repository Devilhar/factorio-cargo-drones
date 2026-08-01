
local drone_placement_offset_y = 0.5
local deploy_prepare_end_offset = 0.4

local direction_to_cardinal = {
    [defines.direction.north]	= "north",
	[defines.direction.east]	= "east",
	[defines.direction.south]	= "south",
	[defines.direction.west]	= "west",
}

local function migrate_deployers(deployers)
    for unit_number, deployer in pairs(deployers) do
        local properties = storage.managed_entities[unit_number].properties

        local drone_data = properties.drone_data

        if drone_data then
            drone_data.drone_name = "cargo-drone"
            drone_data.drone_quality = "normal"
            drone_data.dummy_fuel_drone = properties.dummy_fuel_drone

            drone_data.drone = rendering.draw_sprite{
                sprite = "cargo-drone-deployer-cargo-drone-" .. direction_to_cardinal[deployer.direction] .. "-4",
                target = { entity = deployer, offset = { 0, deploy_prepare_end_offset + drone_placement_offset_y } },
                surface = deployer.surface,
                render_layer = "higher-object-under",
            }
            drone_data.drone_shadow = rendering.draw_sprite{
                sprite = "cargo-drone-deployer-cargo-drone-shadow-" .. direction_to_cardinal[deployer.direction],
                target = { entity = deployer, offset = { -deploy_prepare_end_offset, 0 } },
                surface = deployer.surface,
                render_layer = "object",
            }
        else
            properties.dummy_fuel_drone.destroy()

            properties.dummy_fuel_drone = nil
        end

        local drone_container = properties.drone_container

        if drone_container and drone_container.valid then
            local drone_container_inventory = drone_container.get_inventory(defines.inventory.chest)

            drone_container_inventory.set_filter(1, { name = "cargo-drone" })

            -- Set to invalid item and let it reset itself during the deployer's tick
            for i = 2, #drone_container_inventory do
                drone_container_inventory.set_filter(i, { name = "red-wire" })
            end
        end
    end
end

local function create_name_render_object(target)
    local properties = storage.managed_entities[target.unit_number].properties

    properties.name_render_object = rendering.draw_text{
        text = properties.target_name,
        target = { entity = target, offset = { 2, -2 } },
        surface = target.surface,
        render_mode = "chart",
        color = { 1, 1, 1 },
        scale_with_zoom = true,
        scale = 1.25,
        orientation = -31 / 360,
        vertical_alignment = "middle",
        use_rich_text = true,
        visible = false,
        players = {},
    }
end

return function()
    for _, surface_buffer in pairs(storage.deployer_controller.surfaces) do
        migrate_deployers(surface_buffer.inactive)
        migrate_deployers(surface_buffer.active)
    end

    storage.player_storage = storage.player_storage or {}

    storage.player_storage.show_map_overlays = storage.player_storage.show_map_overlays or {}

    for _, surface_buffer in pairs(storage.mooring_controller.surfaces) do
        for _, moorings in pairs(surface_buffer) do
            for _, mooring in pairs(moorings) do
                create_name_render_object(mooring)
            end
        end
    end
    for _, surface_buffer in pairs(storage.depot_helper.depots) do
        for _, depot in pairs(surface_buffer) do
            create_name_render_object(depot)
        end
    end
end
