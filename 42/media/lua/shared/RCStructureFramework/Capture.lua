local Plans = require("RCStructureFramework/Plans")
local Presets = require("RCStructureFramework/Presets")
local PlacementHelpers = require("RCStructureFramework/PlacementHelpers")

---See docs/how-to/capture.md for the passes, options, and accuracy notes.
---@class RCStructureFrameworkCapture
local Capture = {}

local TAG_KEY = PlacementHelpers.MOD_DATA_KEY

---@param obj IsoObject
---@return string|nil
---@nodiscard
local function spriteNameOf(obj)
    if type(obj.getSpriteName) == "function" then
        local n = obj:getSpriteName()
        if type(n) == "string" and n ~= "" then return n end
    end
    local sprite = type(obj.getSprite) == "function" and obj:getSprite() or nil
    if sprite and type(sprite.getName) == "function" then
        local n = sprite:getName()
        if type(n) == "string" and n ~= "" then return n end
    end
    return nil
end

---@param obj IsoObject
---@return PropertyContainer|nil
---@nodiscard
local function spritePropsOf(obj)
    local sprite = type(obj.getSprite) == "function" and obj:getSprite() or nil
    if sprite and type(sprite.getProperties) == "function" then
        return sprite:getProperties()
    end
    return nil
end

---@param props PropertyContainer|nil
---@param flag any
---@return boolean
---@nodiscard
local function hasFlag(props, flag)
    return props ~= nil and flag ~= nil and props:has(flag) == true
end

---@param obj IsoObject
---@return boolean
---@nodiscard
local function objNorth(obj)
    if type(obj.getNorth) == "function" then
        return obj:getNorth() == true
    end
    return false
end

---@param area table
---@return table|nil  { minX, maxX, minY, maxY, minZ, maxZ }
---@nodiscard
local function toBounds(area)
    if type(area) ~= "table" then return nil end

    if type(area.x1) == "number" and type(area.x2) == "number"
        and type(area.y1) == "number" and type(area.y2) == "number" then
        local z1 = type(area.z1) == "number" and area.z1 or 0
        local z2 = type(area.z2) == "number" and area.z2 or z1
        return {
            minX = math.floor(math.min(area.x1, area.x2)),
            maxX = math.floor(math.max(area.x1, area.x2)),
            minY = math.floor(math.min(area.y1, area.y2)),
            maxY = math.floor(math.max(area.y1, area.y2)),
            minZ = math.floor(math.min(z1, z2)),
            maxZ = math.floor(math.max(z1, z2)),
        }
    end

    if type(area.x) == "number" and type(area.y) == "number"
        and type(area.w) == "number" and type(area.h) == "number" then
        local z = type(area.z) == "number" and math.floor(area.z) or 0
        local levels = type(area.levels) == "number" and math.max(1, math.floor(area.levels)) or 1
        return {
            minX = math.floor(area.x),
            maxX = math.floor(area.x + area.w - 1),
            minY = math.floor(area.y),
            maxY = math.floor(area.y + area.h - 1),
            minZ = z,
            maxZ = z + levels - 1,
        }
    end

    return nil
end

