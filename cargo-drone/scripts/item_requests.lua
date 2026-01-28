
local ep    = require("scripts.entity_property")
local dt    = require("scripts.drone_tasks")

-- item_name, item_quality, provider, count
local item_provider_lookup = {}
-- requester, item_name, quality, count
local provider_items = {}
-- requester, item_name, quality, count
local requester_items = {}

local requester_items = {}

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

local item_requests = {}

function item_requests.update_items()
    -- item_name, item_quality, provider, count
    item_provider_lookup = {}
    -- requester, item_name, quality, count
    provider_items = {}
    -- requester, item_name, quality, count
    requester_items = {}

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
    for requester, items in pairs(requester_items) do
        for item_name, quality_count in pairs(items) do
            for quality, count in pairs(quality_count) do
                
            end
        end
    end
end

return item_requests
