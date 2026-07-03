---See docs/concepts/authority-and-rooms.md for the authority model.
---@class RCStructureFrameworkRoomLighting
local RoomLighting = {}

---@type fun(roomName:string):boolean|nil
local roomFilter = nil

---@param fn fun(roomName:string):boolean
---@return nil
function RoomLighting.setRoomFilter(fn)
    roomFilter = fn
end

local SWEEP_INTERVAL = 30

---@type table<number, IsoRoom>
local pending = {}

local sinceSweep = 0

---@param isoRoom IsoRoom
---@return boolean
---@nodiscard
local function isFrameworkRoom(isoRoom)
    if not isoRoom then return false end
    if type(roomFilter) ~= "function" then return false end
    local name = isoRoom:getName()
    if type(name) ~= "string" or name == "" then return false end
    return roomFilter(name) == true
end

---@param square IsoGridSquare
---@return IsoRoom|nil
---@nodiscard
local function frameworkRoomOfSquare(square)
    if not square then return nil end
    local isoRoom = square:getRoom()
    if isFrameworkRoom(isoRoom) then
        return isoRoom
    end
    return nil
end

---@param switchObj IsoLightSwitch
---@return boolean
---@nodiscard
local function isRoomGlowSwitch(switchObj)
    local sprite = switchObj:getSprite()
    if not sprite then return true end
    local props = sprite:getProperties()
    if props and props:has("lightR") then
        return false
    end
    return true
end

---@param isoRoom IsoRoom
---@return nil
local function addRoomLightsToCell(isoRoom)
    if isServer() then return end
    local cell = getCell()
    if not cell then return end
    local worldRoomLights = cell.roomLights
    local roomLights = isoRoom.roomLights
    if not worldRoomLights or not roomLights then return end
    for i = 0, roomLights:size() - 1 do
        local roomLight = roomLights:get(i)
        if not worldRoomLights:contains(roomLight) then
            worldRoomLights:add(roomLight)
        end
    end
end

---@param isoRoom IsoRoom
---@param switchObj IsoLightSwitch
---@return nil
local function wireSwitch(isoRoom, switchObj)
    if not isRoomGlowSwitch(switchObj) then return end
    local roomDef = isoRoom:getRoomDef()
    if not roomDef then return end

    local switches = isoRoom:getLightSwitches()
    if switches and not switches:contains(switchObj) then
        switches:add(switchObj)
    end

    isoRoom:createLights(false)
    addRoomLightsToCell(isoRoom)
end

---@param isoRoom IsoRoom
---@return nil
local function cleanupRoomLights(isoRoom)
    local cell = getCell()
    local worldRoomLights = cell and cell.roomLights
    local roomLights = isoRoom.roomLights
    if roomLights then
        for i = 0, roomLights:size() - 1 do
            local roomLight = roomLights:get(i)
            if worldRoomLights then
                worldRoomLights:remove(roomLight)
            end
        end
        roomLights:clear()
    end
end

---@param isoRoom IsoRoom
---@return nil
local function reconcileRoom(isoRoom)
    local roomDef = isoRoom:getRoomDef()
    if not roomDef then return end
    local cell = getCell()
    if not cell then return end

    local rects = roomDef:getRects()
    if not rects then return end
    local z = roomDef:getZ()
    local roomId = roomDef:getID()
    local foundSwitch = false

    for ri = 0, rects:size() - 1 do
        local rr = rects:get(ri)
        local x0, y0 = rr:getX(), rr:getY()
        local x1, y1 = x0 + rr:getW(), y0 + rr:getH()
        for x = x0, x1 - 1 do
            for y = y0, y1 - 1 do
                local sq = cell:getGridSquare(x, y, z)
                local sqRoom = sq and sq:getRoom()
                local sqDef = sqRoom and sqRoom:getRoomDef()
                if sqDef and sqDef:getID() == roomId then
                    local objs = sq:getObjects()
                    if objs then
                        for oi = 0, objs:size() - 1 do
                            local o = objs:get(oi)
                            if instanceof(o, "IsoLightSwitch") and isRoomGlowSwitch(o) then
                                foundSwitch = true
                                wireSwitch(isoRoom, o)
                            end
                        end
                    end
                end
            end
        end
    end

    if not foundSwitch and isoRoom.roomLights and isoRoom.roomLights:size() > 0 then
        cleanupRoomLights(isoRoom)
    end
end

---@param isoRoom IsoRoom
---@return nil
local function scheduleReconcile(isoRoom)
    local roomDef = isoRoom:getRoomDef()
    if not roomDef then return end
    pending[roomDef:getID()] = isoRoom
end

---@param obj IsoObject
---@return nil
local function onObjectAdded(obj)
    if not obj then return end
    if not instanceof(obj, "IsoLightSwitch") then return end
    local isoRoom = frameworkRoomOfSquare(obj:getSquare())
    if isoRoom then
        wireSwitch(isoRoom, obj)
    end
end

---@param obj IsoObject
---@return nil
local function onObjectAboutToBeRemoved(obj)
    if not obj then return end
    if not instanceof(obj, "IsoLightSwitch") then return end
    local isoRoom = frameworkRoomOfSquare(obj:getSquare())
    if isoRoom then
        scheduleReconcile(isoRoom)
    end
end

---@param square IsoGridSquare
---@return nil
local function onLoadGridsquare(square)
    if not square then return end
    local objs = square:getObjects()
    if not objs then return end
    local size = objs:size()
    if size == 0 then return end

    local hasSwitch = false
    for i = 0, size - 1 do
        if instanceof(objs:get(i), "IsoLightSwitch") then
            hasSwitch = true
            break
        end
    end
    if not hasSwitch then return end

    local isoRoom = frameworkRoomOfSquare(square)
    if not isoRoom then return end
    for i = 0, size - 1 do
        local o = objs:get(i)
        if instanceof(o, "IsoLightSwitch") then
            wireSwitch(isoRoom, o)
        end
    end
end

---@return nil
local function sweepLoadedRooms()
    local cell = getCell()
    if not cell then return end
    local rooms = cell:getRoomList()
    if not rooms then return end
    for i = 0, rooms:size() - 1 do
        local room = rooms:get(i)
        if isFrameworkRoom(room) then
            reconcileRoom(room)
        end
    end
end

---@return nil
local function onTick()
    if pending then
        local toProcess = pending
        pending = {}
        for _, room in pairs(toProcess) do
            if isFrameworkRoom(room) then
                reconcileRoom(room)
            end
        end
    end

    sinceSweep = sinceSweep + 1
    if sinceSweep >= SWEEP_INTERVAL then
        sinceSweep = 0
        sweepLoadedRooms()
    end
end

local registered = false

---@return nil
function RoomLighting.registerEvents()
    if registered then return end
    if isServer() and not isClient() then return end
    registered = true
    Events.OnObjectAdded.Add(onObjectAdded)
    Events.OnObjectAboutToBeRemoved.Add(onObjectAboutToBeRemoved)
    Events.LoadGridsquare.Add(onLoadGridsquare)
    Events.OnTick.Add(onTick)
end

---@return nil
function RoomLighting.unregisterEvents()
    if not registered then return end
    registered = false
    Events.OnObjectAdded.Remove(onObjectAdded)
    Events.OnObjectAboutToBeRemoved.Remove(onObjectAboutToBeRemoved)
    Events.LoadGridsquare.Remove(onLoadGridsquare)
    Events.OnTick.Remove(onTick)
end

return RoomLighting
