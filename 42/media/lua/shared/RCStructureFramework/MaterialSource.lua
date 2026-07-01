local Registry = require("RCStructureFramework/Registry")

---@class RCStructureFrameworkMaterialSourceFactoryCtx
---@field structureId string
---@field character IsoPlayer
---@field container InventoryItem?
---@field containers InventoryItem[]?
---@field plan table?
---@field variant string?

---@class RCStructureFrameworkMaterialSourceInstance
---@field canConsume fun(self, req: table): boolean
---@field consume fun(self, req: table): boolean
---@field refund fun(self, req: table): boolean
---@field availableSummary fun(self): table
---@field describe fun(self): string

---@class RCStructureFrameworkMaterialSource
local MaterialSource = {}

---@type table<string, fun(ctx: table): table?>
local factories = {}

---@param kind string
---@param factory fun(ctx: table): table?
---@return nil
function MaterialSource.register(kind, factory)
    if type(kind) ~= "string" or kind == "" or type(factory) ~= "function" then
        return
    end
    factories[kind] = factory
end

---@param kind string
---@param ctx table
---@return table?
---@nodiscard
function MaterialSource.create(kind, ctx)
    local factory = factories[kind]
    if not factory then
        return nil
    end
    return factory(ctx or {})
end

---See docs/concepts/material-sources.md for the model.
---@param structureId string
---@param character IsoPlayer
---@param container InventoryItem?
---@param plan table?
---@return table?
---@nodiscard
function MaterialSource.fromDef(structureId, character, container, plan)
    local def = Registry.requireStructure(structureId)
    if not def then return nil end

    if type(def.createMaterialSource) == "function" then
        return def.createMaterialSource(character, container, plan)
    end

    local kind = def.materialSource
    if type(kind) ~= "string" or kind == "" then
        return nil
    end

    return MaterialSource.create(kind, {
        structureId = structureId,
        character = character,
        container = container,
        plan = plan,
    })
end

local RawInventorySource = require("RCStructureFramework/MaterialSources/RawInventorySource")
local UniversalContainerSource = require("RCStructureFramework/MaterialSources/UniversalContainerSource")
local BagOfContainersSource = require("RCStructureFramework/MaterialSources/BagOfContainersSource")

MaterialSource.register("raw", function(ctx) return RawInventorySource.create(ctx) end)
MaterialSource.register("universal", function(ctx) return UniversalContainerSource.create(ctx) end)
MaterialSource.register("bag", function(ctx) return BagOfContainersSource.create(ctx) end)

MaterialSource.RawInventorySource = RawInventorySource
MaterialSource.UniversalContainerSource = UniversalContainerSource
MaterialSource.BagOfContainersSource = BagOfContainersSource

return MaterialSource
