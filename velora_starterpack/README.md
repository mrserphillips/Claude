# Velora City — Starter Pack (`velora_starterpack`)

A premium "choose your path" starter pack for **Qbox (qbx_core)**, **ox_inventory**, **ox_lib** and **oxmysql**.

New characters visit the **Velora welcome host**, a ped standing in the **Legion Square car park**, and choose **THE CIVILIAN DREAM** or **THE CRIMINAL UNDERWORLD**. Both paths get the standard starter rewards plus the bonus for their path. Each character can claim once, and the claim is enforced by the database.

---

## Requirements

| Resource | Notes |
|---|---|
| `qbx_core` | Qbox core (multicharacter built in) |
| `ox_inventory` | All items are granted through its server exports |
| `ox_lib` | Callbacks and notifications |
| `oxmysql` | Persistent claim tracking |
| `ox_target` *(optional)* | Third-eye interaction with the ped. Without it, players get an `[E]` prompt instead. |

No ESX or qb-inventory functions are used.

## Installation

1. **Copy** the `velora_starterpack` folder into your resources directory (for example `resources/[velora]/velora_starterpack`).

2. **Database.** The tables are created automatically on first start (`Config.Database.autoCreate = true`). If you prefer to create them yourself, run `sql/install.sql` against your server database. Running it is safe either way.

   > **Live server?** Every existing character counts as "unclaimed". To give the pack only to characters created from now on, run the optional `INSERT IGNORE … SELECT citizenid FROM players` block at the bottom of `sql/install.sql` once.

3. **Items.** Every reward item must exist in `ox_inventory/data/items.lua`:
   `phone`, `cos_sprunk`, `bbs_double_cheese_goat`, `lockpick`, `pumpkin_patch_card`, `bodywavewigs`, `pink_messenger_bag`, `ls_og_kush_bag`, `ls_og_kush_seed`.
   On start, the resource prints a clear `ERROR` line for each missing item. **Claims are blocked until the problem is fixed**, so nobody receives a broken pack. Item icons come from `ox_inventory/web/images/<item>.png`; if an icon is missing, the UI shows a styled letter instead.

4. **Avoid a double phone.** qbx_core gives its own starter items (`qbx_core/config/shared.lua → starterItems`). If that list includes `phone`, remove it there, or remove it from this resource's `Config.Rewards.standard.items`.

