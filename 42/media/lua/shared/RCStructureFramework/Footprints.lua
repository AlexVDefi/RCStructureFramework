local Geometry = require("RCStructureFramework/Geometry")
local Registry = require("RCStructureFramework/Registry")
---@class RCStructureFrameworkFootprints
local Footprints = {}

---@param rect table
---@param gableAxis string?
---@return table|nil
---@nodiscard
function Footprints.getFootprintFromRoomRect(rect, gableAxis)
    local xValue = Geometry.numberFromValue(rect.x)
    local yValue = Geometry.numberFromValue(rect.y)
    local zValue = Geometry.numberFromValue(rect.z)
    local widthValue = Geometry.numberFromValue(rect.w)
    local heightValue = Geometry.numberFromValue(rect.h)

    if xValue == nil or yValue == nil or zValue == nil or widthValue == nil or heightValue == nil then
        return nil
    end

    local x = math.floor(xValue)
    local y = math.floor(yValue)
    local z = math.floor(zValue)
    local width = math.floor(widthValue)
    local height = math.floor(heightValue)

    if width < 1 or height < 1 then
        return nil
    end

    return {
        westX = x,
        eastX = x + width,
        northY = y,
        southY = y + height,
        z = z,
        roofZ = z + 1,
        gableAxis = gableAxis,
        walls = {},
        roomRect = {
            x = x,
            y = y,
            z = z,
            w = width,
            h = height,
        },
        boundary = {
            squares = {},
            map = {},
            bounds = {
                minX = x,
                maxX = x + width,
                minY = y,
                maxY = y + height,
                z = z,
            },
        },
    }
end

---@param structureId string
---@param plan table
---@return table|nil
---@nodiscard
function Footprints.getFootprintFromPlan(structureId, plan)
    local def = Registry.requireStructure(structureId)
    if def.getFootprintFromPlan then
        return def.getFootprintFromPlan(plan)
    end
    if plan and plan.x and plan.y and plan.w and plan.h then
        return Footprints.getFootprintFromRoomRect(plan, plan.gableAxis)
    end
    return nil
end

---@param cells table[]
---@param z integer?
---@return table|nil
---@nodiscard
function Footprints.getFootprintFromCells(cells, z)
    if type(cells) ~= "table" or #cells == 0 then
        return nil
    end

    local minX, maxX, minY, maxY
    local zUsed = z
    local membership = {}
    local count = 0

    for i = 1, #cells do
        local c = cells[i]
        if c then
            local cx = Geometry.numberFromValue(c.x)
            local cy = Geometry.numberFromValue(c.y)
            local cz = Geometry.numberFromValue(c.z)
            if cx and cy and cz then
                if zUsed == nil then zUsed = math.floor(cz) end
                if math.floor(cz) == zUsed then
                    cx = math.floor(cx)
                    cy = math.floor(cy)
                    if minX == nil or cx < minX then minX = cx end
                    if maxX == nil or cx > maxX then maxX = cx end
                    if minY == nil or cy < minY then minY = cy end
                    if maxY == nil or cy > maxY then maxY = cy end
                    membership[Geometry.squareKey(cx, cy, zUsed)] = true
                    count = count + 1
                end
            end
        end
    end

    if count == 0 or minX == nil then
        return nil
    end

    local width = (maxX - minX) + 1
    local height = (maxY - minY) + 1
    local zFinal = zUsed or 0

    return {
        westX = minX,
        eastX = minX + width,
        northY = minY,
        southY = minY + height,
        z = zFinal,
        roofZ = zFinal + 1,
        gableAxis = nil,
        walls = {},
        roomRect = { x = minX, y = minY, z = zFinal, w = width, h = height },
        boundary = {
            kind = "cells",
            map = membership,
            ---@param self table
            ---@param x integer
            ---@param y integer
            ---@return boolean
            contains = function(self, x, y)
                return self.map[Geometry.squareKey(x, y, zFinal)] == true
            end,
            bounds = {
                minX = minX, maxX = minX + width,
                minY = minY, maxY = minY + height,
                z = zFinal,
            },
        },
        cellCount = count,
    }
end

---@param rects table[]
---@param gableAxis string?
---@return table|nil
---@nodiscard
function Footprints.getFootprintFromRects(rects, gableAxis)
    if type(rects) ~= "table" or #rects == 0 then
        return nil
    end

    local minX, maxX, minY, maxY, zUsed
    local clean = {}

    for i = 1, #rects do
        local r = rects[i]
        if r then
            local rx = Geometry.numberFromValue(r.x)
            local ry = Geometry.numberFromValue(r.y)
            local rz = Geometry.numberFromValue(r.z)
            local rw = Geometry.numberFromValue(r.w)
            local rh = Geometry.numberFromValue(r.h)
            if rx and ry and rz and rw and rh and rw > 0 and rh > 0 then
                rx = math.floor(rx); ry = math.floor(ry); rz = math.floor(rz)
                rw = math.floor(rw); rh = math.floor(rh)
                if zUsed == nil then zUsed = rz end
                if rz == zUsed then
                    if minX == nil or rx < minX then minX = rx end
                    if minY == nil or ry < minY then minY = ry end
                    if maxX == nil or rx + rw > maxX then maxX = rx + rw end
                    if maxY == nil or ry + rh > maxY then maxY = ry + rh end
                    clean[#clean + 1] = { x = rx, y = ry, z = rz, w = rw, h = rh }
                end
            end
        end
    end

    if #clean == 0 then return nil end

    local zFinal = zUsed or 0
    local width = maxX - minX
    local height = maxY - minY

    ---@param x integer
    ---@param y integer
    ---@return boolean
    ---@nodiscard
    local function rectContains(x, y)
        for i = 1, #clean do
            local r = clean[i]
            if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
                return true
            end
        end
        return false
    end

    return {
        westX = minX,
        eastX = minX + width,
        northY = minY,
        southY = minY + height,
        z = zFinal,
        roofZ = zFinal + 1,
        gableAxis = gableAxis,
        walls = {},
        roomRect = { x = minX, y = minY, z = zFinal, w = width, h = height },
        rects = clean,
        boundary = {
            kind = "rects",
            rects = clean,
            ---@param self table
            ---@param x integer
            ---@param y integer
            ---@return boolean
            contains = function(self, x, y)
                return rectContains(x, y)
            end,
            bounds = {
                minX = minX, maxX = minX + width,
                minY = minY, maxY = minY + height,
                z = zFinal,
            },
        },
    }
end

return Footprints
