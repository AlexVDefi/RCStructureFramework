require("ISUI/ISCollapsableWindow")
require("ISUI/ISScrollingListBox")
require("ISUI/ISButton")

local PieceLibrary = require("RCStructureFramework/PieceLibrary")

---@class RCStructurePieceCatalogPanel : ISCollapsableWindow
RCStructurePieceCatalogPanel = ISCollapsableWindow:derive("RCStructurePieceCatalogPanel")
RCStructurePieceCatalogPanel.instance = nil

---@class RCStructurePieceCatalogList : ISScrollingListBox
RCStructurePieceCatalogList = ISScrollingListBox:derive("RCStructurePieceCatalogList")

local FONT = UIFont.Medium
local FONT_HGT = getTextManager():getFontHeight(FONT)
local PADDING = 10
local BUTTON_HGT = FONT_HGT + 10
local THUMB_SIZE = 48
local ITEM_HEIGHT = THUMB_SIZE + PADDING

---@type table<string, IsoSprite>
local SPRITE_CACHE = {}

---@param spriteName string
---@return IsoSprite|nil
---@nodiscard
local function getCachedSprite(spriteName)
    if type(spriteName) ~= "string" or spriteName == "" then return nil end
    local cached = SPRITE_CACHE[spriteName]
    if not cached then
        cached = IsoSprite.new()
        cached:LoadSingleTexture(spriteName)
        SPRITE_CACHE[spriteName] = cached
    end
    return cached
end

---@param piece table
---@return string
---@nodiscard
local function getPieceLabel(piece)
    if type(piece.label) == "string" and piece.label ~= "" then
        return piece.label
    end
    if type(piece.labelKey) == "string" and piece.labelKey ~= "" then
        return getText(piece.labelKey)
    end
    if type(piece.id) == "string" and piece.id ~= "" then
        return piece.id
    end
    return piece.spriteName or "?"
end

---@param self RCStructurePieceCatalogList
---@param y number
---@param item table
---@param alt boolean
---@return number
function RCStructurePieceCatalogList:doDrawItem(y, item, alt)
    local data = item.item
    local piece = data and data.piece

    if self.selected == item.index then
        self:drawRect(0, y, self.width, ITEM_HEIGHT - 1, 0.5, 0.7, 0.45, 0.15)
    elseif alt then
        self:drawRect(0, y, self.width, ITEM_HEIGHT - 1, 0.3, 0.18, 0.18, 0.20)
    end
    self:drawRectBorder(0, y, self.width, ITEM_HEIGHT - 1, 0.5, 0.4, 0.4, 0.4)

    local boxX = 6
    local boxY = y + math.floor((ITEM_HEIGHT - THUMB_SIZE) / 2)
    self:drawRect(boxX, boxY, THUMB_SIZE, THUMB_SIZE, 1, 0.08, 0.08, 0.10)

    if piece and piece.spriteName then
        local sprite = getCachedSprite(piece.spriteName)
        local texture = sprite and sprite:getTextureForCurrentFrame(IsoDirections.N)
        if texture then
            local tw = texture:getWidth()
            local th = texture:getHeight()
            if tw > 0 and th > 0 then
                local scale = math.min((THUMB_SIZE - 4) / tw, (THUMB_SIZE - 4) / th)
                local dw = math.max(1, math.floor(tw * scale))
                local dh = math.max(1, math.floor(th * scale))
                self:drawTextureScaled(
                    texture,
                    boxX + math.floor((THUMB_SIZE - dw) / 2),
                    boxY + math.floor((THUMB_SIZE - dh) / 2),
                    dw, dh, 1, 1, 1, 1
                )
            end
        end
    end
    self:drawRectBorder(boxX, boxY, THUMB_SIZE, THUMB_SIZE, 1, 0.4, 0.4, 0.45)

    local label = piece and getPieceLabel(piece) or "?"
    self:drawText(label, boxX + THUMB_SIZE + 10, y + math.floor((ITEM_HEIGHT - FONT_HGT) / 2), 1, 1, 1, 1, FONT)

    return y + ITEM_HEIGHT
end

---@class RCStructurePieceCatalogOptions
---@field x number?
---@field y number?
---@field width number?
---@field height number?
---@field structureId string
---@field category string
---@field variant string?
---@field tag string?
---@field titleKey string?
---@field title string?
---@field parentPanel any?
---@field onSelect fun(piece: table)?

---@param opts RCStructurePieceCatalogOptions
---@return RCStructurePieceCatalogPanel
function RCStructurePieceCatalogPanel.openFor(opts)
    if RCStructurePieceCatalogPanel.instance then
        RCStructurePieceCatalogPanel.instance:close()
    end

    local w = opts.width or 360
    local h = opts.height or 420
    local x = opts.x
    local y = opts.y
    if (x == nil or y == nil) and opts.parentPanel then
        x = opts.parentPanel:getAbsoluteX() + opts.parentPanel.width + PADDING
        y = opts.parentPanel:getAbsoluteY()
    end
    if x == nil then x = (getCore():getScreenWidth() - w) / 2 end
    if y == nil then y = (getCore():getScreenHeight() - h) / 2 end

    local win = RCStructurePieceCatalogPanel:new(x, y, w, h, opts)
    win:initialise()
    win:addToUIManager()
    RCStructurePieceCatalogPanel.instance = win
    return win
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param opts RCStructurePieceCatalogOptions
---@return RCStructurePieceCatalogPanel
function RCStructurePieceCatalogPanel:new(x, y, w, h, opts)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = opts.title
        or (opts.titleKey and getText(opts.titleKey))
        or getText("IGUI_RCStructureFramework_CatalogTitle")
    o.resizable = false
    o.structureId = opts.structureId
    o.category = opts.category
    o.variant = opts.variant
    o.tag = opts.tag
    o.parentPanel = opts.parentPanel
    o.onSelect = opts.onSelect
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    return o
end

