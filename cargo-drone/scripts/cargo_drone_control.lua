local util = require("util")
local gd = require("scripts.game_debug")
local ep = require("scripts.entity_property")

-- Shamelessly stolen from AAI Programmable Vehicles, because I couldn't be bothered doing it myself
local function vector_to_orientation_xy(x, y)
    if x == 0 then
        if y > 0 then
            return 0.5
        end

        return 0
    end

    if y == 0 then
        if x < 0 then
            return 0.75
        end

        return 0.25
    end

    if y < 0 then
        if x > 0 then
            return math.atan(x / -y) / math.pi / 2
        end
        
        return 1 + math.atan(x / -y) / math.pi / 2
    end

    return 0.5 + math.atan(x / -y) / math.pi / 2
end

-- Shamelessly stolen from AAI Programmable Vehicles, because I couldn't be bothered doing it myself
local function orientation_from_to(a, b)
    return vector_to_orientation_xy(b.x - a.x, b.y - a.y)
end

-- Shamelessly stolen from AAI Programmable Vehicles, because I couldn't be bothered doing it myself
local function orientation_delta_from_to(a, b)
    local da = b - a
    
	if da < -0.5 then
        da = da + 1
    elseif da > 0.5 then
        da = da - 1
    end

    return da
end

local function move_to_position(cargo_drone_entity, target_position)
    local distance_to_target = util.distance(cargo_drone_entity.position, target_position)

    if distance_to_target < 1 then
        if cargo_drone_entity.speed == 0 then
            cargo_drone_entity.riding_state = { acceleration = defines.riding.acceleration.nothing, direction = defines.riding.direction.straight }

            return true
        end

        cargo_drone_entity.riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight }

        return false
    end

    local function orientation_closest_64_cardinal(orientation)
        return math.floor(orientation * 64 + 0.5) / 64
    end

    local target_speed = distance_to_target / 60 / 2
    local target_orientation = orientation_from_to(cargo_drone_entity.position, target_position)

    target_orientation = orientation_closest_64_cardinal(target_orientation)

    local direction = defines.riding.direction.straight
    local acceleration = defines.riding.acceleration.nothing

    local orientation_delta = orientation_delta_from_to(cargo_drone_entity.orientation, target_orientation)
    local min_orientation_delta = math.max(math.min(distance_to_target / 2000 , 0.05), 0.01)

    min_orientation_delta = orientation_closest_64_cardinal(min_orientation_delta)
    local quater_64_cardinal = 1 / 256

    if distance_to_target >= 100 or math.abs(orientation_delta) <= min_orientation_delta + quater_64_cardinal then
        if cargo_drone_entity.speed < target_speed then
            acceleration = defines.riding.acceleration.accelerating
        elseif cargo_drone_entity.speed > target_speed + (1 / 60) then
            acceleration = defines.riding.acceleration.braking
        end
    end

    if orientation_delta < -min_orientation_delta then
        direction = defines.riding.direction.left
    elseif orientation_delta > min_orientation_delta then
        direction = defines.riding.direction.right
    elseif cargo_drone_entity.speed == 0 and acceleration == defines.riding.acceleration.accelerating then
        -- For some reason the drone can't accelerate without ever turning. So just turn for a frame if standing still
        direction = defines.riding.direction.left
    end

    cargo_drone_entity.riding_state = { acceleration = acceleration, direction = direction }
    
    return false
end

local function reset_task(cargo_drone_entity)
    local requester = ep.get_entity_property(cargo_drone_entity, "target_requester")
    local provider  = ep.get_entity_property(cargo_drone_entity, "target_provider")

    if requester and requester.valid then
        ep.set_entity_property(requester, "active_cargo_drone")
        requester.proxy_target_entity = nil
    end
    if provider and provider.valid then
        ep.set_entity_property(provider, "active_cargo_drone")
        provider.proxy_target_entity = nil
    end

    ep.set_entity_property(cargo_drone_entity, "requested_items")
    ep.set_entity_property(cargo_drone_entity, "target_requester")
    ep.set_entity_property(cargo_drone_entity, "target_provider")

    cargo_drone_entity.riding_state = { acceleration = defines.riding.acceleration.braking, direction = defines.riding.direction.straight }
end

