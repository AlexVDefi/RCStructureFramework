local Registry = require("RCStructureFramework/Registry")
---@class RCStructureFrameworkMaterialContainers
local MaterialContainers = {}

local DEFAULT_COUNT_KEY = "RCStructureFramework_materialCount"
local DEFAULT_VARIANT_KEY = "RCStructureFramework_variant"
local DEFAULT_STRUCTURE_KEY = "RCStructureFramework_structureId"
local DEFAULT_VERSION_KEY = "RCStructureFramework_version"
local DEFAULT_VERSION = 1

-- See docs/how-to/multiplayer.md for the server-authority model.
local COMMAND_MODULE = "RCStructureFramework"
local COMMAND_NAME = "materialContainerOp"

---@param config table
---@param key string
---@return string
---@nodiscard
local function getConfigKey(config, key)
    local value = config[key]
    if type(value) == "string" and value ~= "" then
        return value
    end

    if key == "countKey" then
        return DEFAULT_COUNT_KEY
    end
    if key == "variantKey" then
        return DEFAULT_VARIANT_KEY
    end
    if key == "structureKey" then
        return DEFAULT_STRUCTURE_KEY
    end
    return DEFAULT_VERSION_KEY
end

---@param structureId string
---@return table|nil
---@nodiscard
local function getContainerConfig(structureId)
    local def = Registry.requireStructure(structureId)
    return def.materialContainer
end

---@param config table
---@param field string
---@return ItemTag|nil
---@nodiscard
local function getTag(config, field)
    local tagName = config[field]
    if type(tagName) ~= "string" or tagName == "" then
        return nil
    end

    if config._tagCache == nil then
        config._tagCache = {}
    end
    if config._tagCache[field] == nil then
        config._tagCache[field] = ItemTag.get(ResourceLocation.of(tagName))
    end
    return config._tagCache[field]
end

---@param config table
---@param variant string
---@param tagTableField string
---@return ItemTag|nil
---@nodiscard
local function getVariantTag(config, variant, tagTableField)
    local tagTable = config[tagTableField]
    if type(tagTable) ~= "table" then
        return nil
    end

    local tagName = tagTable[variant]
    if type(tagName) ~= "string" or tagName == "" then
        return nil
    end

    local cacheField = "_" .. tagTableField .. "Cache"
    if config[cacheField] == nil then
        config[cacheField] = {}
    end
    if config[cacheField][variant] == nil then
        config[cacheField][variant] = ItemTag.get(ResourceLocation.of(tagName))
    end
    return config[cacheField][variant]
end

---@param item InventoryItem|nil
---@param tag ItemTag|nil
---@return boolean
---@nodiscard
local function itemHasTag(item, tag)
    return item ~= nil and tag ~= nil and instanceof(item, "InventoryItem") and item:hasTag(tag)
end

---@param structureId string
---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function MaterialContainers.isContainer(structureId, item)
    local config = getContainerConfig(structureId)
    if not config then
        return false
    end
    return itemHasTag(item, getTag(config, "containerTag"))
end

---@param structureId string
---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function MaterialContainers.isLooseMaterial(structureId, item)
    local config = getContainerConfig(structureId)
    if not config then
        return false
    end
    return itemHasTag(item, getTag(config, "materialTag"))
end

---@param structureId string
---@param item InventoryItem
---@return string|nil
---@nodiscard
function MaterialContainers.getContainerVariantFromItem(structureId, item)
    local config = getContainerConfig(structureId)
    if not config then
        return nil
    end

    local def = Registry.requireStructure(structureId)
    if type(def.variantIds) == "table" then
        for i = 1, #def.variantIds do
            local variant = def.variantIds[i]
            if itemHasTag(item, getVariantTag(config, variant, "containerVariantTags")) then
                return variant
            end
        end
    end

    return nil
end

---@param structureId string
---@param item InventoryItem
---@return string|nil
---@nodiscard
function MaterialContainers.getMaterialVariantFromItem(structureId, item)
    local config = getContainerConfig(structureId)
    if not config then
        return nil
    end

    local def = Registry.requireStructure(structureId)
    if type(def.variantIds) == "table" then
        for i = 1, #def.variantIds do
            local variant = def.variantIds[i]
            if itemHasTag(item, getVariantTag(config, variant, "materialVariantTags")) then
                return variant
            end
        end
    end

    return nil
end

