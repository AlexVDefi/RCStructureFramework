local Registry = require("RCStructureFramework/Registry")
local Migrations = require("RCStructureFramework/Migrations")
local Json = require("RCStructureFramework/Json")
---@class RCStructureFrameworkPresets
local Presets = {}

---@param value any
---@return string
---@nodiscard
function Presets.jsonEncode(value)
    return Json.encode(value)
end

---@param text string
---@return any|nil
---@nodiscard
function Presets.jsonDecode(text)
    return Json.decode(text)
end

---@param structureId string
---@return string
---@nodiscard
local function getPresetFile(structureId)
    local def = Registry.getStructure(structureId)
    if def and type(def.presetsFile) == "string" and def.presetsFile ~= "" then
        return def.presetsFile
    end
    return "RCStructureFramework_" .. tostring(structureId) .. "_Presets.json"
end

---@param structureId string
---@param plan table
---@return table
---@nodiscard
function Presets.toRelative(structureId, plan)
    local planZ = plan.z or 0

    local walls = {}
    if type(plan.walls) == "table" then
        for i = 1, #plan.walls do
            local w = plan.walls[i]
            walls[#walls + 1] = {
                dx = w.x - plan.x,
                dy = w.y - plan.y,
                dz = (w.z or planZ) - planZ,
                north = w.north == true,
                wallType = w.wallType,
                slotKind = w.slotKind,
                spriteName = w.spriteName,
                wallpaperSpriteName = w.wallpaperSpriteName,
            }
        end
    end

    local cells = {}
    if type(plan.cells) == "table" then
        for i = 1, #plan.cells do
            local c = plan.cells[i]
            cells[#cells + 1] = {
                dx = c.x - plan.x,
                dy = c.y - plan.y,
                dz = (c.z or planZ) - planZ,
                spriteName = c.spriteName,
                isRug = c.isRug == true and true or nil,
            }
        end
    end

    local roofs = {}
    if type(plan.roofs) == "table" then
        for i = 1, #plan.roofs do
            local r = plan.roofs[i]
            roofs[#roofs + 1] = {
                dx = r.x - plan.x,
                dy = r.y - plan.y,
                dz = r.z - planZ,
                north = r.north == true,
                spriteName = r.spriteName,
                slope = r.slope,
                roofKind = r.roofKind,
            }
        end
    end

    local rects = nil
    if type(plan.rects) == "table" and #plan.rects > 0 then
        rects = {}
        for i = 1, #plan.rects do
            local rr = plan.rects[i]
            rects[#rects + 1] = {
                dx = rr.x - plan.x,
                dy = rr.y - plan.y,
                dz = (rr.z or planZ) - planZ,
                w = rr.w,
                h = rr.h,
                kind = rr.kind,
            }
        end
    end

    local stairs = {}
    if type(plan.stairs) == "table" then
        for i = 1, #plan.stairs do
            local s = plan.stairs[i]
            stairs[#stairs + 1] = {
                dx = s.x - plan.x,
                dy = s.y - plan.y,
                dz = (s.z or planZ) - planZ,
                north = s.north == true,
                bottomSprite = s.bottomSprite,
                middleSprite = s.middleSprite,
                topSprite = s.topSprite,
                pillarSprite = s.pillarSprite,
            }
        end
    end

    local furniture = {}
    if type(plan.furniture) == "table" then
        for i = 1, #plan.furniture do
            local f = plan.furniture[i]
            local fp = nil
            if type(f.footprint) == "table" then
                fp = { w = f.footprint.w, h = f.footprint.h }
            end
            furniture[#furniture + 1] = {
                dx = f.x - plan.x,
                dy = f.y - plan.y,
                dz = (f.z or planZ) - planZ,
                facing = f.facing,
                defId = f.defId,
                spriteName = f.spriteName,
                footprint = fp,
                anchor = f.anchor or "origin",
            }
        end
    end

    local appliances = {}
    if type(plan.appliances) == "table" then
        for i = 1, #plan.appliances do
            local a = plan.appliances[i]
            local fp = nil
            if type(a.footprint) == "table" then
                fp = { w = a.footprint.w, h = a.footprint.h }
            end
            local utilities = nil
            if type(a.utilities) == "table" then
                utilities = { power = a.utilities.power, water = a.utilities.water }
            end
            appliances[#appliances + 1] = {
                dx = a.x - plan.x,
                dy = a.y - plan.y,
                dz = (a.z or planZ) - planZ,
                facing = a.facing,
                defId = a.defId,
                spriteName = a.spriteName,
                footprint = fp,
                anchor = a.anchor or "origin",
                utilities = utilities,
            }
        end
    end

    local decoratives = {}
    if type(plan.decoratives) == "table" then
        for i = 1, #plan.decoratives do
            local d = plan.decoratives[i]
            decoratives[#decoratives + 1] = {
                dx = d.x - plan.x,
                dy = d.y - plan.y,
                dz = (d.z or planZ) - planZ,
                facing = d.facing,
                defId = d.defId,
                spriteName = d.spriteName,
                anchor = d.anchor or "origin",
            }
        end
    end

    local vegetation = {}
    if type(plan.vegetation) == "table" then
        for i = 1, #plan.vegetation do
            local v = plan.vegetation[i]
            vegetation[#vegetation + 1] = {
                dx = v.x - plan.x,
                dy = v.y - plan.y,
                dz = (v.z or planZ) - planZ,
                defId = v.defId,
                spriteName = v.spriteName,
            }
        end
    end

    return {
        name = "",
        version = Migrations.CURRENT_PRESET_VERSION,
        structureId = structureId,
        variant = plan.variant or plan.color,
        w = plan.w,
        h = plan.h,
        gableAxis = plan.gableAxis,
        walls = walls,
        cells = cells,
        roofs = roofs,
        rects = rects,
        stairs = stairs,
        furniture = furniture,
        appliances = appliances,
        decoratives = decoratives,
        vegetation = vegetation,
    }
