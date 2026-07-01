---@type table<string, table>
local RCStructureFramework = {
    PieceLibrary = require("RCStructureFramework/PieceLibrary"),
    PlacementHelpers = require("RCStructureFramework/PlacementHelpers"),
    Registry = require("RCStructureFramework/Registry"),
    Geometry = require("RCStructureFramework/Geometry"),
    Plans = require("RCStructureFramework/Plans"),
    Footprints = require("RCStructureFramework/Footprints"),
    MaterialContainers = require("RCStructureFramework/MaterialContainers"),
    MaterialSource = require("RCStructureFramework/MaterialSource"),
    RecipeSource = require("RCStructureFramework/RecipeSource"),
    Migrations = require("RCStructureFramework/Migrations"),
    Json = require("RCStructureFramework/Json"),
    Presets = require("RCStructureFramework/Presets"),
    RoomPersistence = require("RCStructureFramework/RoomPersistence"),
    PlannedConstructions = require("RCStructureFramework/PlannedConstructions"),
    PiecePresence = require("RCStructureFramework/PiecePresence"),
    DefaultValidators = require("RCStructureFramework/DefaultValidators"),
    PlacementValidation = require("RCStructureFramework/PlacementValidation"),
    Builder = require("RCStructureFramework/Builder"),
    BuildRecipeCallbacks = require("RCStructureFramework/BuildRecipeCallbacks"),
    Events = require("RCStructureFramework/Events"),
    Rooms = require("RCStructureFramework/Rooms"),
    Build = require("RCStructureFramework/Build"),
    Capture = require("RCStructureFramework/Capture"),
    Introspect = require("RCStructureFramework/Introspect"),
}

-- Dev-friendly top-level shortcuts (see docs/reference/api.md):
RCStructureFramework.build = RCStructureFramework.Build.build
RCStructureFramework.defineStructure = RCStructureFramework.Registry.defineStructure

RCStructureFramework.System = require("RCStructureFramework/System")
RCStructureFramework.RoomLighting = require("RCStructureFramework/RoomLighting")
RCStructureFramework.SpritePropertyPatcher = require("RCStructureFramework/SpritePropertyPatcher")
RCStructureFramework.Config = require("RCStructureFramework/Config")

RCStructureFramework.RoomLighting.setRoomFilter(function(roomName)
    return RCStructureFramework.Registry.getStructureByRoomName(roomName) ~= nil
end)

local EventRegistration = require("RCStructureFramework/EventRegistration")
EventRegistration.wire("roomLighting",
    RCStructureFramework.RoomLighting.registerEvents,
    RCStructureFramework.RoomLighting.unregisterEvents)
EventRegistration.wire("spritePatcher",
    RCStructureFramework.SpritePropertyPatcher.registerEvents,
    RCStructureFramework.SpritePropertyPatcher.unregisterEvents)
EventRegistration.wire("roomSync",
    RCStructureFramework.System.registerEvents,
    RCStructureFramework.System.unregisterEvents)
EventRegistration.wire("materialContainers",
    RCStructureFramework.MaterialContainers.registerEvents,
    RCStructureFramework.MaterialContainers.unregisterEvents)
EventRegistration.wire("plannedConstructions",
    RCStructureFramework.PlannedConstructions.registerEvents,
    RCStructureFramework.PlannedConstructions.unregisterEvents)

---@param key string
---@return boolean
function RCStructureFramework.enable(key)
    return EventRegistration.enable(key)
end

---@param key string
---@return boolean
function RCStructureFramework.disable(key)
    return EventRegistration.disable(key)
end

_G.RCStructureFramework = RCStructureFramework
_G.RCSF = RCStructureFramework

return RCStructureFramework
