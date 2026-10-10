# Missy's Job Creator v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `missys_job_creator` from v1.0.10 to a non-destructive v2.0.0 in-city QBX job builder with native NUI confirmations, world points, crafting/harvest/process actions, job fleet garages, blips, job duplicate/import/export, search/filtering, and integration diagnostics while preserving existing NPC shops, business stock, and Sky society revenue.

**Architecture:** Keep the existing v1 modules intact and add focused v2 modules around a shared `MJC.State`. Persist new world-point, fleet, and blip data in additive SQL tables; validate every economy/inventory action server-side; render points/blips/fleet client-side from the broadcast state; and expand the existing NUI into job workspaces and contextual editors rather than replacing the working shop/business backend.

**Tech Stack:** FiveM Lua 5.4, Qbox/QBX Core, ox_lib, ox_target, ox_inventory, oxmysql, qbx_management, Sky `sky_base` internal job balances, vanilla HTML/CSS/ES modules, pytest regression checks, Node syntax checks.

**Spec:** `docs/superpowers/specs/2026-09-06-missys-job-creator-v2-design.md`

## Global Constraints

- Resource name remains exactly `missys_job_creator`.
- Target version is exactly `2.0.0`.
- Upgrade is additive and non-destructive: existing v1 jobs, grades, NPCs, shops, businesses, stock links, and IDs remain readable and valid.
- Sky society revenue continues to use the existing `sky_base` internal job-balance route; no second ledger is introduced.
- All admin mutations continue to use the existing `MJC.Permissions` layer.
- World-point economy/inventory actions are server-authoritative and revalidate distance, job, grade, duty, quantities, and configured item/price data from persisted state.
- No police restraint/search actions, revive/heal, impound, weapon licences, replacement personal garage, replacement boss/HR system, or replacement society banking system are added.
- Browser-native `window.confirm`, `window.alert`, and `window.prompt` must not exist in production web code.

---

## File Structure

### Existing files to modify

- `fxmanifest.lua` — load new shared/client/server modules and set version 2.0.0.
- `config.lua` — v2 defaults for point streaming, action limits, supported appearance adapters, package-size limits.
- `sql/missys_job_creator.sql` — additive points/blips/fleet/migration tables.
- `shared/constants.lua` — package version and point/presentation enums.
- `shared/validation.lua` — common access, point-type, action-config, and package validators.
- `server/schema.lua` — schema execution stays additive; invoke idempotent legacy boss migration after schema load.
- `server/persistence.lua` — load/decode points, blips, fleet and expose lookup helpers.
- `server/jobs.lua` — dependency reporting includes v2 records; old direct boss registration is retired after migration.
- `server/main.lua` — register v2 callbacks/actions and restore all runtime modules.
- `client/main.lua` — register v2 NUI callbacks and bootstrap integration status.
- `client/placement.lua` — reuse placement for point coordinates, prop/NPC preview, and teleport/fleet spawn destinations.
- `web/index.html` — new tabs, modal host, search/filter host.
- `web/state.js` — modal/search/workspace/filter state and draft defaults.
- `web/app.js` — v2 views, modal flow, job workspace, point/fleet/blip/package editors.
- `web/styles.css` — native modal, workspace subnav, status/filter/editor styling.
- `README.md` — v2 install, migration, supported point types, Sky banking note.

### New focused modules

- `shared/point_types.lua` — supported action/presentation definitions and defaults.
- `server/migrations.lua` — idempotent legacy boss-point migration.
- `server/points.lua` — point CRUD, lookup, common access/distance validation.
- `server/point_actions.lua` — stash/boss/duty/wardrobe/outfit/craft/shop/sell/harvest/process/teleport action handlers.
- `server/blips.lua` — blip CRUD.
- `server/fleet.lua` — fleet CRUD and temporary fleet-vehicle lease state.
- `server/job_packages.lua` — duplicate/export/import validation and persistence.
- `server/integrations.lua` — live integration status/adapter detection.
- `client/points.lua` — target zones, markers, point-owned NPC/prop streaming.
- `client/point_actions.lua` — player-facing menus/progress/wardrobe/teleport dispatch.
- `client/blips.lua` — visibility-aware job blips.
- `client/fleet.lua` — fleet menu, spawn/return flow, client entity tracking.
- `tests/test_v2_modal.py`
- `tests/test_v2_schema.py`
- `tests/test_v2_points.py`
- `tests/test_v2_actions.py`
- `tests/test_v2_packages.py`
- `tests/test_v2_integrations.py`
- `tests/test_v2_manifest.py`

---

### Task 1: Replace browser-native confirmations with an in-NUI modal and establish v2 navigation state

**Files:**
- Modify: `web/index.html`
- Modify: `web/styles.css`
- Modify: `web/state.js`
- Modify: `web/app.js`
- Test: `tests/test_v2_modal.py`

**Interfaces:**
- Consumes: existing `post(event, data)` and `ui.bootstrap.state`.
- Produces: `ui.modal`, `openModal(options)`, `closeModal()`, `confirmModal()`, top-level tabs `jobs|points|npcs|businesses|integrations`, and reusable list filters.

- [ ] **Step 1: Write the failing modal regression test**

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_production_ui_uses_native_nui_modal_not_browser_dialogs():
    app = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')
    index = (ROOT / 'web' / 'index.html').read_text(encoding='utf-8')
    assert 'window.confirm' not in app
    assert 'window.alert' not in app
    assert 'window.prompt' not in app
    assert 'id="confirmModal"' in index
    assert 'data-action="modalConfirm"' in index
    assert 'data-action="modalCancel"' in index
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `pytest -q tests/test_v2_modal.py`

Expected: FAIL because `window.confirm` exists and the modal markup does not.

- [ ] **Step 3: Add modal state to `web/state.js`**

