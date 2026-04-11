
--[[
    Encoding and decoding strings into two LuaLogisticSection filter properties.

    One which is just the string, and the other to keep track of the icons used in it.
    Icons are still embedded into the section with the string. The reason for keeping
    track of icons separately as well is so that users can see and change them in the
    parameter UI in blueprints.

    The string is stored as a series of filters, one filter per 4 characters since the
    type used for filter.min is int32.

    The icons are gotten by scanning the string for them. Iterating through all icons,
    the first instance of each unique icon is indexed. So the first unique icon will
    always be index 1, the next unique icon will be either 2 or a higher index if the
    first icon is repeated.
    
    So given string: "Hello[item=wood][item=iron-plate][item=wood][item=copper-plate]"
    The indices will be:
        [item=wood]         = 1
        [item=iron-plate]   = 2
        [item=copper-plate] = 4
    
    Since wood appears more than once, it only uses the first occurrence of wood.
    Meanwhile since copper-plate is the fourth icon, its index is 4 as it still counts
    the duplicate wood towards the index.

    However, we can't store the icons as filters with their indices as value. This is
    due to how blueprint parameters work. Since users can change icons there, it's
    possible to combine multiple icons, and the way Factorio handles this is by adding
    their values together.
    This creates a problem, since this breaks indices.
    
    Given the string: "World[item=wood][item=iron-plate]"
    The indices will be:
        [item=wood]         = 1
        [item=iron-plate]   = 2
    
    And if the user then changes iron-plate into wood in a blueprint, the indices will
    be:
        [item=wood]         = 3
        
    Which is incorrect.
    To fix this, we instead store the index as a bit. So the first index will be 1,
    second will be 2, and 3 will be 4. Then 8, 16, 32, etc.
    This allows us to get which icons in the string each type points to. Since 3 can
    only be created by adding 1 and 2 together.

    Now we face another problem though; values can also be changed in blueprint
    parameters.
    Changing the value of an icon is not supported, but if there's another entity that
    also has that value, the user now can't change it. To combat this, we can try and
    reduce the risk of value collisions. This is done in two ways.

    Since the values closer to zero are more likely to be used by other entities, we
    can offset the bits used to index icons. This will make the values larger.
    This reduces the maximum amount of possible icons, but this is not an issue if the
    maximum amount of possible bytes is low enough.
    
    Secondly, to reduce the risk even more, we can reverse the indices. So instead of
    1 being the first icon, 1 would be the last possible icon. This means that the
    user need to use the maximum amount of icons in the name for it to get as close
    as it can to zero.
    We do need to avoid the 32nd bit, since the value in filters are signed. Hitting
    it cause the value to go negative, and negative numbers can't be used since adding
    them together with positive numbers does not produce reversible indices.
]]

local index_chars = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local max_bytes = 144 -- #index_chars * 4

local index_to_str = {}
local str_to_index = {}

