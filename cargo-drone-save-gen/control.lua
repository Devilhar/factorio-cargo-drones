
local symbols = {
    ["."] = 68,
    ["0"] = 29,
    ["1"] = 30,
    ["2"] = 31,
    ["3"] = 32,
    ["4"] = 33,
    ["5"] = 34,
    ["6"] = 35,
    ["7"] = 36,
    ["8"] = 37,
    ["9"] = 38,
}

local version_text_pos = { -15, 16 }

local function split_version(version)
    local vers = {}

    for str in string.gmatch(version, "([^\\.]+)") do
        table.insert(vers, tonumber(str))
    end

    return table.unpack(vers)
end

function on_surface_cleared(event)
    if not storage.gen then
        return
    end

    storage.gen = nil

	local surface = game.get_surface(event.surface_index)

    local cargo_drone_version = script.active_mods["cargo-drone"]

    local major, minor, patch = split_version(cargo_drone_version)

    local feature_switches = {
        proxy_moorings = minor < 4,
        depot = minor >= 8,
    }

    local player = game.players[1]

    player.get_inventory(defines.inventory.character_main).clear()

    for i = 1, #cargo_drone_version do
        local letter = surface.create_entity{
            name = "textplate-large-plastic",
            position = { version_text_pos[1] + i * 2, version_text_pos[2] },
            force = player.force
        }

        local symbol = string.sub(cargo_drone_version, i, i)

        letter.graphics_variation = symbols[symbol]
    end

    local moorng_names = {}

    if feature_switches.proxy_moorings then
        moorng_names.provider   = "cargo-drone-provider-mooring"
        moorng_names.requester  = "cargo-drone-requester-mooring"
        moorng_names.refueler   = "cargo-drone-refuel-mooring"
    else
        moorng_names.provider   = "cargo-drone-mooring-constant-combinator-provider"
        moorng_names.requester  = "cargo-drone-mooring-constant-combinator-requester"
        moorng_names.refueler   = "cargo-drone-mooring-constant-combinator-refueler"
    end

    local provider = surface.create_entity{
        name = moorng_names.provider,
        position = { -9, -5 },
        force = player.force,
        raise_built = true
    }
    local requester = surface.create_entity{
        name = moorng_names.requester,
        position = { -3, -5 },
        force = player.force,
        raise_built = true
    }
    surface.create_entity{
        name = moorng_names.refueler,
        position = { 3, -5 },
        force = player.force,
        raise_built = true
    }
    local cc = surface.create_entity{
        name = "constant-combinator",
        position = { -6, -5 },
        force = player.force,
        raise_built = true
    }
    if feature_switches.depot then
        surface.create_entity{
            name = "cargo-drone-depot-constant-combinator",
            position = { 9, -5 },
            force = player.force,
            raise_built = true
        }
    end
    local drone = surface.create_entity{
        name = "cargo-drone",
        position = { -9, -4 },
        force = player.force,
        raise_built = true
    }

    local cc_wc = cc.get_wire_connector(defines.wire_connector_id.circuit_red)

    cc_wc.connect_to(provider.get_wire_connector(defines.wire_connector_id.circuit_red))
    cc_wc.connect_to(requester.get_wire_connector(defines.wire_connector_id.circuit_red))

    local cc_cb = cc.get_control_behavior()

    cc_cb.get_section(1).filters = {
        {
            value = {
                name = "iron-plate",
                quality = "normal",
            },
            min = 50
        },
        {
            value = {
                name = "copper-plate",
                quality = "normal",
            },
            min = 150
        },
        {
            value = {
                name = "steel-plate",
                quality = "normal",
            },
            min = 200
        },
    }

    drone.get_inventory(defines.inventory.fuel).insert{
        name = "coal",
        count = 100
    }

    surface.create_entity{
        name = "entity-ghost",
        inner_name = moorng_names.provider,
        position = { -9, 5 },
        force = player.force,
        raise_built = true
    }
    surface.create_entity{
        name = "entity-ghost",
        inner_name = moorng_names.requester,
        position = { -3, 5 },
        force = player.force,
        raise_built = true
    }
    surface.create_entity{
        name = "entity-ghost",
        inner_name = moorng_names.refueler,
        position = { 3, 5 },
        force = player.force,
        raise_built = true
    }
    if feature_switches.depot then
        surface.create_entity{
            name = "entity-ghost",
            inner_name = "cargo-drone-depot-constant-combinator",
            position = { 9, 5 },
            force = player.force,
            raise_built = true
        }
    end
    surface.create_entity{
        name = "entity-ghost",
        inner_name = "cargo-drone",
        position = { -9, 6 },
        force = player.force,
        raise_built = true
    }

end

script.on_event(defines.events.on_surface_cleared, on_surface_cleared)

-- /c remote.call("cargo-drone-save-gen", "generate")
remote.add_interface("cargo-drone-save-gen", {
	generate = function()
        storage.gen = true

		local surface = game.get_surface(1)

        surface.generate_with_lab_tiles = true

		surface.clear(true)
	end
})
