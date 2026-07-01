local Geometry = require("RCStructureFramework/Geometry")
local Registry = require("RCStructureFramework/Registry")
---@class RCStructureFrameworkRoomPersistence
local RoomPersistence = {}

RoomPersistence.MOD_DATA_KEY = "RCStructureFrameworkRooms"

---@type table[]
local syncedRooms = {}

---@return table[]
---@nodiscard
function RoomPersistence.getRoomRecords()
    local data = ModData.getOrCreate(RoomPersistence.MOD_DATA_KEY)
    if data.rooms == nil then
        data.rooms = {}
    end
    return data.rooms
end

---@return nil
function RoomPersistence.transmitRoomRecords()
    if isServer() then
        ModData.transmit(RoomPersistence.MOD_DATA_KEY)
    end
end

---@param structureId string
---@param rect table
---@return string
---@nodiscard
local function recordKey(structureId, rect)
    return tostring(structureId) .. ":" .. Geometry.roomRecordKey(rect)
end

---@param structureId string
---@param rects table[]
---@return string
---@nodiscard
local function rectsRecordKey(structureId, rects)
    local sorted = {}
    for i = 1, #rects do sorted[i] = rects[i] end
    table.sort(sorted, function(a, b)
        if a.z ~= b.z then return a.z < b.z end
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        if a.w ~= b.w then return a.w < b.w end
        return a.h < b.h
    end)
    local parts = { tostring(structureId), "rects" }
    for i = 1, #sorted do parts[#parts + 1] = Geometry.roomRecordKey(sorted[i]) end
    return table.concat(parts, ":")
end

---@param footprintOrRect table
---@return table[]|nil
---@nodiscard
local function extractRects(footprintOrRect)
    if type(footprintOrRect) ~= "table" then return nil end
    if type(footprintOrRect.rects) == "table" and #footprintOrRect.rects > 0 then
        return footprintOrRect.rects
    end
    return nil
end

---@param footprintOrRect table
---@return table[]|nil
---@nodiscard
local function extractStairs(footprintOrRect)
    if type(footprintOrRect) ~= "table" then return nil end
    if type(footprintOrRect.stairs) == "table" and #footprintOrRect.stairs > 0 then
        return footprintOrRect.stairs
    end
    return nil
end

