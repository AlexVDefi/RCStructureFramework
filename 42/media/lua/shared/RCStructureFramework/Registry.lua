local PieceLibrary = require("RCStructureFramework/PieceLibrary")
---@class RCStructureFrameworkRegistry
local Registry = {}

---@type table<string, table>
local structures = {}

---@param value any
---@return boolean
---@nodiscard
local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

---@param def table
---@return table|nil
---@nodiscard
local function normalizeDefinition(def)
    if type(def) ~= "table" or not isNonEmptyString(def.id) then
        return nil
    end

    if def.variantIds == nil and type(def.variants) == "table" then
        ---@type string[]
        local variantIds = {}
        for id, _ in pairs(def.variants) do
            variantIds[#variantIds + 1] = id
        end
        table.sort(variantIds)
        def.variantIds = variantIds
    end

    return def
end

local KNOWN_DEF_KEYS = {
    id = true, roomName = true, variants = true, variantIds = true,
    useGenericBuilder = true, buildFromContainer = true, synthesizeRoofs = true,
    beforeBuild = true, afterBuild = true, getPieceMaterialRequirement = true,
    configureWallObject = true, configureCellObject = true, configureRoofObject = true,
    configureFurnitureObject = true, configureApplianceObject = true,
    configureDecorativeObject = true, configureVegetationObject = true,
    buildCompletion = true, getRemovableObjects = true, beforeDisassemble = true,
    afterDisassemble = true, refundViaMaterialSource = true, getDisassemblyRefundPreview = true,
    materialSource = true, createMaterialSource = true, materialContainer = true,
    getMinimumContainerMaterialCount = true, validation = true,
    validateContainerPlacement = true, validateCompletion = true, validateDisassembly = true,
    isSelectionValid = true, getPieceSpriteName = true, getCellSpriteName = true,
    getPlacementSummary = true, getFootprintFromPlan = true, getGableAxis = true,
    getRoofPieceCount = true, getRoofPreview = true, buildRecipeCallbacks = true,
    editor = true, presetsFile = true, useCatalogUI = true, selectTitleKey = true,
    editTitleKey = true, placeLabelKey = true, invalidSizeTooltipKey = true,
    incompletePerimeterTooltipKey = true, invalidPlacementTooltipKey = true,
    materialTooltipKey = true, allowMultiStorey = true, singleStorey = true,
    disableZControl = true, requireSingleRect = true,
}

local KNOWN_MATERIAL_SOURCES = { raw = true, universal = true, bag = true }

local KNOWN_VALIDATORS = {
    noEmptyPlan = true, noOverlap = true, slotKindCompatible = true,
    roofNeedsWallUnder = true, floorNeedsCell = true, zAboveEmpty = true,
    minimumRoomRectSize = true, stairLinks = true, obstructionFree = true,
    footprintFitsInRect = true, multiRectEdgeConnectivity = true,
}

---@param a string
---@param b string
---@return boolean
---@nodiscard
local function isWithinEdit1(a, b)
    if a == b then return true end
    local la, lb = #a, #b
    if la > lb + 1 or lb > la + 1 then return false end
    if la == lb then
        local diffs = 0
        for i = 1, la do
            if string.sub(a, i, i) ~= string.sub(b, i, i) then
                diffs = diffs + 1
                if diffs > 1 then return false end
            end
        end
        return true
    end
    local short, long = a, b
    if la > lb then short, long = b, a end
    local i, j = 1, 1
    local skipped = false
    while i <= #short and j <= #long do
        if string.sub(short, i, i) == string.sub(long, j, j) then
            i = i + 1
            j = j + 1
        else
            if skipped then return false end
            skipped = true
            j = j + 1
        end
    end
    return true
end

---@param key string
---@return string|nil
---@nodiscard
local function suggestKey(key)
    for known, _ in pairs(KNOWN_DEF_KEYS) do
        if isWithinEdit1(key, known) then return known end
    end
    return nil
end

---@return boolean
---@nodiscard
local function validationEnabled()
    local cfg = RCSF_Config
    if type(cfg) == "table" and cfg.validateDefs == false then return false end
    return true
end

---@param msg string
---@return nil
local function logValidation(msg)
    local cfg = RCSF_Config
    if type(cfg) == "table" and cfg.verboseValidation then
        print(msg)
    end
end

---@param def table
---@return nil
local function validateDefinition(def)
    local id = tostring(def.id)
    for k, _ in pairs(def) do
        if type(k) == "string" and not KNOWN_DEF_KEYS[k] then
            local hint = suggestKey(k)
            if hint then
                logValidation("[RCSF] structure '" .. id .. "': unknown def key '" .. k .. "' (did you mean '" .. hint .. "'?)")
            else
                logValidation("[RCSF] structure '" .. id .. "': unknown def key '" .. k .. "'")
            end
        end
    end

    if def.materialSource ~= nil then
        if type(def.materialSource) ~= "string" or not KNOWN_MATERIAL_SOURCES[def.materialSource] then
            logValidation("[RCSF] structure '" .. id .. "': materialSource '" .. tostring(def.materialSource) .. "' is not one of raw/universal/bag")
        end
        if type(def.createMaterialSource) == "function" then
            logValidation("[RCSF] structure '" .. id .. "': both materialSource and createMaterialSource set; createMaterialSource wins")
        end
    end

    if type(def.validation) == "table" and type(def.validation.useDefaults) == "table" then
        local list = def.validation.useDefaults
        for i = 1, #list do
            local name = list[i]
            if type(name) == "string" and not KNOWN_VALIDATORS[name] then
                logValidation("[RCSF] structure '" .. id .. "': unknown default validator '" .. name .. "'")
            end
        end
    end
end

---@param def table
---@return boolean
function Registry.registerStructure(def)
    local clean = normalizeDefinition(def)
    if not clean then
        logValidation("[RCSF] registerStructure: missing or invalid required field 'id' (non-empty string); definition rejected")
        return false
    end

    if validationEnabled() then
        validateDefinition(clean)
    end

    structures[clean.id] = clean
    return true
end

---@param structureId string
---@param entries table
---@return integer registered
function Registry.registerPieces(structureId, entries)
    if not isNonEmptyString(structureId) or type(entries) ~= "table" then
        return 0
    end

    local count = 0
    for i = 1, #entries do
        local piece = entries[i]
        if type(piece) == "table" then
            piece.structureId = piece.structureId or structureId
            if not isNonEmptyString(piece.id)
                and isNonEmptyString(piece.spriteName) then
                piece.id = piece.structureId .. ":" .. piece.spriteName
            end
            if PieceLibrary.register(piece) then
                count = count + 1
            end
        end
    end
    return count
end

---See docs/how-to/register-structures.md.
---@param def table  RCSFStructureDef, optionally with an inline `pieces` array
---@return table|nil
function Registry.defineStructure(def)
    if type(def) ~= "table" then
        logValidation("[RCSF] defineStructure: expected a table")
        return nil
    end

    local pieces = nil
    if type(def.pieces) == "table" then
        pieces = def.pieces
        def.pieces = nil
    end

    if def.variants == nil and def.variantIds == nil then
        def.variants = { default = true }
    end

    if not Registry.registerStructure(def) then
        return nil
    end

    if pieces then
        Registry.registerPieces(def.id, pieces)
    end

    return structures[def.id]
end

---@param structureId string
---@param variant string|nil
---@param pieceType string
---@param north boolean
---@return string|nil
---@nodiscard
function Registry.getPieceSpriteName(structureId, variant, pieceType, north)
    local fromLib = PieceLibrary.findSpriteName(structureId, variant, pieceType, north)
    if fromLib then
        return fromLib
    end

    local def = structures[structureId]
    if def and type(def.getPieceSpriteName) == "function" then
        return def.getPieceSpriteName(variant, pieceType, north)
    end
    return nil
end

---@param structureId string
---@return table|nil
---@nodiscard
function Registry.getStructure(structureId)
    return structures[structureId]
end

---@param structureId string
---@return table
---@nodiscard
function Registry.requireStructure(structureId)
    local def = structures[structureId]
    if not def then
        error("Unknown RC structure definition: " .. tostring(structureId))
    end
    return def
end

---@param roomName string
---@param baseName string
---@return boolean
---@nodiscard
local function roomNameMatchesBase(roomName, baseName)
    if roomName == baseName then
        return true
    end
    local prefix = baseName .. "_"
    return string.sub(roomName, 1, #prefix) == prefix
end

---@param roomName string
---@return table|nil
---@nodiscard
function Registry.getStructureByRoomName(roomName)
    if type(roomName) ~= "string" or roomName == "" then
        return nil
    end

    for _, def in pairs(structures) do
        if type(def.roomName) == "string" and def.roomName ~= ""
            and roomNameMatchesBase(roomName, def.roomName) then
            return def
        end
    end

    return nil
end

---@return table
---@nodiscard
function Registry.getAllStructures()
    return structures
end

return Registry
