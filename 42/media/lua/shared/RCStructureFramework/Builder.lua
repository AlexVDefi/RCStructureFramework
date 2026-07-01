local Registry = require("RCStructureFramework/Registry")
local PlacementHelpers = require("RCStructureFramework/PlacementHelpers")
local Events = require("RCStructureFramework/Events")
---@class RCStructureFrameworkBuilder
local Builder = {}

---@param structureId string
---@param character IsoPlayer
---@param container InventoryItem
---@param plan table
---@return boolean
function Builder.buildFromContainer(structureId, character, container, plan)
    local def = Registry.requireStructure(structureId)
    if def.buildFromContainer then
        return def.buildFromContainer(character, container, plan)
    end
    return false
end

---@param def table
---@param plan table
---@param wall table
---@return string|nil
---@nodiscard
local function resolveWallSprite(def, plan, wall)
    if type(wall.spriteName) == "string" and wall.spriteName ~= "" then
        return wall.spriteName
    end
    return Registry.getPieceSpriteName(def.id, plan.variant or plan.color, wall.wallType, wall.north == true)
end

---@param def table
---@param plan table
---@param cell table
---@return string|nil
---@nodiscard
local function resolveCellSprite(def, plan, cell)
    if type(cell.spriteName) == "string" and cell.spriteName ~= "" then
        return cell.spriteName
    end
    if type(def.getCellSpriteName) == "function" then
        return def.getCellSpriteName(plan.variant or plan.color, cell)
    end
    return nil
end

---@param placed table  IsoObject[]
---@param consumed table?  list of { source, req } entries to refund in reverse order
local function rollback(placed, consumed)
    for i = #placed, 1, -1 do
        PlacementHelpers.removeObject(placed[i])
    end
    if consumed then
        for i = #consumed, 1, -1 do
            local entry = consumed[i]
            if entry.source and type(entry.source.refund) == "function" then
                entry.source:refund(entry.req)
            end
        end
    end
end

