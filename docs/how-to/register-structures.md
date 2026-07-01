# Register structures and pieces

Everything starts with two registrations, both in `media/lua/shared/` (so they run on client
**and** server): the **structure** (one def) and its **pieces** (the catalog the player
paints from).

## Register the structure

```lua
local RCSF = require("RCStructureFramework")

RCSF.Registry.registerStructure({
    id                = "MyMod_Shed",      -- the only required field
    roomName          = "MyModShed",       -- create an IsoRoom (omit for no room)
    useGenericBuilder = true,              -- use the built-in per-piece builder
    materialSource    = "raw",             -- consume from inventory
    variants          = { default = true },
    editor            = { allowCells = true, pieceTypes = { "wall", "floor" } },
    validation        = { useDefaults = { "noEmptyPlan", "noOverlap", "slotKindCompatible" } },
})
```

Only `id` is required; every other field has a sensible default. The full field list - build
hooks, custom validation, disassembly, sprites, UI flags - is in
[Reference → Structure definition](../reference/structure-definition.md).

```{tip}
Prefer [`RCSF.defineStructure`](introspection.md) if you want validation + an inline `pieces`
array + a default variant in a single call.
```

### `variants`

A structure can have visual variants (materials, colors). Keys are variant ids:

```lua
variants = { green = true, yellow = true }   -- two tent colors
```

The active variant flows through the plan (`plan.variant`) into sprite resolution. With one
look, `{ default = true }` is the idiomatic single-variant set.

## Register pieces

Pieces are catalog entries. `category` is the **placement slot**; `categoryGroup` is the
**catalog UI bucket**; `materialRequirement` is the **cost**.

```lua
RCSF.Registry.registerPieces("MyMod_Shed", {
    { spriteName = "walls_exterior_wooden_01_0", category = "wall", pieceType = "wall",
      categoryGroup = "wall", materialRequirement = { fullType = "Base.Plank", count = 2 } },

    { spriteName = "walls_exterior_wooden_01_8", category = "wall", pieceType = "door",
      slotKind = "door", categoryGroup = "door",
      materialRequirement = { fullType = "Base.Plank", count = 2 } },

    { spriteName = "floors_exterior_natural_01_0", category = "floor",
      categoryGroup = "floor", materialRequirement = { fullType = "Base.Plank", count = 1 } },
})
```

`registerPieces` returns the number registered and auto-fills each piece's `structureId` and
an `id` (`structureId .. ":" .. spriteName`) when you don't supply one. The full piece field
list is in [Reference → Data contracts](#piece).

### Slot kinds vs. categories

- `category` / `categoryGroup` are about **organization** (which paint phase, which UI tab).
- `slotKind` (`"wall"` / `"door"` / `"window"`) is about **engine behavior** - a `"door"`
  slot places an `IsoDoor`, a `"window"` an `IsoWindow`, the default `"wall"` an
  `IsoThumpable`. The framework's door/window-frame walkability fix
  ([`SpritePropertyPatcher`](#spritepropertypatcher)) keys off this.

## Re-registration is safe

Both calls are idempotent: re-registering a structure overwrites the def, and registering a
piece id again replaces it. That makes hot-reload and `Core.ResetLua` clean - your `shared/`
file just re-runs.

```{seealso}
- [Materials & unlocks](materials-and-unlocks.md) - costs, recipes, and gating pieces behind skills/magazines/research.
- [Validation](validation.md) - control what footprints and plans are accepted.
```
