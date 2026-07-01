---@class RCStructureFrameworkRecipeSource
---some consumed and some kept. See docs/how-to/materials-and-unlocks.md.
local RecipeSource = {}

---@param recipe table
---@return boolean
---@nodiscard
local function recipeIsValid(recipe)
    return type(recipe) == "table" and #recipe > 0
end

---@param item InventoryItem
---@param req table
---@return boolean
---@nodiscard
local function itemMatches(item, req)
    if not item then return false end
    if type(req.fullType) == "string" and req.fullType ~= "" then
        return item.getFullType and item:getFullType() == req.fullType
    end
    if type(req.tag) == "string" and req.tag ~= "" then
        local script = item.getScriptItem and item:getScriptItem() or nil
        if not script or type(script.getTags) ~= "function" then return false end
        local tags = script:getTags()
        if not tags or type(tags.iterator) ~= "function" then return false end
        local it = tags:iterator()
        while it:hasNext() do
            if tostring(it:next()) == req.tag then return true end
        end
        return false
    end
    return false
end

---@param entry any
---@return ItemContainer|nil
---@nodiscard
local function resolveContainer(entry)
    if type(entry) ~= "userdata" and type(entry) ~= "table" then return nil end
    if entry.getItems then return entry end
    if entry.getContainer then
        local c = entry:getContainer()
        if c and c.getItems then return c end
    end
    return nil
end

---@param character IsoPlayer|nil
---@param containers table?
---@param fn fun(item:InventoryItem, source:string, sourceRef:any)
---@return nil
local function iterAvailableItems(character, containers, fn)
    if character and character.getInventory then
        local inv = character:getInventory()
        if inv and inv.getItems then
            local items = inv:getItems()
            for i = 0, items:size() - 1 do
                fn(items:get(i), "inventory", inv)
            end
        end
    end
    if type(containers) ~= "table" then return end
    for ci = 1, #containers do
        local container = resolveContainer(containers[ci])
        if container then
            local items = container:getItems()
            for i = 0, items:size() - 1 do
                fn(items:get(i), "container", container)
            end
        end
    end
end

---@param recipe table
---@param character IsoPlayer|nil
---@param containers table?
---@return table
---@nodiscard
local function collectMatches(recipe, character, containers)
    ---@type table[]
    local matches = {}
    for i = 1, #recipe do matches[i] = {} end
    iterAvailableItems(character, containers,
        ---@param item InventoryItem
        ---@param source string
        ---@param sourceRef any
        function(item, source, sourceRef)
            for i = 1, #recipe do
                if itemMatches(item, recipe[i]) then
                    local list = matches[i]
                    list[#list + 1] = { item = item, source = source, sourceRef = sourceRef }
                end
            end
        end)
    return matches
end

---@param recipe table
---@param character IsoPlayer|nil
---@param containers table?
---@return table  { [reqIdx] = count }
---@nodiscard
function RecipeSource.countAvailable(recipe, character, containers)
    if not recipeIsValid(recipe) then return {} end
    ---@type integer[]
    local counts = {}
    for i = 1, #recipe do counts[i] = 0 end
    iterAvailableItems(character, containers,
        ---@param item InventoryItem
        function(item)
            for i = 1, #recipe do
                if itemMatches(item, recipe[i]) then
                    counts[i] = counts[i] + 1
                end
            end
        end)
    return counts
end

---@param recipe table
---@param character IsoPlayer|nil
---@param containers table?
---@return boolean, table?
---@nodiscard
function RecipeSource.hasAll(recipe, character, containers)
    if not recipeIsValid(recipe) then return true, nil end

    local matches = collectMatches(recipe, character, containers)
    ---@type table<InventoryItem, boolean>
    local consumeClaimed = {}
    ---@type table[]
    local missing = {}

    for i = 1, #recipe do
        local req = recipe[i]
        if not req.keep then
            local needed = req.count or 1
            local taken = 0
            local list = matches[i]
            for j = 1, #list do
                local entry = list[j]
                if not consumeClaimed[entry.item] then
                    consumeClaimed[entry.item] = true
                    taken = taken + 1
                    if taken >= needed then break end
                end
            end
            if taken < needed then
                missing[#missing + 1] = { req = req, available = taken, needed = needed }
            end
        end
    end

    for i = 1, #recipe do
        local req = recipe[i]
        if req.keep then
            local needed = req.count or 1
            local available = 0
            local list = matches[i]
            for j = 1, #list do
                if not consumeClaimed[list[j].item] then
                    available = available + 1
                    if available >= needed then break end
                end
            end
            if available < needed then
                missing[#missing + 1] = { req = req, available = available, needed = needed }
            end
        end
    end

    if #missing > 0 then return false, missing end
    return true, nil
end

---@param recipe table
---@param character IsoPlayer|nil
---@param containers table?
---@return boolean, table
function RecipeSource.consumeAtomic(recipe, character, containers)
    if not recipeIsValid(recipe) then return true, {} end

    local matches = collectMatches(recipe, character, containers)
    ---@type table<InventoryItem, boolean>
    local consumeClaimed = {}
    ---@type table[]
    local toConsume = {}

    for i = 1, #recipe do
        local req = recipe[i]
        if not req.keep then
            local needed = req.count or 1
            local taken = 0
            local list = matches[i]
            for j = 1, #list do
                local entry = list[j]
                if not consumeClaimed[entry.item] then
                    consumeClaimed[entry.item] = true
                    toConsume[#toConsume + 1] = entry
                    taken = taken + 1
                    if taken >= needed then break end
                end
            end
            if taken < needed then
                return false, {}
            end
        end
    end

    for i = 1, #recipe do
        local req = recipe[i]
        if req.keep then
            local needed = req.count or 1
            local available = 0
            local list = matches[i]
            for j = 1, #list do
                if not consumeClaimed[list[j].item] then
                    available = available + 1
                    if available >= needed then break end
                end
            end
            if available < needed then
                return false, {}
            end
        end
    end

    ---@type table[]
    local consumed = {}
    for i = 1, #toConsume do
        local entry = toConsume[i]
        if entry.sourceRef and entry.sourceRef.Remove then
            entry.sourceRef:Remove(entry.item)
        end
        consumed[#consumed + 1] = entry
    end

    return true, consumed
end

return RecipeSource