end

---@param structureId string
---@param preset table
---@param anchorX number
---@param anchorY number
---@param z number
---@return table
---@nodiscard
function Presets.toPlanAt(structureId, preset, anchorX, anchorY, z)
    local walls = {}
    if type(preset.walls) == "table" then
        for i = 1, #preset.walls do
            local w = preset.walls[i]
            local dx = type(w.dx) == "number" and w.dx or 0
            local dy = type(w.dy) == "number" and w.dy or 0
            local dz = type(w.dz) == "number" and w.dz or 0
            walls[#walls + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                north = w.north == true,
                wallType = w.wallType,
                slotKind = w.slotKind,
                spriteName = w.spriteName,
                wallpaperSpriteName = w.wallpaperSpriteName,
            }
        end
    end

    local cells = {}
    if type(preset.cells) == "table" then
        for i = 1, #preset.cells do
            local c = preset.cells[i]
            local dx = type(c.dx) == "number" and c.dx or 0
            local dy = type(c.dy) == "number" and c.dy or 0
            local dz = type(c.dz) == "number" and c.dz or 0
            cells[#cells + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                spriteName = c.spriteName,
                isRug = c.isRug == true and true or nil,
            }
        end
    end

    local roofs = {}
    if type(preset.roofs) == "table" then
        for i = 1, #preset.roofs do
            local r = preset.roofs[i]
            local dx = type(r.dx) == "number" and r.dx or 0
            local dy = type(r.dy) == "number" and r.dy or 0
            local dz = type(r.dz) == "number" and r.dz or 0
            roofs[#roofs + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                north = r.north == true,
                spriteName = r.spriteName,
                slope = r.slope,
                roofKind = r.roofKind,
            }
        end
    end

    local rects = nil
    if type(preset.rects) == "table" and #preset.rects > 0 then
        rects = {}
        for i = 1, #preset.rects do
            local rr = preset.rects[i]
            local dx = type(rr.dx) == "number" and rr.dx or 0
            local dy = type(rr.dy) == "number" and rr.dy or 0
            local dz = type(rr.dz) == "number" and rr.dz or 0
            rects[#rects + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                w = rr.w,
                h = rr.h,
                kind = rr.kind,
            }
        end
    end

    local stairs = {}
    if type(preset.stairs) == "table" then
        for i = 1, #preset.stairs do
            local s = preset.stairs[i]
            local dx = type(s.dx) == "number" and s.dx or 0
            local dy = type(s.dy) == "number" and s.dy or 0
            local dz = type(s.dz) == "number" and s.dz or 0
            stairs[#stairs + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                north = s.north == true,
                bottomSprite = s.bottomSprite,
                middleSprite = s.middleSprite,
                topSprite = s.topSprite,
                pillarSprite = s.pillarSprite,
            }
        end
    end

    local furniture = {}
    if type(preset.furniture) == "table" then
        for i = 1, #preset.furniture do
            local f = preset.furniture[i]
            local dx = type(f.dx) == "number" and f.dx or 0
            local dy = type(f.dy) == "number" and f.dy or 0
            local dz = type(f.dz) == "number" and f.dz or 0
            local fp = nil
            if type(f.footprint) == "table" then
                fp = { w = f.footprint.w, h = f.footprint.h }
            end
            furniture[#furniture + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                facing = f.facing,
                defId = f.defId,
                spriteName = f.spriteName,
                footprint = fp,
                anchor = f.anchor or "origin",
            }
        end
    end

    local appliances = {}
    if type(preset.appliances) == "table" then
        for i = 1, #preset.appliances do
            local a = preset.appliances[i]
            local dx = type(a.dx) == "number" and a.dx or 0
            local dy = type(a.dy) == "number" and a.dy or 0
            local dz = type(a.dz) == "number" and a.dz or 0
            local fp = nil
            if type(a.footprint) == "table" then
                fp = { w = a.footprint.w, h = a.footprint.h }
            end
            local utilities = nil
            if type(a.utilities) == "table" then
                utilities = { power = a.utilities.power, water = a.utilities.water }
            end
            appliances[#appliances + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                facing = a.facing,
                defId = a.defId,
                spriteName = a.spriteName,
                footprint = fp,
                anchor = a.anchor or "origin",
                utilities = utilities,
            }
        end
    end

    local decoratives = {}
    if type(preset.decoratives) == "table" then
        for i = 1, #preset.decoratives do
            local d = preset.decoratives[i]
            local dx = type(d.dx) == "number" and d.dx or 0
            local dy = type(d.dy) == "number" and d.dy or 0
            local dz = type(d.dz) == "number" and d.dz or 0
            decoratives[#decoratives + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                facing = d.facing,
                defId = d.defId,
                spriteName = d.spriteName,
                anchor = d.anchor or "origin",
            }
        end
    end

    local vegetation = {}
    if type(preset.vegetation) == "table" then
        for i = 1, #preset.vegetation do
            local v = preset.vegetation[i]
            local dx = type(v.dx) == "number" and v.dx or 0
            local dy = type(v.dy) == "number" and v.dy or 0
            local dz = type(v.dz) == "number" and v.dz or 0
            vegetation[#vegetation + 1] = {
                x = anchorX + dx,
                y = anchorY + dy,
                z = z + dz,
                defId = v.defId,
                spriteName = v.spriteName,
            }
        end
    end

    return {
        version = preset.version or Migrations.CURRENT_PRESET_VERSION,
        schemaVersion = 4,
        structureId = structureId,
        variant = preset.variant,
        color = preset.variant,
        x = anchorX,
        y = anchorY,
        z = z,
        w = preset.w,
        h = preset.h,
        gableAxis = preset.gableAxis,
        walls = walls,
        cells = cells,
        roofs = roofs,
        rects = rects,
        stairs = stairs,
        furniture = furniture,
        appliances = appliances,
        decoratives = decoratives,
        vegetation = vegetation,
    }
