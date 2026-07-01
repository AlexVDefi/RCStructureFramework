# Disassemble & refund

The framework can tear a structure back down and refund its materials, either through a
ready-made UI or programmatically.

## The disassembly UI

Open it from a context menu on a built piece:

```lua
require("RCStructureFramework/DisassemblyUI")

local function onFillWorldContext(playerIndex, context, worldObjects)
    local player = getSpecificPlayer(playerIndex)
    local obj = worldObjects[1]
    if obj and isMyShedPiece(obj) then
        context:addOption("Dismantle Shed", nil, function()
            RCStructureDisassemblyUI.open("MyMod_Shed", obj, player)
        end)
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldContext)
```

The UI runs the same server-authoritative timed action the build uses, removes the pieces,
and refunds materials.

## Per-piece refunds

The cleanest refund model: set `refundViaMaterialSource = true` on the def. Every piece the
builder places is stamped with an `RCStructureFramework` modData tag recording its material
requirement; on disassembly the framework reads that tag and refunds each piece through the
material source. No bookkeeping on your side.

```lua
RCSF.Registry.registerStructure({
    id = "MyMod_Shed",
    refundViaMaterialSource = true,
    getPieceMaterialRequirement = function(piece)
        return { fullType = "Base.Plank", count = piece.slotKind == "door" and 4 or 2 }
    end,
    -- …
})
```

## Custom teardown logic

For anything bespoke, implement the disassembly callbacks
([structure-definition reference](../reference/structure-definition.md#disassembly)):

- `validateDisassembly(character, object)` → `(ok, reasonKey?, data?)` - gate it, and produce
  the `data` used below.
- `getRemovableObjects(data)` → `IsoObject[]` - which objects to remove.
- `beforeDisassemble(objects, data, character, materialSource)` → return `false` to abort.
- `afterDisassemble(objects, data, character, materialSource, removed)` - bulk refund/cleanup.

## Disassemble programmatically

```lua
local outcome = RCSF.Builder.disassembleFromPlan("MyMod_Shed", player, {
    data           = data,           -- from validateDisassembly
    materialSource = source,
})
-- outcome = { success, removed, reason? }
```

```{important}
Disassembly mutates the world and grants items - it must run **server-side** in multiplayer,
and a refund must be gated on the piece **actually being removed** this call, not on a
precomputed amount. The framework's action handles this; if you call
`disassembleFromPlan` yourself, do it on the server and re-resolve objects from coordinates.
See [Multiplayer](multiplayer.md) and
[Authority & rooms](../concepts/authority-and-rooms.md).
```

Disassembly fires `OnRCSFStructureDisassembled` - see [React to events](events.md).
