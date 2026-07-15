
local constants     = require("constants")
local ep            = require("entity_property")
local dlh           = require("deployer_helper")
local dc            = require("drone_controller")

local deployer_overlap_dir_sprites = {
	[defines.direction.north]	= "deployer-overlap-north",
	[defines.direction.east]	= "deployer-overlap-east",
	[defines.direction.south]	= "deployer-overlap-south",
	[defines.direction.west]	= "deployer-overlap-west",
}
local drone_dir_sprites = {
	[defines.direction.north]	= "cargo-drone-north",
	[defines.direction.east]	= "cargo-drone-east",
	[defines.direction.south]	= "cargo-drone-south",
	[defines.direction.west]	= "cargo-drone-west",
}
local drone_half_dir_sprites = {
	[defines.direction.north]	= "cargo-drone-half-north",
	[defines.direction.east]	= "cargo-drone-half-east",
	[defines.direction.south]	= "cargo-drone-half-south",
	[defines.direction.west]	= "cargo-drone-half-west",
}
local drone_shadow_dir_sprites = {
	[defines.direction.north]	= "cargo-drone-shadow-north",
	[defines.direction.east]	= "cargo-drone-shadow-east",
	[defines.direction.south]	= "cargo-drone-shadow-south",
	[defines.direction.west]	= "cargo-drone-shadow-west",
}

local activation_state = {
    active      = 1,
    inactive    = 2,
}
local drone_states = {
    idle    = 1,
    prepare = 2,
    release = 3,
}

local drone_placement_offset_y = 1

local deploy_prepare_begin_offset = 3
local deploy_prepare_ticks = 6 * 60
local deploy_prepare_sprite_change_ticks = 3 * 60

local deploy_release_rest_ticks = 1 * 60
local deploy_release_take_off_ticks = 5 * 60
local deploy_release_layer_change_tick = 3.5 * 60

local function register_deployer(deployer)
    local surface_buffer = storage.deployer_controller.surfaces[deployer.surface.index]

    if not surface_buffer then
        surface_buffer = {
            inactive = {},
            active = {},
            releasing_drones = 0,
        }

        storage.deployer_controller.surfaces[deployer.surface.index] = surface_buffer
    end

    surface_buffer.inactive[deployer.unit_number] = deployer
end
local function unregister_deployer(deployer)
    local surface_buffer = storage.deployer_controller.surfaces[deployer.surface.index]

    if not surface_buffer then
        return
    end

    surface_buffer.inactive[deployer.unit_number] = nil
    surface_buffer.active[deployer.unit_number] = nil

    if next(surface_buffer.inactive) == nil and next(surface_buffer.active) == nil then
        storage.deployer_controller.surfaces[deployer.surface.index] = nil
    end
end

local function recalculate_releasing_drones(surface_index)
    local surface_buffer = storage.deployer_controller.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    local count = 0

    for _, deployer in pairs(surface_buffer.inactive) do
        local drone_data = ep.get_entity_property(deployer, "drone_data")

        if drone_data and drone_data.state == drone_states.release then
            count = count + 1
        end
    end
    for _, deployer in pairs(surface_buffer.active) do
        local drone_data = ep.get_entity_property(deployer, "drone_data")

        if drone_data and drone_data.state == drone_states.release then
            count = count + 1
        end
    end

    surface_buffer.releasing_drones = count
end
local function get_releasing_drone_count(surface_index)
    local surface_buffer = storage.deployer_controller.surfaces[surface_index]

    if not surface_buffer then
        return 0
    end

    return surface_buffer.releasing_drones
end

local function update_drone_count(surface_index)
    local surface_buffer = storage.deployer_controller.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    local drone_count = dc.drone_count(surface_index) + get_releasing_drone_count(surface_index)

    for _, deployer in pairs(surface_buffer.inactive) do
        dlh.set_drone_count(deployer, drone_count)
    end
    for _, deployer in pairs(surface_buffer.active) do
        dlh.set_drone_count(deployer, drone_count)
    end
