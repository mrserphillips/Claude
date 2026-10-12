# Minigame Art Guide

Every minigame can use painted or photographed artwork instead of the built-in drawings.

- **Where files go:** save each image into `web/images/minigames/` using the exact path in the tables below.
- **Optional:** every file is optional. If a file is missing, the game draws its own version of that piece, so you can add art one piece at a time.
- **To see new art:** restart the resource (`ensure velora_jamco`). You don't need to rebuild anything.
- **Sizing guides:** run `python3 tools/gen_art_templates.py` to create a template PNG for every file in `install/art-templates/`. Each one is the exact size to deliver, with guides showing where the game paints jam and where pivot points sit. They aren't shipped with the resource because the game doesn't use them.

## Art already included
Your painted set is already in the game:

| Stage | Files |
|---|---|
| Preparation | `prepare/board.png` (board); cut fruit `fruit/<fruit>_cut.png` for strawberry, apple, peach, orange and lemon |
| Cooking | `heat/pot.png` (copper pot), plus `heat/pot_front.png`, which is the same pot with the opening cut out |
| Stirring | Shares `heat/pot.png` in a 3/4 view; spoon is `stir/spoon.png` |
| Filling | `fill/jar.png` (glass made see-through), `fill/pour_pot.png` and `fill/pour_stream.png` (tipped pot and its jam stream) |
| Orchard | `harvest/branch.png`; ripe, `_unripe` and `_rotten` versions of strawberry, apple, peach, orange, lemon, raspberry, blackberry, cherry and blueberry |

**How the game uses it:**
- The jam in every pot, stream and jar is recoloured to each recipe's colour, so orange marmalade looks orange.
- Floating fruit pieces in the pot use your fruit art.

**Still missing (built-in drawing or icon is used for now):**

| Missing | Files that would fill the gap |
|---|---|
| Plum | `plum.png`, `plum_unripe.png`, `plum_rotten.png`, `plum_cut.png` |
| Cut berries and cherries | `_cut` versions of raspberry, blackberry, blueberry and cherry (optional) |
| Golden fruit | `fruit/golden.png` |
| Lid, seen from directly above | `seal/lid.png` |
| Gas burner under the pot | `heat/stove.png`, 960 × 220 |
| Backgrounds | `kitchen_bg.jpg`, `harvest/bg.jpg` |
| Basket | `harvest/basket.png` |

## Format rules
- **`.png` files:**
  - Must have a **transparent background**.
  - The object should fill the canvas and be centred as shown in the template.
- **`.jpg` files:** these are full backgrounds, with no transparency needed.
- **No baked-in text or UI:** the game draws all the meters, labels and buttons itself.
- **Matching look:** use the same lighting and style on every piece. Warm, moody kitchen light with a dark cottagecore feel matches the UI.
- **Size:** deliver at the template size. Larger is fine if you keep the same proportions.

## Priority list
These give the biggest improvement first.

| # | File | Size (px) | What it is |
|---|------|-----------|------------|
| 1 | `kitchen_bg.jpg` | 2000 × 1040 | Background behind every crafting stage: a dark rustic kitchen, worktop in soft focus |
| 2 | `heat/pot.png` | 800 × 460 | Copper jam pot, front view, open top (jam is painted into the opening) |
| 3 | `stir/pot_top.png` | 924 × 924 | The same pot seen from directly above |
| 4 | `fill/jar.png` | 560 × 704 | Empty glass jam jar, front view, glass see-through |
| 5 | `seal/lid.png` | 760 × 760 | Gold jar lid seen from directly above |
| 6 | `prepare/board.png` | 1400 × 680 | Wooden chopping board, top-down |
| 7 | `harvest/bg.jpg` | 2000 × 1120 | Orchard at golden hour, out of focus |
| 8 | `harvest/branch.png` | 2400 × 240 | One long leafy branch, base on the left |
| 9 | `fruit/<fruit>.png` + `_unripe` / `_rotten` / `_cut` | 256 × 256 each | Realistic fruit for picking and slicing |

## Everything the game reads

### Shared
| File | Size | Notes |
|---|---|---|
| `kitchen_bg.jpg` | 2000 × 1040 | Used by every crafting stage unless that stage has its own `bg.jpg` |
| `jam_texture.jpg` | 1024 × 1024 | **Greyscale** close-up of jam: glossy, with fruit pieces and seeds. The game tints it with each recipe's colour and uses its bright spots as highlights. A default texture is already included. |

### Preparation stage (`prepare/`)
| File | Size | Notes |
|---|---|---|
| `bg.jpg` | 2000 × 1040 | Optional background just for this stage |
| `board.png` | 1400 × 680 | Wooden chopping board seen from above |
| `knife.png` | 440 × 120 | Kitchen knife with the **tip pointing left** at the marked spot. It replaces the mouse cursor. |

### Cooking stage (`heat/`)
| File | Size | Notes |
|---|---|---|
| `bg.jpg` | 2000 × 1040 | Optional stage background |
| `stove.png` | 960 × 220 | Gas hob or cast-iron burner, front view. Flames are drawn by the game. |
| `pot.png` | 800 × 460 | **The open top must line up with the pink ellipse in the template** (centre 400,116, width 592, height 108). That's where the game paints the bubbling jam. |
| `pot_front.png` | 800 × 460 | Optional. Only the front lip of the rim; everything else transparent. It's drawn over the jam for depth. |

