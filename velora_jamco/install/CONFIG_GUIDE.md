# Configuration & Coordinates Guide

Everything players can see is in `config.lua`. Recipes live in `server/recipes.lua`, which only the server loads, so hidden ingredients stay secret.

## Admin helpers
These are restricted to `Config.AdminGroup` (default `group.admin`).

| Command | What it does |
|---|---|
| `/jamcoords` | Copies your position as `vec4(x, y, z, heading)` to the clipboard |
| `/jamtree <fruit>` | Copies a ready-made `tree(...)` or `bush(...)` line for your position |
| `/jamreset` | Restocks every tree immediately |

## 1. Business NPC: `Config.Business`
- **`npc.coords`:** a `vec4`. The ped is placed at `z - 1.0`, so use the coordinates you get standing on the floor.
- **`returnPoint` and `returnRadius`:** where a van must be parked for its deposit to be refunded.
- **`Config.Van.Spawns`:** the van bays, tried in order. Occupied bays are skipped.

## 2. Orchard trees
**Use the in-game placement tool.** You don't need to edit coordinates. Placed trees are saved in the database (`velora_jamco_trees`) and appear for everyone straight away.

| Command | What it does |
|---|---|
| `/jamplace [fruit]` | Starts placement mode. The fruit defaults to `orange`. |
| `/jamremove` | Removes the placed tree nearest to you (within 4 m) |
| `/jamreset` | Restocks every tree immediately |

**Placement mode controls:**

| Key | Action |
|---|---|
| Look at the ground | Shows a see-through preview of the tree where it will stand |
| **E** | Place a tree |
| **Mouse wheel** | Rotate |
| **← / →** | Change fruit |
| **G** | Switch between a spawned prop and a real GTA tree |
| **Backspace** | Finish |

In **real GTA tree** mode, look at the base of a real orange tree and press E. Nothing is spawned; the real tree just becomes harvestable. This is what you want for the Grapeseed orange groves.

**What placed trees use:**
- **Props:** strawberries, blueberries, blackberries and raspberries are bushes (`prop_bush_med_03`). Everything else is a fruit tree (`prop_veg_crop_orange`). Both are set in `Config.Harvest.DefaultProps`.
- **Stock, restock and yield:** set in `Config.Harvest.Placed`.
- **Difficulty per fruit:** set in `Config.Harvest.FruitDifficulty`.
- **Orchard blip and waypoint:** follow wherever the trees are.

**Example trees in `Config.Orchards[*].trees`:**
- These use placeholder coordinates and are **off by default** (`Config.Harvest.UseConfigTrees = false`).
- To use them, set that to `true` and fix each line, for example:
  ```lua
  tree('gs_orange_1', 'orange', x, y, z, { difficulty = 'easy' })
  ```
- `prop = false` targets a real tree at the coordinates.
- `/jamtree <fruit>` copies a ready-made line for where you stand.

## 3. Kitchen: `Config.Kitchens`
- **`coords`:** the interaction point. Put it on the hob of the stove.
- **Real stove in your interior:** set `prop = false`.
- **No stove:** keep `prop = { model = 'prop_cooker_03', coords = vec4(...) }` and stand where the stove should go. Use `/jamcoords` and subtract about 1.0 from Z so the prop sits on the floor.
- **`maxDistance`:** moving further than this from the stove abandons the batch.

## 4. Vans: `Config.Van`
- **`Models`:** any vehicle spawn names.
- **`Colours`:** GTA colour indexes, plus the hex values shown in the UI.
- **`Deposit = 0`:** turns the deposit off.
- **`RefundHealth`:** the minimum body and engine health needed for a refund.
- **`Config.VehicleKeys`:** one of `qbx_vehiclekeys`, `wasabi_carlock`, `qs-vehiclekeys`, `MrNewbVehicleKeys`, `mk_vehiclekeys` or `none`.

## 5. Recipes: `server/recipes.lua`
```lua
{ id = 'blushing_hearts', label = 'Blushing Hearts', fruits = { 'strawberry', 'raspberry' }, special = nil,
  rarity = 'uncommon', image = 'jar_11', color = '#d01849', color2 = '#ff7aa2', value = nil, description = '...' }
```
- **Ingredients:** 1–3 fruits plus an optional special ingredient. The order doesn't matter.
- **Duplicates:** two recipes with the same ingredients are rejected at startup, with a console warning.
- **`value`:** overrides the base price, which otherwise comes from the rarity in `Config.Rarities`.
- **Never rename an `id`** once players have discovered it.
- **New icons:** add `web/images/jams/jar_XX.png`, or reuse an existing one.

## 6. Economy
| Setting | Default |
|---|---|
| Base value: experimental / common / uncommon / rare / epic / legendary | $55 / $95 / $135 / $185 / $255 / $380 |
| Quality multiplier: Poor → Perfect Batch | ×0.60 → ×1.25, plus a small ±10% scale inside the tier |
| Customer type multiplier | ×0.72 – ×1.20 |
| Favourite flavour | +18% |
| Bulk order | +6% per extra jar |
| Market saturation | −2.5% per jar sold of that recipe, floor 65%, recovers 1% per minute |
| Supplies per jar (sugar, jar, lid) | about $17 |

**Batches:** every batch makes 3–12 jars (`Config.Crafting.MinJarsPerBatch` / `MaxJarsPerBatch`), and the kitchen picks the biggest batch your fruit allows.

| Fruits in the mix | Fruit per jar (`FruitPerJar`) | Example |
|---|---|---|
| One | 2 | 12 strawberries make 6 jars |
| Two | 1 of each | 8 strawberries + 8 raspberries make 8 jars |
| Three | 1 of each | 5 of each of three berries make 5 jars |

**Typical earnings:** an 8-jar Uncommon batch at Fine quality sells for roughly $1,000–1,200. That batch takes 16 fruit (about 4–5 trees) and roughly 10–15 minutes of work. Bigger batches add only a couple of extra slicing targets and stir turns. If that pays too much for your server, lower `Config.Rarities[*].value` or raise `FruitPerJar`.

Fruit can't be bought, jam can only be sold to NPCs (with cooldowns), and supplies can't be sold back, so there is no money loop.

## 7. Selling: `Config.Selling`
With `/selljam` on, customers walk up to you one at a time. Press **E** (or use ox_target) to serve them.

| Setting | What it controls |
|---|---|
| `Command` | The command name (default `selljam`) |
| `FirstCustomerDelay`, `CustomerInterval` | Seconds before the first customer, and between customers |
| `SpawnDistance` | How far away (metres) a customer starts walking from |
| `ArriveTimeout`, `WaitTimeout` | How long a customer walks, then waits, before giving up |
| `ServeDistance`, `ServeKey` | How close they stop, and the serve key (38 = E) |
| `Quantity` | Weights for wanting 1, 2 or 3 jars. They buy fewer if you have fewer |
| `CustomerModels` | Ped models customers can use |
| `CustomerTypes` | Weights, price ranges, haggle room, patience and the pitch each type likes |

## 8. Other settings
| Setting | What it controls |
|---|---|
| `Config.RequireShift` | Makes harvesting or cooking require an active shift |
| `Config.Crafting` | Batch size, fruit per jar, pectin bonus, mixing bowl requirement, cancel refunds |
| `Config.Minigames` | Tuning for each stage (rarity makes stages harder automatically) |
| `Config.QualityWeights` | How much each stage counts towards quality |
