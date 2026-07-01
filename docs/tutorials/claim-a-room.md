# Tutorial 2 - Claim a quest room

You don't always want the player to *build* a room - sometimes a quest, prefab, or zone mod
just needs the engine to treat an existing area as a real room: for room detection, lighting,
"are you inside the vault?" checks, and the map.

In this tutorial you'll claim a hand-picked area as a room when a quest starts, and release it
when the quest ends - server-side, persisted, and MP-synced - using
[`RCSF.Rooms`](../how-to/rooms.md). No walls, no UI.

## The idea

`RCSF.Rooms.assign(rectOrRects, name, opts)` creates a real `IsoRoom` over any area and
returns a descriptor you keep. `RCSF.Rooms.unassign(...)` tears it down. Both are
**server-authoritative** - call them from server-side quest logic.

## Step 1 - A quest module (shared)

Create `media/lua/shared/VaultQuest/Quest.lua`. We'll keep the active assignment in ModData so
it survives a relog mid-quest.

```{code-block} lua
:caption: media/lua/shared/VaultQuest/Quest.lua
:linenos:

local RCSF = require("RCStructureFramework")

local Quest = {}
Quest.ROOM_NAME = "VaultQuestRoom"
Quest.AREA      = { x = 10600, y = 9420, z = 0, w = 6, h = 5 }   -- your chosen spot

---Begin the quest: claim the vault area as a real room. Server/SP only.
function Quest.begin()
    if isClient() then return end           -- server-authoritative
    if Quest.isActive() then return end

    local assignment = RCSF.Rooms.assign(Quest.AREA, Quest.ROOM_NAME, { id = "vault_quest" })
    if assignment then
        ModData.getOrCreate("VaultQuest").assignment = assignment
        ModData.transmit("VaultQuest")
        print("[VaultQuest] vault room claimed")
    end
end

---End the quest: release the room. Server/SP only.
function Quest.finish()
    if isClient() then return end
    local data = ModData.getOrCreate("VaultQuest")
    if not data.assignment then return end
    RCSF.Rooms.unassign(data.assignment)     -- the descriptor carries id + rects
    data.assignment = nil
    ModData.transmit("VaultQuest")
    print("[VaultQuest] vault room released")
end

function Quest.isActive()
    return ModData.getOrCreate("VaultQuest").assignment ~= nil
end

return Quest
```

Notice how little there is: `assign` returns a descriptor, you stash it, and pass it straight
back to `unassign`. The framework handles room creation, persistence, MP sync, and
reconstituting the room on a later session.

## Step 2 - Trigger it

Hook the quest to whatever should start it - reading a note, entering a trigger zone, a
command. Here's a debug command and a server hook:

```{code-block} lua
:caption: media/lua/server/VaultQuest/Triggers.lua
:linenos:

local Quest = require("VaultQuest/Quest")

-- Example: start the quest the first time the server boots a fresh world.
Events.OnServerStarted.Add(function()
    if not Quest.isActive() then Quest.begin() end
end)

-- Example: react to entry. OnRCSFRoomAssigned fires when the room is claimed.
Events.OnRCSFRoomAssigned.Add(function(info)
    if info.id == "vault_quest" then
        print("[VaultQuest] room " .. info.name .. " is live (" .. #info.rects .. " rect)")
    end
end)
```

```{admonition} Server-authoritative spawners register on OnServerStarted
:class: tip
On a dedicated server, `OnGameStart` never fires - use `OnServerStarted` (or `OnServerStarted`
+ an SP fallback) for anything that must run once on the authoritative side.
```

## Step 3 - Verify

1. Start a world with the mod enabled (the `OnServerStarted` hook claims the room).
2. Walk into the area: open the debug room-info overlay, or place a light switch inside after
   dark - it lights the room, proving the engine sees a real `IsoRoom`.
3. Call `Quest.finish()` (e.g. from a debug option) and confirm the room is gone.
4. Relog: the room is still there until you finish the quest - it persisted.

## Multi-rect vaults

A bigger vault can be several rectangles; edge-adjacent ones become one building:

```lua
Quest.AREA = {
    { x = 10600, y = 9420, z = 0, w = 6, h = 5 },
    { x = 10606, y = 9420, z = 0, w = 4, h = 5 },   -- adjacent → same building
}
```

Pass it the same way; `assign`/`unassign` handle the list.

## Next

- [How-to → Assign a room](../how-to/rooms.md) - the full options reference.
- [Concepts → Authority & rooms](../concepts/authority-and-rooms.md) - why this is server-side.
```
