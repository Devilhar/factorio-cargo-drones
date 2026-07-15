
local mooring_types = {
	provider = 1,
	requester = 2,
	refueler = 3
}

local function migrate_drones()
    for _, entity_data in pairs(storage.cargo_drones) do
        local drone = entity_data.entity

        if drone.valid then
            local surface_buffer = storage.drone_controller.surfaces[drone.surface.index]

            if not surface_buffer then
                surface_buffer = {
                    drones = {},
                    drone_count = 0,
                }

                storage.drone_controller.surfaces[drone.surface.index] = surface_buffer
            end

            surface_buffer.drones[drone.unit_number] = drone
            surface_buffer.drone_count = surface_buffer.drone_count + 1
        end
    end
end
local function migrate_moorings(mooring_type, source)
    for _, entity_data in pairs(source) do
        local mooring = entity_data.entity

        if mooring.valid then
            local surface_buffer = storage.mooring_controller.surfaces[mooring.surface.index]

            if not surface_buffer then
                surface_buffer = {
                    [mooring_types.provider] = {},
                    [mooring_types.requester] = {},
                    [mooring_types.refueler] = {},
                }

                storage.mooring_controller.surfaces[mooring.surface.index] = surface_buffer
            end

            surface_buffer[mooring_type][mooring.unit_number] = mooring
        end
    end
end

local function remove_invalid_depots()
    local removed_surfaces = {}

    for surface_index, surface_buffer in pairs(storage.depot_helper.depots) do
        local removed = {}

        for unit_number, depot in pairs(surface_buffer) do
            if not depot.valid then
                table.insert(removed, unit_number)
            end
        end

        for _, unit_number in ipairs(removed) do
            surface_buffer[unit_number] = nil
        end

        if next(surface_buffer) == nil then
            table.insert(removed_surfaces, surface_index)
        end
    end

    for _, surface_index in ipairs(removed_surfaces) do
        storage.depot_helper.surfaces[surface_index] = nil
    end
end

return function()
    storage.drone_controller = storage.drone_controller or {}
    storage.mooring_controller = storage.mooring_controller or {}

    storage.drone_controller.surfaces = storage.drone_controller.surfaces or {}
    storage.mooring_controller.surfaces = storage.mooring_controller.surfaces or {}

    migrate_drones()
    migrate_moorings(mooring_types.provider, storage.cargo_drone_provider_mooring)
    migrate_moorings(mooring_types.requester, storage.cargo_drone_requester_mooring)
    migrate_moorings(mooring_types.refueler, storage.cargo_drone_refuel_mooring)

    storage.scheduler.tickrate_buffer = nil
    storage.cargo_drones = nil
    storage.cargo_drone_provider_mooring = nil
    storage.cargo_drone_requester_mooring = nil
    storage.cargo_drone_refuel_mooring = nil

    storage.deployer_controller = storage.deployer_controller or {}

    storage.deployer_controller.surfaces = storage.deployer_controller.surfaces or {}

    remove_invalid_depots()
end
