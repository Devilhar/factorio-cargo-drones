
local window_gui_name = "cargo-drone-mooring"
local close_button_gui_name = "cargo-drone-mooring-close-button"

local function build_gui(player, mooring)
    local frame = player.gui.screen.add{
        type = "frame",
        name = window_gui_name,
        direction = "vertical"
    }

    frame.auto_center = true

    local titlebar = frame.add{
        type = "flow",
        direction = "horizontal",
    }

    titlebar.drag_target = frame
    titlebar.style.horizontal_spacing = 8
    titlebar.style.height = 28

    local title = titlebar.add{
        type = "label",
        caption = mooring.localised_name,
        style = "frame_title",
        ignored_by_interaction = true
    }

    title.drag_target = frame

    local filler = titlebar.add{
        type = "empty-widget",
        style = "draggable_space_header",
    }

    filler.style.height = 24
    filler.style.horizontally_stretchable = true
    filler.style.left_margin = 4
    filler.style.right_margin = 4
    filler.drag_target = frame

    titlebar.add{
        type = "sprite-button",
        name = close_button_gui_name,
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        style = "frame_action_button",
        tooltip = { "gui.close-instruction" },
    }

    storage.player_gui[player.index] = {
        frame = frame,
        entity_unit_number = mooring.unit_number
    }
    storage.gui_entity_lookup[mooring.unit_number] = player.index

    player.opened = frame
end

local gui_mooring = {}

function gui_mooring.create_player_storage()
    storage.player_gui = storage.player_gui or {}
    storage.gui_entity_lookup = storage.gui_entity_lookup or {}
end

function gui_mooring.on_gui_opened(event)
	local entity = event.entity

	if not entity or not entity.valid then
		return
	end

	if entity.name ~= "cargo-drone-provider-mooring"
        and entity.name ~= "cargo-drone-requester-mooring"
        and entity.name ~= "cargo-drone-refuel-mooring" then
        return
	end

    local player = game.get_player(event.player_index)

    if player.gui.screen[window_gui_name] then
        return
    end

    player.opened = nil

    build_gui(player, entity)
end
function gui_mooring.on_gui_closed(event)
	if event.gui_type ~= defines.gui_type.custom then
		return
	end

	local player = game.get_player(event.player_index)

    if event.element ~= player.gui.screen[window_gui_name] then
        return
    end

    if not storage.player_gui[event.player_index] then
        return
    end

    player.gui.screen[window_gui_name].destroy()
    storage.gui_entity_lookup[storage.player_gui[event.player_index].entity_unit_number] = nil

    storage.player_gui[event.player_index] = nil

    player.opened = nil
end
function gui_mooring.on_gui_click(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    local player = game.get_player(event.player_index)

    if element.name ~= close_button_gui_name then
        return
    end

    if not player.gui.screen[window_gui_name] then
        return
    end

    player.opened = nil
end
function gui_mooring.on_object_destroyed(event)
    local player_index = storage.gui_entity_lookup[event.useful_id]

    if player_index == nil then
        return
    end

    local player = game.get_player(player_index)

    if not player then
        return
    end

    player.opened = nil
end

return gui_mooring