end

local function update_or_create_overlap_dir(deployer)
	local overlap = ep.get_entity_property(deployer, "overlap_sprite")

	if overlap and overlap.valid then
		overlap.sprite = deployer_overlap_dir_sprites[deployer.direction]

		return
	end

	ep.set_entity_property(deployer, "overlap_sprite", rendering.draw_sprite{
		sprite = deployer_overlap_dir_sprites[deployer.direction],
		target = deployer,
		surface = deployer.surface,
		render_layer = "higher-object-above",
	})
end
local function update_drone_dir(deployer)
	local drone_data = ep.get_entity_property(deployer, "drone_data")

	if not drone_data then
		return
	end

    if drone_data.drone_sprite_half then
        drone_data.drone.sprite = drone_half_dir_sprites[deployer.direction]
    else
        drone_data.drone.sprite = drone_dir_sprites[deployer.direction]
    end
    drone_data.drone_shadow.sprite = drone_shadow_dir_sprites[deployer.direction]
end

local function create_drone(deployer)
    local drone = deployer.surface.create_entity{
        name = "cargo-drone",
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y + drone_placement_offset_y },
        direction = deployer.direction,
        create_build_effect_smoke = true,
        raise_built = true,
    }

    local dummy_fuel_drone = ep.get_entity_property(deployer, "dummy_fuel_drone")

    if dummy_fuel_drone and dummy_fuel_drone.valid then
        drone.get_inventory(defines.inventory.fuel).transfer_from_inventory(dummy_fuel_drone.get_inventory(defines.inventory.fuel))
    end
end

local function begin_prepare_drone(deployer, game_tick)
    ep.set_entity_property(deployer, "drone_data", {
        state = drone_states.prepare,
        tick_start = game_tick,
        drone = rendering.draw_sprite{
            sprite = drone_half_dir_sprites[deployer.direction],
            target = { entity = deployer, offset = { constants.drone_shift[1], deploy_prepare_begin_offset + drone_placement_offset_y } },
            surface = deployer.surface,
            render_layer = "higher-object-under",
        },
        drone_sprite_half = true,
        drone_shadow = rendering.draw_sprite{
            sprite = drone_shadow_dir_sprites[deployer.direction],
            target = { entity = deployer, offset = { 0, constants.drone_shadow_shift[2] } },
            surface = deployer.surface,
            render_layer = "object",
        },
    })

    deployer.surface.play_sound{ path = "cargo-drone-deployer-raise-drone", position = deployer.position }
end
local function tick_prepare_drone(deployer, game_tick, drone_data)
    local progress = math.min((game_tick - drone_data.tick_start) / deploy_prepare_ticks, 1)

    if game_tick == drone_data.tick_start + deploy_prepare_sprite_change_ticks then
        drone_data.drone.sprite = drone_dir_sprites[deployer.direction]
        drone_data.drone_sprite_half = false
    end

    drone_data.drone.target = {
        entity = deployer,
        offset = { constants.drone_shift[1], deploy_prepare_begin_offset - deploy_prepare_begin_offset * progress + drone_placement_offset_y },
    }

    if game_tick < drone_data.tick_start + deploy_prepare_ticks then
        return
    end

    drone_data.state = drone_states.idle

    local proxy_container = ep.get_entity_property(deployer, "proxy_container")
    local dummy_fuel_drone = ep.get_entity_property(deployer, "dummy_fuel_drone")

    if proxy_container and proxy_container.valid and dummy_fuel_drone and dummy_fuel_drone.valid then
        proxy_container.proxy_target_entity = dummy_fuel_drone
        proxy_container.proxy_target_inventory = defines.inventory.fuel
    end
end

