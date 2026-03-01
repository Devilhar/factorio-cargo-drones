
local constants = require("scripts.constants")
local ep        = require("scripts.entity_property")

local signal_id_drone_limit     = { type = "virtual", name = "signal-L", quality = "normal" }
local signal_id_priority        = { type = "virtual", name = "signal-P", quality = "normal" }
local signal_id_drone_count     = { type = "virtual", name = "signal-C", quality = "normal" }

local settings_index = {
    drone_limit                     = 1,
    drone_limit_circuit             = 2,
    drone_limit_circuit_signal_id   = 3,
    priority                        = 4,
    priority_circuit                = 5,
    priority_circuit_signal_id      = 6,
    drone_count_circuit             = 7,
    drone_count_signal_id           = 8,
-- Deprecated
--  fuel_inventory                  = 9,
--  fuel_inventory_output           = 10,
--  fuel_inventory_signal_id        = 11,
}
local settings_filter_name = {
    drone_limit                     = "signal-A",
    drone_limit_circuit             = "signal-B",
    drone_limit_circuit_signal_id   = "signal-C",
    priority                        = "signal-D",
    priority_circuit                = "signal-E",
    priority_circuit_signal_id      = "signal-F",
    drone_count_circuit             = "signal-G",
    drone_count_signal_id           = "signal-H",
-- Deprecated
--  fuel_inventory                  = "signal-I",
--  fuel_inventory_output           = "signal-J",
--  fuel_inventory_signal_id        = "signal-K",
}
local section_index = {
    settings                        = 1,
    drone_limit                     = 2,
    priority_circuit                = 3,
    drone_count                     = 4,
-- Deprecated
--  fuel_inventory                  = 5,
    output                          = 6,
    inventory_targets               = 7,
}
local output_index = {
    drone_count                     = 1,
    fuel_inventory                  = 2,
}

local mooring_types = {
	provider = 1,
	requester = 2,
	refueler = 3
}

local mooring_type_lookup = {
	["cargo-drone-mooring-constant-combinator-provider"]    = mooring_types.provider,
	["cargo-drone-mooring-constant-combinator-requester"]   = mooring_types.requester,
	["cargo-drone-mooring-constant-combinator-refueler"]    = mooring_types.refueler,
}

local function get_settings_section(mooring)
    local cb = mooring.get_control_behavior()

    return cb.get_section(section_index.settings)
end

local function set_filter_value(index, filter_name, mooring, value)
    local section = get_settings_section(mooring)

    if value ~= nil then
        section.set_slot(index, {
            value = {
                type = "virtual",
                name = filter_name,
                quality = "normal",
            },
            min = value
        })
    else
        section.clear_slot(index)
    end
end
local function get_filter_value(index, mooring)
    local section = get_settings_section(mooring)

    local filter = section.get_slot(index)

    if not filter then
        return nil
    end

    return filter.min
end

local function set_signal_id(mooring, index, signal_id)
    local section = mooring.get_control_behavior().get_section(index)

    if signal_id ~= nil then
        section.set_slot(1, {
            value = {
                type = signal_id.type,
                name = signal_id.name,
                quality = signal_id.quality or "normal",
            },
            min = 0
        })
    else
        section.clear_slot(1)
    end
end

local function set_drone_limit(mooring, limit)
    set_filter_value(settings_index.drone_limit, settings_filter_name.drone_limit, mooring, limit)
end
local function get_drone_limit(mooring)
    local limit = get_filter_value(settings_index.drone_limit, mooring)

    if limit == nil then
        return nil
    end

    if limit < 0 then
        limit = 0
    end

    return limit
end

local function get_drone_limit_circuit(mooring)
    return get_filter_value(settings_index.drone_limit_circuit, mooring) ~= nil
end
local function set_drone_limit_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.drone_limit_circuit, settings_filter_name.drone_limit_circuit, mooring, 0)
    else
        set_filter_value(settings_index.drone_limit_circuit, settings_filter_name.drone_limit_circuit, mooring, nil)
    end
end

local function get_drone_limit_circuit_signal_id(mooring)
    if get_filter_value(settings_index.drone_limit_circuit_signal_id, mooring) == nil then
        return signal_id_drone_limit
    end

    local section = mooring.get_control_behavior().get_section(section_index.drone_limit)

    return section.get_slot(1).value
