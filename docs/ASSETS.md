# Art brief (hand this to whoever makes the art)

The game already ships with a full set of art made by its builders and generators:
a low-poly world and cars (built into Studio by the command in `docs/STUDIO_SETUP.md`),
a UI sprite sheet (`assets/ui/UiSheet.png`), 40 sound effects and 3 music loops (`assets/audio`).
This brief is for **replacing or adding** art. Drop objects into these folders in Roblox Studio;
names must match exactly. Nothing here needs code changes.

Regenerate the sheet/sounds with `python3 tools/art/make_ui_sheet.py` and
`python3 tools/audio/make_audio.py` after editing those scripts.

> Tip for an AI chat helping with art: Claude can't upload meshes, but it **can** write a Luau
> script for the Studio **command bar** (View → Command Bar) that builds a model out of Parts
> and puts it in the right folder. Ask for one model per script, and give it the sizes below.

## Folder layout

```
ReplicatedStorage
└── Assets                (Folder)
    ├── Cars              (Folder)  any number of car Models, any names
    │   └── RageCar       (Model)   optional: the Road Rage driver's car
    ├── Chickens          (Folder)  chicken skin rigs, named by skin id (see list below)
    ├── EggSkins          (Folder)  egg projectiles (Part or Model), named by egg skin id
    ├── HitEffects        (Folder)  egg hit effects, named by hit effect id
    ├── WinEffects        (Folder)  winner celebrations, named by win effect id
    ├── Emotes            (Folder)  Animation objects, named by emote id
    ├── Animations        (Folder)
    │   └── Glide         (Animation) played while gliding
    ├── Effects           (Folder)
    │   └── Feathers      chicken squashed by a car
    └── Sounds            (Folder)  Sounds named like any effect in SoundSprites.luau
                                    (CarHorn, Bawk, EggHit, Coin...) replace that effect
ServerStorage
└── Assets                (Folder)
    ├── ArenaDecor        (Model/Folder) trees, buildings, street lamps around the road
    └── LobbyDecor        (Model/Folder) decoration inside the lobby
```

## Cosmetic ids

The full list (names, prices, rarities) is in `src/shared/Cosmetics.luau`. Art must be named
with the **id**:

| Slot | Folder | Ids |
|---|---|---|
| Chicken skin | `Chickens` | Classic, BrownHen, Bantam, Midnight, RubberDuck, Golden, Robo, Rainbow |
| Egg skin | `EggSkins` | ClassicEgg, BrownEgg, SpeckledEgg, EasterEgg, RottenEgg, GoldenEgg, FireballEgg, DiamondEgg |
| Hit effect | `HitEffects` | Splat, FeatherPuff, ConfettiPop, Sparkle, Boom, LoveTap |
| Win effect | `WinEffects` | Confetti, GoldenRain, Fireworks, Pillar, Supernova |
| Emote | `Emotes` | Bawk, Spin, Hop, LayEgg, Dance, Flex |

Anything missing uses a generated stand-in: chickens get a chubby body in the skin's colours
with a beak, comb and tail; eggs are coloured ellipsoids; effects are coloured particles;
emotes are text bubbles, spins and hops.

## Sizes and rules

| Asset | Size (studs) | Rules |
|---|---|---|
| Car | 8 wide × 6 tall × 14 long | Model **pivot at the center** of the car, **front facing -Z** (the pivot's LookVector). Anchoring/collision are handled by the game. Bright colours read best at speed. |
| Chicken rig | about 4 tall | A full character Model: `Humanoid`, `HumanoidRootPart`, and an `Animate` LocalScript (copy one from a default character in Play mode). R15 recommended. Keep it under ~4.5 studs tall so jumping over cars still works. |
| Egg | about 1 × 1 × 1.35 | Long axis along Z. |
| Hit / win effect | — | A ParticleEmitter, or a Folder/Attachment holding several. Emitters with `Enabled = false` are burst once (`EmitCount` attribute, default 30); enabled ones run for the `Duration` attribute (default 3s). |
| Emote / Glide animation | — | R15, must be owned by the game's owner (or group) to play. Emotes play once; Glide loops. |

## Map coordinates (for ArenaDecor)

- The road runs along **X** from -120 to 120, top surface at **Y = 0**.
- 6 lanes, 14 studs each: road covers **Z = -42 … 42**.
- Sidewalks: **Z = -82 … -42** (side A) and **42 … 82** (side B), top at Y = 0.5. Don't put
  solid decor on the sidewalks or the road: they are the play area.
- Tunnels at **X = ±120 … ±126** where cars come out.
- Lobby balcony centered at **(0, 70, -150)**, 90 × 50, looking down at the road.
- Decor should be **Anchored**, and set `CanCollide = false` on anything chickens shouldn't stand on.
