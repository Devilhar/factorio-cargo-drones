
local ep = require("scripts.entity_property")
local mh = require("scripts.mooring_helper")
local dt = require("scripts.drone_tasks")

local mooring_controller = {}

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

function mooring_controller.on_destroyed_entity(entity)
    local entity_unit_number = entity.unit_number

    if mh.is_mooring(entity_unit_number) then
		mh.mooring_destroyed(entity)
	end

    mh.on_destroyed_entity(entity)
end

return mooring_controller