```js
export function createModalState() {
  return {
    open: false,
    tone: 'danger',
    title: '',
    message: '',
    details: [],
    confirmLabel: 'Confirm',
    cancelLabel: 'Cancel',
    pendingAction: null,
  };
}

// inside createUiState()
modal: createModalState(),
filters: { text: '', enabled: 'all', job: '', type: 'all' },
workspace: { jobId: null, section: 'overview' },
```

- [ ] **Step 4: Add the modal host and v2 top navigation to `web/index.html`**

```html
<nav class="tabs" aria-label="Creator sections">
  <button data-tab="jobs">Jobs</button>
  <button data-tab="points">World Points</button>
  <button data-tab="npcs">NPCs</button>
  <button data-tab="businesses">Businesses</button>
  <button data-tab="integrations">Integrations</button>
</nav>

<section id="confirmModal" class="modalBackdrop hidden" role="dialog" aria-modal="true">
  <div class="modalCard">
    <p class="eyebrow" id="modalKicker">CONFIRM ACTION</p>
    <h2 id="modalTitle"></h2>
    <p id="modalMessage" class="subtitle"></p>
    <div id="modalDetails" class="modalDetails"></div>
    <div class="modalActions">
      <button class="ghost" data-action="modalCancel">Cancel</button>
      <button class="danger" data-action="modalConfirm">Confirm</button>
    </div>
  </div>
</section>
```

- [ ] **Step 5: Replace `deleteCurrent()` browser confirmation with reusable modal callbacks**