### Stirring stage (`stir/`)
| File | Size | Notes |
|---|---|---|
| `pot_top.png` | 924 × 924 | Pot seen from directly above. Jam is painted inside the circle at centre 462,462, radius 410. |
| `spoon.png` | 600 × 160 | Wooden spoon from above, **bowl on the left**, handle to the right |

### Filling stage (`fill/`)
| File | Size | Notes |
|---|---|---|
| `jar.png` | 560 × 704 | Glass jar, front view. **Glass must be see-through** inside the pink box (x60 y96, 440 × 580), because it's drawn over the jam. Keep reflections and highlights in it. |
| `jar_back.png` | 560 × 704 | Optional back wall of the jar, drawn behind the jam |
| `ladle.png` | 620 × 220 | Steel ladle, side view, **bowl on the left**. The bowl centre (100,110) is where it tilts from. |

### Sealing stage (`seal/`)
| File | Size | Notes |
|---|---|---|
| `jar_top.png` | 1000 × 1000 | Open jar seen from above. The lid sits on the centre. |
| `lid.png` | 760 × 760 | Lid seen from directly above, centred. It rotates as you twist, so avoid directional lighting baked in. |

### Orchard picking (`harvest/`)
| File | Size | Notes |
|---|---|---|
| `bg.jpg` | 2000 × 1120 | Orchard background, out of focus |
| `branch.png` | 2400 × 240 | One straight, leafy branch with its **base on the left** and **tip on the right**. The game bends it to follow each of the four branches. |
| `basket.png` | 300 × 300 | Wicker basket |

### Fruit (`fruit/`)
- **Fruit ids:** `orange apple lemon cherry peach strawberry blueberry blackberry raspberry plum`. The golden fruit is `golden.png`.
- **Files per fruit:**

  | File | What it shows | Used in |
  |---|---|---|
  | `<fruit>.png` | Ripe fruit, 256 × 256, centred, transparent | Picking and slicing |
  | `<fruit>_unripe.png` | Green, unripe version | Picking |
  | `<fruit>_rotten.png` | Bruised, mouldy version | Picking |
  | `<fruit>_cut.png` | Sliced open, showing the inside | Slicing, after a cut |

- **If any of these are missing:** the inventory icons are used instead, recoloured.

## Fine-tuning alignment
If an image lines up slightly wrong, you don't need to redraw it. Edit the numbers in `ART_LAYOUT` at the top of `web/js/art.js`, then restart the resource.

| Stage | Setting | What it controls |
|---|---|---|
| Cooking | `heat.surface` | Centre and radii of the jam in the pot |
| Stirring | `stir.surface` | Centre and radius of the jam circle |
| Filling | `fill.inside` | The rectangle the jam fills |
| Filling | `fill.ladle.pivotX` / `pivotY` | The point the ladle tilts around |
| Slicing / stirring | `knife` / `spoon` | Size and grip point |

## Ready-made image prompts
These work with image generators. Add *"transparent background, PNG, no text"* for cut-outs. For a consistent set, keep the same style line in every prompt:

> **Style line:** *photorealistic, warm moody candlelit kitchen lighting, dark gothic cottagecore, rich colours, high detail, soft shadows*

| File | Prompt |
|---|---|
| `kitchen_bg.jpg` | Dark rustic farmhouse kitchen wall and wooden worktop, dried flowers and copper utensils hanging, shallow depth of field, empty centre, + style line |
| `heat/pot.png` | Hammered copper jam pan with two handles, front view at eye level slightly above the rim so the open top is visible as an empty ellipse, isolated, + style line |
| `stir/pot_top.png` | Hammered copper jam pan seen from directly above, empty, round, isolated, + style line |
| `stir/spoon.png` | Worn wooden spoon seen from above, lying horizontally, bowl on the left, isolated |
| `fill/jar.png` | Empty clear glass jam jar with screw thread, front view, transparent glass with soft reflections, isolated |
| `fill/ladle.png` | Stainless steel ladle, side view, lying horizontally, bowl on the left, isolated |
| `seal/lid.png` | Gold metal jam jar lid seen from directly above, embossed letter V, isolated |
| `seal/jar_top.png` | Open glass jar full of dark berry jam seen from directly above, isolated |
| `prepare/board.png` | Worn oak chopping board seen from directly above, isolated |
| `prepare/knife.png` | Small kitchen paring knife, horizontal, blade pointing left, isolated |
| `harvest/bg.jpg` | Orange orchard at golden hour, Californian countryside, rows of fruit trees, heavily blurred background bokeh |
| `harvest/branch.png` | Single long horizontal fruit tree branch with green leaves, no fruit, isolated |
| `fruit/strawberry.png` | One ripe strawberry, isolated, studio lighting (repeat for each fruit) |
| `fruit/strawberry_unripe.png` | One unripe pale green strawberry, isolated |
| `fruit/strawberry_rotten.png` | One rotten mouldy bruised strawberry, isolated |
| `fruit/strawberry_cut.png` | Strawberry sliced in half showing the inside, isolated |
| `jam_texture.jpg` | Extreme close-up top-down of glossy fruit jam surface with seeds and fruit pieces, flat even lighting, black and white |

Once you've generated the images, place them in the folders above and they'll appear in game.
