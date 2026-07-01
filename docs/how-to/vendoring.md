# Use only the parts you need

RC Structure Framework supports three levels of "use only what you need":

1. **Depend on everything** (default) - `require=RCStructureFramework`, call what you want.
2. **Opt out of auto-systems** - keep the dependency but disable subsystems you don't need.
3. **Vendor a module** - copy a single self-contained module into your own mod with no
   dependency on the framework at all.

## 1. Default: one dependency

Declare `require=RCStructureFramework` in your `mod.info` and `require("RCStructureFramework")`.
Nothing you don't call has any gameplay effect except the auto-systems below (which you can
disable).

## 2. Opt out of auto-systems

A few subsystems register vanilla events at load and run automatically. Two ways to disable
them.

**Reliable for a dependent mod (recommended).** Your mod's files load *after* the framework,
so by the time they run it has already bound its events. Call `RCSF.disable(key)` at your own
**shared-file scope** - it unbinds cleanly, and because both the framework's bind and your
`disable` re-run on `Core.ResetLua` (in dependency order), it stays disabled across the reset:

```lua
-- media/lua/shared/MyMod/RCSFConfig.lua
RCSF.disable("roomLighting")
RCSF.disable("spritePatcher")
```

Keys: `roomLighting`, `spritePatcher`, `roomSync`, `materialContainers`, `plannedConstructions`.
`RCSF.enable(key)` re-binds.

**Load-time config (vendored / load-order you control).** If you can run code *before* the
framework loads, set the global config table; the framework reads it at load:

```lua
RCSF_Config = RCSF_Config or {}
RCSF_Config.systems = {
    roomLighting        = false,   -- don't wire light switches into runtime rooms
    spritePatcher       = false,   -- don't run the door/window-frame walkability re-patch
    roomSync            = false,   -- don't auto-create/sync IsoRooms from ModData
    materialContainers  = false,   -- don't bind the material-container OnClientCommand handler
    plannedConstructions = false,  -- don't sync ghost-preview records
}
RCSF_Config.validateDefs = true    -- def validation on registerStructure (default true)
```

Defaults are **all enabled**, so a mod that sets nothing behaves exactly as before. Disabling
a system never changes multiplayer authority - it only controls whether the system loads.

```{note}
`spritePatcher`: the pure `SpritePropertyPatcher.applyToSprite(...)` call on the live build
path always runs (the builder needs it); the opt-out only disables the save-load re-patch
sweep.
```

## 3. Vendor a single module

Some modules are self-contained drop-ins you can copy into your own mod and use **without
depending on RCStructureFramework at all**. Use this when you want exactly one capability (say,
the runtime light-switch fix) and don't want a hard dependency.

To vendor:

1. Copy the file into your mod, e.g. `YourMod/media/lua/shared/YourMod/Geometry.lua`.
2. Rewrite any internal `require("RCStructureFramework/...")` paths to your mod's paths
   (Tier-1 modules have none, or use injection - see below).
3. Require it: `require("YourMod/Geometry")`.

Each vendorable file carries a header comment stating its tier and dependencies.

### Vendoring tiers

```{list-table}
:header-rows: 1
:widths: 12 88

* - Tier
  - Meaning
* - **T1**
  - Standalone drop-in. No framework `require`; copy one file.
* - **T2**
  - Vendors as a small documented cluster (copy 2-3 files together).
* - **T3**
  - Deeply interdependent; don't vendor - depend on the framework.
```

#### Tier 1 - standalone drop-ins

```{list-table}
:header-rows: 1
:widths: 26 20 54

* - Module
  - Deps
  - Notes
* - `Geometry`
  - none
  - coordinate/rect math.
* - `RecipeSource`
  - none
  - atomic item+tag recipe consumption.
* - `PieceLibrary`
  - none
  - catalog registry + unlock gating.
* - `SpritePropertyPatcher`
  - none
  - door/window-frame walkability fix; pure `applyToSprite` + opt-in hooks.
* - `Json`
  - none
  - the JSON codec (split out of `Presets`).
* - `RoomLighting`
  - injected
  - the runtime light-switch fix; call `RoomLighting.setRoomFilter(fn)` to supply your own "is this my room" predicate instead of the `Registry` lookup.
```

#### Tier 2 - small clusters

```{list-table}
:header-rows: 1
:widths: 24 40 36

* - Cluster
  - Files
  - Notes
* - Plan toolkit
  - `Plans` + `Geometry`
  - plan construction/copy/normalize.
* - Material toolkit
  - `MaterialSource` + `MaterialSources/*` + `Registry` (+ `MaterialContainers` for `"bag"`)
  - `"raw"`/`"universal"` need only `Registry`.
* - Room toolkit
  - `RoomPersistence` + `Geometry` + `Registry`
  - runtime room creation/persistence/sync.
* - Validators
  - `DefaultValidators` + `Plans` + `Geometry`
  - (+ `RoomPersistence`/`PlannedConstructions` for a few rules).
```

#### Tier 3 - depend on the framework

`Builder`, `PlacementHelpers`, `PlacementValidation`, `PlannedConstructions`, `Footprints`,
`BuildRecipeCallbacks`, the structure-aware part of `Presets`, and all `client/*` UI. These
pull in much of the rest - vendoring one drags in the cluster, so just take the dependency.

### Rules a Tier-1 module obeys

- No `require("RCStructureFramework/<other-module>")` (cross-module deps removed via injection,
  e.g. `RoomLighting.setRoomFilter`).
- Never reaches the `_G.RCStructureFramework` / `_G.RCSF` global.
- Carries a header comment documenting its tier + dependencies + the path-rewrite note.

If you vendor a module and later want to upstream a fix, please open a PR against the
framework copy so other consumers benefit.