end
local function set_drone_limit_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.drone_limit_circuit_signal_id, settings_filter_name.drone_limit_circuit_signal_id, mooring, 0)
    set_signal_id(mooring, section_index.drone_limit, signal_id)
end

local function get_priority(mooring)
    local priority = get_filter_value(settings_index.priority, mooring) or 50

    if priority < 0 then
        priority = 0
    elseif priority > 255 then
        priority = 255
    end

    return priority
end
local function set_priority(mooring, limit)
    set_filter_value(settings_index.priority, settings_filter_name.priority, mooring, limit)
end

local function get_priority_circuit(mooring)
    return get_filter_value(settings_index.priority_circuit, mooring) ~= nil
end
local function set_priority_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.priority_circuit, settings_filter_name.priority_circuit, mooring, 0)
    else
        set_filter_value(settings_index.priority_circuit, settings_filter_name.priority_circuit, mooring, nil)
    end
end

local function get_priority_circuit_signal_id(mooring)
    if get_filter_value(settings_index.priority_circuit_signal_id, mooring) == nil then
        return signal_id_priority
    end

    local section = mooring.get_control_behavior().get_section(section_index.priority_circuit)

    return section.get_slot(1).value
end
local function set_priority_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.priority_circuit_signal_id, settings_filter_name.priority_circuit_signal_id, mooring, 0)
    set_signal_id(mooring, section_index.priority_circuit, signal_id)
end

local function get_drone_count(mooring_unit_number)
    return ep.get_entity_property_from_unit_number(mooring_unit_number, "drone_count") or 0
end
local function set_drone_count(mooring, count)
    if count <= 0 then
        count = nil
    end

    ep.set_entity_property(mooring, "drone_count", count)
end

local function get_drone_count_circuit(mooring)
    return get_filter_value(settings_index.drone_count_circuit, mooring) ~= nil
end
local function set_drone_count_circuit(mooring, flag)
    if flag then
        set_filter_value(settings_index.drone_count_circuit, settings_filter_name.drone_count_circuit, mooring, 0)
    else
        set_filter_value(settings_index.drone_count_circuit, settings_filter_name.drone_count_circuit, mooring, nil)
    end
end

local function get_drone_count_circuit_signal_id(mooring)
    if get_filter_value(settings_index.drone_count_signal_id, mooring) == nil then
        return signal_id_drone_count
    end

    local section = mooring.get_control_behavior().get_section(section_index.drone_count)

    return section.get_slot(1).value
end
local function set_drone_count_circuit_signal_id(mooring, signal_id)
    set_filter_value(settings_index.drone_count_signal_id, settings_filter_name.drone_count_signal_id, mooring, 0)
    set_signal_id(mooring, section_index.drone_count, signal_id)
end

local function update_drone_count_output(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.output)

    if not get_drone_count_circuit(mooring) then
        section.clear_slot(output_index.drone_count)

        return
    end

    local signal_id = get_drone_count_circuit_signal_id(mooring)
    local count = get_drone_count(mooring.unit_number)

    if signal_id == nil or count == 0 then
        section.clear_slot(output_index.drone_count)

        return
    end

    section.set_slot(output_index.drone_count, {
        value = signal_id,
        min = count
    })
end

local function get_inventory_target(mooring, x, y)
    local index = x + (y - 1) * 3
    local section = mooring.get_control_behavior().get_section(section_index.inventory_targets)

    local slot = section.get_slot(index)

    if not slot then
        return nil
    end

    return slot.min
end
local function set_inventory_target(mooring, x, y, target)
    local index = x + (y - 1) * 3
    local section = mooring.get_control_behavior().get_section(section_index.inventory_targets)

    if target ~= nil then
        section.set_slot(index, {
            value = {
                type = "virtual",
                name = "signal-" .. index,
                quality = "normal",
            },
            min = target
        })
    else
        section.clear_slot(index)
    end
end

local function get_rotated_offset(mooring, x, y)
    local rot = math.floor(mooring.orientation * 4 + 0.05) % 4

    x = x - 2
    y = y - 2

    local tmp = x

    if rot == 1 then
        x = y
        y = -tmp
    elseif rot == 2 then
        x = -x
        y = -y
    elseif rot == 3 then
        x = -y
        y = tmp
    end

    x = x + 2
    y = y + 2

    return x, y
end

local function clear_fuel_inventory_output(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.output)

    section.clear_slot(output_index.fuel_inventory)
end

local function get_proxy_container_offset(index)
    return ((index - 1) % 3) + 1, math.floor((index - 1) / 3) + 1
