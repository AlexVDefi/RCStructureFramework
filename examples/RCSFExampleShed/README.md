# RCSF Example Shed

A minimal, working consumer mod for [RC Structure Framework](../../README.md). It's the
companion to the [Getting started](../../docs/GETTING_STARTED.md) tutorial.

## What it shows

- **Registering a structure + pieces** - one `Registry.registerStructure` call and a
  `Registry.registerPieces` batch (one wall, one floor).
- **The generic builder with raw materials** - `useGenericBuilder = true` +
  `materialSource = "raw"` consumes planks straight from the player's inventory.
- **A runtime room with lighting** - `roomName` makes the built shed a real `IsoRoom`;
  the `roomLighting` system wires any light switch placed inside.
- **Subset opt-out** - the shed disables the three auto-systems it doesn't need
  (`spritePatcher`, `plannedConstructions`, `materialContainers`) via `RCSF.disable(...)`,
  demonstrating the "use only a subset" pattern. See [Vendoring](../../docs/VENDORING.md).

## Files

| File | Role |
|---|---|
| [42/mod.info](42/mod.info) | declares `require=RCStructureFramework` |
| [.../shared/RCSFExampleShed/ExampleShed.lua](42/media/lua/shared/RCSFExampleShed/ExampleShed.lua) | registers the structure + pieces, opts out of unneeded systems |
| [.../client/RCSFExampleShed/ExampleShedMenu.lua](42/media/lua/client/RCSFExampleShed/ExampleShedMenu.lua) | opens the placement UI from an inventory context menu |
| [.../shared/Translate/EN/IG_UI.json](42/media/lua/shared/Translate/EN/IG_UI.json) | UI strings |

## Try it

1. Copy this folder into your PZ `mods/` directory (or symlink it), so the game sees
   `mods/RCSFExampleShed`.
2. Enable both **RC Structure Framework** and **RCSF Example Shed**.
3. In-game, get some planks, right-click any inventory item → **Build Example Shed**.
4. Drag a footprint, paint walls + a floor, and confirm. Each wall costs 2 planks, each
   floor 1.

That's the whole framework loop, registration, UI, validation, material consumption,
build, and a runtime room in ~50 lines of consumer code.
