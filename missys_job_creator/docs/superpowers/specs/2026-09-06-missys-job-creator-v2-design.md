# Missy's Job Creator v2 — Design Specification

Date: 6 September 2026  
Resource: `missys_job_creator`  
Target framework: Qbox / QBX Core  
Primary integrations: ox_lib, ox_target, ox_inventory, oxmysql, qbx_management, Sky (`sky_base` internal society banking), appearance resource when present

## 1. Goal

Turn the current creator into a complete in-city job builder while preserving the systems that already work: QBX jobs, grades, NPCs, business-stock shops, business stashes, txAdmin/ACE access, and Sky society revenue.

v2 adds a reusable world-point system inspired by the strongest job-creator workflows: admins can create the job once, then attach the locations and employee interactions that make the job usable without editing Lua coordinates by hand.

The upgrade must be non-destructive. Existing v1 jobs, NPCs, shops, businesses, stock, and society links remain valid after installing v2.

## 2. UX cleanup

### 2.1 Native NUI confirmations only

All browser-native calls such as `window.confirm`, `window.alert`, or browser prompt windows are removed.

A reusable in-GTA modal component handles:
- delete confirmation;
- destructive import overwrite warnings;
- dependency warnings;
- validation messages that require a choice.

The modal remains inside the FiveM NUI layer and therefore always renders over GTA.

For delete actions, the modal shows the exact entity name and dependency summary. A job with dependencies is not hard-deleted. The UI shows what is blocking deletion and sends the admin to the relevant section instead of opening an external-looking browser dialog.

### 2.2 Main navigation

The top-level creator navigation becomes:

- **Jobs**
- **World Points**
- **NPCs**
- **Businesses**
- **Integrations**

The old standalone Shops workflow remains supported by the backend, but shop configuration is surfaced contextually under the relevant job/business and under NPC role configuration rather than taking a permanent top-level tab.

### 2.3 Search and filters

Every list supports:
- text search;
- enabled/disabled filter;
- linked job filter where applicable;
- type filter for world points;
- compact status indicators.

This prevents the creator becoming unmanageable as the server accumulates jobs and locations.

## 3. Job workspace

Selecting a job opens a job workspace with sections:

- Overview
- Grades
- Locations
- Fleet
- Blips
- Settings
- Export / Duplicate

Existing QBX jobs that were not created by Missy's Job Creator can still be selected as linked jobs for businesses, NPCs, and world points, but only creator-owned jobs expose destructive job editing.

### 3.1 Duplicate Job

`Duplicate Job` copies:
- job settings;
- grades;
- world points;
- fleet configuration;
- job blips;
- point-specific crafting/harvest/process configuration.

It does **not** duplicate:
- society balances;
- live business stock;
- business banking rows;
- existing player job assignments;
- standalone NPCs or NPC shops that could accidentally duplicate economy links.

The admin supplies the new internal job name and display label before the copy is committed.

### 3.2 Export / Import

A job can be exported to a versioned JSON package containing only creator configuration.

The export modal contains a selectable JSON text area and a Copy button. This avoids relying on external browser downloads inside FiveM.

Import accepts pasted JSON and performs a dry validation first. The preview shows:
- package version;
- job name and label;
- number of grades;
- number of points;
- number of blips;
- fleet vehicle count;
- conflicts with existing jobs.

Import never overwrites an existing internal job name silently.

## 4. World Point subsystem

World Points are the core of v2. A point belongs to a QBX job and has one action type plus one presentation type.

### 4.1 Supported action types

1. **Stash** — ox_inventory stash, configurable slots/weight and grade access.
2. **Boss Menu** — opens the configured boss-management integration for allowed grades.
3. **Duty** — toggles the player's duty state for the linked job.
4. **Wardrobe** — opens the detected appearance/clothing resource.
5. **Job Outfit** — applies a job-specific saved outfit configuration through the appearance adapter.
6. **Crafting** — recipes with ingredients, quantities, output, output quantity, and craft time.
7. **Shop** — employee/public shop point without requiring an NPC; can use infinite stock or an existing linked business stock source.
8. **Sell / Market** — accepts configured items from players and pays through a server-authoritative route.
9. **Harvest** — gives configured raw items with server-side cooldown, quantity rules, and optional required tool.
10. **Process** — removes configured ingredients and produces configured outputs after a timed action.
11. **Teleport** — teleports to a configured destination and heading, optionally carrying the current vehicle.
12. **Garage** — spawns and returns temporary job fleet vehicles.

