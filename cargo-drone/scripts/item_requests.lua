
local util  = require("util")

local ep    = require("scripts.entity_property")
local mh    = require("scripts.mooring_helper")
local dt    = require("scripts.drone_tasks")
local rc    = require("scripts.requester_cooldown")

local max_scans_per_tick = 10

local function get_item_signals(mooring)
    local mooring_signals = mooring.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if not mooring_signals then
        return nil
    end

    local items = {}
    local priority = mh.get_priority(mooring)

    for _, signal in ipairs(mooring_signals) do
        if signal.count > 0 and signal.signal.type == nil then
            if not items[signal.signal.name] then
                items[signal.signal.name] = {}
            end

            local item_data = {
                count = signal.count,
                priority = priority,
                mooring = mooring
            }

            if type(signal.signal.quality) == "string" then
                items[signal.signal.name][signal.signal.quality] = item_data
            elseif type(signal.signal.quality) == "table" then
                items[signal.signal.name][signal.signal.quality.name] = item_data
            else
                items[signal.signal.name]["normal"] = item_data
            end
        end
    end

    return items
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
                        local selected_quality = selected_item[item_data.quality]

                        selected_quality.count = selected_quality.count - item_data.count

                        if selected_quality.count <= 0 then
                            selected_quality = nil

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

local function insert_priority(sorted_moorings, element_data)
    local length = #sorted_moorings

    local lower = 1
    local upper = length
    local middle = 0

    while lower <= upper do
        middle = math.floor((lower + upper) / 2)

        if sorted_moorings[middle].priority == element_data.priority then
            lower = middle + 1
        elseif sorted_moorings[middle].priority > element_data.priority then
            lower = middle + 1
        else
            upper = middle - 1
        end
    end

    if lower == length and sorted_moorings[lower].priority >= element_data.priority then
        table.insert(sorted_moorings, element_data)
    else
        table.insert(sorted_moorings, lower, element_data)
    end
end

local function add_items(mooring, mooring_items, item_mooring_lookup)
    local items = get_items(mooring)

    if not items then
        return false
    end

    local priority = mh.get_priority(mooring)

    mooring_items[mooring] = items
    for item_name, item_quality in pairs(items) do
        if not item_mooring_lookup[item_name] then
            item_mooring_lookup[item_name] = {}
        end

        local selected_item = item_mooring_lookup[item_name]

        for quality, item_data in pairs(item_quality) do
            if item_data.count > 0 then
                if not selected_item[quality] then
                    selected_item[quality] = {}
                end

                item_data.priority = priority

                insert_priority(selected_item[quality], item_data)
            end
        end
    end

    return true
end

local function get_closest_provider(requester, item_name, item_quality, item_provider_lookup)
    if not item_provider_lookup[item_name] or not item_provider_lookup[item_name][item_quality] then
        return nil
    end

    local providers = item_provider_lookup[item_name][item_quality]

    local highest_priority = -1
    local closest_provider = nil
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for _, item_data in ipairs(providers) do
        local provider = item_data.mooring

        if item_data.count > 0 and provider.valid and not dt.is_at_target_limit(provider) then
            if provider.surface.index == requester.surface.index then
                if highest_priority <= item_data.priority then
                    local distance = util.distance(provider.position, requester.position)

                    if highest_priority < item_data.priority or distance < closest_distance then
                        highest_priority = item_data.priority
                        closest_provider = provider
                        closest_distance = distance
                    end
                end
            end
        end
    end

    return closest_provider
end

local function get_common_items(requester, requester_items, selected_provider_items)
    local items = {}

    for item_name, r_quality in pairs(requester_items[requester]) do
        for item_quality, r_item_data in pairs(r_quality) do
            local p_quality_count = selected_provider_items[item_name]

            if not p_quality_count then
                goto continue
            end

            local p_item_data = p_quality_count[item_quality]

            if p_item_data == nil or p_item_data.count <= 0 then
                goto continue
            end

            if not items[item_name] then
                items[item_name] = {}
            end

            items[item_name][item_quality] = math.min(r_item_data.count, p_item_data.count)

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
            -- item_name, item_quality, index, { count, priority, mooring }
            item_provider_lookup = {},
            -- provider, item_name, item_quality, { count, priority, mooring }
            provider_items = {},

            -- item_name, item_quality, index, { count, priority, mooring }
            item_requester_lookup = {},
            -- requester, item_name, item_quality, { count, priority, mooring }
            requester_items = {},
            -- index, { priority, requester }
            sorted_requesters = {},

            end_of_requests = false,
            key_index = nil,
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
        sb_provider.provider_items[provider][item.name][item.quality].count     = sb_provider.provider_items[provider][item.name][item.quality].count - item.count
        sb_requester.requester_items[requester][item.name][item.quality].count  = sb_requester.requester_items[requester][item.name][item.quality].count - item.count
    end
end

local function requester_has_item_requests(items, requester_items)
    for _, item in ipairs(items) do
        -- Being extra strict, so that it doesn't overstock somewhere by mistake. Could be an issue for more expensive items
        -- Probably better to just notify the player than hide them somewhere in the network.
        if not requester_items[item.name]
            or not requester_items[item.name][item.quality]
            or requester_items[item.name][item.quality].count < item.count then
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

                local has_items = add_items(requester, sb.requester_items, sb.item_requester_lookup)

                if has_items then
                    local requester_data = {
                        priority = mh.get_priority(requester),
                        requester = requester
                    }

                    insert_priority(sb.sorted_requesters, requester_data)
                end
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

    local selected_requester = nil
    local selected_provider = nil

    local old_key_index = sb.key_index
    local old_key_item_name = sb.key_item_name
    local old_key_item_quality = sb.key_item_quality

    sb.key_index = next(sb.sorted_requesters, sb.key_index)

    while sb.key_index do
        selected_requester = sb.sorted_requesters[sb.key_index].requester
        
        if selected_requester.valid and not dt.is_at_target_limit(selected_requester) then
            local requester_items = sb.requester_items[selected_requester]

            sb.key_item_name = next(requester_items, sb.key_item_name)

            while sb.key_item_name do
                local selected_name = requester_items[sb.key_item_name]

                sb.key_item_quality = next(selected_name, sb.key_item_quality)

                while sb.key_item_quality do
                    local item_data = selected_name[sb.key_item_quality]

                    if item_data.count > 0 then
                        selected_provider = get_closest_provider(selected_requester, sb.key_item_name, sb.key_item_quality, sb.item_provider_lookup)

                        if selected_provider then
                            local request = {}

                            request.requester = selected_requester
                            request.provider = selected_provider
                            request.items = get_common_items(selected_requester, sb.requester_items, sb.provider_items[selected_provider])

                            sb.key_index = old_key_index
                            sb.key_item_name = old_key_item_name
                            sb.key_item_quality = old_key_item_quality

                            return request
                        end
                    end

                    sb.key_item_quality = next(selected_name, sb.key_item_quality)
                end

                sb.key_item_name = next(requester_items, sb.key_item_name)
            end
        end

        sb.key_index = next(sb.sorted_requesters, sb.key_index)
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

    for _, item_data in ipairs(sb.item_requester_lookup[first_item.name][first_item.quality]) do
        local requester = item_data.mooring

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
        local item_data = sb_requester.requester_items[selected_requester][item.name][item.quality]

        item_data.count = item_data.count - item.count
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
