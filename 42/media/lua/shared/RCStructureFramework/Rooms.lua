local Registry = require("RCStructureFramework/Registry")
local RoomPersistence = require("RCStructureFramework/RoomPersistence")
local Events = require("RCStructureFramework/Events")

---See docs/how-to/rooms.md and docs/concepts/authority-and-rooms.md.
---@class RCStructureFrameworkRooms
local Rooms = {}

---@param value any
---@return boolean
---@nodiscard
local function isNumber(value)
    return type(value) == "number"
end

---@param r table
---@return table|nil
---@nodiscard
local function sanitizeRect(r)
    if type(r) ~= "table" then return nil end
    if not isNumber(r.x) or not isNumber(r.y) or not isNumber(r.w) or not isNumber(r.h) then
        return nil
    end
    local w = math.floor(r.w)
    local h = math.floor(r.h)
    if w < 1 or h < 1 then return nil end
    return {
        x = math.floor(r.x),
        y = math.floor(r.y),
        z = isNumber(r.z) and math.floor(r.z) or 0,
        w = w,
        h = h,
    }
end

---@param input table
---@return table[]|nil
---@nodiscard
local function toRects(input)
    if type(input) ~= "table" then return nil end

    ---@type table[]
    local source
    if type(input.rects) == "table" and #input.rects > 0 then
        source = input.rects
    elseif isNumber(input.x) and isNumber(input.w) and isNumber(input.h) then
        source = { input }
    elseif type(input[1]) == "table" then
        source = input
    else
        return nil
    end

    ---@type table[]
    local out = {}
    for i = 1, #source do
        local r = sanitizeRect(source[i])
        if not r then return nil end
        out[#out + 1] = r
    end
    if #out == 0 then return nil end
    return out
end

---@param name string
---@return string
---@nodiscard
local function defaultId(name)
    local token = string.gsub(name, "[^%w]", "_")
    return "RCSFRoom_" .. token
end

---MP client, or the editor rejected the footprint). See docs/how-to/rooms.md.
---@param rectOrRects table
---@param name string
---@param opts table?
---@return RCSFRoomAssignment|nil
function Rooms.assign(rectOrRects, name, opts)
    opts = opts or {}
    if isClient() then return nil end
    if type(name) ~= "string" or name == "" then return nil end

    local rects = toRects(rectOrRects)
    if not rects then return nil end

    local id = opts.id
    if type(id) ~= "string" or id == "" then
        id = defaultId(name)
    end

    Registry.registerStructure({ id = id, roomName = name })

    local footprint
    if #rects == 1 and type(opts.stairs) ~= "table" then
        footprint = rects[1]
    else
        footprint = { rects = rects, stairs = opts.stairs }
    end

    local ok = RoomPersistence.createAssignedRoom(id, footprint, opts.loading == true)
    if not ok then return nil end

    ---@type RCSFRoomAssignment
    local assignment = { id = id, name = name, rects = rects }
    Events.fireRoomAssigned(assignment)
    return assignment
end

---@param target table  assignment descriptor, or rect / rect-list / footprint
---@param opts table?   { id?, name? } when `target` is not a descriptor
---@return boolean
function Rooms.unassign(target, opts)
    opts = opts or {}
    if isClient() then return false end
    if type(target) ~= "table" then return false end

    local rects = toRects(target)
    if not rects then return false end

    local id = opts.id
    if type(id) ~= "string" or id == "" then
        if type(target.id) == "string" and target.id ~= "" then
            id = target.id
        elseif type(opts.name) == "string" and opts.name ~= "" then
            id = defaultId(opts.name)
        elseif type(target.name) == "string" and target.name ~= "" then
            id = defaultId(target.name)
        else
            return false
        end
    end

    local removed
    if #rects == 1 then
        removed = RoomPersistence.removeRoomByRect(id, rects[1], true, opts.loading == true)
    else
        removed = RoomPersistence.removeRoomByRects(id, rects, true, opts.loading == true)
    end

    Events.fireRoomUnassigned({ id = id, name = opts.name or target.name, rects = rects })
    return removed == true
end

return Rooms
