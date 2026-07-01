local Geometry = require("RCStructureFramework/Geometry")
local SpritePropertyPatcher = require("RCStructureFramework/SpritePropertyPatcher")
---@class RCStructureFrameworkPlacementHelpers
local PlacementHelpers = {}

PlacementHelpers.MOD_DATA_KEY = "RCStructureFramework"

---@param obj IsoObject
---@param structureId string
---@param pieceCategory string
---@param spriteName string?
---@param slotKind string?
---@param extra table?
---@return nil
local function tagPlacedObject(obj, structureId, pieceCategory, spriteName, slotKind, extra)
    if not obj then return end
    local modData = obj:getModData()
    local entry = modData[PlacementHelpers.MOD_DATA_KEY]
    if type(entry) ~= "table" then
        entry = {}
        modData[PlacementHelpers.MOD_DATA_KEY] = entry
    end
    entry.structureId = structureId
    entry.pieceCategory = pieceCategory
    if spriteName then entry.spriteName = spriteName end
    if slotKind then entry.slotKind = slotKind end
    if type(extra) == "table" then
        for k, v in pairs(extra) do
            entry[k] = v
        end
    end
    if obj.transmitModData then
        obj:transmitModData()
    end
end

PlacementHelpers.tagPlacedObject = tagPlacedObject

---@param object IsoObject
---@return nil
local function transmitObject(object)
    if isClient() and object.transmitCompleteItemToServer then
        object:transmitCompleteItemToServer()
    elseif isServer() and object.transmitCompleteItemToClients then
        object:transmitCompleteItemToClients()
    end
end

---@param square IsoGridSquare
---@return nil
local function finalizeConstruction(square)
    buildUtil.setHaveConstruction(square, true)
    square:RecalcAllWithNeighbours(true)
    square:setSquareChanged()
end

---@param spriteName string
---@return IsoSprite|nil
---@nodiscard
local function getSpriteByName(spriteName)
    if type(spriteName) ~= "string" or spriteName == "" then return nil end
    local mgr = IsoSpriteManager.instance
    if not mgr then return nil end
    return mgr:getSprite(spriteName)
end

---@param x integer
---@param y integer
---@param z integer
---@return IsoGridSquare|nil
function PlacementHelpers.ensureSquare(x, y, z)
    return Geometry.ensureSquare(x, y, z)
end

---@param sprite IsoSprite|nil
---@return integer
---@nodiscard
local function doorOpenOffset(sprite)
    if not sprite then return 2 end
    local props = sprite:getProperties()
    if not props then return 2 end
    if props:has(IsoPropertyType.GARAGE_DOOR) then return 8 end
    if props:has(IsoPropertyType.DOUBLE_DOOR) then return 4 end
    return 2
end

---@param sprite IsoSprite
---@param spriteName string
---@return IsoSprite closedSprite
---@return string closedSpriteName
---@nodiscard
local function resolveClosedDoorSprite(sprite, spriteName)
    local props = sprite:getProperties()
    if not props or not props:has(IsoFlagType.open) then
        return sprite, spriteName
    end
    local offset = doorOpenOffset(sprite)
    local closed = IsoSprite.getSprite(IsoSpriteManager.instance, sprite, -offset)
    if not closed then
        return sprite, spriteName
    end
    local closedName = closed.getName and closed:getName() or spriteName
    return closed, closedName
end

