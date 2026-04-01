
local index_chars = "1234567890ABCDEFGHIJKLMNOPQRSTUWXYZ"

local index_to_name = {}
local name_to_index = {}
local max_bytes = #index_chars * 4

for i = 1, #index_chars do
    local char = string.sub(index_chars, i, i)

    index_to_name[i] = "cargo-drone-signal-" .. char
end

for i, name in ipairs(index_to_name) do
    name_to_index[name] = i
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

local cc_string_encoder = {}

cc_string_encoder.max_bytes = max_bytes

function cc_string_encoder.byte_length(str)
    return table.pack(string.byte(str, 1, #str)).n
end

function cc_string_encoder.encode(str, section)
    local bytes = table.pack(string.byte(str, 1, #str))

    if bytes.n == 0 then
        section.filters = {}

        return
    end

    local filters = {}

    local index_max = max_bytes / 4
    local index_count = math.floor((bytes.n - 1) / 4) + 1

    for i = 1, math.min(index_count, index_max) do
        local a = bytes[(i - 1) * 4 + 1]
        local b = bytes[(i - 1) * 4 + 2] or 0
        local c = bytes[(i - 1) * 4 + 3] or 0
        local d = bytes[(i - 1) * 4 + 4] or 0

        local encoded_unsigned = a + bit_lshift(b, 8) + bit_lshift(c, 16) + bit_lshift(d, 24)

        local encoded_signed = encoded_unsigned - 2147483648

        filters[i] = {
            value = {
                type = "virtual",
                name = index_to_name[i],
                quality = "normal",
            },
            min = encoded_signed
        }
    end

    section.filters = filters
end

function cc_string_encoder.decode(section)
    local bytes = {}

    for _, filter in ipairs(section.filters) do
        if filter.value then
            local index = name_to_index[filter.value.name]

            if index ~= nil then
                local encoded_signed = filter.min

                local encoded_unsigned = encoded_signed + 2147483648

                local a = bit32.band(encoded_unsigned, 0xFF)
                local b = bit32.band(bit_rshift(encoded_unsigned, 8), 0xFF)
                local c = bit32.band(bit_rshift(encoded_unsigned, 16), 0xFF)
                local d = bit32.band(bit_rshift(encoded_unsigned, 24), 0xFF)

                index = index - 1

                bytes[index * 4 + 1] = a
                if b ~= 0 then bytes[index * 4 + 2] = b end
                if c ~= 0 then bytes[index * 4 + 3] = c end
                if d ~= 0 then bytes[index * 4 + 4] = d end
            end
        end
    end

    return string.char(table.unpack(bytes))
end

return cc_string_encoder