local function get_requested_items(requester_entity)
    local requester_signals = requester_entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
    
    if not requester_signals then
        return nil
    end

    local missing_items = {}

    for _, signal in ipairs(requester_signals) do
        if signal.count > 0 and signal.signal.type == nil then
            if not missing_items[signal.signal.name] then
                missing_items[signal.signal.name] = {}
            end

            if type(signal.signal.quality) == "string" then
                missing_items[signal.signal.name][signal.signal.quality] = signal.count
            elseif type(signal.signal.quality) == "table" then
                missing_items[signal.signal.name][signal.signal.quality.name] = signal.count
            else
                missing_items[signal.signal.name]["normal"] = signal.count
            end
        end
    end

    return missing_items
end
local function get_sorted_mooring_list_closest_to_position(mooring_table, position)
    local sorted_requesters = {}

    for id, data in pairs(mooring_table) do
        table.insert(sorted_requesters, { id = id, data = data })
    end

    table.sort(sorted_requesters, function(lhs, rhs)
        return util.distance(position, lhs.data.entity.position) < util.distance(position, rhs.data.entity.position)
    end)

    return sorted_requesters
end
local function has_items_from_request(cargo_drone_entity, request_items)
    local inventory = cargo_drone_entity.get_inventory(defines.inventory.car_trunk)

    if inventory.is_empty() then
        return false
    end

    local stored_items = {}

    for _, item in ipairs(inventory.get_contents()) do
        if item then
            if not stored_items[item.name] then
                stored_items[item.name] = {}
            end
            if not stored_items[item.name][item.quality] then
                stored_items[item.name][item.quality] = 0
            end

            stored_items[item.name][item.quality] = stored_items[item.name][item.quality] + item.count
        end
    end

    for name, quality_and_count in pairs(stored_items) do
        for quality, count in pairs(quality_and_count) do
            if not request_items[name] or not request_items[name][quality] or request_items[name][quality] < count then
                return false
            end
        end
    end

    return true
end
local function get_available_items_for_requested_items(provider_entity, request_items)
    local provider_signals = provider_entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
    
    if not provider_signals then
        return nil
    end

    local provided_items = {}

    for _, signal in ipairs(provider_signals) do
        if signal.count > 0 and signal.signal.type == nil then
            if not provided_items[signal.signal.name] then
                provided_items[signal.signal.name] = {}
            end

            if type(signal.signal.quality) == "string" then
                provided_items[signal.signal.name][signal.signal.quality] = signal.count
            elseif type(signal.signal.quality) == "table" then
                provided_items[signal.signal.name][signal.signal.quality.name] = signal.count
            else
                provided_items[signal.signal.name]["normal"] = signal.count
            end
        end
    end

    local available_items = {}

    for name, quality_and_count in pairs(provided_items) do
        for quality, count in pairs(quality_and_count) do
            if request_items[name] and request_items[name][quality] then
                table.insert(available_items, { name = name, quality = quality, count = math.min(count, request_items[name][quality]) })
            end
        end
    end

    if not available_items[1] then
        return nil
    end

    return available_items
end