---@param structureId string
---@param item InventoryItem
---@return string|nil
---@nodiscard
function MaterialContainers.getVariant(structureId, item)
    local variant = MaterialContainers.getContainerVariantFromItem(structureId, item)
    if variant then
        return variant
    end

    local config = getContainerConfig(structureId)
    if not config then
        return nil
    end

    local modData = item:getModData()
    local value = modData[getConfigKey(config, "variantKey")]
    if type(value) == "string" and value ~= "" then
        return value
    end

    return nil
end

---@param structureId string
---@param item InventoryItem
---@return integer
---@nodiscard
function MaterialContainers.getMaterialCount(structureId, item)
    local config = getContainerConfig(structureId)
    if not config then
        return 0
    end

    local raw = item:getModData()[getConfigKey(config, "countKey")]
    local count
    if type(raw) == "number" then
        count = raw
    elseif raw == nil then
        count = nil
    else
        count = tonumber(tostring(raw))
    end
    if count == nil or count < 0 then
        return 0
    end
    return math.floor(count)
end

---@param config table
---@param materialCount integer
---@return number
---@nodiscard
local function getContainerWeight(config, materialCount)
    if type(config.getWeight) == "function" then
        return config.getWeight(materialCount)
    end

    local referenceCount = config.weightReferenceCount
    local referenceWeight = config.weightReferenceWeight
    if type(referenceCount) == "number" and referenceCount > 0 and type(referenceWeight) == "number" then
        return materialCount * referenceWeight / referenceCount
    end

    return materialCount
end

---@param item InventoryItem
---@param weight number
---@return nil
local function setContainerWeight(item, weight)
    item:setActualWeight(weight)
    item:setWeight(weight)
    item:setCustomWeight(true)
end

---@param structureId string
---@param item InventoryItem
---@param variant string
---@param materialCount integer
---@return nil
function MaterialContainers.setState(structureId, item, variant, materialCount)
    local config = getContainerConfig(structureId)
    if not config then
        return
    end

    local count = math.max(0, math.floor(materialCount))
    local modData = item:getModData()
    modData[getConfigKey(config, "countKey")] = count
    modData[getConfigKey(config, "variantKey")] = variant
    modData[getConfigKey(config, "structureKey")] = structureId
    local version = config.version
    if version == nil then
        version = DEFAULT_VERSION
    end
    modData[getConfigKey(config, "versionKey")] = version
    setContainerWeight(item, getContainerWeight(config, count))
end

---@param character IsoPlayer
---@param item InventoryItem
---@return nil
local function syncChangedInventoryItem(character, item)
    if isClient() then
        syncItemFields(character, item)
    elseif isServer() then
        syncItemFields(character, item)
    else
    end
end

---@param character IsoPlayer
---@param item InventoryItem
---@return boolean
---@nodiscard
function MaterialContainers.characterOwnsInventoryItem(character, item)
    if not item or not item:getContainer() then
        return false
    end
    return character:getInventory():containsRecursive(item)
end

---@param container ItemContainer
---@param itemFullType string
---@return integer
---@nodiscard
local function getItemCount(container, itemFullType)
    local items = container:getAllTypeRecurse(itemFullType)
    return items:size()
end

---@param character IsoPlayer
---@param itemFullType string
---@return integer|nil
---@nodiscard
function MaterialContainers.getCharacterItemCount(character, itemFullType)
    if character:isBuildCheat() then
        return nil
    end
    return getItemCount(character:getInventory(), itemFullType)
end

---@param character IsoPlayer
---@param itemFullType string
---@param count integer
---@return boolean
function MaterialContainers.consumeCharacterItems(character, itemFullType, count)
    if character:isBuildCheat() then
        return true
    end
    if count <= 0 then
        return true
    end

    local inventory = character:getInventory()
    local items = inventory:getSomeTypeEvalRecurse(itemFullType, buildUtil.predicateMaterial, count)
    if items:size() < count then
        return false
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        character:removeFromHands(item)
        local container = item:getContainer()
        if container then
            if isClient() then
                sendRemoveItemFromContainer(container, item)
            elseif isServer() then
                sendRemoveItemFromContainer(container, item)
            else
            end
            container:Remove(item)
        else
            if isClient() then
                sendRemoveItemFromContainer(inventory, item)
            elseif isServer() then
                sendRemoveItemFromContainer(inventory, item)
            else
            end
            inventory:Remove(item)
        end
    end

    return true
end

