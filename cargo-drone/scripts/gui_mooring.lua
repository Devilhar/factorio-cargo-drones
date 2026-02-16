
-- If you're here looking for a good way to handle GUI. Go elsewhere. There's nothing for you here

local ep = require("scripts.entity_property")
local dt = require("scripts.drone_tasks")
local mh = require("scripts.mooring_helper")

local gui_prefix = "cargo-drone-"

local mooring_drone_prefix = gui_prefix .. "mooring-drone-"
local minimap_name = gui_prefix .. "drone-minimap"

local window_gui_name = gui_prefix .. "window-mooring-main"

local not_observed = {}

local gui_local_data = {}

local function register_on_click(player, element, callback)
    gui_local_data[player.index].on_click[element.name] = callback
end
local function register_on_changed(player, element, callback)
    gui_local_data[player.index].on_changed[element.name] = callback
end
local function register_data_observer(player, get_data, callable)
    table.insert(gui_local_data[player.index].data_observers, {
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

    if not gui_local_data[player.index] then
        return
    end

    local callable = gui_local_data[player.index][action_type][element.name]

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

    mooring_frame.style.width = 432
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
        caption = { "cargo-drone-gui-mooring.enable-drone-limit" },
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
            if mh.is_drone_limit_circuit(mooring) then
                drone_limit_checkbox.state = true
                drone_limit_checkbox.enabled = false
                drone_limit_slider.enabled = false
                drone_limit_field.enabled = false
            else
                drone_limit_checkbox.state = data
                drone_limit_checkbox.enabled = true
                drone_limit_slider.enabled = data
                drone_limit_field.enabled = data
            end
        end)
    register_data_observer(player,
        function() return mh.is_drone_limit_circuit(mooring) end,
        function(data)
            if data then
                drone_limit_checkbox.state = true
                drone_limit_checkbox.enabled = false
                drone_limit_slider.enabled = false
                drone_limit_field.enabled = false
            else
                local drone_limit_enabled = mh.is_drone_limit_enabled(mooring)

                drone_limit_checkbox.state = drone_limit_enabled
                drone_limit_checkbox.enabled = true
                drone_limit_slider.enabled = drone_limit_enabled
                drone_limit_field.enabled = drone_limit_enabled
            end
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
        caption = { "cargo-drone-gui-mooring.priority" },
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

    ---------- Item Signals ----------

    if mooring.name ~= "cargo-drone-mooring-constant-combinator-refueler" then
        local label_caption = "cargo-drone-gui-mooring.provided-items"

        if mooring.name == "cargo-drone-mooring-constant-combinator-requester" then
            label_caption = "cargo-drone-gui-mooring.requested-items"
        end

        local items_header = mooring_frame.add{
            type = "label",
            style = "subheader_label",
            caption = { label_caption }
        }

        items_header.style.margin = 4

        local items_frame = mooring_frame.add{
            type = "frame",
            style = "inside_deep_frame",
            direction = "horizontal"
        }

        items_frame.style.margin = 4
        items_frame.style.horizontally_stretchable = true

        local items_table = items_frame.add{
            type = "table",
            column_count = 11
        }
        local item_indices = {}

        items_table.style.minimal_height = 40
        items_table.style.padding = 4

        local function update_item_element(index, item)
            local item_sprite = item_indices[index]

            if not item_sprite then
                item_sprite = items_table.add{
                    type = "sprite-button",
                    style = "transparent_slot"
                }

                item_indices[index] = item_sprite
            end

            item_sprite.sprite = "item/" .. item.signal.name
            item_sprite.quality = item.signal.quality
            item_sprite.number = item.count
            item_sprite.tooltip = prototypes.item[item.signal.name].localised_name
            item_sprite.visible = true
        end

        local function update_item_signals()
            local mooring_signals = mooring.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

            local current_index = 1

            if mooring_signals then
                for i, item in ipairs(mooring_signals) do
                    if item.signal.type ~= nil then
                        goto continue
                    end
                    if item.count <= 0 then
                        goto continue
                    end

                    update_item_element(i, item)

                    current_index = current_index + 1

                    ::continue::
                end
            end

            for i = current_index, #item_indices do
                item_indices[i].visible = false
            end
        end

        update_item_signals()

        gui_local_data[player.index].item_signal_update = update_item_signals
    end

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

    drones_frame.style.width = 310

    local subheader_frame = drones_frame.add{
        type = "frame",
        style = "subheader_frame"
    }

    subheader_frame.style.horizontally_stretchable = true
    subheader_frame.style.vertical_align = "center"

    subheader_frame.add{
        type = "label",
        caption = { "cargo-drone-gui-mooring.tasked-cargo-drone" },
        style = "subheader_label"
    }

    local drones_scroll = drones_frame.add{
        type = "scroll-pane",
        style = "scroll_pane_in_shallow_frame",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "always"
    }

    drones_scroll.style.margin = 4
    drones_scroll.style.height = 416

    local drone_table = drones_scroll.add{
        type = "table",
        column_count = 1,
    }

    drone_table.style.horizontally_stretchable = true
    drone_table.style.margin = 0

    local function update_elements(drone, minimap, task_label)
        local task = dt.get(dt.get_current_drone_task_id(drone))
        local loc_id = nil
        local target_mooring = nil

        if task.type == dt.task_types.cargo then
            if task.provider_unit_number then
                loc_id = "cargo-drone-status.heading-to-provider"
                target_mooring = ep.get_managed_entity(task.provider_unit_number)
            else
                loc_id = "cargo-drone-status.heading-to-requester"
                target_mooring = ep.get_managed_entity(task.requester_unit_number)
            end
        else
            loc_id = "cargo-drone-status.heading-to-refueler"
            target_mooring = ep.get_managed_entity(task.refueler_unit_number)
        end

        minimap.entity = drone
        task_label.caption = { loc_id, math.floor(util.distance(drone.position, target_mooring.position)) }
    end

    local function create_drone_element(index, drone, task)
        local minimap_border = drone_table.add{
            type = "frame",
            name = mooring_drone_prefix .. index,
            style = "shallow_frame",
            direction = "vertical",
        }

        local minimap_frame = minimap_border.add{
            type = "frame",
            name = gui_prefix .. "minimap-frame",
            style = "inside_deep_frame",
            direction = "vertical"
        }

        minimap_frame.style.margin = 4

        local minimap_flow = minimap_frame.add{
            type = "flow",
            name = gui_prefix .. "minimap-flow",
            direction = "horizontal",
        }

        local minimap = minimap_flow.add{
            type = "minimap",
            name = minimap_name
        }

        minimap.entity = drone
        minimap.style.horizontally_stretchable = true
        minimap.style.height = 120

        local task_frame = minimap_border.add{
            type = "frame",
            name = gui_prefix .. "task-frame",
            style = "inside_deep_frame",
            direction = "vertical"
        }

        task_frame.style.margin = 4

        local task_header_frame = task_frame.add{
            type = "frame",
            name = gui_prefix .. "task-header-frame",
            style = "subheader_frame"
        }

        task_header_frame.style.horizontally_stretchable = true
        task_header_frame.style.vertical_align = "center"

        local task_label = task_header_frame.add{
            type = "label",
            name = gui_prefix .. "task-label",
            style = "subheader_label"
        }

        update_elements(drone, minimap, task_label)

        if not task.items then
            return
        end

        local items_frame = minimap_border.add{
            type = "frame",
            style = "inside_deep_frame",
            direction = "horizontal"
        }

        items_frame.style.margin = 4
        items_frame.style.horizontally_stretchable = true

        local items_table = items_frame.add{
            type = "table",
            column_count = 7
        }

        items_table.style.padding = 4

        for _, item in ipairs(task.items) do
            local item_sprite = items_table.add{
                type = "sprite-button",
                style = "transparent_slot",
                sprite = "item/" .. item.name,
                quality = item.quality,
                number = item.count,
                tooltip = prototypes.item[item.name].localised_name
            }
        end
    end

    gui_local_data[player.index].drone_update = function()
        local task_ids = dt.get_entity_task_ids(mooring)

        local index = 1

        if task_ids then
            for task_id, _ in pairs(task_ids) do
                local task = dt.get(task_id)
                
                local element = drone_table[mooring_drone_prefix .. index]
                local drone = ep.get_managed_entity(task.drone_unit_number)

                if element then
                    local minimap = element[gui_prefix .. "minimap-frame"][gui_prefix .. "minimap-flow"][minimap_name]
                    local task_label = element[gui_prefix .. "task-frame"][gui_prefix .. "task-header-frame"][gui_prefix .. "task-label"]

                    update_elements(drone, minimap, task_label)
                else
                    create_drone_element(index, drone, task)
                end

                index = index + 1
            end
        end

        while true do
            local element = drone_table[mooring_drone_prefix .. index]

            if not element then
                break
            end

            index = index + 1
            element.destroy()
        end
    end
end

local function build_gui_circuit_connection_status(player, mooring, parent)
    local frame = parent.add{
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
    }

    frame.style.horizontally_stretchable = true
    frame.style.vertical_align = "center"
    frame.style.padding = 12
    frame.style.bottom_margin = 8

    local label_loc_not_connected = { "gui-control-behavior.not-connected" }
    local label_loc_connected_to_network = { "gui-control-behavior.connected-to-network" }

    local connection_label = frame.add{ type = "label" }

    register_data_observer(player,
        function()
            return mooring.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil
                or mooring.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil
        end,
        function(data)
            if data then
                connection_label.caption = label_loc_connected_to_network
            else
                connection_label.caption = label_loc_not_connected
            end
        end)

    local network_red_label = frame.add{ type = "label" }
    local network_green_label = frame.add{ type = "label" }

    register_data_observer(player,
        function()
            local network = mooring.get_circuit_network(defines.wire_connector_id.circuit_red)

            if network == nil then
                return nil
            end

            return network.network_id
        end,
        function(data)
            network_red_label.visible = data ~= nil
            if data ~= nil then
                network_red_label.caption = "[color=1.0,0.1,0.1]" .. data .. "[/color]"
            end
        end)
    register_data_observer(player,
        function()
            local network = mooring.get_circuit_network(defines.wire_connector_id.circuit_green)

            if network == nil then
                return nil
            end

            return network.network_id
        end,
        function(data)
            network_green_label.visible = data ~= nil
            if data ~= nil then
                network_green_label.caption = "[color=0.1,1.0,0.1]" .. data .. "[/color]"
            end
        end)

end
local function build_gui_circuit(player, mooring, parent)
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

    build_gui_circuit_connection_status(player, mooring, main_frame)

    ---------- Drone Limit ----------

    local drone_limit_circuit_checkbox = main_frame.add{
        type = "checkbox",
        name = gui_prefix .. "set-drone-limit-checkbox",
        caption = { "cargo-drone-gui-control-behavior-modes.set-drone-limit" },
        tooltip = { "cargo-drone-gui-control-behavior-modes.set-drone-limit-description" },
        style = "subheader_caption_checkbox",
        state = mh.is_drone_limit_circuit(mooring)
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

    register_on_changed(player, drone_limit_circuit_checkbox, function()
        mh.set_drone_limit_circuit(mooring, drone_limit_circuit_checkbox.state)
    end)
    register_data_observer(player,
        function() return mh.is_drone_limit_circuit(mooring) end,
        function(data)
            drone_limit_circuit_checkbox.state = data
            drone_limit_signal_label.enabled = data
            drone_limit_signal_choose_elem_button.enabled = data
        end)

    local function drone_limit_signal_changed(_)
        drone_limit_signal_choose_elem_button.elem_value = mh.get_drone_limit_circuit_signal_id(mooring)
    end
    local function get_drone_limit_signal_element(element)
        local signal_id = mh.get_drone_limit_circuit_signal_id(mooring)

        if signal_id == nil then
            return nil
        end

        return signal_id[element]
    end

    register_on_changed(player, drone_limit_signal_choose_elem_button, function()
        mh.set_drone_limit_circuit_signal_id(mooring, drone_limit_signal_choose_elem_button.elem_value)
    end)
    register_data_observer(player,
        function() return get_drone_limit_signal_element("type") end,
        drone_limit_signal_changed)
    register_data_observer(player,
        function() return get_drone_limit_signal_element("name") end,
        drone_limit_signal_changed)
    register_data_observer(player,
        function() return get_drone_limit_signal_element("quality") end,
        drone_limit_signal_changed)

    main_frame.add{
        type = "line",
    }

    ---------- Drone Count ----------

    local drone_count_circuit_checkbox = main_frame.add{
        type = "checkbox",
        name = gui_prefix .. "read-drone-count-checkbox",
        caption = { "cargo-drone-gui-control-behavior-modes.read-drone-count" },
        tooltip = { "cargo-drone-gui-control-behavior-modes.read-drone-count-description" },
        style = "subheader_caption_checkbox",
        state = mh.is_drone_count_circuit(mooring)
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

    register_on_changed(player, drone_count_circuit_checkbox, function()
        mh.set_drone_count_circuit(mooring, drone_count_circuit_checkbox.state)
    end)
    register_data_observer(player,
        function() return mh.is_drone_count_circuit(mooring) end,
        function(data)
            drone_count_circuit_checkbox.state = data
            drone_count_signal_label.enabled = data
            drone_count_signal_choose_elem_button.enabled = data
        end)

    local function drone_count_signal_changed(_)
        drone_count_signal_choose_elem_button.elem_value = mh.get_drone_count_circuit_signal_id(mooring)
    end
    local function get_drone_count_signal_element(element)
        local signal_id = mh.get_drone_count_circuit_signal_id(mooring)

        if signal_id == nil then
            return nil
        end

        return signal_id[element]
    end

    register_on_changed(player, drone_count_signal_choose_elem_button, function()
        mh.set_drone_count_circuit_signal_id(mooring, drone_count_signal_choose_elem_button.elem_value)
    end)
    register_data_observer(player,
        function() return get_drone_count_signal_element("type") end,
        drone_count_signal_changed)
    register_data_observer(player,
        function() return get_drone_count_signal_element("name") end,
        drone_count_signal_changed)
    register_data_observer(player,
        function() return get_drone_count_signal_element("quality") end,
        drone_count_signal_changed)

    main_frame.add{
        type = "line",
    }

    ---------- Priority ----------

    local priority_circuit_checkbox = main_frame.add{
        type = "checkbox",
        name = gui_prefix .. "set-priority-checkbox",
        caption = { "cargo-drone-gui-control-behavior-modes.set-priority" },
        tooltip = { "cargo-drone-gui-control-behavior-modes.set-priority-description" },
        style = "subheader_caption_checkbox",
        state = mh.is_priority_circuit(mooring)
    }

    priority_circuit_checkbox.style.top_margin = 4
    priority_circuit_checkbox.style.bottom_margin = 4
    priority_circuit_checkbox.style.left_margin = 12
    priority_circuit_checkbox.style.right_margin = 12

    local priority_signal_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }

    priority_signal_flow.style.vertical_align = "center"
    priority_signal_flow.style.top_margin = 4
    priority_signal_flow.style.bottom_margin = 4
    priority_signal_flow.style.left_margin = 12
    priority_signal_flow.style.right_margin = 12

    local priority_signal_label = priority_signal_flow.add{
        type = "label",
        caption = { "cargo-drone-gui-control-behavior-modes.priority" }
    }

    local priority_signal_filler = priority_signal_flow.add{
        type = "empty-widget",
    }

    priority_signal_filler.style.horizontally_stretchable = true

    local priority_signal_choose_elem_button = priority_signal_flow.add{
        type = "choose-elem-button",
        name = gui_prefix .. "priority-signal-choose-elem-button",
        elem_type = "signal"
    }

    register_on_changed(player, priority_circuit_checkbox, function()
        mh.set_priority_circuit(mooring, priority_circuit_checkbox.state)
    end)
    register_data_observer(player,
        function() return mh.is_priority_circuit(mooring) end,
        function(data)
            priority_circuit_checkbox.state = data
            priority_signal_label.enabled = data
            priority_signal_choose_elem_button.enabled = data
        end)

    local function priority_signal_changed(_)
        priority_signal_choose_elem_button.elem_value = mh.get_priority_circuit_signal_id(mooring)
    end
    local function get_priority_signal_element(element)
        local signal_id = mh.get_priority_circuit_signal_id(mooring)

        if signal_id == nil then
            return nil
        end

        return signal_id[element]
    end

    register_on_changed(player, priority_signal_choose_elem_button, function()
        mh.set_priority_circuit_signal_id(mooring, priority_signal_choose_elem_button.elem_value)
    end)
    register_data_observer(player,
        function() return get_priority_signal_element("type") end,
        priority_signal_changed)
    register_data_observer(player,
        function() return get_priority_signal_element("name") end,
        priority_signal_changed)
    register_data_observer(player,
        function() return get_priority_signal_element("quality") end,
        priority_signal_changed)
end

local function build_gui(player, mooring)
    gui_local_data[player.index] = {
        on_click = {},
        on_changed = {},
        data_observers = {}
    }

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

    local localised_name = mooring.localised_name

    if mooring.name == "entity-ghost" then
        localised_name = mooring.ghost_localised_name
    end

    local title = titlebar.add{
        type = "label",
        caption = localised_name,
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
        name = gui_prefix .. "mooring-close-button",
        sprite = "utility/close",
        hovered_sprite = "utility/close",
        clicked_sprite = "utility/close",
        style = "frame_action_button",
        tooltip = { "gui.close-instruction" },
    }

    button_close.style.left_margin = 4

    register_on_click(player, button_close, function()
        if not player.gui.screen[window_gui_name] then
            return
        end

        player.opened = nil
    end)

    local main_flow = frame.add{
        type = "flow",
        direction = "horizontal",
    }

    main_flow.style.horizontal_spacing = 8

    build_gui_mooring(player, mooring, main_flow)

    build_gui_drones(player, mooring, main_flow)

    build_gui_circuit(player, mooring, main_flow)

    player.opened = frame
end

local function add_to_lookup(player_index, entity_unit_number)
    if not storage.gui_mooring_entity_lookup[entity_unit_number] then
        storage.gui_mooring_entity_lookup[entity_unit_number] = {}
    end

    storage.gui_mooring_entity_lookup[entity_unit_number][player_index] = true
end
local function remove_from_lookup(player_index, entity_unit_number)
    local players = storage.gui_mooring_entity_lookup[entity_unit_number]

    if not players then
        error("Tried to remove non-existing entity lookup")
    end

    players[player_index] = nil

    if next(players) == nil then
        storage.gui_mooring_entity_lookup[entity_unit_number] = nil
    end
end

local gui_mooring = {}

function gui_mooring.create_player_storage()
    storage.gui_mooring_player = storage.gui_mooring_player or {}
    storage.gui_mooring_entity_lookup = storage.gui_mooring_entity_lookup or {}
end

function gui_mooring.tick()
    local removed = nil

    for player_index, player_data in pairs(storage.gui_mooring_player) do
        local local_data = gui_local_data[player_index]

        if not player_data.player.connected then
            goto continue
        end

        if not local_data or not player_data.entity or not player_data.entity.valid then
            local surface = game.get_surface(player_data.surface_index)

            if not surface then
                if removed == nil then
                    removed = {}
                end

                table.insert(removed, player_index)

                goto continue
            end

            local entity = surface.find_entity(player_data.entity_name, player_data.position)

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

            add_to_lookup(player_index, entity.unit_number)

            player_data.player.gui.screen[window_gui_name].destroy()

            player_data.player.opened = nil

            build_gui(player_data.player, entity)

            local_data = gui_local_data[player_index]
        end

        for _, observer in ipairs(local_data.data_observers) do
            local data = observer.get_data()

            if data ~= observer.previous_data then
                observer.callable(data)

                observer.previous_data = data
            end
        end
        if local_data.item_signal_update then
            local_data.item_signal_update()
        end
        local_data.drone_update()

        ::continue::
    end

    if removed ~= nil then
        for _, player_index in ipairs(removed) do
            local window = storage.gui_mooring_player[player_index].player.gui.screen[window_gui_name]

            if window then
                window.destroy()
            end

            local player_data = storage.gui_mooring_player[player_index]

            remove_from_lookup(player_index, player_data.entity_unit_number)
            
            storage.gui_mooring_player[player_index] = nil
            gui_local_data[player_index] = nil
        end
    end
end

function gui_mooring.on_player_removed(event)
    local player_data = storage.gui_mooring_player[event.player_index]

    if not player_data then
        return
    end

    remove_from_lookup(event.player_index, player_data.entity_unit_number)

    storage.gui_mooring_player[event.player_index] = nil
    gui_local_data[event.player_index] = nil
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

    storage.gui_mooring_player[player.index] = {
        player = player,
        entity = entity,
        entity_unit_number = entity.unit_number,
        entity_name = entity_name,
        surface_index = entity.surface.index,
        position = entity.position
    }

    add_to_lookup(player.index, entity.unit_number)

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

    if not storage.gui_mooring_player[event.player_index] then
        return
    end

    player.gui.screen[window_gui_name].destroy()

    local entity_unit_number = storage.gui_mooring_player[event.player_index].entity_unit_number

    remove_from_lookup(event.player_index, entity_unit_number)

    storage.gui_mooring_player[event.player_index] = nil
    gui_local_data[player.index] = nil

    player.opened = nil
end
function gui_mooring.on_gui_click(event)
    handle_event(event, "on_click")

    local player = game.get_player(event.player_index)

    if not gui_local_data[player.index] then
        return
    end

    local element = event.element

    if not element or not element.valid then
        return
    end

    if element.name ~= minimap_name then
        return
    end

    player.opened = element.entity
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
function gui_mooring.on_gui_elem_changed(event)
    handle_event(event, "on_changed")
end

function gui_mooring.on_destroyed_entity(event)
    local players = storage.gui_mooring_entity_lookup[event.entity_unit_number]

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

return gui_mooring
