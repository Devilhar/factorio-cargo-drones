
local util  = require("util")

local ep    = require("scripts.entity_property")
local dt    = require("scripts.drone_tasks")
local rc    = require("scripts.requester_cooldown")

local max_scans_per_tick = 10

local function get_item_signals(requester)
    local requester_signals = requester.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if not requester_signals then
        return nil
    end

    local requested_items = {}

    for _, signal in ipairs(requester_signals) do
        if signal.count > 0 and signal.signal.type == nil then
            if not requested_items[signal.signal.name] then
                requested_items[signal.signal.name] = {}
            end

            if type(signal.signal.quality) == "string" then
                requested_items[signal.signal.name][signal.signal.quality] = signal.count
            elseif type(signal.signal.quality) == "table" then
                requested_items[signal.signal.name][signal.signal.quality.name] = signal.count
            else
                requested_items[signal.signal.name]["normal"] = signal.count
            end
        end
    end

    return requested_items
end

local function get_items(mooring)
    local items = get_item_signals(mooring)

    if not items then
        return nil
    end

    local properties = ep.get_entity_properties(mooring)

    if properties.task_ids then
        for task_id, _ in pairs(properties.task_ids) do
            local task = dt.get(task_id)

            for i, item_data in ipairs(task.items) do
                local selected_item = items[item_data.name]

                if selected_item then
                    if selected_item[item_data.quality] ~= nil then
                        selected_item[item_data.quality] = selected_item[item_data.quality] - item_data.count

                        if selected_item[item_data.quality] <= 0 then
                            selected_item[item_data.quality] = nil

                            if next(items) == nil then
                                return nil
                            end
                        end
                    end
                end
            end
        end
    end

    return items
end

local function add_items(provider, mooring_items, item_mooring_lookup)
    local items = get_items(provider)

    if not items then
        return
    end

    mooring_items[provider] = items
    for item_name, quality_count in pairs(items) do
        if not item_mooring_lookup[item_name] then
            item_mooring_lookup[item_name] = {}
        end

        local selected_item = item_mooring_lookup[item_name]

        for quality, count in pairs(quality_count) do
            if count > 0 then
                if not selected_item[quality] then
                    selected_item[quality] = {}
                end

                selected_item[quality][provider] = count 
            end
        end
    end
end

local function get_closest_provider(requester, item_name, item_quality, item_provider_lookup)
    if not item_provider_lookup[item_name] or not item_provider_lookup[item_name][item_quality] then
        return nil
    end

    local providers = item_provider_lookup[item_name][item_quality]

    local closest_provider = nil
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for provider, count in pairs(providers) do
        if count > 0 and provider.valid and not dt.is_at_target_limit(provider) then
            if provider.surface.index == requester.surface.index then
                local distance = util.distance(provider.position, requester.position)

                if distance < closest_distance then
                    closest_provider = provider
                    closest_distance = distance
                end
            end
        end
    end

    return closest_provider
end

local function get_common_items(requester, requester_items, selected_provider_items)
    local items = {}

    for item_name, r_quality_count in pairs(requester_items[requester]) do
        for item_quality, r_count in pairs(r_quality_count) do
            local p_quality_count = selected_provider_items[item_name]

            if not p_quality_count then
                goto continue
            end

            local p_count = p_quality_count[item_quality]

            if p_count == nil or p_count <= 0 then
                goto continue
            end

            if not items[item_name] then
                items[item_name] = {}
            end

            items[item_name][item_quality] = math.min(r_count, p_count)

            ::continue::
        end
    end

    return items
end

local update_stage = 0

local surface_buffer = {}
local provider_buffer = {}
local requester_buffer = {}

local buffer_key = nil

local function try_create_and_get_surface_buffer(surface_index)
    if not surface_buffer[surface_index] then
        surface_buffer[surface_index] = {
            -- item_name, item_quality, provider, item_count
            item_provider_lookup = {},
            -- provider, item_name, item_quality, item_count
            provider_items = {},
            -- item_name, item_quality, requester, item_count
            item_requester_lookup = {},
            -- requester, item_name, item_quality, item_count
            requester_items = {},

            end_of_requests = false,
            key_requester = nil,
            key_item_name = nil,
            key_item_quality = nil
        }
    end

    return surface_buffer[surface_index]