---@param materialSource table?
---@param req table?
---@param consumed table?  appended to with { source, req } when consumption succeeds
---@return boolean
local function consumeIfPossible(materialSource, req, consumed)
    if materialSource == nil or req == nil then return true end
    if type(materialSource.canConsume) == "function" and materialSource:canConsume(req) ~= true then
        return false
    end
    if type(materialSource.consume) == "function" then
        if materialSource:consume(req) == false then return false end
        if consumed then
            consumed[#consumed + 1] = { source = materialSource, req = req }
        end
    end
    return true
end

---@param def table
---@param piece table
---@return table?
---@nodiscard
local function pieceMaterialRequirement(def, piece)
    if type(def.getPieceMaterialRequirement) == "function" then
        return def.getPieceMaterialRequirement(piece)
    end
    return nil
end

local kindOrder = {}
local kindByName = {}

---@param name string
---@param handler table
---@return boolean
function Builder.registerPieceKind(name, handler)
    if type(name) ~= "string" or name == "" then return false end
    if type(handler) ~= "table" then return false end
    if type(handler.place) ~= "function" then return false end
    if type(handler.arrayKey) ~= "string" or handler.arrayKey == "" then return false end

    if kindByName[name] then
        for i = 1, #kindOrder do
            if kindOrder[i].name == name then
                kindOrder[i] = { name = name, handler = handler }
                kindByName[name] = handler
                return true
            end
        end
    end
    kindOrder[#kindOrder + 1] = { name = name, handler = handler }
    kindByName[name] = handler
    return true
end

---@param name string
function Builder.unregisterPieceKind(name)
    if not kindByName[name] then return end
    kindByName[name] = nil
    for i = #kindOrder, 1, -1 do
        if kindOrder[i].name == name then
            table.remove(kindOrder, i)
        end
    end
end

---@param name string
---@return table|nil
---@nodiscard
function Builder.getPieceKindHandler(name)
    return kindByName[name]
end

---@return string[]
---@nodiscard
function Builder.getPieceKinds()
    local copy = {}
    for i = 1, #kindOrder do copy[i] = kindOrder[i].name end
    return copy
end

---@type table
local wallHandler = {
    arrayKey = "walls",
    ---@param wall table
    ---@param ctx table
    ---@return IsoObject|nil, string|nil
    place = function(wall, ctx)
        local sprite = resolveWallSprite(ctx.def, ctx.plan, wall)
        if not sprite then return nil, "missing wall sprite" end
        if not ctx.consumeMaterial(wall) then return nil, "out of materials (wall)" end
        local square = PlacementHelpers.ensureSquare(wall.x, wall.y, wall.z)
        if not square then return nil, "invalid wall square" end
        local slotKind = wall.slotKind
        if type(slotKind) ~= "string" or slotKind == "" then
            slotKind = "wall"
        end
        local configureWall = ctx.options.configureWallObject or ctx.def.configureWallObject
        local obj = PlacementHelpers.placeWallObject(square, wall.north == true, sprite, slotKind, {
            structureId = ctx.structureId,
            openSpriteName = wall.openSpriteName,
            ---@param o IsoObject
            configureObject = function(o)
                if configureWall then configureWall(o, wall, ctx.plan) end
            end,
            modDataExtra = wall.wallType and { wallType = wall.wallType } or nil,
        })
        if not obj then return nil, "wall placement failed" end
        return obj
    end,
}

---@type table
local cellHandler = {
    arrayKey = "cells",
    ---@param cell table
    ---@param ctx table
    ---@return IsoObject|nil, string|nil
    place = function(cell, ctx)
        local sprite = resolveCellSprite(ctx.def, ctx.plan, cell)
        if not sprite then return nil end
        if not ctx.consumeMaterial(cell) then return nil, "out of materials (cell)" end
        local square = PlacementHelpers.ensureSquare(cell.x, cell.y, cell.z)
        if not square then return nil, "invalid cell square" end
        local configureCell = ctx.options.configureCellObject or ctx.def.configureCellObject
        if cell.isRug == true then
            local rug = PlacementHelpers.placeRugObject(square, sprite, {
                structureId = ctx.structureId,
                ---@param o IsoObject
                configureObject = function(o)
                    if configureCell then configureCell(o, cell, ctx.plan) end
                end,
            })
            return rug
        end
        local obj = PlacementHelpers.placeFloorObject(square, sprite, {
            structureId = ctx.structureId,
            ---@param o IsoObject
            configureObject = function(o)
                if configureCell then configureCell(o, cell, ctx.plan) end
            end,
        })
        return obj
    end,
}

---@type table
local roofHandler = {
    arrayKey = "roofs",
    ---@param roof table
    ---@param ctx table
    ---@return IsoObject|nil, string|nil
    place = function(roof, ctx)
        local sprite = roof.spriteName
        if type(sprite) ~= "string" or sprite == "" then return nil end
        if not ctx.consumeMaterial(roof) then return nil, "out of materials (roof)" end
        local square = PlacementHelpers.ensureSquare(roof.x, roof.y, roof.z)
        if not square then return nil, "invalid roof square" end
        local configureRoof = ctx.options.configureRoofObject or ctx.def.configureRoofObject
        local obj = PlacementHelpers.placeRoofObject(square, sprite, roof.north == true, {
            structureId = ctx.structureId,
            ---@param o IsoObject
            configureObject = function(o)
                if configureRoof then configureRoof(o, roof, ctx.plan) end
            end,
            roofKind = roof.roofKind,
        })
        return obj
    end,
}

---@param arrayKey string
---@param category string
---@param placeFn fun(square: IsoGridSquare, sprite: string, north: boolean, opts: table): IsoObject|nil
---@return table
---@nodiscard
local function makeEntityArrayHandler(arrayKey, category, placeFn)
    return {
        arrayKey = arrayKey,
        ---@param entry table
        ---@param ctx table
        ---@return IsoObject|nil, string|nil
        place = function(entry, ctx)
            local sprite = entry.spriteName
            if type(sprite) ~= "string" or sprite == "" then return nil end
            if not ctx.consumeMaterial(entry) then
                return nil, "out of materials (" .. category .. ")"
            end
            local square = PlacementHelpers.ensureSquare(entry.x, entry.y, entry.z)
            if not square then return nil, "invalid " .. category .. " square" end
            local hookKey = "configure" .. category:sub(1, 1):upper() .. category:sub(2) .. "Object"
            local configureFn = ctx.options[hookKey] or ctx.def[hookKey]
            local obj = placeFn(square, sprite, entry.north == true, {
                structureId    = ctx.structureId,
                entityScriptId = entry.entityScriptId,
                utilityHookup  = entry.utilityHookup,
                ---@param o IsoObject
            configureObject = function(o)
                    if configureFn then configureFn(o, entry, ctx.plan) end
                end,
            })
            return obj
        end,
    }
end

local furnitureHandler  = makeEntityArrayHandler("furniture",   "furniture",  PlacementHelpers.placeFurniture)
local applianceHandler  = makeEntityArrayHandler("appliances",  "appliance",  PlacementHelpers.placeAppliance)
local decorativeHandler = makeEntityArrayHandler("decoratives", "decorative", PlacementHelpers.placeDecorative)
local vegetationHandler = makeEntityArrayHandler("vegetation",  "vegetation", PlacementHelpers.placeVegetation)

Builder.registerPieceKind("wall", wallHandler)
Builder.registerPieceKind("cell", cellHandler)
Builder.registerPieceKind("roof", roofHandler)
Builder.registerPieceKind("furniture", furnitureHandler)
Builder.registerPieceKind("appliance", applianceHandler)
Builder.registerPieceKind("decorative", decorativeHandler)
Builder.registerPieceKind("vegetation", vegetationHandler)

---@param structureId string
---@param character IsoPlayer
---@param materialSource table?
---@param plan table
---@param options table?  { configureWallObject?, configureCellObject?, configureRoofObject?, container? }
---@return table
function Builder.buildFromPlan(structureId, character, materialSource, plan, options)
    local def = Registry.requireStructure(structureId)
    options = options or {}

    if def.useGenericBuilder ~= true then
        local container = options.container
        local ok = false
        if def.buildFromContainer then
            ok = def.buildFromContainer(character, container, plan) == true
        end
        if ok then
            Events.fireStructureBuilt(structureId, plan, character, {})
        end
        return { success = ok, placed = {}, failed = {}, reason = ok and nil or "legacy builder failed" }
    end

    if type(def.synthesizeRoofs) == "function" then
        def.synthesizeRoofs(plan)
    end

    local placed = {}
    local consumed = {}

    local ctx = {
        structureId = structureId,
        def = def,
        character = character,
        materialSource = materialSource,
        plan = plan,
        options = options,
        placed = placed,
        consumed = consumed,
    }
    ---@param piece table
    ---@return boolean
    function ctx.consumeMaterial(piece)
        local req = pieceMaterialRequirement(def, piece)
        return consumeIfPossible(materialSource, req, consumed)
    end

    if type(def.beforeBuild) == "function" then
        local ok = def.beforeBuild(plan, character, placed, materialSource, options)
        if ok == false then
            rollback(placed, consumed)
            return { success = false, placed = {}, failed = {}, reason = "beforeBuild rejected" }
        end
    end

    for ki = 1, #kindOrder do
        local entry = kindOrder[ki]
        local handler = entry.handler
        local arr = plan[handler.arrayKey]
        if type(arr) == "table" then
            for i = 1, #arr do
                local piece = arr[i]
                local obj, err = handler.place(piece, ctx)
                if err then
                    rollback(placed, consumed)
                    return { success = false, placed = {}, failed = { piece }, reason = err }
                end
                if obj then
                    placed[#placed + 1] = obj
                end
            end
        end
    end

    if type(def.afterBuild) == "function" then
        local ok = def.afterBuild(plan, character, placed, materialSource, options)
        if ok == false then
            rollback(placed, consumed)
            return { success = false, placed = {}, failed = {}, reason = "afterBuild rejected" }
        end
    end

    Events.fireStructureBuilt(structureId, plan, character, placed)
    return { success = true, placed = placed, failed = {} }
end

---@param structureId string
---@param object IsoObject
---@param character IsoPlayer
---@return boolean
function Builder.buildCompletion(structureId, object, character)
    local def = Registry.requireStructure(structureId)
    if def.buildCompletion then
        return def.buildCompletion(object, character)
    end
    return false
end

---@param def table
---@param materialSource table?
---@param obj IsoObject
local function refundObjectViaMaterialSource(def, materialSource, obj)
    if not materialSource or type(materialSource.refund) ~= "function" then return end
    if not obj or type(obj.getModData) ~= "function" then return end

    local modData = obj:getModData()
    local tag = modData and modData.RCStructureFramework
    if type(tag) ~= "table" then return end

    local req = nil
    if type(def.getPieceMaterialRequirement) == "function" then
        req = def.getPieceMaterialRequirement({
            x = tag.x, y = tag.y, z = tag.z,
            spriteName = tag.spriteName,
            slotKind = tag.slotKind,
            wallType = tag.wallType,
            roofKind = tag.roofKind,
            pieceCategory = tag.pieceCategory,
            _generated = tag._generated,
        })
    end
    if not req then return end
    materialSource:refund(req)
end

---@param structureId string
---@param character IsoPlayer
---@param options table
---@return table
function Builder.disassembleFromPlan(structureId, character, options)
    local def = Registry.requireStructure(structureId)
    options = options or {}

    local data = options.data
    if not data then
        return { success = false, removed = {}, reason = "data" }
    end

    local objects = options.objects
    if not objects then
        if type(def.getRemovableObjects) == "function" then
            objects = def.getRemovableObjects(data) or {}
        else
            objects = {}
        end
    end

    if type(def.beforeDisassemble) == "function" then
        local ok = def.beforeDisassemble(objects, data, character, options.materialSource)
        if ok == false then
            return { success = false, removed = {}, reason = "beforeDisassemble" }
        end
    end

    local removed = {}
    local refundEachPiece = def.refundViaMaterialSource == true
    for i = #objects, 1, -1 do
        local obj = objects[i]
        if obj then
            if refundEachPiece then
                refundObjectViaMaterialSource(def, options.materialSource, obj)
            end
            if PlacementHelpers.removeObject(obj) then
                removed[#removed + 1] = obj
            end
        end
    end

    if type(def.afterDisassemble) == "function" then
        def.afterDisassemble(objects, data, character, options.materialSource, removed)
    end

    Events.fireStructureDisassembled(structureId, character, removed)
    return { success = true, removed = removed }
end

---@param structureId string
---@param width integer
---@param height integer
---@param requestedAxis string?
---@return string|nil
---@nodiscard
function Builder.getGableAxis(structureId, width, height, requestedAxis)
    local def = Registry.requireStructure(structureId)
    if def.getGableAxis then
        return def.getGableAxis(width, height, requestedAxis)
    end
    return nil
end

---@param structureId string
---@param rect table
---@param gableAxis string?
---@return integer
---@nodiscard
function Builder.getRoofPieceCount(structureId, rect, gableAxis)
    local def = Registry.requireStructure(structureId)
    if def.getRoofPieceCount then
        return def.getRoofPieceCount(rect, gableAxis)
    end
    return 0
end

---@param structureId string
---@param rect table
---@param variant string
---@param gableAxis string?
---@return table
---@nodiscard
function Builder.getRoofPreview(structureId, rect, variant, gableAxis)
    local def = Registry.requireStructure(structureId)
    if def.getRoofPreview then
        return def.getRoofPreview(rect, variant, gableAxis)
    end
    return {}
end

---@param structureId string
---@return integer
---@nodiscard
function Builder.getMinimumContainerMaterialCount(structureId)
    local def = Registry.requireStructure(structureId)
    if def.getMinimumContainerMaterialCount then
        return def.getMinimumContainerMaterialCount()
    end
    return 0
end

return Builder
