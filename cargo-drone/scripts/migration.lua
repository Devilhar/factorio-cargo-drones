
local constants = require("constants")

local function create_apply_patch(patch_mod_state)
    local applyer = require(patch_mod_state)

    return function(old_mod_state)
        log("Applying " .. patch_mod_state .. "...")

        applyer(old_mod_state)
    end
end

local patches = {
    {
        mod_state = 4,
        apply = create_apply_patch("migration.4")
    },
    {
        mod_state = 6,
        apply = create_apply_patch("migration.6")
    },
    {
        mod_state = 7,
        apply = create_apply_patch("migration.7")
    },
    {
        mod_state = 8,
        apply = create_apply_patch("migration.8")
    },
    {
        mod_state = 9,
        apply = create_apply_patch("migration.9")
    },
    {
        mod_state = 12,
        apply = create_apply_patch("migration.12")
    },
    {
        mod_state = 13,
        apply = create_apply_patch("migration.13")
    },
    {
        mod_state = 14,
        apply = create_apply_patch("migration.14")
    },
}

local migration = {}

function migration.run_migration()
	if not storage.mod_state and storage.depot_helper then
         -- The state was never set when creating a new save in version 1.9.0. So assume that if it's nil and the depot_helper is set, it was that version.
        storage.mod_state = 13
    end

    if storage.mod_state and storage.mod_state >= constants.current_mod_state then
        return
    end

    local old_mod_state = storage.mod_state or 0

    log("Migrating cargo-drone state from " .. old_mod_state .. " to " .. constants.current_mod_state .. "...")

    storage.mod_state = constants.current_mod_state

    for _, patch in ipairs(patches) do
        if old_mod_state < patch.mod_state then
            patch.apply()
        end
    end

    log("cargo-drone state migration complete")
end

return migration
