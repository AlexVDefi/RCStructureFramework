require("RCStructureFramework/PlacementUI")
local ExampleShed = require("RCSFExampleShed/ExampleShed")

---@param playerIndex integer
---@param context ISContextMenu
---@param items table
---@return nil
local function onFillInventoryContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    context:addOption(getText("IGUI_RCSFExampleShed_Build"), nil, function()
        RCStructurePlacementUI.open(ExampleShed.STRUCTURE_ID, playerIndex, player, nil)
    end)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryContextMenu)
