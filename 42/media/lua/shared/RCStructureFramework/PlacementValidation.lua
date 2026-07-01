local Registry = require("RCStructureFramework/Registry")
local DefaultValidators = require("RCStructureFramework/DefaultValidators")
---@class RCStructureFrameworkPlacementValidation
local PlacementValidation = {}

---@param structureId string
---@param variant string
---@param pieceType string
---@param north boolean
---@return string|nil
---@nodiscard
function PlacementValidation.getPieceSpriteName(structureId, variant, pieceType, north)
    local def = Registry.requireStructure(structureId)
    if def.getPieceSpriteName then
        return def.getPieceSpriteName(variant, pieceType, north)
    end
    return nil
end

---@param structureId string
---@param plan table
---@return table
---@nodiscard
function PlacementValidation.getPlacementSummary(structureId, plan)
    local def = Registry.requireStructure(structureId)
    if def.getPlacementSummary then
        return def.getPlacementSummary(plan)
    end
    return {
        validDimensions = false,
        invalidPlan = true,
        completePerimeter = false,
        wallCount = 0,
        totalRequired = 0,
    }
end

---@param def table
---@param plan table
---@return boolean
---@return string|nil
---@nodiscard
local function runDefaultValidators(def, plan)
    local cfg = def.validation
    if type(cfg) ~= "table" then return true, nil end
    return DefaultValidators.runAll(plan, cfg.useDefaults)
end

---@param structureId string
---@param character IsoPlayer
---@param container InventoryItem
---@param plan table
---@return boolean
---@return string|nil
---@return table|nil
---@nodiscard
function PlacementValidation.validateContainerPlacement(structureId, character, container, plan)
    local def = Registry.requireStructure(structureId)

    local ok, reason = runDefaultValidators(def, plan)
    if ok ~= true then
        return false, reason, nil
    end

    if def.validateContainerPlacement then
        return def.validateContainerPlacement(character, container, plan)
    end
    return false, "definition", nil
end

---@param structureId string
---@param character IsoPlayer
---@param object IsoObject
---@return boolean
---@return string|nil
---@return table|nil
---@nodiscard
function PlacementValidation.validateCompletion(structureId, character, object)
    local def = Registry.requireStructure(structureId)
    if def.validateCompletion then
        return def.validateCompletion(character, object)
    end
    return false, "definition", nil
end

---@param structureId string
---@param character IsoPlayer
---@param object IsoObject
---@return boolean
---@return string|nil
---@return table|nil
---@nodiscard
function PlacementValidation.validateDisassembly(structureId, character, object)
    local def = Registry.requireStructure(structureId)
    if def.validateDisassembly then
        return def.validateDisassembly(character, object)
    end
    return false, "definition", nil
end

---@param structureId string
---@param data table
---@return IsoObject[]
---@nodiscard
function PlacementValidation.getRemovableObjects(structureId, data)
    local def = Registry.requireStructure(structureId)
    if def.getRemovableObjects then
        return def.getRemovableObjects(data)
    end
    return {}
end

return PlacementValidation