---@param square IsoGridSquare
---@param north boolean
---@param spriteName string
---@param slotKind string  "wall" | "door" | "window"
---@param options table?  { structureId, configureObject(obj), modDataExtra, openSpriteName }
---@return IsoObject|nil
function PlacementHelpers.placeWallObject(square, north, spriteName, slotKind, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local cell = getCell()
    local object = nil
    local resolvedOpenSpriteName = options.openSpriteName

    if slotKind == "door" then
        local sprite = getSpriteByName(spriteName)
        if sprite then
            local closed, closedName = resolveClosedDoorSprite(sprite, spriteName)
            if closed ~= sprite and not resolvedOpenSpriteName then
                resolvedOpenSpriteName = spriteName
            end
            sprite = closed
            spriteName = closedName
            object = IsoDoor.new(cell, square, sprite, north == true)
        end
    elseif slotKind == "window" then
        local sprite = getSpriteByName(spriteName)
        if sprite then
            object = IsoWindow.new(cell, square, sprite, north == true)
        end
    else
        object = IsoThumpable.new(cell, square, spriteName, north == true)
        if object then
            if slotKind == "doorframe" then
                object:setName(getText("IGUI_RCStructureFramework_DoorFrame"))
                object:setIsDoorFrame(true)
                object:setCanPassThrough(true)
                object:setIsThumpable(false)
                SpritePropertyPatcher.applyToSprite(spriteName, north == true, "doorframe")
            elseif slotKind == "windowframe" then
                object:setName(getText("IGUI_RCStructureFramework_WindowFrame"))
                SpritePropertyPatcher.applyToSprite(spriteName, north == true, "windowframe")
            else
                object:setName(getText("IGUI_RCStructureFramework_WallRegular"))
            end
        end
    end

    if not object then
        return nil
    end

    if resolvedOpenSpriteName and object.setOpenSprite then
        local openSprite = getSpriteByName(resolvedOpenSpriteName)
        if openSprite then object:setOpenSprite(openSprite) end
    end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    square:AddSpecialObject(object)
    transmitObject(object)

    if options.structureId then
        tagPlacedObject(object, options.structureId, "wall", spriteName, slotKind, options.modDataExtra)
    end

    finalizeConstruction(square)
    return object
end

---@param square IsoGridSquare
---@param spriteName string
---@param options table?  { structureId, configureObject(obj), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeFloorObject(square, spriteName, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local object = square:addFloor(spriteName)
    if not object then
        return nil
    end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    if options.structureId then
        tagPlacedObject(object, options.structureId, "cell", spriteName, nil, options.modDataExtra)
    end

    buildUtil.setHaveConstruction(square, true)
    return object
end

---@param square IsoGridSquare
---@param spriteName string
---@param options table?  { structureId, configureObject(obj), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeRugObject(square, spriteName, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local object = IsoObject.new(getCell(), square, spriteName)
    if not object then
        return nil
    end

    local sprite = object:getSprite()
    if sprite then
        local props = sprite:getProperties()
        if props and not props:has(IsoFlagType.solidfloor) then
            props:set(IsoFlagType.solidfloor)
        end
    end

    square:getObjects():add(object)

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    if options.structureId then
        local extra = options.modDataExtra
        extra = extra or {}
        extra.rug = true
        tagPlacedObject(object, options.structureId, "cell", spriteName, "rug", extra)
    end

    transmitObject(object)
    square:RecalcAllWithNeighbours(true)
    square:setSquareChanged()
    return object
end

---@param square IsoGridSquare
---@return boolean
---@nodiscard
function PlacementHelpers.squareHasRug(square)
    if not square or type(square.getObjects) ~= "function" then return false end
    local objs = square:getObjects()
    if not objs or type(objs.size) ~= "function" then return false end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj then
            local md = obj.getModData and obj:getModData() or nil
            local tag = md and md[PlacementHelpers.MOD_DATA_KEY]
            if type(tag) == "table" and tag.rug == true then
                return true
            end
            local name = obj.getSpriteName and obj:getSpriteName() or nil
            if type(name) ~= "string" or name == "" then
                local sprite = obj.getSprite and obj:getSprite() or nil
                name = sprite and sprite.getName and sprite:getName() or nil
            end
            if type(name) == "string" and string.sub(name, 1, 12) == "floors_rugs_" then
                return true
            end
        end
    end
    return false
end

---@param square IsoGridSquare
---@param spriteName string
---@param north boolean
---@param options table?  { structureId, configureObject(obj), modDataExtra, roofKind }
---@return IsoObject|nil
function PlacementHelpers.placeRoofObject(square, spriteName, north, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local object = IsoThumpable.new(getCell(), square, spriteName, north == true)
    if not object then
        return nil
    end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    square:AddSpecialObject(object)
    transmitObject(object)

    if options.structureId then
        local extra = options.modDataExtra
        if options.roofKind then
            extra = extra or {}
            extra.roofKind = options.roofKind
        end
        tagPlacedObject(object, options.structureId, "roof", spriteName, nil, extra)
    end

    finalizeConstruction(square)
    return object
end

---@param bottomSquare IsoGridSquare
---@param north boolean
---@param def table  { bottomSprite, middleSprite, topSprite, pillarSprite?, name?, health?, modData? }
---@param options table?  { structureId, configureObject(obj, level), modDataExtra }
---@return table|nil  { bottom, middle, top } IsoThumpable trio or nil on failure
function PlacementHelpers.placeStair(bottomSquare, north, def, options)
    if not bottomSquare or type(def) ~= "table" then return nil end
    if type(def.bottomSprite) ~= "string" or def.bottomSprite == "" then return nil end
    if type(def.middleSprite) ~= "string" or def.middleSprite == "" then return nil end
    if type(def.topSprite)    ~= "string" or def.topSprite    == "" then return nil end
    options = options or {}

    local bx, by, bz = bottomSquare:getX(), bottomSquare:getY(), bottomSquare:getZ()
    local mx, my, tx, ty
    if north then
        mx, my = bx, by - 1
        tx, ty = bx, by - 2
    else
        mx, my = bx - 1, by
        tx, ty = bx - 2, by
    end

    local middleSquare = PlacementHelpers.ensureSquare(mx, my, bz)
    if not middleSquare then return nil end
    local topSquare = PlacementHelpers.ensureSquare(tx, ty, bz)
    if not topSquare then return nil end

    local pillar = def.pillarSprite or def.bottomSprite
    local luaobj = ISWoodenStairs:new(
        def.bottomSprite, def.middleSprite, def.topSprite,
        def.bottomSprite, def.middleSprite, def.topSprite,
        pillar, pillar
    )
    luaobj.north = north
    luaobj.sq = bottomSquare
    luaobj.modData = type(def.modData) == "table" and def.modData or {}
    local health = def.health or 500
    ---@return integer
    function luaobj:getHealth() return health end

    ---@param segment any
    ---@param level integer
    ---@param square IsoGridSquare
    ---@param sprite string
    ---@return boolean
    local function configureSegment(segment, level, square, sprite)
        if not segment then return false end
        if segment.setName then segment:setName(def.name or "Stairs") end
        if segment.setCanBarricade then segment:setCanBarricade(false) end
        if segment.setIsDismantable then segment:setIsDismantable(true) end
        if segment.setMaxHealth then segment:setMaxHealth(health) end
        if segment.setHealth then segment:setHealth(health) end
        if segment.setIsStairs then segment:setIsStairs(true) end
        if segment.setBreakSound then segment:setBreakSound("BreakObject") end
        if segment.setModData and type(luaobj.modData) == "table" then
            segment:setModData(copyTable(luaobj.modData))
        end
        if segment.transmitCompleteItemToClients then segment:transmitCompleteItemToClients() end
        if options.structureId then
            local extra = {
                kind  = "stair",
                level = level,
                north = north,
                x = square:getX(), y = square:getY(), z = square:getZ(),
            }
            if type(options.modDataExtra) == "table" then
                for k, v in pairs(options.modDataExtra) do extra[k] = v end
            end
            tagPlacedObject(segment, options.structureId, "stair", sprite, nil, extra)
        end
        if type(options.configureObject) == "function" then
            options.configureObject(segment, level)
        end
        return true
    end

    local bottom = bottomSquare:AddStairs(north, 0, def.bottomSprite, pillar, luaobj)
    if not configureSegment(bottom, 0, bottomSquare, def.bottomSprite) then
        return nil
    end
    local middle = middleSquare:AddStairs(north, 1, def.middleSprite, pillar, luaobj)
    if not configureSegment(middle, 1, middleSquare, def.middleSprite) then
        PlacementHelpers.removeObject(bottom)
        return nil
    end
    local top = topSquare:AddStairs(north, 2, def.topSprite, pillar, luaobj)
    if not configureSegment(top, 2, topSquare, def.topSprite) then
        PlacementHelpers.removeObject(bottom)
        PlacementHelpers.removeObject(middle)
        return nil
    end

    bottomSquare:RecalcAllWithNeighbours(true)
    middleSquare:RecalcAllWithNeighbours(true)
    topSquare:RecalcAllWithNeighbours(true)
    bottomSquare:setSquareChanged()
    middleSquare:setSquareChanged()
    topSquare:setSquareChanged()

    return { bottom = bottom, middle = middle, top = top }
end

---@param bottomX integer
---@param bottomY integer
---@param bottomZ integer
---@param north boolean
---@return integer x, integer y, integer z
---@nodiscard
function PlacementHelpers.getStairLandingTile(bottomX, bottomY, bottomZ, north)
    return Geometry.getStairLandingTile({ x = bottomX, y = bottomY, z = bottomZ, north = north })
end

---@param square IsoGridSquare
---@param north boolean
---@param def table  { spriteName, openSpriteName?, locked?, lockedByKey?, health?, name? }
---@param options table?  { structureId, configureObject(door), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeDoor(square, north, def, options)
    if type(def) ~= "table" or type(def.spriteName) ~= "string" or def.spriteName == "" then
        return nil
    end
    options = options or {}
    local userConfigure = options.configureObject

    local localOpts = {
        structureId  = options.structureId,
        modDataExtra = options.modDataExtra,
        ---@param door any
        configureObject = function(door)
            if def.openSpriteName and door.setOpenSprite then
                local openSprite = getSpriteByName(def.openSpriteName)
                if openSprite then door:setOpenSprite(openSprite) end
            end
            if def.locked == true and door.setLocked then door:setLocked(true) end
            if def.lockedByKey == true and door.setLockedByKey then door:setLockedByKey(true) end
            if def.health and door.setMaxHealth then
                door:setMaxHealth(def.health)
                if door.setHealth then door:setHealth(def.health) end
            end
            if def.name and door.setName then door:setName(def.name) end
            if type(userConfigure) == "function" then userConfigure(door) end
        end,
    }
    return PlacementHelpers.placeWallObject(square, north, def.spriteName, "door", localOpts)
end

---@param square IsoGridSquare
---@param north boolean
---@param def table  { spriteName, openSpriteName?, smashedSpriteName?, smashed?, glassRemoved?, health?, name? }
---@param options table?  { structureId, configureObject(window), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeWindow(square, north, def, options)
    if type(def) ~= "table" or type(def.spriteName) ~= "string" or def.spriteName == "" then
        return nil
    end
    options = options or {}
    local userConfigure = options.configureObject

    local localOpts = {
        structureId  = options.structureId,
        modDataExtra = options.modDataExtra,
        ---@param window any
        configureObject = function(window)
            if def.openSpriteName and window.setOpenSprite then
                local openSprite = getSpriteByName(def.openSpriteName)
                if openSprite then window:setOpenSprite(openSprite) end
            end
            if def.smashedSpriteName and window.setSmashedSprite then
                local smashedSprite = getSpriteByName(def.smashedSpriteName)
                if smashedSprite then window:setSmashedSprite(smashedSprite) end
            end
            if def.smashed == true and window.setSmashed then window:setSmashed(true) end
            if def.glassRemoved == true and window.setGlassRemoved then window:setGlassRemoved(true) end
            if def.health and window.setMaxHealth then
                window:setMaxHealth(def.health)
                if window.setHealth then window:setHealth(def.health) end
            end
            if def.name and window.setName then window:setName(def.name) end
            if type(userConfigure) == "function" then userConfigure(window) end
        end,
    }
    return PlacementHelpers.placeWallObject(square, north, def.spriteName, "window", localOpts)
end

---@param object IsoObject
---@return boolean
---@param square IsoGridSquare
---@param spriteName string
---@param north boolean
---@param options table?  { structureId, configureObject(obj), modDataExtra, entityScriptId }
---@return IsoObject|nil
function PlacementHelpers.placeFurniture(square, spriteName, north, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local object = IsoThumpable.new(getCell(), square, spriteName, north == true)
    if not object then return nil end

    if options.entityScriptId and type(object.getModData) == "function" then
        local md = object:getModData()
        if md then md.entityScriptId = options.entityScriptId end
    end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    if options.structureId then
        tagPlacedObject(object, options.structureId, "furniture", spriteName, nil, options.modDataExtra)
    end

    transmitObject(object)
    buildUtil.setHaveConstruction(square, true)
    finalizeConstruction(square)
    return object
end

---@param square IsoGridSquare
---@param spriteName string
---@param north boolean
---@param options table?  { structureId, configureObject(obj), modDataExtra, entityScriptId, utilityHookup }
---@return IsoObject|nil
function PlacementHelpers.placeAppliance(square, spriteName, north, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    if PlacementHelpers.isLightSwitchSprite(spriteName) then
        return PlacementHelpers.placeLightSwitch(square, spriteName, north, options)
    end

    local object = IsoThumpable.new(getCell(), square, spriteName, north == true)
    if not object then return nil end

    if type(object.getModData) == "function" then
        local md = object:getModData()
        if md then
            if options.entityScriptId  then md.entityScriptId  = options.entityScriptId  end
            if options.utilityHookup   then md.utilityHookup   = options.utilityHookup   end
        end
    end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    if options.structureId then
        tagPlacedObject(object, options.structureId, "appliance", spriteName, nil, options.modDataExtra)
    end

    transmitObject(object)
    buildUtil.setHaveConstruction(square, true)
    finalizeConstruction(square)
    return object
end

---@param spriteName string
---@return boolean
---@nodiscard
function PlacementHelpers.isLightSwitchSprite(spriteName)
    local sprite = getSpriteByName(spriteName)
    if not sprite or type(sprite.getType) ~= "function" then return false end
    local t = sprite:getType()
    return t ~= nil and t == IsoObjectType.lightswitch
end

---@param square IsoGridSquare
---@param spriteName string
---@param north boolean
---@param options table?  { structureId, configureObject(obj), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeLightSwitch(square, spriteName, north, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local sprite = getSpriteByName(spriteName)
    if not sprite then return nil end

    local object = IsoLightSwitch.new(getCell(), square, sprite, square:getRoomID())
    if not object then return nil end

    if type(object.addLightSourceFromSprite) == "function" then
        object:addLightSourceFromSprite()
    end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    square:AddSpecialObject(object)

    if options.structureId then
        local extra = options.modDataExtra
        if north == true then
            extra = extra or {}
            extra.north = true
        end
        tagPlacedObject(object, options.structureId, "appliance", spriteName, nil, extra)
    end

    transmitObject(object)
    finalizeConstruction(square)
    return object
end

---@param square IsoGridSquare
---@param spriteName string
---@param north boolean
---@param options table?  { structureId, configureObject(obj), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeDecorative(square, spriteName, north, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local object = IsoObject.new(getCell(), square, spriteName)
    if not object then return nil end

    if type(options.configureObject) == "function" then
        options.configureObject(object)
    end

    square:AddSpecialObject(object)

    if options.structureId then
        local extra = options.modDataExtra
        if north == true then
            extra = extra or {}
            extra.north = true
        end
        tagPlacedObject(object, options.structureId, "decorative", spriteName, nil, extra)
    end

    transmitObject(object)
    finalizeConstruction(square)
    return object
end

---@param square IsoGridSquare
---@param spriteName string
---@param north boolean
---@param options table?  { structureId, configureObject(obj), modDataExtra }
---@return IsoObject|nil
function PlacementHelpers.placeVegetation(square, spriteName, north, options)
    if not square or type(spriteName) ~= "string" or spriteName == "" then
        return nil
    end
    options = options or {}

    local tree = IsoTree.new(square, spriteName)
    if not tree then return nil end

    if type(options.configureObject) == "function" then
        options.configureObject(tree)
    end

    square:AddTileObject(tree)

    if options.structureId then
        tagPlacedObject(tree, options.structureId, "vegetation", spriteName, nil, options.modDataExtra)
    end

    transmitObject(tree)
    finalizeConstruction(square)
    return tree
end

---@param object IsoObject
---@return boolean
function PlacementHelpers.removeObject(object)
    if not object then return false end
    local square = object:getSquare()
    if not square then return false end

    square:transmitRemoveItemFromSquare(object)
    square:RemoveTileObject(object)
    buildUtil.setHaveConstruction(square, true)
    square:RecalcAllWithNeighbours(true)
    square:setSquareChanged()
    return true
end

return PlacementHelpers
