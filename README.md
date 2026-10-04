# Chicken Crossing (Roblox)

You're a chicken. Cross a road full of very fast cars, glide over traffic, and shoot eggs out of
your butt to knock other chickens into it. Last chicken (or team) alive wins.

- Design and plan: [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)
- Art brief: [`docs/ASSETS.md`](docs/ASSETS.md)
- **Studio setup (start here):** [`docs/STUDIO_SETUP.md`](docs/STUDIO_SETUP.md)
- Test checklist: [`docs/TESTING.md`](docs/TESTING.md)

## Getting it into Roblox Studio

The code lives in this repo and is synced into Studio with [Rojo](https://rojo.space).

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder
   (installs the Rojo version pinned in `rokit.toml`).
2. Install the Rojo plugin in Studio: run `rojo plugin install`.
3. Run `rojo serve` in this folder.
4. In Studio, open a new **Baseplate**, open the Rojo plugin, and click **Connect**.
5. Run the build command from [`docs/STUDIO_SETUP.md`](docs/STUDIO_SETUP.md) in the command bar,
   and upload the 5 asset files it lists. Then press **Play**. In Studio you can test alone; live servers need 2 players.
   To test multiplayer modes (Teams, Road Rage) use **Test → Clients and Servers** with 2+ players.
6. Save the place, then publish it. In **Game Settings → Places**, set **Max Players to 16**.

## Saving data and Robux

- Player data (coins, cosmetics, stats) saves with ProfileStore (`src/server/Packages`).
  To save in Studio, turn on **Game Settings → Security → Enable Studio Access to API
  Services**; otherwise Studio uses temporary data that resets each test.
- To sell things for Robux, create them in the Creator Dashboard under **Monetization**, then
  paste the ids into `Config.Monetization` in `src/shared/Config.luau`:
  - 3 **Developer Products** for the coin packs (500 / 1500 / 5000 coins),
  - 5 **Developer Products** for the Robux-only items (Rainbow, DiamondEgg, LoveTap, Supernova, Flex),
  - 1 **Game Pass** for VIP (double coins).
  Anything left at `0` shows as "Coming soon" in the shop.

## Controls

| Action | PC | Gamepad | Phone |
|---|---|---|---|
| Jump / glide | Space (hold while falling) | A (hold) | Jump button (hold) |
| Shoot egg | Left click or E (aims at the mouse) | R2 | 🥚 button (aims where the camera looks) |
| Road Rage driver | W/S pick lane, A/D send car | D-pad, X/B | On-screen buttons |
| Emotes | 1–4, or the Emotes button | Emotes button | Emotes button |

## Project layout

```
src/shared/    Config (all tuning numbers), TrafficSchedule (deterministic cars), Modes, Cosmetics,
               AssetIds (paste uploaded ids here), generated UiSprites / SoundSprites indexes
src/builders/  Studio builders: world, lobby, cars, lighting, GUI (run once from the command bar)
src/server/    Services: RoundService (game loop), TrafficService, EggService, DataService, ...
src/client/    Controllers (HUD, shop, traffic, movement, eggs, music, world animation) + Anim,
               Sfx, Sprites, CameraFx helpers
assets/        UiSheet.png, Sfx.ogg and music to upload
tools/         art/audio generators, and preview renderers for the world and GUI
tests/         Plain-Luau tests for code that doesn't need Roblox
```

## Checks

```
luau tests/TrafficSchedule.spec.luau
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
```
(`luau` from luau-lang/luau releases, `luau-lsp` from JohnnyMorganz/luau-lsp releases;
`globalTypes.d.luau` is in the luau-lsp repo under `scripts/`.)
