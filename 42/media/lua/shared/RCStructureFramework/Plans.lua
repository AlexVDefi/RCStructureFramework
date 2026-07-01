local Geometry = require("RCStructureFramework/Geometry")
---@class RCStructureFrameworkPlans
local Plans = {}

---@param wall table
---@return string
---@nodiscard
function Plans.wallKey(wall)
    return Plans.makeWallKey(wall.x, wall.y, wall.z, wall.north)
end

---@param x number
---@param y number
---@param z number
---@param north boolean
---@return string
---@nodiscard
function Plans.makeWallKey(x, y, z, north)
    return Geometry.squareKey(x, y, z) .. ":" .. tostring(north)
end

---@param rect table
---@param x number
---@param y number
---@param north boolean
---@return boolean
---@nodiscard
function Plans.wallSlotIsInsideRect(rect, x, y, north)
    local eastX = rect.x + rect.w
    local southY = rect.y + rect.h

    if north then
        return x >= rect.x
            and x <= eastX
            and y >= rect.y
            and y <= southY
    end

    return x >= rect.x
        and x <= eastX
        and y >= rect.y
        and y <= southY
end

---@param startX number
---@param startY number
---@param endX number
---@param endY number
---@param z number
---@return table
---@nodiscard
function Plans.getSelectionRect(startX, startY, endX, endY, z)
    local westX = startX
    local eastX = endX
    if westX > eastX then
        westX = endX
        eastX = startX
    end

    local northY = startY
    local southY = endY
    if northY > southY then
        northY = endY
        southY = startY
    end

    return {
        x = westX,
        y = northY,
        z = math.floor(z),
        w = eastX - westX + 1,
        h = southY - northY + 1,
    }
end

