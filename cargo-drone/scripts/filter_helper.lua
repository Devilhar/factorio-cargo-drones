
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

return filter_helper
