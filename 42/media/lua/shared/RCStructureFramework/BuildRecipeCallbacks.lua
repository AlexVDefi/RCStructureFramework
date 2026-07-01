---@class RCStructureFrameworkBuildRecipeCallbacks
local BuildRecipeCallbacks = {}

RCStructureBuildRecipeCode = RCStructureBuildRecipeCode or {}

---@param structureId string
---@param callbackName string
---@param params table
---@return any
function BuildRecipeCallbacks.call(structureId, callbackName, params)
    local framework = require("RCStructureFramework")
    local def = framework.Registry.requireStructure(structureId)
    local callbacks = def.buildRecipeCallbacks
    if type(callbacks) ~= "table" then
        return nil
    end

    local callback = callbacks[callbackName]
    if callback then
        return callback(params)
    end

    return nil
end

return BuildRecipeCallbacks
