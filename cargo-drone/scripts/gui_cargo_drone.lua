
local ep = require("entity_property")
local dt = require("drone_tasks")
local dh = require("drone_helper")

local gui_prefix = "cargo-drone-"

local gui_targets_name = gui_prefix .. "targets"
local mooring_prefix = gui_prefix .. "mooring-"
local minimap_name = gui_prefix .. "mooring-minimap"

local function update_gui(player, drone)
    local main_frame = player.gui.relative[gui_targets_name][gui_prefix .. "main-frame"]

    local current_mooring_index = 1

    local function update_mooring(unit_number, mooring_type)
        local mooring = ep.get_managed_entity(unit_number)
        local mooring_frame = main_frame[mooring_prefix .. current_mooring_index]

        mooring_frame.visible = true
        mooring_frame[gui_prefix .. "minimap-frame"][gui_prefix .. "minimap-flow"][minimap_name].entity = mooring

        local label = mooring_frame[gui_prefix .. "task-frame"][gui_prefix .. "task-header-frame"][gui_prefix .. "task-label"]

        if dh.get_docked_mooring(drone) == mooring then
            if mooring_type == 1 then
                label.caption = { "cargo-drone-status.docked-with-provider" }
            elseif mooring_type == 2 then
                label.caption = { "cargo-drone-status.docked-with-requester" }
            else
                label.caption = { "cargo-drone-status.docked-with-refueler" }
            end
        elseif dh.get_queuing_mooring(drone) == mooring then
            if mooring_type == 1 then
                label.caption = { "cargo-drone-status.queuing-at-provider", math.floor(util.distance(drone.position, mooring.position)) }
            elseif mooring_type == 2 then
                label.caption = { "cargo-drone-status.queuing-at-requester", math.floor(util.distance(drone.position, mooring.position)) }
            else
                label.caption = { "cargo-drone-status.queuing-at-refueler", math.floor(util.distance(drone.position, mooring.position)) }
            end
        elseif dh.get_parked_depot(drone) == mooring then
            label.caption = { "cargo-drone-status.parked-by-depot" }
        elseif current_mooring_index == 1 then
            if mooring_type == 1 then
                label.caption = { "cargo-drone-status.heading-to-provider", math.floor(util.distance(drone.position, mooring.position)) }
            elseif mooring_type == 2 then
                label.caption = { "cargo-drone-status.heading-to-requester", math.floor(util.distance(drone.position, mooring.position)) }
            elseif mooring_type == 3 then
                label.caption = { "cargo-drone-status.heading-to-refueler", math.floor(util.distance(drone.position, mooring.position)) }
            else
                label.caption = { "cargo-drone-status.heading-to-depot", math.floor(util.distance(drone.position, mooring.position)) }
            end
        else
            if mooring_type == 1 then
                label.caption = { "cargo-drone-status.provider" }
            else
                label.caption = { "cargo-drone-status.requester" }
            end
        end

        current_mooring_index = current_mooring_index + 1
    end

    local function update_task(task)
        if task.provider_unit_number ~= nil then
            update_mooring(task.provider_unit_number, 1)
        end

        if task.requester_unit_number ~= nil then
            update_mooring(task.requester_unit_number, 2)
        end

        if task.refueler_unit_number ~= nil then
            update_mooring(task.refueler_unit_number, 3)
        end

        if task.depot_unit_number ~= nil then
            update_mooring(task.depot_unit_number, 4)
        end
    end

    local task_ids = dt.get_entity_task_ids(drone)

    main_frame[gui_prefix .. "idle-border"].visible = task_ids == nil

    if task_ids then
        update_task(dt.get(task_ids[1]))

        if task_ids[2] then
            update_task(dt.get(task_ids[2]))
        end
    end

    for i = current_mooring_index, 3 do
        main_frame[mooring_prefix .. i].visible = false
    end
end

local gui_cargo_drone = {}

function gui_cargo_drone.create_player_storage()
    storage.gui_cargo_drone = storage.gui_cargo_drone or {}
end

