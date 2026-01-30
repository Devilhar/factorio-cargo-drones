
local util  = require("util")

local ep    = require("scripts.entity_property")
local dt    = require("scripts.drone_tasks")

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

    local properties = ep.get_entity_properties(drone)

    if properties.task_ids then
        for task_id, _ in pairs(properties.task_ids) do
            local task = dt.get(task_id)

            for item_name, quality_count in pairs(task.items) do
                local selected_item = items[item_name]

                if selected_item then
                    for quality, count in pairs(quality_count) do
                        if selected_item[quality] ~= nil then
                            selected_item[quality] = selected_item[quality] - count
                        end
                    end
                end
            end
        end
    end

    return items
end

local function add_provider_items(provider, provider_items, item_provider_lookup)
    local items = get_items(provider)

    if not items then
        return
    end

    provider_items[provider] = items
    for item_name, quality_count in pairs(items) do
        if not item_provider_lookup[item_name] then
            item_provider_lookup[item_name] = {}
        end

        local selected_item = item_provider_lookup[item_name]

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
local function add_requester_items(requester, out_requesters)
    local items = get_items(requester)

    if not items then
        return
    end

    out_requesters[requester] = items
end

local function get_closest_provider(requester, item_name, item_quality, item_count, item_provider_lookup)
    if not item_provider_lookup[item_name] or not item_provider_lookup[item_name][item_quality] then
        return nil
    end

    local providers = item_provider_lookup[item_name][item_quality]

    local closest_provider = nil
    local closest_distance = 30000000 -- Longer than moving from one corner to the other, and then multiplied by 10 for good measure

    for provider, count in pairs(providers) do
        if provider.surface.index == requester.surface.index then
            local distance = util.distance(provider.position, requester.position)

            if distance < closest_distance then
                closest_provider = provider
                closest_distance = distance
            end
        end
    end

    return closest_provider
end

local function get_common_items(requester, requester_items, selected_provider_items)
    local items = {}

    for item_name, r_quality_count in pairs(requester_items[requester]) do
        for item_quality, r_count in pairs(r_quality_count[item_name]) do
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

-- item_name, item_quality, provider, item_count
local item_provider_lookup = {}
-- requester, item_name, item_quality, item_count
local provider_items = {}
-- requester, item_name, item_quality, item_count
local requester_items = {}

local end_of_requests = false
local key_requester = nil
local key_item_name = nil
local key_item_quality = nil

local function next_request()
    if end_of_requests then
        -- All done. No more. Go away.
        return nil
    end

    local selected_provider = nil

    key_requester = next(requester_items, key_requester)

    while key_requester do
        local selected_requester = requester_items[key_requester]

        key_item_name = next(selected_requester, key_item_name)

        while key_item_name do
            local selected_name = selected_requester[key_item_name]

            key_item_quality = next(selected_name, key_item_quality)

            while key_item_quality do
                local item_count = selected_name[key_item_quality]

                selected_provider = get_closest_provider(key_requester, key_item_name, key_item_quality, item_count, item_provider_lookup)

                if selected_provider then
                    local request = {}

                    request.requester = key_requester
                    request.provider = selected_provider
                    request.items = get_common_items(key_requester, requester_items, provider_items[selected_provider])

                    return request
                end

                key_item_quality = next(selected_name, key_item_quality)
            end

            key_item_name = next(selected_requester, key_item_name)
        end

        key_requester = next(requester_items, key_requester)
    end

    end_of_requests = true

    return nil
end

local item_requests = {}

function item_requests.update_items()
    item_provider_lookup = {}
    provider_items = {}
    requester_items = {}
    end_of_requests = false
    key_requester = nil
    key_item_name = nil
    key_item_quality = nil

    local providers = ep.get_cargo_drone_provider_moorings()
    local requesters = ep.get_cargo_drone_requester_moorings()

    for provider_id, provider_data in pairs(providers) do
        add_provider_items(provider_data.entity, provider_items, item_provider_lookup)
    end
    for requester_id, requester_data in pairs(requesters) do
        add_requester_items(requester_data.entity, requester_items)
    end
end

function item_requests.get_next_item_request()
    return next_request()
end

return item_requests
