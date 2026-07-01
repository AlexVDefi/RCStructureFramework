local Geometry = require("RCStructureFramework/Geometry")
local Plans = require("RCStructureFramework/Plans")
local RoomPersistence = require("RCStructureFramework/RoomPersistence")
local PlannedConstructions = require("RCStructureFramework/PlannedConstructions")
local PlacementHelpers = require("RCStructureFramework/PlacementHelpers")

---See docs/how-to/validation.md for the opt-in list and reason keys.
---@class RCStructureFrameworkDefaultValidators
local DefaultValidators = {}

---@param plan table
---@return integer|nil westX
---@return integer|nil eastX
---@return integer|nil northY
---@return integer|nil southY
---@return integer|nil z
---@nodiscard
local function planBounds(plan)
    local rect = plan.rect
    if not rect and type(plan.x) == "number" and type(plan.w) == "number" then
        rect = { x = plan.x, y = plan.y, z = plan.z, w = plan.w, h = plan.h }
    end
    if not rect then return nil, nil, nil, nil, nil end
    return rect.x, rect.x + rect.w, rect.y, rect.y + rect.h, rect.z
end

---@param wall table
---@param westX integer
---@param eastX integer
---@param northY integer
---@param southY integer
---@return boolean
---@nodiscard
local function isCornerSlot(wall, westX, eastX, northY, southY)
    if wall.north then
        return (wall.x == westX or wall.x == eastX - 1)
            and (wall.y == northY or wall.y == southY)
    end
    return (wall.x == westX or wall.x == eastX)
        and (wall.y == northY or wall.y == southY - 1)
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.noOverlap(plan)
    if type(plan) ~= "table" or type(plan.walls) ~= "table" then
        return true, nil
    end

    local seen = {}
    for i = 1, #plan.walls do
        local wall = plan.walls[i]
        if wall then
            local key = Plans.makeWallKey(wall.x, wall.y, wall.z, wall.north == true)
            if seen[key] then
                return false, "noOverlap"
            end
            seen[key] = true
        end
    end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.slotKindCompatible(plan)
    if type(plan) ~= "table" or type(plan.walls) ~= "table" then
        return true, nil
    end
    local westX, eastX, northY, southY = planBounds(plan)
    if not westX then
        return true, nil
    end

    for i = 1, #plan.walls do
        local wall = plan.walls[i]
        local slotKind = wall and wall.slotKind
        if slotKind == "door" or slotKind == "window" then
            if isCornerSlot(wall, westX, eastX, northY, southY) then
                return false, "slotKindCompatible"
            end
        end
    end
    return true, nil
end

