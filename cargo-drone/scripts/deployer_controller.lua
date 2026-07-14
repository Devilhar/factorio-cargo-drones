
local constants     = require("constants")
local ep            = require("entity_property")
local dlh           = require("deployer_helper")
--local dc            = require("drone_controller")

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


local function begin_prepare_drone(deployer, game_tick)
    ep.set_entity_property(deployer, "drone_data", {
        state = drone_states.prepare,
        tick_start = game_tick,
        drone = rendering.draw_sprite{
            sprite = drone_half_dir_sprites[deployer.direction],
            target = { entity = deployer, offset = { constants.drone_shift[1], 1 } },
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
end

local function begin_release_drone(deployer, game_tick)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data then
        return
    end

    drone_data.state = drone_states.release
    drone_data.tick_start = game_tick

    deployer.surface.play_sound{ path = "cargo-drone-deployer-drone-release", position = deployer.position }
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

    local drone = deployer.surface.create_entity{
        name = "cargo-drone",
        force = deployer.force,
        position = { deployer.position.x, deployer.position.y + drone_placement_offset_y },
        direction = deployer.direction,
        create_build_effect_smoke = true,
        raise_built = true,
    }

    drone.burner.currently_burning = "coal"

    drone.burner.remaining_burning_fuel = 4000000

    -- FIXME: Add refuel check
    --dc.check_refuel(drone)

    drone_data.drone.destroy()
    drone_data.drone_shadow.destroy()

    ep.set_entity_property(deployer, "drone_data", nil)
end

local function deploy_drone(deployer, game_tick)
    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if not drone_data then
        begin_prepare_drone(deployer, game_tick)

        return
    end

    if drone_data.state ~= drone_states.idle then
        return
    end

    begin_release_drone(deployer, game_tick)
end

local function tick_deployer(deployer, game_tick)
    local cb = deployer.get_control_behavior()

    if not cb.enabled then
        cb.enabled = true

        deploy_drone(deployer, game_tick)
    end

    local drone_data = ep.get_entity_property(deployer, "drone_data")

    if drone_data then
        if drone_data.state == drone_states.prepare then
            tick_prepare_drone(deployer, game_tick, drone_data)
        elseif drone_data.state == drone_states.release then
            tick_release_drone(deployer, game_tick, drone_data)
        end
    end
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
    local surface_buffer = storage.deployer_controller.surfaces[deployer.surface.index]

    if not surface_buffer then
        surface_buffer = {}

        storage.deployer_controller.surfaces[deployer.surface.index] = surface_buffer
    end

    surface_buffer[deployer.unit_number] = deployer

	ep.entity_manage(deployer)

    update_or_create_overlap_dir(deployer)
    update_drone_dir(deployer)

	dlh.clean_settings(deployer)
end
function deployer_controller.destroyed(deployer)
    local surface_buffer = storage.deployer_controller.surfaces[deployer.surface.index]

    if not surface_buffer then
        return
    end

    surface_buffer[deployer.unit_number] = nil

    if next(surface_buffer) == nil then
        storage.deployer_controller.surfaces[deployer.surface.index] = nil
    end
end

function deployer_controller.tick(game_tick)
    for _, deployers in pairs(storage.deployer_controller.surfaces) do
        for _, deployer in pairs(deployers) do
            tick_deployer(deployer, game_tick)
        end
    end
end

function deployer_controller.direction_changed(deployer)
    update_or_create_overlap_dir(deployer)
    update_drone_dir(deployer)
end

return deployer_controller