```js
function openModal(options) {
  ui.modal = { ...ui.modal, ...options, open: true };
  renderModal();
}

function closeModal() {
  ui.modal.open = false;
  ui.modal.pendingAction = null;
  renderModal();
}

async function confirmModal() {
  const action = ui.modal.pendingAction;
  closeModal();
  if (typeof action === 'function') await action();
}

function requestDeleteCurrent() {
  const draft = currentDraft();
  const entityName = draft.label || draft.job_name || `#${draft.id}`;
  openModal({
    title: `Delete ${entityName}?`,
    message: 'Linked dependencies are protected. The server will refuse unsafe deletion.',
    confirmLabel: 'Delete',
    pendingAction: () => performDeleteCurrent(),
  });
}
```

- [ ] **Step 6: Add modal and filter styling**

```css
.modalBackdrop { position:absolute; inset:0; display:grid; place-items:center; background:rgba(3,2,3,.72); z-index:50; }
.modalCard { width:min(520px,90vw); padding:22px; border-radius:18px; background:#171016; border:1px solid rgba(234,160,196,.28); box-shadow:0 30px 90px rgba(0,0,0,.65); }
.modalDetails { display:grid; gap:8px; margin:16px 0; color:var(--muted); font-size:12px; }
.modalActions { display:flex; justify-content:flex-end; gap:9px; margin-top:18px; }
.filterBar { display:grid; grid-template-columns:minmax(0,1fr) 120px 160px; gap:8px; padding:10px; border-bottom:1px solid var(--line); }
```

- [ ] **Step 7: Run the modal test and JS syntax check**

Run: `pytest -q tests/test_v2_modal.py && node --check web/app.js && node --check web/state.js`

Expected: PASS.

- [ ] **Step 8: Commit the UX foundation**

```bash
git add web/index.html web/styles.css web/state.js web/app.js tests/test_v2_modal.py
git commit -m "feat: add in-game creator confirmations"
```

---

### Task 2: Add the v2 additive schema, persistence shape, and idempotent legacy boss migration

**Files:**
- Modify: `sql/missys_job_creator.sql`
- Create: `server/migrations.lua`
- Modify: `server/schema.lua`
- Modify: `server/persistence.lua`
- Modify: `server/jobs.lua`
- Modify: `fxmanifest.lua`
- Test: `tests/test_v2_schema.py`
- Test: existing `tests/test_enabled_flags.py`

**Interfaces:**
- Produces state maps: `MJC.State.points`, `MJC.State.blips`, `MJC.State.fleet`.
- Produces lookup helpers: `findPoint(id)`, `pointsForJob(jobName)`, `fleetForJob(jobName)`, `blipsForJob(jobName)`.
- Produces `MJC.Migrations.legacyBossPoints()` returning migrated count.

- [ ] **Step 1: Write the failing schema regression test**

```python
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = (ROOT / 'sql' / 'missys_job_creator.sql').read_text(encoding='utf-8')


def test_v2_schema_is_additive():
    for table in ('missys_job_creator_points', 'missys_job_creator_blips', 'missys_job_creator_fleet', 'missys_job_creator_migrations'):
        assert f'CREATE TABLE IF NOT EXISTS `{table}`' in SQL
    assert 'DROP TABLE' not in SQL.upper()
    assert 'TRUNCATE TABLE' not in SQL.upper()


def test_legacy_boss_migration_has_marker():
    text = (ROOT / 'server' / 'migrations.lua').read_text(encoding='utf-8')
    assert 'legacy_boss_points_v2' in text
    assert 'INSERT IGNORE INTO missys_job_creator_migrations' in text
```

- [ ] **Step 2: Run the schema test and verify it fails**

Run: `pytest -q tests/test_v2_schema.py`

Expected: FAIL because the tables/module do not exist.

- [ ] **Step 3: Append additive SQL tables**

```sql
CREATE TABLE IF NOT EXISTS `missys_job_creator_points` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `point_type` VARCHAR(24) NOT NULL,
  `presentation_type` VARCHAR(16) NOT NULL DEFAULT 'target',
  `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `radius` DOUBLE NOT NULL DEFAULT 2.0,
  `access_json` LONGTEXT NULL,
  `presentation_json` LONGTEXT NULL,
  `config_json` LONGTEXT NULL,
  `blip_json` LONGTEXT NULL,
  `hours_json` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_mjc_point_job` (`job_name`), KEY `idx_mjc_point_type` (`point_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_blips` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL, `label` VARCHAR(64) NOT NULL,
  `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
  `sprite` INT NOT NULL DEFAULT 1, `colour` INT NOT NULL DEFAULT 0,
  `scale` DOUBLE NOT NULL DEFAULT 0.8, `short_range` TINYINT(1) NOT NULL DEFAULT 1,
  `access_json` LONGTEXT NULL, `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`), KEY `idx_mjc_blip_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_fleet` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL, `model` VARCHAR(64) NOT NULL, `label` VARCHAR(64) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0, `plate_prefix` VARCHAR(8) NULL, `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`), KEY `idx_mjc_fleet_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_migrations` (
  `migration_key` VARCHAR(64) NOT NULL,
  `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`migration_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 4: Implement legacy boss migration**

```lua
MJC = MJC or {}
MJC.Migrations = {}

function MJC.Migrations.legacyBossPoints()
    local key = 'legacy_boss_points_v2'
    if MySQL.scalar.await('SELECT migration_key FROM missys_job_creator_migrations WHERE migration_key = ?', { key }) then return 0 end
    local jobs = MySQL.query.await('SELECT job_name, label, settings_json FROM missys_job_creator_jobs') or {}
    local migrated = 0
    for i = 1, #jobs do
        local settings = MJC.Validation.decode(jobs[i].settings_json, {})
        local boss = settings.boss
        if boss and boss.enabled and boss.x and boss.y and boss.z then
            MySQL.insert.await([[
                INSERT INTO missys_job_creator_points
                (job_name,label,point_type,presentation_type,x,y,z,heading,radius,access_json,config_json,enabled)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,1)
            ]], { jobs[i].job_name, (jobs[i].label or jobs[i].job_name) .. ' Boss Menu', 'boss', 'target', boss.x, boss.y, boss.z, boss.heading or 0, 2.0, json.encode({ minGrade = 0, duty = 'any' }), json.encode({}) })
            migrated = migrated + 1
        end
    end
    MySQL.insert.await('INSERT IGNORE INTO missys_job_creator_migrations (migration_key) VALUES (?)', { key })
    return migrated
end
```

- [ ] **Step 5: Extend persistence loading/decoding**

```lua
local points = MySQL.query.await('SELECT * FROM missys_job_creator_points ORDER BY id') or {}
for i = 1, #points do
    points[i].access = MJC.Validation.decode(points[i].access_json, {})
    points[i].presentation = MJC.Validation.decode(points[i].presentation_json, {})
    points[i].config = MJC.Validation.decode(points[i].config_json, {})
    points[i].blip = MJC.Validation.decode(points[i].blip_json, {})
    points[i].hours = MJC.Validation.decode(points[i].hours_json, { enabled = false })
end

MJC.State.points = byId(points)
MJC.State.blips = byId(MySQL.query.await('SELECT * FROM missys_job_creator_blips ORDER BY id') or {})
MJC.State.fleet = byId(MySQL.query.await('SELECT * FROM missys_job_creator_fleet ORDER BY id') or {})
```

- [ ] **Step 6: Retire legacy runtime boss registration after migration**

Change `server/jobs.lua` so `restore()` only restores QBX jobs; boss interactions are owned by the v2 point runtime. Keep `settings_json.boss` readable for compatibility but do not call `qbx_management:RegisterBossMenu` from `J.restore()`.

- [ ] **Step 7: Run schema and existing persistence regressions**

Run: `pytest -q tests/test_v2_schema.py tests/test_enabled_flags.py tests/test_existing_business_jobs.py`

Expected: PASS.

- [ ] **Step 8: Commit schema/migration support**

```bash
git add sql/missys_job_creator.sql server/migrations.lua server/schema.lua server/persistence.lua server/jobs.lua fxmanifest.lua tests/test_v2_schema.py
git commit -m "feat: add v2 world data schema"
```

---

### Task 3: Define point types, validation, CRUD, and common server access checks

**Files:**
- Create: `shared/point_types.lua`
- Modify: `shared/constants.lua`
- Modify: `shared/validation.lua`
- Create: `server/points.lua`
- Modify: `server/main.lua`
- Modify: `server/jobs.lua`
- Test: `tests/test_v2_points.py`

**Interfaces:**
- Produces `MJC.PointTypes.ACTIONS` and `MJC.PointTypes.PRESENTATIONS`.
- Produces `MJC.Validation.point(payload)` -> normalized point or `nil,error`.
- Produces `MJC.Points.save(payload)`, `delete(id)`, `dependenciesForJob(jobName)`, `canUse(source, point, distance)`.

- [ ] **Step 1: Write failing point-type and access regression tests**

```python
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def test_all_approved_point_types_are_declared():
    text = (ROOT / 'shared' / 'point_types.lua').read_text(encoding='utf-8')
    for name in ('stash','boss','duty','wardrobe','outfit','crafting','shop','sell','harvest','process','teleport','garage'):
        assert f"'{name}'" in text
    for presentation in ('target','marker','npc','prop'):
        assert f"'{presentation}'" in text


def test_point_server_has_distance_grade_and_duty_gates():
    text = (ROOT / 'server' / 'points.lua').read_text(encoding='utf-8')
    for token in ('GetPlayerPed', 'GetEntityCoords', 'minGrade', 'allowedGrades', 'duty'):
        assert token in text
```

- [ ] **Step 2: Run the focused point test and verify failure**

Run: `pytest -q tests/test_v2_points.py`

Expected: FAIL because the modules do not exist.

- [ ] **Step 3: Define supported point metadata**

```lua
MJC = MJC or {}
MJC.PointTypes = {
    ACTIONS = {
        stash=true,boss=true,duty=true,wardrobe=true,outfit=true,crafting=true,
        shop=true,sell=true,harvest=true,process=true,teleport=true,garage=true,
    },
    PRESENTATIONS = { target=true, marker=true, npc=true, prop=true },
}
```

- [ ] **Step 4: Add normalized point validation**

```lua
function V.point(payload)
    if type(payload) ~= 'table' then return nil, 'Point payload is invalid.' end
    local label, err = V.label(payload.label, 'Point label')
    if not label then return nil, err end
    local jobName, jobErr = V.jobName(payload.job_name)
    if not jobName then return nil, jobErr end
    local pointType = V.trim(payload.point_type)
    if not MJC.PointTypes.ACTIONS[pointType] then return nil, 'Unsupported point type.' end
    local presentation = V.trim(payload.presentation_type)
    if not MJC.PointTypes.PRESENTATIONS[presentation] then return nil, 'Unsupported presentation type.' end
    local p = payload.position or payload
    if not tonumber(p.x) or not tonumber(p.y) or not tonumber(p.z) then return nil, 'Place the point in-world first.' end
    return {
        id = tonumber(payload.id), label = label, job_name = jobName,
        point_type = pointType, presentation_type = presentation,
        x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z), heading = tonumber(p.heading) or 0.0,
        radius = math.max(0.5, math.min(10.0, tonumber(payload.radius) or 2.0)),
        access = type(payload.access) == 'table' and payload.access or { minGrade = 0, duty = 'any' },
        presentation = type(payload.presentation) == 'table' and payload.presentation or {},
        config = type(payload.config) == 'table' and payload.config or {},
        blip = type(payload.blip) == 'table' and payload.blip or {},
        hours = type(payload.hours) == 'table' and payload.hours or { enabled = false },
        enabled = payload.enabled ~= false,
    }