-- The max amount of icons possible in a string
local max_icons_in_name = 18 -- math.floor(max_bytes / #"[item=_]")

-- Arbitrarily selected 28 as highest used bit, as to not to get close to the int32 max numbers. Since those might also be used.
local str_icon_instance_offset = 10 -- 28 - max_icons_in_name

for i = 1, #index_chars do
    local char = string.sub(index_chars, i, i)

    index_to_str[i] = "cargo-drone-signal-" .. char
end

for i, name in ipairs(index_to_str) do
    str_to_index[name] = i
end

local function bit_lshift(x, disp)
    for _ = 1, disp do
        x = x * 2
    end

    return x
end
local function bit_rshift(x, disp)
    for _ = 1, disp do
        x = math.floor(x / 2)
    end

    return x
end

local function encode_string(str, section)
    local bytes = table.pack(string.byte(str, 1, #str))

    if bytes.n == 0 then
        section.filters = {}

        return ""
    end

    local byte_count = math.min(max_bytes, bytes.n)

    local filters = {}
    local index_count = math.floor((byte_count - 1) / 4) + 1

    for i = 1, index_count do
        local a = bytes[(i - 1) * 4 + 1]
        local b = bytes[(i - 1) * 4 + 2] or 0
        local c = bytes[(i - 1) * 4 + 3] or 0
        local d = bytes[(i - 1) * 4 + 4] or 0

        local encoded_unsigned = a + bit_lshift(b, 8) + bit_lshift(c, 16) + bit_lshift(d, 24)

        local encoded_signed = encoded_unsigned - 2147483648

        filters[i] = {
            value = {
                type = "virtual",
                name = index_to_str[i],
                quality = "normal",
            },
            min = encoded_signed
        }
    end

    section.filters = filters

    local encoded_str = string.char(table.unpack(bytes, 1, byte_count))

    return encoded_str
end
local function encode_icons(str, section)
    local function get_first_filter_instances()
        local first_instances = {}
        local last_begin = -1
        local last_assign = -1
        local char = ""
        local instance = 0

        for i = 1, #str do
            char = string.sub(str, i, i)

            if char == "[" then
                last_begin = i
            elseif last_begin ~= -1 and char == "=" then
                if last_assign == -1 then
                    last_assign = i
                else
                    last_begin = -1
                end
            elseif last_assign ~= -1 and char == "]" then
                local filter = string.sub(str, last_begin, i)
                instance = instance + 1

                if first_instances[filter] == nil then
                    first_instances[filter] = { last_begin, last_assign, i, instance }
                end

                last_begin = -1
                last_assign = -1
            end
        end

        return first_instances
    end

    local type_map = {
        ["item"]            = { type = "item",      prototype = "item" },
        ["fluid"]           = { type = "fluid",     prototype = "fluid" },
        ["virtual-signal"]  = { type = "virtual",   prototype = "virtual_signal" },
        ["entity"]          = { type = "entity",    prototype = "entity" },
    }
    local first_instances = get_first_filter_instances()
    local filters = {}

    for _, indices in pairs(first_instances) do
        local type_data = type_map[string.sub(str, indices[1] + 1, indices[2] - 1)]

        if type_data ~= nil then
            local f_name = string.sub(str, indices[2] + 1, indices[3] - 1)

            if prototypes[type_data.prototype][f_name] ~= nil then
                local shifted_instance = bit_lshift(1, str_icon_instance_offset + max_icons_in_name - indices[4])

                table.insert(filters, {
                    value = {
                        type = type_data.type,
                        name = f_name,
                        quality = "normal",
                    },
                    min = shifted_instance
                })
            end
        end
    end

    section.filters = filters
end

local cc_string_encoder = {}

cc_string_encoder.max_bytes = max_bytes

---@param str string
---@return number size
function cc_string_encoder.byte_length(str)
    return table.pack(string.byte(str, 1, #str)).n
end

---@param str string
---@param section_name userdata|table
---@param section_icons userdata|table
---@return string encoded_string
function cc_string_encoder.encode(str, section_name, section_icons)
    local encoded_string = encode_string(str, section_name)

    encode_icons(encoded_string, section_icons)

    return encoded_string
end

---@param section_name userdata|table
---@return string decoded_string
function cc_string_encoder.decode(section_name)
    local bytes = {}
    local highest_index = 0

    local function set_byte(index, value)
        bytes[index] = value

        if index > highest_index then
            highest_index = index
        end
    end

    for _, filter in ipairs(section_name.filters) do
        if filter.value then
            local index = str_to_index[filter.value.name]

            if index ~= nil then
                local encoded_signed = filter.min

                local encoded_unsigned = encoded_signed + 2147483648

                local a = bit32.band(encoded_unsigned, 0xFF)
                local b = bit32.band(bit_rshift(encoded_unsigned, 8), 0xFF)
                local c = bit32.band(bit_rshift(encoded_unsigned, 16), 0xFF)
                local d = bit32.band(bit_rshift(encoded_unsigned, 24), 0xFF)

                index = index - 1

                set_byte(index * 4 + 1, a)
                if b ~= 0 then set_byte(index * 4 + 2, b) end
                if c ~= 0 then set_byte(index * 4 + 3, c) end
                if d ~= 0 then set_byte(index * 4 + 4, d) end
            end
        end
    end

    local cleaned_bytes = {}

    for i = 1, highest_index do
        if bytes[i] ~= nil then
            table.insert(cleaned_bytes, bytes[i])
        end
    end

    return string.char(table.unpack(cleaned_bytes))
end

---@param str string
---@param section_icons userdata|table
---@return string str
function cc_string_encoder.replace_icons(section_icons, str)
    local type_map = {
        ["item"]    = "item",
        ["fluid"]   = "fluid",
        ["virtual"] = "virtual-signal",
        ["entity"]  = "entity",
    }

    local function get_filter_instances()
        local instances = {}

        for _, filter in ipairs(section_icons.filters) do
            if filter.value then
                local type_data = type_map[filter.value.type]

                if type_data ~= nil then
                    local shifted_instance = bit_rshift(filter.min, str_icon_instance_offset)

                    for instance = max_icons_in_name, 1, -1 do
                        if shifted_instance % 2 == 1 then
                            instances[instance] = "[" .. type_data .. "=" .. filter.value.name .. "]"
                        end

                        shifted_instance = bit_rshift(shifted_instance, 1)
                    end
                end
            end
        end

        return instances
    end
    local function get_str_instances()
        local instances = {}
        local last_begin = -1
        local last_assign = -1
        local instance = 0

        for i = 1, #str do
            local char = string.sub(str, i, i)

            if char == "[" then
                last_begin = i
            elseif last_begin ~= -1 and char == "=" then
                if last_assign == -1 then
                    last_assign = i
                else
                    last_begin = -1
                end
            elseif last_assign ~= -1 and char == "]" then
                local filter = string.sub(str, last_begin, i)
                instance = instance + 1

                instances[instance] = { filter, last_begin, i }

                last_begin = -1
                last_assign = -1
            end
        end

        return instances
    end

    local filter_instances = get_filter_instances()
    local str_instances = get_str_instances()
    local replacements = {}

    for instance, filter in pairs(filter_instances) do
        if str_instances[instance] then
            replacements[str_instances[instance][1]] = filter
        end
    end

    for instance = max_icons_in_name, 1, -1 do
        if str_instances[instance] then
            local replacement_filter = replacements[str_instances[instance][1]]

            if replacement_filter ~= str_instances[instance][1] then
                local replace_begin = str_instances[instance][2]
                local replace_end = str_instances[instance][3]

                if replacement_filter == nil then
                    str = string.sub(str, 1, replace_begin - 1) .. string.sub(str, replace_end + 1)
                else
                    str = string.sub(str, 1, replace_begin - 1) .. replacement_filter .. string.sub(str, replace_end + 1)
                end
            end
        end
    end

    return str
end

return cc_string_encoder
