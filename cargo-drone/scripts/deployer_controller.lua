
local ep            = require("entity_property")
local dlh           = require("deployer_helper")
local dc            = require("drone_controller")
local dt            = require("drone_tasks")

local deployer_status = {
    awaiting_drone  = 1,
    preparing       = 2,
    awaiting_fuel   = 3,
    at_drone_limit  = 4,
    idling          = 5,
    releasing       = 6,
}

local direction_to_cardinal = {
    [defines.direction.north]	= "north",
	[defines.direction.east]	= "east",
	[defines.direction.south]	= "south",
	[defines.direction.west]	= "west",
}
local deployer_overlap_dir_sprites = {
	[defines.direction.north]	= "deployer-overlap-north",
	[defines.direction.east]	= "deployer-overlap-east",
	[defines.direction.south]	= "deployer-overlap-south",
	[defines.direction.west]	= "deployer-overlap-west",
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

local drone_placement_offset_y = 0.5

local deploy_prepare_ticks = 6 * 60
local deploy_prepare_sprite_change_ticks = { 2 * 60, 4 * 60, 6 * 60 }

local deploy_release_rest_ticks = 1 * 60
local deploy_release_take_off_ticks = 5 * 60
local deploy_release_layer_change_tick = 2 * 60

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

local function update_drone_container_filters(drone_container)
    local drone_container_inventory = drone_container.get_inventory(defines.inventory.chest)
    local slot_index = 1

    for _, item_name in ipairs(prototypes.mod_data["cargo-drone-mod-data"].data.items) do
        drone_container_inventory.set_filter(slot_index, { name = item_name })

        slot_index = slot_index + 1
    end
end
local function update_drone_count(surface_index)
    local surface_buffer = storage.deployer_controller.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    local drone_count = dc.drone_count(surface_index) + get_releasing_drone_count(surface_index)

    for _, deployer in pairs(surface_buffer.inactive) do
        dlh.set_total_drone_count(deployer, drone_count)
    end
    for _, deployer in pairs(surface_buffer.active) do
        dlh.set_total_drone_count(deployer, drone_count)
    end
end
local function update_available_drone_count(surface_index)
    local surface_buffer = storage.deployer_controller.surfaces[surface_index]

    if not surface_buffer then
        return
    end

    local available_drone_count = dt.idle_drone_count(surface_index) + get_releasing_drone_count(surface_index)

    for _, deployer in pairs(surface_buffer.inactive) do
        dlh.set_available_drone_count(deployer, available_drone_count)
    end
    for _, deployer in pairs(surface_buffer.active) do
        dlh.set_available_drone_count(deployer, available_drone_count)
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

    drone_data.drone.sprite = "cargo-drone-deployer-" .. drone_data.drone_name .. "-" .. direction_to_cardinal[deployer.direction] .. "-" .. drone_data.drone_sprite_quater
    drone_data.drone_shadow.sprite = "cargo-drone-deployer-" .. drone_data.drone_name .. "-shadow-" .. direction_to_cardinal[deployer.direction]
end

local function create_drone(deployer, drone_data)
    local drone = deployer.surface.create_entity{
        name = drone_data.drone_name,
        quality = drone_data.drone_quality,
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y + drone_placement_offset_y },
        direction = deployer.direction,
        create_build_effect_smoke = true,
        raise_built = true,
    }

    local fuel_inventory = drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory and drone_data.dummy_fuel_drone.valid then
        fuel_inventory.transfer_from_inventory(drone_data.dummy_fuel_drone.get_inventory(defines.inventory.fuel))
    end
end

local function begin_prepare_drone(deployer, game_tick, drone_name, drone_quality)
    local dummy_fuel_drone = deployer.surface.create_entity{
        name = "cargo-drone-deployer-dummy-fuel-" .. drone_name,
        quality = drone_quality,
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y + drone_placement_offset_y },
        direction = deployer.direction,
        create_build_effect_smoke = false,
        raise_built = false,
    }

    if dummy_fuel_drone.burner then
        dummy_fuel_drone.burner.currently_burning = "coal"

        dummy_fuel_drone.burner.remaining_burning_fuel = 4000000
    end

    local prototype_data = prototypes.mod_data["cargo-drone-drones"].data[drone_name]

    local body_spawn_offset = prototype_data.deployer.body.spawn_offset
    local shadow_prepare_offset = prototype_data.deployer.shadow.prepare_offset

    ep.set_entity_property(deployer, "drone_data", {
        state = drone_states.prepare,
        tick_start = game_tick,
        drone_name = drone_name,
        drone_quality = drone_quality,
        drone_sprite_quater = 1,
        drone = rendering.draw_sprite{
            sprite = "cargo-drone-deployer-" .. drone_name .. "-" .. direction_to_cardinal[deployer.direction] .. "-" .. 1,
            target = {
                entity = deployer,
                offset = {
                    body_spawn_offset.x or body_spawn_offset[1],
                    (body_spawn_offset.y or body_spawn_offset[2]) + drone_placement_offset_y,
                },
            },
            surface = deployer.surface,
            render_layer = "higher-object-under",
        },
        drone_shadow = rendering.draw_sprite{
            sprite = "cargo-drone-deployer-" .. drone_name .. "-shadow-" .. direction_to_cardinal[deployer.direction],
            target = {
                entity = deployer,
                offset = shadow_prepare_offset,
            },
            surface = deployer.surface,
            render_layer = "object",
        },
        dummy_fuel_drone = dummy_fuel_drone,
    })

    deployer.surface.play_sound{ path = "cargo-drone-deployer-raise-drone", position = deployer.position }