end
```

- [ ] **Step 5: Implement server-side common access/distance gate**

```lua
function P.canUse(source, point, maxDistance)
    if not point or not MJC.Validation.isEnabled(point.enabled) then return false, 'This point is disabled.' end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player unavailable.' end
    local job = player.PlayerData.job or {}
    if job.name ~= point.job_name then return false, 'You do not work here.' end
    local grade = tonumber(job.grade and (job.grade.level or job.grade) or 0) or 0
    local access = point.access or {}
    if grade < (tonumber(access.minGrade) or 0) then return false, 'Your grade cannot use this.' end
    if type(access.allowedGrades) == 'table' and #access.allowedGrades > 0 then
        local allowed = false
        for i = 1, #access.allowedGrades do if tonumber(access.allowedGrades[i]) == grade then allowed = true break end end
        if not allowed then return false, 'Your grade cannot use this.' end
    end
    if access.duty == 'on' and not job.onduty then return false, 'Go on duty first.' end
    if access.duty == 'off' and job.onduty then return false, 'Go off duty first.' end
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local pointCoords = vector3(point.x, point.y, point.z)
    if #(coords - pointCoords) > (maxDistance or point.radius or 3.0) then return false, 'Move closer to the point.' end
    return true, player
end
```

- [ ] **Step 6: Implement CRUD and extend job dependency reporting**

`server/points.lua` persists validated JSON fields; `server/jobs.lua` includes point/blip/fleet counts in `dependenciesForJob(jobName)` so unsafe deletion remains blocked and the NUI modal can surface the returned dependency text.

- [ ] **Step 7: Register point admin callbacks**

```lua
lib.callback.register('missys_job_creator:server:savePoint', function(source, payload)
    return adminMutation(source, MJC.Points.save, payload)
end)
lib.callback.register('missys_job_creator:server:deletePoint', function(source, id)
    return adminMutation(source, MJC.Points.delete, id)
end)
```

- [ ] **Step 8: Run point tests and existing job regressions**

Run: `pytest -q tests/test_v2_points.py tests/test_existing_business_jobs.py tests/test_enabled_flags.py`

Expected: PASS.

- [ ] **Step 9: Commit point CRUD/access foundation**

```bash
git add shared/point_types.lua shared/constants.lua shared/validation.lua server/points.lua server/main.lua server/jobs.lua tests/test_v2_points.py
git commit -m "feat: add world point CRUD and access"
```

---

### Task 4: Implement server-authoritative point actions and client action dispatch

**Files:**
- Create: `server/point_actions.lua`
- Create: `client/point_actions.lua`
- Modify: `server/main.lua`
- Modify: `client/main.lua`
- Modify: `config.lua`
- Test: `tests/test_v2_actions.py`

**Interfaces:**
- Produces callback `missys_job_creator:server:usePoint(pointId, action, payload)`.
- Produces `MJC.PointActions.use(source, pointId, action, payload)` -> `ok,message,data`.
- Client consumes returned `data` only for non-authoritative presentation such as menu contents or teleport destination after validation.

- [ ] **Step 1: Write failing action-security regression tests**

```python
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def test_economy_actions_revalidate_saved_point_and_inventory_server_side():
    text = (ROOT / 'server' / 'point_actions.lua').read_text(encoding='utf-8')
    for token in ('MJC.Points.canUse', 'ox_inventory', 'Search', 'RemoveItem', 'AddItem', 'cooldowns'):
        assert token in text
    assert 'payload.price' not in text


def test_action_module_contains_all_server_authoritative_economy_types():
    text = (ROOT / 'server' / 'point_actions.lua').read_text(encoding='utf-8')
    for action in ('crafting','harvest','process','sell','shop'):
        assert action in text
```

- [ ] **Step 2: Run the action test and verify failure**

Run: `pytest -q tests/test_v2_actions.py`

Expected: FAIL because the action module does not exist.

- [ ] **Step 3: Implement common inventory helpers and cooldowns**

```lua
local cooldowns = {}

local function countItem(source, item)
    return exports.ox_inventory:Search(source, 'count', item) or 0
end

local function canCarry(source, item, count)
    return exports.ox_inventory:CanCarryItem(source, item, count)
end

