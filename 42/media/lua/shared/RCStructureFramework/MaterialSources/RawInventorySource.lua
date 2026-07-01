---@class RCStructureFrameworkRawInventorySource
local RawInventorySource = {}
RawInventorySource.__index = RawInventorySource

---@param ctx table  { character }
---@return table?
---@nodiscard
function RawInventorySource.create(ctx)
    if not ctx or not ctx.character then return nil end
    local self = setmetatable({}, RawInventorySource)
    self.character = ctx.character
    self.inventory = ctx.character:getInventory()
    return self
end

---@param req table?
---@return ArrayList|nil
---@nodiscard
function RawInventorySource:_findMatching(req)
    if not req then return nil end
    if type(req.fullType) == "string" and req.fullType ~= "" then
        return self.inventory:getAllTypeRecurse(req.fullType)
    end
    if type(req.tag) == "string" and req.tag ~= "" then
        local tag = ItemTag.get(ResourceLocation.of(req.tag))
        if not tag then return nil end
        return self.inventory:getAllTagEvalRecurse(tag, buildUtil.predicateMaterial, ArrayList.new())
    end
    return nil
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
---@return boolean
---@nodiscard
function RawInventorySource:canConsume(req)
    local count = reqCount(req)
    if count == 0 then return true end
    if self.character:isBuildCheat() then return true end
    local items = self:_findMatching(req)
    if not items then return false end
    return items:size() >= count
end

---@param req table?
---@return boolean
function RawInventorySource:consume(req)
    local count = reqCount(req)
    if count == 0 then return true end
    if self.character:isBuildCheat() then return true end

    local items = self:_findMatching(req)
    if not items or items:size() < count then return false end

    for i = 0, count - 1 do
        local item = items:get(i)
        self.character:removeFromHands(item)
        local container = item:getContainer() or self.inventory
        if isClient() or isServer() then
            sendRemoveItemFromContainer(container, item)
        end
        container:Remove(item)
    end
    return true
end

---@param req table?
---@return boolean
function RawInventorySource:refund(req)
    local count = reqCount(req)
    if count == 0 then return true end
    local fullType = req and req.fullType
    if type(fullType) ~= "string" or fullType == "" then
        return false
    end

    for _ = 1, count do
        local item = self.inventory:AddItem(fullType)
        if item and (isClient() or isServer()) then
            sendAddItemToContainer(self.inventory, item)
        end
    end
    return true
end

---@return table
---@nodiscard
function RawInventorySource:availableSummary()
    return { kind = "raw" }
end

---@return string
---@nodiscard
function RawInventorySource:describe()
    return "raw"
end

return RawInventorySource
