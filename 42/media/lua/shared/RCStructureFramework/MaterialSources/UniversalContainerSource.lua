---@class RCStructureFrameworkUniversalContainerSource
local UniversalContainerSource = {}
UniversalContainerSource.__index = UniversalContainerSource

local PIECE_COUNTS_KEY = "RCStructureFramework.pieceCounts"

---@param container InventoryItem
---@return table
---@nodiscard
local function getCountsTable(container)
    local modData = container:getModData()
    if type(modData[PIECE_COUNTS_KEY]) ~= "table" then
        modData[PIECE_COUNTS_KEY] = {}
    end
    return modData[PIECE_COUNTS_KEY]
end

---@param ctx table  { character, container }
---@return table?
---@nodiscard
function UniversalContainerSource.create(ctx)
    if not ctx or not ctx.container then return nil end
    local self = setmetatable({}, UniversalContainerSource)
    self.character = ctx.character
    self.container = ctx.container
    return self
end

---@param req table
---@return integer
---@nodiscard
local function reqCount(req)
    local count = req and req.count
    if type(count) ~= "number" or count <= 0 then return 0 end
    return math.floor(count)
end

---@param req table?
---@return string?
---@nodiscard
local function reqPieceId(req)
    if not req then return nil end
    local id = req.pieceId
    if type(id) ~= "string" or id == "" then return nil end
    return id
end

---@param req table?
---@return boolean
---@nodiscard
function UniversalContainerSource:canConsume(req)
    local count = reqCount(req)
    if count == 0 then return true end
    local pieceId = reqPieceId(req)
    if not pieceId then return false end
    local counts = getCountsTable(self.container)
    return (counts[pieceId] or 0) >= count
end

---@param req table?
---@return boolean
function UniversalContainerSource:consume(req)
    local count = reqCount(req)
    if count == 0 then return true end
    local pieceId = reqPieceId(req)
    if not pieceId then return false end

    local counts = getCountsTable(self.container)
    local available = counts[pieceId] or 0
    if available < count then return false end

    counts[pieceId] = available - count
    self:_sync()
    return true
end

---@param req table?
---@return boolean
function UniversalContainerSource:refund(req)
    local count = reqCount(req)
    if count == 0 then return true end
    local pieceId = reqPieceId(req)
    if not pieceId then return false end

    local counts = getCountsTable(self.container)
    counts[pieceId] = (counts[pieceId] or 0) + count
    self:_sync()
    return true
end

---@return nil
function UniversalContainerSource:_sync()
    if isClient() or isServer() then
        syncItemFields(self.character, self.container)
    end
end

---@return table
---@nodiscard
function UniversalContainerSource:availableSummary()
    local counts = getCountsTable(self.container)
    ---@type table<string, integer>
    local copy = {}
    for k, v in pairs(counts) do copy[k] = v end
    return { kind = "universal", pieceCounts = copy }
end

---@return string
---@nodiscard
function UniversalContainerSource:describe()
    return "universal"
end

---@param container InventoryItem
---@param pieceCounts table<string, integer>
---@return nil
function UniversalContainerSource.seed(container, pieceCounts)
    if not container or type(pieceCounts) ~= "table" then return end
    local modData = container:getModData()
    ---@type table<string, integer>
    local table_ = {}
    for id, count in pairs(pieceCounts) do
        if type(id) == "string" and type(count) == "number" and count > 0 then
            table_[id] = math.floor(count)
        end
    end
    modData[PIECE_COUNTS_KEY] = table_
end

UniversalContainerSource.PIECE_COUNTS_KEY = PIECE_COUNTS_KEY

return UniversalContainerSource