---@param character IsoPlayer
---@param item InventoryItem
---@return boolean
local function removeInventoryItem(character, item)
    if not item or not item:getContainer() then
        return false
    end

    character:removeFromHands(item)
    local container = item:getContainer()
    if isClient() then
        sendRemoveItemFromContainer(container, item)
    elseif isServer() then
        sendRemoveItemFromContainer(container, item)
    else
    end
    container:Remove(item)
    return true
end

---@param structureId string
---@param character IsoPlayer
---@param variant string
---@return InventoryItem|nil
---@nodiscard
local function findMatchingContainer(structureId, character, variant)
    local config = getContainerConfig(structureId)
    if not config then
        return nil
    end

    local tag = getTag(config, "containerTag")
    if not tag then
        return nil
    end

    local containers = character:getInventory():getAllTagEvalRecurse(
        tag,
        buildUtil.predicateMaterial,
        ArrayList.new()
    )

    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if MaterialContainers.getVariant(structureId, container) == variant then
            return container
        end
    end

    return nil
end

---@param structureId string
---@param character IsoPlayer
---@param variant string
---@param materialCount integer
---@return InventoryItem|nil
local function createContainer(structureId, character, variant, materialCount)
    local config = getContainerConfig(structureId)
    if not config or type(config.containerItemsByVariant) ~= "table" then
        return nil
    end

    local itemFullType = config.containerItemsByVariant[variant]
    if type(itemFullType) ~= "string" or itemFullType == "" then
        return nil
    end

    local item = character:getInventory():AddItem(itemFullType)
    if not item then
        return nil
    end

    MaterialContainers.setState(structureId, item, variant, materialCount)
    if isClient() then
        sendAddItemToContainer(character:getInventory(), item)
        syncItemFields(character, item)
    elseif isServer() then
        sendAddItemToContainer(character:getInventory(), item)
        syncItemFields(character, item)
    else
    end

    return item
end

---@param structureId string
---@param character IsoPlayer
---@param container InventoryItem
---@param materialCount integer
local function addMaterialsToContainer(structureId, character, container, materialCount)
    local variant = MaterialContainers.getVariant(structureId, container)
    MaterialContainers.setState(
        structureId,
        container,
        variant,
        MaterialContainers.getMaterialCount(structureId, container) + materialCount
    )
    syncChangedInventoryItem(character, container)
end

---@param structureId string
---@param character IsoPlayer
---@param variant string
---@param materialCount integer
---@return InventoryItem|nil
function MaterialContainers.addMaterialsToCharacterContainer(structureId, character, variant, materialCount)
    local container = findMatchingContainer(structureId, character, variant)
    if container then
        addMaterialsToContainer(structureId, character, container, materialCount)
        return container
    end

    return createContainer(structureId, character, variant, materialCount)
end

