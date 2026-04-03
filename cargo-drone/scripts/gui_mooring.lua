
-- If you're here looking for a good way to handle GUI. Go elsewhere. There's nothing for you here. Naught but despair

local constants = require("constants")
local ccse      = require("cc_string_encoder")
local ep        = require("entity_property")
local th        = require("target_helper")
local dt        = require("drone_tasks")
local mh        = require("mooring_helper")
local dh        = require("drone_helper")

local gui_prefix = "cargo-drone-"

local mooring_drone_prefix = gui_prefix .. "mooring-drone-"
local minimap_name = gui_prefix .. "drone-minimap"

local window_gui_name = gui_prefix .. "window-mooring-main"

local entity_types = {
    provider    = 1,
    requester   = 2,
    refueler    = 3,
    depot       = 4,
}
local entity_type_lookup = {
    ["cargo-drone-mooring-constant-combinator-provider"]    = entity_types.provider,
    ["cargo-drone-mooring-constant-combinator-requester"]   = entity_types.requester,
    ["cargo-drone-mooring-constant-combinator-refueler"]    = entity_types.refueler,
    ["cargo-drone-depot-constant-combinator"]               = entity_types.depot,
}

local not_observed = {}

local function is_entity_type_mooring(entity_type)
    return entity_type ~= entity_types.depot
end

local function get_drone_limit_signal_element(player_data, element)
    local signal_id = th.get_drone_limit_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end
local function get_drone_count_signal_element(player_data, element)
    local signal_id = th.get_drone_count_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end
local function get_drone_id_signal_element(player_data, element)
    local signal_id = mh.get_drone_id_circuit_signal_id(player_data.entity)

    if signal_id == nil then
        return nil
    end

    return signal_id[element]
end
local function get_priority_signal_element(player_data, element)
    local signal_id = th.get_priority_circuit_signal_id(player_data.entity)

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
local function get_inventory_target_tooltip(inventory_target)
    if inventory_target == defines.inventory.fuel then
        return { "cargo-drone-gui-mooring.inventory-target-tooltip-fuel" }
    elseif inventory_target == defines.inventory.car_trunk then
        return { "cargo-drone-gui-mooring.inventory-target-tooltip-trunk" }
    elseif inventory_target == defines.inventory.burnt_result then
        return { "cargo-drone-gui-mooring.inventory-target-tooltip-burnt-results" }
    end

    return { "cargo-drone-gui-mooring.inventory-target-tooltip-unknown" }
end

