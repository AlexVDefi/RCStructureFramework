---See docs/how-to/events.md and docs/reference/events.md for the API.
---@class RCStructureFrameworkEvents
local Events = {}

---@type string[]
Events.NAMES = {
    "OnRCSFStructureBuilt",
    "OnRCSFStructureDisassembled",
    "OnRCSFRoomAssigned",
    "OnRCSFRoomUnassigned",
}

if type(LuaEventManager) == "table" and type(LuaEventManager.AddEvent) == "function" then
    for i = 1, #Events.NAMES do
        LuaEventManager.AddEvent(Events.NAMES[i])
    end
end

---@param name string
---@param info table
---@return nil
local function fire(name, info)
    if type(triggerEvent) == "function" then
        triggerEvent(name, info)
    end
end

---@param structureId string
---@param plan RCSFPlan
---@param character IsoPlayer?
---@param placed IsoObject[]
---@return nil
function Events.fireStructureBuilt(structureId, plan, character, placed)
    fire("OnRCSFStructureBuilt", {
        structureId = structureId,
        plan        = plan,
        character   = character,
        placed      = placed or {},
    })
end

---@param structureId string
---@param character IsoPlayer?
---@param removed IsoObject[]
---@return nil
function Events.fireStructureDisassembled(structureId, character, removed)
    fire("OnRCSFStructureDisassembled", {
        structureId = structureId,
        character   = character,
        removed     = removed or {},
    })
end

---@param assignment RCSFRoomAssignment
---@return nil
function Events.fireRoomAssigned(assignment)
    fire("OnRCSFRoomAssigned", assignment)
end

---@param assignment RCSFRoomAssignment
---@return nil
function Events.fireRoomUnassigned(assignment)
    fire("OnRCSFRoomUnassigned", assignment)
end

return Events
