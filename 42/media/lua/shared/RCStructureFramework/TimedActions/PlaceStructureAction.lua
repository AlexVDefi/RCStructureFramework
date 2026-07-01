require("TimedActions/ISBaseTimedAction")
local Builder = require("RCStructureFramework/Builder")
local PlacementValidation = require("RCStructureFramework/PlacementValidation")
local MaterialSource = require("RCStructureFramework/MaterialSource")

---@class RCStructurePlaceAction : ISBaseTimedAction
---@field structureId string
---@field character IsoPlayer
---@field container InventoryItem
---@field plan table
---@field materialSource table?
RCStructurePlaceAction = ISBaseTimedAction:derive("RCStructurePlaceAction")
_G["RCStructurePlaceAction"] = RCStructurePlaceAction

---@return boolean
---@nodiscard
function RCStructurePlaceAction:isValid()
    local valid = PlacementValidation.validateContainerPlacement(
        self.structureId,
        self.character,
        self.container,
        self.plan
    )
    return valid == true
end

---@return nil
function RCStructurePlaceAction:start()
    self:setActionAnim("Build")
end

---@return nil
function RCStructurePlaceAction:perform()
    ISBaseTimedAction.perform(self)
end

---@return boolean
function RCStructurePlaceAction:complete()
    local outcome = Builder.buildFromPlan(self.structureId, self.character, self.materialSource, self.plan, {
        container = self.container,
    })
    return outcome and outcome.success == true
end

---@return number
---@nodiscard
function RCStructurePlaceAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    if type(self.plan) == "table" then
        local summary = PlacementValidation.getPlacementSummary(self.structureId, self.plan)
        if summary and summary.totalRequired then
            return math.max(80, summary.totalRequired * 12)
        end
    end

    return 80
end

---@param character IsoPlayer
---@param structureId string
---@param container InventoryItem
---@param plan table
---@return RCStructurePlaceAction
function RCStructurePlaceAction:new(character, structureId, container, plan)
    local o = ISBaseTimedAction.new(self, character) --[[@as RCStructurePlaceAction]]
    o.structureId = structureId
    o.container = container
    o.plan = plan
    o.materialSource = MaterialSource.fromDef(structureId, character, container, plan)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