local function onCooldown(source, pointId, seconds)
    local key = ('%s:%s'):format(source, pointId)
    local now = os.time()
    if (cooldowns[key] or 0) > now then return true end
    cooldowns[key] = now + math.max(0, tonumber(seconds) or 0)
    return false
end
```

- [ ] **Step 4: Implement crafting/process math from saved configuration**

```lua
local function craft(source, point, recipeId, requestedCount)
    local recipes = point.config.recipes or {}
    local recipe
    for i = 1, #recipes do if tostring(recipes[i].id) == tostring(recipeId) then recipe = recipes[i] break end end
    if not recipe or recipe.enabled == false then return false, 'Recipe unavailable.' end
    local count = math.max(1, math.min(tonumber(requestedCount) or 1, tonumber(recipe.maxBatch) or 1))
    for i = 1, #(recipe.ingredients or {}) do
        local ing = recipe.ingredients[i]
        local need = (tonumber(ing.count) or 0) * count
        if countItem(source, ing.item) < need then return false, ('Missing %s.'):format(ing.item) end
    end
    local outputCount = (tonumber(recipe.outputCount) or 1) * count
    if not canCarry(source, recipe.outputItem, outputCount) then return false, 'Not enough inventory space.' end
    for i = 1, #(recipe.ingredients or {}) do
        local ing = recipe.ingredients[i]
        exports.ox_inventory:RemoveItem(source, ing.item, (tonumber(ing.count) or 0) * count)
    end
    exports.ox_inventory:AddItem(source, recipe.outputItem, outputCount)
    return true, 'Crafting complete.'
end
```

- [ ] **Step 5: Implement harvest, sell, and point-shop server mutations**

Harvest quantity is generated from saved `minQuantity/maxQuantity`; sell price is read only from saved `point.config.items`; point shops reuse the existing business-stock/infinite-shop concepts where possible and never accept a client-supplied price.

- [ ] **Step 6: Implement non-economy actions**

- `stash` returns stash ID after access validation and ensures `ox_inventory:RegisterStash` has been called.
- `boss` triggers the configured `qbx_management` interaction only after job/grade access.
- `duty` calls the supported QBX duty toggle server route.
- `wardrobe`/`outfit` return adapter/config data; the client opens/applies through the detected appearance adapter.
- `teleport` returns persisted destination coordinates after server validation; the client moves the ped/vehicle.
- `garage` delegates to Task 7 fleet lease logic.

- [ ] **Step 7: Register a single action callback**

```lua
lib.callback.register('missys_job_creator:server:usePoint', function(source, pointId, action, payload)
    local ok, message, data = MJC.PointActions.use(source, tonumber(pointId), action, payload or {})
    return { ok = ok, message = message, data = data }
end)
```

- [ ] **Step 8: Implement client dispatch with ox_lib menus/progress**

`client/point_actions.lua` calls the single callback, uses `lib.progressCircle` for configured durations, opens `ox_inventory` stash/shop UIs, dispatches wardrobe adapters, and performs validated teleport only when the server responds `ok=true`.

- [ ] **Step 9: Run action and legacy shop/Sky regressions**

Run: `pytest -q tests/test_v2_actions.py tests/test_sky_revenue.py tests/test_enabled_flags.py`

Expected: PASS.

- [ ] **Step 10: Commit action runtime**

```bash
git add server/point_actions.lua client/point_actions.lua server/main.lua client/main.lua config.lua tests/test_v2_actions.py
git commit -m "feat: add server-authoritative point actions"
```

---

### Task 5: Stream/render world points and reuse in-world placement for points, NPCs, props, and destinations

**Files:**
- Create: `client/points.lua`
- Modify: `client/placement.lua`
- Modify: `client/main.lua`
- Modify: `client/interactions.lua`
- Test: extend `tests/test_ped_placement.py`
- Test: `tests/test_v2_manifest.py`

**Interfaces:**
- Consumes `MJC.State.points` and `MJC.PointActions`.
- Produces `MJC.PointClient.refresh(state)`, `clear()`, `startPlacement(draft)`.

- [ ] **Step 1: Write failing client-manifest/runtime checks**

```python
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def test_manifest_loads_v2_point_modules():
    fx = (ROOT / 'fxmanifest.lua').read_text(encoding='utf-8')
    for path in ('shared/point_types.lua','client/points.lua','client/point_actions.lua','server/points.lua','server/point_actions.lua'):
        assert f"'{path}'" in fx


def test_point_peds_and_props_do_not_apply_negative_z_offset():
    text = (ROOT / 'client' / 'points.lua').read_text(encoding='utf-8')
    assert 'point.z - 1.0' not in text
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `pytest -q tests/test_v2_manifest.py tests/test_ped_placement.py`

Expected: FAIL until v2 modules are loaded.

- [ ] **Step 3: Implement target and marker rendering**

`client/points.lua` registers enabled target points through `exports.ox_target:addSphereZone`; marker points are held in a nearby list and drawn only inside `Config.Points.markerDrawDistance`.

- [ ] **Step 4: Implement distance-streamed point NPC/prop presentations**

Use a thread with `Config.Points.entityStreamDistance`; spawn at exact `point.z`, freeze/invincible point-owned NPCs, and delete streamed entities when leaving range or when state refresh removes/disables the point.

- [ ] **Step 5: Reuse placement for point/presentation/destination modes**

Extend `MJC.Placement.start(options)` to accept `kind='point'|'npc'|'prop'|'destination'`, model when applicable, and always return `{x,y,z,heading}` without applying a hidden Z adjustment.

- [ ] **Step 6: Refresh points on state broadcasts and resource restarts**

`client/main.lua` calls `MJC.PointClient.refresh(state)` alongside existing NPC refresh. `onResourceStop` clears point zones/entities/blips/fleet entities owned by the resource.

- [ ] **Step 7: Run placement/manifest checks plus JS checks**

