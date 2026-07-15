
local ep = require("entity_property")
local mh = require("mooring_helper")
local dt = require("drone_tasks")

local mooring_top_sprites = {
	[mh.mooring_types.provider]     = "cargo-drone-mooring-top-sprite-provider",
	[mh.mooring_types.requester]    = "cargo-drone-mooring-top-sprite-requester",
	[mh.mooring_types.refueler]     = "cargo-drone-mooring-top-sprite-refueler",
}

local function register_mooring(mooring)
    local surface_buffer = storage.mooring_controller.surfaces[mooring.surface.index]

    if not surface_buffer then
        surface_buffer = {}

        for _, mooring_type in pairs(mh.mooring_types) do
            surface_buffer[mooring_type] = {}
        end

        storage.mooring_controller.surfaces[mooring.surface.index] = surface_buffer
    end

    surface_buffer[mh.get_mooring_type(mooring)][mooring.unit_number] = mooring
end
local function unregister_mooring(mooring)
    local surface_buffer = storage.mooring_controller.surfaces[mooring.surface.index]

    if not surface_buffer then
        return
    end

    surface_buffer[mh.get_mooring_type(mooring)][mooring.unit_number] = nil

    for _, mooring_type in pairs(mh.mooring_types) do
        if next(surface_buffer[mooring_type]) ~= nil then
            return
        end
    end

    storage.mooring_controller.surfaces[mooring.surface.index] = nil
end

local mooring_controller = {}

function mooring_controller.init()
    storage.mooring_controller = storage.mooring_controller or {}

    storage.mooring_controller.surfaces = storage.mooring_controller.surfaces or {}
end

function mooring_controller.surface_deleted(surface_index)
    storage.mooring_controller.surfaces[surface_index] = nil
end
function mooring_controller.surface_cleared(surface_index)
    storage.mooring_controller.surfaces[surface_index] = nil
end

function mooring_controller.created(mooring)
	local mooring_type = mh.get_mooring_type(mooring)
    local proxy_containers = mh.create_proxy_containers(mooring)

    if proxy_containers == nil then
        return
    end

    rendering.draw_sprite{
        sprite = mooring_top_sprites[mooring_type],
        target = mooring,
        surface = mooring.surface,
        render_layer = "elevated-higher-object",
    }
    rendering.draw_sprite{
        sprite = "cargo-drone-mooring-top-shadow-sprite",
        target = mooring,
        surface = mooring.surface,
        render_layer = "object",
    }

	ep.entity_manage(mooring)

	ep.set_entity_property(mooring, "proxy_containers", proxy_containers)

	script.register_on_object_destroyed(mooring)

	if mooring_type == mh.mooring_types.requester then
		ep.set_entity_property(mooring, "next_free_gametick", 0)
	end

	mh.clean_settings(mooring)

    register_mooring(mooring)
end

function mooring_controller.destroyed(mooring)
    local proxy_containers = ep.get_entity_property(mooring, "proxy_containers")

    if proxy_containers then
        for _, proxy_container in ipairs(proxy_containers) do
            proxy_container.destroy({ raise_destroy = true })
        end
    end

    unregister_mooring(mooring)
end

function mooring_controller.on_rotate(mooring)
    mh.update_proxy_container_inventories(mooring)
end
function mooring_controller.on_flip(mooring)
    mh.flip_horizontal(mooring)
end

function mooring_controller.tick()
    for _, reader_data in pairs(storage.mooring_helper.active_readers) do
        local request_output = mh.get_request_output(reader_data.mooring)

        if request_output == nil then
            request_output = {}
        end

        local drone_task = dt.get(dt.get_current_drone_task_id(reader_data.drone))
        local inventory = reader_data.drone.get_inventory(defines.inventory.car_trunk)

        for i, item in ipairs(drone_task.items) do
            local count = item.count - inventory.get_item_count(item)
            local request = request_output[i]

            if not request then
                request = {}

                request_output[i] = request
            end

            request.name = item.name
            request.quality = item.quality
            request.count = count
        end

        local index = #drone_task.items + 1

        while request_output[index] ~= nil do
            request_output[index] = nil

            index = index + 1
        end

        mh.set_request_output(reader_data.mooring, request_output)
    end
end

return mooring_controller
