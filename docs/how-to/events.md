# React to framework events

The framework fires four custom Lua events so your mod can react to builds, disassembly, and
room assignment **without patching framework internals**. Subscribe exactly like a vanilla
event - they're already registered for you.

```{list-table}
:header-rows: 1
:widths: 34 66

* - Event
  - Payload `info`
* - `OnRCSFStructureBuilt`
  - `{ structureId, plan, character, placed }`
* - `OnRCSFStructureDisassembled`
  - `{ structureId, character, removed }`
* - `OnRCSFRoomAssigned`
  - `{ id, name, rects }`
* - `OnRCSFRoomUnassigned`
  - `{ id, name, rects }`
```

## Run code when a structure is built

```lua
Events.OnRCSFStructureBuilt.Add(function(info)
    if info.structureId ~= "MyMod_Shed" then return end
    -- info.placed is the IsoObject[] just placed; info.character is the builder.
    if info.character then
        info.character:getXp():AddXP(Perks.Woodwork, 5 * #info.placed)
    end
end)
```

## Award a quest on disassembly

```lua
Events.OnRCSFStructureDisassembled.Add(function(info)
    if info.structureId == "military_tent" and #info.removed > 0 then
        -- credit the player who packed up the tent
    end
end)
```

## Filtering

Always filter on `info.structureId` if you only care about your own structures - every mod's
builds fire the same event.

```{important}
**These events are server-authoritative in multiplayer.** A build's `complete()` runs on the
server, and room assignment is server-gated, so the events fire on the **server** in MP (and
locally in singleplayer). If you need a purely client-side reaction (a sound, a HUD ping),
drive it off the synced world/room state instead of assuming the event reached the client.
See [Authority & rooms](../concepts/authority-and-rooms.md).
```

## Registering your own events (aside)

If you build your own systems on top, register custom events the same way the framework does
- in a `shared/` file, before anything subscribes or triggers:

```lua
-- media/lua/shared/MyMod/EventRegistration.lua
local EVENTS = { "OnMyModQuestRoomEntered" }
for i = 1, #EVENTS do
    LuaEventManager.AddEvent(EVENTS[i])
end
```

`triggerEvent("OnMyModQuestRoomEntered", data)` then reaches your `.Add` listeners. (An
unregistered name makes `.Add` crash and `triggerEvent` silently no-op.)

```{seealso}
[Reference → Events](../reference/events.md) for payload field details and the
`RCSF.Events` helpers.
```
