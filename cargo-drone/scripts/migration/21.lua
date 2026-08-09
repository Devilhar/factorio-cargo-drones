
return function()
    for _, surface_buffer in pairs(storage.drone_controller.surfaces) do
        for _, drone in pairs(surface_buffer.drones) do
            local properties = storage.managed_entities[drone.unit_number].properties

            properties["tickrate"] = nil
        end
    end
end