### 4.2 Presentation types

Each World Point can appear as:
- ox_target zone only;
- visible marker;
- NPC;
- prop.

NPC and prop presentations are point-owned. They do not require a separate standalone NPC record unless the admin wants a multi-role NPC such as hiring + shop interactions.

### 4.3 Common point settings

Every point supports:
- label;
- linked job;
- exact coordinates and heading;
- interaction radius;
- enabled/disabled;
- minimum grade;
- optional explicit allowed-grade list;
- duty requirement (`any`, `on duty`, `off duty` where meaningful);
- presentation type;
- icon/interaction text;
- optional hours;
- optional point blip;
- type-specific configuration.

### 4.4 Placement flow

`Place / Move` hides the admin NUI and enters the existing in-world placement mode. The player positions the point/ped/prop and confirms. The NUI then reopens with the captured coordinates.

No coordinate typing is required for normal setup.

## 5. Server-authoritative action handling

The client is never trusted for economy or inventory mutations.

For harvest, process, crafting, shop, and sell actions the server validates:
- the point exists and is enabled;
- the player's current position is within the configured tolerance;
- job and grade access;
- duty requirements;
- required inventory items/tools;
- configured quantities and prices;
- cooldown/rate-limit state;
- available business stock when applicable.

Only after validation does the server remove/add items or money.

## 6. Crafting, Harvest, and Processing

### 6.1 Crafting

A crafting point contains one or more recipes. Each recipe has:
- display label;
- output item;
- output quantity;
- ingredient list;
- craft duration;
- optional minimum grade;
- optional maximum batch count;
- enabled state.

Players can choose quantity where the recipe permits batch crafting. Ingredient totals are recalculated on the server.

### 6.2 Harvest

Harvest rules support:
- output item;
- min/max quantity;
- duration;
- cooldown;
- optional required tool;
- optional tool consumption chance;
- optional maximum carry check.

### 6.3 Process

Process rules behave like crafting but are intended for raw-to-finished chains. They support multiple input items and one or more configured outputs.

## 7. Job Fleet Garage

v2 adds job fleet vehicles only; it does not replace the server's personal/public garage system.

Each job can define fleet vehicles with:
- model;
- display label;
- minimum grade;
- optional plate prefix;
- enabled state.

A Garage World Point defines:
- menu point;
- spawn coordinate + heading;
- return radius;
- allowed fleet entries.

Spawned vehicles are temporary job vehicles. The server/client bridge tracks them so the player can return them and so duplicate spawning can be restricted.

## 8. Blip creator

Jobs can have multiple standalone blips. Each blip supports:
- name;
- coordinates;
- sprite;
- colour;
- scale;
- short-range toggle;
- visibility: public, linked job only, or minimum grade;
- enabled state.

World Points can also define a small optional blip without creating a separate standalone blip record.

## 9. NPCs and Businesses

### 9.1 Existing NPC system stays

Standalone NPCs remain for:
- shop counters;
- hiring;
- external/custom activities;
- multi-purpose interactions.

The v1 ped placement and exact-Z fixes remain intact.

### 9.2 Business stock and society revenue stay intact

Existing business functionality remains:
- real ox_inventory business stock;
- staff-only restocking;
- customer purchases limited to actual stock;
- revenue routed to the linked society account;
- Sky internal banking route for Missy's House.

v2 does not create a second business-money system.

## 10. Integration status page

The Integrations tab reports live resource state and the selected adapter for:
- qbx_core;
- ox_lib;
- ox_inventory;
- ox_target;
- oxmysql;
- qbx_management;
- sky_base;
- supported appearance/clothing resource.

Each row shows:
- Running / Missing / Optional;
- adapter in use;
- short explanation of what feature depends on it.

The page is diagnostic only; it does not modify other resources.

## 11. Data model

Existing v1 tables remain unchanged.

### 11.1 `missys_job_creator_points`

Stores one row per World Point:
- id;
- job_name;
- label;
- point_type;
- presentation_type;
- x/y/z/heading;
- radius;
- access_json;
- presentation_json;
- config_json;
- blip_json;
- hours_json;
- enabled;
- created_at / updated_at.

Type-specific settings are stored in validated JSON to avoid adding a new SQL table for every point action.

