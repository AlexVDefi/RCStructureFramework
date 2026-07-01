---@class RCStructureFrameworkPieceLibrary
local PieceLibrary = {}

---@class RCStructureFrameworkPiece
---@field id string                   -- unique within the registry; recommended: structureId .. ":" .. spriteName
---@field spriteName string           -- closed-state sprite (also used for walls without an open state)
---@field category string             -- "wall", "floor", "roof", ... (extensible)
---@field subcategory string?         -- e.g. "regular" / "door" / "window" for category="wall"
---@field structureId string?         -- if scoped to a specific structure def
---@field variant string?             -- structure variant id (e.g. "green")
---@field label string?               -- raw text (used only when no labelKey)
---@field labelKey string?            -- IGUI_ key for getText
---@field tags table?                 -- string[]; arbitrary tags for filtering
---@field footprint table?            -- e.g. { w=1, h=1 } for cells; per-piece engine footprint
---@field openSpriteName string?      -- door/window open state; when nil the engine resolves via OPEN_TILE_OFFSET
---@field northVariant string?        -- companion sprite for north-facing walls (mirrors Constants.WALL_SPRITES_BY_COLOR.color.kind.north)
---@field westVariant string?         -- companion sprite for west-facing walls
---@field pieceType string?           -- legacy hook for def.getPieceSpriteName(variant, pieceType, north)
---@field materialRequirement table?  -- { tag?, fullType?, count } consumed by MaterialSource (M4)
---@field categoryGroup string?       -- v3 catalog UI bucket: "floor","wall","roof","door","window","stair","wallpaper","furniture","appliance"
---@field unlockSources table?        -- { skill={PerkKey=level,...}, magazines={fullType,...}, research={itemFullType?|spriteName?|entityScriptId?} }; nil = default-unlocked
---@field materialRecipe table?       -- [{fullType, count, keep?, tag?}, ...] heterogeneous vanilla-style recipe consumed via RecipeSource
---@field thumbnailIcon string?       -- optional override for sidebar tile icon

---@type table<string, table>
local pieces = {}
---@type table<string, table[]>
local byCategory = {}
---@type table<string, table[]>
local byCategoryGroup = {}
---@type table<string, table<string, table[]>>
local byCategoryAndTag = {}
---@type table<string, table<string, table<string, table>>>
local byStructureLookup = {}
---@type table<string, fun(player:IsoPlayer):table?>
local recipeKnowledgeProviders = {}

---@param value any
---@return boolean
---@nodiscard
local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

---@param category string
---@return table
local function getCategoryBucket(category)
    local bucket = byCategory[category]
    if not bucket then
        bucket = {}
        byCategory[category] = bucket
    end
    return bucket
end

---@param group string
---@return table
local function getCategoryGroupBucket(group)
    local bucket = byCategoryGroup[group]
    if not bucket then
        bucket = {}
        byCategoryGroup[group] = bucket
    end
    return bucket
end

---@param category string
---@param tag string
---@return table
local function getTagBucket(category, tag)
    local catTags = byCategoryAndTag[category]
    if not catTags then
        catTags = {}
        byCategoryAndTag[category] = catTags
    end
    local bucket = catTags[tag]
    if not bucket then
        bucket = {}
        catTags[tag] = bucket
    end
    return bucket
end

---@param piece table
---@return nil
local function indexStructureLookup(piece)
    if not isNonEmptyString(piece.structureId) or not isNonEmptyString(piece.pieceType) then
        return
    end
    local variantId = piece.variant or "_"
    local sid = piece.structureId
    if not byStructureLookup[sid] then byStructureLookup[sid] = {} end
    if not byStructureLookup[sid][variantId] then byStructureLookup[sid][variantId] = {} end
    if not byStructureLookup[sid][variantId][piece.pieceType] then
        byStructureLookup[sid][variantId][piece.pieceType] = {}
    end
    local slot = byStructureLookup[sid][variantId][piece.pieceType]

    if isNonEmptyString(piece.northVariant) then
        slot.north = piece.northVariant
    end
    if isNonEmptyString(piece.westVariant) then
        slot.west = piece.westVariant
    elseif slot.west == nil then
        slot.west = piece.spriteName
    end
end

---@param piece table
---@return boolean
function PieceLibrary.register(piece)
    if type(piece) ~= "table" then return false end
    if not isNonEmptyString(piece.id) then return false end
    if not isNonEmptyString(piece.spriteName) then return false end
    if not isNonEmptyString(piece.category) then return false end

    local existing = pieces[piece.id]
    if existing then
        PieceLibrary.unregister(piece.id)
    end

    pieces[piece.id] = piece
    table.insert(getCategoryBucket(piece.category), piece)

    if isNonEmptyString(piece.categoryGroup) then
        table.insert(getCategoryGroupBucket(piece.categoryGroup), piece)
    end

    if type(piece.tags) == "table" then
        for i = 1, #piece.tags do
            local tag = piece.tags[i]
            if isNonEmptyString(tag) then
                table.insert(getTagBucket(piece.category, tag), piece)
            end
        end
    end

    indexStructureLookup(piece)
    return true
