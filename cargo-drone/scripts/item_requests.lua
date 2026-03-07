
local util      = require("util")

local constants = require("scripts.constants")
local ep        = require("scripts.entity_property")
local mh        = require("scripts.mooring_helper")
local dt        = require("scripts.drone_tasks")

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

local function remove_items(items, items_to_remove, mul)
    for i, item_data in ipairs(items_to_remove) do
        local selected_item = items[item_data.name]

        if selected_item then
            local selected_quality = selected_item[item_data.quality]

            if selected_quality then
                selected_quality.count = selected_quality.count - item_data.count * mul

                if selected_quality.count <= 0 then
                    selected_item[item_data.quality] = nil

                    if next(selected_item) == nil then
                        items[item_data.name] = nil

                        if next(items) == nil then
                            return false
                        end
                    end
                end
            end
        end
    end

    return true
end

local function remove_requested_items(mooring, items)
    local properties = ep.get_entity_properties(mooring)

    if properties.task_ids then
        for task_id, _ in pairs(properties.task_ids) do
            local task = dt.get(task_id)

            if task.items then
                if not remove_items(items, task.items, 1) then
                    return false
                end
            end
        end
    end

    return true
end
local function remove_request_output(mooring, items)
    local request_output = mh.get_request_output(mooring)

    if request_output ~= nil then
        local mul = 0

        if mooring.get_circuit_network(defines.wire_connector_id.circuit_red) ~= nil then
            mul = mul + 1
        end
        if mooring.get_circuit_network(defines.wire_connector_id.circuit_green) ~= nil then
            mul = mul + 1
        end

        if mul > 0 then
            if not remove_items(items, request_output, mul) then
                return false
            end
        end
    end

    return true
end

local function get_items(mooring)
    local items = get_item_signals(mooring)

    if not items then
        return nil
    end

    if not remove_requested_items(mooring, items) then
        return nil
    end

    if not remove_request_output(mooring, items) then
        return nil
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

local function get_closest_provider(requester, item_name, item_quality, item_provider_lookup, heuristic_target_count_cost)
    if not item_provider_lookup[item_name] or not item_provider_lookup[item_name][item_quality] then
        return nil
    end

    local providers = item_provider_lookup[item_name][item_quality]

    local highest_priority = -1
    local closest_provider = nil
    local lowest_cost = constants.max_distance

    for _, item_data in ipairs(providers) do
        local provider = item_data.mooring

        if item_data.count > 0 and provider.valid and not mh.is_at_drone_limit(provider) then
            if provider.surface.index == requester.surface.index then
                if highest_priority <= item_data.priority then
                    local cost = util.distance(provider.position, requester.position) + mh.get_drone_count(provider.unit_number) * heuristic_target_count_cost

                    if highest_priority < item_data.priority or cost < lowest_cost then
                        highest_priority = item_data.priority
                        closest_provider = provider
                        lowest_cost = cost
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

local function transfer_items_in_buffer(surface_buffer, provider, requester, items)
    local provider_items = surface_buffer.provider_items[provider]
    local requester_items = surface_buffer.requester_items[requester]

    for _, item in ipairs(items) do
        local provider_item_data = provider_items[item.name][item.quality]
        local requester_item_data = requester_items[item.name][item.quality]

        provider_item_data.count   = provider_item_data.count - item.count
        requester_item_data.count  = requester_item_data.count - item.count

        if requester_item_data.count <= 0 then
            requester_items[item.name][item.quality] = nil

            if next(requester_items[item.name]) == nil then
                requester_items[item.name] = nil
            end
        end
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

function item_requests.create_surface_buffer()
    return {
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

function item_requests.add_items_to_provider(mooring, mooring_items, item_mooring_lookup)
    add_items(mooring, mooring_items, item_mooring_lookup)
end
function item_requests.add_items_to_requester(mooring, mooring_items, item_mooring_lookup, sorted_requesters)
    local has_items = add_items(mooring, mooring_items, item_mooring_lookup)

    if not has_items then
        return false
    end

    local requester_data = {
        priority = mh.get_priority(mooring),
        requester = mooring
    }

    insert_priority(sorted_requesters, requester_data)
end

function item_requests.get_next_item_request(surface_buffer, heuristic_target_count_cost)
    local sb = surface_buffer

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
        
        if selected_requester.valid and not mh.is_at_drone_limit(selected_requester) then
            local requester_items = sb.requester_items[selected_requester]

            sb.key_item_name = next(requester_items, sb.key_item_name)

            while sb.key_item_name do
                local selected_name = requester_items[sb.key_item_name]

                sb.key_item_quality = next(selected_name, sb.key_item_quality)

                while sb.key_item_quality do
                    local item_data = selected_name[sb.key_item_quality]

                    if item_data.count > 0 then
                        selected_provider = get_closest_provider(selected_requester, sb.key_item_name, sb.key_item_quality, sb.item_provider_lookup, heuristic_target_count_cost)

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

function item_requests.assign_to_request_with_items(surface_buffer, drone)
    local inventory = drone.get_inventory(defines.inventory.car_trunk)

    local items = inventory.get_contents()

    local first_item = items[1]

    if not first_item then
        return
    end

    local sb = surface_buffer

    if not sb.item_requester_lookup[first_item.name]
        or not sb.item_requester_lookup[first_item.name][first_item.quality] then
        return
    end

    local selected_requester = nil

    for _, item_data in ipairs(sb.item_requester_lookup[first_item.name][first_item.quality]) do
        local requester = item_data.mooring

        if requester.valid and not mh.is_at_drone_limit(requester) then
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

    for _, item in ipairs(items) do
        local item_data = surface_buffer.requester_items[selected_requester][item.name][item.quality]

        item_data.count = item_data.count - item.count
    end
end

function item_requests.assign_item_request(surface_buffer, drone, item_request)
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

	transfer_items_in_buffer(surface_buffer, item_request.provider, item_request.requester, items_to_fetch)
	dt.assign_cargo(drone, item_request.provider, item_request.requester, items_to_fetch, inventory_filters)
end

return item_requests