end

local function get_default_inventory_target(mooring)
    if ep.is_refueler_mooring(mooring.unit_number) then
        return defines.inventory.fuel
    end

    return defines.inventory.car_trunk
end

local function update_proxy_container_inventories(mooring)
	local proxy_containers = ep.get_entity_property(mooring, "proxy_containers")
    local default_target_inventory = get_default_inventory_target(mooring)

    for i = 1, 9 do
        local x, y = get_proxy_container_offset(i)

        x, y = get_rotated_offset(mooring, x, y)

        local target_inventory = get_inventory_target(mooring, x, y) or default_target_inventory

        proxy_containers[i].proxy_target_inventory = target_inventory
    end
end

local function clean_settings(mooring)
    local cb = mooring.get_control_behavior()

    while cb.sections_count < 7 do
        cb.add_section()
    end
    while cb.sections_count > 7 do
        cb.remove_section(6)
    end

    for i = 1, 7 do
        local section = cb.get_section(i)

        section.active = false
        section.group = ""
    end

    update_drone_count_output(mooring)
    clear_fuel_inventory_output(mooring)
    update_proxy_container_inventories(mooring)

    cb.get_section(section_index.output).active = true
end

local function flip_horizontal(mooring)
    local a1 = get_inventory_target(mooring, 1, 1)
    local b1 = get_inventory_target(mooring, 1, 2)
    local c1 = get_inventory_target(mooring, 1, 3)
    local a3 = get_inventory_target(mooring, 3, 1)
    local b3 = get_inventory_target(mooring, 3, 2)
    local c3 = get_inventory_target(mooring, 3, 3)

    set_inventory_target(mooring, 1, 1, a3)
    set_inventory_target(mooring, 1, 2, b3)
    set_inventory_target(mooring, 1, 3, c3)
    set_inventory_target(mooring, 3, 1, a1)
    set_inventory_target(mooring, 3, 2, b1)
    set_inventory_target(mooring, 3, 3, c1)
end

local function create_proxy_containers(mooring)
    local proxy_containers = {}

    for i = 1, 9 do
        local x, y = get_proxy_container_offset(i)

        proxy_containers[i] = mooring.surface.create_entity({
            name = "cargo-drone-mooring-proxy-container-" .. x .. "_" .. y,
            position = {
                x = mooring.position.x + x - 2,
                y = mooring.position.y + y - 2
            },
            force = mooring.force,
            create_build_effect_smoke = false,
            raise_built = true,
        })

        if not proxy_containers[i] then
            for _, proxy_container in ipairs(proxy_containers) do
                proxy_container.destroy()
            end

            return nil
        end
    end

    return proxy_containers
end

local mooring_helper = {}

function mooring_helper.clear_deprecated_values(mooring)
	clear_fuel_inventory_output(mooring)
end

function mooring_helper.try_setup_mooring(mooring)
	local mooring_type = mooring_type_lookup[mooring.name]

	if mooring_type == nil then
        -- Not a mooring, no need to react
		return true
	end

    local proxy_containers = create_proxy_containers(mooring)

    if proxy_containers == nil then
        return false
    end

	ep.entity_manage(mooring)

	ep.set_entity_property(mooring, "proxy_containers", proxy_containers)

	script.register_on_object_destroyed(mooring)

	if mooring_type == mooring_types.provider then
		ep.add_cargo_drone_provider_mooring(mooring)
	elseif mooring_type == mooring_types.requester then
		ep.add_cargo_drone_requester_mooring(mooring)

		ep.set_entity_property(mooring, "next_free_gametick", 0)
	else
		ep.add_cargo_drone_refuel_mooring(mooring)
	end

	clean_settings(mooring)

    return true
end

function mooring_helper.migration_create_proxy_containers(mooring)
    local proxy_containers = create_proxy_containers(mooring)

    if proxy_containers == nil then
        error("Cargo drone mooring failed to create proxy containers")
    end

	ep.set_entity_property(mooring, "proxy_containers", proxy_containers)
end

function mooring_helper.on_rotate(mooring)
    update_proxy_container_inventories(mooring)
end

function mooring_helper.on_flip(mooring)
    flip_horizontal(mooring)

    update_proxy_container_inventories(mooring)
end

function mooring_helper.clean_settings(mooring)
    clean_settings(mooring)
end

