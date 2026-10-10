# Missy's Job Creator v2

A drop-in QBX/Qbox in-city job builder for Missy's House. v2 keeps the working v1 job/NPC/business-shop systems and adds reusable **World Points**, fleet vehicles, blips, job packages, integration diagnostics, and a cleaned-up NUI that never opens browser-native Windows popups over GTA.

## v2.0.12 — Luna Leaf storefront redesign

- Customer storefront rebuilt to match the Luna Leaf reference layout: circular leaf crest, handwritten header line, line-icon category rail, neon-leaf promo card, featured product card, square-button quantity steppers, trash-icon bag rows, payment-method box and lock/arrow checkout button.
- Product grid and bag list scroll inside a fixed-size window; layout adapts down to 1366×768.
- Missing ox_inventory images hide cleanly instead of showing a broken-image icon; product hearts toggle locally.
- Uses Cormorant Garamond, Crimson Pro and La Belle Aurore from Google Fonts, falling back to Georgia/cursive when offline.

## v2.0.11 — World Point storefront routing

- World Point shops now open the same custom customer storefront as NPC-counter shops instead of the ox_lib context list.
- Luna Leaf / `whitewidow` World Point shops receive the Luna Leaf theme automatically.
- World Point purchases keep their existing server-side stock, payment and society-revenue logic.

## v2.0.10 — Luna Leaf customer storefront

All NPC shops now open the Job Creator custom checkout instead of falling back to the plain ox_inventory shop window. Shops linked to the existing `whitewidow` business key receive the Luna Leaf botanical storefront treatment; the internal job/account key remains unchanged so existing stock and Lation Banking society routing continue to work.


## What's new in v2

- **In-GTA confirmation modals** for delete/import actions. No `window.confirm`, `window.alert`, or browser prompt windows.
- **Job workspace** with Overview, Grades, Locations, Fleet, Blips, Settings, and Export / Duplicate sections.
- **World Points** placed directly in GTA for:
  - Stash
  - Boss Menu
  - Duty
  - Wardrobe
  - Job Outfit
  - Crafting
  - Shop
  - Sell / Market
  - Harvest
  - Process
  - Teleport
  - Garage
- Point presentation can be **ox_target only, marker, NPC, or prop**.
- Point access supports minimum grade, optional explicit allowed grades, duty state, opening hours, and optional point blips.
- **Job Fleet** with temporary job vehicles, grade requirements, plate prefixes, and garage points.
- **Standalone job blips** with public/job/minimum-grade visibility.
- **Duplicate Job** copies creator configuration without copying money, live stock, player assignments, or standalone economy-linked NPCs.
- **Import / Export** uses versioned JSON with validation and conflict protection.
- **Integrations** page shows which required/optional resources the creator can see live.
- Search and filters for larger servers.

## Existing v1 systems preserved

- Real QBX jobs and grades persisted in SQL and restored after restart.
- Existing QBX jobs can be linked without recreating them.
- Persistent standalone NPCs with exact-Z placement.
- Infinite-stock ox_inventory NPC shops.
- Real business-stock NPC shops where customers can buy only what staff actually stocked.
- Staff-only business stock access.
- Shop access modes: public, specific job, or business staff.
- Shop opening hours and cash/bank/Black Money (`black_money`) payment choice.
- Revenue modes: system sink, business account, or business/tax split.
- txAdmin + ACE creator permissions.
- Lation Banking society revenue.

## Upgrade from v1.0.10

1. Stop `missys_job_creator`.
2. Replace the old resource folder with this v2 folder. **Do not delete your existing creator SQL tables.**
3. Start the resource again:

```cfg
ensure missys_job_creator
```

The schema upgrade is additive. v2 creates the new point/blip/fleet/migration tables automatically through oxmysql and keeps the existing jobs, businesses, NPCs, shops, shop items, and stock links.

On first v2 start, the creator performs an idempotent **legacy boss** migration: old creator-owned boss coordinates stored in v1 job settings are converted into Boss Menu World Points once, then marked as migrated so they are not duplicated on later restarts.

If your database user cannot create tables, import `sql/missys_job_creator.sql` manually once before starting v2.

## Dependencies

Required:

- `qbx_core`
- `ox_lib`
- `ox_target`
- `ox_inventory`
- `oxmysql`

Optional integrations:

