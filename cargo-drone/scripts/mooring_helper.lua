
local ep        = require("entity_property")
local fh        = require("filter_helper")
local th        = require("target_helper")

local signal_id_drone_id        = { type = "virtual", name = "signal-T", quality = "normal" }

local setting_names = {
    depot                           = "depot",
    read_requests                   = "read_requests",
    drone_id_circuit                = "drone_id_circuit",
    drone_id_circuit_signal_id      = "drone_id_circuit_signal_id",
    request_mode                    = "request_mode",
}
local settings_filter_name = {
    [setting_names.depot]                       = "signal-L",
    [setting_names.read_requests]               = "signal-M",
    [setting_names.drone_id_circuit]            = "signal-O",
    [setting_names.drone_id_circuit_signal_id]  = "signal-I",
    [setting_names.request_mode]                = "signal-J",
}

local section_index = {
    settings                        = 1,
    inventory_targets               = 7,
    output_requests                 = 8,
    drone_id_output                 = 9,
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

local request_modes = {
    any     = 0,
    stack   = 1,
    fuzzy   = 2,
    full    = 3,
}

local function get_settings_section(mooring)
    local cb = mooring.get_control_behavior()

    return cb.get_section(section_index.settings)
end

local function set_settings_value(mooring, setting_name, value)
    fh.set_filter_value(get_settings_section(mooring), settings_filter_name[setting_name], value)
end
local function get_settings_value(mooring, setting_name)
    return fh.get_filter_value(get_settings_section(mooring), settings_filter_name[setting_name])
end

local function get_read_requests(mooring)
    return get_settings_value(mooring, setting_names.read_requests) ~= nil
end
local function set_read_requests(mooring, flag)
    if flag then
        set_settings_value(mooring, setting_names.read_requests, 0)
    else
        set_settings_value(mooring, setting_names.read_requests, nil)
    end
end

local function unset_request_reader(mooring_unit_number)
    local reader_data = storage.mooring_helper.active_readers[mooring_unit_number]

    if not reader_data then
        return
    end

    if reader_data.mooring.valid then
        ep.set_entity_property(reader_data.mooring, "request_output", nil)
    end

    storage.mooring_helper.active_readers_lookup[mooring_unit_number]              = nil
    storage.mooring_helper.active_readers_lookup[reader_data.drone_unit_number]    = nil

    storage.mooring_helper.active_readers[mooring_unit_number] = nil
end
local function set_request_reader(mooring, drone)
    local unit_number = mooring.unit_number

    unset_request_reader(unit_number)

    storage.mooring_helper.active_readers[unit_number] = {
        mooring             = mooring,
        drone               = drone,
        drone_unit_number   = drone.unit_number,
    }

    storage.mooring_helper.active_readers_lookup[unit_number]       = unit_number
    storage.mooring_helper.active_readers_lookup[drone.unit_number] = unit_number
end

local function update_request_reader(mooring)
    local docked_drone = ep.get_entity_property(mooring, "docked_drone")

    if docked_drone and docked_drone.valid and get_read_requests(mooring) then
        set_request_reader(mooring, docked_drone)
    else
        unset_request_reader(mooring.unit_number)
    end
end
local function update_request_output(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.output_requests)

    local request_output = ep.get_entity_property(mooring, "request_output")

    if request_output == nil or not get_read_requests(mooring) then
        section.filters = {}

        return
    end

    local filters = {}

    for _, item in ipairs(request_output) do
        table.insert(filters, {
            value = {
                name = item.name,
                quality = item.quality,
            },
            min = item.count,
        })
    end

    section.filters = filters
end

local function get_drone_id_circuit(mooring)
    return get_settings_value(mooring, setting_names.drone_id_circuit) ~= nil
end
local function set_drone_id_circuit(mooring, flag)
    if flag then
        set_settings_value(mooring, setting_names.drone_id_circuit, 0)
    else
        set_settings_value(mooring, setting_names.drone_id_circuit, nil)
    end
end

local function get_drone_id(mooring)
    if not get_drone_id_circuit(mooring) then
        return 0
    end

    local drone = ep.get_entity_property(mooring, "docked_drone")

    if not drone or not drone.valid then
        return 0
    end

    return drone.unit_number
end

local function get_drone_id_circuit_signal_id(mooring)
    if get_settings_value(mooring, setting_names.drone_id_circuit_signal_id) == nil then
        return signal_id_drone_id
    end

    local section = mooring.get_control_behavior().get_section(section_index.drone_id_output)

    return section.get_slot(1).value
end
local function set_drone_id_circuit_signal_id(mooring, signal_id)
    set_settings_value(mooring, setting_names.drone_id_circuit_signal_id, 0)
    local section = mooring.get_control_behavior().get_section(section_index.drone_id_output)

    fh.set_signal_id_value(section, signal_id, get_drone_id(mooring))
end

local function update_drone_id_output(mooring)
    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.drone_id_output)

    local signal_id = get_drone_id_circuit_signal_id(mooring)

    if not signal_id then
        return
    end

    local id = get_drone_id(mooring)

    section.filters = {
        {
            value = signal_id,
            min = id
        }
    }
