
local cargo_drone = data.raw["car"]["cargo-drone"]
local deployer_dummy_fuel_drone = data.raw["car"]["cargo-drone-deployer-dummy-fuel-drone"]
local deployer_drone_container = data.raw["container"]["cargo-drone-deployer-drone-container"]


deployer_dummy_fuel_drone.energy_source.fuel_inventory_size = cargo_drone.energy_source.fuel_inventory_size
deployer_dummy_fuel_drone.energy_source.fuel_categories = cargo_drone.energy_source.fuel_categories

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

    local sprite_data = drone_data.deployer_sprites.sprite
    local shadow_data = drone_data.deployer_sprites.shadow

    if not sprite_data then
        error("The drone data for " .. drone_prototype.name .. " is missing the deployer_sprites.sprite table.")
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
        if sprite_data.positions[cardinal] then
            local position = sprite_data.positions[cardinal]

            for i = 1, 4 do
                local sprite_name = sprite_names[cardinal][i]

                if not data.raw.sprite[sprite_name] then
                    local height = (sprite_data.height / 4) * i

                    local sprite = {
                        type = "sprite",
                        name = sprite_names[cardinal][i],
                        filename = sprite_data.filename,
                        priority = "very-low",
                        x = position.x or position[1],
                        y = position.y or position[2],
                        width = sprite_data.width,
                        height = height,
                        shift = { sprite_data.shift[1], util.by_pixel(0, -sprite_data.height / 2)[2] * mults[i] },
                        scale = sprite_data.scale,
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

local drone_count = 0

for name, drone_data in pairs(data.raw["mod-data"]["cargo-drone-data"].data.drones) do
    local drone_prototype = data.raw.car[name]

    if drone_prototype then
        if inventory_size ~= nil and inventory_size ~= drone_prototype.inventory_size then
            error("All cargo drones must have the same inventory size.")
        end

        drone_count = drone_count + 1
        inventory_size = drone_prototype.inventory_size
        make_drone_deployer_sprites(drone_prototype, drone_data)
    end
end

deployer_drone_container.inventory_size = drone_count
