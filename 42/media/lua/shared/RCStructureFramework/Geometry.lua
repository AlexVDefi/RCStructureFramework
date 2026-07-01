---@class RCStructureFrameworkGeometry
local Geometry = {}

---@param x number
---@param y number
---@param z number
---@return string
---@nodiscard
function Geometry.squareKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

---@param rect table
---@return string
---@nodiscard
function Geometry.roomRecordKey(rect)
    return Geometry.squareKey(rect.x, rect.y, rect.z) .. ":" .. tostring(rect.w) .. ":" .. tostring(rect.h)
end

---@param value any
---@return number|nil
---@nodiscard
function Geometry.numberFromValue(value)
    local valueType = type(value)
    if valueType == "number" then
        return value
    end
    if value == nil then
        return nil
    end
    return tonumber(tostring(value))
end

---@param x integer
---@param y integer
---@param z integer
---@return IsoGridSquare|nil
function Geometry.ensureSquare(x, y, z)
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square then
        if not getWorld():isValidSquare(x, y, z) then
            return nil
        end
        square = IsoGridSquare.new(cell, nil, x, y, z)
        cell:ConnectNewSquare(square, false)
    end
    square:EnsureSurroundNotNull()
    return square
end

---@param a table  { x, y, w, h }
---@param b table  { x, y, w, h }
---@return boolean
---@nodiscard
function Geometry.rectsOverlap(a, b)
    return a.x < b.x + b.w
        and b.x < a.x + a.w
        and a.y < b.y + b.h
        and b.y < a.y + a.h
end

---@param a table  { x, y, w, h }
---@param b table  { x, y, w, h }
---@return boolean
---@nodiscard
function Geometry.rectsEdgeAdjacent4(a, b)
    if a.x + a.w == b.x or b.x + b.w == a.x then
        if math.max(a.y, b.y) < math.min(a.y + a.h, b.y + b.h) then
            return true
        end
    end
    if a.y + a.h == b.y or b.y + b.h == a.y then
        if math.max(a.x, b.x) < math.min(a.x + a.w, b.x + b.w) then
            return true
        end
    end
    return false
end

---@param r table  { x, y, w, h }
---@param x integer
---@param y integer
---@return boolean
---@nodiscard
function Geometry.rectContainsCell(r, x, y)
    return x >= r.x and x < r.x + r.w
        and y >= r.y and y < r.y + r.h
end

---@param r table  { x, y, w, h }
---@param x integer
---@param y integer
---@return boolean
---@nodiscard
function Geometry.cellInOrAdjacentToRect(r, x, y)
    if Geometry.rectContainsCell(r, x, y) then return true end
    if (y == r.y - 1 or y == r.y + r.h)
        and x >= r.x and x < r.x + r.w then
        return true
    end
    if (x == r.x - 1 or x == r.x + r.w)
        and y >= r.y and y < r.y + r.h then
        return true
    end
    return false
end

---@param stair table  { x, y, z, north }
---@return integer x, integer y, integer z
---@nodiscard
function Geometry.getStairLandingTile(stair)
    local sz = stair.z or 0
    if stair.north then
        return stair.x, stair.y - 3, sz + 1
    end
    return stair.x - 3, stair.y, sz + 1
end

---@param footprint table
---@param x integer
---@param y integer
---@return boolean
---@nodiscard
function Geometry.isInteriorSquare(footprint, x, y)
    if footprint.boundary and type(footprint.boundary.contains) == "function" then
        return footprint.boundary:contains(x, y)
    end
    return x >= footprint.westX
        and x < footprint.eastX
        and y >= footprint.northY
        and y < footprint.southY
end

---@param character IsoPlayer
---@param x integer
---@param y integer
---@return number
---@nodiscard
local function squareDistanceToCharacter(character, x, y)
    local dx = (x + 0.5) - character:getX()
    local dy = (y + 0.5) - character:getY()
    return dx * dx + dy * dy
end

---@param target table
---@return integer
---@nodiscard
local function getWalkTargetX(target)
    return target.x
end

---@param target table
---@return integer
---@nodiscard
local function getWalkTargetY(target)
    return target.y
end

---@param target table
---@return integer
---@nodiscard
local function getWalkTargetZ(target)
    return target.z