local observers = {
    get_name = {
        get = function(player_data)
            return th.get_name(player_data.entity)
        end,
        updated = function(player_data, data)
            player_data.elements.name_label.caption = data
        end
    },

    is_drone_limit_enabled = {
        get = function(player_data) return th.is_drone_limit_enabled(player_data.entity) end,
        updated = function(player_data, data)
            if th.is_drone_limit_circuit(player_data.entity) then
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
        get = function(player_data) return th.is_drone_limit_circuit(player_data.entity) end,
        updated = function(player_data, data)
            if data then
                player_data.elements.drone_limit_checkbox.state = true
                player_data.elements.drone_limit_checkbox.enabled = false
                player_data.elements.drone_limit_slider.enabled = false
                player_data.elements.drone_limit_field.enabled = false
            else
                local drone_limit_enabled = th.is_drone_limit_enabled(player_data.entity)

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
        get = function(player_data) return th.get_drone_limit(player_data.entity) end,
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
        get = function(player_data) return th.is_priority_circuit(player_data.entity) end,
        updated = function(player_data, data)
            player_data.elements.priority_field.enabled = not data
            player_data.elements.priority_slider.enabled = not data

            player_data.elements.priority_circuit_checkbox.state = data
            player_data.elements.priority_signal_label.enabled = data
            player_data.elements.priority_signal_choose_elem_button.enabled = data
        end
    },
    get_priority = {
        get = function(player_data) return th.get_priority(player_data.entity) end,
        updated = function(player_data, data)
            if player_data.elements.priority_field.text ~= tostring(data) then
                player_data.elements.priority_field.text = tostring(data)
            end
            player_data.elements.priority_slider.slider_value = data
        end
    },

    get_request_mode = {
        get = function(player_data)
            if player_data.entity_type ~= entity_types.requester then
                return
            end

            return mh.get_request_mode(player_data.entity)
        end,
        updated = function(player_data, data)
            if player_data.entity_type ~= entity_types.requester then
                return
            end

            player_data.elements.request_mode_drop_down.selected_index = mh.get_request_mode(player_data.entity) + 1
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
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = th.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_limit_signal_element_name = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = th.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_limit_signal_element_quality = {
        get = function(player_data) return get_drone_limit_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.drone_limit_signal_choose_elem_button.elem_value = th.get_drone_limit_circuit_signal_id(player_data.entity)
        end
    },

    get_drone_id_circuit = {
        get = function(player_data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return nil
            end

            return mh.get_drone_id_circuit(player_data.entity)
        end,
        updated = function(player_data, data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return
            end

            player_data.elements.drone_id_circuit_checkbox.state = data
            player_data.elements.drone_id_signal_label.enabled = data
            player_data.elements.drone_id_signal_choose_elem_button.enabled = data
        end
    },
    get_drone_id_signal_element_type = {
        get = function(player_data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return nil
            end

            return get_drone_id_signal_element(player_data, "type")
        end,
        updated = function(player_data, data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return
            end

            player_data.elements.drone_id_signal_choose_elem_button.elem_value = mh.get_drone_id_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_id_signal_element_name = {
        get = function(player_data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return nil
            end

            return get_drone_id_signal_element(player_data, "name")
        end,
        updated = function(player_data, data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return
            end

            player_data.elements.drone_id_signal_choose_elem_button.elem_value = mh.get_drone_id_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_id_signal_element_quality = {
        get = function(player_data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return nil
            end

            return get_drone_id_signal_element(player_data, "quality")
        end,
        updated = function(player_data, data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return
            end

            player_data.elements.drone_id_signal_choose_elem_button.elem_value = mh.get_drone_id_circuit_signal_id(player_data.entity)
        end
    },

    is_drone_count_circuit = {
        get = function(player_data) return th.is_drone_count_circuit(player_data.entity) end,
        updated = function(player_data, data)
            player_data.elements.drone_count_circuit_checkbox.state = data
            player_data.elements.drone_count_signal_label.enabled = data
            player_data.elements.drone_count_signal_choose_elem_button.enabled = data
        end
    },
    get_drone_count_signal_element_type = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "type") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = th.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_count_signal_element_name = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = th.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },
    get_drone_count_signal_element_quality = {
        get = function(player_data) return get_drone_count_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.drone_count_signal_choose_elem_button.elem_value = th.get_drone_count_circuit_signal_id(player_data.entity)
        end
    },

    get_priority_signal_element_type = {
        get = function(player_data) return get_priority_signal_element(player_data, "type") end,
        updated = function(player_data, data)
            player_data.elements.priority_signal_choose_elem_button.elem_value = th.get_priority_circuit_signal_id(player_data.entity)
        end
    },
    get_priority_signal_element_name = {
        get = function(player_data) return get_priority_signal_element(player_data, "name") end,
        updated = function(player_data, data)
            player_data.elements.priority_signal_choose_elem_button.elem_value = th.get_priority_circuit_signal_id(player_data.entity)
        end
    },
    get_priority_signal_element_quality = {
        get = function(player_data) return get_priority_signal_element(player_data, "quality") end,
        updated = function(player_data, data)
            player_data.elements.priority_signal_choose_elem_button.elem_value = th.get_priority_circuit_signal_id(player_data.entity)
        end
    },

    get_read_requests_circuit = {
        get = function(player_data)
            if not is_entity_type_mooring(player_data.entity_type) then
                return nil
            end

            return mh.get_read_requests(player_data.entity)
        end,
        updated = function(player_data, data)
            if player_data.elements.read_requests_circuit_checkbox then
                player_data.elements.read_requests_circuit_checkbox.state = data
            end
        end
    },
}

for x = 1, 3 do
    for y = 1, 3 do
        observers["get_inventory_target_button_" .. x .. "_" .. y] = {
            get = function(player_data)
                if not is_entity_type_mooring(player_data.entity_type) then
                    return nil
                end

                return mh.get_inventory_target(player_data.entity, x, y)
            end,
            updated = function(player_data, data)
                if not is_entity_type_mooring(player_data.entity_type) then
                    return
                end

                local element = player_data.elements["inventory_target_button_" .. x .. "_" .. y]
                local inventory_target = mh.get_inventory_target(player_data.entity, x, y)

                element.sprite = get_inventory_target_icon(inventory_target)
                element.tooltip = get_inventory_target_tooltip(inventory_target)
            end
        }
    end
end

local function update_item_signals(player_data)
    local function update_item_element(index, name, quality, count)
        local item_sprite = player_data.elements.signal_item_indices[index]

        if not item_sprite then
            item_sprite = player_data.elements.items_table.add{
                type = "sprite-button",
                style = "transparent_slot"
            }

            player_data.elements.signal_item_indices[index] = item_sprite
        end

        item_sprite.sprite = "item/" .. name
        item_sprite.quality = quality
        item_sprite.number = count
        item_sprite.tooltip = prototypes.item[name].localised_name
        item_sprite.visible = true
    end

    local mooring_signals = player_data.entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    local current_index = 1

    if mooring_signals then
        local requests = {}

        for i, item in ipairs(mooring_signals) do
            if item.signal.type ~= nil then
                goto continue
            end
            if item.count <= 0 then
                goto continue
            end

            local selected_item = requests[item.signal.name]

            if not selected_item then
                selected_item = {}

                requests[item.signal.name] = selected_item
            end

            selected_item[item.signal.quality or "normal"] = item.count

            ::continue::
        end

        local request_output = mh.get_request_output(player_data.entity)

        if request_output and mh.get_read_requests(player_data.entity) then
            local mul = 0

            if player_data.entity.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil then
                mul = mul + 1
            end
            if player_data.entity.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil then
                mul = mul + 1
            end

            if mul > 0 then
                for _, item in ipairs(request_output) do
                    local selected_item = requests[item.name]

                    if selected_item and selected_item[item.quality] ~= nil then
                        selected_item[item.quality] = selected_item[item.quality] - item.count * mul
                    end
                end
            end
        end

        for name, quality_and_count in pairs(requests) do
            for quality, count in pairs(quality_and_count) do
                update_item_element(current_index, name, quality, count)

                current_index = current_index + 1
            end
        end
    end

    for i = current_index, #player_data.elements.signal_item_indices do
        player_data.elements.signal_item_indices[i].visible = false
    end
end

local function update_drone_list(player_data)
    local mooring = player_data.entity

    local task_ids = dt.get_entity_task_ids(mooring)
    local sorted_drone_task_list = {}

    local drone_count = 0

    if task_ids then
        local function get_weight(drone, task)
            local target = dh.get_docked_mooring(drone)

            if target then
                if target == mooring then
                    return 1
                else
                    return 5
                end
            end

            target = dh.get_docking_mooring(drone)

            if target then
                if target == mooring then
                    return 2
                else
                    return 6
                end
            end

            target = dh.get_queuing_mooring(drone)

            if target then
                if target == mooring then
                    return 3
                else
                    return 7
                end
            end

            target = dt.get_target(task)

            if target then
                if target == mooring then
                    return 4
                else
                    return 8
                end
            end

            return 9
        end

        local function insert_sorted(drone, task)
            local weight = get_weight(drone, task)

            for i, drone_task in ipairs(sorted_drone_task_list) do
                if weight < drone_task[3] then
                    table.insert(sorted_drone_task_list, i, { drone, task, weight })

                    return
                end
            end

            table.insert(sorted_drone_task_list, { drone, task, weight })
        end

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
            elseif task.refueler_unit_number then
                mooring_type = 3
                target_mooring = ep.get_managed_entity(task.refueler_unit_number)
            else
                mooring_type = 4
                target_mooring = ep.get_managed_entity(task.depot_unit_number)
            end

            if dh.get_docked_mooring(drone) == target_mooring then
                if mooring_type == 1 then
                    task_label.caption = { "cargo-drone-status.docked-with-provider", th.get_name(target_mooring) }
                elseif mooring_type == 2 then
                    task_label.caption = { "cargo-drone-status.docked-with-requester", th.get_name(target_mooring) }
                else
                    task_label.caption = { "cargo-drone-status.docked-with-refueler", th.get_name(target_mooring) }
                end
            elseif dh.get_queuing_mooring(drone) == target_mooring then
                if mooring_type == 1 then
                    task_label.caption = { "cargo-drone-status.queuing-at-provider", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
                elseif mooring_type == 2 then
                    task_label.caption = { "cargo-drone-status.queuing-at-requester", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
                else
                    task_label.caption = { "cargo-drone-status.queuing-at-refueler", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
                end
            elseif dh.get_parked_depot(drone) == target_mooring then
                task_label.caption = { "cargo-drone-status.parked-by-depot", th.get_name(target_mooring) }
            else
                if mooring_type == 1 then
                    task_label.caption = { "cargo-drone-status.heading-to-provider", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
                elseif mooring_type == 2 then
                    task_label.caption = { "cargo-drone-status.heading-to-requester", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
                elseif mooring_type == 3 then
                    task_label.caption = { "cargo-drone-status.heading-to-refueler", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
                else
                    task_label.caption = { "cargo-drone-status.heading-to-depot", th.get_name(target_mooring), math.floor(util.distance(drone.position, target_mooring.position)) }
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

            task_label.style.maximal_width = 250

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
                items_table.add{
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
            drone_count = drone_count + 1
            local task = dt.get(task_id)

            local drone = ep.get_managed_entity(task.drone_unit_number)

            insert_sorted(drone, task)
        end

        for i, drone_task in ipairs(sorted_drone_task_list) do
            local element = player_data.elements.drone_table[mooring_drone_prefix .. i]
            local drone = drone_task[1]
            local task = drone_task[2]

            if element then
                local minimap = element[gui_prefix .. "minimap-frame"][gui_prefix .. "minimap-flow"][minimap_name]
                local task_label = element[gui_prefix .. "task-frame"][gui_prefix .. "task-header-frame"][gui_prefix .. "task-label"]

                update_elements(drone, minimap, task_label)
            else
                create_drone_element(i, drone, task)
            end
        end
    end

    local index = #sorted_drone_task_list + 1

    while true do
        local element = player_data.elements.drone_table[mooring_drone_prefix .. index]

        if not element then
            break
        end

        index = index + 1
        element.destroy()
    end

    player_data.elements.drone_header.caption = { "cargo-drone-gui-mooring.tasked-cargo-drone", drone_count }
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

local function try_set_name(player_data)
    if player_data.elements.name_textfield.text == "" then
        return
    end

    th.set_name(player_data.entity, player_data.elements.name_textfield.text)
    player_data.elements.name_label.visible = true
    player_data.elements.name_edit.visible = true
    player_data.elements.name_textfield.visible = false
    player_data.elements.name_textfield_confirm.visible = false
end

local callbacks = {
    ---------- Mooring ----------
    [gui_prefix .. "mooring-close-button"] = function(player_data, event)
        if not player_data.player.gui.screen[window_gui_name] then
            return
        end

        player_data.player.opened = nil
    end,

    [gui_prefix .. "name-edit"] = function(player_data, event)
        player_data.elements.name_label.visible = false
        player_data.elements.name_edit.visible = false
        player_data.elements.name_textfield.visible = true
        player_data.elements.name_textfield_confirm.visible = true
        player_data.elements.name_textfield_confirm.enabled = true

        player_data.elements.name_textfield.focus()
    end,
    [gui_prefix .. "name-textfield"] = function(player_data, event)
        if event.name == defines.events.on_gui_confirmed then
            try_set_name(player_data)

            return
        end

        local new_text = player_data.elements.name_textfield.text

        if new_text == "" then
            player_data.elements.name_textfield.style = "invalid_value_textfield"
            player_data.elements.name_textfield.tooltip = { "cargo-drone-gui-mooring.rename-tooltip-error-empty" }
            player_data.elements.name_textfield_confirm.enabled = false

            return
        end

        local dummy_section = {}

        ccse.encode(player_data.elements.name_textfield.text, dummy_section)

        local parsed_text = ccse.decode(dummy_section)

        if parsed_text ~= new_text then
            player_data.elements.name_textfield.style = "invalid_value_textfield"
            player_data.elements.name_textfield.tooltip = { "cargo-drone-gui-mooring.rename-tooltip-error-too-big" }
            player_data.elements.name_textfield_confirm.enabled = false

            return
        end

        player_data.elements.name_textfield.style = "textbox"
        player_data.elements.name_textfield.tooltip = nil
        player_data.elements.name_textfield_confirm.enabled = true
    end,
    [gui_prefix .. "name-textfield-confirm"] = function(player_data, event)
        try_set_name(player_data)
    end,
    [gui_prefix .. "open-on-map"] = function(player_data, event)
        player_data.player.centered_on = player_data.entity

        player_data.player.opened = nil
    end,

    [gui_prefix .. "drone-limit-checkbox"] = function(player_data, event)
        th.set_drone_limit_enabled(player_data.entity, player_data.elements.drone_limit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-slider"] = function(player_data, event)
        th.set_drone_limit_value(player_data.entity, player_data.elements.drone_limit_slider.slider_value)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-textfield"] = function(player_data, event)
        local limit = tonumber(player_data.elements.drone_limit_field.text)

        if limit == nil then
            return
        end

        th.set_drone_limit_value(player_data.entity, limit)

        update_gui(player_data)
    end,

    [gui_prefix .. "priority-slider"] = function(player_data, event)
        th.set_priority_value(player_data.entity, player_data.elements.priority_slider.slider_value)

        update_gui(player_data)
    end,
    [gui_prefix .. "priority-textfield"] = function(player_data, event)
        local priority = tonumber(player_data.elements.priority_field.text)

        if priority == nil then
            return
        end

        th.set_priority_value(player_data.entity, priority)

        update_gui(player_data)
    end,

    [gui_prefix .. "request-mode-drop-down"] = function(player_data, event)
        local index = player_data.elements.request_mode_drop_down.selected_index

        -- Not set, ignore
        if index == 0 then
            return
        end

        mh.set_request_mode(player_data.entity, index - 1)

        update_gui(player_data)
    end,

    [gui_prefix .. "depot-alert-button"] = function(player_data, event)
        mh.remove_depot_flag(player_data.entity)
        player_data.elements.depot_alert_button.visible = false
    end,

    ---------- Circuit ----------
    [gui_prefix .. "set-drone-limit-checkbox"] = function(player_data, event)
        th.set_drone_limit_circuit(player_data.entity, player_data.elements.drone_limit_circuit_checkbox.state)

        if not th.is_drone_limit_circuit(player_data.entity) then
            player_data.elements.drone_limit_checkbox.enabled = player_data.elements.drone_limit_checkbox.state
            player_data.elements.drone_limit_slider.enabled = player_data.elements.drone_limit_checkbox.state
            player_data.elements.drone_limit_field.enabled = player_data.elements.drone_limit_checkbox.state
        end

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-limit-signal-choose-elem-button"] = function(player_data, event)
        th.set_drone_limit_circuit_signal_id(player_data.entity, player_data.elements.drone_limit_signal_choose_elem_button.elem_value)
    end,

    [gui_prefix .. "drone-id-checkbox"] = function(player_data, event)
        mh.set_drone_id_circuit(player_data.entity, player_data.elements.drone_id_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-id-signal-choose-elem-button"] = function(player_data, event)
        mh.set_drone_id_circuit_signal_id(player_data.entity, player_data.elements.drone_id_signal_choose_elem_button.elem_value)
    end,

    [gui_prefix .. "read-drone-count-checkbox"] = function(player_data, event)
        th.set_drone_count_circuit(player_data.entity, player_data.elements.drone_count_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "drone-count-signal-choose-elem-button"] = function(player_data, event)
        th.set_drone_count_circuit_signal_id(player_data.entity, player_data.elements.drone_count_signal_choose_elem_button.elem_value)
    end,

    [gui_prefix .. "set-priority-checkbox"] = function(player_data, event)
        th.set_priority_circuit(player_data.entity, player_data.elements.priority_circuit_checkbox.state)

        update_gui(player_data)
    end,
    [gui_prefix .. "priority-signal-choose-elem-button"] = function(player_data, event)
        th.set_priority_circuit_signal_id(player_data.entity, player_data.elements.priority_signal_choose_elem_button.elem_value)
    end,
    [gui_prefix .. "read-requests-checkbox"] = function(player_data, event)
        mh.set_read_requests(player_data.entity, player_data.elements.read_requests_circuit_checkbox.state)

        update_gui(player_data)
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

local function build_gui_mooring(player_data, mooring, mooring_name, parent)
    local mooring_frame = parent.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    ---------- Header ----------
    local header_frame = mooring_frame.add{
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
    }

    header_frame.style.horizontally_stretchable = true
    header_frame.style.vertical_align = "center"

    local name_label = header_frame.add{
        type = "label",
        name = gui_prefix .. "name-label",
        style = "heading_2_label",
        caption = th.get_name(player_data.entity),
    }
    local name_edit = header_frame.add{
        type = "sprite-button",
        name = gui_prefix .. "name-edit",
        style = "tool_button_without_padding",
        sprite = "utility/rename_icon",
    }
    local name_textfield = header_frame.add{
        type = "textfield",
        name = gui_prefix .. "name-textfield",
        style = "textbox",
        text = th.get_name(player_data.entity),
        lose_focus_on_confirm = true,
        icon_selector = true,
        visible = false,
    }
    local name_textfield_confirm = header_frame.add{
        type = "sprite-button",
        name = gui_prefix .. "name-textfield-confirm",
        style = "item_and_count_select_confirm",
        sprite = "utility/enter",
        visible = false,
        tooltip = { "cargo-drone-gui-mooring.rename-tooltip-apply" }
    }

    name_edit.style.size = 16
    name_edit.style.margin = 3
    name_label.style.margin = 2
    name_label.style.maximal_width = 300
    name_textfield_confirm.style.margin = 2

    name_label.style.left_margin = 4

    player_data.elements.name_label = name_label
    player_data.elements.name_edit = name_edit
    player_data.elements.name_textfield = name_textfield
    player_data.elements.name_textfield_confirm = name_textfield_confirm

    local header_filller = header_frame.add{
        type = "empty-widget",
    }

    header_filller.style.horizontally_stretchable = true

    local open_on_map_button = header_frame.add{
        type = "sprite-button",
        name = gui_prefix .. "open-on-map",
        style = "tool_button",
        sprite = "utility/map",
        tooltip = { "gui-train.open-in-map" }
    }

    open_on_map_button.style.margin = 2

    local mooring_flow = mooring_frame.add{
        type = "flow",
        direction = "vertical"
    }

    mooring_flow.style.width = 412
    mooring_flow.style.padding = 16

    ---------- Entity preview ----------
    local preview_frame = mooring_flow.add{
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
    preview.style.width = 380
    preview.style.height = 150

    player_data.elements.preview = preview

    ---------- Drone limit ----------
    local drone_limit_flow = mooring_flow.add{
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
        state = th.is_drone_limit_enabled(mooring)
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
    local priority_flow = mooring_flow.add{
        type = "flow",
        direction = "horizontal",
    }

    priority_flow.style.vertical_align = "center"
    priority_flow.style.horizontal_spacing = 8
    priority_flow.style.bottom_margin = 8

    local priority_tooltip = { "cargo-drone-gui-mooring.priority-mooring-tooltip" }

    if not is_entity_type_mooring(player_data.entity_type) then
        priority_tooltip = { "cargo-drone-gui-mooring.priority-depot-tooltip" }
    end

    priority_flow.add{
        type = "label",
        caption = { "cargo-drone-gui-mooring.priority" },
        tooltip = priority_tooltip,
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
        value = th.get_priority_value(mooring),
        value_step = 10
    }

    local priority_field = priority_flow.add{
        type = "textfield",
        name = gui_prefix .. "priority-textfield",
        style = "slider_value_textfield",
        text = tostring(th.get_priority_value(mooring)),
        numeric = true
    }

    priority_field.style.maximal_width = 40

    player_data.elements.priority_slider = priority_slider
    player_data.elements.priority_field = priority_field

    ---------- Request mode ----------
    if player_data.entity_type == entity_types.requester then
        local request_mode_flow = mooring_flow.add{
            type = "flow",
            direction = "horizontal",
        }

        request_mode_flow.style.vertical_align = "center"
        request_mode_flow.style.horizontal_spacing = 8
        request_mode_flow.style.bottom_margin = 8

        request_mode_flow.add{
            type = "label",
            caption = { "cargo-drone-gui-mooring.request-mode" },
            tooltip = { "cargo-drone-gui-mooring.request-mode-tooltip" },
        }

        local request_mode_filler = request_mode_flow.add{
            type = "empty-widget",
        }

        request_mode_filler.style.horizontally_stretchable = true

        local request_mode_drop_down = request_mode_flow.add{
            type = "drop-down",
            name = gui_prefix .. "request-mode-drop-down",
            items = {
                { "cargo-drone-gui-mooring.request-mode-any" },
                { "cargo-drone-gui-mooring.request-mode-stack" },
                { "cargo-drone-gui-mooring.request-mode-fuzzy" },
                { "cargo-drone-gui-mooring.request-mode-full" },
            },
            selected_index = mh.get_request_mode(mooring) + 1
        }

        player_data.elements.request_mode_drop_down = request_mode_drop_down
    end

    ---------- Depot ----------
    local depot_flow = mooring_flow.add{
        type = "flow",
        direction = "horizontal",
    }

    depot_flow.style.vertical_align = "center"
    depot_flow.style.horizontal_spacing = 8
    depot_flow.style.bottom_margin = 8

    local depot_alert_button = depot_flow.add{
        type = "button",
        name = gui_prefix .. "depot-alert-button",
        caption = { "cargo-drone-gui-mooring.depot-alert-button" },
        tooltip = { "cargo-drone-gui-mooring.depot-alert-button-tooltip" },
        visible = mh.has_depot_flag(mooring)
    }

    player_data.elements.depot_alert_button = depot_alert_button
    ---------- Item Signals ----------

    if player_data.entity_type == entity_types.provider
        or player_data.entity_type == entity_types.requester then
        local label_caption = "cargo-drone-gui-mooring.provided-items"

        if player_data.entity_type == entity_types.requester then
            label_caption = "cargo-drone-gui-mooring.requested-items"
        end

        local items_header = mooring_flow.add{
            type = "label",
            style = "subheader_label",
            caption = { label_caption }
        }

        items_header.style.margin = 4

        local items_frame = mooring_flow.add{
            type = "frame",
            style = "inside_deep_frame",
            direction = "horizontal"
        }

        items_frame.style.margin = 4
        items_frame.style.horizontally_stretchable = true

        local items_scroll = items_frame.add{
            type = "scroll-pane",
            style = "naked_scroll_pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto"
        }

        items_scroll.style.maximal_height = 100

        local items_table = items_scroll.add{
            type = "table",
            column_count = 10
        }
        items_table.style.minimal_height = 40
        items_table.style.horizontally_stretchable = true
        items_table.style.padding = 4

        player_data.elements.items_table = items_table
        player_data.elements.signal_item_indices = {}
    end

    ---------- Item Signals ----------

    local footer_flow = mooring_flow.add{
        type = "flow",
        direction = "horizontal",
    }

    if is_entity_type_mooring(player_data.entity_type) then
        local inventory_targets_flow = footer_flow.add{
            type = "flow",
            direction = "vertical",
        }

        inventory_targets_flow.style.margin = 4

        local inventory_targets_header = inventory_targets_flow.add{
            type = "label",
            style = "subheader_label",
            caption = { "cargo-drone-gui-mooring.inventory-targets" }
        }

        inventory_targets_header.style.margin = 4

        local inventory_targets_rows_flow = inventory_targets_flow.add{
            type = "frame",
            style = "inside_deep_frame",
            direction = "vertical",
        }

        local inventory_targets_row_flow = nil

        local function create_inventory_target_button(x, y)
            local inventory_target = mh.get_inventory_target(mooring, x, y)

            local inventory_target_button = inventory_targets_row_flow.add{
                type = "sprite-button",
                name = gui_prefix .. "inventory-target-button-" .. x .. "_" .. y,
                sprite = get_inventory_target_icon(inventory_target),
                tooltip = get_inventory_target_tooltip(inventory_target)
            }

            player_data.elements["inventory_target_button_" .. x .. "_" .. y] = inventory_target_button
        end

        inventory_targets_row_flow = inventory_targets_rows_flow.add{
            type = "flow",
            direction = "horizontal",
        }

        create_inventory_target_button(1, 1)
        create_inventory_target_button(2, 1)
        create_inventory_target_button(3, 1)

        inventory_targets_row_flow = inventory_targets_rows_flow.add{
            type = "flow",
            direction = "horizontal",
        }

        create_inventory_target_button(1, 2)
        create_inventory_target_button(2, 2)
        create_inventory_target_button(3, 2)

        inventory_targets_row_flow = inventory_targets_rows_flow.add{
            type = "flow",
            direction = "horizontal",
        }

        create_inventory_target_button(1, 3)
        create_inventory_target_button(2, 3)
        create_inventory_target_button(3, 3)
    end

    ---------- Filler ----------
    local mooring_filler = footer_flow.add{
        type = "empty-widget",
        style = "entity_frame_filler"
    }

    mooring_filler.style.top_margin = 8
    mooring_filler.style.bottom_margin = 8
    mooring_filler.style.left_margin = 8
    mooring_filler.style.vertically_stretchable = true
end

local function build_gui_drones(player_data, parent)
    local drones_frame = parent.add{
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical"
    }

    drones_frame.style.width = 310
    drones_frame.style.vertically_stretchable = true

    local subheader_frame = drones_frame.add{
        type = "frame",
        style = "subheader_frame"
    }

    subheader_frame.style.horizontally_stretchable = true
    subheader_frame.style.vertical_align = "center"

    local drone_header = subheader_frame.add{
        type = "label",
        caption = { "cargo-drone-gui-mooring.tasked-cargo-drone", 0 },
        style = "subheader_label"
    }

    local drones_scroll = drones_frame.add{
        type = "scroll-pane",
        style = "scroll_pane_in_shallow_frame",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "always"
    }

    drones_scroll.style.margin = 4
    drones_scroll.style.minimal_height = 416
    drones_scroll.style.vertically_stretchable = true

    local drone_table = drones_scroll.add{
        type = "table",
        column_count = 1,
    }

    drone_table.style.horizontally_stretchable = true
    drone_table.style.margin = 0

    player_data.elements.drone_header = drone_header
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
local function build_gui_circuit(player_data, mooring, mooring_name, parent)
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
        state = th.is_drone_limit_circuit(mooring)
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

    ---------- Drone ID ----------

    if is_entity_type_mooring(player_data.entity_type) then
        main_frame.add{
            type = "line",
        }

        local drone_id_circuit_checkbox = main_frame.add{
            type = "checkbox",
            name = gui_prefix .. "drone-id-checkbox",
            caption = { "cargo-drone-gui-control-behavior-modes.read-docked-drone" },
            tooltip = { "cargo-drone-gui-control-behavior-modes.read-docked-drone-description" },
            style = "subheader_caption_checkbox",
            state = mh.get_drone_id_circuit(mooring)
        }

        drone_id_circuit_checkbox.style.top_margin = 4
        drone_id_circuit_checkbox.style.bottom_margin = 4
        drone_id_circuit_checkbox.style.left_margin = 12
        drone_id_circuit_checkbox.style.right_margin = 12

        local drone_id_signal_flow = main_frame.add{
            type = "flow",
            direction = "horizontal"
        }

        drone_id_signal_flow.style.vertical_align = "center"
        drone_id_signal_flow.style.top_margin = 4
        drone_id_signal_flow.style.bottom_margin = 4
        drone_id_signal_flow.style.left_margin = 12
        drone_id_signal_flow.style.right_margin = 12

        local drone_id_signal_label = drone_id_signal_flow.add{
            type = "label",
            caption = { "cargo-drone-gui-control-behavior-modes.drone-id" }
        }

        local drone_id_signal_filler = drone_id_signal_flow.add{
            type = "empty-widget",
        }

        drone_id_signal_filler.style.horizontally_stretchable = true

        local drone_id_signal_choose_elem_button = drone_id_signal_flow.add{
            type = "choose-elem-button",
            name = gui_prefix .. "drone-id-signal-choose-elem-button",
            elem_type = "signal"
        }

        player_data.elements.drone_id_circuit_checkbox = drone_id_circuit_checkbox
        player_data.elements.drone_id_signal_label = drone_id_signal_label
        player_data.elements.drone_id_signal_choose_elem_button = drone_id_signal_choose_elem_button
    end

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
        state = th.is_drone_count_circuit(mooring)
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
        state = th.is_priority_circuit(mooring)
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

    ---------- Read requests ----------

    if player_data.entity_type == entity_types.provider then
        main_frame.add{
            type = "line",
        }

        local read_requests_circuit_checkbox = main_frame.add{
            type = "checkbox",
            name = gui_prefix .. "read-requests-checkbox",
            caption = { "cargo-drone-gui-control-behavior-modes.read-requests" },
            tooltip = { "cargo-drone-gui-control-behavior-modes.read-requests-description" },
            style = "subheader_caption_checkbox",
            state = mh.get_read_requests(mooring)
        }

        read_requests_circuit_checkbox.style.top_margin = 4
        read_requests_circuit_checkbox.style.bottom_margin = 4
        read_requests_circuit_checkbox.style.left_margin = 12
        read_requests_circuit_checkbox.style.right_margin = 12

        player_data.elements.read_requests_circuit_checkbox = read_requests_circuit_checkbox
    end
end

local function build_gui(player, mooring, mooring_name, entity_type)
    local player_data = {
        player = player,
        entity = mooring,
        entity_unit_number = mooring.unit_number,
        entity_name = mooring_name,
        entity_type = entity_type,
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

    build_gui_mooring(player_data, mooring, mooring_name, main_flow)

    build_gui_drones(player_data, main_flow)

    build_gui_circuit(player_data, mooring, mooring_name, main_flow)

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

    local entity_type = entity_type_lookup[entity_name]

	if not entity_type then
        return
	end

    local player = game.get_player(event.player_index)

    if player.gui.screen[window_gui_name] then
        return
    end

    player.opened = nil

    add_to_lookup(player.index, entity.unit_number)

    build_gui(player, entity, entity_name, entity_type)
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
function gui_mooring.on_gui_selection_state_changed(event)
    handle_event(event)
end
function gui_mooring.on_gui_confirmed(event)
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