function gui_cargo_drone.tick()
    local removed = nil

    for player_index, drone in pairs(storage.gui_cargo_drone) do
        if drone.valid then
            local player = game.get_player(player_index)

            update_gui(player, drone)
        else
            if removed == nil then
                removed = {}
            end

            table.insert(removed, player_index)
        end
    end

    if removed then
        for _, player_index in ipairs(removed) do
	        local player = game.get_player(player_index)

            if player.gui.relative[gui_targets_name] then
                player.gui.relative[gui_targets_name].destroy()
            end
            storage.gui_cargo_drone[player_index] = nil
        end
    end
end

function gui_cargo_drone.on_player_removed(event)
    storage.gui_cargo_drone[event.player_index] = nil
end

function gui_cargo_drone.on_gui_opened(event)
	local entity = event.entity

	if not entity or not entity.valid then
		return
	end

    if entity.name ~= "cargo-drone" then
        return
    end

	local player = game.get_player(event.player_index)

    if player.gui.relative[gui_targets_name] then
        player.gui.relative[gui_targets_name].destroy()
    end

    storage.gui_cargo_drone[event.player_index] = entity

    local targets_frame = player.gui.relative.add{
        type = "frame",
        name = gui_targets_name,
        direction = "vertical",
        anchor = { gui = defines.relative_gui_type.car_gui, position = defines.relative_gui_position.right }
    }

    local title_flow = targets_frame.add{
        type = "flow",
        direction = "horizontal"
    }

    title_flow.style.height = 26
    title_flow.style.horizontally_stretchable = true
    title_flow.style.left_margin = 4
    title_flow.style.right_margin = 4
    title_flow.style.vertical_align = "center"

    title_flow.add{
        type = "label",
        caption = { "cargo-drone-gui-cargo-drone.targets" },
        style = "frame_title"
    }

    local title_filller = title_flow.add{
        type = "empty-widget",
    }

    title_filller.style.horizontally_stretchable = true

    title_flow.add{
        type = "sprite-button",
        name = gui_prefix .. "open-on-map",
        style = "tool_button",
        sprite = "utility/map",
        tooltip = { "gui-train.open-in-map" }
    }

    local main_frame = targets_frame.add{
        type = "frame",
        name = gui_prefix .. "main-frame",
        style = "inside_shallow_frame",
        direction = "vertical",
    }

    main_frame.style.margin = 2
    main_frame.style.width = 310

    local idle_border = main_frame.add{
        type = "frame",
        name = gui_prefix .. "idle-border",
        style = "shallow_frame",
        direction = "vertical",
    }

    local idle_frame = idle_border.add{
        type = "frame",
        style = "inside_deep_frame",
        direction = "vertical"
    }

    idle_frame.style.margin = 4

    local idle_header_frame = idle_frame.add{
        type = "frame",
        style = "subheader_frame"
    }

    idle_header_frame.style.horizontally_stretchable = true
    idle_header_frame.style.vertical_align = "center"

    idle_header_frame.add{
        type = "label",
        style = "subheader_label",
        caption = { "cargo-drone-gui-cargo-drone.idle" }
    }

    local function create_mooring_element(index)
        local mooring_border = main_frame.add{
            type = "frame",
            name = mooring_prefix .. index,
            style = "shallow_frame",
            direction = "vertical",
        }

        local minimap_frame = mooring_border.add{
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

        minimap.style.horizontally_stretchable = true
        minimap.style.height = 120

        local task_frame = mooring_border.add{
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

        task_header_frame.add{
            type = "label",
            name = gui_prefix .. "task-label",
            style = "subheader_label"
        }
    end

    create_mooring_element(1)
    create_mooring_element(2)
    create_mooring_element(3)

    update_gui(player, entity)
end
function gui_cargo_drone.on_gui_closed(event)
	if event.gui_type ~= defines.gui_type.entity then
		return
	end

    if event.entity ~= storage.gui_cargo_drone[event.player_index] then
        return
    end

	local player = game.get_player(event.player_index)

    player.gui.relative[gui_targets_name].destroy()
    storage.gui_cargo_drone[event.player_index] = nil
end
function gui_cargo_drone.on_gui_click(event)
    local player = game.get_player(event.player_index)

    if not storage.gui_cargo_drone[player.index] then
        return
    end

    local element = event.element

    if not element or not element.valid then
        return
    end

    if element.name == minimap_name then
        player.opened = element.entity
    elseif element.name == gui_prefix .. "open-on-map" then
        player.centered_on = storage.gui_cargo_drone[event.player_index]

        player.opened = nil
    end
end

return gui_cargo_drone
