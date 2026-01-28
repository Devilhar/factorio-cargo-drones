
local entity_property = {}

function entity_property.init()
    storage.managed_entities = storage.managed_entities or {}
	storage.managed_entities_queued_for_removal = storage.managed_entities_queued_for_removal or {}

    storage.cargo_drones = storage.cargo_drones or {}
    storage.cargo_drone_provider_mooring = storage.cargo_drone_provider_mooring or {}
    storage.cargo_drone_requester_mooring = storage.cargo_drone_requester_mooring or {}
    storage.cargo_drone_refuel_mooring = storage.cargo_drone_refuel_mooring or {}
end

function entity_property.entity_manage(entity)
	if storage.managed_entities[entity.unit_number] then
		return
	end

	storage.managed_entities[entity.unit_number] = {
		entity = entity,
		properties = {}
	}
	print("Entity managed: " .. entity.unit_number)
end
function entity_property.entity_unmanage(entity_unit_number)
	storage.managed_entities_queued_for_removal[entity_unit_number] = true
	print("Entity queued to unmanage: " .. entity_unit_number)
end

function entity_property.get_managed_entities()
    return storage.managed_entities
end

function entity_property.set_entity_property(entity, property_name, property_value)
    if not storage.managed_entities[entity.unit_number] then
        print("Error; Tried to set entity property on an unmanaged entity.")
    end

    storage.managed_entities[entity.unit_number].properties[property_name] = property_value
end
function entity_property.get_entity_property(entity, property_name)
    if not storage.managed_entities[entity.unit_number] then
        print("Error; Tried to get entity property on an unmanaged entity.")

        return
    end

    return storage.managed_entities[entity.unit_number].properties[property_name]
end
function entity_property.get_entity_properties(entity)
    if not storage.managed_entities[entity.unit_number] then
        print("Error; Tried to get entity properties on an unmanaged entity.")

        return
    end

    return storage.managed_entities[entity.unit_number].properties
end

function entity_property.remove_invalid_entities()
	local invalid_entities = storage.managed_entities_queued_for_removal

	storage.managed_entities_queued_for_removal = {}

    for entity_id, entity_data in pairs(storage.managed_entities) do
		if not entity_data.entity.valid then
			invalid_entities[entity_id] = true
		end
	end

	for entity_id in pairs(invalid_entities) do
		if storage.managed_entities[entity_id] and storage.managed_entities[entity_id].properties["render_obj"] then
			storage.managed_entities[entity_id].properties["render_obj"].destroy()
		end

		storage.managed_entities[entity_id] = nil
		storage.cargo_drones[entity_id] = nil
		storage.cargo_drone_provider_mooring[entity_id] = nil
		storage.cargo_drone_requester_mooring[entity_id] = nil
		storage.cargo_drone_refuel_mooring[entity_id] = nil

		print("Entity unmanaged: " .. entity_id)
	end
end

function entity_property.add_cargo_drone(entity)
	storage.cargo_drones[entity.unit_number] = { entity = entity }
end
function entity_property.add_cargo_drone_provider_mooring(entity)
	storage.cargo_drone_provider_mooring[entity.unit_number] = { entity = entity }
end
function entity_property.add_cargo_drone_requester_mooring(entity)
	storage.cargo_drone_requester_mooring[entity.unit_number] = { entity = entity }
end
function entity_property.add_cargo_drone_refuel_mooring(entity)
	storage.cargo_drone_refuel_mooring[entity.unit_number] = { entity = entity }
end

function entity_property.get_cargo_drones()
	return storage.cargo_drones
end
function entity_property.get_cargo_drone_provider_moorings()
	return storage.cargo_drone_provider_mooring
end
function entity_property.get_cargo_drone_requester_moorings()
	return storage.cargo_drone_requester_mooring
end
function entity_property.get_cargo_drone_refuel_moorings()
	return storage.cargo_drone_refuel_mooring
end

return entity_property
