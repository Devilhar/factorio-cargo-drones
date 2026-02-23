
--[[
To stop requester moorings from requesting items it just received, stop them from making any new requests for a short duration.
This is because the signals take 1 tick to update, and the user shouldn't need to read the content of any inserter.
]]--

local constants = require("scripts.constants")

local requester_cooldown = {}

function requester_cooldown.tick()
    if not storage.requester_cooldown then
        return
    end

    local removal = {}

    for unit_number, cooldown in pairs(storage.requester_cooldown) do
        storage.requester_cooldown[unit_number] = cooldown - 1

        if storage.requester_cooldown[unit_number] <= 0 then
            table.insert(removal, unit_number)
        end
    end

    for _, unit_number in ipairs(removal) do
        storage.requester_cooldown[unit_number] = nil
    end
end

function requester_cooldown.flag_for_cooldown(requester_unit_number)
    if not storage.requester_cooldown then
        storage.requester_cooldown = {}
    end

    storage.requester_cooldown[requester_unit_number] = constants.cooldown_ticks
end
function requester_cooldown.is_on_cooldown(requester_unit_number)
    if not storage.requester_cooldown then
        return false
    end

    return storage.requester_cooldown[requester_unit_number] ~= nil
end

return requester_cooldown