### 11.2 `missys_job_creator_blips`

Stores standalone job blips:
- id;
- job_name;
- label;
- x/y/z;
- sprite;
- colour;
- scale;
- short_range;
- access_json;
- enabled.

### 11.3 `missys_job_creator_fleet`

Stores job fleet entries:
- id;
- job_name;
- model;
- label;
- min_grade;
- plate_prefix;
- enabled.

No society balance data is stored by the Job Creator.

## 12. v1 migration and compatibility

The upgrade only uses `CREATE TABLE IF NOT EXISTS` / additive schema changes.

Existing rows are preserved.

Legacy boss points stored in `jobs.settings_json.boss` are migrated once into `missys_job_creator_points` as `boss` points when no equivalent migration marker exists. Runtime boss registration then uses the v2 point handler so the old and new systems do not create duplicate zones.

Existing NPC, shop, and business IDs remain stable.

## 13. Runtime architecture

New modules are separated by responsibility.

### Shared
- `shared/point_types.lua` — supported point types and common defaults.
- existing validation module extended with world-point/package validators.

### Server
- `server/points.lua` — persistence, access validation, and point CRUD.
- `server/point_actions.lua` — server-side economy/inventory action handlers.
- `server/blips.lua` — blip CRUD.
- `server/fleet.lua` — fleet CRUD and temporary vehicle state.
- `server/job_packages.lua` — duplicate/export/import.
- `server/integrations.lua` — live integration status and adapter detection.
- existing jobs/businesses/NPCs/shops modules remain focused on their current domains.

### Client
- `client/points.lua` — point rendering, targets, markers, streamed NPC/prop presentations.
- `client/point_actions.lua` — client-side UI/progress/teleport/wardrobe dispatch.
- `client/blips.lua` — visibility-aware job blips.
- `client/fleet.lua` — fleet menu, spawn/return interaction and entity tracking.
- existing NPC placement code is reused rather than duplicated.

### Web
- reusable modal component;
- job workspace views;
- World Points list/editor;
- fleet/blip editors;
- import/export modal;
- integration status view;
- search/filter controls.

## 14. Performance

Static ox_target zones may remain registered, but NPC/prop point presentations use distance-based streaming so hundreds of configured points do not mean hundreds of permanent local entities.

State refreshes remain event-driven after mutations. The client does not poll the database.

Marker rendering only iterates nearby enabled marker points.

## 15. Error handling

The resource must fail clearly rather than silently.

Examples:
- invalid ped/prop model -> creator toast + console detail;
- missing optional appearance resource -> wardrobe point shows unavailable rather than crashing;
- missing Sky society account -> transaction fails safely and logs the job/account;
- invalid import JSON -> modal shows validation errors before any DB write;
- job delete blocked by dependencies -> dependency modal lists them;
- point action rejected for distance/access -> no inventory/economy mutation.

## 16. Security

All admin mutations keep the current admin permission layer.

World-point gameplay actions use server-side distance/access validation. NUI-supplied item names, quantities, prices, grades, and coordinates are treated as untrusted input and revalidated against the saved point configuration.

Import packages are schema/version validated and size limited before decoding into DB writes.

## 17. Testing and verification

The v2 regression suite will cover at minimum:
- no browser-native `window.confirm` / `window.alert` delete path;
- modal confirm/cancel state behavior;
- v1 schema/data remains readable;
- legacy boss migration is idempotent;
- world-point validation for every supported point type;
- grade/duty/distance access rejection;
- harvest/craft/process server-side inventory math;
- duplicate-job excludes banking/stock/player assignments;
- import rejects invalid/duplicate job names;
- export package version and required fields;
- integration status handles missing optional resources without crashing;
- existing business-stock and Sky society regression tests remain green;
- JS syntax and ZIP integrity checks.

## 18. Explicit non-goals for v2

To avoid overlapping other Missy's House resources, v2 will not add:
- police handcuff/search/escort actions;
- revive/heal actions;
- impound systems;
- weapon licence systems;
- a replacement personal garage;
- a replacement boss-menu/HR system;
- a second society banking ledger.

Those remain owned by the specialist resources already on the server.

## 19. Delivery

The completed delivery will be one replacement `missys_job_creator` resource ZIP with additive SQL handled by the resource's schema loader. Existing data should survive a straight folder replacement and resource/server restart.

Target version: **2.0.0**.