5. **server.cfg.** Start the resource **after** its dependencies and add the ACE lines:

   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure qbx_core
   ensure ox_inventory
   ensure ox_target        # optional, for third-eye on the ped
   # … your appearance / spawn resources …
   ensure velora_starterpack

   # Starter pack admin commands (/startercheck, /starterreset, /startergive)
   add_ace group.admin velora.starterpack.admin allow
   # Optionally grant individual staff:
   # add_ace identifier.license:xxxxxxxxxxxxxxxx velora.starterpack.admin allow
   ```

6. Restart the server or run `ensure velora_starterpack`.

---

## How it works

### Player flow
1. A character finishes multicharacter selection, spawns, and completes the appearance/clothing menu.
2. If that character has never completed a claim, they get a notification telling them to visit the welcome host, and a **GPS waypoint** to the Legion Square car park.
3. At the ped they use ox_target ("Velora Welcome Pack") or press **[E]**, and the menu opens.
4. The player picks a path, then confirms with **Confirm My Journey**. The choice is now locked.
5. The server delivers everything, and the animated reward screen lists every item plus the cash and bank amounts.
6. **WELCOME TO VELORA** closes the UI and releases NUI focus.

If the player closes the menu with ESC or ✕ before choosing, they can come back to the ped at any time.

### The ped (Legion Square car park)
- **Position:** `Config.Ped.coords = vec4(215.76, -810.12, 30.73, 335.0)`. This is inside the Legion Square car park, a few metres from the qbx_garages "Pillbox Garage Parking" access point (`218.66, -804.08`), so it doesn't block the garage marker. To move it, stand where you want the ped, run `/coords` (or your own coordinate tool), and paste the x, y, z and heading. The z value is your standing height; the script handles placing the ped's feet on the ground.
- **Performance:** the ped is created locally on each client only within `spawnDistance` (60 m) and deleted when the player leaves, using `ox_lib` points. Nothing is networked and there are no idle loops. The `[E]` key check only runs while the player is within 2.5 m of the ped.
- **Interaction:** `Config.Ped.interaction = 'auto'` uses ox_target when it is running, otherwise an ox_lib `[E]` text prompt. You can force `'ox_target'` or `'textui'`.
- **Map blip:** a pink gift blip labelled "Velora Welcome Pack". Configure or disable it in `Config.Ped.blip`.
- **Server-side proximity:** with `requireNearby = true`, the server checks the player's real position (`GetEntityCoords(GetPlayerPed(src))`) when the menu is opened at the ped **and again when the claim is confirmed**. A modded client can't trigger the menu or a claim from elsewhere on the map. The limit is `maxServerDistance`, 8 m by default.
- **Model and animation:** `Config.Ped.model` (default `a_f_y_bevhills_02`) and `Config.Ped.scenario` (default clipboard).

### After a new character spawns
`Config.AutoOpen.mode`:
- `'notify'` *(default)*: shows a notification and sets a GPS waypoint to the ped.
- `'menu'`: opens the menu automatically wherever the player is, which skips the ped.

Either way, this is triggered by qbx_core's `QBCore:Client:OnPlayerLoaded`. After `Config.AutoOpen.delay`, the client waits until **all** of the following have been true continuously for `stableFor` ms:

- the screen is faded in, with no loading screen, player switch or cutscene;
- **no other NUI has focus**, which covers the multicharacter, illenium-appearance, qb-clothing, fivem-appearance and phone UIs;
- the pause menu is closed;
- the ped is alive and visible;
- if qbx_core fired `qb-clothes:client:CreateFirstCharacter` (new character), the appearance menu has opened and then closed.

The readiness check only runs between player load and the menu opening. It stops on success, logout, resource stop or `maxWait`. There are no permanent client loops.

This only triggers once the character is fully in the world.

**Custom appearance resource?** Fire `TriggerEvent('velora_starterpack:client:appearanceFinished')` when it closes, or add its events to `Config.AutoOpen.appearanceStartEvents` / `appearanceFinishEvents`. You can also call `exports.velora_starterpack:OpenIfEligible()` yourself.

### Exploit prevention & reliability

| Threat | Protection |
|---|---|
| Claiming twice / both paths | `UNIQUE(citizenid)` claim row. The first confirmation locks the path and any later request for another path is rejected. |
| Tracking by FiveM account | Claims are keyed on the Qbox **citizenid**. The license is stored only for auditing. |
| Forged rewards from the client | The client sends only `{ path, token }`. Items, counts and money come from `config.lua`, which is loaded **server-only** and never sent to clients. |
| Opening without the menu | The server issues a one-time session token when it opens the menu. A claim without a valid token for the current character is rejected. |
| Event spam / simultaneous requests | Per-player cooldowns, an in-memory lock per player and per citizenid, and a **database lock** on the claim row (`lock_token`, which expires after `lockTimeout`). |
| Inventory full | Weight and free slots are checked for **all** remaining rewards before anything is given. This accounts for non-stackable items needing one slot each and for the cash `money` item needing a slot. (ox_inventory's `AddItem` does not check weight itself.) |
| Partial failures | Every reward is a recorded step. Stackable items are one step; **non-stackable items are one step per unit**, because ox_inventory can partially fill non-stackables. Each step is written as `granting` before it is given and `granted` after. A retry only gives steps that are not `granted`. |
| Crash or restart mid-claim | A step left in `granting` has an unknown outcome, so it is **never re-granted automatically**. It is flagged `review`, the claim is marked `needs_review`, and staff can see it in `/startercheck`. Duplicates are therefore impossible even across crashes. |
| Completion | A claim is marked `completed` only after every step has been processed. Until then it stays `pending`, the path stays locked, and the player can finish with `/starterpack` (the UI opens in "Collect my rewards" mode). |
| Money | Granted through `exports.qbx_core:AddMoney(source, 'cash' / 'bank', amount, reason)` and saved with `exports.qbx_core:Save(source)`. Money is never added as raw items. |

> A note on crash safety: qbx_core and ox_inventory also save player data on their own schedules. If the whole server crashes, data that hadn't been saved yet can be lost. This affects every resource, not just this one. This resource records its own progress immediately and forces a qbx player save after granting money and when a claim completes.

### Verified APIs
These APIs were checked against the current qbx_core and ox_inventory source:
- `exports.qbx_core:GetPlayer`, `GetPlayerByCitizenId`, `AddMoney`, `Save`
- `QBCore:Client:OnPlayerLoaded`, `QBCore:Client:OnPlayerUnload`, `qbx_core:client:playerLoggedOut`, `QBCore:Server:OnPlayerUnload`, `qb-clothes:client:CreateFirstCharacter`
- `exports.ox_inventory:Items`, `GetInventory`, `AddItem`
- `exports.ox_target:addLocalEntity`, `removeLocalEntity`; `lib.points`, `lib.showTextUI`, `lib.requestModel`

---

## Commands

| Command | Who | Description |
|---|---|---|
| `/starterpack` | Players | **Disabled by default** (`Config.Command.enabled = false`), so the ped is the only way to claim. If you enable it while the ped is enabled, it only works near the ped. |
| `/startercheck [id\|citizenid]` | Admin | Shows whether the character claimed, which path, status, attempts, dates, and any steps needing review. Works for offline characters by citizenid. |
| `/starterreset [id\|citizenid]` | Admin | Shows a **warning** first. Run `/starterreset [id] confirm` within 30 seconds to delete the claim. **Items and money already given are not removed, and the character can claim another full pack.** The reset is logged to `velora_starterpack_history`. |
| `/startergive [id]` | Admin | Opens the selection menu for an online player who hasn't claimed. This works wherever the player is, bypassing the ped distance check. |

All admin commands check `velora.starterpack.admin` on the server and also work from the server console.

## Exports

```lua
-- server
exports.velora_starterpack:HasClaimed(citizenid)  -- boolean
exports.velora_starterpack:GetClaim(citizenid)    -- { path, status, needsReview, completedAt } | nil