end

local function transfer_items_in_buffer(provider, requester, items)
    local sb_provider = try_create_and_get_surface_buffer(provider.surface.index)
    local sb_requester = try_create_and_get_surface_buffer(requester.surface.index)

    for _, item in ipairs(items) do
        sb_provider.item_provider_lookup[item.name][item.quality][provider] = sb_provider.item_provider_lookup[item.name][item.quality][provider] - item.count
        sb_provider.provider_items[provider][item.name][item.quality]       = sb_provider.provider_items[provider][item.name][item.quality] - item.count
        sb_requester.requester_items[requester][item.name][item.quality]    = sb_requester.requester_items[requester][item.name][item.quality] - item.count
    end
end

local function requester_has_item_requests(items, requester_items)
    for _, item in ipairs(items) do
        -- Being extra strict, so that it doesn't overstock somewhere by mistake. Could be an issue for more expensive items
        -- Probably better to just notify the player than hide them somewhere in the network.
        if not requester_items[item.name]
            or not requester_items[item.name][item.quality]
            or requester_items[item.name][item.quality] < item.count then
            return false
        end
    end

    return true
end

local item_requests = {}

function item_requests.begin_update()
    update_stage = 0

    surface_buffer = {}
    provider_buffer = {}
    requester_buffer = {}

    buffer_key = nil

    local providers = ep.get_cargo_drone_provider_moorings()
    local requesters = ep.get_cargo_drone_requester_moorings()

    for provider_id, provider_data in pairs(providers) do
        provider_buffer[provider_id] = provider_data.entity
    end
    for requester_id, requester_data in pairs(requesters) do
        requester_buffer[requester_id] = requester_data.entity
    end
end

function item_requests.run_update()
    local scans = 0

    if update_stage == 0 then
        local provider = nil

        repeat
            buffer_key, provider = next(provider_buffer, buffer_key)

            if not buffer_key then
                break
            end

            if provider.valid then
                local sb = try_create_and_get_surface_buffer(provider.surface.index)

                add_items(provider, sb.provider_items, sb.item_provider_lookup)
            end

            scans = scans + 1
        until scans >= max_scans_per_tick

        if buffer_key == nil then
            update_stage = 1
        end
    end

    if update_stage == 0 then
        return false
    end

    if scans >= max_scans_per_tick then
        return false
    end

    local requester = nil

    repeat
        buffer_key, requester = next(requester_buffer, buffer_key)

        if not buffer_key then
            break
        end

        if requester.valid then
            if not rc.is_on_cooldown(buffer_key) then
                local sb = try_create_and_get_surface_buffer(requester.surface.index)

                add_items(requester, sb.requester_items, sb.item_requester_lookup)
            end
        end

        scans = scans + 1
    until scans >= max_scans_per_tick

    return buffer_key == nil
end

function item_requests.get_next_item_request(surface_index)
    local sb = surface_buffer[surface_index]

    if not sb then
        return nil
    end

    if sb.end_of_requests then
        -- All done. No more. Go away.
        return nil
    end

    local selected_provider = nil

    local old_key_requester = sb.key_requester
    local old_key_item_name = sb.key_item_name
    local old_key_item_quality = sb.key_item_quality

    sb.key_requester = next(sb.requester_items, sb.key_requester)

    while sb.key_requester do
        if sb.key_requester.valid and not dt.is_at_target_limit(sb.key_requester) then
            local selected_requester = sb.requester_items[sb.key_requester]

            sb.key_item_name = next(selected_requester, sb.key_item_name)

            while sb.key_item_name do
                local selected_name = selected_requester[sb.key_item_name]

                sb.key_item_quality = next(selected_name, sb.key_item_quality)

                while sb.key_item_quality do
                    local item_count = selected_name[sb.key_item_quality]

                    if item_count > 0 then
                        selected_provider = get_closest_provider(sb.key_requester, sb.key_item_name, sb.key_item_quality, sb.item_provider_lookup)

                        if selected_provider then
                            local request = {}

                            request.requester = sb.key_requester
                            request.provider = selected_provider
                            request.items = get_common_items(sb.key_requester, sb.requester_items, sb.provider_items[selected_provider])

                            sb.key_requester = old_key_requester
                            sb.key_item_name = old_key_item_name
                            sb.key_item_quality = old_key_item_quality

                            return request
                        end
                    end

                    sb.key_item_quality = next(selected_name, sb.key_item_quality)
                end

                sb.key_item_name = next(selected_requester, sb.key_item_name)
            end
        end

        sb.key_requester = next(sb.requester_items, sb.key_requester)
    end

    sb.end_of_requests = true

    return nil
