local RoomPersistence = require("RCStructureFramework/RoomPersistence")
---@class RCStructureFrameworkSystem
local System = {}

---@param key string
---@param data table?
---@return nil
local function onReceiveGlobalModData(key, data)
    if key ~= RoomPersistence.MOD_DATA_KEY then return end
    local rooms = data and data.rooms
    RoomPersistence.syncRoomRecords(rooms, getCell() == nil)
end

---@return nil
local function onLoadedMapZones()
    if isClient() then
        ModData.request(RoomPersistence.MOD_DATA_KEY)
    elseif isServer() then
        RoomPersistence.restorePersistedRooms(true)
    else
        RoomPersistence.restorePersistedRooms(true)
    end
end

local registered = false

---@return nil
function System.registerEvents()
    if registered then return end
    registered = true
    Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)
    Events.OnLoadedMapZones.Add(onLoadedMapZones)
end

---@return nil
function System.unregisterEvents()
    if not registered then return end
    registered = false
    Events.OnReceiveGlobalModData.Remove(onReceiveGlobalModData)
    Events.OnLoadedMapZones.Remove(onLoadedMapZones)
end

return System
