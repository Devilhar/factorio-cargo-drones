
local function migrate_target(target)
    -- V was missing, shift everything down by 1 past it
    local cb = target.get_control_behavior()

    local section_name = cb.get_section(6)

    local filters = section_name.filters
    local new_names = {
        ["cargo-drone-signal-W"] = "cargo-drone-signal-V",
        ["cargo-drone-signal-X"] = "cargo-drone-signal-W",
        ["cargo-drone-signal-Y"] = "cargo-drone-signal-X",
        ["cargo-drone-signal-Z"] = "cargo-drone-signal-Y",
    }

    for _, filter in ipairs(filters) do
        if filter.value and new_names[filter.value.name] ~= nil then
            filter.value.name = new_names[filter.value.name]
        end
    end

    section_name.filters = filters
end

return function()
    local filters_target = {
        { name = "cargo-drone-mooring-constant-combinator-provider" },
        { name = "cargo-drone-mooring-constant-combinator-requester" },
        { name = "cargo-drone-mooring-constant-combinator-refueler" },
        { name = "cargo-drone-depot-constant-combinator" },
        { ghost_name = "cargo-drone-mooring-constant-combinator-provider" },
        { ghost_name = "cargo-drone-mooring-constant-combinator-requester" },
        { ghost_name = "cargo-drone-mooring-constant-combinator-refueler" },
        { ghost_name = "cargo-drone-depot-constant-combinator" },
    }

	for _, surface in pairs(game.surfaces) do
        for _, filter in ipairs(filters_target) do
            for _, entity in pairs(surface.find_entities_filtered(filter)) do
                migrate_target(entity)
            end
        end
	end
end
