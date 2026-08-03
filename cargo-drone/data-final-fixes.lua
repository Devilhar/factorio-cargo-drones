
local mod_data = data.raw["mod-data"]["cargo-drone-data"].data
local deployer_drone_container = data.raw["container"]["cargo-drone-deployer-drone-container"]

mod_data.items = {}
mod_data.burnt_results_enabled = false
mod_data.inventory_size = 0

local inventory_size = nil
local invalid_drones = {}

local function validate_drone_data(drone_name, drone_data)
    local function is_vector(value)
        return (type(value) == "table" or type(value) == "userdata")
            and (type(value.x) == "number" or type(value[1]) == "number")
            and (type(value.y) == "number" or type(value[2]) == "number")
    end

    if type(drone_data.version) ~= "number" then
        error("The drone data for " .. drone_name .. " is missing the version number.")
    end

    if drone_data.version ~= 1 then
        error("The drone data for " .. drone_name .. " has an invalid version number. Version must be equal to 1.")
    end

    if type(drone_data.cable) ~= "table" then
        error("The drone data for " .. drone_name .. " is missing the cable table.")
    end

    if not is_vector(drone_data.cable.attachment_offset) then
        error("The drone data for " .. drone_name .. " is missing the cable.attachment_offset Vector.")
    end
    if not is_vector(drone_data.cable.attachment_shadow_offset) then
        error("The drone data for " .. drone_name .. " is missing the cable.attachment_shadow_offset Vector.")
    end

    if type(drone_data.deployer) ~= "table" then
        error("The drone data for " .. drone_name .. " is missing the deployer table.")
    end

    if type(drone_data.deployer.body) ~= "table" then
        error("The drone data for " .. drone_name .. " is missing the deployer.body table.")
    end

    if not is_vector(drone_data.deployer.body.spawn_offset) then
        error("The drone data for " .. drone_name .. " is missing the deployer.body.spawn_offset Vector.")
    end
    if not is_vector(drone_data.deployer.body.prepare_offset) then
        error("The drone data for " .. drone_name .. " is missing the deployer.body.prepare_offset Vector.")
    end

    if drone_data.deployer.body.positions ~= nil then
        if type(drone_data.deployer.body.positions) ~= "table" then
            error("The drone data for " .. drone_name .. " has an invalid type for the deployer.body.positions table.")
        end

        if type(drone_data.deployer.body.filename) ~= "string" then
            error("The drone data for " .. drone_name .. " is missing the deployer.body.filename string.")
        end
        if type(drone_data.deployer.body.width) ~= "number" then
            error("The drone data for " .. drone_name .. " is missing the deployer.body.width number.")
        end
        if type(drone_data.deployer.body.height) ~= "number" then
            error("The drone data for " .. drone_name .. " is missing the deployer.body.height number.")
        end
        if drone_data.deployer.body.scale ~= nil and type(drone_data.deployer.body.scale) ~= "number" then
            error("The drone data for " .. drone_name .. " has an invalid type for the deployer.body.scale number.")
        end
        if drone_data.deployer.body.shift ~= nil and not is_vector(drone_data.deployer.body.shift) then
            error("The drone data for " .. drone_name .. " has an invalid type for the deployer.body.shift Vector.")
        end
    end

    if type(drone_data.deployer.shadow) ~= "table" then
        error("The drone data for " .. drone_name .. " is missing the deployer.shadow table.")
    end

    if not is_vector(drone_data.deployer.shadow.prepare_offset) then
        error("The drone data for " .. drone_name .. " is missing the deployer.shadow.prepare_offset Vector.")
    end

    if drone_data.deployer.shadow.positions ~= nil then
        if type(drone_data.deployer.shadow.positions) ~= "table" then
            error("The drone data for " .. drone_name .. " has an invalid type for the deployer.shadow.positions table.")
        end

        if type(drone_data.deployer.shadow.filename) ~= "string" then
            error("The drone data for " .. drone_name .. " is missing the deployer.shadow.filename string.")
        end
        if type(drone_data.deployer.shadow.width) ~= "number" then
            error("The drone data for " .. drone_name .. " is missing the deployer.shadow.width number.")
        end
        if type(drone_data.deployer.shadow.height) ~= "number" then
            error("The drone data for " .. drone_name .. " is missing the deployer.shadow.height number.")
        end
        if drone_data.deployer.shadow.scale ~= nil and type(drone_data.deployer.shadow.scale) ~= "number" then
            error("The drone data for " .. drone_name .. " has an invalid type for the deployer.shadow.scale number.")
        end
        if drone_data.deployer.shadow.shift ~= nil and not is_vector(drone_data.deployer.shadow.shift) then
            error("The drone data for " .. drone_name .. " is missing the deployer.shadow.shift Vector.")
        end
    end
end
local function make_drone_deployer_sprites(drone_prototype, drone_data)
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

    local body_data = drone_data.deployer.body
    local shadow_data = drone_data.deployer.shadow

    local mults = {
        1/8 * 3,
        1/8 * 2,
        1/8,
        0,
    }
    local sprites = {}

    if body_data.positions then
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
                            shift = { body_data.shift.x or body_data.shift[1], (body_data.shift.y or body_data.shift[2]) - util.by_pixel(0, body_data.height / 2)[2] * mults[i] },
                            scale = body_data.scale,
                            mipmap_count = 2
                        }

                        table.insert(sprites, sprite)
                    end
                end
            end
        end
    end
    if shadow_data.positions then
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
                        shift = shadow_data.shift,
                        scale = shadow_data.scale,
                        mipmap_count = 2,
                        draw_as_shadow = true,
                    }

                    table.insert(sprites, sprite)
                end
            end
        end
    end

    if next(sprites) ~= nil then
        data:extend(sprites)
    end

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
        validate_drone_data(name, drone_data)

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
    else
        table.insert(invalid_drones, name)
    end
end

for _, name in ipairs(invalid_drones) do
    mod_data.drones[name] = nil
end

mod_data.inventory_size = inventory_size or 0

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
