# Troubleshooting

## Items or icons are missing
- **Item doesn't show up at all:** add the entries from `install/ox_inventory_items.lua` to `ox_inventory/data/items.lua`, then restart ox_inventory.
- **Plain grey item icons:** copy `web/images/items/*.png` into `ox_inventory/web/images/`.
- **Jar icons are blank:**
  - The resource folder must be named exactly `velora_jamco`.
  - If you renamed it, update `Config.JamImageUrl` to match.
  - Jars crafted before the rename keep the old URL in their metadata.

## Starting a shift or spawning a van
- **"All van bays are occupied":** clear the `Config.Van.Spawns` area or add more spawn points.
- **No keys:**
  - Set `Config.VehicleKeys` to match your key script.
  - For an unlisted script, add its export to `giveKeys` in `server/business.lua`, or to the `velora_jamco:client:giveKeys` handler in `client/main.lua`.
- **Deposit not refunded:**
  - The van must be within `Config.Business.returnRadius` of `returnPoint`.
  - Its body and engine health must be at or above `Config.Van.RefundHealth`.
- **Server restarted or player crashed mid-shift:**
  - On a restart, deposits are refunded to online players when the resource stops.
  - If a player crashed, their refund is queued and paid automatically the next time they log in.

## The UI looks old after an update
Type **`/jamversion`** in game. It shows the server, client and UI versions, plus the folder the server is running from.
- **All three versions match:** the UI is up to date.
- **UI says "NOT REPORTED":** your PC is still showing a cached copy of the old UI.
- **Server version is old, or the folder is wrong:** the server is running a different copy of the resource.

The server console also prints `version X running from <folder>` when the resource starts. If you still see the old UI:
1. **Use a clean copy.** Delete the old `velora_jamco` folder on the server completely, then copy in the new one. Copying over the top leaves old files behind, such as the old `web/index.html`. Also check you don't have a second copy of the resource in another folder.
1. **Restart the resource properly.** Run `refresh`, then `ensure velora_jamco` in the server console. `refresh` is needed whenever `fxmanifest.lua` changes, and this update adds new image folders.
2. **Clear the FiveM cache:** close FiveM, open `%localappdata%\FiveM\FiveM.app\data\`, delete the `cache`, `server-cache`, `server-cache-priv` and `nui-storage` folders, then reconnect.
3. **Check the files:** make sure the server has the new files, including `web/js/art.js` and the `web/images/minigames/` folder.

## Harvesting
- **Trees float or stand in concrete:**
  - The example trees use placeholder coordinates and are now off by default.
  - Remove any old trees you placed by editing `config.lua`, then place trees in-game with `/jamplace`.
  - Placed props wait for the ground to load before snapping down.
- **Can't target a tree:**
  - If `prop = false`, the coordinates must be on the real tree.
  - Set `Config.Debug = true` to draw the target zones.
- **"Picked clean":** the tree's stock has run out. It restocks after `restock` seconds. Admins can run `/jamreset`.
- **"Too far from the tree" while standing next to it:** the server compares horizontal distance against `Config.Harvest.MaxDistance + 2`. Check that the tree's X and Y coordinates are correct.
- **A prop model doesn't load:** the fallback prop is used automatically, and a warning is printed in the F8 console.

## Kitchen
- **"You need to be at the jam kitchen":** `Config.Kitchens[*].coords` must be within `maxDistance` of where you stand.
- **The batch ended suddenly:** walking away from the stove, dying, getting into a vehicle, or taking longer than `StageTimeout` on one stage abandons the batch.
  - Abandoned during preparation: every ingredient is refunded.
  - Abandoned later: only jars and lids are refunded.
- **Jars missing after crafting:** your inventory was full. They're waiting on the **Cooling Rack** tab in the kitchen.
- **The server crashed mid-batch:** the ingredients are refunded automatically the next time the player loads in.

## Stuck cursor or black screen
- **Escape and the ✕ button always close the UI.** The UI hides itself before it tells Lua, so the screen can never stay black.
- **Restarting the resource while the UI is open:** this also releases NUI focus.
- **Still stuck:** run `/ensure velora_jamco` from the server console, then check F8 for errors.

## `/selljam`
- **No customer turns up:**
  - Check the notification to make sure selling mode is on.
  - You must be on foot and must not have a menu open.
  - The first customer arrives after `FirstCustomerDelay` and later ones after `CustomerInterval`.
- **The customer gave up:** they leave if you drive off, walk more than 80 m away, or don't serve them within `WaitTimeout`. The next one comes after the interval.
- **No E prompt:** stand within `ServeDistance`. You can also target the customer with ox_target.
- **Selling mode turned itself off:** you ran out of jars.

## Logs
- **Database:** `velora_jamco_logs` records shifts, harvests, crafts, sales, cancellations, recovery events and rejected or implausible minigame results.
- **Console:** set `Config.Logging.console = false` to silence it.