---@param plan table
---@param obj IsoObject
---@param tag table
---@param x integer
---@param y integer
---@param z integer
---@param stairSegments table[]
---@return boolean
---@nodiscard
local function captureTagged(plan, obj, tag, x, y, z, stairSegments)
    local category = tag.pieceCategory
    local sprite = tag.spriteName or spriteNameOf(obj)
    if type(category) ~= "string" then return false end

    if category == "wall" then
        plan.walls[#plan.walls + 1] = {
            x = x, y = y, z = z,
            north = objNorth(obj),
            wallType = tag.wallType,
            slotKind = tag.slotKind or "wall",
            spriteName = sprite,
        }
        return true
    elseif category == "cell" then
        plan.cells[#plan.cells + 1] = {
            x = x, y = y, z = z,
            spriteName = sprite,
            isRug = tag.rug == true or nil,
        }
        return true
    elseif category == "roof" then
        plan.roofs[#plan.roofs + 1] = {
            x = x, y = y, z = z,
            north = objNorth(obj),
            spriteName = sprite,
            roofKind = tag.roofKind,
        }
        return true
    elseif category == "furniture" then
        plan.furniture[#plan.furniture + 1] = {
            x = x, y = y, z = z,
            north = objNorth(obj),
            spriteName = sprite,
            defId = tag.entityScriptId,
        }
        return true
    elseif category == "appliance" then
        plan.appliances[#plan.appliances + 1] = {
            x = x, y = y, z = z,
            north = (tag.north == true) or objNorth(obj),
            spriteName = sprite,
            defId = tag.entityScriptId,
        }
        return true
    elseif category == "decorative" then
        plan.decoratives[#plan.decoratives + 1] = {
            x = x, y = y, z = z,
            north = (tag.north == true) or objNorth(obj),
            spriteName = sprite,
        }
        return true
    elseif category == "vegetation" then
        plan.vegetation[#plan.vegetation + 1] = {
            x = x, y = y, z = z,
            spriteName = sprite,
        }
        return true
    elseif category == "stair" then
        stairSegments[#stairSegments + 1] = {
            x = x, y = y, z = z,
            north = (tag.north == true) or objNorth(obj),
            level = type(tag.level) == "number" and tag.level or 0,
            spriteName = sprite,
        }
        return true
    end

    return false
end

