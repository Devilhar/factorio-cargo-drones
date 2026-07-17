
-- If you're here looking for a good way to handle GUI. Go elsewhere. There's nothing for you here. Naught but despair

local dlh = require("deployer_helper")

local gui_prefix = "cargo-drone-"

local window_gui_name = gui_prefix .. "window-deployer-main"

local not_observed = {}

local function get_drone_limit_signal_element(player_data, element)
    local signal_id = dlh.get_drone_limit_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end
local function get_drone_count_signal_element(player_data, element)
    local signal_id = dlh.get_drone_count_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end

local observers = {
    is_drone_limit_circuit = {
        get = function(player_data) return dlh.is_drone_limit_circuit(player_data.entity) end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_slider.enabled = not data
            player_data.elements.drone_limit_field.enabled = not data
            player_data.elements.drone_limit_circuit_checkbox.state = data
            player_data.elements.drone_limit_signal_label.enabled = data
            player_data.elements.drone_limit_signal_choose_elem_button.enabled = data
        end
    },
    get_drone_limit = {
        get = function(player_data) return dlh.get_drone_limit(player_data.entity) end,
        updated = function(player_data, data)
            if data == nil then
                data = 0
            end

            player_data.elements.drone_limit_slider.slider_value = data
            if player_data.elements.drone_limit_field.text ~= tostring(data) then
                player_data.elements.drone_limit_field.text = tostring(data)
            end
        end
    },

    get_circuit_network_red_green = {
        get = function(player_data)
            return player_data.entity.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil
                or player_data.entity.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil
        end,
        updated = function(player_data, data)
            if data then
                player_data.elements.connection_label.caption = { "gui-control-behavior.connected-to-network" }
            else
                player_data.elements.connection_label.caption = { "gui-control-behavior.not-connected" }
            end
        end
    },
    get_circuit_network_red = {
        get = function(player_data)
            local network = player_data.entity.get_circuit_network(defines.wire_connector_id.circuit_red)

            if network == nil then
                return nil
            end

            return network.network_id
        end,
        updated = function(player_data, data)
            player_data.elements.network_red_label.visible = data ~= nil
            if data ~= nil then
                player_data.elements.network_red_label.caption = "[color=1.0,0.1,0.1]" .. data .. "[/color]"
            end
        end
    },
    get_circuit_network_green = {
        get = function(player_data)
            local network = player_data.entity.get_circuit_network(defines.wire_connector_id.circuit_green)

            if network == nil then
                return nil
            end

            return network.network_id
        end,
        updated = function(player_data, data)
            player_data.elements.network_green_label.visible = data ~= nil
            if data ~= nil then
                player_data.elements.network_green_label.caption = "[color=0.1,1.0,0.1]" .. data .. "[/color]"
            end
        end
    },

    ---------- Circuit ----------
    get_drone_limit_signal_element_type = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "type") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = dlh.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_limit_signal_element_name = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = dlh.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_limit_signal_element_quality = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = dlh.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },

    is_drone_count_circuit = {
        get = function(player_data) return dlh.is_drone_count_circuit(player_data.entity) end,
        updated = function(player_data, data)
            player_data.elements.drone_count_circuit_checkbox.state = data
            player_data.elements.drone_count_signal_label.enabled = data
            player_data.elements.drone_count_signal_choose_elem_button.enabled = data
        end
    },
    get_drone_count_signal_element_type = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "type") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = dlh.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_count_signal_element_name = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = dlh.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_count_signal_element_quality = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = dlh.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
}

local function update_gui(player_data)
    for key, observer in pairs(observers) do
        local data = observer.get(player_data)

        if data ~= player_data.observer_data[key] then
            observer.updated(player_data, data)

            player_data.observer_data[key] = data
        end
    end
end

