
local util      = require("util")

local constants = require("constants")
local sf        = require("stack_frame")
local ep        = require("entity_property")
local th        = require("target_helper")
local mh        = require("mooring_helper")
local dt        = require("drone_tasks")

local function get_item_signals(mooring)
    local mooring_signals = mooring.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

    if not mooring_signals then
        return nil
    end

    local items = {}
    local priority = th.get_priority(mooring)

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

    local priority = th.get_priority(mooring)

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

local function get_minimum_item_request_amount(item_name, count, request_mode)
    if request_mode == mh.request_modes.any then
        return 1
    end

    local stack_size = prototypes.item[item_name].stack_size

    if request_mode == mh.request_modes.full then
        return constants.drone_trunk_size * stack_size
    end

    if request_mode == mh.request_modes.stack or count >= stack_size then
        return stack_size
    end

    return count
end

local function get_closest_provider(root_fb, requester, item_name, item_quality, minimum_amount, item_provider_lookup, heuristic_target_count_cost)
    if not item_provider_lookup[item_name] or not item_provider_lookup[item_name][item_quality] then
        return sf.complete, nil
    end

    if root_fb.step == nil then
        root_fb.step = 1
        root_fb.providers = item_provider_lookup[item_name][item_quality]
        root_fb.highest_priority = -1
        root_fb.closest_provider = nil
        root_fb.lowest_cost = constants.max_distance
    end

    if sf.iterate(root_fb.providers, nil, root_fb, function(fb, index, item_data)
        local provider = item_data.mooring

        if item_data.count >= minimum_amount and provider.valid and not th.is_at_drone_limit(provider) then
            if provider.surface.index == requester.surface.index then
                if root_fb.highest_priority <= item_data.priority then
                    local cost = util.distance(provider.position, requester.position) + th.get_drone_count(provider) * heuristic_target_count_cost

                    if root_fb.highest_priority < item_data.priority or cost < root_fb.lowest_cost then
                        root_fb.highest_priority = item_data.priority
                        root_fb.closest_provider = provider
                        root_fb.lowest_cost = cost
                    end
                end
            end
        end

        return sf.continue_and_yield
    end) then
        return sf.status, sf.ret_val
    end

    return sf.complete, root_fb.closest_provider
end

local function get_common_items(root_fb, requester, request_mode, requester_items, selected_provider_items)
    root_fb.items = {}

    sf.iterate(requester_items[requester], nil, root_fb, function(fb, item_name, r_qualities)
        local stack_size = prototypes.item[item_name].stack_size

        sf.iterate(r_qualities, nil, fb, function(fb, item_quality, r_item_data)
            local p_quality_count = selected_provider_items[item_name]

            if not p_quality_count then
                return sf.continue_and_yield
            end

            local p_item_data = p_quality_count[item_quality]

            if p_item_data == nil then
                return sf.continue_and_yield
            end

            local minimum_amount = get_minimum_item_request_amount(item_name, r_item_data.count, request_mode)

            if p_item_data.count < minimum_amount then
                return sf.continue_and_yield
            end

            if not root_fb.items[item_name] then
                root_fb.items[item_name] = {}
            end

            if request_mode == mh.request_modes.full then
                root_fb.items[item_name][item_quality] = minimum_amount

                return sf.continue_and_yield
            end

            local request_amount = math.min(r_item_data.count, p_item_data.count)

            if request_mode == mh.request_modes.stack then
                request_amount = math.ceil(request_amount / stack_size) * stack_size

                if request_amount > p_item_data.count then
                    request_amount = math.floor(p_item_data.count / stack_size) * stack_size
                end
            end

            root_fb.items[item_name][item_quality] = request_amount

            return sf.continue_and_yield
        end)
    end)

    return sf.complete, root_fb.items
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

        frame_buffer = sf.create_buffer()
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
        priority = th.get_priority(mooring),
        requester = mooring
    }

    insert_priority(sorted_requesters, requester_data)
end

function item_requests.get_next_item_request(frame_buffer, surface_buffer, heuristic_target_count_cost)
    if sf.iterate(surface_buffer.sorted_requesters, nil, frame_buffer, function(root_fb, requester_key, requester_data)
        local requester = requester_data.requester

        if not requester.valid then
            return sf.continue_and_yield
        end

        if root_fb.step == nil then
            if th.is_at_drone_limit(requester) then
                return sf.continue_and_yield
            end

            root_fb.step = 1

            root_fb.request_mode = mh.get_request_mode(requester)
            root_fb.requester_items = surface_buffer.requester_items[requester]
        end

        if sf.iterate(root_fb.requester_items, nil, root_fb, function(fb, item_name, qualities)
            if qualities and sf.iterate(qualities, nil, fb, function(fb, item_quality, item_data)
                if fb.step == nil then
                    fb.step = 1
                    fb.minimum_req_amount = 1

                    if root_fb.request_mode == mh.request_modes.full then
                        local stack_size = prototypes.item[item_name].stack_size

                        fb.minimum_req_amount = constants.drone_trunk_size * stack_size
                    end
                end

                if fb.step == 1 then
                    if item_data.count < fb.minimum_req_amount then
                        return sf.continue_and_yield
                    end

                    if fb.minimum_amount == nil then
                        fb.minimum_amount = get_minimum_item_request_amount(item_name, item_data.count, root_fb.request_mode)
                    end

                    if sf.call(fb, get_closest_provider, requester, item_name, item_quality, fb.minimum_amount, surface_buffer.item_provider_lookup, heuristic_target_count_cost) then
                        return sf.status, sf.ret_val
                    end

                    fb.provider = sf.ret_val

                    if not fb.provider then
                        return sf.continue_and_yield
                    end

                    fb.step = 2
                end

                if sf.call(fb, get_common_items, requester, root_fb.request_mode, surface_buffer.requester_items, surface_buffer.provider_items[fb.provider]) then
                    return sf.status, sf.ret_val
                end

                local request = {}

                request.requester = requester
                request.provider = fb.provider
                request.items = sf.ret_val

                return sf.complete, request
            end) then
                return sf.status, sf.ret_val
            end
        end) then
            return sf.status, sf.ret_val
        end
    end) then
        return sf.status, sf.ret_val
    end

    return sf.complete, nil
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

        if requester.valid and not th.is_at_drone_limit(requester) then
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

	local slot_count = constants.drone_trunk_size
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
