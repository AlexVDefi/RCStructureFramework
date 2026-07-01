local RCSF = require("RCStructureFramework")

---@class RCSFExampleShed
local ExampleShed = {}

ExampleShed.STRUCTURE_ID = "RCSFExampleShed"

RCSF.disable("spritePatcher")
RCSF.disable("plannedConstructions")
RCSF.disable("materialContainers")

RCSF.Registry.registerStructure({
    id                = ExampleShed.STRUCTURE_ID,
    roomName          = "RCSFExampleShed",
    useGenericBuilder = true,
    materialSource    = "raw",
    variants          = { default = true },
    editor            = { allowCells = true, pieceTypes = { "wall", "floor" } },
    validation        = { useDefaults = { "noEmptyPlan", "noOverlap", "slotKindCompatible" } },
    selectTitleKey    = "IGUI_RCSFExampleShed_Select",
    editTitleKey      = "IGUI_RCSFExampleShed_Edit",
    placeLabelKey     = "IGUI_RCSFExampleShed_Place",
})

RCSF.Registry.registerPieces(ExampleShed.STRUCTURE_ID, {
    {
        spriteName = "walls_exterior_wooden_01_0",
        category = "wall", pieceType = "wall", categoryGroup = "wall",
        labelKey = "IGUI_RCSFExampleShed_Wall",
        materialRequirement = { fullType = "Base.Plank", count = 2 },
    },
    {
        spriteName = "floors_exterior_natural_01_0",
        category = "floor", categoryGroup = "floor",
        labelKey = "IGUI_RCSFExampleShed_Floor",
        materialRequirement = { fullType = "Base.Plank", count = 1 },
    },
})

return ExampleShed