end
local function tick_prepare_drone(deployer, game_tick, drone_data)
    local progress = math.min((game_tick - drone_data.tick_start) / deploy_prepare_ticks, 1)

    for i = 2, 4 do
        if game_tick == drone_data.tick_start + deploy_prepare_sprite_change_ticks[i - 1] then
            drone_data.drone.sprite = "cargo-drone-deployer-" .. drone_data.drone_name .. "-" .. direction_to_cardinal[deployer.direction] .. "-" .. i
            drone_data.drone_sprite_quater = i
        end
    end

    local prototype_data = prototypes.mod_data["cargo-drone-drones"].data[drone_data.drone_name]

    local body_spawn_offset = prototype_data.deployer.body.spawn_offset
    local body_prepare_offset = prototype_data.deployer.body.prepare_offset

    local offset = {
        (body_spawn_offset.x or body_spawn_offset[1]) * (1 - progress) + progress * (body_prepare_offset.x or body_prepare_offset[1]),
        (body_spawn_offset.y or body_spawn_offset[2]) * (1 - progress) + progress * (body_prepare_offset.y or body_prepare_offset[2]) + drone_placement_offset_y,
    }

    drone_data.drone.target = {
        entity = deployer,
        offset = offset,
    }

    if game_tick < drone_data.tick_start + deploy_prepare_ticks then
        return
    end

    deployer.surface.play_sound{ path = "cargo-drone-deployer-raise-drone-stop", position = deployer.position }

    drone_data.state = drone_states.idle

    local proxy_container = ep.get_entity_property(deployer, "proxy_container")

    if proxy_container and proxy_container.valid and drone_data.dummy_fuel_drone.valid then
        proxy_container.proxy_target_entity = drone_data.dummy_fuel_drone
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
    update_available_drone_count(deployer.surface.index)
end
local function tick_release_drone(deployer, game_tick, drone_data)
    if game_tick == drone_data.tick_start + deploy_release_layer_change_tick then
        drone_data.drone.render_layer = "air-object"
    end

    if game_tick >= drone_data.tick_start + deploy_release_rest_ticks then
        local prototype_data = prototypes.mod_data["cargo-drone-drones"].data[drone_data.drone_name]

        local progress = 1 - (math.cos(((game_tick - drone_data.tick_start - deploy_release_rest_ticks) / deploy_release_take_off_ticks) * -math.pi) + 1) / 2

        local body_prepare_offset = prototype_data.deployer.body.prepare_offset
        local shadow_prepare_offset = prototype_data.deployer.shadow.prepare_offset

        local body_offset = {
            (body_prepare_offset.x or body_prepare_offset[1]) * (1 - progress),
            (body_prepare_offset.y or body_prepare_offset[2]) * (1 - progress) + drone_placement_offset_y,
        }
        local shadow_offset = {
            (shadow_prepare_offset.x or shadow_prepare_offset[1]) * (1 - progress),
            (shadow_prepare_offset.y or shadow_prepare_offset[2]) * (1 - progress) + drone_placement_offset_y,
        }

        drone_data.drone.target = {
            entity = deployer,
            offset = body_offset,
        }
        drone_data.drone_shadow.target = {
            entity = deployer,
            offset = shadow_offset,
        }
    end

    if game_tick < drone_data.tick_start + deploy_release_rest_ticks + deploy_release_take_off_ticks then
        return
    end

    create_drone(deployer, drone_data)

    drone_data.drone.destroy()
    drone_data.drone_shadow.destroy()
    drone_data.dummy_fuel_drone.destroy({ raise_destroy = true })

    ep.set_entity_property(deployer, "drone_data", nil)

    local proxy_container = ep.get_entity_property(deployer, "proxy_container")
    local drone_container = ep.get_entity_property(deployer, "drone_container")

    if proxy_container and proxy_container.valid and drone_container and drone_container.valid then
        proxy_container.proxy_target_entity = drone_container
        proxy_container.proxy_target_inventory = defines.inventory.chest
    end

    recalculate_releasing_drones(deployer.surface.index)

    update_drone_count(deployer.surface.index)
    update_available_drone_count(deployer.surface.index)
end

