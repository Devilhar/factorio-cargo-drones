
local mod_data = data.raw["mod-data"]["cargo-drone-data"].data
local deployer_drone_container = data.raw["container"]["cargo-drone-deployer-drone-container"]

mod_data.items = {}
mod_data.burnt_results_enabled = false

local inventory_size = nil

local function make_drone_deployer_sprites(drone_prototype, drone_data)
    if not drone_data.deployer_sprites then
        error("The drone data for " .. drone_prototype.name .. " is missing the deployer_sprites table.")
    end

    local sprite_names = {
        north = {
            "cargo-drone-deployer-" .. drone_prototype.name .."-north-1",
            "cargo-drone-deployer-" .. drone_prototype.name .."-north-2",
            "cargo-drone-deployer-" .. drone_prototype.name .."-north-3",
            "cargo-drone-deployer-" .. drone_prototype.name .."-north-4",
        },
        east = {
            "cargo-drone-deployer-" .. drone_prototype.name .."-east-1",
            "cargo-drone-deployer-" .. drone_prototype.name .."-east-2",
            "cargo-drone-deployer-" .. drone_prototype.name .."-east-3",
            "cargo-drone-deployer-" .. drone_prototype.name .."-east-4",
        },
        south = {
            "cargo-drone-deployer-" .. drone_prototype.name .."-south-1",
            "cargo-drone-deployer-" .. drone_prototype.name .."-south-2",
            "cargo-drone-deployer-" .. drone_prototype.name .."-south-3",
            "cargo-drone-deployer-" .. drone_prototype.name .."-south-4",
        },
        west = {
            "cargo-drone-deployer-" .. drone_prototype.name .."-west-1",
            "cargo-drone-deployer-" .. drone_prototype.name .."-west-2",
            "cargo-drone-deployer-" .. drone_prototype.name .."-west-3",
            "cargo-drone-deployer-" .. drone_prototype.name .."-west-4",
        },
    }
    local shadow_names = {
        north   = "cargo-drone-deployer-" .. drone_prototype.name .."-shadow-north",
        east    = "cargo-drone-deployer-" .. drone_prototype.name .."-shadow-east",
        south   = "cargo-drone-deployer-" .. drone_prototype.name .."-shadow-south",
        west    = "cargo-drone-deployer-" .. drone_prototype.name .."-shadow-west",
    }

    local body_data = drone_data.deployer_sprites.body
    local shadow_data = drone_data.deployer_sprites.shadow

    if not body_data then
        error("The drone data for " .. drone_prototype.name .. " is missing the deployer_sprites.body table.")
    end
    if not shadow_data then
        error("The drone data for " .. drone_prototype.name .. " is missing the deployer_sprites.shadow table.")
    end

    local mults = {
        1/8 * 3,
        1/8 * 2,
        1/8,
        0,
    }
    local sprites = {}

    for _, cardinal in ipairs({ "north", "east", "south", "west" }) do
        if body_data.positions[cardinal] then
            local position = body_data.positions[cardinal]

            for i = 1, 4 do
                local sprite_name = sprite_names[cardinal][i]

                if not data.raw.sprite[sprite_name] then
                    local height = (body_data.height / 4) * i

                    local sprite = {
                        type = "sprite",
                        name = sprite_names[cardinal][i],
                        filename = body_data.filename,
                        priority = "very-low",
                        x = position.x or position[1],
                        y = position.y or position[2],
                        width = body_data.width,
                        height = height,
                        shift = { body_data.shift[1], util.by_pixel(0, -body_data.height / 2)[2] * mults[i] },
                        scale = body_data.scale,
                        mipmap_count = 2
                    }

                    table.insert(sprites, sprite)
                end
            end
        end
    end
    for _, cardinal in ipairs({ "north", "east", "south", "west" }) do
        local position = shadow_data.positions[cardinal]

        if position ~= nil then
            local sprite_name = shadow_names[cardinal]

            if not data.raw.sprite[sprite_name] then
                local sprite = {
                    type = "sprite",
                    name = shadow_names[cardinal],
                    filename = shadow_data.filename,
                    priority = "very-low",
                    x = position.x or position[1],
                    y = position.y or position[2],
                    width = shadow_data.width,
                    height = shadow_data.height,
                    shift = { 0, shadow_data.shift[2] },
                    scale = shadow_data.scale,
                    mipmap_count = 2,
                    draw_as_shadow = true,
                }

                table.insert(sprites, sprite)
            end
        end
    end

    data:extend(sprites)

    for _, cardinal in pairs(sprite_names) do
        for _, sprite_name in ipairs(cardinal) do
            if data.raw.sprite[sprite_name] == nil then
                error("Missing sprite or deployer sprite data " .. sprite_name)
            end
        end
    end
    for _, sprite_name in pairs(shadow_names) do
        if data.raw.sprite[sprite_name] == nil then
            error("Missing shadow sprite or deployer shadow data " .. sprite_name)
        end
    end
end

for name, drone_data in pairs(mod_data.drones) do
    local drone_prototype = data.raw.car[name]

    if drone_prototype then
        if inventory_size ~= nil and inventory_size ~= drone_prototype.inventory_size then
            error("All cargo drones must have the same inventory size.")
        end

        inventory_size = drone_prototype.inventory_size
        make_drone_deployer_sprites(drone_prototype, drone_data)

        local energy_source = { type = "void" }

        if drone_prototype.energy_source.type == "burner" then
            if drone_prototype.energy_source.burnt_inventory_size > 0 then
                mod_data.burnt_results_enabled = true
            end
            energy_source = {
                type = "burner",
                fuel_inventory_size = drone_prototype.energy_source.fuel_inventory_size,
                fuel_categories = drone_prototype.energy_source.fuel_categories,
                auto_refuel = false,
            }
        end

        local deployer_dummy_fuel_drone = {
            type = "car",
            name = "cargo-drone-deployer-dummy-fuel-" .. name,
            flags = {
                "hide-alt-info",
                "not-upgradable",
                "not-deconstructable",
                "player-creation",
	            "placeable-off-grid",
	            "not-flammable",
                "not-on-map",
                "not-blueprintable",
                "not-repairable",
                "not-in-kill-statistics",
                "no-automated-item-insertion",
                "no-automated-item-removal",
            },
            hidden = true,
            hidden_in_factoriopedia = true,
            selectable_in_game = false,
            selection_priority = selection_priorities.editor_only,
            selection_box = drone_prototype.selection_box,
            collision_mask = { layers = {} },
            effectivity = 1,
            consumption = "10W",
            rotation_speed = 1,
            rotation_snap_angle = 1,
            energy_source = energy_source,
            inventory_size = 0,
            weight = 1,
            braking_force = 1,
            friction_force = 1,
            energy_per_hit_point = 1,
        }

        data:extend{
            deployer_dummy_fuel_drone
        }
    end
end

local drone_count = 0

for name, item in pairs(data.raw.item) do
    if item.place_result and mod_data.drones[item.place_result] then
        table.insert(mod_data.items, name)
        drone_count = drone_count + 1
    end
end
for name, item in pairs(data.raw["item-with-entity-data"]) do
    if item.place_result and mod_data.drones[item.place_result] then
        table.insert(mod_data.items, name)
        drone_count = drone_count + 1
    end
end

deployer_drone_container.inventory_size = drone_count