local function begin_release_drone(deployer, game_tick)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data then
        return
    end

    drone_data.state = drone_states.release
    drone_data.tick_start = game_tick

    deployer.surface.play_sound{ path = "cargo-drone-deployer-drone-release", position = deployer.position }

    local proxy_container = ep.get_entity_property(deployer, "proxy_container")

    if proxy_container and proxy_container.valid then
        proxy_container.proxy_target_entity = nil
    end

    recalculate_releasing_drones(deployer.surface.index)

    update_drone_count(deployer.surface.index)
end
local function tick_release_drone(deployer, game_tick, drone_data)
    if game_tick == drone_data.tick_start + deploy_release_layer_change_tick then
        drone_data.drone.render_layer = "air-object"
    end

    if game_tick >= drone_data.tick_start + deploy_release_rest_ticks then
        local height_per = 1 - (math.cos(((game_tick - drone_data.tick_start - deploy_release_rest_ticks) / deploy_release_take_off_ticks) * -math.pi) + 1) / 2

        drone_data.drone.target = {
            entity = deployer,
            offset = { constants.drone_shift[1], constants.drone_shift[2] * height_per + drone_placement_offset_y },
        }
        drone_data.drone_shadow.target = {
            entity = deployer,
            offset = { constants.drone_shadow_shift[1] * height_per, constants.drone_shadow_shift[2] + drone_placement_offset_y },
        }
    end

    if game_tick < drone_data.tick_start + deploy_release_rest_ticks + deploy_release_take_off_ticks then
        return
    end

    create_drone(deployer)

    drone_data.drone.destroy()
    drone_data.drone_shadow.destroy()

    ep.set_entity_property(deployer, "drone_data", nil)

    local proxy_container = ep.get_entity_property(deployer, "proxy_container")
    local drone_container = ep.get_entity_property(deployer, "drone_container")

    if proxy_container and proxy_container.valid and drone_container and drone_container.valid then
        proxy_container.proxy_target_entity = drone_container
        proxy_container.proxy_target_inventory = defines.inventory.chest
    end

    recalculate_releasing_drones(deployer.surface.index)

    update_drone_count(deployer.surface.index)
end

local function tick_deployer(deployer, game_tick)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data then
        local drone_container = ep.get_entity_property(deployer, "drone_container")

        if not drone_container or not drone_container.valid then
            return activation_state.inactive
        end

        local container_inventory = drone_container.get_inventory(defines.inventory.chest)

        container_inventory.set_filter(1, { name = "cargo-drone" })

        if container_inventory.is_empty() then
            return activation_state.inactive
        end

        if container_inventory[1].name ~= "cargo-drone" then
            return activation_state.inactive
        end

        local proxy_container = ep.get_entity_property(deployer, "proxy_container")

        if proxy_container and proxy_container.valid then
            proxy_container.proxy_target_entity = nil
        end

        container_inventory.clear()
        begin_prepare_drone(deployer, game_tick)

        return activation_state.active
    end

    if drone_data.state == drone_states.prepare then
        tick_prepare_drone(deployer, game_tick, drone_data)

        return activation_state.active
    end

    if drone_data.state == drone_states.release then
        tick_release_drone(deployer, game_tick, drone_data)

        return activation_state.active
    end

    if dc.drone_count(deployer.surface.index) + get_releasing_drone_count(deployer.surface.index) >= dlh.get_drone_limit(deployer) then
        return activation_state.inactive
    end

    local dummy_fuel_drone = ep.get_entity_property(deployer, "dummy_fuel_drone")

    if not dummy_fuel_drone or not dummy_fuel_drone.valid then
        return activation_state.inactive
    end

    local fuel_inventory = dummy_fuel_drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory.is_full() then
        begin_release_drone(deployer, game_tick)

        return activation_state.active
    end

    return activation_state.inactive
end

local deployer_controller = {}

function deployer_controller.init()
    storage.deployer_controller = storage.deployer_controller or {}

    storage.deployer_controller.surfaces = storage.deployer_controller.surfaces or {}
end

