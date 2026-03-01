
-- If you're here looking for a good way to handle GUI. Go elsewhere. There's nothing for you here. Naught but despair

local constants = require("scripts.constants")
local ep        = require("scripts.entity_property")
local dt        = require("scripts.drone_tasks")
local mh        = require("scripts.mooring_helper")
local dh        = require("scripts.drone_helper")

local gui_prefix = "cargo-drone-"

local mooring_drone_prefix = gui_prefix .. "mooring-drone-"
local minimap_name = gui_prefix .. "drone-minimap"

local window_gui_name = gui_prefix .. "window-mooring-main"

local not_observed = {}

local function get_drone_limit_signal_element(player_data, element)
    local signal_id = mh.get_drone_limit_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end
local function get_drone_count_signal_element(player_data, element)
    local signal_id = mh.get_drone_count_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end
local function get_priority_signal_element(player_data, element)
    local signal_id = mh.get_priority_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end

local function get_inventory_target_icon(inventory_target)
    if inventory_target == defines.inventory.fuel then
        return "item/rocket-fuel"
    elseif inventory_target == defines.inventory.car_trunk then
        return "item/steel-chest"
    elseif inventory_target == defines.inventory.burnt_result then
        return "item/heat-exchanger"
    end

    return "utility/questionmark"
end

local observers = {
    is_drone_limit_enabled = {
        get = function(player_data) return mh.is_drone_limit_enabled(player_data.entity) end,
        updated = function(player_data, data)
            if mh.is_drone_limit_circuit(player_data.entity) then
                player_data.elements.drone_limit_checkbox.state = true
                player_data.elements.drone_limit_checkbox.enabled = false
                player_data.elements.drone_limit_slider.enabled = false
                player_data.elements.drone_limit_field.enabled = false
            else
                player_data.elements.drone_limit_checkbox.state = data
                player_data.elements.drone_limit_checkbox.enabled = true
                player_data.elements.drone_limit_slider.enabled = data
                player_data.elements.drone_limit_field.enabled = data
            end
        end
    },
    is_drone_limit_circuit = {
        get = function(player_data) return mh.is_drone_limit_circuit(player_data.entity) end,
        updated = function(player_data, data)
            if data then
                player_data.elements.drone_limit_checkbox.state = true
                player_data.elements.drone_limit_checkbox.enabled = false
                player_data.elements.drone_limit_slider.enabled = false
                player_data.elements.drone_limit_field.enabled = false
            else
                local drone_limit_enabled = mh.is_drone_limit_enabled(player_data.entity)

                player_data.elements.drone_limit_checkbox.state = drone_limit_enabled
                player_data.elements.drone_limit_checkbox.enabled = true
                player_data.elements.drone_limit_slider.enabled = drone_limit_enabled
                player_data.elements.drone_limit_field.enabled = drone_limit_enabled
            end
            
            player_data.elements.drone_limit_circuit_checkbox.state = data
            player_data.elements.drone_limit_signal_label.enabled = data
            player_data.elements.drone_limit_signal_choose_elem_button.enabled = data
        end
    },
    get_drone_limit = {
        get = function(player_data) return mh.get_drone_limit(player_data.entity) end,
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

    is_priority_circuit = {
        get = function(player_data) return mh.is_priority_circuit(player_data.entity) end,
        updated = function(player_data, data)
            player_data.elements.priority_field.enabled = not data
            player_data.elements.priority_slider.enabled = not data

            player_data.elements.priority_circuit_checkbox.state = data
            player_data.elements.priority_signal_label.enabled = data
            player_data.elements.priority_signal_choose_elem_button.enabled = data
        end
    },
    get_priority = {
        get = function(player_data) return mh.get_priority(player_data.entity) end,
        updated = function(player_data, data)
            if player_data.elements.priority_field.text ~= tostring(data) then
                player_data.elements.priority_field.text = tostring(data)
            end
            player_data.elements.priority_slider.slider_value = data
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
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = mh.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_limit_signal_element_name = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = mh.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_limit_signal_element_quality = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = mh.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },

    is_drone_count_circuit = {
        get = function(player_data) return mh.is_drone_count_circuit(player_data.entity) end,
        updated = function(player_data, data)
            player_data.elements.drone_count_circuit_checkbox.state = data
            player_data.elements.drone_count_signal_label.enabled = data
            player_data.elements.drone_count_signal_choose_elem_button.enabled = data
        end
    },
    get_drone_count_signal_element_type = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "type") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = mh.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_count_signal_element_name = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = mh.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_count_signal_element_quality = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = mh.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },

    get_priority_signal_element_type = {
        get = function(player_data) return get_priority_signal_element(player_data, "type") end,
        updated = function(player_data, data)
            player_data.elements.priority_signal_choose_elem_button.elem_value = mh.get_priority_circuit_signal_id(player_data.entity)
        end
    },
    get_priority_signal_element_name = {
        get = function(player_data) return get_priority_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.priority_signal_choose_elem_button.elem_value = mh.get_priority_circuit_signal_id(player_data.entity)
        end
    },
    get_priority_signal_element_quality = {
        get = function(player_data) return get_priority_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.priority_signal_choose_elem_button.elem_value = mh.get_priority_circuit_signal_id(player_data.entity)
        end
    },
}

