# Chicken Crossing (Roblox)

You're a chicken. Cross a road full of very fast cars, glide over traffic, and shoot eggs out of
your butt to knock other chickens into it. Last chicken (or team) alive wins.

- Design and plan: [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)
- Art brief: [`docs/ASSETS.md`](docs/ASSETS.md)

## Getting it into Roblox Studio

The code lives in this repo and is synced into Studio with [Rojo](https://rojo.space).

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder
   (installs the Rojo version pinned in `rokit.toml`).
2. Install the Rojo plugin in Studio: run `rojo plugin install`.
3. Run `rojo serve` in this folder.
4. In Studio, open a new **Baseplate**, delete the `Baseplate` part and the default `SpawnLocation`
   from Workspace, open the Rojo plugin, and click **Connect**.
5. Press **Play**. In Studio you can test alone; live servers need 2 players.
   To test multiplayer modes (Teams, Road Rage) use **Test → Clients and Servers** with 2+ players.
6. Save the place, then publish it. In **Game Settings → Places**, set **Max Players to 16**.

## Controls

| Action | PC | Gamepad | Phone |
|---|---|---|---|
| Jump / glide | Space (hold while falling) | A (hold) | Jump button (hold) |
| Shoot egg | Left click or E (aims at the mouse) | R2 | 🥚 button (aims where the camera looks) |
| Road Rage driver | W/S pick lane, A/D send car | D-pad, X/B | On-screen buttons |

## Project layout

```
src/shared/   Config (all tuning numbers), TrafficSchedule (deterministic cars), Modes, Remotes, ...
src/server/   Services: RoundService (game loop), TrafficService, EggService, SidewalkService, ...
src/client/   Controllers: TrafficRenderer, MovementController (glide), EggController, RoundUI, ...
tests/        Plain-Luau tests for code that doesn't need Roblox
```

## Checks

```
luau tests/TrafficSchedule.spec.luau
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
```
(`luau` from luau-lang/luau releases, `luau-lsp` from JohnnyMorganz/luau-lsp releases;
`globalTypes.d.luau` is in the luau-lsp repo under `scripts/`.)
