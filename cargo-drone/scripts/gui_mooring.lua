
local window_gui_name = "cargo-drone-mooring"
local close_button_gui_name = "cargo-drone-mooring-close-button"

local function build_gui_mooring(player, mooring, parent)
    local mooring_frame = parent.add{
        type = "frame",
        name = "cargo-drone-mooring-frame", -- FIXME: Is it needed? What does it do?
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    local preview_flow = mooring_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    preview_flow.style.vertical_align = "center"
    preview_flow.style.horizontal_spacing = 8

    local preview = preview_flow.add{
        type = "entity-preview",
        name = "cargo-drone-preview", -- FIXME: Needed?
        style = "wide_entity_button",
    }

    preview.entity = mooring
    preview.style.height = 416
    preview.style.width = 160
end

local function build_gui_drones(player, mooring, parent)
    local drones_frame = parent.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }

    local subheader_frame = drones_frame.add{
        type = "frame",
        style = "subheader_frame"
    }

    subheader_frame.style.horizontally_stretchable = true
    subheader_frame.style.vertical_align = "center"

    subheader_frame.add{
        type = "label",
        caption = "Cargo drones on the way",
        style = "subheader_label"
    }

    local drones_scroll = drones_frame.add{
        type = "scroll-pane",
        style = "scroll_pane_in_shallow_frame"
    }

    drones_scroll.style.margin = 4
    drones_scroll.style.maximal_height = 416

    local drone_table = drones_scroll.add{
        type = "table",
        column_count = 1,
        --style = "bordered_table"
    }

    drone_table.style.horizontally_stretchable = true
    drone_table.style.margin = 0
    
    for i = 1, 6 do
        local minimap_border = drone_table.add{
            type = "frame",
            style = "shallow_frame",
            direction = "vertical",
        }

        minimap_border.style.margin = 4

        local minimap_frame = minimap_border.add{
            type = "frame",
            style = "inside_deep_frame",
            direction = "vertical",
        }

        --minimap_frame.style.margin = 4

        local minimap_flow = minimap_frame.add{
            type = "flow",
            direction = "horizontal",
        }

        local minimap = minimap_flow.add{
            type = "minimap",
            name = "cargo-drone-mooring-drone-minimap", -- FIXME: Needed?
        }

        minimap.entity = mooring
        minimap.style.height = 120
        minimap.style.width = 240
        
        local drone_task_frame = minimap_border.add{
            type = "frame",
            style = "inside_deep_frame"
        }

        local drone_task_header_frame = drone_task_frame.add{
            type = "frame",
            style = "subheader_frame"
        }

        drone_task_header_frame.style.horizontally_stretchable = true
        drone_task_header_frame.style.vertical_align = "center"

        drone_task_header_frame.add{
            type = "label",
            caption = "Heading to provider [42m]",
            style = "subheader_label"
        }

    end
end

local function build_gui(player, mooring)
    -- Shamelessly stolen from Entity GUI Library
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

    local main_flow = frame.add{
        type = "flow",
        direction = "horizontal",
    }

    main_flow.style.horizontal_spacing = 8

    build_gui_mooring(player, mooring, main_flow)

    build_gui_drones(player, mooring, main_flow)

    -- End steal mode

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
