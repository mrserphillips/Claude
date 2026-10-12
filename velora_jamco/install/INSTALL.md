# Installation

## Requirements
- **FXServer with OneSync.** OneSync Infinity is recommended.
- **qbx_core.** Its current exports are used: `GetPlayer`, `AddMoney`, `RemoveMoney` and `GetMoney`.
- **ox_lib, ox_inventory, ox_target and oxmysql.**
- **A vehicle key script.** `qbx_vehiclekeys` works by default. See `Config.VehicleKeys` for the other supported scripts.

## Steps
1. **Copy the resource.** Put the folder into your resources, for example `resources/[velora]/velora_jamco`. Any folder name works, but use the same name in `ensure`. When updating, delete the old folder first instead of copying over it. You can keep your own `config.lua`: any settings added in newer versions are filled in with defaults automatically, and the server console lists them.

2. **Database.** The tables are created automatically the first time the resource starts. If you prefer to create them yourself, run `sql/install.sql`.

3. **Items.**
   - Open `install/ox_inventory_items.lua` and paste every entry into `ox_inventory/data/items.lua`, inside the `return { }` table.
   - Copy every PNG from `velora_jamco/web/images/items/` into `ox_inventory/web/images/`.
   - You don't need to copy the per-recipe jar icons in `web/images/jams/`. Each jar's metadata includes an `imageurl` that points at this resource, whatever its folder is called.

4. **server.cfg.** Make sure the dependencies start before this resource:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure qbx_core
   ensure ox_target
   ensure ox_inventory
   ensure qbx_vehiclekeys
   ensure velora_jamco
   ```

5. **Configure.** Open `config.lua` and replace every coordinate marked `-- PLACEHOLDER`. See `CONFIG_GUIDE.md` for how, including the in-game helpers `/jamcoords` and `/jamtree`.

6. **Optional: Discord logging.** Put a webhook URL in `server/sv_config.lua`. That file is never sent to clients.

7. **Optional: Lation Banking statements.** Fill in `Config.OnMoneyTransaction` in `config.lua`. Lation Banking already reads the qbx_core bank balance, so deposits and refunds show up without this hook.

8. **Restart and check.** Restart the server, or run `ensure velora_jamco`. The console should print `[velora_jamco] loaded 44 recipes`.

## Quick test
1. Go to the business NPC and select **Talk to Rosalind Vale**.
2. Choose **Pantry Supplies** and buy a mixing bowl, sugar, jars and lids.
3. Start a shift with a van and drive to the orchard.
4. Pick fruit, then go back to the kitchen stove and select **Use Jam Kitchen**.
5. Mix fruit and play through the five stages.
6. Type `/selljam` and approach a local.
