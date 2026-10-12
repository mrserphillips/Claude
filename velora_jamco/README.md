# Velora Jam Co. (`velora_jamco`)

Fruit harvesting, jam making, recipe discovery and NPC selling for **Velora RP**.
Built for QBox (`qbx_core`), `ox_inventory`, `ox_target`, `ox_lib` and `oxmysql`, with OneSync.

**The loop:** hire a van, drive to the Grapeseed orchard, pick fruit, cook it at the stove, discover recipes, `/selljam` to locals, earn money, then return the van.

| Guide | What's inside |
|---|---|
| [`install/INSTALL.md`](install/INSTALL.md) | Step-by-step installation |
| [`install/CONFIG_GUIDE.md`](install/CONFIG_GUIDE.md) | Coordinates, trees, kitchens, vans, recipes, economy |
| [`install/TROUBLESHOOTING.md`](install/TROUBLESHOOTING.md) | Common problems and fixes |
| [`install/ox_inventory_items.lua`](install/ox_inventory_items.lua) | Item definitions to paste into ox_inventory |
| [`sql/install.sql`](sql/install.sql) | Database tables (also auto-created on start) |

## Features
- **Business NPC (Rosalind Vale):** a full NUI office for shifts, van hire (model and livery), orchards with waypoints, carried ingredients, recipe book, statistics, achievements and the pantry supplier shop. No job is required.
- **Company vans:** spawned server-side on free bays, so vans never overlap. Keys are given through your key script. The deposit is refunded only if the van comes back undamaged, and deposits are never lost to a crash or restart.
- **Orchard harvesting:** each tree or bush can be a spawned prop or a real GTA tree. Stock is limited and restocks after a cooldown. Fruit baskets add capacity. There's a configurable golden fruit chance.
- **Picking minigame:** fruit grows on illustrated branches. You click it while it glows, avoid rotten fruit, and lose fruit you pick unripe. Three difficulty presets. A perfect round earns a bonus.
- **Five crafting minigames, each with a tutorial and mouse and keyboard controls:**
  - Fruit preparation (slicing targets)
  - Heating, with a temperature simulation and burner inertia
  - Stirring, which tracks real circular mouse motion
  - Jar filling, with ladle drip
  - Lid sealing
- **44 recipes:** 10 single-fruit, 14 two-fruit, 7 with a special ingredient, 4 three-fruit, 6 epic and 3 legendary (these need golden fruit). Recipes are deterministic and stored only on the server, so hidden ingredients can't be read from client files. Unknown mixes become experimental jam.
- **Discovery reveal:** an animated scene with particles, plus a per-character recipe journal that tracks best quality, jars crafted, completion percentage and 10 achievements.
- **Quality system:**

  | Quality | Tier |
  |---|---|
  | 0–39 | Poor |
  | 40–59 | Homemade |
  | 60–79 | Fine |
  | 80–94 | Premium |
  | 95–100 | Perfect Batch |

  Quality is stored in metadata along with recipe, rarity, batch and maker. Jars stack only within a batch, and every recipe shows its own jar icon in ox_inventory.
- **`/selljam`:** customers walk up to you one at a time. Press E or target them to serve. Each wants 1–3 jars and buys fewer if you have fewer. There are 5 customer types, favourite flavours, sales pitches, counteroffers with mood and patience, and market saturation. Customers are local to the seller, so the city population is never touched.
- **Server-authoritative:** the server owns:
  - every reward, payout and inventory change
  - every distance check
  - minigame scoring, computed from raw telemetry with plausibility checks
  - per-player locks that block double-callbacks
  - logging to the database and an optional Discord webhook
