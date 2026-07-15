
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

return entity_property
