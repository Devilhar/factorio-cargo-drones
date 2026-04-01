
local function make_graphical_set(position)
    return {
        base = {
            position = position,
            size = 36,
            scale = 36/80,
            corner_size = 6,
        }
    }
end

data.raw["gui-style"].default["cargo-drone-items"] = {
    type = "button_style",
    parent = "transparent_button",
    size = 36,
    draw_shadow_under_picture = true,
    default_graphical_set = make_graphical_set({0, 736}),
    hovered_graphical_set = make_graphical_set({0, 736}),
    clicked_graphical_set = make_graphical_set({0, 736}),
    selected_graphical_set = make_graphical_set({0, 736}),
}
data.raw["gui-style"].default["cargo-drone-requested"] = {
    type = "button_style",
    parent = "transparent_button",
    size = 36,
    draw_shadow_under_picture = true,
    default_graphical_set = make_graphical_set({0, 656}),
    hovered_graphical_set = make_graphical_set({0, 656}),
    clicked_graphical_set = make_graphical_set({0, 656}),
    selected_graphical_set = make_graphical_set({0, 656}),
}