Run: `pytest -q tests/test_v2_manifest.py tests/test_ped_placement.py && node --check web/app.js`

Expected: PASS.

- [ ] **Step 8: Commit point rendering/placement**

```bash
git add client/points.lua client/placement.lua client/main.lua client/interactions.lua fxmanifest.lua tests/test_v2_manifest.py tests/test_ped_placement.py
git commit -m "feat: render and place world points"
```

---

### Task 6: Add standalone blips and visibility rules

**Files:**
- Create: `server/blips.lua`
- Create: `client/blips.lua`
- Modify: `server/main.lua`
- Modify: `client/main.lua`
- Modify: `fxmanifest.lua`
- Test: `tests/test_v2_points.py`

**Interfaces:**
- Produces `MJC.Blips.save/delete` and `MJC.BlipClient.refresh(state)`.
- Blip access schema: `{ mode='public'|'job'|'grade', minGrade=0 }`.

- [ ] **Step 1: Extend point test with blip visibility assertions**

```python
def test_blip_client_supports_public_job_and_grade_visibility():
    text = (ROOT / 'client' / 'blips.lua').read_text(encoding='utf-8')
    for token in ("'public'", "'job'", "'grade'", 'SetBlipSprite', 'SetBlipColour', 'SetBlipScale'):
        assert token in text
```

- [ ] **Step 2: Run the focused test and verify failure**

Run: `pytest -q tests/test_v2_points.py`

Expected: FAIL because `client/blips.lua` does not exist.

- [ ] **Step 3: Implement CRUD validation/persistence**

`server/blips.lua` clamps sprite/colour to non-negative integers, scale to `0.1..5.0`, validates linked job names, and persists `access_json`.

- [ ] **Step 4: Implement client visibility-aware blip refresh**

Create/delete blips when job/grade changes and when state refreshes; public blips are always visible, job blips only for the linked job, grade blips only at/above persisted minimum grade.

- [ ] **Step 5: Register admin callbacks and module manifests**

```lua
lib.callback.register('missys_job_creator:server:saveBlip', function(source, payload)
    return adminMutation(source, MJC.Blips.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteBlip', function(source, id)
    return adminMutation(source, MJC.Blips.delete, id)
end)
```

- [ ] **Step 6: Run blip/manifest regressions**

Run: `pytest -q tests/test_v2_points.py tests/test_v2_manifest.py`

Expected: PASS.

- [ ] **Step 7: Commit blips**

```bash
git add server/blips.lua client/blips.lua server/main.lua client/main.lua fxmanifest.lua tests/test_v2_points.py
git commit -m "feat: add job blip creator runtime"
```

---

### Task 7: Add temporary job fleet garage configuration and lease tracking

**Files:**
- Create: `server/fleet.lua`
- Create: `client/fleet.lua`
- Modify: `server/point_actions.lua`
- Modify: `server/main.lua`
- Modify: `client/main.lua`
- Modify: `fxmanifest.lua`
- Test: `tests/test_v2_actions.py`

**Interfaces:**
- Produces `MJC.Fleet.save/delete`, `listForPlayer(source,jobName)`, `requestLease(source,pointId,fleetId)`, `releaseLease(source,netId)`.
- Lease map keyed by player source prevents duplicate active fleet spawns by default.

- [ ] **Step 1: Extend action tests for fleet restrictions**

```python
def test_fleet_server_tracks_temporary_leases_and_grade_access():
    text = (ROOT / 'server' / 'fleet.lua').read_text(encoding='utf-8')
    for token in ('activeLeases', 'min_grade', 'job_name', 'NetworkGetEntityFromNetworkId'):
        assert token in text
```

- [ ] **Step 2: Run focused test and verify failure**

Run: `pytest -q tests/test_v2_actions.py`

Expected: FAIL because fleet module is absent.

- [ ] **Step 3: Implement fleet CRUD and eligible-list filtering**

Normalize model/label/min grade/plate prefix and return only enabled entries linked to the player's current job and grade.

- [ ] **Step 4: Implement server lease token flow**

Before spawning, server validates the garage point via `MJC.Points.canUse`, validates the requested fleet ID against persisted state, rejects a second active lease, and returns a one-time lease token with persisted model/plate prefix/spawn data.

- [ ] **Step 5: Implement client spawn/return**

Client loads the validated model, creates the temporary vehicle at the persisted garage spawn coordinates, assigns a generated plate using the persisted prefix, sends net ID back to finalise the lease, and returns/deletes only the currently leased entity within the configured return radius.

- [ ] **Step 6: Clean leases on disconnect/resource stop**

Server clears source lease state on `playerDropped`; client deletes local resource-owned fleet vehicle on resource stop when safe.

- [ ] **Step 7: Run action/manifest regressions**

Run: `pytest -q tests/test_v2_actions.py tests/test_v2_manifest.py`

Expected: PASS.

- [ ] **Step 8: Commit fleet garage runtime**

```bash
git add server/fleet.lua client/fleet.lua server/point_actions.lua server/main.lua client/main.lua fxmanifest.lua tests/test_v2_actions.py
git commit -m "feat: add temporary job fleet garages"
```

---

### Task 8: Implement job duplicate/export/import packages without copying money/stock/player assignments

**Files:**
- Create: `server/job_packages.lua`
- Modify: `shared/constants.lua`
- Modify: `shared/validation.lua`
- Modify: `server/main.lua`
- Modify: `client/main.lua`
- Test: `tests/test_v2_packages.py`

**Interfaces:**
- Produces `MJC.JobPackages.export(jobName)` -> package table.
- Produces `validateImport(rawJson)` -> preview or error.
- Produces `import(sourcePackage,newJobName,newLabel)`.
- Produces `duplicate(sourceJobName,newJobName,newLabel)` using export/import internally.

- [ ] **Step 1: Write failing package safety tests**