end

---@param structureId string
---@param entry table
---@return table|nil
---@nodiscard
local function validatePreset(structureId, entry)
    if type(entry) ~= "table" then return nil end
    if type(entry.name) ~= "string" or entry.name == "" then return nil end
    if type(entry.w) ~= "number" or type(entry.h) ~= "number" then return nil end
    if entry.w < 1 or entry.h < 1 then return nil end

    entry = Migrations.migratePreset(entry)

    local cleanWalls = {}
    if type(entry.walls) == "table" then
        for i = 1, #entry.walls do
            local w = entry.walls[i]
            if type(w) == "table" and type(w.dx) == "number" and type(w.dy) == "number" then
                local slotKind = w.slotKind
                if type(slotKind) ~= "string" or slotKind == "" then
                    slotKind = "wall"
                end
                cleanWalls[#cleanWalls + 1] = {
                    dx = math.floor(w.dx),
                    dy = math.floor(w.dy),
                    dz = type(w.dz) == "number" and math.floor(w.dz) or 0,
                    north = w.north == true,
                    wallType = w.wallType,
                    slotKind = slotKind,
                    spriteName = type(w.spriteName) == "string" and w.spriteName or nil,
                    wallpaperSpriteName = type(w.wallpaperSpriteName) == "string" and w.wallpaperSpriteName or nil,
                }
            end
        end
    end

    local cleanCells = {}
    if type(entry.cells) == "table" then
        for i = 1, #entry.cells do
            local c = entry.cells[i]
            if type(c) == "table" and type(c.dx) == "number" and type(c.dy) == "number" then
                cleanCells[#cleanCells + 1] = {
                    dx = math.floor(c.dx),
                    dy = math.floor(c.dy),
                    dz = type(c.dz) == "number" and math.floor(c.dz) or 0,
                    spriteName = type(c.spriteName) == "string" and c.spriteName or nil,
                    isRug = c.isRug == true and true or nil,
                }
            end
        end
    end

    local cleanRoofs = {}
    if type(entry.roofs) == "table" then
        for i = 1, #entry.roofs do
            local r = entry.roofs[i]
            if type(r) == "table" and type(r.dx) == "number" and type(r.dy) == "number" then
                cleanRoofs[#cleanRoofs + 1] = {
                    dx = math.floor(r.dx),
                    dy = math.floor(r.dy),
                    dz = type(r.dz) == "number" and math.floor(r.dz) or 0,
                    north = r.north == true,
                    spriteName = type(r.spriteName) == "string" and r.spriteName or nil,
                    slope = r.slope,
                    roofKind = type(r.roofKind) == "string" and r.roofKind or nil,
                }
            end
        end
    end

    local cleanRects = nil
    if type(entry.rects) == "table" and #entry.rects > 0 then
        cleanRects = {}
        for i = 1, #entry.rects do
            local rr = entry.rects[i]
            if type(rr) == "table"
                and type(rr.dx) == "number" and type(rr.dy) == "number"
                and type(rr.w) == "number" and type(rr.h) == "number"
                and rr.w >= 1 and rr.h >= 1 then
                local kind = rr.kind
                if type(kind) ~= "string" or kind == "" then
                    kind = "room"
                end
                cleanRects[#cleanRects + 1] = {
                    dx = math.floor(rr.dx),
                    dy = math.floor(rr.dy),
                    dz = type(rr.dz) == "number" and math.floor(rr.dz) or 0,
                    w = math.floor(rr.w),
                    h = math.floor(rr.h),
                    kind = kind,
                }
            end
        end
        if #cleanRects == 0 then cleanRects = nil end
    end

    local cleanStairs = {}
    if type(entry.stairs) == "table" then
        for i = 1, #entry.stairs do
            local s = entry.stairs[i]
            if type(s) == "table" and type(s.dx) == "number" and type(s.dy) == "number" then
                cleanStairs[#cleanStairs + 1] = {
                    dx = math.floor(s.dx),
                    dy = math.floor(s.dy),
                    dz = type(s.dz) == "number" and math.floor(s.dz) or 0,
                    north = s.north == true,
                    bottomSprite = type(s.bottomSprite) == "string" and s.bottomSprite or nil,
                    middleSprite = type(s.middleSprite) == "string" and s.middleSprite or nil,
                    topSprite = type(s.topSprite) == "string" and s.topSprite or nil,
                    pillarSprite = type(s.pillarSprite) == "string" and s.pillarSprite or nil,
                }
            end
        end
    end

    ---@param fp table?
    ---@return table?
    ---@nodiscard
    local function cleanFootprint(fp)
        if type(fp) ~= "table" then return nil end
        if type(fp.w) ~= "number" or type(fp.h) ~= "number" then return nil end
        if fp.w < 1 or fp.h < 1 then return nil end
        return { w = math.floor(fp.w), h = math.floor(fp.h) }
    end

    local cleanFurniture = {}
    if type(entry.furniture) == "table" then
        for i = 1, #entry.furniture do
            local f = entry.furniture[i]
            if type(f) == "table" and type(f.dx) == "number" and type(f.dy) == "number" then
                local anchor = f.anchor
                if type(anchor) ~= "string" or anchor == "" then anchor = "origin" end
                cleanFurniture[#cleanFurniture + 1] = {
                    dx = math.floor(f.dx),
                    dy = math.floor(f.dy),
                    dz = type(f.dz) == "number" and math.floor(f.dz) or 0,
                    facing = f.facing,
                    defId = type(f.defId) == "string" and f.defId or nil,
                    spriteName = type(f.spriteName) == "string" and f.spriteName or nil,
                    footprint = cleanFootprint(f.footprint),
                    anchor = anchor,
                }
            end
        end
    end

    local cleanAppliances = {}
    if type(entry.appliances) == "table" then
        for i = 1, #entry.appliances do
            local a = entry.appliances[i]
            if type(a) == "table" and type(a.dx) == "number" and type(a.dy) == "number" then
                local anchor = a.anchor
                if type(anchor) ~= "string" or anchor == "" then anchor = "origin" end
                local utilities = nil
                if type(a.utilities) == "table" then
                    utilities = { power = a.utilities.power, water = a.utilities.water }
                end
                cleanAppliances[#cleanAppliances + 1] = {
                    dx = math.floor(a.dx),
                    dy = math.floor(a.dy),
                    dz = type(a.dz) == "number" and math.floor(a.dz) or 0,
                    facing = a.facing,
                    defId = type(a.defId) == "string" and a.defId or nil,
                    spriteName = type(a.spriteName) == "string" and a.spriteName or nil,
                    footprint = cleanFootprint(a.footprint),
                    anchor = anchor,
                    utilities = utilities,
                }
            end
        end
    end

    local cleanDecoratives = {}
    if type(entry.decoratives) == "table" then
        for i = 1, #entry.decoratives do
            local d = entry.decoratives[i]
            if type(d) == "table" and type(d.dx) == "number" and type(d.dy) == "number" then
                local anchor = d.anchor
                if type(anchor) ~= "string" or anchor == "" then anchor = "origin" end
                cleanDecoratives[#cleanDecoratives + 1] = {
                    dx = math.floor(d.dx),
                    dy = math.floor(d.dy),
                    dz = type(d.dz) == "number" and math.floor(d.dz) or 0,
                    facing = d.facing,
                    defId = type(d.defId) == "string" and d.defId or nil,
                    spriteName = type(d.spriteName) == "string" and d.spriteName or nil,
                    anchor = anchor,
                }
            end
        end
    end

    local cleanVegetation = {}
    if type(entry.vegetation) == "table" then
        for i = 1, #entry.vegetation do
            local v = entry.vegetation[i]
            if type(v) == "table" and type(v.dx) == "number" and type(v.dy) == "number" then
                cleanVegetation[#cleanVegetation + 1] = {
                    dx = math.floor(v.dx),
                    dy = math.floor(v.dy),
                    dz = type(v.dz) == "number" and math.floor(v.dz) or 0,
                    defId = type(v.defId) == "string" and v.defId or nil,
                    spriteName = type(v.spriteName) == "string" and v.spriteName or nil,
                }
            end
        end
    end

    return {
        name = entry.name,
        version = Migrations.CURRENT_PRESET_VERSION,
        structureId = structureId,
        variant = entry.variant,
        w = math.floor(entry.w),
        h = math.floor(entry.h),
        gableAxis = entry.gableAxis,
        walls = cleanWalls,
        cells = cleanCells,
        roofs = cleanRoofs,
        rects = cleanRects,
        stairs = cleanStairs,
        furniture = cleanFurniture,
        appliances = cleanAppliances,
        decoratives = cleanDecoratives,
        vegetation = cleanVegetation,
    }