end

local function get_request_mode(mooring)
    return get_settings_value(mooring, setting_names.request_mode) or request_modes.any
end
local function set_request_mode(mooring, request_mode)
    if request_mode == request_modes.any then
        set_settings_value(mooring, setting_names.request_mode, nil)
    else
        set_settings_value(mooring, setting_names.request_mode, request_mode)
    end
end

local function get_inventory_target(mooring, x, y)
    local index = x + (y - 1) * 3
    local section = mooring.get_control_behavior().get_section(section_index.inventory_targets)

    return fh.get_filter_value(section, "signal-" .. index)
end
local function set_inventory_target(mooring, x, y, target)
    local index = x + (y - 1) * 3
    local section = mooring.get_control_behavior().get_section(section_index.inventory_targets)

    fh.set_filter_value(section, "signal-" .. index, target)
end

local function get_rotated_offset(mooring, x, y)
    x = x - 2
    y = y - 2

    local tmp = x
    local direction = mooring.direction

    if direction == defines.direction.east then
        x = y
        y = -tmp
    elseif direction == defines.direction.south then
        x = -x
        y = -y
    elseif direction == defines.direction.west then
        x = -y
        y = tmp
    end

    x = x + 2
    y = y + 2

    return x, y
end
local function get_proxy_container_offset(index)
    return ((index - 1) % 3) + 1, math.floor((index - 1) / 3) + 1
end
local function get_default_inventory_target(mooring)
    if mooring.name == "cargo-drone-mooring-constant-combinator-refueler"
        or (mooring.name == "entity-ghost" and mooring.ghost_name == "cargo-drone-mooring-constant-combinator-refueler") then
        return defines.inventory.fuel
    end

    return defines.inventory.car_trunk
end
local function update_proxy_container_inventories(mooring)
	local proxy_containers = ep.get_entity_property(mooring, "proxy_containers")

    -- Ghost entities have no proxy containers
    if not proxy_containers then
        return
    end

    local default_target_inventory = get_default_inventory_target(mooring)

    for i = 1, 9 do
        local x, y = get_proxy_container_offset(i)

        x, y = get_rotated_offset(mooring, x, y)

        local target_inventory = get_inventory_target(mooring, x, y) or default_target_inventory

        proxy_containers[i].proxy_target_inventory = target_inventory
    end
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

local function resize_and_activate_sections(control_behavior)
    while control_behavior.sections_count < 9 do
        control_behavior.add_section()
    end
    while control_behavior.sections_count > 9 do
        control_behavior.remove_section(10)
    end

    for i = 7, 9 do
        local section = control_behavior.get_section(i)

        section.active = false
        section.group = ""
    end

    control_behavior.get_section(section_index.output_requests).active = true
    control_behavior.get_section(section_index.drone_id_output).active = true
end
local function clear_all_outputs(mooring)
    th.clear_all_outputs(mooring)

    local cb = mooring.get_control_behavior()

    local section = cb.get_section(section_index.output_requests)

    section.filters = {}

    section = cb.get_section(section_index.drone_id_output)

    local signal_filter = section.filters[1]

    if not signal_filter or not signal_filter.value then
        return
    end

    section.filters = {
        {
            value = signal_filter.value,
            min = 0
        }
    }
end
local function clean_settings_all(mooring, mooring_name)
    local cb = mooring.get_control_behavior()

    resize_and_activate_sections(cb)

    th.clean_settings(mooring)

    set_settings_value(mooring, setting_names.depot, nil)
    if mooring_type_lookup[mooring_name] == mooring_types.requester then
        local request_mode = get_request_mode(mooring)

        if request_mode < request_modes.any or request_mode > request_modes.full then
            set_settings_value(mooring, setting_names.request_mode, nil)
        end
    else
        set_settings_value(mooring, setting_names.request_mode, nil)
    end
end
local function clean_settings_ghost(mooring)
    clean_settings_all(mooring, mooring.ghost_name)

    clear_all_outputs(mooring)
end
local function clean_settings(mooring)
    clean_settings_all(mooring, mooring.name)

    if mooring_type_lookup[mooring.name] ~= mooring_types.provider then
        set_read_requests(mooring, false)
    end

    update_drone_id_output(mooring)
    update_request_reader(mooring)
    update_request_output(mooring)
    update_proxy_container_inventories(mooring)
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

