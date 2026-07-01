require("ISUI/ISToolTipInv")
local Registry = require("RCStructureFramework/Registry")
local MaterialContainers = require("RCStructureFramework/MaterialContainers")

RCStructureMaterialTooltip = RCStructureMaterialTooltip or {}

local TOOLTIP_APPEND_BOTTOM = 5
local TOOLTIP_LABEL_R = 1
local TOOLTIP_LABEL_G = 1
local TOOLTIP_LABEL_B = 0.8
local TOOLTIP_LABEL_A = 1

---@param value unknown
---@return number|nil
---@nodiscard
local function numberFromValue(value)
    local valueType = type(value)
    if valueType == "number" then
        return value
    end
    if value == nil then
        return nil
    end
    return tonumber(tostring(value))
end

---@param item InventoryItem
---@return string|nil
---@nodiscard
local function getItemStructureId(item)
    local structures = Registry.getAllStructures()
    for structureId, def in pairs(structures) do
        if def.materialContainer and MaterialContainers.isContainer(structureId, item) then
            return structureId
        end
    end
    return nil
end

---@param panel ISToolTipInv
---@param tooltip ObjectTooltip
---@param item InventoryItem
---@return nil
local function appendMaterialContainerLayout(panel, tooltip, item)
    if not item or not instanceof(item, "InventoryItem") then
        return
    end

    local structureId = getItemStructureId(item)
    if not structureId then
        return
    end

    local def = Registry.requireStructure(structureId)
    local labelKey = "Tooltip_RCStructureFramework_Materials"
    if type(def.materialTooltipKey) == "string" and def.materialTooltipKey ~= "" then
        labelKey = def.materialTooltipKey
    end

    local layout = tooltip:beginLayout()
    local row = layout:addItem()
    row:setLabel(
        getText(labelKey, tostring(MaterialContainers.getMaterialCount(structureId, item))),
        TOOLTIP_LABEL_R,
        TOOLTIP_LABEL_G,
        TOOLTIP_LABEL_B,
        TOOLTIP_LABEL_A
    )

    local currentHeight = numberFromValue(tooltip:getHeight())
    local font = tooltip:getFont()
    local lineSpacing = numberFromValue(getTextManager():getFontHeight(font))
    local left = numberFromValue(getTextManager():MeasureStringX(font, "0"))
    if currentHeight == nil or lineSpacing == nil or left == nil then
        tooltip:endLayout(layout)
        return
    end

    tooltip:setMeasureOnly(true)
    layout:render(left, currentHeight, tooltip)
    tooltip:setMeasureOnly(false)

    local newHeight = currentHeight + lineSpacing + TOOLTIP_APPEND_BOTTOM
    local newWidth = numberFromValue(tooltip:getWidth())
    if newWidth then
        tooltip:setWidth(newWidth)
        panel:setWidth(newWidth)
    end
    panel:setHeight(newHeight)

    panel:drawRect(
        0,
        currentHeight,
        panel:getWidth(),
        newHeight - currentHeight,
        panel.backgroundColor.a,
        panel.backgroundColor.r,
        panel.backgroundColor.g,
        panel.backgroundColor.b
    )
    layout:render(left, currentHeight, tooltip)
    tooltip:setHeight(newHeight)
    panel:drawRectBorder(
        0,
        0,
        panel:getWidth(),
        newHeight,
        panel.borderColor.a,
        panel.borderColor.r,
        panel.borderColor.g,
        panel.borderColor.b
    )
    tooltip:endLayout(layout)
end

---@param self ISToolTipInv
---@return nil
function RCStructureMaterialTooltip.renderWithStructureTooltip(self)
    ISToolTipInv.RCStructureFramework_OriginalRender(self)

    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then
        return
    end
    if not self.tooltip then
        return
    end

    appendMaterialContainerLayout(self, self.tooltip, self.item)
end

---@return nil
function RCStructureMaterialTooltip.install()
    if ISToolTipInv.RCStructureFramework_OriginalRender then
        return
    end

    ISToolTipInv.RCStructureFramework_OriginalRender = ISToolTipInv.render
    ISToolTipInv.render = RCStructureMaterialTooltip.renderWithStructureTooltip
end

RCStructureMaterialTooltip.install()
Events.OnGameStart.Add(RCStructureMaterialTooltip.install)

return RCStructureMaterialTooltip