local function find_task(cargo_drone_entity, game_tick)
    local requesters = get_sorted_mooring_list_closest_to_position(ep.get_cargo_drone_requester_moorings(), cargo_drone_entity.position)

    for _, requester in ipairs(requesters) do
        if cargo_drone_entity.surface.index ~= requester.data.entity.surface.index then
            goto next_requester
        end

        local active_cargo_drone = ep.get_entity_property(requester.data.entity, "active_cargo_drone")

        if active_cargo_drone and active_cargo_drone.valid then
            goto next_requester
        end

        local next_free_gametick = ep.get_entity_property(requester.data.entity, "next_free_gametick")

        if next_free_gametick ~= nil and next_free_gametick > game_tick then
            goto next_requester
        end

        local requested_items = get_requested_items(requester.data.entity)

        if not requested_items then
            goto next_requester
        end

        local has_requested_items = false

        for _, _ in pairs(requested_items) do has_requested_items = true break end

        if not has_requested_items then
            goto next_requester
        end
        
        if not cargo_drone_entity.get_inventory(defines.inventory.car_trunk).is_empty() then
            if has_items_from_request(cargo_drone_entity, requested_items) then
                ep.set_entity_property(cargo_drone_entity, "target_requester", requester.data.entity)
                ep.set_entity_property(requester.data.entity, "active_cargo_drone", cargo_drone_entity)

                return
            end
            
            goto next_requester
        end

        local providers = get_sorted_mooring_list_closest_to_position(ep.get_cargo_drone_provider_moorings(), requester.data.entity.position)

        for _, provider in ipairs(providers) do
            if cargo_drone_entity.surface.index ~= provider.data.entity.surface.index then
                goto next_provider
            end

            local active_cargo_drone = ep.get_entity_property(provider.data.entity, "active_cargo_drone")

            if active_cargo_drone and active_cargo_drone.valid then
                goto next_provider
            end

            local provider_signals = provider.data.entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

            if not provider_signals then
                goto next_provider
            end

            for _, provider_signal in ipairs(provider_signals) do
                if provider_signal.count > 0 and provider_signal.signal.type == nil then
                    local has_item = false

                    if type(provider_signal.signal.quality) == "string" then
                        has_item = requested_items[provider_signal.signal.name] and requested_items[provider_signal.signal.name][provider_signal.signal.quality]
                    elseif type(provider_signal.signal.quality) == "table" then
                        has_item = requested_items[provider_signal.signal.name] and requested_items[provider_signal.signal.name][provider_signal.signal.quality.name]
                    else
                        has_item = requested_items[provider_signal.signal.name] and requested_items[provider_signal.signal.name]["normal"]
                    end

                    if has_item then
                        local available_items = get_available_items_for_requested_items(provider.data.entity, requested_items)

                        if available_items then
                            local inventory = cargo_drone_entity.get_inventory(defines.inventory.car_trunk)

                            local slots = #inventory
                            local available_items_count = #available_items
                            local items_to_fetch = {}

                            local slot_index = 1
                            local item_index = 1
                            while item_index <= available_items_count and slot_index <= slots do
                                local count = available_items[item_index].count
                                local added = 0
                                local stack_size = prototypes.item[available_items[item_index].name].stack_size
                                while count > 0 and slot_index <= slots do
                                    inventory.set_filter(slot_index, { name = available_items[item_index].name, quality = available_items[item_index].quality })
                                    added = added + math.min(count, stack_size)

                                    count = count - stack_size
                                    slot_index = slot_index + 1
                                end

                                table.insert(items_to_fetch, { name = available_items[item_index].name, quality = available_items[item_index].quality, count = added })
                                item_index = item_index + 1
                            end
                            for i = slot_index, slots do
                                inventory.set_filter(i, { name = "red-wire", quality = "normal" })
                            end

                            ep.set_entity_property(cargo_drone_entity, "requested_items", items_to_fetch)
                            ep.set_entity_property(cargo_drone_entity, "target_requester", requester.data.entity)
                            ep.set_entity_property(cargo_drone_entity, "target_provider", provider.data.entity)
                            ep.set_entity_property(requester.data.entity, "active_cargo_drone", cargo_drone_entity)
                            ep.set_entity_property(provider.data.entity, "active_cargo_drone", cargo_drone_entity)

                            return
                        end
                    end
                end
            end
            
            ::next_provider::
        end

        ::next_requester::
    end
    
    if not cargo_drone_entity.get_inventory(defines.inventory.car_trunk).is_empty() then
        for i = 1, #game.players do
            game.players[i].add_custom_alert(cargo_drone_entity, { type = "virtual", name = "signal-lock" }, { "cargo-drone-alerts.invalid-items" }, true)
        end
    end
end

local function cargo_drone_dock_with_mooring(cargo_drone_entity, mooring_entity, inventory)
    local completed = move_to_position(cargo_drone_entity, mooring_entity.position)

    if not completed then
        return false
    end

    mooring_entity.proxy_target_entity = cargo_drone_entity
    mooring_entity.proxy_target_inventory = inventory

    return true
end