---See docs/concepts/authority-and-rooms.md for the room/building model.
---@param rects table[]
---@param stairs table[]?
---@return table[]  list of groups; each group is a list of rect references
---@nodiscard
function RoomPersistence.partitionRectsByConnectivity(rects, stairs)
    if type(rects) ~= "table" or #rects == 0 then return {} end

    local n = #rects
    ---@type integer[]
    local parent = {}
    for i = 1, n do parent[i] = i end

    ---@param i integer
    ---@return integer
    ---@nodiscard
    local function find(i)
        while parent[i] ~= i do
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        return i
    end

    ---@param a integer
    ---@param b integer
    ---@return nil
    local function union(a, b)
        local ra, rb = find(a), find(b)
        if ra ~= rb then parent[ra] = rb end
    end

    for i = 1, n - 1 do
        local ai = rects[i]
        local aiZ = ai.z or 0
        for j = i + 1, n do
            local bj = rects[j]
            if aiZ == (bj.z or 0) then
                if Geometry.rectsOverlap(ai, bj) or Geometry.rectsEdgeAdjacent4(ai, bj) then
                    union(i, j)
                end
            end
        end
    end

    if type(stairs) == "table" then
        for s = 1, #stairs do
            local stair = stairs[s]
            if type(stair) == "table" and type(stair.x) == "number" and type(stair.y) == "number" then
                local sz = stair.z or 0
                local lx, ly, lz = Geometry.getStairLandingTile(stair)
                local lowerIdx, upperIdx = nil, nil
                for i = 1, n do
                    local r = rects[i]
                    local rz = r.z or 0
                    if not lowerIdx and rz == sz and Geometry.cellInOrAdjacentToRect(r, stair.x, stair.y) then
                        lowerIdx = i
                    end
                    if not upperIdx and rz == lz and Geometry.cellInOrAdjacentToRect(r, lx, ly) then
                        upperIdx = i
                    end
                    if lowerIdx and upperIdx then break end
                end
                if lowerIdx and upperIdx then
                    union(lowerIdx, upperIdx)
                end
            end
        end
    end

    ---@type table<integer, integer>
    local rootToGroup = {}
    ---@type table[]
    local groups = {}
    for i = 1, n do
        local r = find(i)
        local idx = rootToGroup[r]
        if not idx then
            groups[#groups + 1] = {}
            idx = #groups
            rootToGroup[r] = idx
        end
        local g = groups[idx]
        g[#g + 1] = rects[i]
    end

    return groups
end

---@param footprintOrRect table
---@return table|nil
---@nodiscard
local function extractSingleRect(footprintOrRect)
    if type(footprintOrRect) ~= "table" then return nil end
    if footprintOrRect.x and footprintOrRect.w and footprintOrRect.h then
        return footprintOrRect
    end
    if type(footprintOrRect.roomRect) == "table" then
        return footprintOrRect.roomRect
    end
    return nil
end

---@param record table
---@return table|nil
---@nodiscard
function RoomPersistence.getRectFromRecord(record)
    local x = tonumber(record.x)
    local y = tonumber(record.y)
    local z = tonumber(record.z)
    local w = tonumber(record.w)
    local h = tonumber(record.h)

    if x == nil or y == nil or z == nil or w == nil or h == nil then
        return nil
    end

    return { x = x, y = y, z = z, w = w, h = h }
end

---@param structureId string
---@param rect table
---@return nil
function RoomPersistence.rememberRoom(structureId, rect)
    local def = Registry.requireStructure(structureId)
    local rooms = RoomPersistence.getRoomRecords()
    local key = recordKey(structureId, rect)

    for i = 1, #rooms do
        local record = rooms[i]
        if record.key == key then
            record.structureId = structureId
            record.roomName = def.roomName
            record.x = rect.x
            record.y = rect.y
            record.z = rect.z
            record.w = rect.w
            record.h = rect.h
            record.rects = nil
            RoomPersistence.transmitRoomRecords()
            return
        end
    end

    rooms[#rooms + 1] = {
        key = key,
        structureId = structureId,
        roomName = def.roomName,
        x = rect.x,
        y = rect.y,
        z = rect.z,
        w = rect.w,
        h = rect.h,
    }
    RoomPersistence.transmitRoomRecords()
end

---@param structureId string
---@param rects table[]
---@return nil
function RoomPersistence.rememberRoomFromRects(structureId, rects)
    if type(rects) ~= "table" or #rects == 0 then return end
    local def = Registry.requireStructure(structureId)
    local rooms = RoomPersistence.getRoomRecords()
    local key = rectsRecordKey(structureId, rects)
    local first = rects[1]

    ---@type table[]
    local rectsCopy = {}
    for i = 1, #rects do
        local r = rects[i]
        rectsCopy[i] = { x = r.x, y = r.y, z = r.z, w = r.w, h = r.h }
    end

    for i = 1, #rooms do
        local record = rooms[i]
        if record.key == key then
            record.structureId = structureId
            record.roomName = def.roomName
            record.x = first.x
            record.y = first.y
            record.z = first.z
            record.w = first.w
            record.h = first.h
            record.rects = rectsCopy
            RoomPersistence.transmitRoomRecords()
            return
        end
    end

    rooms[#rooms + 1] = {
        key = key,
        structureId = structureId,
        roomName = def.roomName,
        x = first.x,
        y = first.y,
        z = first.z,
        w = first.w,
        h = first.h,
        rects = rectsCopy,
    }
    RoomPersistence.transmitRoomRecords()
end

---@param structureId string
---@param rect table
---@return nil
function RoomPersistence.forgetRoom(structureId, rect)
    local rooms = RoomPersistence.getRoomRecords()
    local key = recordKey(structureId, rect)

    for i = #rooms, 1, -1 do
        if rooms[i].key == key then
            table.remove(rooms, i)
            RoomPersistence.transmitRoomRecords()
            return
        end
    end
end

---@param structureId string
---@param rects table[]
---@return nil
function RoomPersistence.forgetRoomByRects(structureId, rects)
    if type(rects) ~= "table" or #rects == 0 then return end
    local rooms = RoomPersistence.getRoomRecords()
    local key = rectsRecordKey(structureId, rects)

    for i = #rooms, 1, -1 do
        if rooms[i].key == key then
            table.remove(rooms, i)
            RoomPersistence.transmitRoomRecords()
            return
        end
    end
end

---@param roomDef RoomDef
---@param structureId string
---@param rect table
---@return boolean
---@nodiscard
local function isStructureRoomDef(roomDef, structureId, rect)
    if not roomDef then
        return false
    end
    local def = Registry.requireStructure(structureId)
    local baseName = def.roomName
    if type(baseName) ~= "string" or baseName == "" then
        return false
    end
    local name = roomDef:getName()
    if type(name) ~= "string" then
        return false
    end
    if name ~= baseName then
        local prefix = baseName .. "_"
        if string.sub(name, 1, #prefix) ~= prefix then
            return false
        end
    end
    return roomDef:getZ() == rect.z
        and roomDef:contains(rect.x, rect.y)
end

---@param rect table
---@return RoomDef|nil
---@nodiscard
local function getInteriorRoomDef(rect)
    return getWorld():getMetaGrid():getRoomAt(rect.x, rect.y, rect.z)
end

---@param structureId string
---@param rect table
---@return RoomDef|nil
---@nodiscard
function RoomPersistence.getRoomDef(structureId, rect)
    local roomDef = getInteriorRoomDef(rect)
    if isStructureRoomDef(roomDef, structureId, rect) then
        return roomDef
    end
    return nil
end

---@param roomDef RoomDef
---@return table|nil
---@nodiscard
local function getRectFromRoomDef(roomDef)
    local rects = roomDef:getRects()
    if rects:size() == 0 then
        return nil
    end

    local roomRect = rects:get(0)
    return {
        x = roomRect:getX(),
        y = roomRect:getY(),
        z = roomDef:getZ(),
        w = roomRect:getW(),
        h = roomRect:getH(),
    }
end

---@param roomDef RoomDef
---@return boolean
local function markRoomDefRuntimeOnly(roomDef)
    if roomDef.userDefined then
        roomDef.userDefined = false
    end

    local buildingDef = roomDef:getBuilding()
    if not buildingDef then
        return false
    end

    if buildingDef:isUserDefined() then
        buildingDef:setUserDefined(false)
    end

    return true
end

---@param rect table
---@return boolean
---@nodiscard
function RoomPersistence.hasInteriorRoom(rect)
    local roomDef = getInteriorRoomDef(rect)
    return roomDef and roomDef:getBuilding() ~= nil
end

---@param structureId string
---@param rect table
---@return boolean
function RoomPersistence.markRoomRuntimeOnly(structureId, rect)
    local roomDef = RoomPersistence.getRoomDef(structureId, rect)
    if not roomDef then
        return false
    end

    return markRoomDefRuntimeOnly(roomDef)
end

---@return BuildingRoomsEditor
local function resetBuildingRoomsEditor()
    BuildingRoomsEditor.Reset()

    local editor = BuildingRoomsEditor.getInstance()
    editor:setCurrentBuilding(nil)
    editor:setCurrentRoom(nil)
    return editor
end

---See docs/concepts/authority-and-rooms.md for the room/building model.
---@param def table
---@param groupRects table[]
---@param loading boolean?
---@param roomNameStartIndex integer
---@return boolean ok, integer nextRoomNameIndex
local function buildOneBuildingForGroup(def, groupRects, loading, roomNameStartIndex)
    local editor = resetBuildingRoomsEditor()
    local building = editor:createBuilding()
    editor:setCurrentBuilding(building)

    local nextRoomIndex = roomNameStartIndex
    for i = 1, #groupRects do
        local r = groupRects[i]
        local room = building:createRoom(r.z)
        editor:setCurrentRoom(room)
        room:setName(def.roomName .. "_" .. tostring(nextRoomIndex))
        nextRoomIndex = nextRoomIndex + 1

        if not editor:canAddRoomRectangle(room, r.x, r.y, r.w, r.h, r.z) then
            resetBuildingRoomsEditor()
            return false, nextRoomIndex
        end
        room:addRectangle(r.x, r.y, r.w, r.h)
    end

    if not editor:isValid() then
        resetBuildingRoomsEditor()
        return false, nextRoomIndex
    end

    editor:applyChanges(loading == true)
    resetBuildingRoomsEditor()
    return true, nextRoomIndex
end

---@param structureId string
---@param rects table[]
---@param loading boolean?
---@param stairs table[]?
---@return boolean
local function createRoomFromRects(structureId, rects, loading, stairs)
    local def = Registry.requireStructure(structureId)
    if not def.roomName then
        return true
    end

    local groups = RoomPersistence.partitionRectsByConnectivity(rects, stairs)
    if #groups == 0 then return true end

    local nextRoomIndex = 1
    for gi = 1, #groups do
        local groupRects = groups[gi]
        local probe = groupRects[1]

        if RoomPersistence.markRoomRuntimeOnly(structureId, probe) then
            nextRoomIndex = nextRoomIndex + #groupRects
        elseif RoomPersistence.hasInteriorRoom(probe) then
            nextRoomIndex = nextRoomIndex + #groupRects
        else
            local ok, newNextRoomIndex = buildOneBuildingForGroup(def, groupRects, loading, nextRoomIndex)
            if not ok then
                return false
            end
            nextRoomIndex = newNextRoomIndex
            if not RoomPersistence.markRoomRuntimeOnly(structureId, probe) then
                return false
            end
            for ri = 2, #groupRects do
                RoomPersistence.markRoomRuntimeOnly(structureId, groupRects[ri])
            end
        end
    end

    RoomPersistence.rememberRoomFromRects(structureId, rects)
    return true
end

---@param structureId string
---@param rectOrFootprint table  rect with `{x,y,z,w,h}`, or footprint with `.rects[]` / `.roomRect`
---@param loading boolean?
---@return boolean
function RoomPersistence.createRoom(structureId, rectOrFootprint, loading)
    local rects = extractRects(rectOrFootprint)
    if rects then
        local stairs = extractStairs(rectOrFootprint)
        return createRoomFromRects(structureId, rects, loading, stairs)
    end

    local rect = extractSingleRect(rectOrFootprint)
    if not rect then
        return false
    end

    local def = Registry.requireStructure(structureId)
    if not def.roomName then
        return true
    end

    if RoomPersistence.markRoomRuntimeOnly(structureId, rect) then
        RoomPersistence.rememberRoom(structureId, rect)
        return true
    end
    if RoomPersistence.hasInteriorRoom(rect) then
        return true
    end

    local editor = resetBuildingRoomsEditor()
    local building = editor:createBuilding()
    editor:setCurrentBuilding(building)

    local room = building:createRoom(rect.z)
    editor:setCurrentRoom(room)
    room:setName(def.roomName)

    if not editor:canAddRoomRectangle(room, rect.x, rect.y, rect.w, rect.h, rect.z) then
        resetBuildingRoomsEditor()
        return false
    end

    room:addRectangle(rect.x, rect.y, rect.w, rect.h)

    if not editor:isValid() then
        resetBuildingRoomsEditor()
        return false
    end

    editor:applyChanges(loading == true)
    resetBuildingRoomsEditor()

    if RoomPersistence.markRoomRuntimeOnly(structureId, rect) then
        RoomPersistence.rememberRoom(structureId, rect)
        return true
    end

    return false
end

---See docs/concepts/authority-and-rooms.md for the authority model.
---@param records table[]?
---@return nil
function RoomPersistence.ensureAssignmentDefs(records)
    if type(records) ~= "table" then return end
    for i = 1, #records do
        local r = records[i]
        if type(r) == "table" and r.assignment == true
            and type(r.structureId) == "string" and r.structureId ~= ""
            and type(r.roomName) == "string" and r.roomName ~= ""
            and not Registry.getStructure(r.structureId) then
            Registry.registerStructure({ id = r.structureId, roomName = r.roomName })
        end
    end
end

---See docs/concepts/authority-and-rooms.md for the authority model.
---@param structureId string
---@param rectOrFootprint table
---@param loading boolean?
---@return boolean
function RoomPersistence.createAssignedRoom(structureId, rectOrFootprint, loading)
    local ok = RoomPersistence.createRoom(structureId, rectOrFootprint, loading)
    if not ok then return false end

    local rooms = RoomPersistence.getRoomRecords()
    local rects = extractRects(rectOrFootprint)
    local key
    if rects then
        key = rectsRecordKey(structureId, rects)
    else
        local rect = extractSingleRect(rectOrFootprint)
        if not rect then return true end
        key = recordKey(structureId, rect)
    end

    for i = 1, #rooms do
        if rooms[i].key == key then
            rooms[i].assignment = true
            RoomPersistence.transmitRoomRecords()
            break
        end
    end
    return true
end

---@param loading boolean?
---@return nil
local function refreshRoomMetadata(loading)
    local editor = resetBuildingRoomsEditor()
    editor:applyChanges(loading == true)
    resetBuildingRoomsEditor()
end

---@param loading boolean?
---@return nil
function RoomPersistence.restoreLoadedRoomDefs(loading)
    RoomPersistence.ensureAssignmentDefs(RoomPersistence.getRoomRecords())

    local buildings = getWorld():getMetaGrid():getBuildings()
    local changed = false

    for i = 0, buildings:size() - 1 do
        local buildingDef = buildings:get(i)
        local rooms = buildingDef:getRooms()

        for j = 0, rooms:size() - 1 do
            local roomDef = rooms:get(j)
            local def = Registry.getStructureByRoomName(roomDef:getName())
            if def then
                if markRoomDefRuntimeOnly(roomDef) then
                    changed = true
                end
                local rect = getRectFromRoomDef(roomDef)
                if rect then
                    RoomPersistence.rememberRoom(def.id, rect)
                end
            end
        end

        local emptyOutside = buildingDef:getEmptyOutside()
        for j = 0, emptyOutside:size() - 1 do
            local roomDef = emptyOutside:get(j)
            local def = Registry.getStructureByRoomName(roomDef:getName())
            if def then
                if markRoomDefRuntimeOnly(roomDef) then
                    changed = true
                end
                local rect = getRectFromRoomDef(roomDef)
                if rect then
                    RoomPersistence.rememberRoom(def.id, rect)
                end
            end
        end
    end

    if changed then
        refreshRoomMetadata(loading)
    end
end

---@param isoBuilding IsoBuilding
---@return nil
local function clearIsoBuilding(isoBuilding)
    isoBuilding.def = nil
    if isoBuilding.rooms then
        isoBuilding.rooms:clear()
    end
    if isoBuilding.exits then
        isoBuilding.exits:clear()
    end
    if isoBuilding.container then
        isoBuilding.container:clear()
    end
    if isoBuilding.windows then
        isoBuilding.windows:clear()
    end
    if isoBuilding.lights then
        isoBuilding.lights:clear()
    end
end

---@param isoRoom IsoRoom
---@return nil
local function clearIsoRoom(isoRoom)
    local roomLights = isoRoom.roomLights
    local worldRoomLights = getCell().roomLights

    if roomLights and worldRoomLights then
        for i = 0, roomLights:size() - 1 do
            local roomLight = roomLights:get(i)
            roomLight.active = false
            worldRoomLights:remove(roomLight)
        end
    end

    getCell():getRoomList():remove(isoRoom)
    isoRoom.building = nil
    isoRoom.def = nil
    if isoRoom.lightSwitches then
        isoRoom.lightSwitches:clear()
    end
    if isoRoom.rects then
        isoRoom.rects:clear()
    end
    if isoRoom.roomLights then
        isoRoom.roomLights:clear()
    end
    if isoRoom.squares then
        isoRoom.squares:clear()
    end
end

---@param metaCell IsoMetaCell
---@param roomDef RoomDef
---@return nil
local function removeRoomDefFromMetaCell(metaCell, roomDef)
    local isoRoom = nil
    local isoRooms = metaCell.isoRooms
    if isoRooms then
        isoRoom = isoRooms:remove(roomDef:getID())
    end

    if isoRoom then
        local isoBuilding = isoRoom:getBuilding()
        if isoBuilding then
            local isoBuildingDef = isoBuilding:getDef()
            local isoBuildings = metaCell.isoBuildings
            local removedIsoBuilding = nil
            if isoBuildingDef and isoBuildings then
                removedIsoBuilding = isoBuildings:remove(isoBuildingDef:getID())
            end
            if removedIsoBuilding then
                clearIsoBuilding(removedIsoBuilding)
            end
        end
        clearIsoRoom(isoRoom)
    end

    if metaCell.rooms then
        metaCell.rooms:remove(roomDef:getID())
    end
    if metaCell.roomList then
        metaCell.roomList:remove(roomDef)
    end
    if metaCell.roomByMetaId then
        metaCell.roomByMetaId:remove(roomDef.metaId)
    end
    roomDef:setBuilding(nil)
end

---@param roomDefs ArrayList
---@param metaCell IsoMetaCell
---@return nil
local function removeRoomDefsFromMetaCell(roomDefs, metaCell)
    for i = 0, roomDefs:size() - 1 do
        removeRoomDefFromMetaCell(metaCell, roomDefs:get(i))
    end
end

---@param buildingDef BuildingDef
---@param loading boolean?
---@return boolean
local function removeBuildingFromWorld(buildingDef, loading)
    local metaGrid = getWorld():getMetaGrid()
    local metaCell = metaGrid:getCellData(buildingDef:getCellX(), buildingDef:getCellY())
    if not metaCell then
        return false
    end

    metaCell:removeRooms(buildingDef:getRooms())
    metaCell:removeRooms(buildingDef:getEmptyOutside())
    metaGrid:removeRoomsFromAdjacentCells(buildingDef)

    removeRoomDefsFromMetaCell(buildingDef:getRooms(), metaCell)
    removeRoomDefsFromMetaCell(buildingDef:getEmptyOutside(), metaCell)

    if metaCell.buildings then
        metaCell.buildings:remove(buildingDef)
    end
    if metaCell.buildingByMetaId then
        metaCell.buildingByMetaId:remove(buildingDef.metaId)
    end

    metaGrid:getBuildings():remove(buildingDef)
    buildingDef:getRooms():clear()
    buildingDef:getEmptyOutside():clear()
    buildingDef:resetMinMaxLevel()
    refreshRoomMetadata(loading)
    return true
end

---@param structureId string
---@param rect table
---@param clearRecord boolean?
---@param loading boolean?
---@return boolean
function RoomPersistence.removeRoomByRect(structureId, rect, clearRecord, loading)
    local roomDef = RoomPersistence.getRoomDef(structureId, rect)
    local buildingDef = nil
    if roomDef then
        buildingDef = roomDef:getBuilding()
    end

    if not roomDef or not buildingDef then
        if clearRecord ~= false then
            RoomPersistence.forgetRoom(structureId, rect)
        end
        return false
    end

    local removed = removeBuildingFromWorld(buildingDef, loading)

    if clearRecord ~= false then
        RoomPersistence.forgetRoom(structureId, rect)
    end

    return removed
end

---@param structureId string
---@param rects table[]
---@param clearRecord boolean?
---@param loading boolean?
---@return boolean
function RoomPersistence.removeRoomByRects(structureId, rects, clearRecord, loading)
    if type(rects) ~= "table" or #rects == 0 then return false end

    local anyRemoved = false
    for i = 1, #rects do
        if RoomPersistence.removeRoomByRect(structureId, rects[i], false, loading) then
            anyRemoved = true
        end
    end

    if clearRecord ~= false then
        RoomPersistence.forgetRoomByRects(structureId, rects)
    end

    return anyRemoved
end

---@param record table
---@return table[]|nil
---@nodiscard
local function getRectsFromRecord(record)
    if type(record.rects) ~= "table" or #record.rects == 0 then return nil end
    ---@type table[]
    local rects = {}
    for i = 1, #record.rects do
        local r = RoomPersistence.getRectFromRecord(record.rects[i])
        if r then rects[#rects + 1] = r end
    end
    if #rects == 0 then return nil end
    return rects
end

---@param entry table  { structureId, rect?, rects? }
---@return string
---@nodiscard
local function recordKeyForEntry(entry)
    if entry.rects then return rectsRecordKey(entry.structureId, entry.rects) end
    return recordKey(entry.structureId, entry.rect)
end

---@param rooms table[]?
---@param loading boolean?
---@return nil
function RoomPersistence.syncRoomRecords(rooms, loading)
    RoomPersistence.ensureAssignmentDefs(rooms)

    ---@type table<string, boolean>
    local desiredRooms = {}
    ---@type table[]
    local nextSyncedRooms = {}

    if rooms then
        for i = 1, #rooms do
            local record = rooms[i]
            if Registry.getStructure(record.structureId) then
                local rects = getRectsFromRecord(record)
                if rects then
                    local key = rectsRecordKey(record.structureId, rects)
                    desiredRooms[key] = true
                    nextSyncedRooms[#nextSyncedRooms + 1] = { structureId = record.structureId, rects = rects }
                    RoomPersistence.createRoom(record.structureId, { rects = rects }, loading)
                else
                    local rect = RoomPersistence.getRectFromRecord(record)
                    if rect then
                        local key = recordKey(record.structureId, rect)
                        desiredRooms[key] = true
                        nextSyncedRooms[#nextSyncedRooms + 1] = { structureId = record.structureId, rect = rect }
                        RoomPersistence.createRoom(record.structureId, rect, loading)
                    end
                end
            end
        end
    end

    for i = #syncedRooms, 1, -1 do
        local synced = syncedRooms[i]
        if desiredRooms[recordKeyForEntry(synced)] == nil then
            if synced.rects then
                RoomPersistence.removeRoomByRect(synced.structureId, synced.rects[1], false, loading)
            else
                RoomPersistence.removeRoomByRect(synced.structureId, synced.rect, false, loading)
            end
        end
    end

    syncedRooms = nextSyncedRooms
end

---@param loading boolean?
---@return nil
function RoomPersistence.restorePersistedRooms(loading)
    RoomPersistence.restoreLoadedRoomDefs(loading)
    RoomPersistence.syncRoomRecords(RoomPersistence.getRoomRecords(), loading)
end

return RoomPersistence
