# pc-mechanic on Qbox with lation banking society funds

pc-mechanic's server code is escrow-encrypted, so lation banking can't be added
to it directly. Instead, the `qb-banking` folder here is a small bridge
resource. It presents the qb-banking society API, which pc-mechanic already
supports, and forwards every balance, deposit and withdrawal to lation banking.

## Install

1. **Config**: copy `pc-mechanic/config/config.lua` over the one in your
   pc-mechanic resource. Only two lines change:
   - `Config.Framework = "Qbox"`
   - `Config.SocietyBanking = "qb-banking"`
   (`UseExternalBanking` and `SocietyMoneyAccess` were already `true`.)
2. **Bridge**: copy the `qb-banking` folder into `resources/`. Keep the folder
   name exactly `qb-banking`, and don't run the real qb-banking alongside it.
3. **Check the lation export names** in `qb-banking/config.lua`
   (`BridgeConfig.Exports`, `BridgeConfig.LationResource`,
   `BridgeConfig.AccountPrefix`) against lation's docs (Exports > Server).
   These are the only lines you should need to change.
4. **server.cfg order**:
   ```
   ensure oxmysql
   ensure ox_lib
   ensure qbx_core
   ensure lation_ui
   ensure lation_banking
   ensure qb-banking
   ensure pc-mechanic-props
   ensure pc-mechanic
   ```
5. **Job**: make sure `qbx_core/shared/jobs.lua` has a `mechanic` job with
   grades 0-4. pc-mechanic's `Config.Roles` maps to those grades, and
   `Config.MechanicJobs = {"mechanic"}`. The society account in lation must
   use the same name (or `society_mechanic` with `AccountPrefix = "society_"`).

## Test

- Set `BridgeConfig.Debug = true`, restart, then run `bridgetest mechanic` in
  the **server console**. It should print the same balance lation shows for
  the mechanic society.
- In game, deposit or withdraw from the tablet's Management page and confirm
  the lation account changes.
- A red `exports['lation_banking']:X failed` line means an export name in
  `qb-banking/config.lua` is wrong.

Note: when external banking returns 0 or errors, pc-mechanic quietly falls
back to its own `pc_mechanic_business_info.funds` table. If the tablet shows a
balance that doesn't match lation, the bridge isn't connecting. Check the
console.