```python
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def test_package_module_is_versioned_and_excludes_economy_state():
    text = (ROOT / 'server' / 'job_packages.lua').read_text(encoding='utf-8')
    assert 'PACKAGE_VERSION' in text
    for forbidden in ('business_ledger', 'balance', 'assigned member', 'PlayerData'):
        assert forbidden not in text
    for included in ('grades', 'points', 'blips', 'fleet'):
        assert included in text


def test_import_checks_size_and_job_conflicts_before_writes():
    text = (ROOT / 'server' / 'job_packages.lua').read_text(encoding='utf-8')
    assert 'Config.Packages.maxBytes' in text
    assert 'GetJob' in text
    assert 'json.decode' in text
```

- [ ] **Step 2: Run package tests and verify failure**

Run: `pytest -q tests/test_v2_packages.py`

Expected: FAIL because the package module does not exist.

- [ ] **Step 3: Define package contract**

```lua
MJC.Constants.PACKAGE_VERSION = 2

-- export shape
{
  packageVersion = MJC.Constants.PACKAGE_VERSION,
  resource = 'missys_job_creator',
  job = { job_name='example', label='Example', job_type='', default_duty=1, off_duty_pay=0, enabled=1 },
  grades = {},
  points = {},
  blips = {},
  fleet = {},
}
```

- [ ] **Step 4: Implement export and dry validation**

Export strips DB IDs/timestamps and any business/shop/stock/society/player state. Validation rejects packages over `Config.Packages.maxBytes`, malformed JSON, unsupported package version, invalid job names, unsupported point types, invalid fleet/blip rows, and existing target job names.

- [ ] **Step 5: Implement duplicate/import as a transaction**

Use `MySQL.transaction.await` to create the job + grades + points + blips + fleet together; if any write fails, nothing is committed. Duplicate calls export then import with the supplied new internal name/label.

- [ ] **Step 6: Register callbacks**

```lua
lib.callback.register('missys_job_creator:server:exportJob', function(source, jobName)
    if not MJC.Permissions.isAdmin(source) then return { ok=false, error='No permission.' } end
    return MJC.JobPackages.export(jobName)
end)
```

Register equivalent guarded callbacks for `previewImport`, `importJob`, and `duplicateJob`.

- [ ] **Step 7: Run package and legacy regressions**

Run: `pytest -q tests/test_v2_packages.py tests/test_existing_business_jobs.py tests/test_sky_revenue.py`

Expected: PASS.

- [ ] **Step 8: Commit packages**

```bash
git add server/job_packages.lua shared/constants.lua shared/validation.lua server/main.lua client/main.lua tests/test_v2_packages.py
git commit -m "feat: add job duplicate import export"
```

---

### Task 9: Add live integration diagnostics

**Files:**
- Create: `server/integrations.lua`
- Modify: `server/main.lua`
- Modify: `client/main.lua`
- Modify: `config.lua`
- Test: `tests/test_v2_integrations.py`

**Interfaces:**
- Produces `MJC.Integrations.status()` -> array of `{ key,label,state,required,adapter,detail }`.
- Bootstrap includes `integrations` for the admin UI.

- [ ] **Step 1: Write failing integration-status tests**

```python
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def test_integration_status_covers_required_and_optional_resources():
    text = (ROOT / 'server' / 'integrations.lua').read_text(encoding='utf-8')
    for key in ('qbx_core','ox_lib','ox_inventory','ox_target','oxmysql','qbx_management','sky_base'):
        assert key in text
    assert 'appearance' in text.lower()
    assert 'GetResourceState' in text
```

- [ ] **Step 2: Run test and verify failure**

Run: `pytest -q tests/test_v2_integrations.py`

Expected: FAIL because the module does not exist.

- [ ] **Step 3: Implement resource-state detection and appearance adapter selection**

Check required resources directly. For appearance, detect configured candidates in order such as `illenium-appearance`, `qb-clothing`, and `fivem-appearance`; report `Optional` if none are started rather than throwing.

- [ ] **Step 4: Include diagnostics in bootstrap and refresh callback**

```lua
lib.callback.register('missys_job_creator:server:integrations', function(source)
    if not MJC.Permissions.isAdmin(source) then return {} end
    return MJC.Integrations.status()
end)
```

- [ ] **Step 5: Run integration test**

Run: `pytest -q tests/test_v2_integrations.py`

Expected: PASS.

- [ ] **Step 6: Commit diagnostics**

```bash
git add server/integrations.lua server/main.lua client/main.lua config.lua tests/test_v2_integrations.py
git commit -m "feat: add integration diagnostics"
```

---

### Task 10: Build the v2 NUI job workspace, world-point editor, fleet/blip editors, packages UI, search/filters, and integration page

**Files:**
- Modify: `web/state.js`
- Modify: `web/app.js`
- Modify: `web/index.html`
- Modify: `web/styles.css`
- Modify: `client/main.lua`
- Test: `tests/test_v2_modal.py`
- Test: `tests/test_v2_manifest.py`

**Interfaces:**
- Consumes all v2 server/client callbacks from Tasks 3–9.
- Produces top-level tabs `Jobs`, `World Points`, `NPCs`, `Businesses`, `Integrations` and job workspace sections `Overview`, `Grades`, `Locations`, `Fleet`, `Blips`, `Settings`, `Export / Duplicate`.

- [ ] **Step 1: Extend UI regression tests for approved navigation/workspace labels**

```python
def test_v2_navigation_and_job_workspace_exist():
    app = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')
    index = (ROOT / 'web' / 'index.html').read_text(encoding='utf-8')
    for label in ('World Points', 'Integrations'):
        assert label in index or label in app
    for section in ('Overview','Grades','Locations','Fleet','Blips','Settings','Export / Duplicate'):
        assert section in app
```

- [ ] **Step 2: Run UI tests and verify failure**

