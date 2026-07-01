local MaterialContainers = require("RCStructureFramework/MaterialContainers")

---See docs/concepts/material-sources.md for when to use it.
---@class RCStructureFrameworkBagOfContainersSource
local BagOfContainersSource = {}
BagOfContainersSource.__index = BagOfContainersSource

---@param ctx table  { structureId, character, container?, containers?, variant? }
---@return table?
---@nodiscard
function BagOfContainersSource.create(ctx)
    if not ctx or not ctx.structureId or not ctx.character then return nil end

    ---@type InventoryItem[]
    local containers = {}
    if type(ctx.containers) == "table" then
        for i = 1, #ctx.containers do
            if ctx.containers[i] then
                containers[#containers + 1] = ctx.containers[i]
            end
        end
    elseif ctx.container then
        containers[1] = ctx.container
    end

    local self = setmetatable({}, BagOfContainersSource)
    self.structureId = ctx.structureId
    self.character = ctx.character
    self.containers = containers
    self.variant = ctx.variant
    if not self.variant and containers[1] then
        self.variant = MaterialContainers.getVariant(self.structureId, containers[1])
    end
    return self
end

---@param req table?
---@return integer
---@nodiscard
local function reqCount(req)
    local count = req and req.count
    if type(count) ~= "number" or count <= 0 then return 0 end
    return math.floor(count)
end

---@return integer
---@nodiscard
function BagOfContainersSource:_totalAvailable()
    local total = 0
    for i = 1, #self.containers do
        total = total + MaterialContainers.getMaterialCount(self.structureId, self.containers[i])
    end
    return total
end

---@param container InventoryItem
---@return nil
function BagOfContainersSource:_sync(container)
    if isClient() or isServer() then
        syncItemFields(self.character, container)
    end
end

---@param req table?
---@return boolean
---@nodiscard
function BagOfContainersSource:canConsume(req)
    local count = reqCount(req)
    if count == 0 then return true end
    return self:_totalAvailable() >= count
end

---@param req table?
---@return boolean
function BagOfContainersSource:consume(req)
    local count = reqCount(req)
    if count == 0 then return true end
    if self:_totalAvailable() < count then return false end

    local need = count
    for i = 1, #self.containers do
        if need <= 0 then break end
        local container = self.containers[i]
        local available = MaterialContainers.getMaterialCount(self.structureId, container)
        if available > 0 then
            local take = math.min(need, available)
            local variant = MaterialContainers.getVariant(self.structureId, container) or self.variant
            MaterialContainers.setState(self.structureId, container, variant, available - take)
            self:_sync(container)
            need = need - take
        end
    end
    return need <= 0
end

---@param req table?
---@return boolean
function BagOfContainersSource:refund(req)
    local count = reqCount(req)
    if count == 0 then return true end

    if self.containers[1] then
        local container = self.containers[1]
        local available = MaterialContainers.getMaterialCount(self.structureId, container)
        local variant = MaterialContainers.getVariant(self.structureId, container) or self.variant
        MaterialContainers.setState(self.structureId, container, variant, available + count)
        self:_sync(container)
        return true
    end

    if self.variant then
        MaterialContainers.addMaterialsToCharacterContainer(
            self.structureId, self.character, self.variant, count
        )
        return true
    end

    return false
end

---@return table
---@nodiscard
function BagOfContainersSource:availableSummary()
    return {
        kind = "bag",
        variant = self.variant,
        totalAvailable = self:_totalAvailable(),
        containerCount = #self.containers,
    }
end

---@return string
---@nodiscard
function BagOfContainersSource:describe()
    return "bag"
end

return BagOfContainersSource
