require("ISUI/ISCollapsableWindowJoypad")
require("ISUI/ISPanelJoypad")
require("ISUI/ISButton")
require("ISUI/ISContextMenu")
require("TimedActions/WalkToTimedAction")
require("RCStructureFramework/TimedActions/PlaceStructureAction")
require("RCStructureFramework/PresetsWindow")
require("RCStructureFramework/SavePresetDialog")
require("RCStructureFramework/PieceCatalogPanel")

local Registry = require("RCStructureFramework/Registry")
local Builder = require("RCStructureFramework/Builder")
local Geometry = require("RCStructureFramework/Geometry")
local MaterialContainers = require("RCStructureFramework/MaterialContainers")
local PlacementValidation = require("RCStructureFramework/PlacementValidation")
local Plans = require("RCStructureFramework/Plans")
local Presets = require("RCStructureFramework/Presets")
local DefaultValidators = require("RCStructureFramework/DefaultValidators")
local PiecePresence = require("RCStructureFramework/PiecePresence")

RCStructurePlacementUI = RCStructurePlacementUI or {}
---@class RCStructurePlacementPanel : ISCollapsableWindowJoypad
RCStructurePlacementPanel = ISCollapsableWindowJoypad:derive("RCStructurePlacementPanel")

local FONT_BODY = UIFont.Medium
local FONT_HGT_BODY = getTextManager():getFontHeight(FONT_BODY)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_BODY + 10
local PHASE_SELECT = "select"
local PHASE_EDIT = "edit"
local EDIT_WALLS = "walls"
local EDIT_CELLS = "cells"
local CATEGORY_WALL = "wall"
local CATEGORY_FLOOR = "floor"
local CATEGORY_ROOF = "roof"
local GABLE_AXIS_NORTH_SOUTH = "northSouth"
local GABLE_AXIS_WEST_EAST = "westEast"
local MIN_BUILD_Z = 0
local MAX_BUILD_Z = 12
local MAX_PIECE_BUTTONS_PER_ROW = 4
---@type table<string, IsoSprite>
local PREVIEW_SPRITES = {}

---@param spriteName string
---@return IsoSprite
---@nodiscard
local function getPreviewSprite(spriteName)
    local sprite = PREVIEW_SPRITES[spriteName]
    if not sprite then
        sprite = IsoSprite.new()
        sprite:LoadSingleTexture(spriteName)
        PREVIEW_SPRITES[spriteName] = sprite
    end
    return sprite
end

---@param value number
---@return number
---@nodiscard
local function floorValue(value)
    return math.floor(value)
end

---@param value number
---@return integer
---@nodiscard
local function clampBuildZ(value)
    local z = floorValue(value)
    if z < MIN_BUILD_Z then
        return MIN_BUILD_Z
    end
    if z > MAX_BUILD_Z then
        return MAX_BUILD_Z
    end
    return z
end

---@param z integer
---@return string
---@nodiscard
local function formatBuildZ(z)
    if z > 0 then
        return "+" .. tostring(z)
    end
    return tostring(z)
end

---@param target table
---@return integer
---@nodiscard
local function getPickedSquareX(target)
    return target.x
end

---@param target table
---@return integer
---@nodiscard
local function getPickedSquareY(target)
    return target.y
end

---@param target table
---@return integer
---@nodiscard
local function getPickedSquareZ(target)
    return target.z
end

---@param x integer
---@param y integer
---@param z integer
---@return table
---@nodiscard
local function newPickedSquare(x, y, z)
    return {
        x = x,
        y = y,
        z = z,
        getX = getPickedSquareX,
        getY = getPickedSquareY,
        getZ = getPickedSquareZ,
    }
end

---@param panel ISUIElement
---@param x number
---@param y number
---@return boolean
---@nodiscard
local function isInsidePanel(panel, x, y)
    return x >= 0 and x < panel.width and y >= 0 and y < panel.height
end

---@param button ISButton
---@return nil
local function setPlacementButtonFont(button)
    button:setFont(FONT_BODY)
end

---@param def table
---@return table
---@nodiscard
local function getEditorConfig(def)
    if type(def.editor) == "table" then
        return def.editor
    end
    return {}
end

---@param def table
---@return table
---@nodiscard
local function getPieceTypes(def)
    local editor = getEditorConfig(def)
    if type(editor.pieceTypes) == "table" and #editor.pieceTypes > 0 then
        return editor.pieceTypes
    end
    return {
        { id = "wall", labelKey = "IGUI_RCStructureFramework_WallRegular" },
    }
end

---@param def table
---@param field string
---@param defaultKey string
---@return string
---@nodiscard
local function getDefText(def, field, defaultKey)
    local key = def[field]
    if type(key) ~= "string" or key == "" then
        key = defaultKey
    end
    return getText(key)
end

---@param def table
---@return boolean
---@nodiscard
local function canEditCells(def)
    local editor = getEditorConfig(def)
    return editor.allowCells == true
end

---@param def table
---@return boolean
---@nodiscard
local function useCatalogUI(def)
    return def.useCatalogUI == true
end

---@param def table
---@return boolean
---@nodiscard
local function isSingleStorey(def)
    return def.singleStorey ~= false and def.allowMultiStorey ~= true
end

---@param def table
---@return boolean
---@nodiscard
local function isZControlEnabled(def)
    return def.disableZControl ~= true
end

---@param category string?
---@return string
---@nodiscard
local function editModeForCategory(category)
    if category == CATEGORY_FLOOR then return EDIT_CELLS end
    return EDIT_WALLS
end

---@param def table
---@param rect table
---@param gableAxis string?
---@return boolean
---@return string|nil
---@nodiscard
local function selectionIsValid(def, rect, gableAxis)
    if def.isSelectionValid then
        return def.isSelectionValid(rect, gableAxis)
    end
    if def.getGableAxis then
        return Builder.getGableAxis(def.id, rect.w, rect.h, gableAxis) ~= nil
    end
    return rect.w > 0 and rect.h > 0
end

---@param x number
---@param y number
---@param z number
---@return string
---@nodiscard
local function cellKey(x, y, z)
    return Geometry.squareKey(x, y, z)
end

