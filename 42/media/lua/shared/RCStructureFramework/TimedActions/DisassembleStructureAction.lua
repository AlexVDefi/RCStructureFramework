require("TimedActions/ISBaseTimedAction")
local Builder = require("RCStructureFramework/Builder")
local PlacementValidation = require("RCStructureFramework/PlacementValidation")
local Registry = require("RCStructureFramework/Registry")
local MaterialSource = require("RCStructureFramework/MaterialSource")

---@class RCStructureDisassembleAction : ISBaseTimedAction
---@field structureId string
---@field character IsoPlayer
---@field targetObject IsoObject
---@field data table
---@field objects table?
---@field materialSource table?
RCStructureDisassembleAction = ISBaseTimedAction:derive("RCStructureDisassembleAction")
_G["RCStructureDisassembleAction"] = RCStructureDisassembleAction

---@return boolean
---@nodiscard
function RCStructureDisassembleAction:isValid()
    local valid = PlacementValidation.validateDisassembly(self.structureId, self.character, self.targetObject)
    return valid == true
end

---@return boolean
function RCStructureDisassembleAction:waitToStart()
    if self.targetObject and self.character.faceThisObjectAlt then
        self.character:faceThisObjectAlt(self.targetObject)
    end
    return self.character:shouldBeTurning()
end

---@return nil
function RCStructureDisassembleAction:update()
    if self.targetObject and self.character.faceThisObjectAlt then
        self.character:faceThisObjectAlt(self.targetObject)
    end
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
end

---@return nil
function RCStructureDisassembleAction:start()
    self:setActionAnim("Build")
end

---@return nil
function RCStructureDisassembleAction:perform()
    ISBaseTimedAction.perform(self)
end

---@return boolean
function RCStructureDisassembleAction:complete()
    local def = Registry.getStructure(self.structureId)

    local data = self.data
    local objects = self.objects
    if def and type(def.validateDisassembly) == "function" and self.targetObject then
        local valid, reason, freshData = def.validateDisassembly(self.character, self.targetObject)
        if freshData and (valid or reason == "distance") then
            data = freshData
            objects = nil
        end
    end

    if not data then
        return false
    end

    local materialSource = self.materialSource
    if not materialSource and def and def.refundViaMaterialSource == true then
        materialSource = MaterialSource.fromDef(self.structureId, self.character, nil, nil)
    end

    local outcome = Builder.disassembleFromPlan(self.structureId, self.character, {
        data = data,
        objects = objects,
        materialSource = materialSource,
    })
    return outcome and outcome.success == true
end

---@return number
---@nodiscard
function RCStructureDisassembleAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local def = Registry.getStructure(self.structureId)
    if def and type(def.getDisassemblyDuration) == "function" then
        local custom = def.getDisassemblyDuration(self.data, self.objects)
        if type(custom) == "number" and custom > 0 then return custom end
    end
    return 100
end

---@param character IsoPlayer
---@param structureId string
---@param targetObject IsoObject
---@param data table
---@param options table?  { objects?, materialSource? }
---@return RCStructureDisassembleAction
function RCStructureDisassembleAction:new(character, structureId, targetObject, data, options)
    local o = ISBaseTimedAction.new(self, character) --[[@as RCStructureDisassembleAction]]
    o.structureId = structureId
    o.targetObject = targetObject
    o.data = data
    o.objects = options and options.objects
    o.materialSource = options and options.materialSource
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

return RCStructureDisassembleAction