---@param structureId string
---@param character IsoPlayer
---@param variant string
---@param container InventoryItem?
---@return InventoryItem[]
---@nodiscard
function MaterialContainers.collectMatchingLooseMaterials(structureId, character, variant, container)
    local config = getContainerConfig(structureId)
    local looseMaterials = {}
    if not config then
        return looseMaterials
    end

    local tag = getTag(config, "materialTag")
    if not tag then
        return looseMaterials
    end

    local items = character:getInventory():getAllTagEvalRecurse(
        tag,
        buildUtil.predicateMaterial,
        ArrayList.new()
    )

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= container
                and MaterialContainers.isLooseMaterial(structureId, item)
                and not MaterialContainers.isContainer(structureId, item)
                and MaterialContainers.getMaterialVariantFromItem(structureId, item) == variant then
            looseMaterials[#looseMaterials + 1] = item
        end
    end

    return looseMaterials
end

---@param character IsoPlayer
---@param items InventoryItem[]
---@return integer
local function removeLooseMaterials(character, items)
    local converted = 0

    for i = #items, 1, -1 do
        local item = items[i]
        if item:getContainer() and removeInventoryItem(character, item) then
            converted = converted + 1
        end
    end

    return converted
end

---@param structureId string
---@param character IsoPlayer
---@param variant string
---@return integer
---@nodiscard
function MaterialContainers.getMatchingLooseMaterialCount(structureId, character, variant)
    return #MaterialContainers.collectMatchingLooseMaterials(structureId, character, variant, nil)
end

---@param structureId string
---@param character IsoPlayer
---@param variant string
---@return integer
function MaterialContainers.packLooseMaterials(structureId, character, variant)
    if isClient() then
        sendClientCommand(character, COMMAND_MODULE, COMMAND_NAME,
            { structureId = structureId, op = "packLoose", variant = variant })
        return MaterialContainers.getMatchingLooseMaterialCount(structureId, character, variant)
    end
    local items = MaterialContainers.collectMatchingLooseMaterials(structureId, character, variant, nil)
    local converted = removeLooseMaterials(character, items)

    if converted > 0 then
        MaterialContainers.addMaterialsToCharacterContainer(structureId, character, variant, converted)
    end

    return converted
end

---@param structureId string
---@param character IsoPlayer
---@param container InventoryItem
---@param count integer
---@return boolean
function MaterialContainers.takeMaterials(structureId, character, container, count)
    if isClient() then
        sendClientCommand(character, COMMAND_MODULE, COMMAND_NAME, {
            structureId = structureId, op = "take",
            variant = MaterialContainers.getVariant(structureId, container), count = count,
        })
        return true
    end
    if not MaterialContainers.characterOwnsInventoryItem(character, container)
            or not MaterialContainers.isContainer(structureId, container) then
        return false
    end

    local config = getContainerConfig(structureId)
    if not config or type(config.materialItemsByVariant) ~= "table" then
        return false
    end

    local variant = MaterialContainers.getVariant(structureId, container)
    local available = MaterialContainers.getMaterialCount(structureId, container)
    local takeCount = count
    if takeCount > available then
        takeCount = available
    end
    if takeCount <= 0 then
        return false
    end

    local itemFullType = config.materialItemsByVariant[variant]
    if type(itemFullType) ~= "string" or itemFullType == "" then
        return false
    end

    MaterialContainers.setState(structureId, container, variant, available - takeCount)
    for i = 1, takeCount do
        local item = character:getInventory():AddItem(itemFullType)
        if isClient() then
            sendAddItemToContainer(character:getInventory(), item)
        elseif isServer() then
            sendAddItemToContainer(character:getInventory(), item)
        else
        end
    end

    syncChangedInventoryItem(character, container)
    return true
end

---@param structureId string
---@param character IsoPlayer
---@param container InventoryItem
---@return integer
function MaterialContainers.addLooseMaterials(structureId, character, container)
    if isClient() then
        local variant = MaterialContainers.getVariant(structureId, container)
        sendClientCommand(character, COMMAND_MODULE, COMMAND_NAME,
            { structureId = structureId, op = "addLoose", variant = variant })
        return MaterialContainers.getMatchingLooseMaterialCount(structureId, character, variant)
    end
    if not MaterialContainers.characterOwnsInventoryItem(character, container)
            or not MaterialContainers.isContainer(structureId, container) then
        return 0
    end

    local variant = MaterialContainers.getVariant(structureId, container)
    local items = MaterialContainers.collectMatchingLooseMaterials(structureId, character, variant, container)
    local converted = removeLooseMaterials(character, items)

    if converted > 0 then
        MaterialContainers.setState(
            structureId,
            container,
            variant,
            MaterialContainers.getMaterialCount(structureId, container) + converted
        )
        syncChangedInventoryItem(character, container)
    end

    return converted
end

local function runContainerOp(structureId, character, op, variant, count)
    if op == "packLoose" then
        MaterialContainers.packLooseMaterials(structureId, character, variant)
    elseif op == "addLoose" then
        local container = findMatchingContainer(structureId, character, variant)
        if container then
            MaterialContainers.addLooseMaterials(structureId, character, container)
        else
            MaterialContainers.packLooseMaterials(structureId, character, variant)
        end
    elseif op == "take" then
        local container = findMatchingContainer(structureId, character, variant)
        if container and count and count > 0 then
            MaterialContainers.takeMaterials(structureId, character, container, count)
        end
    end
end

local function onMaterialContainerCommand(module, command, player, args)
    if module ~= COMMAND_MODULE or command ~= COMMAND_NAME then return end
    if not player then return end
    args = args or {}
    if type(args.structureId) ~= "string" or type(args.variant) ~= "string" then return end
    runContainerOp(args.structureId, player, args.op, args.variant, tonumber(args.count))
end

local registered = false

---@return nil
function MaterialContainers.registerEvents()
    if registered then return end
    registered = true
    if not isClient() then
        Events.OnClientCommand.Add(onMaterialContainerCommand)
    end
end

---@return nil
function MaterialContainers.unregisterEvents()
    if not registered then return end
    registered = false
    if not isClient() then
        Events.OnClientCommand.Remove(onMaterialContainerCommand)
    end
end

return MaterialContainers
