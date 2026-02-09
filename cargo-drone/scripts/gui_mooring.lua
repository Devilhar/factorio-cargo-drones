
local mh = require("scripts.mooring_helper")

local gui_prefix = "cargo-drone-"

local window_gui_name = gui_prefix .. "window-mooring-main"
local window_gui_circuit_network_name = gui_prefix .. "window-mooring-circuit-network"

local not_observed = {}

local function register_on_click(player, element, callback)
    if element.name == "" then
        error("Registered nameless GuiElement")
    end

    storage.gui_player[player.index].on_click[element.name] = callback
end
local function register_on_changed(player, element, callback)
    if element.name == "" then
        error("Registered nameless GuiElement")
    end

    storage.gui_player[player.index].on_changed[element.name] = callback
end
local function register_data_observer(player, get_data, callable)
    table.insert(storage.gui_player[player.index].data_observers, {
        get_data = get_data,
        callable = callable,
        previous_data = not_observed
    })
end

local function handle_event(event, action_type)
    local element = event.element

    if not element or not element.valid then
        return
    end

    local player = game.get_player(event.player_index)

    if not storage.gui_player[player.index] then
        return
    end

    local callable = storage.gui_player[player.index][action_type][element.name]

    if not callable then
        return
    end

    callable()
end

local function build_gui_mooring(player, mooring, parent)
    local mooring_frame = parent.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    mooring_frame.style.padding = 16

    ---------- Entity preview ----------
    local preview_frame = mooring_frame.add{
        type = "frame",
        direction = "horizontal",
        style = "inside_deep_frame"
    }
    
    preview_frame.style.bottom_margin = 16

    local preview = preview_frame.add{
        type = "entity-preview",
        style = "wide_entity_button"
    }

    preview.entity = mooring
    preview.style.width = 400
    preview.style.height = 150

    ---------- Drone limit ----------
    local drone_limit_flow = mooring_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    drone_limit_flow.style.vertical_align = "center"
    drone_limit_flow.style.horizontal_spacing = 8
    drone_limit_flow.style.bottom_margin = 8

    local drone_limit_checkbox = drone_limit_flow.add{
        type = "checkbox",
        name = gui_prefix .. "drone-limit-checkbox",
        caption = "Enable drone limit", -- FIXME: Localize
        state = mh.is_drone_limit_enabled(mooring)
    }

    local drone_limit_filler = drone_limit_flow.add{
        type = "empty-widget",
    }

    drone_limit_filler.style.horizontally_stretchable = true

    local drone_limit_slider = drone_limit_flow.add{
        type = "slider",
        name = gui_prefix .. "drone-limit-slider",
        style = "notched_slider",
        minimum_value = 0,
        maximum_value = 8,
        value_step = 1
    }

    local drone_limit_field = drone_limit_flow.add{
        type = "textfield",
        name = gui_prefix .. "drone-limit-textfield",
        style = "slider_value_textfield",
        numeric = true
    }

    drone_limit_field.style.maximal_width = 40

    register_on_changed(player, drone_limit_checkbox, function()
        mh.set_drone_limit_enabled(mooring, drone_limit_checkbox.state)
    end)
    register_on_changed(player, drone_limit_slider, function()
        mh.set_drone_limit_value(mooring, drone_limit_slider.slider_value)
    end)
    register_on_changed(player, drone_limit_field, function()
        local limit = tonumber(drone_limit_field.text)

        if limit == nil then
            return
        end

        mh.set_drone_limit_value(mooring, limit)
    end)

    register_data_observer(player,
        function() return mh.is_drone_limit_enabled(mooring) end,
        function(data)
            drone_limit_checkbox.state = data
            drone_limit_slider.enabled = data
            drone_limit_field.enabled = data
        end)
    register_data_observer(player,
        function() return mh.get_drone_limit(mooring) end,
        function(data)
            if data == nil then
                data = 0
            end

            drone_limit_slider.slider_value = data
            drone_limit_field.text = tostring(data)
        end)

    drone_limit_slider.enabled = drone_limit_checkbox.state
    drone_limit_field.enabled = drone_limit_checkbox.state

    ---------- Priority ----------
    local priority_flow = mooring_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    priority_flow.style.vertical_align = "center"
    priority_flow.style.horizontal_spacing = 8
    priority_flow.style.bottom_margin = 8

    priority_flow.add{
        type = "label",
        caption = "Priority", -- FIXME: Localize
    }

    local priority_filler = priority_flow.add{
        type = "empty-widget",
    }

    priority_filler.style.horizontally_stretchable = true

    local priority_slider = priority_flow.add{
        type = "slider",
        name = gui_prefix .. "priority-slider",
        style = "notched_slider",
        minimum_value = 0,
        maximum_value = 90,
        value = mh.get_priority_value(mooring),
        value_step = 10
    }

    local priority_field = priority_flow.add{
        type = "textfield",
        name = gui_prefix .. "priority-textfield",
        style = "slider_value_textfield",
        text = tostring(mh.get_priority_value(mooring)),
        numeric = true
    }

    priority_field.style.maximal_width = 40

    register_on_changed(player, priority_slider, function()
        mh.set_priority_value(mooring, priority_slider.slider_value)
    end)
    register_on_changed(player, priority_field, function()
        local priority = tonumber(priority_field.text)

        if priority == nil then
            return
        end

        mh.set_priority_value(mooring, priority)
    end)

    register_data_observer(player,
        function() return mh.is_priority_circuit(mooring) end,
        function(data)
            priority_field.enabled = not data
            priority_slider.enabled = not data
        end)
    register_data_observer(player,
        function() return mh.get_priority(mooring) end,
        function(data)
            priority_field.text = tostring(data)
            priority_slider.slider_value = data
        end)

    ---------- Filler ----------
    local mooring_filler = mooring_frame.add{
        type = "empty-widget",
        style = "entity_frame_filler"
    }

    mooring_filler.style.vertically_stretchable = true
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
    }

    drone_table.style.horizontally_stretchable = true
    drone_table.style.margin = 0

    for i = 1, 5 do
        local minimap_border = drone_table.add{
            type = "frame",
            style = "shallow_frame",
            direction = "vertical",
        }

        local minimap_frame = minimap_border.add{
            type = "frame",
            style = "inside_deep_frame",
            direction = "vertical",
        }

        minimap_frame.style.margin = 4

        local minimap_flow = minimap_frame.add{
            type = "flow",
            direction = "horizontal",
        }

        local minimap = minimap_flow.add{
            type = "minimap",
            name = "cargo-drone-mooring-drone-minimap-" .. i,
            raise_hover_events = true
        }

        minimap.entity = mooring
        minimap.style.height = 120
        minimap.style.width = 240

        local drone_task_frame = minimap_border.add{
            type = "frame",
            style = "inside_deep_frame"
        }

        drone_task_frame.style.margin = 4

        local drone_task_header_frame = drone_task_frame.add{
            type = "frame",
            style = "subheader_frame"
        }

        drone_task_header_frame.style.horizontally_stretchable = true
        drone_task_header_frame.style.vertical_align = "center"

        drone_task_header_frame.add{
            type = "label",
            caption = "Heading to provider [color=0.1,0.7,1.0][" .. i .. "m][/color]", -- FIXME: Localize
            style = "subheader_label"
        }
    end
