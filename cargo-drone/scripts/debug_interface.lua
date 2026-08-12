
if not settings.startup["cargo-drone-debug-mode"].value then
    return
end

local ep = require("entity_property")
local dt = require("drone_tasks")

local count_children_recursive = function(parent) return 0 end

count_children_recursive = function(parent)
    local count = 0

    for _, child in pairs(parent) do
        count = count + 1

        if type(child) == "table" then
            count = count + count_children_recursive(child)
        end
    end

    return count
end

-- This interface is used for debugging and is incredibly volatile.
-- Any function here may change in any update for any reason and without warning.
remote.add_interface("cargo-drone-debug", {
    get_next_tick = function(unit_number)
        return ep.get_entity_property_from_unit_number(unit_number, "next_tick") or 0
    end,
    get_storage_info = function()
        local info = {}

        info.value_count = count_children_recursive(storage)

        return info
    end,
    get_drones_info = function()
        local info = {
            count = 0,
            idle_count = 0,
            docked = 0,
            queuing = 0,
            parked = 0,
        }

        for surface_index, surface_buffer in pairs(storage.drone_controller.surfaces) do
            for unit_number, drone in pairs(surface_buffer.drones) do
                if drone.valid then
                    info.count = info.count + 1

                    if ep.get_entity_property(drone, "docked_mooring") then
                        info.docked = info.docked + 1
                    end
                    if ep.get_entity_property(drone, "queuing_mooring") then
                        info.queuing = info.queuing + 1
                    end
                    if ep.get_entity_property(drone, "parked_depot") then
                        info.parked = info.parked + 1
                    end

                    local idle_surface_buffer = storage.drone_tasks.surfaces[surface_index]

                    if idle_surface_buffer and idle_surface_buffer.idle_drones[unit_number] then
                        info.idle_count = info.idle_count + 1
                    end
                end
            end
        end

        return info
    end,
    get_scheduler_info = function()
        local info = {}

        info.state = storage.scheduler.update_state
        info.next_interval = storage.scheduler.last_schedule_tick + settings.global["cargo-drone-min-schedule-interval"].value - game.tick

        return info
    end,
})