---@param plan table
---@param obj IsoObject
---@param x integer
---@param y integer
---@param z integer
---@param captureDecor boolean
---@return string|nil
local function captureHeuristic(plan, obj, x, y, z, captureDecor)
    local sprite = spriteNameOf(obj)
    if not sprite then return nil end
    local props = spritePropsOf(obj)

    if instanceof(obj, "IsoDoor") then
        plan.walls[#plan.walls + 1] = {
            x = x, y = y, z = z,
            north = hasFlag(props, IsoFlagType.doorN) or objNorth(obj),
            slotKind = "door",
            spriteName = sprite,
        }
        return "wall"
    end

    if instanceof(obj, "IsoWindow") then
        plan.walls[#plan.walls + 1] = {
            x = x, y = y, z = z,
            north = hasFlag(props, IsoFlagType.windowN) or objNorth(obj),
            slotKind = "window",
            spriteName = sprite,
        }
        return "wall"
    end

    if hasFlag(props, IsoFlagType.WallN) or hasFlag(props, IsoFlagType.WallNW) then
        plan.walls[#plan.walls + 1] = {
            x = x, y = y, z = z, north = true, slotKind = "wall", spriteName = sprite,
        }
        return "wall"
    end
    if hasFlag(props, IsoFlagType.WallW) then
        plan.walls[#plan.walls + 1] = {
            x = x, y = y, z = z, north = false, slotKind = "wall", spriteName = sprite,
        }
        return "wall"
    end

    if hasFlag(props, IsoFlagType.solidfloor) then
        plan.cells[#plan.cells + 1] = { x = x, y = y, z = z, spriteName = sprite }
        return "cell"
    end

    if captureDecor then
        plan.decoratives[#plan.decoratives + 1] = { x = x, y = y, z = z, spriteName = sprite }
        return "decorative"
    end

    return nil
end

---@param plan table
---@param segments table[]
---@return nil
local function assembleStairs(plan, segments)
    ---@type table<string, table>
    local byPos = {}
    for i = 1, #segments do
        local s = segments[i]
        byPos[s.x .. ":" .. s.y .. ":" .. s.z] = s
    end

    for i = 1, #segments do
        local s = segments[i]
        if s.level == 0 then
            local mid, top
            if s.north then
                mid = byPos[s.x .. ":" .. (s.y - 1) .. ":" .. s.z]
                top = byPos[s.x .. ":" .. (s.y - 2) .. ":" .. s.z]
            else
                mid = byPos[(s.x - 1) .. ":" .. s.y .. ":" .. s.z]
                top = byPos[(s.x - 2) .. ":" .. s.y .. ":" .. s.z]
            end
            plan.stairs[#plan.stairs + 1] = {
                x = s.x, y = s.y, z = s.z,
                north = s.north,
                bottomSprite = s.spriteName,
                middleSprite = mid and mid.spriteName or nil,
                topSprite = top and top.spriteName or nil,
            }
        end
    end
end

---@param plan table
---@return table[]
---@nodiscard
local function deriveRects(plan)
    ---@type table<integer, table>
    local boundsByZ = {}

    ---@param list table[]
    ---@return nil
    local function accumulate(list)
        for i = 1, #list do
            local p = list[i]
            local z = p.z or 0
            local b = boundsByZ[z]
            if not b then
                b = { minX = p.x, maxX = p.x, minY = p.y, maxY = p.y }
                boundsByZ[z] = b
            else
                if p.x < b.minX then b.minX = p.x end
                if p.x > b.maxX then b.maxX = p.x end
                if p.y < b.minY then b.minY = p.y end
                if p.y > b.maxY then b.maxY = p.y end
            end
        end
    end

    if #plan.cells > 0 then
        accumulate(plan.cells)
    else
        accumulate(plan.walls)
    end

    ---@type table[]
    local rects = {}
    for z, b in pairs(boundsByZ) do
        rects[#rects + 1] = {
            x = b.minX, y = b.minY, z = z,
            w = b.maxX - b.minX + 1,
            h = b.maxY - b.minY + 1,
            kind = "room",
        }
    end
    return rects
end

---@param area table
---@param opts table?
---@return table|nil
function Capture.captureArea(area, opts)
    opts = opts or {}
    local bounds = toBounds(area)
    if not bounds then return nil end

    local includeUntagged = opts.includeUntagged == true
    local captureDecor = opts.captureDecor == true

    ---@type table
    local plan = {
        structureId = opts.structureId,
        variant = opts.variant,
        x = bounds.minX, y = bounds.minY, z = bounds.minZ,
        w = bounds.maxX - bounds.minX + 1,
        h = bounds.maxY - bounds.minY + 1,
        walls = {}, cells = {}, roofs = {},
        stairs = {}, furniture = {}, appliances = {},
        decoratives = {}, vegetation = {},
    }
    ---@type table[]
    local stairSegments = {}
    local taggedCount, untaggedCount = 0, 0

    local cell = getCell()
    if not cell then return nil end

    for z = bounds.minZ, bounds.maxZ do
        for x = bounds.minX, bounds.maxX do
            for y = bounds.minY, bounds.maxY do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    local objs = sq:getObjects()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            local md = type(obj.getModData) == "function" and obj:getModData() or nil
                            local tag = md and md[TAG_KEY]
                            local consumed = false
                            if type(tag) == "table" and type(tag.structureId) == "string" then
                                if not opts.onlyStructureId or tag.structureId == opts.onlyStructureId then
                                    consumed = captureTagged(plan, obj, tag, x, y, z, stairSegments)
                                    if consumed then taggedCount = taggedCount + 1 end
                                else
                                    consumed = true
                                end
                            end
                            if not consumed and includeUntagged and not opts.onlyStructureId then
                                local bucket = captureHeuristic(plan, obj, x, y, z, captureDecor)
                                if bucket then untaggedCount = untaggedCount + 1 end
                            end
                        end
                    end
                end
            end
        end
    end

    assembleStairs(plan, stairSegments)

    if type(opts.rects) == "table" and #opts.rects > 0 then
        plan.rects = opts.rects
    else
        plan.rects = deriveRects(plan)
    end

    Plans.normalizePlan(plan)

    local counts = {
        walls = #plan.walls, cells = #plan.cells, roofs = #plan.roofs,
        stairs = #plan.stairs, furniture = #plan.furniture,
        appliances = #plan.appliances, decoratives = #plan.decoratives,
        vegetation = #plan.vegetation,
        tagged = taggedCount, untagged = untaggedCount,
    }

    local result = { plan = plan, counts = counts }

    local wantPreset = opts.asPreset == true or type(opts.name) == "string" or opts.save == true
    if wantPreset and type(opts.structureId) == "string" and opts.structureId ~= "" then
        local preset = Presets.toRelative(opts.structureId, plan)
        if type(opts.name) == "string" and opts.name ~= "" then
            preset.name = opts.name
        end
        result.preset = preset
        if opts.save == true and type(preset.name) == "string" and preset.name ~= "" then
            Presets.add(opts.structureId, preset)
            result.saved = true
        end
    end

    return result
end

return Capture