end

local function build_gui_circuit(player, mooring, show_circuit_network)
    local frame = player.gui.screen.add{
        type = "frame",
        name = window_gui_circuit_network_name,
        direction = "vertical",
        visible = show_circuit_network,
    }

    local titlebar = frame.add{
        type = "flow",
        direction = "horizontal",
    }

    titlebar.drag_target = frame

    local title = titlebar.add{
        type = "label",
        caption = { "gui-control-behavior.circuit-connection" },
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

    local main_frame = frame.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    local priority_circuit_checkbox = main_frame.add{
        type = "checkbox",
        name = gui_prefix .. "set-priority-checkbox",
        caption = "Set priority", -- FIXME: Localize
        --style = "",
        state = mh.is_priority_circuit(mooring)
    }

    priority_circuit_checkbox.style.top_margin = 8
    priority_circuit_checkbox.style.bottom_margin = 8
    priority_circuit_checkbox.style.left_margin = 13
    priority_circuit_checkbox.style.right_margin = 13

    register_on_changed(player, priority_circuit_checkbox, function()
        mh.set_priority_circuit(mooring, priority_circuit_checkbox.state)
    end)
    register_data_observer(player,
        function() return mh.is_priority_circuit(mooring) end,
        function(data)
            priority_circuit_checkbox.state = data
        end)

    main_frame.add{
        type = "line",
    }

    return frame
end

local function build_gui(player, mooring)
    storage.gui_player[player.index] = {
        entity_unit_number = mooring.unit_number,
        on_click = {},
        on_changed = {},
        data_observers = {}
    }
    storage.gui_entity_lookup[mooring.unit_number] = player.index

    local show_circuit_network =
        mooring.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil
        or mooring.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil

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

    local button_circuit_network = titlebar.add{
        type = "sprite-button",
        name = gui_prefix .. "mooring-circuit-button",
        sprite = "utility/circuit_network_panel",
        hovered_sprite = "utility/circuit_network_panel",
        clicked_sprite = "utility/circuit_network_panel",
        style = "frame_action_button",
        tooltip = { "gui-control-behavior.circuit-network" },
        auto_toggle = true,
        toggled = show_circuit_network
    }

    local button_close = titlebar.add{
        type = "sprite-button",
        name = gui_prefix .. "mooring-close-button",
        sprite = "utility/close",
        hovered_sprite = "utility/close",
        clicked_sprite = "utility/close",
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

    local circuit_frame = build_gui_circuit(player, mooring, show_circuit_network)

    register_on_click(player, button_circuit_network, function()
        circuit_frame.visible = not circuit_frame.visible
    end)

    register_on_click(player, button_close, function()
        if not player.gui.screen[window_gui_name] then
            return
        end

        player.opened = nil
    end)

    player.opened = frame
end

local gui_mooring = {}

function gui_mooring.create_player_storage()
    storage.gui_player = storage.gui_player or {}
    storage.gui_entity_lookup = storage.gui_entity_lookup or {}
end

function gui_mooring.update_data_observers()
    -- If you're here looking for a good way to handle data changes and GUI. Go elsewhere. There's nothing for you here
    for player_index, player_data in pairs(storage.gui_player) do
        for _, observer in ipairs(player_data.data_observers) do
            local data = observer.get_data()

            if data ~= observer.previous_data then
                observer.callable(data)

                observer.previous_data = data
            end
        end
    end
end

function gui_mooring.on_gui_opened(event)
	local entity = event.entity

	if not entity or not entity.valid then
		return
	end

    local entity_name = entity.name

    if entity_name == "entity-ghost" then
        entity_name = entity.ghost_name
    end

	if entity_name ~= "cargo-drone-mooring-constant-combinator-provider"
        and entity_name ~= "cargo-drone-mooring-constant-combinator-requester"
        and entity_name ~= "cargo-drone-mooring-constant-combinator-refueler" then
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

    if not storage.gui_player[event.player_index] then
        return
    end

    player.gui.screen[window_gui_name].destroy()
    if player.gui.screen[window_gui_circuit_network_name] then
        player.gui.screen[window_gui_circuit_network_name].destroy()
    end
    storage.gui_entity_lookup[storage.gui_player[event.player_index].entity_unit_number] = nil

    storage.gui_player[event.player_index] = nil

    player.opened = nil
end
function gui_mooring.on_gui_location_changed(event)
    local player = game.get_player(event.player_index)

    local mooring_window = player.gui.screen[window_gui_name]
    local mooring_circuit_window = player.gui.screen[window_gui_circuit_network_name]

    if event.element == mooring_window then
        if not mooring_circuit_window then
            return
        end

        mooring_circuit_window.location = { x = mooring_window.location.x + 945, y = mooring_window.location.y }
    elseif event.element == mooring_circuit_window then
        if not mooring_window then
            return
        end

        mooring_window.location = { x = mooring_circuit_window.location.x - 945, y = mooring_circuit_window.location.y }
    end
end
function gui_mooring.on_gui_click(event)
    handle_event(event, "on_click")
end
function gui_mooring.on_gui_checked_state_changed(event)
    handle_event(event, "on_changed")
end
function gui_mooring.on_gui_value_changed(event)
    handle_event(event, "on_changed")
end
function gui_mooring.on_gui_text_changed(event)
    handle_event(event, "on_changed")
end
function gui_mooring.on_gui_hover(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    if element.name:sub(1, 34) == "cargo-drone-mooring-drone-minimap-" then
        --game.print("HOVER: " .. element.name)
    end
end
function gui_mooring.on_gui_leave(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    if element.name:sub(1, 34) == "cargo-drone-mooring-drone-minimap-" then
        --game.print("LEAVE: " .. element.name)
    end
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