end

---@param structureId string
---@return table
---@nodiscard
function Presets.load(structureId)
    local reader = getFileReader(getPresetFile(structureId), false)
    if not reader then return {} end

    local content = ""
    while true do
        local line = reader:readLine()
        if not line then break end
        content = content .. line .. "\n"
    end
    reader:close()

    local decoded = Presets.jsonDecode(content)
    if type(decoded) ~= "table" then return {} end

    local result = {}
    for i = 1, #decoded do
        local clean = validatePreset(structureId, decoded[i])
        if clean then result[#result + 1] = clean end
    end
    return result
end

---@param structureId string
---@param list table
---@return nil
function Presets.save(structureId, list)
    local writer = getFileWriter(getPresetFile(structureId), true, false)
    if not writer then return end
    local output = list
    if output == nil then
        output = {}
    end
    writer:write(Presets.jsonEncode(output))
    writer:close()
end

---@param list table
---@param name string
---@return string
---@nodiscard
local function uniqueName(list, name)
    ---@type table<string, boolean>
    local taken = {}
    for i = 1, #list do
        taken[list[i].name] = true
    end
    if not taken[name] then return name end
    local n = 2
    while taken[name .. " (" .. tostring(n) .. ")"] do
        n = n + 1
    end
    return name .. " (" .. tostring(n) .. ")"
end

---@param structureId string
---@param preset table
---@return nil
function Presets.add(structureId, preset)
    local list = Presets.load(structureId)
    local clean = validatePreset(structureId, preset)
    if not clean then return end
    clean.name = uniqueName(list, clean.name)
    list[#list + 1] = clean
    Presets.save(structureId, list)
end

---@param structureId string
---@param index integer
---@return nil
function Presets.remove(structureId, index)
    local list = Presets.load(structureId)
    if index < 1 or index > #list then return end
    table.remove(list, index)
    Presets.save(structureId, list)
end

---@param structureId string
---@param index integer
---@param name string
---@return nil
function Presets.rename(structureId, index, name)
    local list = Presets.load(structureId)
    if index < 1 or index > #list then return end
    if type(name) ~= "string" or name == "" then return end
    list[index].name = uniqueName(list, name)
    Presets.save(structureId, list)
end

return Presets