local function tick_refuel(cargo_drone_entity)
    local target_refuel = ep.get_entity_property(cargo_drone_entity, "target_refuel")
    local fuel_inventory = cargo_drone_entity.get_inventory(defines.inventory.fuel)

    if not target_refuel or not target_refuel.valid then
        if fuel_inventory.count_empty_stacks() == 0 then
            ep.set_entity_property(cargo_drone_entity, "target_refuel")

            return true
        end
    end
    
    if fuel_inventory.is_full() then
        if target_refuel and target_refuel.valid then
            target_refuel.proxy_target_entity = nil
            ep.set_entity_property(target_refuel, "active_cargo_drone")
        end
        ep.set_entity_property(cargo_drone_entity, "target_refuel")

        return true
    end

    if not target_refuel or not target_refuel.valid then
        local refuelers = get_sorted_mooring_list_closest_to_position(ep.get_cargo_drone_refuel_moorings(), cargo_drone_entity.position)

        target_refuel = nil

        for _, refueler in ipairs(refuelers) do
            if cargo_drone_entity.surface.index ~= refueler.data.entity.surface.index then
                goto continue
            end

            local active_cargo_drone = ep.get_entity_property(refueler.data.entity, "active_cargo_drone")

            if active_cargo_drone and active_cargo_drone.valid then
                goto continue
            end

            target_refuel = refueler.data.entity
            
            break

            ::continue::
        end
        
        ep.set_entity_property(cargo_drone_entity, "target_refuel", target_refuel)
        if target_refuel then
            ep.set_entity_property(target_refuel, "active_cargo_drone", cargo_drone_entity)
        end

        if not target_refuel then
            return true
        end
    end

    local target_provider = ep.get_entity_property(cargo_drone_entity, "target_provider")
    local target_requester = ep.get_entity_property(cargo_drone_entity, "target_requester")

    if target_provider and target_provider.valid then
        target_provider.proxy_target_entity = nil
    end
    if target_requester and target_requester.valid then
        target_requester.proxy_target_entity = nil
    end

    cargo_drone_dock_with_mooring(cargo_drone_entity, target_refuel, defines.inventory.fuel)

    return false
end
local function tick_provider(cargo_drone_entity)
    local target_provider = ep.get_entity_property(cargo_drone_entity, "target_provider")

    if target_provider then
        if not target_provider.valid then
            reset_task(cargo_drone_entity)

            return false
        end
        
        local target_requester = ep.get_entity_property(cargo_drone_entity, "target_requester")

        if not target_requester or not target_requester.valid then
            reset_task(cargo_drone_entity)

            return false
        end

        local completed = cargo_drone_dock_with_mooring(cargo_drone_entity, target_provider, defines.inventory.car_trunk)

        if not completed then
            return false
        end

        local inventory = cargo_drone_entity.get_inventory(defines.inventory.car_trunk)
        local requested_items = table.deepcopy(ep.get_entity_property(cargo_drone_entity, "requested_items"))

        for i, requested_item in ipairs(requested_items) do
            local has_item = false

            for _, inventory_item in ipairs(inventory.get_contents()) do
                if inventory_item.name == requested_item.name and inventory_item.quality == requested_item.quality then
                    requested_item.count = requested_item.count - inventory_item.count

                    if requested_item.count <= 0 then
                        has_item = true

                        break
                    end
                end
            end

            if not has_item then
                return false
            end
        end

        target_provider.proxy_target_entity = nil
        ep.set_entity_property(target_provider, "active_cargo_drone")
        ep.set_entity_property(cargo_drone_entity, "target_provider")
    end
    
    return true
end
local function tick_requester(cargo_drone_entity, game_tick)
   local target_requester = ep.get_entity_property(cargo_drone_entity, "target_requester")

    if target_requester then
        if not target_requester.valid then
            reset_task(cargo_drone_entity)

            return false
        end

        local completed = cargo_drone_dock_with_mooring(cargo_drone_entity, target_requester, defines.inventory.car_trunk)

        if not completed then
            return false
        end

        if not cargo_drone_entity.get_inventory(defines.inventory.car_trunk).is_empty() then
            return false
        end

        target_requester.proxy_target_entity = nil
        ep.set_entity_property(target_requester, "active_cargo_drone")
        ep.set_entity_property(cargo_drone_entity, "target_requester")
        ep.set_entity_property(target_requester, "next_free_gametick", game_tick + 60)
    end
    
    return true
end

function tick_cargo_drone(cargo_drone_entity, game_tick)
    if cargo_drone_entity.burner.remaining_burning_fuel <= 0 and cargo_drone_entity.burner.inventory.is_empty() then
        for i = 1, #game.players do
            game.players[i].add_custom_alert(cargo_drone_entity, { type = "virtual", name = "signal-fuel" }, { "cargo-drone-alerts.no-fuel" }, true)
        end
    end

    local result = tick_refuel(cargo_drone_entity)

    if not result then
        return
    end

    result = tick_provider(cargo_drone_entity)

    if not result then
        return
    end

    result = tick_requester(cargo_drone_entity, game_tick)

    if not result then
        return
    end

    find_task(cargo_drone_entity, game_tick)
end
