
return function()
    for _, surface_buffer in pairs(storage.drone_controller.surfaces) do
        surface_buffer.scheduled_every = {}
        surface_buffer.scheduled_ticks = {}

        for unit_number, drone in pairs(surface_buffer.drones) do
            local properties = storage.managed_entities[drone.unit_number].properties

            properties["tickrate"] = nil
            surface_buffer.scheduled_every[unit_number] = drone
        end
    end
end
