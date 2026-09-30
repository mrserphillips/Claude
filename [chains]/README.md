# [chains] – FiveM addon chains

Three addon clothing resources. They add new drawables, so nothing in the base game is replaced.

| Resource        | Male | Female | Component       |
|-----------------|:----:|:------:|-----------------|
| `bratt_chain`   |      |   ✔    | 7 – Accessories |
| `monster_chain` |  ✔   |   ✔    | 7 – Accessories |
| `esluts_chain`  |      |   ✔    | 7 – Accessories |

## Install

1. Copy the whole `[chains]` folder into your server's `resources/` folder.
2. Add this line to `server.cfg`:
   ```
   ensure [chains]
   ```
   You can also ensure them one by one, e.g. `ensure monster_chain`.
3. Restart the server. Clients download the assets on join.

## Finding them in-game

Each chain is added **after** the last base-game drawable in the
Accessories/Chains slot (component 7), and after any other addon clothing packs
you run. In your clothing menu (illenium-appearance, qb-clothing, fivem-appearance
and so on), scroll to the end of the Accessories list.

## Notes

- Each resource has its own `dlcName` (`mp_f_bratt_chain`, `mp_m_monster_chain`,
  `mp_f_monster_chain`, `mp_f_esluts_chain`), so they don't clash with each other.
- `esluts_chain` is a very heavy model (18 MB .ydd). FiveM may warn in the
  console that it's an oversized asset. Players with low-end PCs may see it
  load late.
- `bratt_chain` model by Kayla Development. Do not re-upload it publicly.