end

---@param x integer
---@param y integer
---@param z integer
---@return table
---@nodiscard
local function newWalkTarget(x, y, z)
    return {
        x = x,
        y = y,
        z = z,
        getX = getWalkTargetX,
        getY = getWalkTargetY,
        getZ = getWalkTargetZ,
    }
end

---@param footprint table
---@return table
---@nodiscard
local function getAdjacentFootprintRing(footprint)
    local ring = {}

    for x = footprint.westX - 1, footprint.eastX do
        ring[#ring + 1] = { x = x, y = footprint.northY - 1 }
        ring[#ring + 1] = { x = x, y = footprint.southY }
    end
    for y = footprint.northY, footprint.southY - 1 do
        ring[#ring + 1] = { x = footprint.westX - 1, y = y }
        ring[#ring + 1] = { x = footprint.eastX, y = y }
    end

    return ring
end

---@param ring table
---@param character IsoPlayer
---@return nil
local function sortRingByDistance(ring, character)
    table.sort(ring, function(a, b)
        return squareDistanceToCharacter(character, a.x, a.y)
            < squareDistanceToCharacter(character, b.x, b.y)
    end)
end

---@param footprint table
---@param x integer
---@param y integer
---@return boolean
---@nodiscard
function Geometry.isAdjacentToFootprint(footprint, x, y)
    if footprint.boundary and type(footprint.boundary.contains) == "function" then
        if footprint.boundary:contains(x, y) then
            return false
        end
        return footprint.boundary:contains(x - 1, y)
            or footprint.boundary:contains(x + 1, y)
            or footprint.boundary:contains(x, y - 1)
            or footprint.boundary:contains(x, y + 1)
    end

    if y == footprint.northY - 1 or y == footprint.southY then
        return x >= footprint.westX - 1 and x <= footprint.eastX
    end

    if x == footprint.westX - 1 or x == footprint.eastX then
        return y >= footprint.northY and y < footprint.southY
    end

    return false
end

---@param footprint table
---@param character IsoPlayer
---@return IsoGridSquare|nil
---@nodiscard
function Geometry.findNearestOutsideSquare(footprint, character)
    if not footprint then return nil end
    local cell = getCell()
    local z = footprint.z

    local px = math.floor(character:getX())
    local py = math.floor(character:getY())
    if not Geometry.isInteriorSquare(footprint, px, py) then
        return nil
    end

    local candidates = {
        { x = px, y = footprint.northY - 1 },
        { x = px, y = footprint.southY },
        { x = footprint.westX - 1, y = py },
        { x = footprint.eastX, y = py },
    }
    sortRingByDistance(candidates, character)

    for i = 1, #candidates do
        local c = candidates[i]
        local sq = cell:getGridSquare(c.x, c.y, z)
        if sq and sq:canStand() then
            return sq
        end
    end

    return Geometry.findNearestAdjacentFootprintSquare(footprint, character)
end

---@param footprint table
---@param character IsoPlayer
---@return IsoGridSquare|nil
---@nodiscard
function Geometry.findNearestAdjacentFootprintSquare(footprint, character)
    if not footprint then return nil end
    local cell = getCell()
    local z = footprint.z
    local ring = getAdjacentFootprintRing(footprint)
    sortRingByDistance(ring, character)

    for i = 1, #ring do
        local c = ring[i]
        local sq = cell:getGridSquare(c.x, c.y, z)
        if sq and sq:canStand() then
            return sq
        end
    end

    return nil
end

---@param footprint table
---@param character IsoPlayer
---@return IsoGridSquare|table|nil
---@nodiscard
function Geometry.findNearestAdjacentFootprintWalkTarget(footprint, character)
    if not footprint then return nil end
    local cell = getCell()
    local z = footprint.z
    local ring = getAdjacentFootprintRing(footprint)
    sortRingByDistance(ring, character)

    for i = 1, #ring do
        local c = ring[i]
        local sq = cell:getGridSquare(c.x, c.y, z)
        if sq and sq:canStand() then
            return sq
        end
    end

    if #ring > 0 then
        local c = ring[1]
        return newWalkTarget(c.x, c.y, z)
    end

    return nil
end

return Geometry
