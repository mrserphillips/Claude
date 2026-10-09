# giveaway-wheel

QBox script: a casino lucky wheel prop (`vw_prop_vw_luckywheel_01a` base with the
`vw_prop_vw_luckywheel_02a` disc on top) with ox_target options. Players target it to sign
up for a giveaway; admins target it to spin. Every online player sees the on-screen wheel
spin at the same time and land on the same winner (chosen server-side so it can't be
manipulated), while the disc on the prop physically spins along with it.

## Dependencies

- `qbx_core`
- `ox_lib`
- `ox_target`

## Install

1. Drop the `giveaway-wheel` folder into your resources directory.
2. Add `ensure giveaway-wheel` to your `server.cfg` (after `ox_lib`, `ox_target`, `qbx_core`).
3. Open [config.lua](config.lua) and set `Config.Prop.coords` / `heading` to wherever you
   want the lucky wheel to spawn. If the disc doesn't sit right on the base, tweak
   `Config.Wheel.offset`; set `Config.Wheel.enabled = false` to spawn the base only.
4. Make sure your server.cfg actually grants the ace groups in `Config.AdminGroups`
   (default: `admin`, `god`) to your admins, e.g.:
   ```
   add_ace group.admin command allow
   add_principal identifier.license:xxxxxxxx group.admin
   ```

## Usage

- Players walk up to the lucky wheel and use the **Sign Up for Giveaway** target option.
  Their character name goes on the wheel. Each character (by citizenid) can only sign up
  once per round.
- Admins see three extra target options on the wheel (hidden from everyone else):
  - **Spin the Wheel** — if there are at least `Config.MinEntrants` (default 2) sign-ups,
    every connected player's screen shows the wheel spinning and landing on the same
    winner, and the prop's disc spins too. The list clears automatically after
    (`Config.ClearAfterSpin`).
  - **View Entrants** — shows the current entrants to the admin.
  - **Clear Entrants** — wipes the sign-up list (asks to confirm first).
- The chat commands `/spinwheel`, `/giveawaylist` and `/cleargiveaway` still work as a
  fallback for admins.

## How the sync works

The server picks the winner with `math.random` (not the client), then broadcasts the
full entrant list plus the winner's index to every client in one event. Each client's
wheel is a pure function of that list + index, so they all compute the identical spin
angle and land in the same place — no clock sync needed.

## Files

- [fxmanifest.lua](fxmanifest.lua)
- [config.lua](config.lua) — prop, target, permissions, commands, timing
- [server/main.lua](server/main.lua) — sign-up list, permission checks, winner pick, broadcast
- [client/main.lua](client/main.lua) — spawns the wheel base + disc, adds the ox_target options, spins the disc and relays spin events to the NUI
- [html/](html/) — the wheel itself (canvas-drawn, CSS-animated)