-- client
exports.velora_starterpack:OpenIfEligible()       -- boolean (opened)
exports.velora_starterpack:IsOpen()               -- boolean
```

## Configuration

Everything is in `config.lua`:

- `Config.Ped`: model, position, scenario, ox_target or `[E]` interaction, labels, blip, server-side distance check
- `Config.Enabled`: master switch
- `Config.Debug`: verbose console output
- `Config.AutoOpen`: enable, `mode` (`'notify'` or `'menu'`), waypoint, delay, stability window, max wait, appearance events, reopen on resource restart
- `Config.Command`: the `/starterpack` command name or disable it
- `Config.Rewards.standard`: items and `money = { cash, bank }` for everyone
- `Config.Rewards.paths.civilian` / `.criminal`: title, subtitle, description, tags, bonus items and optional extra money
- `Config.Inventory`: cash item name and icon path
- `Config.Security`: cooldowns, DB lock timeout, spam-logging threshold
- `Config.Admin`: ACE name, command names, reset confirmation window
- `Config.Logging.webhook`: optional Discord webhook (server-only, never exposed)
- `Config.UI.colors` / `Config.UI.text`: every colour and every line of UI text
- `Config.Notify`: ox_lib notification position, duration and all messages

## Database tables

| Table | Purpose |
|---|---|
| `velora_starterpack_claims` | One row per citizenid: path, `pending`/`completed`, `needs_review`, lock, timestamps |
| `velora_starterpack_rewards` | Per-step progress (`granting` / `granted` / `review`) |
| `velora_starterpack_history` | Audit log: path chosen, completed, admin reset, admin open |

## Previewing the UI

Open `web/index.html` in a desktop browser. Outside FiveM it runs a preview with sample data, so you can see the selection, confirmation and reward screens. Item icons only load in-game.

## Troubleshooting

- **"The starter pack is temporarily unavailable"**: check the server console for `Config:` errors, usually a missing item in ox_inventory.
- **No arrival notification**: set `Config.Debug = true` and watch the F8 console for readiness messages. Another resource may be holding NUI focus. Players can still walk to the ped.
- **Ped floating or sunk into the ground**: re-take the coordinates with `/coords` while standing on that spot. Use your standing height, not the ground height.
- **"You need to be with the Velora welcome host…"**: the player is more than `maxServerDistance` from `Config.Ped.coords`. If you moved the ped, check that the coordinates you pasted are where it actually stands.
- **`needs_review` claims**: the server stopped while that step was being granted. Check the player's inventory or balance and give the item manually if needed.
