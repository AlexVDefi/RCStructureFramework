local Geometry = require("RCStructureFramework/Geometry")
local Plans = require("RCStructureFramework/Plans")
local PieceLibrary = require("RCStructureFramework/PieceLibrary")
local RoomPersistence = require("RCStructureFramework/RoomPersistence")

---@class RCStructureFrameworkPlannedConstructions
---See docs/how-to/multiplayer.md for the server/client sync rules.
local PlannedConstructions = {}

PlannedConstructions.MOD_DATA_KEY = "RCStructureFrameworkPlanned"

local CHUNK_BUCKET_SIZE = 10

local clientCache = nil

local chunkIndex = nil
local chunkIndexDirty = true

---@return string
---@nodiscard
local function generateId()
    local ts = (type(getTimestampMs) == "function") and getTimestampMs() or os.time()
    local rnd = (type(ZombRand) == "function") and ZombRand(1000000000) or math.random(0, 999999999)
    return string.format("p%d-%d", ts, rnd)
end

---@param x integer
---@param y integer
---@param z integer
---@return string
---@nodiscard
local function cellKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

---@param x integer
---@param y integer
---@return integer chunkX, integer chunkY
---@nodiscard
local function chunkKey(x, y)
    return math.floor(x / CHUNK_BUCKET_SIZE), math.floor(y / CHUNK_BUCKET_SIZE)
end

---@return table
---@nodiscard
local function getServerRecords()
    local data = ModData.getOrCreate(PlannedConstructions.MOD_DATA_KEY)
    if data.records == nil then data.records = {} end
    return data.records
end

---@return nil
local function transmitRecords()
    if isServer and isServer() and ModData and ModData.transmit then
        ModData.transmit(PlannedConstructions.MOD_DATA_KEY)
    end
    chunkIndexDirty = true
end

---@param recipe table?
---@return table?
---@nodiscard
local function copyRecipe(recipe)
    if type(recipe) ~= "table" then return nil end
    local copy = {}
    for i = 1, #recipe do
        local r = recipe[i]
        if type(r) == "table" then
            copy[i] = {
                fullType = r.fullType,
                tag      = r.tag,
                count    = r.count,
                keep     = r.keep == true or nil,
            }
        end
    end
    return copy
end

---@param piecePlan table
---@return table|nil
---@nodiscard
local function resolveFrozenRecipe(piecePlan)
    if type(piecePlan.materialRecipe) == "table" then
        return copyRecipe(piecePlan.materialRecipe)
    end
    if type(piecePlan.spriteName) == "string" and piecePlan.spriteName ~= "" then
        local libPiece = PieceLibrary.find({ spriteName = piecePlan.spriteName })
        if libPiece and type(libPiece.materialRecipe) == "table" then
            return copyRecipe(libPiece.materialRecipe)
        end
    end
    return nil
end

---@param plan table
---@return table[]
---@nodiscard
local function flattenPlanToPieces(plan)
    ---@type table[]
    local pieces = {}
    ---@param arrName string
    ---@param kind string
    ---@return nil
    local function pushKindArray(arrName, kind)
        local arr = plan[arrName]
        if type(arr) ~= "table" then return end
        for i = 1, #arr do
            local p = arr[i]
            if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
                pieces[#pieces + 1] = {
                    kind       = kind,
                    x          = p.x,
                    y          = p.y,
                    z          = p.z or 0,
                    north      = p.north == true or nil,
                    spriteName = p.spriteName,
                    slotKind   = p.slotKind,
                    defId      = p.defId,
                    materialRecipe = resolveFrozenRecipe(p),
                    builtAt    = nil,
                    builtBy    = nil,
                    bottomSprite = p.bottomSprite,
                    middleSprite = p.middleSprite,
                    topSprite    = p.topSprite,
                    isRug      = p.isRug == true or nil,
                }
            end
        end
    end
    pushKindArray("walls",       "wall")
    pushKindArray("cells",       "cell")
    pushKindArray("roofs",       "roof")
    pushKindArray("stairs",      "stair")
    pushKindArray("furniture",   "furniture")
    pushKindArray("appliances",  "appliance")
    pushKindArray("decoratives", "decorative")
    pushKindArray("vegetation",  "vegetation")
    return pieces
end

---@return nil
local function reindexChunks()
    chunkIndex = {}
    local records = getServerRecords()
    for ri = 1, #records do
        local record = records[ri]
        if type(record) == "table" and type(record.pieces) == "table" then
            for pi = 1, #record.pieces do
                local p = record.pieces[pi]
                if p and type(p.x) == "number" and type(p.y) == "number" then
                    local cx, cy = chunkKey(p.x, p.y)
                    if not chunkIndex[cx] then chunkIndex[cx] = {} end
                    if not chunkIndex[cx][cy] then chunkIndex[cx][cy] = {} end
                    chunkIndex[cx][cy][record.id] = true
                end
            end
        end
    end
    chunkIndexDirty = false