end

---@param id string
---@return nil
function PieceLibrary.unregister(id)
    local piece = pieces[id]
    if not piece then return end

    pieces[id] = nil

    local bucket = byCategory[piece.category]
    if bucket then
        for i = #bucket, 1, -1 do
            if bucket[i] == piece then
                table.remove(bucket, i)
            end
        end
    end

    if isNonEmptyString(piece.categoryGroup) then
        local groupBucket = byCategoryGroup[piece.categoryGroup]
        if groupBucket then
            for i = #groupBucket, 1, -1 do
                if groupBucket[i] == piece then
                    table.remove(groupBucket, i)
                end
            end
        end
    end

    local catTags = byCategoryAndTag[piece.category]
    if catTags and type(piece.tags) == "table" then
        for ti = 1, #piece.tags do
            local tagBucket = catTags[piece.tags[ti]]
            if tagBucket then
                for j = #tagBucket, 1, -1 do
                    if tagBucket[j] == piece then
                        table.remove(tagBucket, j)
                    end
                end
            end
        end
    end

    if isNonEmptyString(piece.structureId) and isNonEmptyString(piece.pieceType) then
        local variantId = piece.variant or "_"
        local sid = byStructureLookup[piece.structureId]
        local v = sid and sid[variantId]
        local slot = v and v[piece.pieceType]
        if slot then
            if slot.north == piece.northVariant then slot.north = nil end
            if slot.west == piece.westVariant or slot.west == piece.spriteName then slot.west = nil end
        end
    end
end

---@param id string
---@return table|nil
---@nodiscard
function PieceLibrary.get(id)
    return pieces[id]
end

---@param category string
---@return table
---@nodiscard
function PieceLibrary.getByCategory(category)
    local bucket = byCategory[category]
    if not bucket then return {} end
    local copy = {}
    for i = 1, #bucket do copy[i] = bucket[i] end
    return copy
end

---@param category string
---@param tag string
---@return table
---@nodiscard
function PieceLibrary.getByCategoryAndTag(category, tag)
    local catTags = byCategoryAndTag[category]
    if not catTags then return {} end
    local bucket = catTags[tag]
    if not bucket then return {} end
    local copy = {}
    for i = 1, #bucket do copy[i] = bucket[i] end
    return copy
end

---@param predicate function|table
---@return table|nil
---@nodiscard
function PieceLibrary.find(predicate)
    if type(predicate) == "function" then
        for _, piece in pairs(pieces) do
            if predicate(piece) then return piece end
        end
        return nil
    end

    if type(predicate) ~= "table" then return nil end

    if isNonEmptyString(predicate.structureId)
        and isNonEmptyString(predicate.pieceType) then
        local variantId = predicate.variant or "_"
        local sid = byStructureLookup[predicate.structureId]
        local v = sid and sid[variantId]
        local slot = v and v[predicate.pieceType]
        if slot then
            if predicate.north == true then return slot.north and pieces[slot.north] or nil end
            if predicate.north == false then return slot.west and pieces[slot.west] or nil end
            local first = slot.west or slot.north
            return first and pieces[first] or nil
        end
    end

    for _, piece in pairs(pieces) do
        local match = true
        for k, v in pairs(predicate) do
            if piece[k] ~= v then
                match = false
                break
            end
        end
        if match then return piece end
    end
    return nil
end

---@param structureId string
---@param variant string|nil
---@param pieceType string
---@param north boolean
---@return string|nil
---@nodiscard
function PieceLibrary.findSpriteName(structureId, variant, pieceType, north)
    local variantId = variant or "_"
    local sid = byStructureLookup[structureId]
    local v = sid and sid[variantId]
    local slot = v and v[pieceType]
    if not slot then return nil end
    if north then return slot.north end
    return slot.west
end

