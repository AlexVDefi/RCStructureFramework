require("ISUI/ISCollapsableWindow")
require("ISUI/ISScrollingListBox")
require("ISUI/ISButton")
require("ISUI/ISModalDialog")
local Presets = require("RCStructureFramework/Presets")

---@class RCStructurePresetsWindow : ISCollapsableWindow
RCStructurePresetsWindow = ISCollapsableWindow:derive("RCStructurePresetsWindow")
RCStructurePresetsWindow.instance = nil

local FONT = UIFont.Medium
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PADDING = 10
local BUTTON_HGT = FONT_HGT + 10

---@param structureId string
---@param panel table
---@return RCStructurePresetsWindow
function RCStructurePresetsWindow.openFor(structureId, panel)
    if RCStructurePresetsWindow.instance then
        RCStructurePresetsWindow.instance:close()
    end

    local w, h = 360, 380
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    if panel then
        x = panel:getAbsoluteX() + panel.width + PADDING
        y = panel:getAbsoluteY()
    end

    local win = RCStructurePresetsWindow:new(x, y, w, h, structureId, panel)
    win:initialise()
    win:addToUIManager()
    RCStructurePresetsWindow.instance = win
    return win
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param structureId string
---@param panel table
---@return RCStructurePresetsWindow
function RCStructurePresetsWindow:new(x, y, w, h, structureId, panel)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = getText("IGUI_RCStructureFramework_PresetsTitle")
    o.resizable = false
    o.structureId = structureId
    o.parentPanel = panel
    o.presets = {}
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    return o
end

---@return nil
function RCStructurePresetsWindow:initialise()
    ISCollapsableWindow.initialise(self)

    local listY = self:titleBarHeight() + PADDING
    local listH = self.height - listY - PADDING - BUTTON_HGT - PADDING

    self.list = ISScrollingListBox:new(PADDING, listY, self.width - PADDING * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = FONT_HGT + 6
    self.list.font = FONT
    self.list.drawBorder = true
    self.list.doDrawItem = RCStructurePresetsWindow.drawListItem
    self.list.target = self
    self:addChild(self.list)

    local buttonY = self.height - BUTTON_HGT - PADDING
    local buttonW = math.floor((self.width - PADDING * 4) / 3)

    self.applyButton = ISButton:new(
        PADDING,
        buttonY,
        buttonW,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_PresetApply"),
        self,
        RCStructurePresetsWindow.onApply
    )
    self.applyButton:setFont(FONT)
    self.applyButton:enableAcceptColor()
    self:addChild(self.applyButton)

    self.deleteButton = ISButton:new(
        PADDING * 2 + buttonW,
        buttonY,
        buttonW,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_PresetDelete"),
        self,
        RCStructurePresetsWindow.onDelete
    )
    self.deleteButton:setFont(FONT)
    self:addChild(self.deleteButton)

    self.closeButton = ISButton:new(
        PADDING * 3 + buttonW * 2,
        buttonY,
        buttonW,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_PresetClose"),
        self,
        RCStructurePresetsWindow.onClose
    )
    self.closeButton:setFont(FONT)
    self.closeButton:enableCancelColor()
    self:addChild(self.closeButton)

    self:refreshList()
end

---@param self ISScrollingListBox
---@param y number
---@param item table
---@param alt boolean
---@return number
function RCStructurePresetsWindow.drawListItem(self, y, item, alt)
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    end
    self:drawRectBorder(0, y, self.width, self.itemheight - 1, 0.5, 0.4, 0.4, 0.4)

    self:drawText(item.text, 6, y + 3, 1, 1, 1, 1, self.font)

    return y + self.itemheight
end

---@return nil
function RCStructurePresetsWindow:refreshList()
    self.presets = Presets.load(self.structureId)
    self.list:clear()

    if #self.presets == 0 then
        self.list:addItem(getText("IGUI_RCStructureFramework_PresetsEmpty"), { empty = true })
        self.list.selected = 0
        return
    end

    for i = 1, #self.presets do
        local p = self.presets[i]
        local label = string.format("%s  -  %dx%d", p.name, p.w, p.h)
        self.list:addItem(label, { empty = false, index = i, preset = p })
    end
    self.list.selected = 1
end

---@return table|nil
---@return integer|nil
---@nodiscard
function RCStructurePresetsWindow:getSelectedPreset()
    local selected = self.list.selected
    if not selected or selected < 1 then return nil end
    local item = self.list.items[selected]
    if not item or not item.item or item.item.empty then return nil end
    return item.item.preset, item.item.index
end

---@return nil
function RCStructurePresetsWindow:prerender()
    ISCollapsableWindow.prerender(self)
    local hasSelection = self:getSelectedPreset() ~= nil
    self.applyButton.enable = hasSelection and self.parentPanel ~= nil
    self.deleteButton.enable = hasSelection
end

---@return nil
function RCStructurePresetsWindow:onApply()
    local preset = self:getSelectedPreset()
    if not preset then return end
    if self.parentPanel and self.parentPanel.beginPresetPreview then
        self.parentPanel:beginPresetPreview(preset)
    end
    self:close()
end

---@return nil
function RCStructurePresetsWindow:onDelete()
    local preset, index = self:getSelectedPreset()
    if not preset or not index then return end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local dlgW, dlgH = 320, 150
    local message = getText("IGUI_RCStructureFramework_PresetDeleteConfirm", preset.name)
    local dlg = ISModalDialog:new(
        (sw - dlgW) / 2,
        (sh - dlgH) / 2,
        dlgW,
        dlgH,
        message,
        true,
        self,
        RCStructurePresetsWindow.onDeleteConfirmed
    )
    dlg.pendingIndex = index
    dlg:initialise()
    dlg:addToUIManager()
end

---@param button table
---@return nil
function RCStructurePresetsWindow:onDeleteConfirmed(button)
    if button.internal ~= "YES" then return end
    local index = button.parent and button.parent.pendingIndex
    if not index then return end
    Presets.remove(self.structureId, index)
    self:refreshList()
end

---@return nil
function RCStructurePresetsWindow:onClose()
    self:close()
end

---@return nil
function RCStructurePresetsWindow:close()
    if RCStructurePresetsWindow.instance == self then
        RCStructurePresetsWindow.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

return RCStructurePresetsWindow