---@param plan table
---@return table  { [squareKey] = wall, ... } for the layer below the roof
---@nodiscard
local function buildWallsByZ(plan)
    local byZ = {}
    if type(plan.walls) ~= "table" then return byZ end
    for i = 1, #plan.walls do
        local wall = plan.walls[i]
        local z = wall.z
        if not byZ[z] then byZ[z] = {} end
        byZ[z][Geometry.squareKey(wall.x, wall.y, z)] = wall
    end
    return byZ
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.roofNeedsWallUnder(plan)
    if type(plan) ~= "table" or type(plan.roofs) ~= "table" then
        return true, nil
    end

    local wallsByZ = buildWallsByZ(plan)

    for i = 1, #plan.roofs do
        local roof = plan.roofs[i]
        if roof and roof._generated ~= true and roof.roofKind ~= "eave" then
            local zBelow = roof.z - 1
            local layer = wallsByZ[zBelow]
            local hasAnchor = false
            if layer then
                if layer[Geometry.squareKey(roof.x, roof.y, zBelow)]
                    or layer[Geometry.squareKey(roof.x + 1, roof.y, zBelow)]
                    or layer[Geometry.squareKey(roof.x, roof.y + 1, zBelow)] then
                    hasAnchor = true
                end
            end
            if not hasAnchor then
                return false, "roofNeedsWallUnder"
            end
        end
    end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.floorNeedsCell(plan)
    if type(plan) ~= "table" or type(plan.walls) ~= "table" then
        return true, nil
    end
    if type(plan.cells) ~= "table" or #plan.cells == 0 then
        return true, nil
    end

    local cellsByZ = {}
    for i = 1, #plan.cells do
        local cell = plan.cells[i]
        if not cellsByZ[cell.z] then cellsByZ[cell.z] = {} end
        cellsByZ[cell.z][Geometry.squareKey(cell.x, cell.y, cell.z)] = cell
    end

    for i = 1, #plan.walls do
        local wall = plan.walls[i]
        local layer = cellsByZ[wall.z]
        if layer then
            local hasNeighbour
            if wall.north then
                hasNeighbour = layer[Geometry.squareKey(wall.x, wall.y - 1, wall.z)]
                    or layer[Geometry.squareKey(wall.x, wall.y, wall.z)]
            else
                hasNeighbour = layer[Geometry.squareKey(wall.x - 1, wall.y, wall.z)]
                    or layer[Geometry.squareKey(wall.x, wall.y, wall.z)]
            end
            if not hasNeighbour then
                return false, "floorNeedsCell"
            end
        else
            return false, "floorNeedsCell"
        end
    end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.zAboveEmpty(plan)
    if type(plan) ~= "table" or type(plan.roofs) ~= "table" then
        return true, nil
    end

    local wallsAboveByZ = {}
    if type(plan.walls) == "table" then
        for i = 1, #plan.walls do
            local wall = plan.walls[i]
            if not wallsAboveByZ[wall.z] then wallsAboveByZ[wall.z] = {} end
            wallsAboveByZ[wall.z][Geometry.squareKey(wall.x, wall.y, wall.z)] = true
        end
    end

    local roofsByZ = {}
    for i = 1, #plan.roofs do
        local roof = plan.roofs[i]
        if not roofsByZ[roof.z] then roofsByZ[roof.z] = {} end
        roofsByZ[roof.z][Geometry.squareKey(roof.x, roof.y, roof.z)] = true
    end

    for i = 1, #plan.roofs do
        local roof = plan.roofs[i]
        if roof and roof._generated ~= true and roof.roofKind ~= "eave" then
            local zAbove = roof.z + 1
            local key = Geometry.squareKey(roof.x, roof.y, zAbove)
            if (wallsAboveByZ[zAbove] and wallsAboveByZ[zAbove][key])
                or (roofsByZ[zAbove] and roofsByZ[zAbove][key]) then
                return false, "zAboveEmpty"
            end
        end
    end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.minimumRoomRectSize(plan)
    if type(plan) ~= "table" or type(plan.rects) ~= "table" then
        return true, nil
    end
    for i = 1, #plan.rects do
        local r = plan.rects[i]
        local kind = r.kind
        if type(kind) ~= "string" or kind == "" then
            kind = "room"
        end
        if kind == "room" then
            if (r.w or 0) < 2 or (r.h or 0) < 2 then
                return false, "rectTooSmall"
            end
        end
    end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.stairLinks(plan)
    if type(plan) ~= "table" then return true, nil end
    if type(plan.cells) ~= "table" or #plan.cells == 0 then return true, nil end
    if type(plan.rects) ~= "table" or #plan.rects == 0 then return true, nil end

    local hasUpperCell = false
    for ci = 1, #plan.cells do
        if (plan.cells[ci].z or 0) > 0 then hasUpperCell = true; break end
    end
    if not hasUpperCell then return true, nil end

    local groups = RoomPersistence.partitionRectsByConnectivity(plan.rects, plan.stairs)
    local rectGroup = {}
    local groupHasGround = {}
    for gi = 1, #groups do
        local g = groups[gi]
        for ri = 1, #g do
            rectGroup[g[ri]] = gi
            if (g[ri].z or 0) == 0 then groupHasGround[gi] = true end
        end
    end

    for ci = 1, #plan.cells do
        local cell = plan.cells[ci]
        local cz = cell.z or 0
        if cz > 0 then
            local containingRect = nil
            for ri = 1, #plan.rects do
                local r = plan.rects[ri]
                if (r.z or 0) == cz and Geometry.rectContainsCell(r, cell.x, cell.y) then
                    containingRect = r
                    break
                end
            end
            if containingRect then
                local gi = rectGroup[containingRect]
                if not gi or not groupHasGround[gi] then
                    return false, "missingStairLink"
                end
            end
        end
    end

    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.obstructionFree(plan)
    if type(plan) ~= "table" then return true, nil end

    local cell = getCell()
    if not cell then return true, nil end

    ---@param sq IsoGridSquare
    ---@return boolean
    ---@nodiscard
    local function squareHasVehicle(sq)
        if type(sq.getVehicleContainer) == "function" and sq:getVehicleContainer() ~= nil then
            return true
        end
        if type(sq.getMovingObjects) ~= "function" then return false end
        local movers = sq:getMovingObjects()
        if not movers or type(movers.size) ~= "function" then return false end
        for i = 0, movers:size() - 1 do
            local obj = movers:get(i)
            if obj and instanceof(obj, "BaseVehicle") then
                return true
            end
        end
        return false
    end

    ---@param sq IsoGridSquare
    ---@return boolean
    ---@nodiscard
    local function squareHasTree(sq)
        if type(sq.getObjects) ~= "function" then return false end
        local objs = sq:getObjects()
        if not objs or type(objs.size) ~= "function" then return false end
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if obj and instanceof(obj, "IsoTree") then
                return true
            end
        end
        return false
    end

    ---@param sq IsoGridSquare
    ---@return boolean
    ---@nodiscard
    local function squareHasMultiTileFurniture(sq)
        if type(sq.getObjects) ~= "function" then return false end
        local objs = sq:getObjects()
        if not objs or type(objs.size) ~= "function" then return false end
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if obj and instanceof(obj, "IsoThumpable")
               and type(obj.getEntityScript) == "function" then
                local script = obj:getEntityScript()
                if script and type(script.getSize) == "function" then
                    local size = script:getSize()
                    if size and size > 1 then return true end
                end
            end
        end
        return false
    end

    ---@param x integer
    ---@param y integer
    ---@param z integer
    ---@return boolean
    ---@nodiscard
    local function squareObstructed(x, y, z)
        if not getWorld():isValidSquare(x, y, z) then return true end
        local sq = cell:getGridSquare(x, y, z)
        if sq == nil then
            return false
        end
        local props = sq:getProperties()
        if props and (props:has(IsoFlagType.solid) or props:has(IsoFlagType.solidtrans)) then
            return true
        end
        if sq.getRoom and sq:getRoom() ~= nil then
            return true
        end
        if squareHasVehicle(sq) then return true end
        if squareHasTree(sq) then return true end
        if squareHasMultiTileFurniture(sq) then return true end
        return false
    end

    ---@param x integer
    ---@param y integer
    ---@param z integer
    ---@return boolean
    ---@nodiscard
    local function rugSquareObstructed(x, y, z)
        if not getWorld():isValidSquare(x, y, z) then return true end
        local sq = cell:getGridSquare(x, y, z)
        if sq == nil then return false end
        local props = sq:getProperties()
        if props and (props:has(IsoFlagType.solid) or props:has(IsoFlagType.solidtrans)) then
            return true
        end
        if squareHasVehicle(sq) then return true end
        if squareHasTree(sq) then return true end
        if squareHasMultiTileFurniture(sq) then return true end
        if PlacementHelpers.squareHasRug(sq) then return true end
        return false
    end

    if type(plan.cells) == "table" then
        for i = 1, #plan.cells do
            local c = plan.cells[i]
            local cz = c.z or 0
            if c.isRug == true then
                if rugSquareObstructed(c.x, c.y, cz) then
                    return false, "obstructed"
                end
            else
                if squareObstructed(c.x, c.y, cz) then
                    return false, "obstructed"
                end
            end
        end
    end

    if type(plan.roofs) == "table" then
        for i = 1, #plan.roofs do
            local r = plan.roofs[i]
            if r and r._generated ~= true and r.roofKind ~= "eave" then
                if squareObstructed(r.x, r.y, r.z or 0) then
                    return false, "obstructed"
                end
            end
        end
    end

    if type(plan.stairs) == "table" then
        for i = 1, #plan.stairs do
            local s = plan.stairs[i]
            local sz = s.z or 0
            local mx, my, tx, ty
            if s.north then
                mx, my = s.x, s.y - 1
                tx, ty = s.x, s.y - 2
            else
                mx, my = s.x - 1, s.y
                tx, ty = s.x - 2, s.y
            end
            if squareObstructed(s.x, s.y, sz)
                or squareObstructed(mx, my, sz)
                or squareObstructed(tx, ty, sz) then
                return false, "obstructed"
            end
        end
    end

    if PlannedConstructions.intersects(plan) then
        return false, "obstructed"
    end

    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.footprintFitsInRect(plan)
    if type(plan) ~= "table" then return true, nil end

    ---@param piece table
    ---@return integer w, integer h
    ---@nodiscard
    local function getFootprint(piece)
        local fp = piece.footprint
        if type(fp) ~= "table" then return 1, 1 end
        local w = (type(fp.w) == "number" and fp.w >= 1) and math.floor(fp.w) or 1
        local h = (type(fp.h) == "number" and fp.h >= 1) and math.floor(fp.h) or 1
        return w, h
    end

    ---@param x integer
    ---@param y integer
    ---@param z integer
    ---@return boolean
    ---@nodiscard
    local function cellInsideAnyRect(x, y, z)
        if type(plan.rects) ~= "table" or #plan.rects == 0 then return true end
        for ri = 1, #plan.rects do
            local r = plan.rects[ri]
            if (r.z or 0) == z and Geometry.rectContainsCell(r, x, y) then
                return true
            end
        end
        return false
    end

    ---@type table<string, boolean>
    local wallTiles = {}
    if type(plan.walls) == "table" then
        for i = 1, #plan.walls do
            local w = plan.walls[i]
            wallTiles[Geometry.squareKey(w.x, w.y, w.z or 0)] = true
        end
    end

    ---@param arrName string
    ---@return boolean, string|nil
    ---@nodiscard
    local function checkArray(arrName)
        local arr = plan[arrName]
        if type(arr) ~= "table" then return true, nil end
        for i = 1, #arr do
            local piece = arr[i]
            if piece then
                local w, h = getFootprint(piece)
                if w > 1 or h > 1 then
                    local z = piece.z or 0
                    for dx = 0, w - 1 do
                        for dy = 0, h - 1 do
                            local tx = piece.x + dx
                            local ty = piece.y + dy
                            if not cellInsideAnyRect(tx, ty, z) then
                                return false, "footprintExceedsRect"
                            end
                            if wallTiles[Geometry.squareKey(tx, ty, z)] then
                                return false, "footprintOverlapsWall"
                            end
                        end
                    end
                end
            end
        end
        return true, nil
    end

    local ok, reason = checkArray("furniture")
    if not ok then return false, reason end
    ok, reason = checkArray("appliances")
    if not ok then return false, reason end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.noEmptyPlan(plan)
    if type(plan) ~= "table" then
        return false, "emptyPlan"
    end
    if type(plan.rects) ~= "table" or #plan.rects == 0 then
        return false, "emptyPlan"
    end
    return true, nil