---@param structureId string
---@return nil
function PieceLibrary.unregisterStructure(structureId)
    if not isNonEmptyString(structureId) then return end
    ---@type string[]
    local ids = {}
    for id, piece in pairs(pieces) do
        if piece.structureId == structureId then ids[#ids + 1] = id end
    end
    for i = 1, #ids do PieceLibrary.unregister(ids[i]) end
end

---@return table
---@nodiscard
function PieceLibrary.all()
    local copy = {}
    for id, piece in pairs(pieces) do copy[id] = piece end
    return copy
end

---@return nil
function PieceLibrary.rebuildBuckets()
    for k in pairs(byCategory) do byCategory[k] = nil end
    for k in pairs(byCategoryGroup) do byCategoryGroup[k] = nil end
    for k in pairs(byCategoryAndTag) do byCategoryAndTag[k] = nil end
    for k in pairs(byStructureLookup) do byStructureLookup[k] = nil end

    for _, piece in pairs(pieces) do
        if isNonEmptyString(piece.category) then
            table.insert(getCategoryBucket(piece.category), piece)
        end
        if isNonEmptyString(piece.categoryGroup) then
            table.insert(getCategoryGroupBucket(piece.categoryGroup), piece)
        end
        if type(piece.tags) == "table" and isNonEmptyString(piece.category) then
            for i = 1, #piece.tags do
                local tag = piece.tags[i]
                if isNonEmptyString(tag) then
                    table.insert(getTagBucket(piece.category, tag), piece)
                end
            end
        end
        indexStructureLookup(piece)
    end
end

---@param group string
---@return table
---@nodiscard
function PieceLibrary.getByCategoryGroup(group)
    local bucket = byCategoryGroup[group]
    if not bucket then return {} end
    local copy = {}
    for i = 1, #bucket do copy[i] = bucket[i] end
    return copy
end

---@return fun(): table|nil
---@nodiscard
function PieceLibrary.iter()
    ---@type string[]
    local ids = {}
    for id, _ in pairs(pieces) do ids[#ids + 1] = id end
    local i = 0
    ---@return table|nil
    return function()
        i = i + 1
        if i > #ids then return nil end
        return pieces[ids[i]]
    end
end

---@param name string
---@param fn fun(player:IsoPlayer):table?
---@return boolean
function PieceLibrary.addRecipeKnowledgeProvider(name, fn)
    if not isNonEmptyString(name) or type(fn) ~= "function" then return false end
    recipeKnowledgeProviders[name] = fn
    return true
end

---@param name string
---@return nil
function PieceLibrary.removeRecipeKnowledgeProvider(name)
    recipeKnowledgeProviders[name] = nil
end

---@deprecated Use `addRecipeKnowledgeProvider(name, fn)`. Single-slot shim kept
---@param fn fun(player:IsoPlayer):table?|nil
---@return nil
function PieceLibrary.setKnownRecipesProvider(fn)
    if type(fn) == "function" then
        recipeKnowledgeProviders["_legacy"] = fn
    else
        recipeKnowledgeProviders["_legacy"] = nil
    end
end

---@param research table
---@return string|nil
---@nodiscard
local function makeResearchKey(research)
    if type(research) ~= "table" then return nil end
    if type(research.itemFullType)   == "string" and research.itemFullType   ~= "" then return "item:"   .. research.itemFullType end
    if type(research.spriteName)     == "string" and research.spriteName     ~= "" then return "sprite:" .. research.spriteName end
    if type(research.entityScriptId) == "string" and research.entityScriptId ~= "" then return "entity:" .. research.entityScriptId end
    return nil
end

---@param research table
---@return string|nil
---@nodiscard
function PieceLibrary.makeResearchKey(research)
    return makeResearchKey(research)
end

---@param skillTable table  -- { PerkConstName = requiredLevel, ... }
---@param player IsoPlayer
---@return boolean
---@nodiscard
local function checkSkillUnlock(skillTable, player)
    if type(skillTable) ~= "table" then return false end
    if not player or type(player.getPerkLevel) ~= "function" then return false end
    if type(Perks) ~= "table" then return false end
    for perkKey, requiredLevel in pairs(skillTable) do
        if type(requiredLevel) == "number" then
            local perk = Perks[perkKey]
            if perk and player:getPerkLevel(perk) >= requiredLevel then
                return true
            end
        end
    end
    return false
end

---@param player IsoPlayer
---@return table?
---@nodiscard
local function gatherKnownRecipes(player)
    local merged = nil
    for _, fn in pairs(recipeKnowledgeProviders) do
        local set = fn(player)
        if type(set) == "table" then
            if merged == nil then merged = {} end
            for k, v in pairs(set) do
                if v then merged[k] = true end
            end
        end
    end
    return merged
end

---@param piece table
---@param player IsoPlayer
---@return boolean
---@nodiscard
function PieceLibrary.isUnlockedFor(piece, player)
    if type(piece) ~= "table" then return false end
    local sources = piece.unlockSources
    if sources == nil then return true end
    if type(sources) ~= "table" then return false end

    if type(sources.skill) == "table" then
        if checkSkillUnlock(sources.skill, player) then return true end
    end

    local known = nil
    if type(sources.magazines) == "table" or type(sources.research) == "table" then
        known = gatherKnownRecipes(player)
    end

    if type(sources.magazines) == "table" and type(known) == "table" then
        for i = 1, #sources.magazines do
            local fullType = sources.magazines[i]
            if type(fullType) == "string" and known[fullType] then return true end
        end
    end

    if type(sources.research) == "table" and type(known) == "table" then
        local key = makeResearchKey(sources.research)
        if key and known[key] then return true end
    end

    return false
end

return PieceLibrary