- `qbx_management` — Boss Menu World Points
- `lation_banking` — Missy's House society revenue
- `illenium-appearance` or `fivem-appearance` — wardrobe/outfit actions

Recommended start order:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_target
ensure ox_inventory
ensure qbx_management
ensure lation_banking
ensure missys_job_creator
```

## Permissions

Normal Qbox admins are accepted through the `admin` ACE object. A custom owner permission can also be used:

```cfg
add_ace group.owner missys.jobcreator allow
add_principal identifier.license:YOUR_LICENSE group.owner
```

Authenticated txAdmin admins are accepted as a fallback when `Config.AllowTxAdmin = true`.

Useful diagnostics:

```text
/jobcreatorperm
/jobcreatortest
```

## Using the creator

Open it in game:

```text
/jobcreator
```

The main navigation is:

**Jobs | World Points | NPCs | Businesses | Integrations**

### Create a job

Create the QBX job and grades first. After saving it, open the job workspace to add locations, fleet vehicles, and blips without editing Lua vectors.

### Create a World Point

1. Open **World Points** or a job's **Locations** section.
2. Pick the linked QBX job and action type.
3. Pick presentation: target, marker, NPC, or prop.
4. Configure grade/duty/hours and the action-specific settings.
5. Click **Place / Move in world**.
6. Position it in GTA and confirm placement.

Normal placement controls use the existing creator placement system. The point is saved at the exact confirmed coordinates rather than applying an artificial Z offset.

### Grade and duty access

Every point can set a minimum grade. You can additionally enter explicit allowed grades such as `0, 2, 4`. When explicit grades are present, only those grades are accepted. Duty can be unrestricted, on-duty only, or off-duty only.

### Crafting / harvest / processing

Crafting recipes support ingredients, output quantity, maximum batch, and craft duration. Harvest supports min/max output, cooldown, optional required tool, and tool-consumption chance. Processing supports multiple inputs and outputs and a maximum batch.

Inventory and economy changes are validated server-side. Client-submitted prices or item counts are not trusted.

### Job fleet garages

Add models under the job's **Fleet** section, then create a **Garage** World Point. Fleet entries support labels, minimum grades, plate prefixes, and enabled state.

Fleet vehicles are **temporary job vehicles**. They are leased through the job garage flow and are not added to player-owned/public garage storage.

### Blips

A job can have multiple standalone blips. Configure sprite, colour, scale, short-range behavior, and visibility (public, linked job only, or minimum grade). World Points can also carry their own small optional blip.


### Black Money payments

Shops and blackmarket-style World Points can use **Cash**, **Bank**, or **Black Money**. The Black Money option uses the `black_money` ox_inventory item as currency. Purchases are validated and removed server-side, and failed deliveries refund the same payment type. Sell/blackmarket payout points can also pay out `black_money`.

For infinite-stock NPC shops, ox_inventory handles `black_money` as an item currency natively. Bank-paid infinite shops use Missy's custom checkout because ox_inventory shop currency does not directly spend the QBX bank balance.

## NPC business shops

Business shops remain contextual under a Business rather than taking a permanent top-level tab.

For a restaurant counter such as White Widow:

1. Create/link the business to the existing QBX job.
2. Place its staff stock access point.
3. Create/place the counter NPC.
4. Open the Business and add a counter Shop.
5. Choose **Real business stock** and the linked business/job.
6. Add the exact ox_inventory item names and prices.

Staff put finished products into the business stash. Customers can only buy the stock that really exists.

Standalone NPC shops still support infinite stock, real business stock, public/job/staff access, opening hours, cash/bank/Black Money (`black_money`) payment, system/business/split revenue, and configurable business split percentage.

## Lation Banking society revenue

Missy's House now uses Lation Banking for society accounts. Lation addresses a society account by the exact job name, so a White Widow business linked to `whitewidow` is credited through:

```lua
exports['lation_banking']:AddAccountMoney(jobName, amount, reason)
```

The Job Creator passes the business job key through unchanged and fails closed if `Config.Revenue.provider = 'lation'` but `lation_banking` is unavailable. It does not silently credit the creator's fallback ledger in that case.

## Duplicate Job

Duplicate Job copies:

- job settings and grades;
- World Points and their action configuration;
- fleet entries;
- standalone job blips.

It deliberately does **not** copy society balances, business stock, player assignments, business banking rows, or standalone NPC shops.

## Import / Export

The Export / Duplicate section can generate a versioned JSON package and copy it to the clipboard. Import validates the JSON first and shows a preview before creation.

Imports never silently overwrite an existing internal job name. Choose a new internal name when there is a conflict.

## Integrations page

Use **Integrations** when something such as boss menus, wardrobe actions, stock, targets, or society revenue is not behaving as expected. The page shows the live resource state for QBX, ox resources, qbx_management, Lation Banking, and supported appearance resources.

`/jobcreatortest` also performs a read-only relationship/module check and prints the results to the server console.

## Important behavior

QBX runtime-created jobs are restored by this resource after restart. You do not need to edit the QBX shared jobs file for creator-owned jobs.

Business-stock purchases are server-authoritative. Price, quantity, access, proximity, stock, carry capacity, and payment are rechecked before delivery. If stock removal or item delivery fails, the transaction is rolled back where possible.

## Troubleshooting

- **Creator says no permission:** run `/jobcreatorperm` and check txAdmin/ACE status.
- **NPC/point is missing:** confirm its model exists and use the in-world Place / Move flow again.
- **Boss point does nothing:** check the **Integrations** tab for `qbx_management`.
- **Wardrobe does nothing:** check which appearance adapter is detected in **Integrations**.
- **Business money does not move:** confirm `lation_banking` is running and `Config.Revenue.provider = 'lation'`.
- **Old boss point missing after upgrade:** check server startup for the legacy boss migration count and run `/jobcreatortest`.

### Standalone markets / blackmarkets

World Point **Shop** and **Sell** markets can be created with **Standalone / No Job** instead of a QBX job. Standalone markets are always public-access at the job layer, while opening hours and payment type still apply. Cash, bank, and `black_money` are supported. If a standalone shop uses business stock or sends revenue to a society account, choose the separate **Business / society link** in the market settings; the market itself remains jobless.




### Player-owned stashes

World Point **Stash** access can be set to **Job / Grades** or **Specific Player**. For **Specific Player**, enter the player's QBX Citizen ID; the stash is saved without a job link and only that citizen can open it. Existing job/grade stashes are unchanged.

### v2.0.9

- World Point stashes can now be restricted to one specific QBX player by Citizen ID instead of requiring a job.
- Player-owned stashes can be completely standalone with no QBX job link.
- Player ownership is checked server-side before use and reinforced with an ox_inventory `openInventory` hook so another client cannot bypass the creator interaction by guessing the stash ID.
- Job/grade stashes continue to work as before.

### v2.0.8

- Fixed business-stock stashes failing with `cannot open inventory` when staff opened stock from a linked NPC counter away from the dedicated stock point.
- Business stock stashes now register every valid access coordinate: the dedicated business stock point plus all enabled linked business-stock NPCs.
- Stock interactions now ask the server to refresh/register the stash immediately before opening it, while preserving QBX job access restrictions.

### v2.0.7

- Moved business/society shop revenue from Sky internal banking to Lation Banking.
- Society deposits now use `exports['lation_banking']:AddAccountMoney(jobName, amount, reason)` with the exact linked QBX job name.
- The Integrations page and `/jobcreatortest` now report `lation_banking` instead of `sky_base`.
- Explicit Lation revenue mode fails closed if `lation_banking` is unavailable, preventing sales from being credited to the wrong ledger.

### v2.0.6

- Increased the per-purchase shop limit from 20 to 200.
- `Config.MaxPurchaseCount` is now the single authoritative cap for NPC custom checkout and World Point shops.
- Customer shop NUI receives the configured server limit instead of hardcoding 20.

### v2.0.5

- Fixed World Point NPC/prop placement handoff so the live Presentation selector is sent explicitly to the client.
- NPC/prop presentations auto-fill the configured default model when the model field is blank.
- Placement now normalizes and validates presentation mode instead of silently falling back to a marker.
- Placement buttons clearly show `Place / Move NPC` or `Place / Move Prop`.

### v2.0.4
- Fixed World Points/creator tabs crashing on sparse database-ID state after deletes/recreates.
- Added sparse-safe row lookup so linked point/shop editors find rows by database ID instead of array position.
- Retains the v2.0.3 standalone-market UI scoping and NPC/prop model fallback fixes.

### v2.0.3

- Fixes World Point editor lockups caused by the standalone-market job selector rerendering non-point forms.
- Blank NPC/prop model fields now fall back to configured defaults for placement previews and persistent world-point entities.