---@param startX number
---@param startY number
---@param endX number
---@param endY number
---@param z number
---@param existingRects table[]?
---@return table
---@nodiscard
function Plans.getSelection(startX, startY, endX, endY, z, existingRects)
    local rect = Plans.getSelectionRect(startX, startY, endX, endY, z)
    if type(existingRects) == "table" and #existingRects > 0 then
        local rects = {}
        for i = 1, #existingRects do rects[i] = existingRects[i] end
        rects[#rects + 1] = rect
        return { kind = "rects", rects = rects }
    end
    return { kind = "rect", rect = rect }
end

---@param rect table
---@param pieceType string
---@return table
---@nodiscard
function Plans.getRectanglePerimeterWalls(rect, pieceType)
    local walls = {}

    for x = rect.x, rect.x + rect.w - 1 do
        walls[#walls + 1] = { x = x, y = rect.y, z = rect.z, north = true, wallType = pieceType }
        walls[#walls + 1] = { x = x, y = rect.y + rect.h, z = rect.z, north = true, wallType = pieceType }
    end

    for y = rect.y, rect.y + rect.h - 1 do
        walls[#walls + 1] = { x = rect.x, y = y, z = rect.z, north = false, wallType = pieceType }
        walls[#walls + 1] = { x = rect.x + rect.w, y = y, z = rect.z, north = false, wallType = pieceType }
    end

    return walls
end

---@param walls table
---@return table
---@nodiscard
function Plans.buildWallMap(walls)
    local wallMap = {}
    if type(walls) ~= "table" then
        return wallMap
    end

    for i = 1, #walls do
        wallMap[Plans.wallKey(walls[i])] = i
    end
    return wallMap
end

---@param roof table
---@return string
---@nodiscard
function Plans.roofKey(roof)
    return Plans.makeRoofKey(roof.x, roof.y, roof.z)
end

---@param x number
---@param y number
---@param z number
---@return string
---@nodiscard
function Plans.makeRoofKey(x, y, z)
    return Geometry.squareKey(x, y, z)
end

---@param roofs table
---@return table
---@nodiscard
function Plans.buildRoofMap(roofs)
    local roofMap = {}
    if type(roofs) ~= "table" then
        return roofMap
    end

    for i = 1, #roofs do
        roofMap[Plans.roofKey(roofs[i])] = i
    end
    return roofMap
end

---@param roof table
---@return table
---@nodiscard
function Plans.copyRoof(roof)
    return {
        x = roof.x,
        y = roof.y,
        z = roof.z,
        north = roof.north == true,
        spriteName = roof.spriteName,
        slope = roof.slope,
        roofKind = roof.roofKind,
    }
end

---@param wall table
---@return table
---@nodiscard
function Plans.copyWall(wall)
    return {
        x = wall.x,
        y = wall.y,
        z = wall.z,
        north = wall.north == true,
        wallType = wall.wallType,
        slotKind = wall.slotKind,
        spriteName = wall.spriteName,
        wallpaperSpriteName = wall.wallpaperSpriteName,
    }
end

---@param stair table
---@return table
---@nodiscard
function Plans.copyStair(stair)
    return {
        x = stair.x,
        y = stair.y,
        z = stair.z,
        north = stair.north == true,
        bottomSprite = stair.bottomSprite,
        middleSprite = stair.middleSprite,
        topSprite = stair.topSprite,
        pillarSprite = stair.pillarSprite,
    }
end

---@param piece table
---@return table
---@nodiscard
function Plans.copyFurniture(piece)
    local footprint = nil
    if type(piece.footprint) == "table" then
        footprint = { w = piece.footprint.w, h = piece.footprint.h }
    end
    return {
        x = piece.x,
        y = piece.y,
        z = piece.z,
        facing = piece.facing,
        defId = piece.defId,
        spriteName = piece.spriteName,
        footprint = footprint,
        anchor = piece.anchor or "origin",
    }
end

---@param piece table
---@return table
---@nodiscard
function Plans.copyAppliance(piece)
    local footprint = nil
    if type(piece.footprint) == "table" then
        footprint = { w = piece.footprint.w, h = piece.footprint.h }
    end
    local utilities = nil
    if type(piece.utilities) == "table" then
        utilities = { power = piece.utilities.power, water = piece.utilities.water }
    end
    return {
        x = piece.x,
        y = piece.y,
        z = piece.z,
        facing = piece.facing,
        defId = piece.defId,
        spriteName = piece.spriteName,
        footprint = footprint,
        anchor = piece.anchor or "origin",
        utilities = utilities,
    }
end

---@param piece table
---@return table
---@nodiscard
function Plans.copyDecorative(piece)
    return {
        x = piece.x,
        y = piece.y,
        z = piece.z,
        facing = piece.facing,
        defId = piece.defId,
        spriteName = piece.spriteName,
        anchor = piece.anchor or "origin",
    }
end

---@param piece table
---@return table
---@nodiscard
function Plans.copyVegetation(piece)
    return {
        x = piece.x,
        y = piece.y,
        z = piece.z,
        defId = piece.defId,
        spriteName = piece.spriteName,
    }
end

---@param plan table
---@return table
---@nodiscard
function Plans.copyPlan(plan)
    local copy = {}
    for k, v in pairs(plan) do
        copy[k] = v
    end

    if type(plan.walls) == "table" then
        copy.walls = {}
        for i = 1, #plan.walls do
            copy.walls[#copy.walls + 1] = Plans.copyWall(plan.walls[i])
        end
    end

    if type(plan.cells) == "table" then
        copy.cells = {}
        for i = 1, #plan.cells do
            local c = plan.cells[i]
            copy.cells[#copy.cells + 1] = {
                x = c.x, y = c.y, z = c.z,
                spriteName = c.spriteName,
                isRug = c.isRug == true and true or nil,
            }
        end
    end

    if type(plan.roofs) == "table" then
        copy.roofs = {}
        for i = 1, #plan.roofs do
            copy.roofs[#copy.roofs + 1] = Plans.copyRoof(plan.roofs[i])
        end
    end

    if type(plan.rects) == "table" then
        copy.rects = {}
        for i = 1, #plan.rects do
            local r = plan.rects[i]
            copy.rects[#copy.rects + 1] = {
                x = r.x, y = r.y, z = r.z, w = r.w, h = r.h,
                kind = r.kind,
            }
        end
    end

    if type(plan.stairs) == "table" then
        copy.stairs = {}
        for i = 1, #plan.stairs do
            copy.stairs[#copy.stairs + 1] = Plans.copyStair(plan.stairs[i])
        end
    end

    if type(plan.furniture) == "table" then
        copy.furniture = {}
        for i = 1, #plan.furniture do
            copy.furniture[#copy.furniture + 1] = Plans.copyFurniture(plan.furniture[i])
        end
    end

    if type(plan.appliances) == "table" then
        copy.appliances = {}
        for i = 1, #plan.appliances do
            copy.appliances[#copy.appliances + 1] = Plans.copyAppliance(plan.appliances[i])
        end
    end

    if type(plan.decoratives) == "table" then
        copy.decoratives = {}
        for i = 1, #plan.decoratives do
            copy.decoratives[#copy.decoratives + 1] = Plans.copyDecorative(plan.decoratives[i])
        end
    end

    if type(plan.vegetation) == "table" then
        copy.vegetation = {}
        for i = 1, #plan.vegetation do
            copy.vegetation[#copy.vegetation + 1] = Plans.copyVegetation(plan.vegetation[i])
        end
    end

    return copy
end

---@param rectIndex integer
---@param plan table
---@return integer|nil
---@nodiscard
function Plans.getRoofZ(rectIndex, plan)
    if type(plan) ~= "table" or type(plan.rects) ~= "table" then return nil end
    local rect = plan.rects[rectIndex]
    if not rect then return nil end

    if type(plan.walls) ~= "table" then return nil end

    local maxZ = nil
    for i = 1, #plan.walls do
        local wall = plan.walls[i]
        if wall and Plans.wallSlotIsInsideRect(rect, wall.x, wall.y, wall.north == true) then
            local wz = wall.z or 0
            if maxZ == nil or wz > maxZ then maxZ = wz end
        end
    end

    if maxZ == nil then return nil end
    return maxZ + 1
end

---@param plan table
---@return table[]  list of `{fromZ,toZ,x,y}`
---@nodiscard
function Plans.getStairLinks(plan)
    local links = {}
    if type(plan) ~= "table" then return links end
    if type(plan.stairs) ~= "table" or #plan.stairs == 0 then return links end
    if type(plan.rects) ~= "table" or #plan.rects == 0 then return links end

    for i = 1, #plan.stairs do
        local stair = plan.stairs[i]
        if type(stair) == "table" and type(stair.x) == "number" and type(stair.y) == "number" then
            local sz = stair.z or 0
            local lx, ly, lz = Geometry.getStairLandingTile(stair)

            local hasUpperRect = false
            for ri = 1, #plan.rects do
                local r = plan.rects[ri]
                if (r.z or 0) == lz and Geometry.cellInOrAdjacentToRect(r, lx, ly) then
                    hasUpperRect = true
                    break
                end
            end

            if hasUpperRect then
                links[#links + 1] = {
                    fromZ = sz,
                    toZ   = lz,
                    x     = stair.x,
                    y     = stair.y,
                }
            end
        end
    end

    return links
end

---@param plan table
---@return table
function Plans.normalizePlan(plan)
    if type(plan) ~= "table" then return plan end
    plan.schemaVersion = 4
    if type(plan.walls)       ~= "table" then plan.walls       = {} end
    if type(plan.cells)       ~= "table" then plan.cells       = {} end
    if type(plan.roofs)       ~= "table" then plan.roofs       = {} end

    if type(plan.rects) ~= "table" or #plan.rects == 0 then
        plan.rects = {}
        if type(plan.rect) == "table"
            and type(plan.rect.x) == "number" and type(plan.rect.y) == "number"
            and type(plan.rect.z) == "number"
            and type(plan.rect.w) == "number" and type(plan.rect.h) == "number" then
            plan.rects[1] = {
                x = plan.rect.x,
                y = plan.rect.y,
                z = plan.rect.z,
                w = plan.rect.w,
                h = plan.rect.h,
                kind = "room",
            }
            plan.rect = nil
        elseif type(plan.x) == "number" and type(plan.y) == "number"
            and type(plan.z) == "number"
            and type(plan.w) == "number" and type(plan.h) == "number" then
            plan.rects[1] = {
                x = plan.x,
                y = plan.y,
                z = plan.z,
                w = plan.w,
                h = plan.h,
                kind = "room",
            }
        end
    end

    if type(plan.stairs)      ~= "table" then plan.stairs      = {} end
    if type(plan.furniture)   ~= "table" then plan.furniture   = {} end
    if type(plan.appliances)  ~= "table" then plan.appliances  = {} end
    if type(plan.decoratives) ~= "table" then plan.decoratives = {} end
    if type(plan.vegetation)  ~= "table" then plan.vegetation  = {} end
    return plan
end

return Plans