local function remove_invalid_moorings()
    local invalid_readers = {}

    for unit_number, active_reader in pairs(storage.mooring_helper.active_readers) do
        if not active_reader.mooring.valid or not active_reader.drone.valid then
            table.insert(invalid_readers, {
                unit_number = unit_number,
                mooring = active_reader.mooring
            })
        end
    end

    for _, data in ipairs(invalid_readers) do
        unset_request_reader(data.unit_number)

        if data.mooring.valid then
            update_request_output(data.mooring)
        end
    end
end

local mooring_helper = {}

mooring_helper.mooring_types = mooring_types
mooring_helper.request_modes = request_modes

function mooring_helper.init()
    storage.mooring_helper = storage.mooring_helper or {}

    storage.mooring_helper.active_readers           = storage.mooring_helper.active_readers or {}
    storage.mooring_helper.active_readers_lookup    = storage.mooring_helper.active_readers_lookup or {}
end

function mooring_helper.surface_deleted(surface_index)
    remove_invalid_moorings()
end
function mooring_helper.surface_cleared(surface_index)
    remove_invalid_moorings()
end

function mooring_helper.clean()
    remove_invalid_moorings()
end

function mooring_helper.is_name_mooring(name)
    return mooring_type_lookup[name] ~= nil
end
function mooring_helper.get_mooring_type(mooring)
    return mooring_type_lookup[mooring.name]
end

function mooring_helper.clean_settings(mooring)
    clean_settings(mooring)
end
function mooring_helper.clean_settings_ghost(mooring)
    clean_settings_ghost(mooring)
end

function mooring_helper.flip_horizontal(mooring)
    flip_horizontal(mooring)
end

function mooring_helper.create_proxy_containers(mooring)
    return create_proxy_containers(mooring)
end
function mooring_helper.update_proxy_container_inventories(mooring)
    update_proxy_container_inventories(mooring)
end

function mooring_helper.on_destroyed_entity(entity)
    local mooring_unit_number = storage.mooring_helper.active_readers_lookup[entity.unit_number]

    if mooring_unit_number == nil then
        return
    end

    local mooring = ep.get_managed_entity(mooring_unit_number)

    if not mooring or not mooring.valid then
        return
    end

    unset_request_reader(mooring.unit_number)

    update_request_output(mooring)
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
function mooring_helper.get_inventory_target_absolute(mooring, x, y)
    return get_inventory_target(mooring, x, y) or get_default_inventory_target(mooring)
end
function mooring_helper.set_inventory_target_absolute(mooring, x, y, target)
    set_inventory_target(mooring, x, y, target)

    update_proxy_container_inventories(mooring)
end

function mooring_helper.get_request_output(mooring)
    return ep.get_entity_property(mooring, "request_output")
end
function mooring_helper.set_request_output(mooring, request_output)
    ep.set_entity_property(mooring, "request_output", request_output)

    update_request_output(mooring)
end

function mooring_helper.get_read_requests(mooring)
    return get_read_requests(mooring)
end
function mooring_helper.set_read_requests(mooring, flag)
    set_read_requests(mooring, flag)

    update_request_reader(mooring)
    update_request_output(mooring)
end

function mooring_helper.set_request_reader(mooring, drone)
    set_request_reader(mooring, drone)

    update_request_reader(mooring)
    update_request_output(mooring)
end
function mooring_helper.unset_request_reader(mooring)
    unset_request_reader(mooring.unit_number)

    update_request_output(mooring)
end

function mooring_helper.remove_depot_flag(mooring)
    set_settings_value(mooring, setting_names.depot, nil)
end
function mooring_helper.has_depot_flag(mooring)
    return get_settings_value(mooring, setting_names.depot) ~= nil
end

function mooring_helper.get_docked_drone(mooring)
    return ep.get_entity_property(mooring, "docked_drone")
end
function mooring_helper.set_docked_drone(mooring, drone)
    ep.set_entity_property(mooring, "docked_drone", drone)

    update_drone_id_output(mooring)
end

function mooring_helper.get_drone_id_circuit(mooring)
    return get_drone_id_circuit(mooring)
end
function mooring_helper.set_drone_id_circuit(mooring, flag)
    set_drone_id_circuit(mooring, flag)

    update_drone_id_output(mooring)
end

function mooring_helper.get_drone_id_circuit_signal_id(mooring)
    return get_drone_id_circuit_signal_id(mooring)
end
function mooring_helper.set_drone_id_circuit_signal_id(mooring, signal_id)
    set_drone_id_circuit_signal_id(mooring, signal_id)
end

function mooring_helper.get_request_mode(mooring)
    return get_request_mode(mooring)
end
function mooring_helper.set_request_mode(mooring, request_mode)
    set_request_mode(mooring, request_mode)
end

return mooring_helper
