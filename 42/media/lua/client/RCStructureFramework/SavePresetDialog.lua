require("ISUI/ISTextBox")
local Presets = require("RCStructureFramework/Presets")

RCStructureSavePresetDialog = RCStructureSavePresetDialog or {}

---@param panel table
---@return nil
function RCStructureSavePresetDialog.openFor(panel)
    if not panel or not panel.getPlan then return end
    local plan = panel:getPlan()
    if not plan then return end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w, h = 320, 150
    local defaultName = string.format("%dx%d preset", plan.w, plan.h)

    local box = ISTextBox:new(
        (sw - w) / 2,
        (sh - h) / 2,
        w,
        h,
        getText("IGUI_RCStructureFramework_SavePresetPrompt"),
        defaultName,
        nil,
        RCStructureSavePresetDialog.onResult,
        panel.playerIndex
    )
    box.panel = panel
    box.defaultName = defaultName
    box:initialise()
    box:addToUIManager()
end

---@param target any
---@param button table
---@return nil
function RCStructureSavePresetDialog.onResult(target, button)
    if button.internal ~= "OK" then return end
    local box = button.parent
    if not box or not box.panel then return end

    local panel = box.panel
    local name = ""
    if box.entry then
        name = box.entry:getText()
    end
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        name = box.defaultName or "preset"
    end

    local plan = panel:getPlan()
    if not plan then return end

    local preset = Presets.toRelative(panel.structureId, plan)
    preset.name = name
    Presets.add(panel.structureId, preset)
end

return RCStructureSavePresetDialog