function mooring_helper.is_drone_limit_enabled(mooring)
    return get_drone_limit(mooring) ~= nil
end
function mooring_helper.set_drone_limit_enabled(mooring, flag)
    if flag then
        set_drone_limit(mooring, 0)
    else
        set_drone_limit(mooring, nil)
    end
end

function mooring_helper.get_drone_limit_value(mooring)
    return get_drone_limit(mooring) or 0
end
function mooring_helper.set_drone_limit_value(mooring, value)
    set_drone_limit(mooring, value)
end

function mooring_helper.is_drone_limit_circuit(mooring)
    return get_drone_limit_circuit(mooring)
end
function mooring_helper.set_drone_limit_circuit(mooring, flag)
    if flag then
        set_drone_limit(mooring, 0)
        set_drone_limit_circuit(mooring, true)
    else
        set_drone_limit_circuit(mooring, false)
    end
end

function mooring_helper.get_drone_limit_circuit_signal_id(mooring)
    return get_drone_limit_circuit_signal_id(mooring)
end
function mooring_helper.set_drone_limit_circuit_signal_id(mooring, signal_id)
    set_drone_limit_circuit_signal_id(mooring, signal_id)
end

function mooring_helper.get_drone_limit(mooring)
    if not get_drone_limit_circuit(mooring) then
        return get_drone_limit(mooring)
    end

    local signal_id = get_drone_limit_circuit_signal_id(mooring)

    if signal_id == nil then
        return 0
    end

    local limit_signal = mooring.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if limit_signal < 0 then
        return 0
    end

    return limit_signal
end

function mooring_helper.get_priority_value(mooring)
    return get_priority(mooring)
end
function mooring_helper.set_priority_value(mooring, value)
    if value < 0 then
        value = 0
    elseif value > 255 then
        value = 255
    end

    set_priority(mooring, value)
end

function mooring_helper.is_priority_circuit(mooring)
    return get_priority_circuit(mooring)
end
function mooring_helper.set_priority_circuit(mooring, flag)
    if flag then
        set_priority(mooring, nil)
        set_priority_circuit(mooring, true)
    else
        set_priority_circuit(mooring, false)
    end
end

function mooring_helper.get_priority_circuit_signal_id(mooring)
    return get_priority_circuit_signal_id(mooring)
end
function mooring_helper.set_priority_circuit_signal_id(mooring, signal_id)
    set_priority_circuit_signal_id(mooring, signal_id)
end

function mooring_helper.get_priority(mooring)
    if not get_priority_circuit(mooring) then
        return get_priority(mooring)
    end

    local signal_id = get_priority_circuit_signal_id(mooring)

    if signal_id == nil then
        return 0
    end

    local priority = mooring.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if priority < 0 then
        return 0
    end

    if priority >= 256 then
        return 255
    end

    return priority
end

function mooring_helper.get_drone_count_value(mooring_unit_number)
    return get_drone_count(mooring_unit_number)
end
function mooring_helper.set_drone_count_value(mooring, value)
    if value < 0 then
        value = 0
    end

    set_drone_count(mooring, value)

    update_drone_count_output(mooring)
end

function mooring_helper.is_drone_count_circuit(mooring)
    return get_drone_count_circuit(mooring)
end
function mooring_helper.set_drone_count_circuit(mooring, flag)
    set_drone_count_circuit(mooring, flag)

    update_drone_count_output(mooring)
end

function mooring_helper.get_drone_count_circuit_signal_id(mooring)
    return get_drone_count_circuit_signal_id(mooring)
end
function mooring_helper.set_drone_count_circuit_signal_id(mooring, signal_id)
    set_drone_count_circuit_signal_id(mooring, signal_id)

    update_drone_count_output(mooring)
end

function mooring_helper.is_at_drone_limit(mooring)
    local drone_limit = mooring_helper.get_drone_limit(mooring)

    if drone_limit == nil then
        return false
    end

    local target_count = get_drone_count(mooring.unit_number)

    return target_count >= drone_limit
end

function mooring_helper.get_inventory_target(mooring, x, y)
    x, y = get_rotated_offset(mooring, x, y)

    return get_inventory_target(mooring, x, y) or get_default_inventory_target(mooring)
end
function mooring_helper.set_inventory_target(mooring, x, y, target)
    x, y = get_rotated_offset(mooring, x, y)

    set_inventory_target(mooring, x, y, target)

    update_proxy_container_inventories(mooring)
end

return mooring_helper
