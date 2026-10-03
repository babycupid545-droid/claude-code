# Art brief (hand this to whoever makes the art)

The game runs with **zero art**: every missing asset falls back to simple generated shapes.
Art is added by dropping objects into these folders in Roblox Studio. Names must match exactly.
Nothing in this list needs code changes.

> Tip for an AI chat helping with art: Claude can't upload meshes, but it **can** write a Luau
> script for the Studio **command bar** (View → Command Bar) that builds a model out of Parts
> and puts it in the right folder. Ask for one model per script, and give it the sizes below.

## Folder layout

```
ReplicatedStorage
└── Assets                (Folder)
    ├── Cars              (Folder)  any number of car Models, any names
    │   └── RageCar       (Model)   optional: the Road Rage driver's car
    ├── Eggs              (Folder)
    │   └── Default       (Part or Model) the egg projectile
    ├── Animations        (Folder)
    │   └── Glide         (Animation) played while gliding
    ├── Effects           (Folder)  each is a ParticleEmitter, or an Attachment/Folder holding several
    │   ├── EggHit        egg splat
    │   ├── Feathers      chicken squashed by a car
    │   └── Win           winner celebration
    └── Sounds            (Folder)  Sounds named like the effects (EggHit, Feathers, Win)
ServerStorage
└── Assets                (Folder)
    ├── ArenaDecor        (Model/Folder) trees, buildings, street lamps around the road
    └── LobbyDecor        (Model/Folder) decoration inside the lobby
```

## Sizes and rules

| Asset | Size (studs) | Rules |
|---|---|---|
| Car | 8 wide × 6 tall × 14 long | Model **pivot at the center** of the car, **front facing -Z** (the pivot's LookVector). Anchoring/collision are handled by the game. Bright colours read best at speed. |
| Egg | about 1 × 1 × 1.35 | Long axis along Z. |
| Glide animation | — | R15, looping, wings out. Must be owned by the game's owner (or group) to play. |
| Effects | — | Emitters should have `Enabled = false`; the game calls `:Emit()` on them. |

## Map coordinates (for ArenaDecor)

- The road runs along **X** from -120 to 120, top surface at **Y = 0**.
- 6 lanes, 14 studs each: road covers **Z = -42 … 42**.
- Sidewalks: **Z = -82 … -42** (side A) and **42 … 82** (side B), top at Y = 0.5. Don't put
  solid decor on the sidewalks or the road: they are the play area.
- Tunnels at **X = ±120 … ±126** where cars come out.
- Lobby balcony centered at **(0, 70, -150)**, 90 × 50, looking down at the road.
- Decor should be **Anchored**, and set `CanCollide = false` on anything chickens shouldn't stand on.

## Coming later (cosmetics milestone)

Chicken skins (a full rig per skin), egg skins, hit effects, win effects and emotes will use
`Assets/Chickens`, `Assets/EggSkins`, `Assets/HitEffects`, `Assets/WinEffects`, `Assets/Emotes`.
The exact format will be added here when that milestone is built.