end

---@param plan table
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.multiRectEdgeConnectivity(plan)
    if type(plan) ~= "table" or type(plan.rects) ~= "table" then
        return true, nil
    end
    local n = #plan.rects
    if n < 2 then
        return true, nil
    end

    for i = 1, n - 1 do
        local a = plan.rects[i]
        for j = i + 1, n do
            local b = plan.rects[j]
            if (a.z or 0) == (b.z or 0) and Geometry.rectsOverlap(a, b) then
                return false, "rectsOverlap"
            end
        end
    end

    ---@type table<integer, integer[]>
    local rectsByZ = {}
    for i = 1, n do
        local z = plan.rects[i].z or 0
        if not rectsByZ[z] then
            rectsByZ[z] = {}
        end
        rectsByZ[z][#rectsByZ[z] + 1] = i
    end

    ---@type integer[]
    local parent = {}
    for i = 1, n do
        parent[i] = i
    end

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
        local ra = find(a)
        local rb = find(b)
        if ra ~= rb then
            parent[ra] = rb
        end
    end

    for _, indices in pairs(rectsByZ) do
        local count = #indices
        for i = 1, count - 1 do
            for j = i + 1, count do
                local ai = indices[i]
                local bj = indices[j]
                if Geometry.rectsEdgeAdjacent4(plan.rects[ai], plan.rects[bj]) then
                    union(ai, bj)
                end
            end
        end

        ---@type integer|nil
        local root = nil
        for i = 1, count do
            local r = find(indices[i])
            if root == nil then
                root = r
            elseif r ~= root then
                return false, "rectsNotConnected"
            end
        end
    end

    return true, nil
end

---@param plan table
---@param names string[]
---@return boolean, string|nil
---@nodiscard
function DefaultValidators.runAll(plan, names)
    if type(names) ~= "table" then return true, nil end
    for i = 1, #names do
        local fn = DefaultValidators[names[i]]
        if type(fn) == "function" then
            local ok, reason = fn(plan)
            if ok ~= true then
                return false, reason or names[i]
            end
        end
    end
    return true, nil
end

return DefaultValidators
