
---@class RCSFConfig
---@field systems table<string, boolean>
---@field validateDefs boolean
---@field verboseValidation boolean

RCSF_Config = RCSF_Config or {}
RCSF_Config.systems = RCSF_Config.systems or {}

---@type table<string, boolean>
local systemDefaults = {
    roomLighting = true,
    spritePatcher = true,
    roomSync = true,
    materialContainers = true,
    plannedConstructions = true,
}

for key, value in pairs(systemDefaults) do
    if RCSF_Config.systems[key] == nil then
        RCSF_Config.systems[key] = value
    end
end

if RCSF_Config.validateDefs == nil then
    RCSF_Config.validateDefs = true
end

if RCSF_Config.verboseValidation == nil then
    RCSF_Config.verboseValidation = false
end

return RCSF_Config