local function tick_deployer(deployer, game_tick)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data then
        local drone_container = ep.get_entity_property(deployer, "drone_container")

        if not drone_container or not drone_container.valid then
            return activation_state.inactive
        end

        local container_inventory = drone_container.get_inventory(defines.inventory.chest)

        update_drone_container_filters(drone_container)

        if container_inventory.is_empty() then
            return activation_state.inactive
        end

        local drone_item = container_inventory.get_contents()[1]

        local item_prototype = prototypes.item[drone_item.name]

        if not item_prototype or not item_prototype.place_result then
            return activation_state.inactive
        end

        local drone_name = item_prototype.place_result.name

        if not prototypes.mod_data["cargo-drone-drones"].data[drone_name] then
            return activation_state.inactive
        end

        local proxy_container = ep.get_entity_property(deployer, "proxy_container")

        if proxy_container and proxy_container.valid then
            proxy_container.proxy_target_entity = nil
        end

        container_inventory.remove({ name = drone_item.name, quality = drone_item.quality, count = 1  })
        begin_prepare_drone(deployer, game_tick, drone_name, drone_item.quality)

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

    local releasing_drone_count = get_releasing_drone_count(deployer.surface.index)

    if dc.drone_count(deployer.surface.index) + releasing_drone_count >= dlh.get_drone_limit(deployer) then
        return activation_state.inactive
    end

    if not dlh.get_always_release(deployer) then
        if releasing_drone_count > 0 or dt.idle_drone_count(deployer.surface.index) > 0 then
            return activation_state.inactive
        end
    end

    if not drone_data.dummy_fuel_drone.valid then
        return activation_state.inactive
    end

    local fuel_inventory = drone_data.dummy_fuel_drone.get_inventory(defines.inventory.fuel)

    if not fuel_inventory or fuel_inventory.is_full() then
        begin_release_drone(deployer, game_tick)

        return activation_state.active
    end

    return activation_state.inactive
end

local deployer_controller = {}

deployer_controller.deployer_status = deployer_status

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

    update_drone_container_filters(drone_container)

    ep.set_entity_property(deployer, "drone_container", drone_container)

    proxy_container.proxy_target_entity = drone_container
    proxy_container.proxy_target_inventory = defines.inventory.chest

    update_or_create_overlap_dir(deployer)
    update_drone_dir(deployer)

	dlh.clean_settings(deployer)

    dlh.set_total_drone_count(deployer, dc.drone_count(deployer.surface.index))
end
function deployer_controller.destroyed(deployer)
    local drone_data = ep.get_entity_property(deployer, "drone_data")
    local proxy_container = ep.get_entity_property(deployer, "proxy_container")
    local drone_container = ep.get_entity_property(deployer, "drone_container")

    if drone_data then
        create_drone(deployer, drone_data)

        drone_data.dummy_fuel_drone.destroy({ raise_destroy = true })
    end

    if proxy_container then
        proxy_container.destroy({ raise_destroy = true })
    end
    if drone_container then
        drone_container.destroy({ raise_destroy = true })
    end

    unregister_deployer(deployer)

    recalculate_releasing_drones(deployer.surface.index)

    update_drone_count(deployer.surface.index)
    update_available_drone_count(deployer.surface.index)
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
function deployer_controller.idle_drone_count_changed(surface_index)
    update_available_drone_count(surface_index)
end

function deployer_controller.release_drone(deployer)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if drone_data and drone_data.state == drone_states.idle then
        begin_release_drone(deployer, game.tick)
    end
end

function deployer_controller.get_deployer_status(deployer)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data then
        return deployer_status.awaiting_drone
    end

    if drone_data.state == drone_states.prepare then
        return deployer_status.preparing
    end

    if drone_data.state == drone_states.release then
        return deployer_status.releasing
    end

    if not drone_data.dummy_fuel_drone.valid then
        return deployer_status.awaiting_fuel
    end

    local fuel_inventory = drone_data.dummy_fuel_drone.get_inventory(defines.inventory.fuel)

    if fuel_inventory and not fuel_inventory.is_full() then
        return deployer_status.awaiting_fuel
    end

    local releasing_drone_count = get_releasing_drone_count(deployer.surface.index)

    if dc.drone_count(deployer.surface.index) + releasing_drone_count >= dlh.get_drone_limit(deployer) then
        return deployer_status.at_drone_limit
    end

    return deployer_status.idling
end
function deployer_controller.is_drone_prepared(deployer)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    return drone_data ~= nil and drone_data.state == drone_states.idle
end
function deployer_controller.get_drone_inventory(deployer)
    local drone_container = ep.get_entity_property(deployer, "drone_container")

    if not drone_container then
        return nil
    end

    return drone_container.get_inventory(defines.inventory.chest)
end
function deployer_controller.get_fuel_inventory(deployer)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data or not drone_data.dummy_fuel_drone.valid then
        return nil
    end

    return drone_data.dummy_fuel_drone.get_inventory(defines.inventory.fuel)
end

return deployer_controller