function deployer_controller.surface_deleted(surface_index)
    storage.deployer_controller.surfaces[surface_index] = nil
end
function deployer_controller.surface_cleared(surface_index)
    storage.deployer_controller.surfaces[surface_index] = nil
end

function deployer_controller.created(deployer)
    register_deployer(deployer)

    local proxy_container = deployer.surface.create_entity{
        name = "cargo-drone-deployer-proxy-container",
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y },
        create_build_effect_smoke = false,
        raise_built = false,
    }

    ep.set_entity_property(deployer, "proxy_container", proxy_container)

    local drone_container = deployer.surface.create_entity{
        name = "cargo-drone-deployer-drone-container",
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y },
        create_build_effect_smoke = false,
        raise_built = false,
    }

    drone_container.get_inventory(defines.inventory.chest).set_filter(1, { name = "cargo-drone" })

    ep.set_entity_property(deployer, "drone_container", drone_container)

    proxy_container.proxy_target_entity = drone_container
    proxy_container.proxy_target_inventory = defines.inventory.chest

    local dummy_fuel_drone = deployer.surface.create_entity{
        name = "cargo-drone-deployer-dummy-fuel-drone",
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y },
        create_build_effect_smoke = false,
        raise_built = false,
    }

    dummy_fuel_drone.burner.currently_burning = "coal"

    dummy_fuel_drone.burner.remaining_burning_fuel = 4000000

    ep.set_entity_property(deployer, "dummy_fuel_drone", dummy_fuel_drone)

    update_or_create_overlap_dir(deployer)
    update_drone_dir(deployer)

	dlh.clean_settings(deployer)

    dlh.set_drone_count(deployer, dc.drone_count(deployer.surface.index))
end
function deployer_controller.destroyed(deployer)
    local drone_data = ep.get_entity_property(deployer, "drone_data")
    local proxy_container = ep.get_entity_property(deployer, "proxy_container")
    local drone_container = ep.get_entity_property(deployer, "drone_container")
    local dummy_fuel_drone = ep.get_entity_property(deployer, "dummy_fuel_drone")

    if drone_data then
        create_drone(deployer)
    end

    if proxy_container then
        proxy_container.destroy({ raise_destroy = true })
    end
    if drone_container then
        drone_container.destroy({ raise_destroy = true })
    end
    if dummy_fuel_drone then
        dummy_fuel_drone.destroy({ raise_destroy = true })
    end

    unregister_deployer(deployer)

    recalculate_releasing_drones(deployer.surface.index)

    update_drone_count(deployer.surface.index)
end

function deployer_controller.tick(game_tick)
    for _, surface_buffer in pairs(storage.deployer_controller.surfaces) do
        local activate = nil
        local deactivate = nil

        for _, deployer in pairs(surface_buffer.inactive) do
            if deployer.unit_number % 60 == game_tick % 60 then
                local state = tick_deployer(deployer, game_tick)

                if state == activation_state.active then
                    if not activate then
                        activate = {}
                    end

                    table.insert(activate, deployer)
                end
            end
        end
        for _, deployer in pairs(surface_buffer.active) do
            local state = tick_deployer(deployer, game_tick)

            if state == activation_state.inactive then
                if not deactivate then
                    deactivate = {}
                end

                table.insert(deactivate, deployer)
            end
        end

        if activate then
            for _, deployer in ipairs(activate) do
                surface_buffer.inactive[deployer.unit_number] = nil
                surface_buffer.active[deployer.unit_number] = deployer
            end
        end
        if deactivate then
            for _, deployer in ipairs(deactivate) do
                surface_buffer.inactive[deployer.unit_number] = deployer
                surface_buffer.active[deployer.unit_number] = nil
            end
        end
    end
end

function deployer_controller.direction_changed(deployer)
    update_or_create_overlap_dir(deployer)
    update_drone_dir(deployer)
end

function deployer_controller.drone_count_changed(surface_index)
    update_drone_count(surface_index)
end

return deployer_controller
