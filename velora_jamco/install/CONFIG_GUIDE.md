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

## 2. Orchard trees: `Config.Orchards[*].trees`
Each line looks like this:
```lua
tree('gs_orange_1', 'orange', x, y, z, { difficulty = 'easy', stock = 12, restock = 900, yield = { min = 3, max = 5 } })
bush('gs_rasp_1', 'raspberry', x, y, z)
```
- **`prop`:** a model to spawn locally. Props snap to the ground, so Z only needs to be roughly right.
- **`prop = false`:** targets a real GTA tree already standing at those coordinates. Stand next to the trunk and use `/jamtree orange`, then add `prop = false` to the options.
- **Orange trees:** only produce oranges unless you change `fruit`. To have several fruits in one spot, add one entry per fruit.
- **Other options:**

  | Option | What it controls |
  |---|---|
  | `stock` | Total fruit before the tree is picked clean |
  | `restock` | Seconds until a picked-clean tree refills |
  | `yield` | Ripe fruit per picking round |
  | `difficulty` | `easy`, `normal` or `hard` (presets in `Config.Harvest.Difficulties`) |

- **Tree ids:** must be unique.

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

**Typical earnings:** a 4-jar Uncommon batch at Fine quality sells for roughly $520–600. That batch takes about 16 fruit (5–6 trees) and roughly 10–15 minutes of total work. To scale payouts, change `Config.Rarities[*].value`.

Fruit can't be bought, jam can only be sold to NPCs (with cooldowns), and supplies can't be sold back, so there is no money loop.

## 7. Selling: `Config.Selling`
| Setting | What it controls |
|---|---|
| `Command` | The command name (default `selljam`) |
| `PedCooldown` | Seconds before the same ped can be approached again |
| `RejectChance`, `MaxConsecutiveRejects` | Fair rejections: after the maximum in a row, the next customer always listens |
| `AllowedPopTypes` | Only ambient population peds can be customers, so scripted NPCs are never touched |
| `CustomerTypes` | Weights, price ranges, haggle room, patience and the pitch each type likes |

## 8. Other settings
| Setting | What it controls |
|---|---|
| `Config.RequireShift` | Makes harvesting or cooking require an active shift |
| `Config.Crafting` | Batch size, fruit per jar, pectin bonus, mixing bowl requirement, cancel refunds |
| `Config.Minigames` | Tuning for each stage (rarity makes stages harder automatically) |
| `Config.QualityWeights` | How much each stage counts towards quality |