for x = 1, 3 do
    for y = 1, 3 do
        observers["get_inventory_target_button_" .. x .. "_" .. y] = {
            get = function(player_data) return mh.get_inventory_target(player_data.entity, x, y) end,
            updated = function(player_data, data)
                player_data.elements["inventory_target_button_" .. x .. "_" .. y].sprite = get_inventory_target_icon(mh.get_inventory_target(player_data.entity, x, y))
            end
        }
    end
end

local function update_item_signals(player_data)
    local mooring_signals = player_data.entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    local current_index = 1

    local function update_item_element(index, item)
        local item_sprite = player_data.elements.signal_item_indices[index]

        if not item_sprite then
            item_sprite = player_data.elements.items_table.add{
                type = "sprite-button",
                style = "transparent_slot"
            }

            player_data.elements.signal_item_indices[index] = item_sprite
        end

        item_sprite.sprite = "item/" .. item.signal.name
        item_sprite.quality = item.signal.quality
        item_sprite.number = item.count
        item_sprite.tooltip = prototypes.item[item.signal.name].localised_name
        item_sprite.visible = true
    end

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

    for i = current_index, #player_data.elements.signal_item_indices do
        player_data.elements.signal_item_indices[i].visible = false
    end
end

local function update_drone_list(player_data)
    local task_ids = dt.get_entity_task_ids(player_data.entity)

    local index = 1

    if task_ids then
        local function update_elements(drone, minimap, task_label)
            local task = dt.get(dt.get_current_drone_task_id(drone))
            local mooring_type = 0
            local target_mooring = nil

            if task.provider_unit_number ~= nil then
                mooring_type = 1
                target_mooring = ep.get_managed_entity(task.provider_unit_number)
            elseif task.requester_unit_number then
                mooring_type = 2
                target_mooring = ep.get_managed_entity(task.requester_unit_number)
            else
                mooring_type = 3
                target_mooring = ep.get_managed_entity(task.refueler_unit_number)
            end

            if dh.get_docked_mooring(drone) == target_mooring then
                if mooring_type == 1 then
                    task_label.caption = { "cargo-drone-status.docked-with-provider" }
                elseif mooring_type == 2 then
                    task_label.caption = { "cargo-drone-status.docked-with-requester" }
                else
                    task_label.caption = { "cargo-drone-status.docked-with-refueler" }
                end
            elseif dh.get_queuing_mooring(drone) == target_mooring then
                if mooring_type == 1 then
                    task_label.caption = { "cargo-drone-status.queuing-at-provider", math.floor(util.distance(drone.position, target_mooring.position)) }
                elseif mooring_type == 2 then
                    task_label.caption = { "cargo-drone-status.queuing-at-requester", math.floor(util.distance(drone.position, target_mooring.position)) }
                else
                    task_label.caption = { "cargo-drone-status.queuing-at-refueler", math.floor(util.distance(drone.position, target_mooring.position)) }
                end
            else
                if mooring_type == 1 then
                    task_label.caption = { "cargo-drone-status.heading-to-provider", math.floor(util.distance(drone.position, target_mooring.position)) }
                elseif mooring_type == 2 then
                    task_label.caption = { "cargo-drone-status.heading-to-requester", math.floor(util.distance(drone.position, target_mooring.position)) }
                else
                    task_label.caption = { "cargo-drone-status.heading-to-refueler", math.floor(util.distance(drone.position, target_mooring.position)) }
                end
            end

            minimap.entity = drone
        end

        local function create_drone_element(index, drone, task)
            local minimap_border = player_data.elements.drone_table.add{
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

        for task_id, _ in pairs(task_ids) do
            local task = dt.get(task_id)
            
            local element = player_data.elements.drone_table[mooring_drone_prefix .. index]
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
        local element = player_data.elements.drone_table[mooring_drone_prefix .. index]

        if not element then
            break
        end

        index = index + 1
        element.destroy()
    end
end

local function update_gui(player_data)
    for key, observer in pairs(observers) do
        local data = observer.get(player_data)

        if data ~= player_data.observer_data[key] then
            observer.updated(player_data, data)

            player_data.observer_data[key] = data
        end
    end

    if player_data.elements.items_table ~= nil then
        update_item_signals(player_data)
    end
    update_drone_list(player_data)
end

local callbacks = {
    ---------- Mooring ----------
    [gui_prefix .. "mooring-close-button"] = function(player_data, event)
        if not player_data.player.gui.screen[window_gui_name] then
            return
        end

        player_data.player.opened = nil
    end,

    [gui_prefix .. "drone-limit-checkbox"] = function(player_data, event)
        mh.set_drone_limit_enabled(player_data.entity, player_data.elements.drone_limit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-slider"] = function(player_data, event)
        mh.set_drone_limit_value(player_data.entity, player_data.elements.drone_limit_slider.slider_value)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-textfield"] = function(player_data, event)
        local limit = tonumber(player_data.elements.drone_limit_field.text)

        if limit == nil then
            return
        end

        mh.set_drone_limit_value(player_data.entity, limit)

        update_gui(player_data)
    end,

    [gui_prefix .. "priority-slider"] = function(player_data, event)
        mh.set_priority_value(player_data.entity, player_data.elements.priority_slider.slider_value)

        update_gui(player_data)
    end,
    [gui_prefix .. "priority-textfield"] = function(player_data, event)
        local priority = tonumber(player_data.elements.priority_field.text)

        if priority == nil then
            return
        end

        mh.set_priority_value(player_data.entity, priority)

        update_gui(player_data)
    end,

    ---------- Circuit ----------
    [gui_prefix .. "set-drone-limit-checkbox"] = function(player_data, event)
        mh.set_drone_limit_circuit(player_data.entity, player_data.elements.drone_limit_circuit_checkbox.state)

        if not mh.is_drone_limit_circuit(player_data.entity) then
            player_data.elements.drone_limit_checkbox.enabled = player_data.elements.drone_limit_checkbox.state
            player_data.elements.drone_limit_slider.enabled = player_data.elements.drone_limit_checkbox.state
            player_data.elements.drone_limit_field.enabled = player_data.elements.drone_limit_checkbox.state
        end

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-signal-choose-elem-button"] = function(player_data, event)
        mh.set_drone_limit_circuit_signal_id(player_data.entity, player_data.elements.drone_limit_signal_choose_elem_button.elem_value)
    end,

    [gui_prefix .. "read-drone-count-checkbox"] = function(player_data, event)
        mh.set_drone_count_circuit(player_data.entity, player_data.elements.drone_count_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-count-signal-choose-elem-button"] = function(player_data, event)
        mh.set_drone_count_circuit_signal_id(player_data.entity, player_data.elements.drone_count_signal_choose_elem_button.elem_value)
    end,

    [gui_prefix .. "set-priority-checkbox"] = function(player_data, event)
        mh.set_priority_circuit(player_data.entity, player_data.elements.priority_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "priority-signal-choose-elem-button"] = function(player_data, event)
        mh.set_priority_circuit_signal_id(player_data.entity, player_data.elements.priority_signal_choose_elem_button.elem_value)
    end,
}

for x = 1, 3 do
    for y = 1, 3 do
        callbacks[gui_prefix .. "inventory-target-button-" .. x .. "_" .. y] = function(player_data, event)
            local target = mh.get_inventory_target(player_data.entity, x, y)

            if event.button == defines.mouse_button_type.left then
                if target == defines.inventory.car_trunk then
                    target = defines.inventory.fuel
                elseif constants.drone_has_burnt_result and target == defines.inventory.fuel then
                    target = defines.inventory.burnt_result
                else
                    target = defines.inventory.car_trunk
                end
            elseif event.button == defines.mouse_button_type.right then
                if target == defines.inventory.fuel then
                    target = defines.inventory.car_trunk
                elseif constants.drone_has_burnt_result and target == defines.inventory.car_trunk then
                    target = defines.inventory.burnt_result
                else
                    target = defines.inventory.fuel
                end
            else
                return
            end

            mh.set_inventory_target(player_data.entity, x, y, target)

            update_gui(player_data)
        end
    end
end

local function handle_event(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    local player = game.get_player(event.player_index)

    if not storage.gui_mooring_player[player.index] then
        return
    end

    local callable = callbacks[element.name]

    if not callable then
        return
    end

    callable(storage.gui_mooring_player[player.index], event)
end

local function build_gui_mooring(player_data, mooring, parent)
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

    player_data.elements.preview = preview

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

    player_data.elements.drone_limit_checkbox = drone_limit_checkbox
    player_data.elements.drone_limit_slider = drone_limit_slider
    player_data.elements.drone_limit_field = drone_limit_field

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

    player_data.elements.priority_slider = priority_slider
    player_data.elements.priority_field = priority_field

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

        player_data.elements.items_table = items_table
        player_data.elements.signal_item_indices = {}

        items_table.style.minimal_height = 40
        items_table.style.padding = 4
    end

    ---------- Item Signals ----------

    local inventory_target_flow = mooring_frame.add{
        type = "flow",
        direction = "vertical",
    }

    inventory_target_flow.style.horizontal_align = "center"

    local inventory_target_row_flow = mooring_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    local function create_inventory_target_button(x, y)
        local inventory_target_button = inventory_target_row_flow.add{
            type = "sprite-button",
            name = gui_prefix .. "inventory-target-button-" .. x .. "_" .. y,
            sprite = get_inventory_target_icon(mh.get_inventory_target(mooring, x, y)),
        }

        player_data.elements["inventory_target_button_" .. x .. "_" .. y] = inventory_target_button
    end

    create_inventory_target_button(1, 1)
    create_inventory_target_button(2, 1)
    create_inventory_target_button(3, 1)

    inventory_target_row_flow = mooring_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    create_inventory_target_button(1, 2)
    create_inventory_target_button(2, 2)
    create_inventory_target_button(3, 2)

    inventory_target_row_flow = mooring_frame.add{
        type = "flow",
        direction = "horizontal",
    }

    create_inventory_target_button(1, 3)
    create_inventory_target_button(2, 3)
    create_inventory_target_button(3, 3)

    ---------- Filler ----------
    local mooring_filler = mooring_frame.add{
        type = "empty-widget",
        style = "entity_frame_filler"
    }

    mooring_filler.style.vertically_stretchable = true
end

local function build_gui_drones(player_data, parent)
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

    player_data.elements.drone_table = drone_table
end

local function build_gui_circuit_connection_status(player_data, mooring, parent)
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
local function build_gui_circuit(player_data, mooring, parent)
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

    build_gui_circuit_connection_status(player_data, mooring, main_frame)

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

    player_data.elements.drone_count_circuit_checkbox = drone_count_circuit_checkbox
    player_data.elements.drone_count_signal_label = drone_count_signal_label
    player_data.elements.drone_count_signal_choose_elem_button = drone_count_signal_choose_elem_button

    ---------- Priority ----------

    main_frame.add{
        type = "line",
    }

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

    player_data.elements.priority_circuit_checkbox = priority_circuit_checkbox
    player_data.elements.priority_signal_label = priority_signal_label
    player_data.elements.priority_signal_choose_elem_button = priority_signal_choose_elem_button
end

local function build_gui(player, mooring, mooring_name)
    local player_data = {
        player = player,
        entity = mooring,
        entity_unit_number = mooring.unit_number,
        entity_name = mooring_name,
        surface_index = mooring.surface.index,
        position = mooring.position,
        elements = {},
        observer_data = {}
    }

    for key, _ in pairs(observers) do
        player_data.observer_data[key] = not_observed
    end

    storage.gui_mooring_player[player.index] = player_data

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

    local main_flow = frame.add{
        type = "flow",
        direction = "horizontal",
    }

    main_flow.style.horizontal_spacing = 8

    build_gui_mooring(player_data, mooring, main_flow)

    build_gui_drones(player_data, main_flow)

    build_gui_circuit(player_data, mooring, main_flow)

    player.opened = frame

    update_gui(player_data)
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
            player_data.elements.preview.entity = entity

            add_to_lookup(player_index, entity.unit_number)
        end

        update_gui(player_data)

        ::continue::
    end

    if removed ~= nil then
        for _, player_index in ipairs(removed) do
            local player_data = storage.gui_mooring_player[player_index]

            if player_data.player.valid then
               local window = player_data.player.gui.screen[window_gui_name]

                if window then
                    window.destroy()
                end
            end

            remove_from_lookup(player_index, player_data.entity_unit_number)
            
            storage.gui_mooring_player[player_index] = nil
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

    add_to_lookup(player.index, entity.unit_number)

    build_gui(player, entity, entity_name)
end
function gui_mooring.on_gui_closed(event)
	if event.gui_type ~= defines.gui_type.custom then
		return
	end

	local player = game.get_player(event.player_index)

    if event.element.name ~= window_gui_name then
        return
    end

    player.gui.screen[window_gui_name].destroy()

    if not storage.gui_mooring_player[event.player_index] then
        return
    end

    local entity_unit_number = storage.gui_mooring_player[event.player_index].entity_unit_number

    remove_from_lookup(event.player_index, entity_unit_number)

    storage.gui_mooring_player[event.player_index] = nil

    player.opened = nil
end
function gui_mooring.on_gui_click(event)
    handle_event(event)

    local player = game.get_player(event.player_index)
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
    handle_event(event)
end
function gui_mooring.on_gui_value_changed(event)
    handle_event(event)
end
function gui_mooring.on_gui_text_changed(event)
    handle_event(event)
end
function gui_mooring.on_gui_elem_changed(event)
    handle_event(event)
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
