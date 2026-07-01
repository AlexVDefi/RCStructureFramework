
---@class RCStructureFrameworkPiecePresence
local PiecePresence = {}

---@return IsoCell|nil
---@nodiscard
local function getWorldCell()
    return getCell()
end

---@param x integer
---@param y integer
---@param z integer
---@return IsoGridSquare|nil
---@nodiscard
local function getSquare(x, y, z)
    if not getWorld():isValidSquare(x, y, z) then return nil end
    local cell = getWorldCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

---@param sq IsoGridSquare
---@return boolean
---@nodiscard
local function squareHasNorthWall(sq)
    local props = sq:getProperties()
    if not props then return false end
    return props:has(IsoFlagType.WallN)
        or props:has(IsoFlagType.WallNW)
        or props:has(IsoFlagType.WindowN)
        or props:has(IsoFlagType.DoorWallN)
end

---@param sq IsoGridSquare
---@return boolean
---@nodiscard
local function squareHasWestWall(sq)
    local props = sq:getProperties()
    if not props then return false end
    return props:has(IsoFlagType.WallW)
        or props:has(IsoFlagType.WallNW)
        or props:has(IsoFlagType.WindowW)
        or props:has(IsoFlagType.DoorWallW)
end

---@param x integer
---@param y integer
---@param z integer
---@param north boolean  true → north-edge wall, false → west-edge wall
---@return boolean
---@nodiscard
function PiecePresence.hasRealWallAt(x, y, z, north)
    local sq = getSquare(x, y, z)
    if not sq then return false end
    if north == true then
        return squareHasNorthWall(sq)
    end
    return squareHasWestWall(sq)
end

---@param x integer
---@param y integer
---@param z integer
---@param spriteName string|nil
---@return boolean
---@nodiscard
function PiecePresence.hasRealFloorAt(x, y, z, spriteName)
    local sq = getSquare(x, y, z)
    if not sq then return false end
    local floor = sq:getFloor()
    if not floor then return false end
    if type(spriteName) == "string" and spriteName ~= "" then
        local current = floor:getSpriteName() or (floor:getSprite() and floor:getSprite():getName())
        if current == spriteName then
            return true
        end
        return false
    end
    local current = floor:getSpriteName() or (floor:getSprite() and floor:getSprite():getName())
    if type(current) ~= "string" or current == "" then return false end
    if string.sub(current, 1, 7) == "blends_"
        or string.sub(current, 1, 11) == "vegetation_"
        or string.sub(current, 1, 10) == "d_generic_"
        or string.sub(current, 1, 25) == "floors_exterior_natural_" then
        return false
    end
    return true
end

---@param x integer
---@param y integer
---@param z integer
---@param north boolean
---@return boolean
---@nodiscard
function PiecePresence.hasRealStairAt(x, y, z, north)
    local sq = getSquare(x, y, z)
    if not sq then return false end
    if north == true then
        return sq:HasStairsNorth() == true
    end
    return sq:HasStairsWest() == true
end

---@param x integer
---@param y integer
---@param z integer
---@param spriteName string|nil
---@return boolean
---@nodiscard
function PiecePresence.hasObjectWithSpriteAt(x, y, z, spriteName)
    if type(spriteName) ~= "string" or spriteName == "" then return false end
    local sq = getSquare(x, y, z)
    if not sq then return false end
    local objs = sq:getObjects()
    if not objs or type(objs.size) ~= "function" then return false end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj then
            local name = obj.getSpriteName and obj:getSpriteName() or nil
            if name == spriteName then
                return true
            end
            local sprite = obj.getSprite and obj:getSprite() or nil
            if sprite and sprite.getName and sprite:getName() == spriteName then
                return true
            end
        end
    end
    return false
end

---@param piece table  { kind, x, y, z, north?, spriteName?, isRug? }
---@return boolean
---@nodiscard
function PiecePresence.isPieceRealized(piece)
    if type(piece) ~= "table" then return false end
    local kind = piece.kind
    if kind == "wall" then
        return PiecePresence.hasRealWallAt(piece.x, piece.y, piece.z or 0, piece.north == true)
    end
    if kind == "cell" then
        if piece.isRug == true then
            return PiecePresence.hasObjectWithSpriteAt(piece.x, piece.y, piece.z or 0, piece.spriteName)
        end
        return PiecePresence.hasRealFloorAt(piece.x, piece.y, piece.z or 0, piece.spriteName)
    end
    if kind == "stair" then
        return PiecePresence.hasRealStairAt(piece.x, piece.y, piece.z or 0, piece.north == true)
    end
    if kind == "roof" or kind == "furniture" or kind == "appliance"
        or kind == "decorative" or kind == "vegetation" then
        return PiecePresence.hasObjectWithSpriteAt(piece.x, piece.y, piece.z or 0, piece.spriteName)
    end
    return false
end

---@param a table  { x, y, z, north }
---@param b table  { x, y, z, north }
---@return boolean
---@nodiscard
function PiecePresence.wallIsoOrder(a, b)
    local az = a.z or 0
    local bz = b.z or 0
    if az ~= bz then return az < bz end
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    local aNorth = a.north == true
    local bNorth = b.north == true
    if aNorth ~= bNorth then return not aNorth end
    return false
end

---@param walls table[]
---@return integer[]
---@nodiscard
function PiecePresence.sortedWallIndices(walls)
    ---@type integer[]
    local indices = {}
    if type(walls) ~= "table" then return indices end
    for i = 1, #walls do
        indices[i] = i
    end
    table.sort(indices, function(ia, ib)
        return PiecePresence.wallIsoOrder(walls[ia], walls[ib])
    end)
    return indices
end

---@param a table  { x, y, z }
---@param b table  { x, y, z }
---@return boolean
---@nodiscard
function PiecePresence.pieceIsoOrder(a, b)
    local az = a.z or 0
    local bz = b.z or 0
    if az ~= bz then return az < bz end
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return false
end

---@param pieces table[]
---@return integer[]
---@nodiscard
function PiecePresence.sortedPieceIndices(pieces)
    ---@type integer[]
    local indices = {}
    if type(pieces) ~= "table" then return indices end
    for i = 1, #pieces do
        indices[i] = i
    end
    table.sort(indices, function(ia, ib)
        return PiecePresence.pieceIsoOrder(pieces[ia], pieces[ib])
    end)
    return indices
end

---@param panel table
---@param pieceZ number|nil
---@return boolean
---@nodiscard
function PiecePresence.inZPass(panel, pieceZ)
    local activeZ = panel._zPassActiveZ
    if activeZ == nil then return true end
    local z = pieceZ or 0
    if panel._zPassActiveOnly == true then
        return z == activeZ
    end
    return z ~= activeZ
end

return PiecePresence