Run: `pytest -q tests/test_v2_modal.py`

Expected: FAIL until v2 views are implemented.

- [ ] **Step 3: Implement reusable filtered-list helpers**

```js
function filteredRows(rows, type) {
  const text = ui.filters.text.trim().toLowerCase();
  return rows.filter(row => {
    if (ui.filters.enabled !== 'all' && String(isEnabled(row)) !== String(ui.filters.enabled === 'enabled')) return false;
    if (ui.filters.job && (row.job_name || row.business_job || '') !== ui.filters.job) return false;
    if (type === 'point' && ui.filters.type !== 'all' && row.point_type !== ui.filters.type) return false;
    if (!text) return true;
    return `${row.label || ''} ${row.job_name || ''} ${row.point_type || ''}`.toLowerCase().includes(text);
  });
}
```

- [ ] **Step 4: Implement job workspace shell and contextual shop/business links**

Selecting a creator-owned job opens subnavigation; selecting an external QBX-only job allows linking/viewing but hides destructive job editing. Existing standalone shops remain in backend/state, but job/business/NPC editors expose linked shop configuration contextually.

- [ ] **Step 5: Implement World Point editor**

Editor fields include action type, presentation type, linked job, place/move button, label, radius, access/duty/grade settings, hours, optional point blip, presentation-specific model/scenario/prop fields, and action-specific configuration panels.

- [ ] **Step 6: Implement recipe/harvest/process/shop/sell sub-editors**

Provide add/remove rows for ingredients/outputs/items; batch count and duration inputs; required tool/cooldown settings; and never expose a client-side field that can override a saved price during use.

- [ ] **Step 7: Implement Fleet and Blips workspace sections**

Fleet editor: model, label, min grade, plate prefix, enabled. Blip editor: label, place coordinates, sprite, colour, scale, short range, public/job/grade visibility, enabled.

- [ ] **Step 8: Implement Export / Duplicate / Import modals**

Export shows selectable JSON and Copy button using `navigator.clipboard.writeText` with a textarea selection fallback. Import accepts pasted JSON, first calls preview, displays conflicts/counts in the native NUI modal, and only then enables the commit action. Duplicate prompts for the new internal name/label inside the same NUI modal/forms, never browser prompt.

- [ ] **Step 9: Implement Integrations page**

Render status rows with Running/Missing/Optional indicator, adapter, and dependency explanation; add a Refresh button that calls the integration callback.

- [ ] **Step 10: Run UI, JS, and package regressions**

Run: `pytest -q tests/test_v2_modal.py tests/test_v2_packages.py tests/test_v2_integrations.py && node --check web/app.js && node --check web/state.js`

Expected: PASS.

- [ ] **Step 11: Commit full v2 UI**

```bash
git add web/state.js web/app.js web/index.html web/styles.css client/main.lua tests/test_v2_modal.py
git commit -m "feat: add v2 creator workspace"
```

---

### Task 11: Final integration, versioning, docs, full regression suite, and release ZIP

**Files:**
- Modify: `fxmanifest.lua`
- Modify: `README.md`
- Modify: `server/selftest.lua`
- Modify: `config.lua`
- Test: all `tests/*.py`

**Interfaces:**
- Final artifact: `missys_job_creator_v2_0_0.zip` containing one `missys_job_creator/` folder with no `.pytest_cache` or `__pycache__` directories.

- [ ] **Step 1: Set manifest metadata to v2**

```lua
name 'missys_job_creator'
author "Missy's House"
description 'In-city QBX job, world point, NPC and business creator'
version '2.0.0'
```

- [ ] **Step 2: Extend self-test coverage**

`/jobcreatortest` reports module readiness for permissions, state, points, point actions, blips, fleet, integrations, ox_inventory, ox_target, qbx_core, qbx_management, and `sky_base`, without mutating player/business data.

- [ ] **Step 3: Update README with upgrade and feature guidance**

Document direct folder replacement, additive automatic schema creation, legacy boss migration, point types, placement controls, grade/duty access, real business stock, Sky `addJobBalance` route, fleet temporary-vehicle behavior, import/export safety, and troubleshooting via Integrations tab.

- [ ] **Step 4: Run the complete regression suite**

Run: `pytest -q`

Expected: all tests PASS, including existing v1 regressions for NUI closed state, permissions, txAdmin, ped placement, enabled flags, existing QBX business jobs, and Sky revenue.

- [ ] **Step 5: Run JS syntax checks**

Run: `node --check web/app.js && node --check web/state.js`

Expected: both exit 0.

- [ ] **Step 6: Scan production files for forbidden browser dialogs and obsolete banking calls**

Run:

```bash
! grep -RInE 'window\.(confirm|alert|prompt)|addJobMoney|Renewed-Banking' web client server config.lua
```

Expected: exit 0 with no matches.

- [ ] **Step 7: Remove generated caches before packaging**

Run:

```bash
find . -type d \( -name __pycache__ -o -name .pytest_cache \) -prune -exec rm -rf {} +
```

- [ ] **Step 8: Build and verify the ZIP**

Run from the parent directory:

```bash
zip -qr missys_job_creator_v2_0_0.zip missys_job_creator
unzip -t missys_job_creator_v2_0_0.zip
```

Expected: `No errors detected in compressed data`.

- [ ] **Step 9: Inspect release contents**

Run:

```bash
unzip -l missys_job_creator_v2_0_0.zip | grep -E 'missys_job_creator/(fxmanifest.lua|server/points.lua|server/point_actions.lua|client/points.lua|client/fleet.lua|web/app.js|sql/missys_job_creator.sql)'
```

Expected: every listed production file is present once under the single resource folder.

- [ ] **Step 10: Commit release**

```bash
git add fxmanifest.lua README.md server/selftest.lua config.lua
git commit -m "release: missys job creator v2.0.0"
```
