local Registry = require("RCStructureFramework/Registry")
local Plans = require("RCStructureFramework/Plans")
local MaterialSource = require("RCStructureFramework/MaterialSource")
local Builder = require("RCStructureFramework/Builder")
local RoomPersistence = require("RCStructureFramework/RoomPersistence")

---creation. See docs/how-to/headless-build.md for the API and options.
---@class RCStructureFrameworkBuild
local Build = {}

---See docs/how-to/headless-build.md for the full options reference.
---@param structureId string
---@param plan RCSFPlan
---@param character IsoPlayer?
---@param opts table?
---@return RCSFBuildOutcome
function Build.build(structureId, plan, character, opts)
    opts = opts or {}

    local def = Registry.getStructure(structureId)
    if not def then
        return { success = false, placed = {}, failed = {}, reason = "unknown structure '" .. tostring(structureId) .. "'" }
    end
    if type(plan) ~= "table" then
        return { success = false, placed = {}, failed = {}, reason = "missing plan" }
    end
    if isClient() and opts.allowClient ~= true then
        return { success = false, placed = {}, failed = {}, reason = "RCSF.build is server-authoritative; pass opts.allowClient to override" }
    end

    local working = Plans.normalizePlan(Plans.copyPlan(plan))
    if type(working.structureId) ~= "string" or working.structureId == "" then
        working.structureId = structureId
    end
    if opts.variant ~= nil then
        working.variant = opts.variant
    end

    local source
    if opts.materialSource ~= nil then
        source = opts.materialSource
    elseif opts.free == true then
        source = nil
    else
        source = MaterialSource.fromDef(structureId, character, opts.container, working)
    end

    local builderOptions = opts.builderOptions or {}
    if builderOptions.container == nil and opts.container ~= nil then
        builderOptions.container = opts.container
    end

    local wantRoom = opts.createRoom ~= false
        and type(def.roomName) == "string" and def.roomName ~= ""
        and type(working.rects) == "table" and #working.rects > 0
    local roomFootprint = nil
    local roomCreated = false
    if wantRoom then
        local stairs = nil
        if type(working.stairs) == "table" and #working.stairs > 0 then
            stairs = working.stairs
        end
        if #working.rects == 1 and stairs == nil then
            roomFootprint = working.rects[1]
        else
            roomFootprint = { rects = working.rects, stairs = stairs }
        end
        roomCreated = RoomPersistence.createRoom(structureId, roomFootprint, false) == true
    end

    local outcome = Builder.buildFromPlan(structureId, character, source, working, builderOptions)
    if type(outcome) ~= "table" then
        return { success = false, placed = {}, failed = {}, reason = "builder returned nil" }
    end

    if wantRoom then
        if outcome.success then
            outcome.roomCreated = roomCreated
        elseif roomCreated and roomFootprint then
            if roomFootprint.rects then
                RoomPersistence.removeRoomByRects(structureId, roomFootprint.rects, true, false)
            else
                RoomPersistence.removeRoomByRect(structureId, roomFootprint, true, false)
            end
            outcome.roomCreated = false
        end
    end

    return outcome
end

return Build