local callbacks = {
    ---------- Deployers ----------
    [gui_prefix .. "deployer-close-button"] = function(player_data, event)
        if not player_data.player.gui.screen[window_gui_name] then
            return
        end

        player_data.player.opened = nil
    end,

    [gui_prefix .. "drone-limit-slider"] = function(player_data, event)
        dlh.set_drone_limit_value(player_data.entity, player_data.elements.drone_limit_slider.slider_value)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-textfield"] = function(player_data, event)
        local limit = tonumber(player_data.elements.drone_limit_field.text)

        if limit == nil then
            return
        end

        dlh.set_drone_limit_value(player_data.entity, limit)

        update_gui(player_data)
    end,

    ---------- Circuit ----------
    [gui_prefix .. "set-drone-limit-checkbox"] = function(player_data, event)
        dlh.set_drone_limit_circuit(player_data.entity, player_data.elements.drone_limit_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-signal-choose-elem-button"] = function(player_data, event)
        dlh.set_drone_limit_circuit_signal_id(player_data.entity, player_data.elements.drone_limit_signal_choose_elem_button.elem_value)
    end,

    [gui_prefix .. "read-drone-count-checkbox"] = function(player_data, event)
        dlh.set_drone_count_circuit(player_data.entity, player_data.elements.drone_count_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-count-signal-choose-elem-button"] = function(player_data, event)
        dlh.set_drone_count_circuit_signal_id(player_data.entity, player_data.elements.drone_count_signal_choose_elem_button.elem_value)
    end,
}

local function handle_event(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    local player = game.get_player(event.player_index)

    if not storage.gui_deployer_player[player.index] then
        return
    end

    local callable = callbacks[element.name]

    if not callable then
        return
    end

    callable(storage.gui_deployer_player[player.index], event)
end

local function build_gui_deployer(player_data, deployer, parent)
    local deployer_frame = parent.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    local deployer_flow = deployer_frame.add{
        type = "flow",
        direction = "vertical"
    }

    deployer_flow.style.width = 412
    deployer_flow.style.padding = 16

    ---------- Entity preview ----------
    local preview_frame = deployer_flow.add{
        type = "frame",
        direction = "horizontal",
        style = "inside_deep_frame"
    }

    preview_frame.style.bottom_margin = 16

    local preview = preview_frame.add{
        type = "entity-preview",
        style = "wide_entity_button"
    }

    preview.entity = deployer
    preview.style.width = 380
    preview.style.height = 150

    player_data.elements.preview = preview

    ---------- Drone limit ----------
    local drone_limit_flow = deployer_flow.add{
        type = "flow",
        direction = "horizontal",
    }

    drone_limit_flow.style.vertical_align = "center"
    drone_limit_flow.style.horizontal_spacing = 8
    drone_limit_flow.style.bottom_margin = 8

    drone_limit_flow.add{
        type = "label",
        caption = { "cargo-drone-gui-deployer.drone-limit" },
        tooltip = { "cargo-drone-gui-deployer.drone-limit-tooltip" },
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

    player_data.elements.drone_limit_slider = drone_limit_slider
    player_data.elements.drone_limit_field = drone_limit_field

    ---------- Filler ----------
    local deployer_filler = deployer_flow.add{
        type = "empty-widget",
        style = "entity_frame_filler"
    }

    deployer_filler.style.top_margin = 8
    deployer_filler.style.bottom_margin = 8
    deployer_filler.style.left_margin = 8
    deployer_filler.style.vertically_stretchable = true
end

local function build_gui_circuit_connection_status(player_data, parent)
    local frame = parent.add{
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
    }

    frame.style.horizontally_stretchable = true
    frame.style.vertical_align = "center"
    frame.style.padding = 12
    frame.style.bottom_margin = 8

    local connection_label = frame.add{ type = "label" }
    local network_red_label = frame.add{ type = "label" }
    local network_green_label = frame.add{ type = "label" }

    player_data.elements.connection_label = connection_label
    player_data.elements.network_red_label = network_red_label
    player_data.elements.network_green_label = network_green_label
end
local function build_gui_circuit(player_data, deployer, parent)
    local frame = parent.add{
        type = "frame",
        direction = "vertical",
    }

    local main_frame = frame.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    main_frame.style.bottom_padding = 4

    build_gui_circuit_connection_status(player_data, main_frame)

    ---------- Drone Limit ----------

    local drone_limit_circuit_checkbox = main_frame.add{
        type = "checkbox",
        name = gui_prefix .. "set-drone-limit-checkbox",
        caption = { "cargo-drone-gui-control-behavior-modes.set-drone-limit" },
        tooltip = { "cargo-drone-gui-control-behavior-modes.set-drone-limit-description" },
        style = "subheader_caption_checkbox",
        state = dlh.is_drone_limit_circuit(deployer)
    }

    drone_limit_circuit_checkbox.style.top_margin = 4
    drone_limit_circuit_checkbox.style.bottom_margin = 4
    drone_limit_circuit_checkbox.style.left_margin = 12
    drone_limit_circuit_checkbox.style.right_margin = 12

    local drone_limit_signal_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }

    drone_limit_signal_flow.style.vertical_align = "center"
    drone_limit_signal_flow.style.top_margin = 4
    drone_limit_signal_flow.style.bottom_margin = 4
    drone_limit_signal_flow.style.left_margin = 12
    drone_limit_signal_flow.style.right_margin = 12

    local drone_limit_signal_label = drone_limit_signal_flow.add{
        type = "label",
        caption = { "cargo-drone-gui-control-behavior-modes.drone-limit" }
    }

    local drone_limit_signal_filler = drone_limit_signal_flow.add{
        type = "empty-widget",
    }

    drone_limit_signal_filler.style.horizontally_stretchable = true

    local drone_limit_signal_choose_elem_button = drone_limit_signal_flow.add{
        type = "choose-elem-button",
        name = gui_prefix .. "drone-limit-signal-choose-elem-button",
        elem_type = "signal"
    }

    player_data.elements.drone_limit_circuit_checkbox = drone_limit_circuit_checkbox
    player_data.elements.drone_limit_signal_label = drone_limit_signal_label
    player_data.elements.drone_limit_signal_choose_elem_button = drone_limit_signal_choose_elem_button

    ---------- Drone Count ----------

    main_frame.add{
        type = "line",
    }

    local drone_count_circuit_checkbox = main_frame.add{
        type = "checkbox",
        name = gui_prefix .. "read-drone-count-checkbox",
        caption = { "cargo-drone-gui-control-behavior-modes.read-drone-count" },
        tooltip = { "cargo-drone-gui-control-behavior-modes.read-drone-count-description" },
        style = "subheader_caption_checkbox",
        state = dlh.is_drone_count_circuit(deployer)
    }

    drone_count_circuit_checkbox.style.top_margin = 4
    drone_count_circuit_checkbox.style.bottom_margin = 4
    drone_count_circuit_checkbox.style.left_margin = 12
    drone_count_circuit_checkbox.style.right_margin = 12

    local drone_count_signal_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }

    drone_count_signal_flow.style.vertical_align = "center"
    drone_count_signal_flow.style.top_margin = 4
    drone_count_signal_flow.style.bottom_margin = 4
    drone_count_signal_flow.style.left_margin = 12
    drone_count_signal_flow.style.right_margin = 12

    local drone_count_signal_label = drone_count_signal_flow.add{
        type = "label",
        caption = { "cargo-drone-gui-control-behavior-modes.drone-count" }
    }

    local drone_count_signal_filler = drone_count_signal_flow.add{
        type = "empty-widget",
    }

    drone_count_signal_filler.style.horizontally_stretchable = true

    local drone_count_signal_choose_elem_button = drone_count_signal_flow.add{
        type = "choose-elem-button",
        name = gui_prefix .. "drone-count-signal-choose-elem-button",
        elem_type = "signal"
    }

    player_data.elements.drone_count_circuit_checkbox = drone_count_circuit_checkbox
    player_data.elements.drone_count_signal_label = drone_count_signal_label
    player_data.elements.drone_count_signal_choose_elem_button = drone_count_signal_choose_elem_button
end

local function build_gui(player, deployer)
    local player_data = {
        player = player,
        entity = deployer,
        entity_unit_number = deployer.unit_number,
        surface_index = deployer.surface.index,
        position = deployer.position,
        elements = {},
        observer_data = {}
    }

    for key, _ in pairs(observers) do
        player_data.observer_data[key] = not_observed
    end

    storage.gui_deployer_player[player.index] = player_data

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
        caption = { "entity-name.cargo-drone-deployer-constant-combinator" },
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

    local button_close = titlebar.add{
        type = "sprite-button",
        name = gui_prefix .. "deployer-close-button",
        sprite = "utility/close",
        hovered_sprite = "utility/close",
        clicked_sprite = "utility/close",
        style = "frame_action_button",
        tooltip = { "gui.close-instruction" },
    }

    button_close.style.left_margin = 4

    local main_flow = frame.add{
        type = "flow",
        direction = "horizontal",
    }

    main_flow.style.horizontal_spacing = 8

    build_gui_deployer(player_data, deployer, main_flow)

    build_gui_circuit(player_data, deployer, main_flow)

    player.opened = frame

    update_gui(player_data)
end

local function add_to_lookup(player_index, entity_unit_number)
    if not storage.gui_deployer_entity_lookup[entity_unit_number] then
        storage.gui_deployer_entity_lookup[entity_unit_number] = {}
    end

    storage.gui_deployer_entity_lookup[entity_unit_number][player_index] = true
end
local function remove_from_lookup(player_index, entity_unit_number)
    local players = storage.gui_deployer_entity_lookup[entity_unit_number]

    if not players then
        error("Tried to remove non-existing entity lookup")
    end

    players[player_index] = nil

    if next(players) == nil then
        storage.gui_deployer_entity_lookup[entity_unit_number] = nil
    end
end

local gui_deployer = {}

function gui_deployer.create_player_storage()
    storage.gui_deployer_player = storage.gui_deployer_player or {}
    storage.gui_deployer_entity_lookup = storage.gui_deployer_entity_lookup or {}
end

function gui_deployer.tick()
    local removed = nil

    for player_index, player_data in pairs(storage.gui_deployer_player) do
        if not player_data.player.connected then
            goto continue
        end

        if not player_data.entity or not player_data.entity.valid then
            local surface = game.get_surface(player_data.surface_index)

            if not surface then
                if removed == nil then
                    removed = {}
                end

                table.insert(removed, player_index)

                goto continue
            end

            local entity = surface.find_entity("cargo-drone-deployer-constant-combinator", player_data.position)

            if not entity then
                if removed == nil then
                    removed = {}
                end

                table.insert(removed, player_index)

                goto continue
            end

            remove_from_lookup(player_index, player_data.entity_unit_number)

            player_data.entity = entity
            player_data.entity_unit_number = entity.unit_number
            player_data.elements.preview.entity = entity

            add_to_lookup(player_index, entity.unit_number)
        end

        update_gui(player_data)

        ::continue::
    end

    if removed ~= nil then
        for _, player_index in ipairs(removed) do
            local player_data = storage.gui_deployer_player[player_index]

            if player_data.player.valid then
               local window = player_data.player.gui.screen[window_gui_name]

                if window then
                    window.destroy()
                end
            end

            remove_from_lookup(player_index, player_data.entity_unit_number)

            storage.gui_deployer_player[player_index] = nil
        end
    end
end

function gui_deployer.on_player_removed(event)
    local player_data = storage.gui_deployer_player[event.player_index]

    if not player_data then
        return
    end

    remove_from_lookup(event.player_index, player_data.entity_unit_number)

    storage.gui_deployer_player[event.player_index] = nil
end

function gui_deployer.on_gui_opened(event)
	local entity = event.entity

	if not entity or not entity.valid then
		return
	end

    local entity_name = entity.name

    if entity_name == "entity-ghost" then
        entity_name = entity.ghost_name
    end

	if entity_name ~= "cargo-drone-deployer-constant-combinator" then
        return
	end

    local player = game.get_player(event.player_index)

    if player.gui.screen[window_gui_name] then
        return
    end

    player.opened = nil

    add_to_lookup(player.index, entity.unit_number)

    build_gui(player, entity)
end
function gui_deployer.on_gui_closed(event)
	if event.gui_type ~= defines.gui_type.custom then
		return
	end

	local player = game.get_player(event.player_index)

    if not event.element.valid or event.element.name ~= window_gui_name then
        return
    end

    player.gui.screen[window_gui_name].destroy()

    if not storage.gui_deployer_player[event.player_index] then
        return
    end

    local entity_unit_number = storage.gui_deployer_player[event.player_index].entity_unit_number

    remove_from_lookup(event.player_index, entity_unit_number)

    storage.gui_deployer_player[event.player_index] = nil

    player.opened = nil
end
function gui_deployer.on_gui_click(event)
    handle_event(event)
end
function gui_deployer.on_gui_checked_state_changed(event)
    handle_event(event)
end
function gui_deployer.on_gui_value_changed(event)
    handle_event(event)
end
function gui_deployer.on_gui_text_changed(event)
    handle_event(event)
end
function gui_deployer.on_gui_elem_changed(event)
    handle_event(event)
end
function gui_deployer.on_gui_selection_state_changed(event)
    handle_event(event)
end
function gui_deployer.on_gui_confirmed(event)
    handle_event(event)
end

function gui_deployer.on_destroyed_entity(event)
    local players = storage.gui_deployer_entity_lookup[event.entity_unit_number]

    if not players then
        return
    end

    for player_index, _ in pairs(players) do
        local player = game.get_player(player_index)

        if not player then
            break
        end

        player.opened = nil
    end
end

return gui_deployer
