# Events

The framework registers four custom Lua events through `LuaEventManager.AddEvent`, so you
can react to builds, disassembly, and room assignment **without patching framework
internals**. Subscribe with the global `Events` table, exactly like a vanilla event.

```{seealso}
Task-oriented guide with examples: [How-to → React to framework events](../how-to/events.md).
```

## Subscribing

```lua
Events.OnRCSFStructureBuilt.Add(function(info)
    -- info.structureId, info.plan, info.character, info.placed
end)
```

Each event delivers **one descriptor table** (so the payload can grow without breaking a
positional signature). The shapes are also declared as `@class` types in `Contracts.lua`.

## Firing side / authority

```{important}
Each event fires on whichever side actually performed the operation. Builds and
disassembly run **server-authoritatively** in multiplayer (the timed action's
`complete()` runs on the server), so `OnRCSFStructureBuilt` / `OnRCSFStructureDisassembled`
fire on the server (and locally in singleplayer). Room assignment is likewise
server-authoritative.

A listener that needs a purely client-side reaction should drive it off the synced
world/room state, not assume the event reaches every client. See
[Concepts → Authority & rooms](../concepts/authority-and-rooms.md).
```

## The events

`````{list-table}
:header-rows: 1
:widths: 30 70

* - Event
  - Payload (one table arg)
* - `OnRCSFStructureBuilt`
  - `{ structureId, plan, character, placed }` - fired by `Builder.buildFromPlan` (and `RCSF.build`) on success. `placed` is the `IsoObject[]` placed this build (empty for legacy builders).
* - `OnRCSFStructureDisassembled`
  - `{ structureId, character, removed }` - fired by `Builder.disassembleFromPlan` on success. `removed` is the `IsoObject[]` torn down.
* - `OnRCSFRoomAssigned`
  - `{ id, name, rects }` - fired by `RCSF.Rooms.assign`.
* - `OnRCSFRoomUnassigned`
  - `{ id, name, rects }` - fired by `RCSF.Rooms.unassign`.
`````

## `RCSF.Events`

The module table also exposes the names and the `fire*` helpers the framework calls
internally:

- `RCSF.Events.NAMES` → `string[]` of the four event names.
- `fireStructureBuilt(structureId, plan, character, placed)`
- `fireStructureDisassembled(structureId, character, removed)`
- `fireRoomAssigned(assignment)` / `fireRoomUnassigned(assignment)`

You normally don't call these - the framework does. They're documented so you know exactly
when and with what each event fires.
