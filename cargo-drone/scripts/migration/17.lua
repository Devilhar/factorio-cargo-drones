
local mooring_names = {
    ["cargo-drone-mooring-constant-combinator-provider"] = {
        name = "Provider",
        filters = {
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-1",
                    quality = "normal",
                },
                min = -160468400
            },
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-2",
                    quality = "normal",
                },
                min = -228236183
            },
        }
    },
    ["cargo-drone-mooring-constant-combinator-requester"] = {
        name = "Requester",
        filters = {
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-1",
                    quality = "normal",
                },
                min = -177117870
            },
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-2",
                    quality = "normal",
                },
                min = -445353115
            },
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-3",
                    quality = "normal",
                },
                min = -2147483534
            },
        }
    },
    ["cargo-drone-mooring-constant-combinator-refueler"] = {
        name = "Refueler",
        filters = {
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-1",
                    quality = "normal",
                },
                min = -177838766
            },
            {
                value = {
                    type = "virtual",
                    name = "cargo-drone-signal-2",
                    quality = "normal",
                },
                min = -228234139
            },
        }
    },
}
local depot_name = {
    name = "Depot",
    filters = {
        {
            value = {
                type = "virtual",
                name = "cargo-drone-signal-1",
                quality = "normal",
            },
            min = -277846716
        },
        {
            value = {
                type = "virtual",
                name = "cargo-drone-signal-2",
                quality = "normal",
            },
            min = -2147483532
        },
    }
}

local function manage_entity(entity)
    storage.managed_entities[entity.unit_number] = {
        entity = entity,
        properties = {}
    }
end

local function migrate_mooring(mooring)
--[[
    name                            = nil -> 5,
    inventory_targets               = 5 -> 6,
    output_requests                 = 6 -> 7,
    drone_id_output                 = 7 -> 8,
]]
    local cb = mooring.get_control_behavior()

    cb.add_section()

    local sections = cb.sections

    sections[8].filters = sections[7].filters

    sections[7].filters = sections[6].filters

    sections[6].filters = sections[5].filters

    local type_name = mooring_names[mooring.name]

    if mooring.name == "entity-ghost" then
        type_name = mooring_names[mooring.ghost_name]
        manage_entity(mooring)
    end

    sections[5].filters = type_name.filters
    storage.managed_entities[mooring.unit_number].properties["target_name"] = type_name.name

    sections[6].active = false
    sections[8].active = true
end
local function migrate_depot(depot)
    local cb = depot.get_control_behavior()

    local section_name = cb.add_section()

    if depot.name == "entity-ghost" then
        manage_entity(depot)
    end

    section_name.filters = depot_name.filters
    storage.managed_entities[depot.unit_number].properties["target_name"] = depot_name.name
end

return function()
    local filters_mooring = {
        { name = "cargo-drone-mooring-constant-combinator-provider" },
        { name = "cargo-drone-mooring-constant-combinator-requester" },
        { name = "cargo-drone-mooring-constant-combinator-refueler" },
        { ghost_name = "cargo-drone-mooring-constant-combinator-provider" },
        { ghost_name = "cargo-drone-mooring-constant-combinator-requester" },
        { ghost_name = "cargo-drone-mooring-constant-combinator-refueler" },
    }
    local filters_depot = {
        { name = "cargo-drone-depot-constant-combinator" },
        { ghost_name = "cargo-drone-depot-constant-combinator" },
    }

	for _, surface in pairs(game.surfaces) do
        for _, filter in ipairs(filters_mooring) do
            for _, entity in pairs(surface.find_entities_filtered(filter)) do
                migrate_mooring(entity)
            end
        end
        for _, filter in ipairs(filters_depot) do
            for _, entity in pairs(surface.find_entities_filtered(filter)) do
                migrate_depot(entity)
            end
        end
	end
end
