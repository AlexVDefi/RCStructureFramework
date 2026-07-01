---See docs/reference/api.md (SpritePropertyPatcher) for the public API.
---@class RCStructureFrameworkSpritePropertyPatcher
local SpritePropertyPatcher = {}

local MOD_DATA_KEY = "RCStructureFramework"

---@type table<string, boolean>
local mutatedSprites = {}

---@param spriteName string
---@param north boolean
---@param slotKind string  "doorframe" | "windowframe"
---@return nil
function SpritePropertyPatcher.applyToSprite(spriteName, north, slotKind)
    if type(spriteName) ~= "string" or spriteName == "" then return end
    if slotKind ~= "doorframe" and slotKind ~= "windowframe" then return end

    local cacheKey = spriteName .. (north and "|N|" or "|W|") .. slotKind
    if mutatedSprites[cacheKey] then return end

    local sprite = IsoSpriteManager.instance:getSprite(spriteName)
    if not sprite then return end
    local props = sprite:getProperties()

    if slotKind == "doorframe" then
        if north then
            props:set(IsoFlagType.DoorWallN)
            props:set(IsoFlagType.canPathN)
        else
            props:set(IsoFlagType.DoorWallW)
            props:set(IsoFlagType.canPathW)
        end
    else
        if north then
            props:set(IsoFlagType.WindowN)
        else
            props:set(IsoFlagType.WindowW)
        end
    end

    mutatedSprites[cacheKey] = true
end

---@param obj IsoObject
---@return nil
local function patchFromObject(obj)
    if not obj then return end
    if not instanceof(obj, "IsoThumpable") then return end
    local md = obj:getModData()
    local tag = md and md[MOD_DATA_KEY]
    if type(tag) ~= "table" then return end
    local slotKind = tag.slotKind
    if slotKind ~= "doorframe" and slotKind ~= "windowframe" then return end
    local spriteName = tag.spriteName
    if type(spriteName) ~= "string" or spriteName == "" then
        spriteName = obj:getSpriteName()
    end
    SpritePropertyPatcher.applyToSprite(spriteName, obj:getNorth() == true, slotKind)
end

---@param square IsoGridSquare
---@return nil
local function onLoadGridsquare(square)
    if not square then return end
    local objs = square:getSpecialObjects()
    if not objs then return end
    local size = objs:size()
    if size == 0 then return end
    for i = 0, size - 1 do
        patchFromObject(objs:get(i))
    end
end

---@param obj IsoObject
---@return nil
local function onObjectAdded(obj)
    patchFromObject(obj)
end

local registered = false

---@return nil
function SpritePropertyPatcher.registerEvents()
    if registered then return end
    registered = true
    Events.LoadGridsquare.Add(onLoadGridsquare)
    Events.OnObjectAdded.Add(onObjectAdded)
end

---@return nil
function SpritePropertyPatcher.unregisterEvents()
    if not registered then return end
    registered = false
    Events.LoadGridsquare.Remove(onLoadGridsquare)
    Events.OnObjectAdded.Remove(onObjectAdded)
end

return SpritePropertyPatcher
