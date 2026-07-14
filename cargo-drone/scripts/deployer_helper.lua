
local function clean_settings(deployer)
    local cb = deployer.get_control_behavior()

    while cb.sections_count < 1 do
        cb.add_section()
    end
    while cb.sections_count > 1 do
        cb.remove_section(2)
    end


end

local deployer_helper = {}

function deployer_helper.clean_settings(deployer)
    clean_settings(deployer)
end

return deployer_helper
