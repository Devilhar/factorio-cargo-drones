
local filter_helper = {}

function filter_helper.set_filter_value(section, filter_name, value)
    local filters = section.filters

    for i, filter in ipairs(filters) do
        if filter.value and filter.value.name == filter_name then
            if value == nil then
                table.remove(filters, i)
            else
                filter.min = value
            end

            section.filters = filters

            return
        end
    end

    if value == nil then
        return
    end

    table.insert(filters, {
        value = {
            type = "virtual",
            name = filter_name,
            quality = "normal",
        },
        min = value
    })

    section.filters = filters
end
function filter_helper.get_filter_value(section, filter_name)
    for _, filter in ipairs(section.filters) do
        if filter.value and filter.value.name == filter_name then
            return filter.min
        end
    end

    return nil
end

function filter_helper.set_signal_id_value(section, signal_id, value)
    if signal_id == nil then
        section.filters = {}

        return
    end

    section.filters = {
        {
            value = {
                type = signal_id.type,
                name = signal_id.name,
                quality = signal_id.quality or "normal",
            },
            min = value
        }
    }
end
function filter_helper.get_signal_id_value(section)
    local filter = section.filters[1]

    if not filter then
        return nil, 0
    end

    return filter.value, filter.min
end

return filter_helper