---@return nil
function RCStructurePlacementPanel:initialise()
    ISCollapsableWindowJoypad.initialise(self)
    self:createChildren()
    if self.pinButton then self.pinButton:setVisible(false) end
    if self.collapseButton then self.collapseButton:setVisible(false) end

    local bottomReserve = self:resizeWidgetHeight() + UI_BORDER_SPACING

    local buttonY = self.height - bottomReserve - BUTTON_HGT
    local halfWidth = math.floor((self.width - (UI_BORDER_SPACING * 3)) / 2)

    self.accept = ISButton:new(
        UI_BORDER_SPACING,
        buttonY,
        halfWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_Accept"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.accept.internal = "ACCEPT"
    setPlacementButtonFont(self.accept)
    self.accept:enableAcceptColor()
    self:addChild(self.accept)

    self.cancel = ISButton:new(
        UI_BORDER_SPACING * 2 + halfWidth,
        buttonY,
        halfWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_Cancel"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.cancel.internal = "CANCEL"
    setPlacementButtonFont(self.cancel)
    self.cancel:enableCancelColor()
    self:addChild(self.cancel)

    self.placeStructure = ISButton:new(
        UI_BORDER_SPACING,
        buttonY,
        halfWidth,
        BUTTON_HGT,
        getDefText(self.definition, "placeLabelKey", "IGUI_RCStructureFramework_PlaceStructure"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.placeStructure.internal = "PLACE_STRUCTURE"
    setPlacementButtonFont(self.placeStructure)
    self.placeStructure:enableAcceptColor()
    self:addChild(self.placeStructure)

    local pieceTypes = getPieceTypes(self.definition)
    local pieceCount = #pieceTypes
    local perRow = pieceCount
    if perRow > MAX_PIECE_BUTTONS_PER_ROW then perRow = MAX_PIECE_BUTTONS_PER_ROW end
    if perRow < 1 then perRow = 1 end
    local rowCount = math.ceil(pieceCount / perRow)
    local pieceButtonWidth = math.floor((self.width - (UI_BORDER_SPACING * (perRow + 1))) / perRow)
    local pieceRowsHeight = rowCount * BUTTON_HGT + (rowCount - 1) * UI_BORDER_SPACING
    local pieceButtonY = buttonY - pieceRowsHeight - UI_BORDER_SPACING
    ---@type ISButton[]
    self.pieceButtons = {}
    for i = 1, pieceCount do
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local piece = pieceTypes[i]
        local button = ISButton:new(
            UI_BORDER_SPACING + col * (UI_BORDER_SPACING + pieceButtonWidth),
            pieceButtonY + row * (BUTTON_HGT + UI_BORDER_SPACING),
            pieceButtonWidth,
            BUTTON_HGT,
            getText(piece.labelKey),
            self,
            RCStructurePlacementPanel.onClick
        )
        button.internal = "PIECE_" .. tostring(i)
        button.pieceType = piece.id
        button.pieceCategory = piece.category
        setPlacementButtonFont(button)
        self:addChild(button)
        self.pieceButtons[#self.pieceButtons + 1] = button
    end

    local secondaryY = pieceButtonY - BUTTON_HGT - UI_BORDER_SPACING
    local thirdWidth = math.floor((self.width - UI_BORDER_SPACING * 4) / 3)

    self.rotateButton = ISButton:new(
        UI_BORDER_SPACING,
        secondaryY,
        thirdWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_Rotate"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.rotateButton.internal = "ROTATE"
    setPlacementButtonFont(self.rotateButton)
    self:addChild(self.rotateButton)

    self.eraseButton = ISButton:new(
        UI_BORDER_SPACING * 2 + thirdWidth,
        secondaryY,
        thirdWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_Erase"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.eraseButton.internal = "ERASE_MODE"
    setPlacementButtonFont(self.eraseButton)
    self:addChild(self.eraseButton)

    self.cellModeButton = ISButton:new(
        UI_BORDER_SPACING * 3 + thirdWidth * 2,
        secondaryY,
        thirdWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_FootprintMode"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.cellModeButton.internal = "CELL_MODE"
    setPlacementButtonFont(self.cellModeButton)
    self:addChild(self.cellModeButton)

    local presetsRowY = secondaryY - BUTTON_HGT - UI_BORDER_SPACING
    local presetThirdWidth = math.floor((self.width - UI_BORDER_SPACING * 4) / 3)

    self.editFootprintButton = ISButton:new(
        UI_BORDER_SPACING,
        presetsRowY,
        presetThirdWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_EditFootprint"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.editFootprintButton.internal = "EDIT_FOOTPRINT"
    self.editFootprintButton:setTooltip(getText("Tooltip_RCStructureFramework_EditFootprint"))
    setPlacementButtonFont(self.editFootprintButton)
    self:addChild(self.editFootprintButton)

    self.openPresets = ISButton:new(
        UI_BORDER_SPACING * 2 + presetThirdWidth,
        presetsRowY,
        presetThirdWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_OpenPresets"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.openPresets.internal = "OPEN_PRESETS"
    setPlacementButtonFont(self.openPresets)
    self:addChild(self.openPresets)

    self.savePreset = ISButton:new(
        UI_BORDER_SPACING * 3 + presetThirdWidth * 2,
        presetsRowY,
        presetThirdWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_SavePreset"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.savePreset.internal = "SAVE_PRESET"
    setPlacementButtonFont(self.savePreset)
    self:addChild(self.savePreset)

    local zRowY = presetsRowY - BUTTON_HGT - UI_BORDER_SPACING
    local zButtonWidth = BUTTON_HGT + 24
    self.zControlY = zRowY
    self.zControlLabelX = UI_BORDER_SPACING * 2 + zButtonWidth
    self.zControlLabelWidth = self.width - (UI_BORDER_SPACING * 4) - (zButtonWidth * 2)

    self.zDownButton = ISButton:new(
        UI_BORDER_SPACING,
        zRowY,
        zButtonWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_BuildLevelDown"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.zDownButton.internal = "Z_DOWN"
    self.zDownButton:setTooltip(getText("Tooltip_RCStructureFramework_BuildLevelDown"))
    setPlacementButtonFont(self.zDownButton)
    self:addChild(self.zDownButton)

    self.zUpButton = ISButton:new(
        UI_BORDER_SPACING * 3 + zButtonWidth + self.zControlLabelWidth,
        zRowY,
        zButtonWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_BuildLevelUp"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.zUpButton.internal = "Z_UP"
    self.zUpButton:setTooltip(getText("Tooltip_RCStructureFramework_BuildLevelUp"))
    setPlacementButtonFont(self.zUpButton)
    self:addChild(self.zUpButton)

    local editZRowY = zRowY - BUTTON_HGT - UI_BORDER_SPACING
    self.editZControlY = editZRowY

    self.editZDownButton = ISButton:new(
        UI_BORDER_SPACING,
        editZRowY,
        zButtonWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_EditLevelDown"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.editZDownButton.internal = "EDIT_Z_DOWN"
    self.editZDownButton:setTooltip(getText("Tooltip_RCStructureFramework_EditLevelDown"))
    setPlacementButtonFont(self.editZDownButton)
    self:addChild(self.editZDownButton)

    self.editZUpButton = ISButton:new(
        UI_BORDER_SPACING * 3 + zButtonWidth + self.zControlLabelWidth,
        editZRowY,
        zButtonWidth,
        BUTTON_HGT,
        getText("IGUI_RCStructureFramework_EditLevelUp"),
        self,
        RCStructurePlacementPanel.onClick
    )
    self.editZUpButton.internal = "EDIT_Z_UP"
    self.editZUpButton:setTooltip(getText("Tooltip_RCStructureFramework_EditLevelUp"))
    setPlacementButtonFont(self.editZUpButton)
    self:addChild(self.editZUpButton)

    self:updateButtonVisibility()
end

---@return nil
function RCStructurePlacementPanel:updateButtonVisibility()
    local selecting = self.phase == PHASE_SELECT
    local editing = self.phase == PHASE_EDIT
    local previewing = self.previewMode == true

    self.accept:setVisible(selecting and not previewing)
    self.placeStructure:setVisible(editing)
    for i = 1, #self.pieceButtons do
        self.pieceButtons[i]:setVisible(editing)
    end
    self.rotateButton:setVisible(editing)
    self.eraseButton:setVisible(editing)
    self.cellModeButton:setVisible(editing and canEditCells(self.definition))
    self.openPresets:setVisible(true)
    self.savePreset:setVisible(editing)
    self.editFootprintButton:setVisible(editing)
    local zEnabled = isZControlEnabled(self.definition)
    self.zDownButton:setVisible(zEnabled)
    self.zUpButton:setVisible(zEnabled)
    local multiStorey = not isSingleStorey(self.definition)
    self.editZDownButton:setVisible(zEnabled and multiStorey and editing)
    self.editZUpButton:setVisible(zEnabled and multiStorey and editing)
end

---@param button ISButton
---@return nil
function RCStructurePlacementPanel:onClick(button)
    if button.internal == "CANCEL" then
        self:close()
        return
    end

    if button.internal == "ACCEPT" then
        self:acceptSelection()
        return
    end

    if button.internal == "ROTATE" then
        self:rotateStructure()
    elseif button.internal == "ERASE_MODE" then
        self.eraseMode = not self.eraseMode
        self:updateButtonVisibility()
    elseif button.internal == "CELL_MODE" then
        if self.editMode == EDIT_CELLS then
            self.editMode = EDIT_WALLS
        else
            self.editMode = EDIT_CELLS
        end
        self.activePiece = nil
        self:updateButtonVisibility()
    elseif button.internal == "PLACE_STRUCTURE" then
        self:queuePlacement()
    elseif button.internal == "OPEN_PRESETS" then
        RCStructurePresetsWindow.openFor(self.structureId, self)
    elseif button.internal == "SAVE_PRESET" then
        RCStructureSavePresetDialog.openFor(self)
    elseif button.internal == "EDIT_FOOTPRINT" then
        self:enterFootprintEditMode()
    elseif button.internal == "Z_DOWN" then
        self:changeBuildZ(-1)
    elseif button.internal == "Z_UP" then
        self:changeBuildZ(1)
    elseif button.internal == "EDIT_Z_DOWN" then
        self:changeActiveEditZ(-1)
    elseif button.internal == "EDIT_Z_UP" then
        self:changeActiveEditZ(1)
    elseif button.pieceType then
        if useCatalogUI(self.definition) and button.pieceCategory then
            self:openCatalogFor(button.pieceCategory, button.pieceType)
        else
            self.eraseMode = false
            self.selectedWallType = button.pieceType
            self.editMode = EDIT_WALLS
            self.activePiece = nil
            self:updateButtonVisibility()
        end
    end
end

---@param category string
---@param pieceType string?
---@return nil
function RCStructurePlacementPanel:openCatalogFor(category, pieceType)
    self.eraseMode = false
    self.editMode = editModeForCategory(category)
    self:updateButtonVisibility()

    RCStructurePieceCatalogPanel.openFor({
        structureId = self.structureId,
        category = category,
        variant = self.variant,
        parentPanel = self,
        title = nil,
        ---@param piece table
        onSelect = function(piece)
            self:onCatalogPieceSelected(category, pieceType, piece)
        end,
    })
end

---@param category string
---@param pieceType string?
---@param piece table
---@return nil
function RCStructurePlacementPanel:onCatalogPieceSelected(category, pieceType, piece)
    self.eraseMode = false
    self.activePiece = {
        category = category,
        pieceType = pieceType or piece.pieceType,
        slotKind = piece.slotKind or piece.subcategory,
        spriteName = piece.spriteName,
        northVariant = piece.northVariant,
        westVariant = piece.westVariant,
        openSpriteName = piece.openSpriteName,
        isRug = piece.isRug == true and true or nil,
    }
    if self.activePiece.pieceType then
        self.selectedWallType = self.activePiece.pieceType
    end
    self.editMode = editModeForCategory(category)
    self:updateButtonVisibility()
end

---@param z integer
---@return nil
function RCStructurePlacementPanel:movePlanToBuildZ(z)
    if type(self.rects) == "table" then
        for i = 1, #self.rects do
            self.rects[i].z = z
        end
    end
    if self.rect then
        self.rect.z = z
    end
    for i = 1, #self.walls do
        self.walls[i].z = z
    end
    for i = 1, #self.cells do
        self.cells[i].z = z
    end
    self:rebuildWallMap()
    self:rebuildCellMap()
end

---@param z number
---@return nil
function RCStructurePlacementPanel:setBuildZ(z)
    local buildZ = clampBuildZ(z)
    if buildZ == self.selectedZ then
        return
    end

    local prevZ = self.selectedZ
    self.selectedZ = buildZ
    if isSingleStorey(self.definition) then
        self:movePlanToBuildZ(buildZ)
        self.activeEditZ = buildZ
    else
        local offset = (self.activeEditZ or buildZ) - prevZ
        self.activeEditZ = clampBuildZ(buildZ + offset)
    end
    if self.previewAnchor then
        self.previewAnchor.z = buildZ
    end
end

---@param delta integer
---@return nil
function RCStructurePlacementPanel:changeBuildZ(delta)
    self:setBuildZ(self.selectedZ + delta)
end

---@param z number
---@return nil
function RCStructurePlacementPanel:setActiveEditZ(z)
    local clamped = clampBuildZ(z)
    if isSingleStorey(self.definition) then
        clamped = self.selectedZ
    end
    self.activeEditZ = clamped
end

---@param delta integer
---@return nil
function RCStructurePlacementPanel:changeActiveEditZ(delta)
    self:setActiveEditZ((self.activeEditZ or self.selectedZ) + delta)
end

---@return nil
function RCStructurePlacementPanel:close()
    ISWorldObjectContextMenu.disableWorldMenu = false
    if RCStructurePlacementUI.instance == self then
        RCStructurePlacementUI.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

---@param screenX number
---@param screenY number
---@return IsoGridSquare|table
---@nodiscard
function RCStructurePlacementPanel:pickSquare(screenX, screenY)
    local playerIndex = self.playerIndex
    local z = self.activeEditZ or self.selectedZ
    local worldX = floorValue(screenToIsoX(playerIndex, screenX, screenY, z))
    local worldY = floorValue(screenToIsoY(playerIndex, screenX, screenY, z))
    local square = getCell():getGridSquare(worldX, worldY, z)
    if square then
        return square
    end
    return newPickedSquare(worldX, worldY, z)
end

---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:getSelectionRect()
    if self.startingX == nil or self.startingY == nil or self.endX == nil or self.endY == nil then
        return nil
    end

    return Plans.getSelectionRect(
        self.startingX,
        self.startingY,
        self.endX,
        self.endY,
        self.selectedZ
    )
end

---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:getActiveRect()
    if self.previewMode and self.pendingPreset and self.previewAnchor then
        return {
            x = self.previewAnchor.x,
            y = self.previewAnchor.y,
            z = self.previewAnchor.z,
            w = self.pendingPreset.w,
            h = self.pendingPreset.h,
        }
    end
    if self.phase == PHASE_SELECT then
        return self:getSelectionRect()
    end
    return self.rect
end

---@param rect table
---@return string|nil
---@nodiscard
function RCStructurePlacementPanel:getGableAxisForRect(rect)
    return Builder.getGableAxis(self.structureId, rect.w, rect.h, self.gableAxis)
end

---@return nil
function RCStructurePlacementPanel:rotateWall()
    self.wallNorth = not self.wallNorth
end

---@return nil
function RCStructurePlacementPanel:rotateStructure()
    if not self.rect then
        return
    end

    if type(self.rects) == "table" and #self.rects > 1 then
        self:rotateWall()
        return
    end

    if self.editMode == EDIT_CELLS then
        self:rotateWall()
        return
    end

    local oldRect = self.rect
    local oldRx = oldRect.x
    local oldRy = oldRect.y
    local oldWalls = self.walls
    local oldCells = self.cells

    local newW = oldRect.h
    local newH = oldRect.w
    local rotated = {
        x = oldRect.x,
        y = oldRect.y,
        z = oldRect.z,
        w = newW,
        h = newH,
    }

    local swappedAxis = self.gableAxis
    if self.gableAxis == GABLE_AXIS_NORTH_SOUTH then
        swappedAxis = GABLE_AXIS_WEST_EAST
    elseif self.gableAxis == GABLE_AXIS_WEST_EAST then
        swappedAxis = GABLE_AXIS_NORTH_SOUTH
    end

    local newAxis = Builder.getGableAxis(self.structureId, newW, newH, swappedAxis)
    if not newAxis and self.definition.getGableAxis then
        newAxis = Builder.getGableAxis(self.structureId, newW, newH)
    end
    if self.definition.getGableAxis and not newAxis then
        return
    end

    self.rect = rotated
    if type(self.rects) == "table" and #self.rects == 1 then
        self.rects[1] = rotated
    end
    self.gableAxis = newAxis
    self.walls = {}
    self.wallMap = {}
    self.cells = {}
    self.cellMap = {}
    self:populatePerimeterWalls()

    for i = 1, #oldWalls do
        local wall = oldWalls[i]
        self:addOrReplaceWall({
            x = oldRx + (wall.y - oldRy),
            y = oldRy + (wall.x - oldRx),
            z = wall.z,
            north = not wall.north,
            wallType = wall.wallType,
        })
    end

    for i = 1, #oldCells do
        local cell = oldCells[i]
        self:addOrReplaceCell({
            x = oldRx + (cell.y - oldRy),
            y = oldRy + (cell.x - oldRx),
            z = cell.z,
        })
    end
end

---@param x integer
---@param y integer
---@param z integer
---@return integer|nil
---@nodiscard
function RCStructurePlacementPanel:findRectIndexAt(x, y, z)
    for i = 1, #self.rects do
        local r = self.rects[i]
        if (r.z or 0) == z and Geometry.rectContainsCell(r, x, y) then
            return i
        end
    end
    return nil
end

---@param candidate table|nil
---@return table
---@nodiscard
function RCStructurePlacementPanel:buildValidationPlan(candidate)
    local rects = {}
    for i = 1, #self.rects do
        rects[i] = self.rects[i]
    end
    if candidate then
        rects[#rects + 1] = candidate
    end
    return { rects = rects }
end

---@param rect table
---@return boolean ok, string|nil reason
---@nodiscard
function RCStructurePlacementPanel:validateRectAgainstCommitted(rect)
    if rect.w < 1 or rect.h < 1 then
        return false, "rectTooSmall"
    end
    local plan = self:buildValidationPlan(rect)
    return DefaultValidators.multiRectEdgeConnectivity(plan)
end

---@return boolean committed
function RCStructurePlacementPanel:commitDraftRect()
    local rect = self:getSelectionRect()
    if not rect then
        return false
    end
    rect.kind = "room"

    local gableAxis = self:getGableAxisForRect(rect)
    if not selectionIsValid(self.definition, rect, gableAxis) then
        return false
    end

    if #self.rects > 0 then
        local ok = self:validateRectAgainstCommitted(rect)
        if not ok then
            return false
        end
    end

    self.rects[#self.rects + 1] = rect
    self.rect = rect
    if #self.rects == 1 then
        self.gableAxis = gableAxis
    end
    self.selectedRectIndex = nil
    return true
end

---@return nil
function RCStructurePlacementPanel:acceptSelection()
    if self:getSelectionRect() and #self.rects == 0 then
        self:commitDraftRect()
    end

    if #self.rects == 0 then
        return
    end

    local ok = DefaultValidators.noEmptyPlan({ rects = self.rects })
    if not ok then
        return
    end
    ok = DefaultValidators.multiRectEdgeConnectivity({ rects = self.rects })
    if not ok then
        return
    end

    if self.footprintEditMode == true then
        local pruned = self:pruneOutsideFootprint()
        self.footprintEditMode = false
        self.rect = self.rects[1]
        self.phase = PHASE_EDIT
        self.editMode = EDIT_WALLS
        self.selectedRectIndex = nil
        self:updateButtonVisibility()
        if pruned > 0 and self.character then
            HaloTextHelper.addBadText(self.character,
                getText("IGUI_RCStructureFramework_FootprintEdit_Pruned", tostring(pruned)))
        end
        return
    end

    self.rect = self.rects[1]
    if not self.gableAxis then
        self.gableAxis = self:getGableAxisForRect(self.rect)
    end
    self.phase = PHASE_EDIT
    self.editMode = EDIT_WALLS
    self.walls = {}
    self.wallMap = {}
    self.cells = {}
    self.cellMap = {}
    self.selectedRectIndex = nil
    self:populatePerimeterWalls()
    self:populateRectangleCells()
    self:updateButtonVisibility()
end

---@return nil
function RCStructurePlacementPanel:enterFootprintEditMode()
    if self.phase ~= PHASE_EDIT then return end
    self.footprintEditMode = true
    self.phase = PHASE_SELECT
    self.selecting = false
    self.drawingWall = false
    self.drawingCell = false
    self.erasing = false
    self.eraseMode = false
    self.startingX = nil
    self.startingY = nil
    self.endX = nil
    self.endY = nil
    self.selectedRectIndex = nil
    self:updateButtonVisibility()
end

---@return integer  number of pieces pruned
function RCStructurePlacementPanel:pruneOutsideFootprint()
    local pruned = 0

    local newWalls = {}
    for i = 1, #self.walls do
        local wall = self.walls[i]
        local wz = wall.z or 0
        local keep = false
        for ri = 1, #self.rects do
            local r = self.rects[ri]
            if (r.z or 0) == wz then
                if Geometry.rectContainsCell(r, wall.x, wall.y) then
                    keep = true
                    break
                end
                if wall.north and Geometry.rectContainsCell(r, wall.x, wall.y - 1) then
                    keep = true
                    break
                end
                if (not wall.north) and Geometry.rectContainsCell(r, wall.x - 1, wall.y) then
                    keep = true
                    break
                end
            end
        end
        if keep then
            newWalls[#newWalls + 1] = wall
        else
            pruned = pruned + 1
        end
    end
    self.walls = newWalls
    self:rebuildWallMap()

    local newCells = {}
    for i = 1, #self.cells do
        local cell = self.cells[i]
        local cz = cell.z or 0
        local keep = false
        for ri = 1, #self.rects do
            local r = self.rects[ri]
            if (r.z or 0) == cz and Geometry.rectContainsCell(r, cell.x, cell.y) then
                keep = true
                break
            end
        end
        if keep then
            newCells[#newCells + 1] = cell
        else
            pruned = pruned + 1
        end
    end
    self.cells = newCells
    self:rebuildCellMap()

    pruned = pruned + (self:pruneExtraPiecesOutsideFootprint() or 0)
    return pruned
end

---@return integer
function RCStructurePlacementPanel:pruneExtraPiecesOutsideFootprint()
    return 0
end

---@param r table
---@return table[]  array of `{ id, x, y }`
---@nodiscard
function RCStructurePlacementPanel:getHandlePositions(r)
    local x1, y1 = r.x, r.y
    local x2, y2 = r.x + r.w - 1, r.y + r.h - 1
    local handles = {
        { id = "NW", x = x1, y = y1 },
        { id = "NE", x = x2, y = y1 },
        { id = "SE", x = x2, y = y2 },
        { id = "SW", x = x1, y = y2 },
    }
    return handles
end

---@param rectIndex integer|nil
---@param sx integer
---@param sy integer
---@param sz integer
---@return string|nil
---@nodiscard
function RCStructurePlacementPanel:getHandleAtSquare(rectIndex, sx, sy, sz)
    if rectIndex == nil then return nil end
    local r = self.rects[rectIndex]
    if not r then return nil end
    if (r.z or 0) ~= sz then return nil end

    local handles = self:getHandlePositions(r)
    for i = 1, #handles do
        local h = handles[i]
        if h.x == sx and h.y == sy then
            return h.id
        end
    end
    return nil
end

---@param renderZ integer|nil
---@return nil
function RCStructurePlacementPanel:renderSelectedRectHandles(renderZ)
    if self.phase ~= PHASE_SELECT then return end
    local idx = self.selectedRectIndex
    if not idx then return end
    local r = self.rects[idx]
    if not r then return end

    local z = renderZ or r.z or 0
    local handles = self:getHandlePositions(r)
    for i = 1, #handles do
        local h = handles[i]
        addAreaHighlightForPlayer(
            self.playerIndex,
            h.x, h.y, h.x + 1, h.y + 1,
            z,
            1.0, 0.95, 0.25, 0.85
        )
    end
end

---@param rect table
---@param handle string
---@param dragX integer
---@param dragY integer
---@return table
---@nodiscard
function RCStructurePlacementPanel:applyHandleResize(rect, handle, dragX, dragY)
    local x1, y1 = rect.x, rect.y
    local x2, y2 = rect.x + rect.w - 1, rect.y + rect.h - 1

    if handle == "NW" then x1, y1 = dragX, dragY
    elseif handle == "N"  then y1 = dragY
    elseif handle == "NE" then x2, y1 = dragX, dragY
    elseif handle == "E"  then x2 = dragX
    elseif handle == "SE" then x2, y2 = dragX, dragY
    elseif handle == "S"  then y2 = dragY
    elseif handle == "SW" then x1, y2 = dragX, dragY
    elseif handle == "W"  then x1 = dragX
    end

    if x2 < x1 then x1, x2 = x2, x1 end
    if y2 < y1 then y1, y2 = y2, y1 end

    return {
        x = x1, y = y1, z = rect.z,
        w = x2 - x1 + 1, h = y2 - y1 + 1,
        kind = rect.kind,
    }
end

---@param rectIndex integer
---@param handle string
---@return nil
function RCStructurePlacementPanel:beginResize(rectIndex, handle)
    local orig = self.rects[rectIndex]
    if not orig then return end
    self.resizingRectIndex = rectIndex
    self.resizingHandle = handle
    self.resizingOrigRect = {
        x = orig.x, y = orig.y, z = orig.z,
        w = orig.w, h = orig.h, kind = orig.kind,
    }
end

---@param square IsoGridSquare|table|nil
---@return nil
function RCStructurePlacementPanel:updateResize(square)
    if not self.resizingHandle or not self.resizingOrigRect or not self.resizingRectIndex then
        return
    end
    if not square then return end
    local newRect = self:applyHandleResize(
        self.resizingOrigRect, self.resizingHandle,
        square:getX(), square:getY()
    )
    self.rects[self.resizingRectIndex] = newRect
    if self.selectedRectIndex == self.resizingRectIndex and self.rect then
        if self.rect == self.resizingOrigRect or self.rects[self.resizingRectIndex] then
            self.rect = self.rects[self.resizingRectIndex]
        end
    end
end

---@return boolean  true when the resize was committed, false when reverted
function RCStructurePlacementPanel:endResize()
    local idx = self.resizingRectIndex
    if not idx then return false end

    local newRect = self.rects[idx]
    local committed = true

    if not newRect or newRect.w < 1 or newRect.h < 1 then
        committed = false
    elseif #self.rects > 1 then
        local plan = { rects = {} }
        for i = 1, #self.rects do
            if i ~= idx then
                plan.rects[#plan.rects + 1] = self.rects[i]
            end
        end
        plan.rects[#plan.rects + 1] = newRect
        local ok = DefaultValidators.multiRectEdgeConnectivity(plan)
        if not ok then committed = false end
    end

    if not committed then
        self.rects[idx] = self.resizingOrigRect
        if self.rect == newRect then
            self.rect = self.rects[idx]
        end
    else
        if self.rect == self.resizingOrigRect then
            self.rect = self.rects[idx]
        end
    end

    self.resizingRectIndex = nil
    self.resizingHandle = nil
    self.resizingOrigRect = nil
    return committed
end

---@return nil
function RCStructurePlacementPanel:populatePerimeterWalls()
    local rects = self.rects
    if type(rects) ~= "table" or #rects == 0 then
        if not self.rect then
            return
        end
        rects = { self.rect }
    end

    for ri = 1, #rects do
        local rect = rects[ri]
        local walls = Plans.getRectanglePerimeterWalls(rect, self.selectedWallType)
        for i = 1, #walls do
            self:addOrReplaceWall(walls[i])
        end
    end
end

---@return nil
function RCStructurePlacementPanel:populateRectangleCells()
    if not canEditCells(self.definition) then
        return
    end

    local rects = self.rects
    if type(rects) ~= "table" or #rects == 0 then
        if not self.rect then
            return
        end
        rects = { self.rect }
    end

    for ri = 1, #rects do
        local rect = rects[ri]
        for x = rect.x, rect.x + rect.w - 1 do
            for y = rect.y, rect.y + rect.h - 1 do
                self:addOrReplaceCell({ x = x, y = y, z = rect.z })
            end
        end
    end
end

---@param wall table
---@return nil
function RCStructurePlacementPanel:addOrReplaceWall(wall)
    local key = Plans.wallKey(wall)
    local index = self.wallMap[key]
    if index then
        self.walls[index] = wall
    else
        self.walls[#self.walls + 1] = wall
        self.wallMap[key] = #self.walls
    end
end

---@return nil
function RCStructurePlacementPanel:rebuildWallMap()
    self.wallMap = Plans.buildWallMap(self.walls)
end

---@param key string
---@return nil
function RCStructurePlacementPanel:removeWallByKey(key)
    local index = self.wallMap[key]
    if not index then
        return
    end

    table.remove(self.walls, index)
    self:rebuildWallMap()
end

---@param cell table
---@return nil
function RCStructurePlacementPanel:addOrReplaceCell(cell)
    local key = cellKey(cell.x, cell.y, cell.z)
    local index = self.cellMap[key]
    if index then
        self.cells[index] = cell
    else
        self.cells[#self.cells + 1] = cell
        self.cellMap[key] = #self.cells
    end
end

---@return nil
function RCStructurePlacementPanel:rebuildCellMap()
    self.cellMap = {}
    for i = 1, #self.cells do
        local cell = self.cells[i]
        self.cellMap[cellKey(cell.x, cell.y, cell.z)] = i
    end
end

---@param key string
---@return nil
function RCStructurePlacementPanel:removeCellByKey(key)
    local index = self.cellMap[key]
    if not index then
        return
    end

    table.remove(self.cells, index)
    self:rebuildCellMap()
end

---@param north boolean
---@return string|nil
---@nodiscard
function RCStructurePlacementPanel:resolveActiveWallSprite(north)
    local active = self.activePiece
    if not active then return nil end
    if north and type(active.northVariant) == "string" and active.northVariant ~= "" then
        return active.northVariant
    end
    if (not north) and type(active.westVariant) == "string" and active.westVariant ~= "" then
        return active.westVariant
    end
    return active.spriteName
end

---@return table[]
---@nodiscard
function RCStructurePlacementPanel:getActiveRectList()
    if type(self.rects) == "table" and #self.rects > 0 then
        return self.rects
    end
    if self.rect then
        return { self.rect }
    end
    return {}
end

---@param square IsoGridSquare|table
---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:getDraftWallForSquare(square)
    if not square then
        return nil
    end

    local rects = self:getActiveRectList()
    if #rects == 0 then
        return nil
    end

    local x = square:getX()
    local y = square:getY()
    local z = floorValue(square:getZ())
    local singleStorey = isSingleStorey(self.definition)

    for ri = 1, #rects do
        local rect = rects[ri]
        if (not singleStorey) or z == rect.z then
            if Plans.wallSlotIsInsideRect(rect, x, y, self.wallNorth) then
                local wall = {
                    x = x,
                    y = y,
                    z = z,
                    north = self.wallNorth,
                    wallType = self.selectedWallType,
                }
                if self.activePiece and self.activePiece.category == CATEGORY_WALL then
                    wall.slotKind = self.activePiece.slotKind
                    wall.spriteName = self:resolveActiveWallSprite(self.wallNorth)
                    wall.openSpriteName = self.activePiece.openSpriteName
                end
                return wall
            end
        end
    end

    return nil
end

---@param square IsoGridSquare|table
---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:getDraftCellForSquare(square)
    if not square then
        return nil
    end

    local rects = self:getActiveRectList()
    if #rects == 0 then
        return nil
    end

    local x = square:getX()
    local y = square:getY()
    local z = floorValue(square:getZ())
    local singleStorey = isSingleStorey(self.definition)

    for ri = 1, #rects do
        local rect = rects[ri]
        if (not singleStorey) or z == rect.z then
            if Geometry.rectContainsCell(rect, x, y) then
                local cell = { x = x, y = y, z = z }
                if self.activePiece and self.activePiece.category == CATEGORY_FLOOR then
                    cell.spriteName = self.activePiece.spriteName
                    if self.activePiece.isRug == true then
                        cell.isRug = true
                    end
                end
                return cell
            end
        end
    end

    return nil
end

---@param square IsoGridSquare|table
---@return table|nil
---@return string|nil
---@nodiscard
function RCStructurePlacementPanel:getExistingWallForSquare(square)
    if not square then
        return nil, nil
    end

    local x = square:getX()
    local y = square:getY()
    local z = floorValue(square:getZ())

    local selectedKey = Plans.makeWallKey(x, y, z, self.wallNorth)
    local selectedIndex = self.wallMap[selectedKey]
    if selectedIndex then
        return self.walls[selectedIndex], selectedKey
    end

    for i = 1, #self.walls do
        local wall = self.walls[i]
        if wall.x == x and wall.y == y and wall.z == z then
            return wall, Plans.wallKey(wall)
        end
    end

    local northKey = Plans.makeWallKey(x, y, z, true)
    local northIndex = self.wallMap[northKey]
    if northIndex then
        return self.walls[northIndex], northKey
    end

    local westKey = Plans.makeWallKey(x, y, z, false)
    local westIndex = self.wallMap[westKey]
    if westIndex then
        return self.walls[westIndex], westKey
    end

    return nil, nil
end

---@param square IsoGridSquare|table
---@return nil
function RCStructurePlacementPanel:addDraftWallForSquare(square)
    local wall = self:getDraftWallForSquare(square)
    if wall then
        self:addOrReplaceWall(wall)
    end
end

---@param square IsoGridSquare|table
---@return nil
function RCStructurePlacementPanel:addDraftCellForSquare(square)
    local cell = self:getDraftCellForSquare(square)
    if cell then
        self:addOrReplaceCell(cell)
    end
end

---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:getPlan()
    local rects = self.rects
    if (type(rects) ~= "table" or #rects == 0) and not self.rect then
        return nil
    end

    if type(rects) ~= "table" or #rects == 0 then
        rects = { self.rect }
    end

    local anchor = rects[1]
    return {
        version = 3,
        structureId = self.structureId,
        variant = self.variant,
        color = self.variant,
        x = anchor.x,
        y = anchor.y,
        z = anchor.z,
        w = anchor.w,
        h = anchor.h,
        gableAxis = self.gableAxis,
        walls = self.walls,
        cells = self.cells,
        roofs = self.roofs or {},
        rects = rects,
        stairs = self.stairs or {},
    }
end

---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:getSummary()
    local plan = self:getPlan()
    if not plan then
        return nil
    end
    return PlacementValidation.getPlacementSummary(self.structureId, plan)
end

---@return boolean
---@return string|nil
---@return table|nil
---@nodiscard
function RCStructurePlacementPanel:validatePlan()
    local plan = self:getPlan()
    if not plan then
        return false, "selection"
    end
    return PlacementValidation.validateContainerPlacement(self.structureId, self.character, self.container, plan)
end

---@param preset table
---@return nil
function RCStructurePlacementPanel:beginPresetPreview(preset)
    if not preset then return end
    self.pendingPreset = preset
    self.previewMode = true
    self.phase = PHASE_SELECT
    self.selecting = false
    self.drawingWall = false
    self.drawingCell = false
    self.startingX = nil
    self.startingY = nil
    self.endX = nil
    self.endY = nil
    self.rect = nil
    self.rects = {}
    self.selectedRectIndex = nil
    self.walls = {}
    self.wallMap = {}
    self.cells = {}
    self.cellMap = {}
    self.previewAnchor = nil
    self:updateButtonVisibility()
end

---@return nil
function RCStructurePlacementPanel:cancelPresetPreview()
    self.previewMode = false
    self.pendingPreset = nil
    self.previewAnchor = nil
    self:updateButtonVisibility()
end

---@param anchorSquare IsoGridSquare|table
---@return nil
function RCStructurePlacementPanel:applyPreset(anchorSquare)
    if not self.pendingPreset or not anchorSquare then return end
    local z = self.selectedZ
    local plan = Presets.toPlanAt(self.structureId, self.pendingPreset, anchorSquare:getX(), anchorSquare:getY(), z)

    if not plan.variant then
        plan.variant = self.variant
        plan.color = self.variant
    end

    ---@type table[]
    local rects = {}
    if type(plan.rects) == "table" and #plan.rects > 0 then
        for i = 1, #plan.rects do
            local rr = plan.rects[i]
            rects[i] = {
                x = rr.x, y = rr.y, z = rr.z,
                w = rr.w, h = rr.h,
                kind = rr.kind or "room",
            }
        end
    else
        rects[1] = { x = plan.x, y = plan.y, z = plan.z, w = plan.w, h = plan.h, kind = "room" }
    end

    self.rects = rects
    self.rect = rects[1]
    self.selectedRectIndex = nil
    self.gableAxis = plan.gableAxis
    self.walls = plan.walls
    self.cells = plan.cells
    self:rebuildWallMap()
    self:rebuildCellMap()
    self.phase = PHASE_EDIT
    self.previewMode = false
    self.pendingPreset = nil
    self.previewAnchor = nil
    self:updateButtonVisibility()
end

---@return nil
function RCStructurePlacementPanel:queuePlacement()
    local valid, reason, summary = self:validatePlan()
    if not valid and reason ~= "distance" then
        return
    end

    local plan = self:getPlan()
    if not plan then
        return
    end

    if summary and summary.footprint then
        local footprint = summary.footprint
        local px = math.floor(self.character:getX())
        local py = math.floor(self.character:getY())
        local insideFootprint = Geometry.isInteriorSquare(footprint, px, py)
        local adjacentToFootprint = Geometry.isAdjacentToFootprint(footprint, px, py)
        local walkTarget = nil

        if insideFootprint then
            walkTarget = Geometry.findNearestOutsideSquare(footprint, self.character)
            if not walkTarget then
                walkTarget = Geometry.findNearestAdjacentFootprintWalkTarget(footprint, self.character)
            end
        elseif not adjacentToFootprint then
            walkTarget = Geometry.findNearestAdjacentFootprintWalkTarget(footprint, self.character)
        end

        if walkTarget then
            ISTimedActionQueue.add(ISWalkToTimedAction:new(self.character, walkTarget))
        elseif insideFootprint or not adjacentToFootprint or not valid then
            return
        end
    elseif not valid then
        return
    end

    ISTimedActionQueue.add(RCStructurePlaceAction:new(self.character, self.structureId, self.container, plan))
    self:close()
end

---@return nil
function RCStructurePlacementPanel:updateButtonStates()
    self.zDownButton.enable = self.selectedZ > MIN_BUILD_Z
    self.zUpButton.enable = self.selectedZ < MAX_BUILD_Z
    if self.editZDownButton and self.editZUpButton then
        local activeZ = self.activeEditZ or self.selectedZ
        self.editZDownButton.enable = activeZ > MIN_BUILD_Z
        self.editZUpButton.enable = activeZ < MAX_BUILD_Z
    end

    if self.eraseButton then
        local desired = self.eraseMode == true
        if self._eraseButtonState ~= desired then
            self._eraseButtonState = desired
            if desired then
                self.eraseButton:setTitle(getText("IGUI_RCStructureFramework_StopErasing"))
                self.eraseButton:enableCancelColor()
            else
                self.eraseButton:setTitle(getText("IGUI_RCStructureFramework_Erase"))
                self.eraseButton:setBorderRGBA(0.7, 0.7, 0.7, 1)
                self.eraseButton:setBackgroundRGBA(0, 0, 0, 1)
                self.eraseButton:setBackgroundColorMouseOverRGBA(0.3, 0.3, 0.3, 1)
            end
        end
    end

    if self.phase == PHASE_SELECT then
        self.accept.enable = false

        local committed = type(self.rects) == "table" and #self.rects or 0
        if committed > 0 then
            self.accept.enable = true
        else
            local rect = self:getSelectionRect()
            if rect then
                local gableAxis = self:getGableAxisForRect(rect)
                if selectionIsValid(self.definition, rect, gableAxis) then
                    self.accept.enable = true
                end
            end
        end
        return
    end

    local valid, reason, summary = self:validatePlan()
    local canWalkToFootprint = reason == "distance" and summary ~= nil and summary.footprint ~= nil
    self.placeStructure.enable = valid == true or canWalkToFootprint
    self.rotateButton.enable = self.rect ~= nil
        and (type(self.rects) ~= "table" or #self.rects <= 1)
end

---@param rect table
---@param r number
---@param g number
---@param b number
---@param a number
---@return nil
function RCStructurePlacementPanel:renderFootprintTinted(rect, r, g, b, a)
    addAreaHighlightForPlayer(
        self.playerIndex,
        rect.x, rect.y,
        rect.x + rect.w, rect.y + rect.h,
        rect.z,
        r, g, b, a
    )
end

---@param rect table
---@return nil
function RCStructurePlacementPanel:renderFootprint(rect)
    local gableAxis = self:getGableAxisForRect(rect)
    local validSelection = selectionIsValid(self.definition, rect, gableAxis)
    if validSelection then
        self:renderFootprintTinted(rect, 0.1, 0.75, 0.25, 0.35)
    else
        self:renderFootprintTinted(rect, 0.9, 0.1, 0.1, 0.35)
    end
end

---@return nil
function RCStructurePlacementPanel:renderFootprintHighlight()
    if self.previewMode then
        local previewRect = self:getActiveRect()
        if previewRect then
            self:renderFootprint(previewRect)
        end
        return
    end

    local committed = self.rects
    if type(committed) == "table" and #committed > 0 then
        for i = 1, #committed do
            local rect = committed[i]
            if i == self.resizingRectIndex then
                self:renderFootprint(rect)
            elseif i == self.selectedRectIndex then
                self:renderFootprintTinted(rect, 0.95, 0.85, 0.2, 0.45)
            else
                self:renderFootprintTinted(rect, 0.1, 0.55, 0.25, 0.25)
            end
        end
    end

    if self.phase == PHASE_SELECT then
        local draft = self:getSelectionRect()
        if draft then
            self:renderFootprint(draft)
        end
        self:renderSelectedRectHandles()
    end
end

---@param wall table
---@return string|nil
---@nodiscard
function RCStructurePlacementPanel:resolveWallEntrySprite(wall)
    if type(wall.spriteName) == "string" and wall.spriteName ~= "" then
        return wall.spriteName
    end
    return PlacementValidation.getPieceSpriteName(self.structureId, self.variant, wall.wallType, wall.north)
end

---@param pieceZ integer
---@param baseAlpha number
---@return number  alpha multiplier in [0, 1]; 0 means skip
---@nodiscard
function RCStructurePlacementPanel:zRenderAlpha(pieceZ, baseAlpha)
    if isSingleStorey(self.definition) then return baseAlpha end
    local active = self.activeEditZ or self.selectedZ
    local diff = math.abs(pieceZ - active)
    if diff == 0 then return baseAlpha end
    if diff == 1 then return baseAlpha * 0.35 end
    return 0
end

---@return nil
function RCStructurePlacementPanel:renderCellPreviews()
    local order = PiecePresence.sortedPieceIndices(self.cells)
    for k = 1, #order do
        local cell = self.cells[order[k]]
        local hideForExistingFloor = cell.isRug ~= true
            and PiecePresence.hasRealFloorAt(cell.x, cell.y, cell.z or 0, cell.spriteName)
        if not PiecePresence.inZPass(self, cell.z) then
        elseif hideForExistingFloor then
        elseif type(cell.spriteName) == "string" and cell.spriteName ~= "" then
            local alpha = self:zRenderAlpha(cell.z, 0.55)
            if alpha > 0 then
                local sprite = getPreviewSprite(cell.spriteName)
                sprite:RenderGhostTileColor(cell.x, cell.y, cell.z, 0.2, 0.55, 0.95, alpha)
            end
        else
            local alpha = self:zRenderAlpha(cell.z, 0.25)
            if alpha > 0 then
                addAreaHighlightForPlayer(self.playerIndex, cell.x, cell.y, cell.x + 1, cell.y + 1, cell.z, 0.2, 0.55, 0.95, alpha)
            end
        end
    end
end

---@return nil
function RCStructurePlacementPanel:renderWallPreviews()
    local order = PiecePresence.sortedWallIndices(self.walls)
    for k = 1, #order do
        local wall = self.walls[order[k]]
        if PiecePresence.inZPass(self, wall.z) then
            local spriteName = self:resolveWallEntrySprite(wall)
            if spriteName and not PiecePresence.hasRealWallAt(wall.x, wall.y, wall.z or 0, wall.north == true) then
                local alpha = self:zRenderAlpha(wall.z, 0.65)
                if alpha > 0 then
                    local sprite = getPreviewSprite(spriteName)
                    sprite:RenderGhostTileColor(wall.x, wall.y, wall.z, 0.1, 0.75, 0.25, alpha)
                end
            end
        end
    end
end

---@param square IsoGridSquare|table
---@param r number
---@param g number
---@param b number
---@param a number
---@return nil
function RCStructurePlacementPanel:highlightHoveredSquare(square, r, g, b, a)
    addAreaHighlightForPlayer(
        self.playerIndex,
        square:getX(),
        square:getY(),
        square:getX() + 1,
        square:getY() + 1,
        floorValue(square:getZ()),
        r, g, b, a
    )
end

---@return nil
function RCStructurePlacementPanel:renderHoveredErasePreview()
    local mouseX = getMouseX()
    local mouseY = getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end

    local square = self:pickSquare(mouseX, mouseY)
    if not square then return end
    self:highlightHoveredSquare(square, 0.95, 0.2, 0.2, 0.55)
end

---@return nil
function RCStructurePlacementPanel:renderHoveredWallPreview()
    local mouseX = getMouseX()
    local mouseY = getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end

    local square = self:pickSquare(mouseX, mouseY)
    local wall = self:getDraftWallForSquare(square)
    if not square or not wall then
        return
    end

    self:highlightHoveredSquare(square, 0.95, 0.85, 0.2, 0.55)

    local spriteName = self:resolveWallEntrySprite(wall)
    if spriteName then
        local sprite = getPreviewSprite(spriteName)
        sprite:RenderGhostTileColor(wall.x, wall.y, wall.z, 0.95, 0.85, 0.2, 0.75)
    end
end

---@return nil
function RCStructurePlacementPanel:renderHoveredCellPreview()
    if self.editMode ~= EDIT_CELLS then
        return
    end

    local mouseX = getMouseX()
    local mouseY = getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end

    local square = self:pickSquare(mouseX, mouseY)
    local cell = self:getDraftCellForSquare(square)
    if not cell then
        return
    end

    self:highlightHoveredSquare(square, 0.95, 0.85, 0.2, 0.55)

    if type(cell.spriteName) == "string" and cell.spriteName ~= "" then
        local sprite = getPreviewSprite(cell.spriteName)
        sprite:RenderGhostTileColor(cell.x, cell.y, cell.z, 0.95, 0.85, 0.2, 0.65)
    end
end

---@return nil
function RCStructurePlacementPanel:renderHoveredRoofPreview()
    local active = self.activePiece
    if not active or active.category ~= CATEGORY_ROOF then return end
    if type(active.spriteName) ~= "string" or active.spriteName == "" then return end

    local mouseX = getMouseX()
    local mouseY = getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end

    local square = self:pickSquare(mouseX, mouseY)
    if not square then return end

    self:highlightHoveredSquare(square, 0.6, 0.4, 0.95, 0.45)

    local sprite = getPreviewSprite(active.spriteName)
    sprite:RenderGhostTileColor(square:getX(), square:getY(), floorValue(square:getZ()), 0.6, 0.4, 0.95, 0.7)
end

---@return nil
function RCStructurePlacementPanel:renderRoofPreviews()
    if not self.rect then
        return
    end

    local parts = Builder.getRoofPreview(self.structureId, self.rect, self.variant, self.gableAxis)
    local order = PiecePresence.sortedPieceIndices(parts)
    for k = 1, #order do
        local part = parts[order[k]]
        if PiecePresence.inZPass(self, part.z)
            and not PiecePresence.hasObjectWithSpriteAt(part.x, part.y, part.z, part.spriteName) then
            local sprite = getPreviewSprite(part.spriteName)
            sprite:RenderGhostTileColor(part.x, part.y, part.z, 0.2, 0.55, 0.95, 0.25)
        end
    end
end

---@return nil
function RCStructurePlacementPanel:renderWorldPreview()
    if self.previewMode then
        self:renderPresetPreview()
        return
    end
    if self.phase == PHASE_EDIT then
        local activeZ = self.activeEditZ or self.selectedZ or 0
        self._zPassActiveZ = activeZ

        self._zPassActiveOnly = false
        self:renderCellPreviews()
        self:renderWallPreviews()
        self:renderRoofPreviews()

        self._zPassActiveOnly = true
        self:renderCellPreviews()
        self:renderWallPreviews()
        self:renderRoofPreviews()

        self._zPassActiveZ = nil
        self._zPassActiveOnly = nil

        if self.eraseMode then
            self:renderHoveredErasePreview()
        elseif self.activePiece and self.activePiece.category == CATEGORY_ROOF then
            self:renderHoveredRoofPreview()
        elseif self.editMode == EDIT_CELLS then
            self:renderHoveredCellPreview()
        else
            self:renderHoveredWallPreview()
        end

        self:renderPipetteHoverPreview()
    end
end

---@param y number
---@param text string
---@return number
function RCStructurePlacementPanel:drawInfoLine(y, text)
    self:drawText(text, UI_BORDER_SPACING, y, 1, 1, 1, 1, FONT_BODY)
    return y + FONT_HGT_BODY + 4
end

---@param y number
---@param text string
---@return number
function RCStructurePlacementPanel:drawWarningLine(y, text)
    local maxWidth = self.width - (UI_BORDER_SPACING * 2)
    local textManager = getTextManager()
    local words = {}
    for word in string.gmatch(text, "%S+") do
        words[#words + 1] = word
    end

    local line = ""
    for i = 1, #words do
        local candidate = words[i]
        if line ~= "" then
            candidate = line .. " " .. words[i]
        end
        if textManager:MeasureStringX(FONT_BODY, candidate) <= maxWidth then
            line = candidate
        else
            if line ~= "" then
                self:drawText(line, UI_BORDER_SPACING, y, 1, 0.35, 0.25, 1, FONT_BODY)
                y = y + FONT_HGT_BODY + 2
            end
            line = words[i]
        end
    end

    if line ~= "" then
        self:drawText(line, UI_BORDER_SPACING, y, 1, 0.35, 0.25, 1, FONT_BODY)
        y = y + FONT_HGT_BODY + 2
    end

    return y + 2
end

---@return string
function RCStructurePlacementPanel:getBuildLevelText()
    return getText("IGUI_RCStructureFramework_BuildLevel", formatBuildZ(self.selectedZ))
end

---@return nil
function RCStructurePlacementPanel:drawBuildLevelControl()
    if not isZControlEnabled(self.definition) then
        return
    end
    local label = self:getBuildLevelText()
    local labelY = self.zControlY + math.floor((BUTTON_HGT - FONT_HGT_BODY) / 2)
    self:drawRect(
        self.zControlLabelX,
        self.zControlY,
        self.zControlLabelWidth,
        BUTTON_HGT,
        0.28,
        0.12,
        0.12,
        0.12
    )
    self:drawRectBorder(
        self.zControlLabelX,
        self.zControlY,
        self.zControlLabelWidth,
        BUTTON_HGT,
        0.55,
        0.45,
        0.45,
        0.45
    )
    self:drawTextCentre(
        label,
        self.zControlLabelX + math.floor(self.zControlLabelWidth / 2),
        labelY,
        1,
        1,
        1,
        1,
        FONT_BODY
    )

    if not isSingleStorey(self.definition) then
        local editLabel = getText("IGUI_RCStructureFramework_EditLevel", formatBuildZ(self.activeEditZ or self.selectedZ))
        local editY = self.editZControlY + math.floor((BUTTON_HGT - FONT_HGT_BODY) / 2)
        self:drawRect(self.zControlLabelX, self.editZControlY, self.zControlLabelWidth, BUTTON_HGT, 0.28, 0.12, 0.12, 0.12)
        self:drawRectBorder(self.zControlLabelX, self.editZControlY, self.zControlLabelWidth, BUTTON_HGT, 0.55, 0.45, 0.45, 0.45)
        self:drawTextCentre(editLabel, self.zControlLabelX + math.floor(self.zControlLabelWidth / 2), editY, 1, 1, 1, 1, FONT_BODY)
    end
end

---@param y number
---@return nil
function RCStructurePlacementPanel:drawSelectionInfo(y)
    if self.footprintEditMode == true then
        y = self:drawWarningLine(y, getText("IGUI_RCStructureFramework_FootprintEdit_Banner"))
    end

    if isZControlEnabled(self.definition) then
        y = self:drawInfoLine(y, self:getBuildLevelText())
    end

    local rect = self:getSelectionRect()
    if not rect then
        self:drawInfoLine(y, getText("IGUI_RCStructureFramework_DragFootprint"))
        return
    end

    y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_Size", tostring(rect.w), tostring(rect.h)))
    local gableAxis = self:getGableAxisForRect(rect)
    local validSelection = selectionIsValid(self.definition, rect, gableAxis)
    if not validSelection then
        self:drawWarningLine(y, getDefText(self.definition, "invalidSizeTooltipKey", "Tooltip_RCStructureFramework_InvalidSize"))
        return
    end

    local roofPieces = Builder.getRoofPieceCount(self.structureId, rect, gableAxis)
    local perimeterPieces = (rect.w * 2) + (rect.h * 2)
    y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_PerimeterPieces", tostring(perimeterPieces)))
    y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_RoofPieces", tostring(roofPieces)))
    self:drawInfoLine(y, getText("IGUI_RCStructureFramework_TotalPieces", tostring(perimeterPieces + roofPieces)))
end

---@param y number
---@return nil
function RCStructurePlacementPanel:drawEditInfo(y)
    local summary = self:getSummary()
    if not summary then
        return
    end

    if isZControlEnabled(self.definition) then
        y = self:drawInfoLine(y, self:getBuildLevelText())
    end
    y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_Size", tostring(self.rect.w), tostring(self.rect.h)))
    y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_ContainerPieces", tostring(MaterialContainers.getMaterialCount(self.structureId, self.container))))
    if summary.wallCount then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_WallPieces", tostring(summary.wallCount)))
    end
    if summary.internalWallCount then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_InternalWallPieces", tostring(summary.internalWallCount)))
    end
    if summary.roofReserve then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_RoofPieces", tostring(summary.roofReserve)))
    end
    if summary.totalRequired then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_TotalPieces", tostring(summary.totalRequired)))
    end

    if self.gableAxis == GABLE_AXIS_NORTH_SOUTH then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_GableNorthSouth"))
    elseif self.gableAxis == GABLE_AXIS_WEST_EAST then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_GableWestEast"))
    end

    if self.editMode == EDIT_CELLS then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_FootprintMode"))
    elseif self.wallNorth then
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_WallNorth"))
    else
        y = self:drawInfoLine(y, getText("IGUI_RCStructureFramework_WallWest"))
    end

    if summary.completePerimeter == false then
        self:drawWarningLine(y, getDefText(self.definition, "incompletePerimeterTooltipKey", "Tooltip_RCStructureFramework_IncompletePerimeter"))
        return
    end

    local needed = summary.totalRequired
    local have = MaterialContainers.getMaterialCount(self.structureId, self.container)
    if needed and needed > have then
        self:drawWarningLine(y, getText("IGUI_RCStructureFramework_NotEnoughPieces", tostring(needed), tostring(have)))
        return
    end

    local valid, reason = self:validatePlan()
    if not valid and reason ~= "distance" then
        self:drawWarningLine(y, getDefText(self.definition, "invalidPlacementTooltipKey", "Tooltip_RCStructureFramework_InvalidPlacement"))
    end
end

---@return nil
function RCStructurePlacementPanel:updatePreviewAnchor()
    if not self.previewMode then return end
    local mouseX, mouseY = getMouseX(), getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end
    local square = self:pickSquare(mouseX, mouseY)
    if square then
        self.previewAnchor = {
            x = square:getX(),
            y = square:getY(),
            z = self.selectedZ,
        }
    end
end

---@return nil
function RCStructurePlacementPanel:renderPresetPreview()
    if not self.previewMode or not self.pendingPreset or not self.previewAnchor then
        return
    end
    local anchor = self.previewAnchor
    local preset = self.pendingPreset
    local variant = preset.variant
    if not variant then
        variant = self.variant
    end

    if preset.cells then
        for i = 1, #preset.cells do
            local c = preset.cells[i]
            local cx = anchor.x
            local cy = anchor.y
            if type(c.dx) == "number" then
                cx = cx + c.dx
            end
            if type(c.dy) == "number" then
                cy = cy + c.dy
            end
            addAreaHighlightForPlayer(self.playerIndex, cx, cy, cx + 1, cy + 1, anchor.z, 0.2, 0.55, 0.95, 0.25)
        end
    end

    if preset.walls then
        for i = 1, #preset.walls do
            local pw = preset.walls[i]
            local wx = anchor.x
            local wy = anchor.y
            if type(pw.dx) == "number" then
                wx = wx + pw.dx
            end
            if type(pw.dy) == "number" then
                wy = wy + pw.dy
            end
            local north = pw.north == true
            local spriteName = PlacementValidation.getPieceSpriteName(self.structureId, variant, pw.wallType, north)
            if spriteName and not PiecePresence.hasRealWallAt(wx, wy, anchor.z, north) then
                local sprite = getPreviewSprite(spriteName)
                sprite:RenderGhostTileColor(wx, wy, anchor.z, 0.95, 0.85, 0.2, 0.6)
            end
        end
    end

    local rect = { x = anchor.x, y = anchor.y, z = anchor.z, w = preset.w, h = preset.h }
    local parts = Builder.getRoofPreview(self.structureId, rect, variant, preset.gableAxis)
    for i = 1, #parts do
        local part = parts[i]
        if not PiecePresence.hasObjectWithSpriteAt(part.x, part.y, part.z, part.spriteName) then
            local sprite = getPreviewSprite(part.spriteName)
            sprite:RenderGhostTileColor(part.x, part.y, part.z, 0.2, 0.55, 0.95, 0.25)
        end
    end
end

---@return nil
function RCStructurePlacementPanel:prerender()
    self:updatePreviewAnchor()
    self:updateButtonStates()
    self:renderFootprintHighlight()

    local titleKey = self.phase == PHASE_EDIT and "editTitleKey" or "selectTitleKey"
    local defaultKey = self.phase == PHASE_EDIT
        and "IGUI_RCStructureFramework_EditStructure"
        or "IGUI_RCStructureFramework_SelectFootprint"
    self:setTitle(getDefText(self.definition, titleKey, defaultKey))

    ISCollapsableWindowJoypad.prerender(self)
    self:drawBuildLevelControl()

    local stripY = self:titleBarHeight() + 4
    self:drawStatusStrip(stripY)

    local y = stripY + FONT_HGT_BODY + 10

    if self.phase == PHASE_SELECT then
        self:drawSelectionInfo(y)
    else
        self:drawEditInfo(y)
    end
end

---@param y number
---@return nil
function RCStructurePlacementPanel:drawStatusStrip(y)
    local stripHgt = FONT_HGT_BODY + 6
    local x = UI_BORDER_SPACING
    local w = self.width - UI_BORDER_SPACING * 2
    self:drawRect(x, y, w, stripHgt, 0.25, 0.12, 0.16, 0.20)
    self:drawRectBorder(x, y, w, stripHgt, 0.5, 0.35, 0.35, 0.35)

    local parts = self:getStatusStripParts()
    if #parts == 0 then return end

    local line = parts[1]
    for i = 2, #parts do
        line = line .. "  ·  " .. parts[i]
    end
    self:drawTextCentre(line, math.floor(self.width / 2), y + 3, 0.95, 0.95, 0.95, 1, FONT_BODY)
end

---@return string[]
---@nodiscard
function RCStructurePlacementPanel:getStatusStripParts()
    local parts = {}

    if self.eraseMode == true then
        parts[#parts + 1] = getText("IGUI_RCStructureFramework_StopErasing")
    elseif self.footprintEditMode == true then
        parts[#parts + 1] = getText("IGUI_RCStructureFramework_EditFootprint")
    elseif self.activePiece then
        local ap = self.activePiece
        if type(ap.slotKind) == "string" and ap.slotKind ~= "" then
            parts[#parts + 1] = ap.slotKind
        elseif type(ap.pieceType) == "string" and ap.pieceType ~= "" then
            parts[#parts + 1] = ap.pieceType
        elseif type(ap.category) == "string" and ap.category ~= "" then
            parts[#parts + 1] = ap.category
        end
    end

    if isZControlEnabled(self.definition) then
        local z = self.activeEditZ or self.selectedZ or 0
        parts[#parts + 1] = "Z " .. formatBuildZ(z)
    end

    if self.rect then
        parts[#parts + 1] = tostring(self.rect.w) .. " x " .. tostring(self.rect.h)
    end

    return parts
end

---@param square IsoGridSquare|table|nil
---@return table[]  array of `{ kind, piece, index }` entries
---@nodiscard
function RCStructurePlacementPanel:getPipetteCandidatesAt(square)
    local candidates = {}
    if not square then return candidates end

    local x = square:getX()
    local y = square:getY()
    local z = floorValue(square:getZ())

    for i = 1, #self.walls do
        local wall = self.walls[i]
        if wall.x == x and wall.y == y and (wall.z or 0) == z then
            candidates[#candidates + 1] = { kind = "wall", piece = wall, index = i }
        end
    end

    local key = cellKey(x, y, z)
    local cellIndex = self.cellMap[key]
    if cellIndex then
        candidates[#candidates + 1] = { kind = "cell", piece = self.cells[cellIndex], index = cellIndex }
    end

    local extras = self:getExtraPipetteCandidatesAt(square, x, y, z)
    if type(extras) == "table" then
        for i = 1, #extras do
            candidates[#candidates + 1] = extras[i]
        end
    end

    return candidates
end

---@param square IsoGridSquare|table
---@param x integer
---@param y integer
---@param z integer
---@return table[]|nil
---@nodiscard
function RCStructurePlacementPanel:getExtraPipetteCandidatesAt(square, x, y, z)
    return nil
end

---@param pick table  `{ kind, piece, index }`
---@return string
---@nodiscard
function RCStructurePlacementPanel:pipetteLabelFor(pick)
    local piece = pick.piece
    if pick.kind == "wall" then
        if type(piece.slotKind) == "string" and piece.slotKind ~= "" then
            return piece.slotKind
        end
        if type(piece.wallType) == "string" and piece.wallType ~= "" then
            return piece.wallType
        end
        return "wall"
    end
    if pick.kind == "cell" then
        if type(piece.spriteName) == "string" and piece.spriteName ~= "" then
            return piece.spriteName
        end
        return "floor"
    end
    if type(piece.spriteName) == "string" and piece.spriteName ~= "" then
        return piece.spriteName
    end
    return pick.kind or "?"
end

---@param pick table  `{ kind, piece, index }`
---@return nil
function RCStructurePlacementPanel:applyPipettePick(pick)
    self.eraseMode = false
    local kind = pick.kind
    local piece = pick.piece

    if kind == "wall" then
        self.editMode = EDIT_WALLS
        self.selectedWallType = piece.wallType
        self.activePiece = {
            category = CATEGORY_WALL,
            pieceType = piece.wallType,
            slotKind = piece.slotKind,
            spriteName = piece.spriteName,
            northVariant = piece.spriteName,
            westVariant = piece.spriteName,
            openSpriteName = piece.openSpriteName,
        }
        self.wallNorth = piece.north == true
    elseif kind == "cell" then
        self.editMode = EDIT_CELLS
        self.activePiece = {
            category = CATEGORY_FLOOR,
            spriteName = piece.spriteName,
            isRug = piece.isRug == true and true or nil,
        }
    else
        return
    end

    self:updateButtonVisibility()
    self:announcePipettePick(pick)
end

---@param pick table
---@return nil
function RCStructurePlacementPanel:announcePipettePick(pick)
    if not self.character then return end
    local label = self:pipetteLabelFor(pick) or "?"
    HaloTextHelper.addGoodText(self.character,
        getText("IGUI_RCStructureFramework_Pipette_Picked", label))
end

---@param square IsoGridSquare|table
---@return nil
function RCStructurePlacementPanel:pipetteAtSquare(square)
    if not square then return end

    local sx = square:getX()
    local sy = square:getY()
    local sz = floorValue(square:getZ())
    local squareKey = Geometry.squareKey(sx, sy, sz)

    if self._pipetteHoverSquareKey ~= squareKey then
        self._pipetteHoverSquareKey = squareKey
        self._pipetteCycleIndex = 1
    end

    local candidates = self:getPipetteCandidatesAt(square)
    if #candidates == 0 then
        if self.character then
            HaloTextHelper.addBadText(self.character,
                getText("IGUI_RCStructureFramework_Pipette_NothingToPick"))
        end
        return
    end

    local idx = self._pipetteCycleIndex
    if type(idx) ~= "number" or idx < 1 or idx > #candidates then
        idx = 1
    end
    local target = candidates[idx]
    self._pipetteCycleIndex = (idx % #candidates) + 1

    self:applyPipettePick(target)
end

---@return nil
function RCStructurePlacementPanel:update()
    local pressed = isMouseButtonDown(2)
    local wasPressed = self._middleMouseDown == true
    self._middleMouseDown = pressed

    if not pressed or wasPressed then
        return
    end
    if self.phase ~= PHASE_EDIT then return end
    if self.previewMode then return end

    local mouseX = getMouseX()
    local mouseY = getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end

    local square = self:pickSquare(mouseX, mouseY)
    self:pipetteAtSquare(square)
end

---@return nil
function RCStructurePlacementPanel:renderPipetteHoverPreview()
    if self.phase ~= PHASE_EDIT then return end
    if self.eraseMode then return end
    if self.previewMode then return end

    local mouseX = getMouseX()
    local mouseY = getMouseY()
    if isInsidePanel(self, mouseX - self:getAbsoluteX(), mouseY - self:getAbsoluteY()) then
        return
    end

    local square = self:pickSquare(mouseX, mouseY)
    if not square then return end

    local candidates = self:getPipetteCandidatesAt(square)
    if #candidates == 0 then return end

    self:highlightHoveredSquare(square, 0.2, 0.85, 0.95, 0.25)
end

---@param square IsoGridSquare|table
---@return nil
function RCStructurePlacementPanel:eraseAtSquare(square)
    if not square then return end
    local x = square:getX()
    local y = square:getY()
    local z = floorValue(square:getZ())

    if self.editMode == EDIT_CELLS then
        local key = cellKey(x, y, z)
        if self.cellMap[key] then
            self:removeCellByKey(key)
        end
        return
    end

    local _, key = self:getExistingWallForSquare(square)
    if key then
        self:removeWallByKey(key)
    end
end

---@param x number
---@param y number
---@return boolean|nil
function RCStructurePlacementPanel:onMouseDownOutside(x, y)
    if isInsidePanel(self, x, y) then
        return true
    end

    local square = self:pickSquare(x + self:getAbsoluteX(), y + self:getAbsoluteY())
    if not square then
        return
    end

    if self.previewMode then
        self:applyPreset(square)
        ISWorldObjectContextMenu.disableWorldMenu = true
        return
    end

    if self.phase == PHASE_SELECT then
        local sx = square:getX()
        local sy = square:getY()
        local sz = floorValue(square:getZ())

        local handle = self:getHandleAtSquare(self.selectedRectIndex, sx, sy, sz)
        if handle then
            self:beginResize(self.selectedRectIndex, handle)
            ISWorldObjectContextMenu.disableWorldMenu = true
            return
        end

        local existingIndex = self:findRectIndexAt(sx, sy, sz)
        if existingIndex then
            self.selectedRectIndex = existingIndex
            ISWorldObjectContextMenu.disableWorldMenu = true
            return
        end

        self.selectedRectIndex = nil
        self.selecting = true
        self.startingX = sx
        self.startingY = sy
        self.endX = sx
        self.endY = sy
        ISWorldObjectContextMenu.disableWorldMenu = true
        return
    end

    if self.eraseMode then
        self.erasing = true
        self:eraseAtSquare(square)
        ISWorldObjectContextMenu.disableWorldMenu = true
        return
    end

    if self.editMode == EDIT_CELLS then
        self.drawingCell = true
        self:addDraftCellForSquare(square)
    else
        self.drawingWall = true
        self:addDraftWallForSquare(square)
    end
    ISWorldObjectContextMenu.disableWorldMenu = true
end

---@param dx number
---@param dy number
---@return nil
function RCStructurePlacementPanel:onMouseMoveOutside(dx, dy)
    ISCollapsableWindowJoypad.onMouseMoveOutside(self, dx, dy)

    local square = self:pickSquare(getMouseX(), getMouseY())
    if not square then
        return
    end

    if self.resizingHandle then
        self:updateResize(square)
        return
    end

    if self.phase == PHASE_SELECT and self.selecting then
        self.endX = square:getX()
        self.endY = square:getY()
    elseif self.phase == PHASE_EDIT and self.erasing then
        self:eraseAtSquare(square)
    elseif self.phase == PHASE_EDIT and self.drawingCell then
        self:addDraftCellForSquare(square)
    elseif self.phase == PHASE_EDIT and self.drawingWall then
        self:addDraftWallForSquare(square)
    end
end

---@param x number
---@param y number
---@return nil
function RCStructurePlacementPanel:onMouseUpOutside(x, y)
    ISCollapsableWindowJoypad.onMouseUpOutside(self, x, y)

    if self.resizingHandle then
        self:endResize()
        return
    end

    local wasSelecting = self.selecting
    self.selecting = false
    self.drawingWall = false
    self.drawingCell = false
    self.erasing = false

    if wasSelecting and self.phase == PHASE_SELECT and not self.previewMode then
        self:commitDraftRect()
        self.startingX = nil
        self.startingY = nil
        self.endX = nil
        self.endY = nil
    end
end

---@param index integer
---@return nil
function RCStructurePlacementPanel:removeRectByIndex(index)
    if type(self.rects) ~= "table" then
        return
    end
    if index < 1 or index > #self.rects then
        return
    end
    table.remove(self.rects, index)
    if self.selectedRectIndex == index then
        self.selectedRectIndex = nil
    elseif self.selectedRectIndex and self.selectedRectIndex > index then
        self.selectedRectIndex = self.selectedRectIndex - 1
    end
    if #self.rects > 0 then
        self.rect = self.rects[#self.rects]
    else
        self.rect = nil
        self.gableAxis = nil
    end
end

---@param x number
---@param y number
---@return boolean|nil
function RCStructurePlacementPanel:onRightMouseDownOutside(x, y)
    if isInsidePanel(self, x, y) then
        return true
    end

    if self.previewMode then
        self:cancelPresetPreview()
        return
    end

    if self.phase == PHASE_SELECT then
        local square = self:pickSquare(x + self:getAbsoluteX(), y + self:getAbsoluteY())
        if square then
            local sx = square:getX()
            local sy = square:getY()
            local sz = floorValue(square:getZ())
            local hitIndex = self:findRectIndexAt(sx, sy, sz)
            if hitIndex then
                self.selectedRectIndex = hitIndex
                local context = ISContextMenu.get(self.playerIndex, getMouseX(), getMouseY())
                context:addOption(getText("IGUI_RCStructureFramework_DeleteRect"), self, RCStructurePlacementPanel.removeRectByIndex, hitIndex)
                return
            end
        end

        self.selecting = false
        self.startingX = nil
        self.startingY = nil
        self.endX = nil
        self.endY = nil
        self.selectedRectIndex = nil
        return
    end

    local square = self:pickSquare(x + self:getAbsoluteX(), y + self:getAbsoluteY())
    if self.editMode == EDIT_CELLS and square then
        local key = cellKey(square:getX(), square:getY(), floorValue(square:getZ()))
        if self.cellMap[key] then
            local context = ISContextMenu.get(self.playerIndex, getMouseX(), getMouseY())
            context:addOption(getText("ContextMenu_RCStructureFramework_DeleteDraftCell"), self, RCStructurePlacementPanel.removeCellByKey, key)
        end
        return
    end

    local wall, key = self:getExistingWallForSquare(square)
    if not wall or not key then
        return
    end

    local context = ISContextMenu.get(self.playerIndex, getMouseX(), getMouseY())
    context:addOption(getText("ContextMenu_RCStructureFramework_DeleteDraftWall"), self, RCStructurePlacementPanel.removeWallByKey, key)
end

---@param key integer
---@return nil
function RCStructurePlacementPanel:onKeyPressed(key)
    if self.phase ~= PHASE_EDIT then
        return
    end

    if getCore():isKey("Rotate building", key) then
        self:rotateWall()
    end
end

---@param joypadData table
---@return nil
function RCStructurePlacementPanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForB(self.cancel)
    if self.phase == PHASE_SELECT then
        self:setISButtonForA(self.accept)
    else
        self:setISButtonForA(self.placeStructure)
    end
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param playerIndex number
---@param character IsoPlayer
---@param structureId string
---@param container InventoryItem
---@return RCStructurePlacementPanel
function RCStructurePlacementPanel:new(x, y, width, height, playerIndex, character, structureId, container)
    local o = ISCollapsableWindowJoypad.new(self, x, y, width, height)
    local definition = Registry.requireStructure(structureId)
    local pieceTypes = getPieceTypes(definition)
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.82 }
    o.resizable = false
    o.width = width
    o.height = height
    o.playerIndex = playerIndex
    o.character = character
    o.structureId = structureId
    o.definition = definition
    o.container = container
    o.variant = MaterialContainers.getVariant(structureId, container)
    o.selectedZ = clampBuildZ(character:getZ())
    o.phase = PHASE_SELECT
    o.editMode = EDIT_WALLS
    o.selectedWallType = pieceTypes[1].id
    o.wallNorth = true
    o.walls = {}
    o.wallMap = {}
    o.cells = {}
    o.cellMap = {}
    ---@type table[]  committed rectangles in PHASE_SELECT (sticky multi-rect)
    o.rects = {}
    ---@type integer|nil  index into self.rects highlighted for delete/edit
    o.selectedRectIndex = nil
    o.selecting = false
    o.drawingWall = false
    o.drawingCell = false
    o.erasing = false
    o.eraseMode = false
    o.activePiece = nil
    o.activeEditZ = o.selectedZ
    o.previewMode = false
    o.pendingPreset = nil
    o.previewAnchor = nil
    o.footprintEditMode = false
    ---@type integer|nil  index into self.rects of the rect being resized
    o.resizingRectIndex = nil
    ---@type string|nil   one of "NW" / "N" / "NE" / "E" / "SE" / "S" / "SW" / "W"
    o.resizingHandle = nil
    ---@type table|nil    snapshot of the rect before resize for revert-on-invalid
    o.resizingOrigRect = nil
    return o
end

---@param key integer
---@return nil
function RCStructurePlacementUI.onKeyPressed(key)
    local panel = RCStructurePlacementUI.instance
    if panel then
        panel:onKeyPressed(key)
    end
end

---@return nil
function RCStructurePlacementUI.renderWorldPreview()
    local panel = RCStructurePlacementUI.instance
    if panel and panel:getIsVisible() then
        panel:renderWorldPreview()
    end
end

---@param structureId string
---@param playerIndex number
---@param character IsoPlayer
---@param container InventoryItem
---@return nil
function RCStructurePlacementUI.open(structureId, playerIndex, character, container)
    if RCStructurePlacementUI.instance then
        RCStructurePlacementUI.instance:close()
    end

    local width = 440
    local height = 430 + (BUTTON_HGT * 3) + (UI_BORDER_SPACING * 3) + 30 + 24
    local x = getPlayerScreenLeft(playerIndex) + UI_BORDER_SPACING
    local y = getPlayerScreenTop(playerIndex) + UI_BORDER_SPACING
    local panel = RCStructurePlacementPanel:new(x, y, width, height, playerIndex, character, structureId, container)
    panel:initialise()
    panel:addToUIManager()
    RCStructurePlacementUI.instance = panel
end

Events.OnKeyPressed.Add(RCStructurePlacementUI.onKeyPressed)
Events.RenderOpaqueObjectsInWorld.Add(RCStructurePlacementUI.renderWorldPreview)

return RCStructurePlacementUI
