local Registry = require("RCStructureFramework/Registry")
local PieceLibrary = require("RCStructureFramework/PieceLibrary")

---See docs/how-to/introspection.md for the API.
---@class RCStructureFrameworkIntrospect
local Introspect = {}

---@param value any
---@return boolean
---@nodiscard
local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

---@param list table?
---@return table
---@nodiscard
local function copyList(list)
    local out = {}
    if type(list) == "table" then
        for i = 1, #list do out[i] = list[i] end
    end
    return out
end

---@param structureId string
---@return integer
---@nodiscard
local function countPiecesForStructure(structureId)
    local n = 0
    for piece in PieceLibrary.iter() do
        if piece.structureId == structureId then n = n + 1 end
    end
    return n
end

---@param def table
---@return table
---@nodiscard
local function structureSummary(def)
    local materialSourceKind = nil
    if type(def.createMaterialSource) == "function" then
        materialSourceKind = "custom"
    elseif isNonEmptyString(def.materialSource) then
        materialSourceKind = def.materialSource
    end

    local buildMode = "none"
    if def.useGenericBuilder == true then
        buildMode = "generic"
    elseif type(def.buildFromContainer) == "function" then
        buildMode = "legacy"
    end

    return {
        id = def.id,
        roomName = def.roomName,
        variantIds = copyList(def.variantIds),
        useGenericBuilder = def.useGenericBuilder == true,
        materialSource = def.materialSource,
        materialSourceKind = materialSourceKind,
        buildMode = buildMode,
        hasValidation = type(def.validation) == "table",
        pieceCount = countPiecesForStructure(def.id),
    }
end

---@param structureId string
---@return boolean
---@nodiscard
function Introspect.hasStructure(structureId)
    return Registry.getStructure(structureId) ~= nil
end

---@return string[]
---@nodiscard
function Introspect.listStructureIds()
    ---@type string[]
    local ids = {}
    for id, _ in pairs(Registry.getAllStructures()) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

---@param structureId string
---@return table|nil
---@nodiscard
function Introspect.getStructure(structureId)
    local def = Registry.getStructure(structureId)
    if not def then return nil end
    return structureSummary(def)
end

---@return table[]
---@nodiscard
function Introspect.listStructures()
    ---@type table[]
    local out = {}
    local ids = Introspect.listStructureIds()
    for i = 1, #ids do
        out[i] = structureSummary(Registry.getStructure(ids[i]))
    end
    return out
end

---@param structureId string
---@return string[]
---@nodiscard
function Introspect.listVariants(structureId)
    local def = Registry.getStructure(structureId)
    if not def then return {} end
    return copyList(def.variantIds)
end

---@param pieceId string
---@return table|nil
---@nodiscard
function Introspect.getPiece(pieceId)
    local piece = PieceLibrary.get(pieceId)
    if not piece then return nil end
    local copy = {}
    for k, v in pairs(piece) do copy[k] = v end
    return copy
end

---@param piece table
---@param filter table
---@return boolean
---@nodiscard
local function pieceMatches(piece, filter)
    if isNonEmptyString(filter.structureId) and piece.structureId ~= filter.structureId then
        return false
    end
    if isNonEmptyString(filter.category) and piece.category ~= filter.category then
        return false
    end
    if isNonEmptyString(filter.categoryGroup) and piece.categoryGroup ~= filter.categoryGroup then
        return false
    end
    if isNonEmptyString(filter.variant) and piece.variant ~= filter.variant then
        return false
    end
    if isNonEmptyString(filter.pieceType) and piece.pieceType ~= filter.pieceType then
        return false
    end
    if isNonEmptyString(filter.tag) then
        local found = false
        if type(piece.tags) == "table" then
            for i = 1, #piece.tags do
                if piece.tags[i] == filter.tag then found = true; break end
            end
        end
        if not found then return false end
    end
    return true
end

---@param filter table?
---@return table[]
---@nodiscard
function Introspect.listPieces(filter)
    filter = filter or {}
    ---@type table[]
    local out = {}
    for piece in PieceLibrary.iter() do
        if pieceMatches(piece, filter) then
            local copy = {}
            for k, v in pairs(piece) do copy[k] = v end
            out[#out + 1] = copy
        end
    end
    return out
end

---@param filter table?
---@return integer
---@nodiscard
function Introspect.countPieces(filter)
    filter = filter or {}
    local n = 0
    for piece in PieceLibrary.iter() do
        if pieceMatches(piece, filter) then n = n + 1 end
    end
    return n
end

---@return string[]
---@nodiscard
function Introspect.listCategories()
    ---@type table<string, boolean>
    local seen = {}
    for piece in PieceLibrary.iter() do
        if isNonEmptyString(piece.category) then seen[piece.category] = true end
    end
    ---@type string[]
    local out = {}
    for k, _ in pairs(seen) do out[#out + 1] = k end
    table.sort(out)
    return out
end

---@return string[]
---@nodiscard
function Introspect.listCategoryGroups()
    ---@type table<string, boolean>
    local seen = {}
    for piece in PieceLibrary.iter() do
        if isNonEmptyString(piece.categoryGroup) then seen[piece.categoryGroup] = true end
    end
    ---@type string[]
    local out = {}
    for k, _ in pairs(seen) do out[#out + 1] = k end
    table.sort(out)
    return out
end

return Introspect
