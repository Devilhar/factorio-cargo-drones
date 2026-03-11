
local function get_entity_property_from_unit_number(unit_number, property_name)
    if not storage.managed_entities[unit_number] then
        print("Error; Tried to get entity property on an unmanaged entity.")

        return
    end

    return storage.managed_entities[unit_number].properties[property_name]
end
local function get_entity_properties_from_unit_number(unit_number)
    if not storage.managed_entities[unit_number] then
        print("Error; Tried to get entity properties on an unmanaged entity.")

        return
    end

    return storage.managed_entities[unit_number].properties
end

local entity_property = {}

function entity_property.init()
    storage.managed_entities = storage.managed_entities or {}

    storage.cargo_drones = storage.cargo_drones or {}
    storage.cargo_drone_provider_mooring = storage.cargo_drone_provider_mooring or {}
    storage.cargo_drone_requester_mooring = storage.cargo_drone_requester_mooring or {}
    storage.cargo_drone_refuel_mooring = storage.cargo_drone_refuel_mooring or {}
end

function entity_property.remove_invalid_entities()
	local removed = {}

	for unit_number, entity_data in pairs(storage.managed_entities) do
		if not entity_data.entity.valid then
			table.insert(removed, unit_number)
		end
	end

	for _, unit_number in ipairs(removed) do
		storage.managed_entities[unit_number] = nil
		storage.cargo_drones[unit_number] = nil
		storage.cargo_drone_provider_mooring[unit_number] = nil
		storage.cargo_drone_requester_mooring[unit_number] = nil
		storage.cargo_drone_refuel_mooring[unit_number] = nil
	end
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
function entity_property.entity_unmanage(unit_number)
	storage.managed_entities[unit_number] = nil
	storage.cargo_drones[unit_number] = nil
	storage.cargo_drone_provider_mooring[unit_number] = nil
	storage.cargo_drone_requester_mooring[unit_number] = nil
	storage.cargo_drone_refuel_mooring[unit_number] = nil

	print("Entity unmanaged: " .. unit_number)
end
function entity_property.is_managed(unit_number)
	return storage.managed_entities[unit_number] ~= nil
end

function entity_property.get_managed_entity(unit_number)
	if not storage.managed_entities[unit_number] then
		return nil
	end

	return storage.managed_entities[unit_number].entity
end
function entity_property.get_managed_entities()
    return storage.managed_entities
end

function entity_property.is_cargo_drone(unit_number)
	return storage.cargo_drones[unit_number] ~= nil
end
function entity_property.is_provider_mooring(unit_number)
	return storage.cargo_drone_provider_mooring[unit_number] ~= nil
end
function entity_property.is_requester_mooring(unit_number)
	return storage.cargo_drone_requester_mooring[unit_number] ~= nil
end
function entity_property.is_refueler_mooring(unit_number)
	return storage.cargo_drone_refuel_mooring[unit_number] ~= nil
end

function entity_property.set_entity_property(entity, property_name, property_value)
    if not storage.managed_entities[entity.unit_number] then
        print("Error; Tried to set entity property on an unmanaged entity.")
    end

    storage.managed_entities[entity.unit_number].properties[property_name] = property_value
end
function entity_property.get_entity_property(entity, property_name)
    return get_entity_property_from_unit_number(entity.unit_number, property_name)
end
function entity_property.get_entity_property_from_unit_number(unit_number, property_name)
	return get_entity_property_from_unit_number(unit_number, property_name)
end
function entity_property.get_entity_properties(entity)
    return get_entity_properties_from_unit_number(entity.unit_number)
end
function entity_property.get_entity_properties_from_unit_number(unit_number)
    return get_entity_properties_from_unit_number(unit_number)
end

function entity_property.remove_entities(entities)
	for unit_number in pairs(entities) do
		if storage.managed_entities[unit_number] and storage.managed_entities[unit_number].properties["render_obj"] then
			storage.managed_entities[unit_number].properties["render_obj"].destroy()
		end

		storage.managed_entities[unit_number] = nil
		storage.cargo_drones[unit_number] = nil
		storage.cargo_drone_provider_mooring[unit_number] = nil
		storage.cargo_drone_requester_mooring[unit_number] = nil
		storage.cargo_drone_refuel_mooring[unit_number] = nil

		print("Entity unmanaged: " .. unit_number)
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
