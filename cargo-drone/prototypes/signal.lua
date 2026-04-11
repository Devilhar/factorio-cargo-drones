
local signal_chars = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local signals = {}

for i = 1, #signal_chars do
    local char = string.sub(signal_chars, i, i)

    table.insert(signals, {
        type = "virtual-signal",
        name = "cargo-drone-signal-" .. char,
        localised_name = "Cargo Drone internal signal",
        icon = "__base__/graphics/icons/signal/signal_" .. char .. ".png",
        hidden = true,
        parameter = false,
    })
end

data:extend(signals)
