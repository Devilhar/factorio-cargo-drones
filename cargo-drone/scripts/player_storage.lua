
local function reset_map_overlay(player_index)
    for i, index in ipairs(storage.player_storage.show_map_overlays) do
		if index == player_index then
			table.remove(storage.player_storage.show_map_overlays, i)

			return true
		end
	end

    return false
end

local player_storage = {}

function player_storage.init()
    storage.player_storage = storage.player_storage or {}

    storage.player_storage.show_map_overlays = storage.player_storage.show_map_overlays or {}
end

function player_storage.player_removed(player_index)
    reset_map_overlay(player_index)
end

function player_storage.toggle_player_map_overlay(player_index)
    if reset_map_overlay(player_index) then
        return
    end

	table.insert(storage.player_storage.show_map_overlays, player_index)
end
function player_storage.get_show_map_overlays()
    return storage.player_storage.show_map_overlays
end

return player_storage
