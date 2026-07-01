# Ship safely to multiplayer

RC Structure Framework is **server-authoritative** and works on dedicated servers, listen
hosts, and singleplayer. The built-in UI flow already does the right thing - this page is the
rules **your** consumer code must follow so you don't desync. For the model behind the rules,
see [Concepts → Authority & rooms](../concepts/authority-and-rooms.md).

## The rules

:::{admonition} 1. Mutate persistent state on the server, never in an `if isClient()` branch.
:class: warning
Inventory sync helpers (`sendAddItemToContainer`, `sendRemoveItemFromContainer`,
`syncItemModData`, …) are **server-only no-ops on a client** - calling them client-side
silently desyncs. Use the framework's build flow (which runs server-side) or a
`sendClientCommand` → `OnClientCommand` handler.
:::

**2. Use explicit three-way branching** where side matters:

```lua
if isClient() then        -- MP client: UI, previews, requests
elseif isServer() then    -- MP server: authoritative mutation
else                      -- singleplayer
end
```

Never `if not isServer()` - singleplayer is *neither* client nor server, and that guard
silently breaks SP.

**3. A timed action's `complete()` runs on the server in MP.** Don't rely on nested-table
`IsoObject` arrays surviving `NetTimedAction` serialization - re-resolve world objects from
coordinates and gate refunds on the mutation actually happening this call. (This is why
`RCSFPlannedPiece` carries `x,y,z` rather than object references.)

**4. Server-side re-validation reads the *server's* inventory.** A client-only / debug-spawned
item that never synced will fail the server-side material/tool check, so the build silently
does nothing. In tests, grant items server-side.

**5. Anything that must survive `Core.ResetLua` lives on disk/ModData, not a `local`.** A
client joining a modded server triggers a ResetLua mid-connect; the framework's load-time
config and event re-registration are designed for this (every file re-runs and re-derives its
state). If you add your own auto-systems, follow the same pattern.

## The headless APIs are server-authoritative too

The programmatic entry points match the build flow - call them from server-side logic:

```{list-table}
:header-rows: 1
:widths: 38 62

* - API
  - In multiplayer
* - [`RCSF.build(...)`](headless-build.md)
  - Runs on the server / SP; returns a **failure outcome on an MP client** (unless `opts.allowClient`). The result syncs to clients normally.
* - [`RCSF.Rooms.assign / unassign`](rooms.md)
  - Server-authoritative; **no-op on an MP client**. The room reaches clients via the room-record sync.
* - [Events](events.md)
  - Fire on the side that performed the op - **server-side in MP**. Don't assume a listener runs on every client.
```

## What syncs, and how

```{list-table}
:header-rows: 1
:widths: 34 18 48

* - State
  - Owner
  - Sync
* - Rooms (`RoomPersistence`, incl. `RCSF.Rooms`)
  - server
  - ModData `RCStructureFrameworkRooms` → `transmit` → clients' `OnReceiveGlobalModData`
* - Planned constructions
  - server
  - ModData `RCStructureFrameworkPlanned` → `transmit`; clients `ModData.request` on game start
* - Material container ops
  - server
  - `sendClientCommand` → `OnClientCommand` (`"RCStructureFramework"` / `"materialContainerOp"`)
* - Light state
  - server
  - server sets `room.def.lightsActive`; clients render via the cell room-light list
```

## Test matrix

When verifying an integration, cover **dedicated server + client**, **listen host**, and
**singleplayer** - the three paths where authority and synchronization behave differently.