end

function item_requests.assign_to_request_with_items(drone)
    local inventory = drone.get_inventory(defines.inventory.car_trunk)

    local items = inventory.get_contents()

    local first_item = items[1]

    if not first_item then
        return
    end

    local sb = surface_buffer[drone.surface.index]

    if not sb then
        return
    end

    if not sb.item_requester_lookup[first_item.name]
        or not sb.item_requester_lookup[first_item.name][first_item.quality] then
        return
    end

    local selected_requester = nil

    for requester, _ in pairs(sb.item_requester_lookup[first_item.name][first_item.quality]) do
        if requester.valid and not dt.is_at_target_limit(requester) then
            if requester_has_item_requests(items, sb.requester_items[requester]) then
                selected_requester = requester
            end
        end
    end

    if not selected_requester then
        return
    end

    local inventory_filters = {}

    for slot_index = 1, #inventory do
        local item_stack = inventory[slot_index]

        if item_stack.valid_for_read then
            inventory_filters[slot_index] = { name = item_stack.name, quality = item_stack.quality }
            inventory.set_filter(slot_index, { name = item_stack.name, quality = item_stack.quality })
        else
            inventory.set_filter(slot_index, { name = "red-wire", quality = "normal" })
        end
    end

	dt.assign_cargo(drone, nil, selected_requester, items, inventory_filters)

    local sb_requester = try_create_and_get_surface_buffer(selected_requester.surface.index)

    for _, item in ipairs(items) do
        sb_requester.requester_items[selected_requester][item.name][item.quality] = sb_requester.requester_items[selected_requester][item.name][item.quality] - item.count
    end
end

function item_requests.assign_item_request(drone, item_request)
	local inventory = drone.get_inventory(defines.inventory.car_trunk)

	local slot_count = #inventory
	local items_to_fetch = {}
	local inventory_filters = {}

	local slot_index = 1

	local item_name, quality_count = next(item_request.items)
	local item_quality, count = nil, 0

	if quality_count then
		item_quality, count = next(quality_count)
	end

	while item_name ~= nil and slot_index <= slot_count do
		local added = 0
		local stack_size = prototypes.item[item_name].stack_size

		while count > 0 and slot_index <= slot_count do
			inventory_filters[slot_index] = { name = item_name, quality = item_quality }
            inventory.set_filter(slot_index, { name = item_name, quality = item_quality })
			added = added + math.min(count, stack_size)

			count = count - stack_size
			slot_index = slot_index + 1
		end

		table.insert(items_to_fetch, { name = item_name, quality = item_quality, count = added })

		item_quality, count = next(quality_count, item_quality)

		if item_quality == nil then
			item_name, quality_count = next(item_request.items, item_name)

			if quality_count ~= nil then
				item_quality, count = next(quality_count)
			end
		end
	end

    for i = slot_index, slot_count do
        inventory.set_filter(i, { name = "red-wire", quality = "normal" })
    end

	transfer_items_in_buffer(item_request.provider, item_request.requester, items_to_fetch)
	dt.assign_cargo(drone, item_request.provider, item_request.requester, items_to_fetch, inventory_filters)
end

return item_requests
