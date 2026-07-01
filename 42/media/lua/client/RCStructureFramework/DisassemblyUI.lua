require("ISUI/ISCollapsableWindow")
require("ISUI/ISScrollingListBox")
require("ISUI/ISButton")
require("RCStructureFramework/TimedActions/DisassembleStructureAction")
require("TimedActions/WalkToTimedAction")

local PlacementValidation = require("RCStructureFramework/PlacementValidation")
local Registry = require("RCStructureFramework/Registry")
local MaterialSource = require("RCStructureFramework/MaterialSource")
local Geometry = require("RCStructureFramework/Geometry")

---@class RCStructureDisassemblyUI
RCStructureDisassemblyUI = RCStructureDisassemblyUI or {}
RCStructureDisassemblyUI.instance = nil

---@class RCStructureDisassemblyWindow : ISCollapsableWindow
RCStructureDisassemblyWindow = ISCollapsableWindow:derive("RCStructureDisassemblyWindow")

local FONT = UIFont.Medium
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PADDING = 10
local BUTTON_HGT = FONT_HGT + 10
local ROW_HGT = FONT_HGT + 6

---@param def table
---@param data table
---@param objects table
---@return table[]  list of { label, count } refund preview rows
---@nodiscard
local function computeRefundPreview(def, data, objects)
    if type(def.getDisassemblyRefundPreview) == "function" then
        local rows = def.getDisassemblyRefundPreview(data, objects)
        if type(rows) == "table" then return rows end
    end

    if type(def.getPieceMaterialRequirement) ~= "function" then
        return {}
    end

    local totals = {}
    local order = {}
    for i = 1, #objects do
        local obj = objects[i]
        if obj and type(obj.getModData) == "function" then
            local tag = obj:getModData() and obj:getModData().RCStructureFramework
            if type(tag) == "table" then
                local req = def.getPieceMaterialRequirement({
                    spriteName = tag.spriteName,
                    slotKind = tag.slotKind,
                    wallType = tag.wallType,
                    roofKind = tag.roofKind,
                    pieceCategory = tag.pieceCategory,
                    _generated = tag._generated,
                })
                if req and type(req.count) == "number" and req.count > 0 then
                    local key = req.fullType or req.tag or req.pieceId or "piece"
                    if not totals[key] then
                        totals[key] = { label = key, count = 0 }
                        order[#order + 1] = key
                    end
                    totals[key].count = totals[key].count + req.count
                end
            end
        end
    end

    local rows = {}
    for i = 1, #order do
        rows[#rows + 1] = totals[order[i]]
    end
    return rows
end

---@param structureId string
---@param object IsoObject
---@param character IsoPlayer
---@return boolean
function RCStructureDisassemblyUI.open(structureId, object, character)
    local valid, reason, data = PlacementValidation.validateDisassembly(structureId, character, object)
    if not valid and reason ~= "distance" then
        return false
    end

    if RCStructureDisassemblyUI.instance then
        RCStructureDisassemblyUI.instance:close()
    end

    local w, h = 380, 380
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    local win = RCStructureDisassemblyWindow:new(x, y, w, h, structureId, object, character, data)
    win:initialise()
    win:addToUIManager()
    RCStructureDisassemblyUI.instance = win
    return true
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param structureId string
---@param targetObject IsoObject
---@param character IsoPlayer
---@param data table
---@return RCStructureDisassemblyWindow
function RCStructureDisassemblyWindow:new(x, y, w, h, structureId, targetObject, character, data)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = getText("IGUI_RCStructureFramework_DisassemblyTitle")
    o.resizable = false
    o.structureId = structureId
    o.targetObject = targetObject
    o.character = character
    o.data = data
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    return o
end

---@return nil
function RCStructureDisassemblyWindow:initialise()
    ISCollapsableWindow.initialise(self)

    local def = Registry.requireStructure(self.structureId)
    self.def = def
    self.objects = (type(def.getRemovableObjects) == "function" and def.getRemovableObjects(self.data)) or {}
    self.refundRows = computeRefundPreview(def, self.data, self.objects)

    local listY = self:titleBarHeight() + PADDING + FONT_HGT + 6
    local listH = self.height - listY - PADDING - BUTTON_HGT - PADDING

    self.list = ISScrollingListBox:new(PADDING, listY, self.width - PADDING * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.font = FONT
    self.list.drawBorder = true
    self.list.doDrawItem = RCStructureDisassemblyWindow.drawListItem
    self:addChild(self.list)

    if #self.refundRows == 0 then
        self.list:addItem(getText("IGUI_RCStructureFramework_DisassemblyNothing"), { empty = true })
    else
        for i = 1, #self.refundRows do
            local row = self.refundRows[i]
            local label = string.format("%s  x  %d", tostring(row.label or "?"), row.count or 0)
            self.list:addItem(label, { empty = false, row = row })
        end
    end

    local buttonY = self.height - BUTTON_HGT - PADDING
    local buttonW = math.floor((self.width - PADDING * 3) / 2)

    self.confirmButton = ISButton:new(
        PADDING, buttonY, buttonW, BUTTON_HGT,
        getText("IGUI_RCStructureFramework_DisassemblyConfirm"),
        self, RCStructureDisassemblyWindow.onConfirm
    )
    self.confirmButton:setFont(FONT)
    self.confirmButton:enableAcceptColor()
    self:addChild(self.confirmButton)

    self.cancelButton = ISButton:new(
        PADDING * 2 + buttonW, buttonY, buttonW, BUTTON_HGT,
        getText("IGUI_RCStructureFramework_DisassemblyCancel"),
        self, RCStructureDisassemblyWindow.onCancel
    )
    self.cancelButton:setFont(FONT)
    self.cancelButton:enableCancelColor()
    self:addChild(self.cancelButton)
end

---@param self ISScrollingListBox
---@param y number
---@param item table
---@param alt boolean
---@return number
function RCStructureDisassemblyWindow.drawListItem(self, y, item, alt)
    if alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, 0.3, 0.18, 0.18, 0.20)
    end
    self:drawRectBorder(0, y, self.width, self.itemheight - 1, 0.5, 0.4, 0.4, 0.4)
    self:drawText(item.text, 6, y + 3, 1, 1, 1, 1, self.font)
    return y + self.itemheight
end

---@return nil
function RCStructureDisassemblyWindow:prerender()
    ISCollapsableWindow.prerender(self)
    local headerY = self:titleBarHeight() + PADDING
    self:drawText(
        getText("IGUI_RCStructureFramework_DisassemblyHeader", tostring(#self.objects)),
        PADDING, headerY, 1, 1, 1, 1, FONT
    )
end

---@return nil
function RCStructureDisassemblyWindow:onConfirm()
    local def = self.def
    local materialSource = nil
    if def.refundViaMaterialSource == true then
        materialSource = MaterialSource.fromDef(self.structureId, self.character, nil, nil)
    end

    local data = self.data
    local footprint = data and data.footprint
    if footprint and self.character then
        local px = math.floor(self.character:getX())
        local py = math.floor(self.character:getY())
        local insideFootprint = Geometry.isInteriorSquare(footprint, px, py)
        local adjacentToFootprint = Geometry.isAdjacentToFootprint(footprint, px, py)
        if insideFootprint then
            local target = Geometry.findNearestOutsideSquare(footprint, self.character)
                or Geometry.findNearestAdjacentFootprintWalkTarget(footprint, self.character)
            if target then
                ISTimedActionQueue.add(ISWalkToTimedAction:new(self.character, target))
            end
        elseif not adjacentToFootprint then
            local target = Geometry.findNearestAdjacentFootprintWalkTarget(footprint, self.character)
            if target then
                ISTimedActionQueue.add(ISWalkToTimedAction:new(self.character, target))
            end
        end
    end

    ISTimedActionQueue.add(RCStructureDisassembleAction:new(
        self.character, self.structureId, self.targetObject, self.data,
        { objects = self.objects, materialSource = materialSource }
    ))
    self:close()
end

---@return nil
function RCStructureDisassemblyWindow:onCancel()
    self:close()
end

---@return nil
function RCStructureDisassemblyWindow:close()
    if RCStructureDisassemblyUI.instance == self then
        RCStructureDisassemblyUI.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

return RCStructureDisassemblyUI
