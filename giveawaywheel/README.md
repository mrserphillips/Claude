# giveaway-wheel

QBox script: a table prop with an ox_target option lets players sign up for a giveaway.
An admin runs a chat command to spin a wheel that every online player sees at the same
time, landing on the same winner (chosen server-side so it can't be manipulated).

## Dependencies

- `qbx_core`
- `ox_lib`
- `ox_target`

## Install

1. Drop the `giveaway-wheel` folder into your resources directory.
2. Add `ensure giveaway-wheel` to your `server.cfg` (after `ox_lib`, `ox_target`, `qbx_core`).
3. Open [config.lua](config.lua) and set `Config.Prop.coords` / `heading` to wherever you
   want the table to spawn.
4. Make sure your server.cfg actually grants the ace groups in `Config.AdminGroups`
   (default: `admin`, `god`) to your admins, e.g.:
   ```
   add_ace group.admin command allow
   add_principal identifier.license:xxxxxxxx group.admin
   ```

## Usage

- Players walk up to the table and use the ox_target option to sign up. Each character
  (by citizenid) can only sign up once per round.
- An admin runs `/spinwheel` in chat. If there are at least `Config.MinEntrants` (default 2)
  sign-ups, every connected player's screen shows the wheel spinning and landing on the
  same winner. The list clears automatically after (`Config.ClearAfterSpin`).
- `/cleargiveaway` — wipes the current sign-up list without spinning.
- `/giveawaylist` — admin-only, prints current entrants to the admin's own chat.

## How the sync works

The server picks the winner with `math.random` (not the client), then broadcasts the
full entrant list plus the winner's index to every client in one event. Each client's
wheel is a pure function of that list + index, so they all compute the identical spin
angle and land in the same place — no clock sync needed.

## Files

- [fxmanifest.lua](fxmanifest.lua)
- [config.lua](config.lua) — prop, target, permissions, commands, timing
- [server/main.lua](server/main.lua) — sign-up list, permission checks, winner pick, broadcast
- [client/main.lua](client/main.lua) — spawns the prop, adds the ox_target option, relays spin events to the NUI
- [html/](html/) — the wheel itself (canvas-drawn, CSS-animated)