---@return nil
function RCStructurePieceCatalogPanel:initialise()
    ISCollapsableWindow.initialise(self)

    local listY = self:titleBarHeight() + PADDING
    local listH = self.height - listY - PADDING - BUTTON_HGT - PADDING

    self.list = RCStructurePieceCatalogList:new(PADDING, listY, self.width - PADDING * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ITEM_HEIGHT
    self.list.font = FONT
    self.list.drawBorder = true
    self.list.target = self
    self.list.onmousedblclick = RCStructurePieceCatalogPanel.onListDoubleClick
    self:addChild(self.list)

    local buttonY = self.height - BUTTON_HGT - PADDING
    local buttonW = math.floor((self.width - PADDING * 3) / 2)

    self.selectButton = ISButton:new(
        PADDING,
        buttonY,
        buttonW,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_CatalogSelect"),
        self,
        RCStructurePieceCatalogPanel.onSelectClicked
    )
    self.selectButton:setFont(FONT)
    self.selectButton:enableAcceptColor()
    self:addChild(self.selectButton)

    self.cancelButton = ISButton:new(
        PADDING * 2 + buttonW,
        buttonY,
        buttonW,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_CatalogCancel"),
        self,
        RCStructurePieceCatalogPanel.onCancel
    )
    self.cancelButton:setFont(FONT)
    self.cancelButton:enableCancelColor()
    self:addChild(self.cancelButton)

    self:refreshList()
end

---@return table[]
---@nodiscard
function RCStructurePieceCatalogPanel:collectPieces()
    local pieces
    if self.tag then
        pieces = PieceLibrary.getByCategoryAndTag(self.category, self.tag)
    else
        pieces = PieceLibrary.getByCategory(self.category)
    end

    if not pieces then return {} end

    local localPlayer = getPlayer()
    local cheat = localPlayer and type(localPlayer.isBuildCheat) == "function"
        and localPlayer:isBuildCheat() == true

    ---@type table[]
    local filtered = {}
    for i = 1, #pieces do
        local piece = pieces[i]
        local matchStructure = self.structureId == nil or piece.structureId == nil or piece.structureId == self.structureId
        local matchVariant = self.variant == nil or piece.variant == nil or piece.variant == self.variant
        local unlocked = cheat or (not localPlayer) or PieceLibrary.isUnlockedFor(piece, localPlayer)
        if matchStructure and matchVariant and unlocked then
            filtered[#filtered + 1] = piece
        end
    end

    table.sort(filtered, function(a, b)
        return getPieceLabel(a) < getPieceLabel(b)
    end)

    return filtered
end

---@return nil
function RCStructurePieceCatalogPanel:refreshList()
    self.list:clear()
    self.pieces = self:collectPieces()

    if #self.pieces == 0 then
        self.list:addItem(getText("IGUI_RCStructureFramework_CatalogEmpty"), { empty = true })
        self.list.selected = 0
        return
    end

    for i = 1, #self.pieces do
        local piece = self.pieces[i]
        self.list:addItem(getPieceLabel(piece), { empty = false, piece = piece, index = i })
    end
    self.list.selected = 1
end

---@return table|nil
---@nodiscard
function RCStructurePieceCatalogPanel:getSelectedPiece()
    local selected = self.list.selected
    if not selected or selected < 1 then return nil end
    local item = self.list.items[selected]
    if not item or not item.item or item.item.empty then return nil end
    return item.item.piece
end

---@return nil
function RCStructurePieceCatalogPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local hasSelection = self:getSelectedPiece() ~= nil
    self.selectButton.enable = hasSelection
end

---@return nil
function RCStructurePieceCatalogPanel:onSelectClicked()
    local piece = self:getSelectedPiece()
    if not piece then return end
    if type(self.onSelect) == "function" then
        self.onSelect(piece)
    end
    self:close()
end

---@param self ISScrollingListBox
---@param item table
---@return nil
function RCStructurePieceCatalogPanel.onListDoubleClick(self, item)
    local panel = self.parent
    if panel and panel.onSelectClicked then
        panel:onSelectClicked()
    end
end

---@return nil
function RCStructurePieceCatalogPanel:onCancel()
    self:close()
end

---@return nil
function RCStructurePieceCatalogPanel:close()
    if RCStructurePieceCatalogPanel.instance == self then
        RCStructurePieceCatalogPanel.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

return RCStructurePieceCatalogPanel