end

---@return nil
local function ensureChunkIndex()
    if chunkIndexDirty or chunkIndex == nil then
        reindexChunks()
    end
end

---@return table[]
---@nodiscard
local function readSource()
    if isClient and isClient() and not (isServer and isServer()) then
        return clientCache or {}
    end
    return getServerRecords()
end

---@param params table  { ownerId, blueprintItemId?, plan }
---@return string|nil  recordId on success, nil on rejection
function PlannedConstructions.register(params)
    if isClient and isClient() then return nil end
    if type(params) ~= "table" or type(params.plan) ~= "table" then return nil end

    local id = generateId()
    local normalized = Plans.normalizePlan(Plans.copyPlan(params.plan))
    local record = {
        id              = id,
        ownerId         = params.ownerId,
        blueprintItemId = params.blueprintItemId,
        plan            = normalized,
        createdAtMs     = (type(getTimestampMs) == "function") and getTimestampMs() or 0,
        pieces          = flattenPlanToPieces(normalized),
    }

    local records = getServerRecords()
    records[#records + 1] = record
    transmitRecords()
    return id
end

---@param recordId string
---@param requesterId string
---@return boolean
function PlannedConstructions.cancel(recordId, requesterId)
    if isClient and isClient() then return false end
    if type(recordId) ~= "string" then return false end

    local records = getServerRecords()
    for i = 1, #records do
        if records[i].id == recordId then
            if requesterId ~= "ADMIN" and records[i].ownerId ~= requesterId then
                return false
            end
            table.remove(records, i)
            transmitRecords()
            return true
        end
    end
    return false
end

---@param recordId string
---@param pieceIndex integer
---@param builtBy string|nil
---@return boolean
function PlannedConstructions.markBuilt(recordId, pieceIndex, builtBy)
    if isClient and isClient() then return false end
    if type(recordId) ~= "string" or type(pieceIndex) ~= "number" then return false end

    local records = getServerRecords()
    local record = nil
    for i = 1, #records do
        if records[i].id == recordId then record = records[i]; break end
    end
    if not record then return false end

    local piece = record.pieces and record.pieces[pieceIndex]
    if not piece then return false end
    if piece.builtAt ~= nil then return true end

    piece.builtAt = (type(getTimestampMs) == "function") and getTimestampMs() or 0
    piece.builtBy = builtBy

    PlannedConstructions._tryCreateRoomsForCompleteGroups(record)

    transmitRecords()
    return true
end

---@private  internal: only called by markBuilt within this module
---@param record table
---@return nil
function PlannedConstructions._tryCreateRoomsForCompleteGroups(record)
    if type(record) ~= "table" or type(record.plan) ~= "table" then return end
    local plan = record.plan
    local structureId = plan.structureId
    if type(structureId) ~= "string" or structureId == "" then return end
    if type(plan.rects) ~= "table" or #plan.rects == 0 then return end

    ---@type table<string, boolean>
    local builtSet = {}
    for i = 1, #record.pieces do
        local p = record.pieces[i]
        if p.builtAt ~= nil then
            local key = (p.kind or "?") .. ":" .. cellKey(p.x, p.y, p.z) .. ":" .. tostring(p.north == true)
            builtSet[key] = true
        end
    end
    ---@param kind string?
    ---@param x integer
    ---@param y integer
    ---@param z integer
    ---@param north boolean?
    ---@return boolean
    ---@nodiscard
    local function isBuilt(kind, x, y, z, north)
        return builtSet[(kind or "?") .. ":" .. cellKey(x, y, z) .. ":" .. tostring(north == true)] == true
    end

    local groups = RoomPersistence.partitionRectsByConnectivity(plan.rects, plan.stairs)

    for gi = 1, #groups do
        local groupRects = groups[gi]
        local complete = true
        local hasBuiltStructure = false

        -- docs/concepts/authority-and-rooms.md.
        if type(plan.cells) == "table" then
            for ci = 1, #plan.cells do
                local c = plan.cells[ci]
                for ri = 1, #groupRects do
                    if Geometry.rectContainsCell(groupRects[ri], c.x, c.y)
                        and isBuilt("cell", c.x, c.y, c.z or 0, false) then
                        hasBuiltStructure = true
                        break
                    end
                end
            end
        end

        if complete and type(plan.walls) == "table" then
            for wi = 1, #plan.walls do
                local w = plan.walls[wi]
                local belongs = false
                for ri = 1, #groupRects do
                    if Plans.wallSlotIsInsideRect(groupRects[ri], w.x, w.y, w.north == true) then
                        belongs = true; break
                    end
                end
                if belongs then
                    if isBuilt("wall", w.x, w.y, w.z, w.north) then
                        hasBuiltStructure = true
                    else
                        complete = false; break
                    end
                end
            end
        end

        if complete and type(plan.roofs) == "table" then
            for rfi = 1, #plan.roofs do
                local roof = plan.roofs[rfi]
                local belongs = false
                for ri = 1, #groupRects do
                    if Geometry.rectContainsCell(groupRects[ri], roof.x, roof.y) then
                        belongs = true; break
                    end
                end
                if belongs and not isBuilt("roof", roof.x, roof.y, roof.z, roof.north) then
                    complete = false; break
                end
            end
        end

        complete = complete and hasBuiltStructure

        if complete then
            local groupStairs = nil
            if type(plan.stairs) == "table" and #plan.stairs > 0 then
                groupStairs = {}
                for si = 1, #plan.stairs do
                    local s = plan.stairs[si]
                    for ri = 1, #groupRects do
                        if (groupRects[ri].z or 0) == (s.z or 0)
                            and Geometry.cellInOrAdjacentToRect(groupRects[ri], s.x, s.y) then
                            groupStairs[#groupStairs + 1] = s; break
                        end
                    end
                end
                if #groupStairs == 0 then groupStairs = nil end
            end

            RoomPersistence.createRoom(structureId, {
                rects  = groupRects,
                stairs = groupStairs,
            }, false)
        end
    end
end

---re-running is harmless. See docs/concepts/authority-and-rooms.md.
---@return nil
function PlannedConstructions.reconcileRoomsOnLoad()
    if isClient and isClient() then return end
    local data = ModData.getOrCreate(PlannedConstructions.MOD_DATA_KEY)
    if data.roomReconcileV1 == true then return end
    if type(data.records) == "table" then
        for i = 1, #data.records do
            PlannedConstructions._tryCreateRoomsForCompleteGroups(data.records[i])
        end
    end
    data.roomReconcileV1 = true
    transmitRecords()
end

---@param recordId string
---@return table|nil
---@nodiscard
function PlannedConstructions.getRecord(recordId)
    if type(recordId) ~= "string" then return nil end
    local source = readSource()
    for i = 1, #source do
        if source[i].id == recordId then return source[i] end
    end
    return nil
end

---@param x integer
---@param y integer
---@param radiusChunks integer?
---@return table[]
---@nodiscard
function PlannedConstructions.getRecordsForChunk(x, y, radiusChunks)
    local r = radiusChunks or 1
    local cx0, cy0 = chunkKey(x, y)

    if isServer and isServer() then
        ensureChunkIndex()
        local seen = {}
        local out = {}
        for cx = cx0 - r, cx0 + r do
            local row = chunkIndex[cx]
            if row then
                for cy = cy0 - r, cy0 + r do
                    local bucket = row[cy]
                    if bucket then
                        for recordId in pairs(bucket) do
                            if not seen[recordId] then
                                seen[recordId] = true
                                local rec = PlannedConstructions.getRecord(recordId)
                                if rec then out[#out + 1] = rec end
                            end
                        end
                    end
                end
            end
        end
        return out
    end

    local source = readSource()
    local out = {}
    for i = 1, #source do
        local rec = source[i]
        if type(rec) == "table" and type(rec.pieces) == "table" then
            local touches = false
            for pi = 1, #rec.pieces do
                local p = rec.pieces[pi]
                if p then
                    local pcx, pcy = chunkKey(p.x, p.y)
                    if math.abs(pcx - cx0) <= r and math.abs(pcy - cy0) <= r then
                        touches = true; break
                    end
                end
            end
            if touches then out[#out + 1] = rec end
        end
    end
    return out
end

---@param candidatePlan table  v3 plan in world coords
---@return boolean intersects, table? conflictRecordIds
---@nodiscard
function PlannedConstructions.intersects(candidatePlan)
    if type(candidatePlan) ~= "table" then return false, nil end

    local source = readSource()
    ---@type table<string, string>
    local existingCells = {}
    for i = 1, #source do
        local rec = source[i]
        if type(rec) == "table" and type(rec.pieces) == "table" then
            for pi = 1, #rec.pieces do
                local p = rec.pieces[pi]
                if p and p.builtAt == nil and type(p.x) == "number" then
                    existingCells[cellKey(p.x, p.y, p.z or 0)] = rec.id
                end
            end
        end
    end

    ---@type table<string, boolean>
    local conflicts = {}
    ---@param arrName string
    ---@return nil
    local function check(arrName)
        local arr = candidatePlan[arrName]
        if type(arr) ~= "table" then return end
        for i = 1, #arr do
            local p = arr[i]
            if p and type(p.x) == "number" then
                local id = existingCells[cellKey(p.x, p.y, p.z or 0)]
                if id and not conflicts[id] then conflicts[id] = true end
            end
        end
    end
    check("walls"); check("cells"); check("roofs")
    check("stairs"); check("furniture"); check("appliances")
    check("decoratives"); check("vegetation")

    ---@type string[]
    local ids = {}
    for id in pairs(conflicts) do ids[#ids + 1] = id end
    if #ids == 0 then return false, nil end
    return true, ids
end

---@param player IsoPlayer|nil  reserved (auth checks layered by caller)
---@param opts table?
---@return table|nil record, integer|nil pieceIndex
---@nodiscard
function PlannedConstructions.getNextUnbuiltPieceFor(player, opts)
    opts = opts or {}
    local source = readSource()
    if type(source) ~= "table" then return nil, nil end

    local fallbackRec, fallbackIdx = nil, nil

    for i = 1, #source do
        local rec = source[i]
        local matches = (not opts.recordId) or rec.id == opts.recordId
        if matches and type(rec.pieces) == "table" then
            for pi = 1, #rec.pieces do
                local p = rec.pieces[pi]
                if p and p.builtAt == nil
                    and not (opts.exclude and opts.exclude[p.kind]) then
                    if opts.preferMaterial and type(p.materialRecipe) == "table" then
                        local first = p.materialRecipe[1]
                        if first and first.fullType == opts.preferMaterial then
                            return rec, pi
                        end
                    end
                    if not fallbackRec then
                        fallbackRec, fallbackIdx = rec, pi
                    end
                end
            end
        end
    end

    return fallbackRec, fallbackIdx
end

---@param recordId string
---@param opts table?  { exclude = { kind = true,... } }
---@return table  { pieces, totalsByFullType, totalsByTag, requirements }
---@nodiscard
function PlannedConstructions.getRequiredMaterials(recordId, opts)
    opts = opts or {}
    local rec = PlannedConstructions.getRecord(recordId)
    if not rec or type(rec.pieces) ~= "table" then
        return { pieces = 0, totalsByFullType = {}, totalsByTag = {}, requirements = {} }
    end

    ---@type table<string, integer>
    local totalsByFullType = {}
    ---@type table<string, integer>
    local totalsByTag = {}
    ---@type table[]
    local requirements = {}
    local pieceCount = 0

    for i = 1, #rec.pieces do
        local p = rec.pieces[i]
        if p and p.builtAt == nil
            and not (opts.exclude and opts.exclude[p.kind])
            and type(p.materialRecipe) == "table" then
            pieceCount = pieceCount + 1
            for j = 1, #p.materialRecipe do
                local req = p.materialRecipe[j]
                if type(req) == "table" then
                    local needed = req.count or 1
                    if not req.keep then
                        if req.fullType then
                            totalsByFullType[req.fullType] = (totalsByFullType[req.fullType] or 0) + needed
                        elseif req.tag then
                            totalsByTag[req.tag] = (totalsByTag[req.tag] or 0) + needed
                        end
                    end
                    requirements[#requirements + 1] = { req = req, count = needed }
                end
            end
        end
    end

    return {
        pieces           = pieceCount,
        totalsByFullType = totalsByFullType,
        totalsByTag      = totalsByTag,
        requirements     = requirements,
    }
end

---@param name string
---@param data table
---@return nil
local function onReceiveGlobalModData(name, data)
    if name ~= PlannedConstructions.MOD_DATA_KEY then return end
    if type(data) ~= "table" or type(data.records) ~= "table" then
        clientCache = {}
        return
    end
    ---@type table[]
    local cache = {}
    for i = 1, #data.records do cache[i] = data.records[i] end
    clientCache = cache
end

---@return nil
local function requestInitialSync()
    if isClient and isClient() and ModData and ModData.request then
        ModData.request(PlannedConstructions.MOD_DATA_KEY)
    end
end

---@return nil
local function reconcileRoomsOnLoad()
    PlannedConstructions.reconcileRoomsOnLoad()
end

local registered = false

---@return nil
function PlannedConstructions.registerEvents()
    if registered then return end
    registered = true
    if Events and Events.OnReceiveGlobalModData then
        Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)
    end
    if Events and Events.OnGameStart then
        Events.OnGameStart.Add(requestInitialSync)
    end
    if Events and Events.OnLoadedMapZones then
        Events.OnLoadedMapZones.Add(reconcileRoomsOnLoad)
    end
end

---@return nil
function PlannedConstructions.unregisterEvents()
    if not registered then return end
    registered = false
    if Events and Events.OnReceiveGlobalModData then
        Events.OnReceiveGlobalModData.Remove(onReceiveGlobalModData)
    end
    if Events and Events.OnGameStart then
        Events.OnGameStart.Remove(requestInitialSync)
    end
    if Events and Events.OnLoadedMapZones then
        Events.OnLoadedMapZones.Remove(reconcileRoomsOnLoad)
    end
end

return PlannedConstructions
