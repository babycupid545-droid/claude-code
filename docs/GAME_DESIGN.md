# Why Did The Chicken… — Game Design & Tech Plan

A Roblox elimination game. You're a chicken. Cars fly down many lanes at very high speed.
You can jump high, glide, and shoot eggs out of your butt at other chickens.
Last chicken (or last team) alive wins.

---

## 1. Core loop

```
 ┌──────────┐  vote mode   ┌───────────┐  load map   ┌────────┐
 │  LOBBY   │ ───────────▶ │  INTERMISSION │ ───────▶ │  GAME  │
 └──────────┘   (15 s)     └───────────┘   (5 s)     └────────┘
      ▲                                                  │ hit by car / egg-knocked
      │                                                  ▼
      │          round ends (1 player/team left)   ┌────────────┐
      └──────────────────── results + win effect ◀─│ ELIMINATED │ (spectate)
                                                   └────────────┘
```

Implemented as a **server-side state machine** (`Lobby → Voting → Loading → InRound → Results → Lobby`).
The current state + timer is replicated with attributes on `ReplicatedStorage.RoundState`, so every client UI just
listens to `GetAttributeChangedSignal` — no polling, no custom sync code.

**Recommendation: one place, not two.** Lobby and arena live in the same server; the arena map is cloned from
`ServerStorage.Maps` at round start and destroyed after. TeleportService between a lobby place and a game place adds
5–15 s of loading per round and breaks the "quick rounds with friends" feel. Switch to multi-place only if you later
need 50+ player servers.

---

## 2. Game modes (voted every round)

| Mode | Rules | Why it's fun |
|---|---|---|
| **Solo** | Free-for-all. Last chicken alive. | The base game. |
| **Teams** | Red spawns on one side, Blue on the other. Last team with anyone alive. | Eggs fly *across* the traffic — you shoot over the road. |
| **Rush Hour** *(suggested)* | Traffic starts slow and gets faster/denser every 15 s. | Guaranteed ending, rising tension. |
| **Road Rage** *(suggested)* | When you die, you respawn **as a car driver** and can steer a car within your lane to hunt chickens. | Eliminated players keep playing — fixes the boring "dead, wait 3 min" problem. |
| **Golden Egg** *(suggested)* | Teams. A golden egg sits on each side. Carry the enemy egg back across the road to score; carrier can't glide. First to 3. | Gives crossing the road a real *reason*. |
| **Hot Egg** *(suggested)* | One player holds a ticking egg. Hit someone with it to pass it. Holder when it pops is out. | Chaotic, short rounds. |
| **Crossing Race** *(suggested)* | Not elimination: first to cross the road N times wins. Eggs knock people back. | Lighter mode for new players. |
| **Floor is Lava Road** *(suggested)* | Lanes randomly turn into lava/river; safe lanes shrink. | Map variety with no new code for eggs/cars. |

Voting: 3 random modes are offered each lobby (not all of them — fewer choices = faster votes). Majority wins, ties
are random. Modes are data-driven modules (`Modes/Solo.luau`, `Modes/Teams.luau` …) that implement the same
interface: `setup(players, map)`, `onEliminated(player)`, `checkWinner()`, `cleanup()`. Adding a mode = adding one
file.

---

## 3. Mechanics — how to build each one well

### 3.1 Cars that are *super fast* (the hardest part)
Fast physics parts replicated from the server **look jittery and hit unfairly** because of network latency.
The proven approach (used by most "Crossy Road"-style Roblox games):

1. Server decides a **schedule**: `{lane, spawnTime, speed, carType}` using a seeded RNG, and sends the seed + round
   start time to clients once.
2. **Every client spawns and moves cars locally** (anchored models, CFrame updated in `RunService.Heartbeat`) using
   `workspace:GetServerTimeNow()`, so everyone sees the same car at the same place.
3. **Hits are checked on the server** with the same math: car position is a pure function of time, so the server
   can check "was a car overlapping this chicken at time T" without any car parts existing on the server.
   Allow a small latency forgiveness window.

Result: buttery-smooth 200+ stud/s cars, zero network cost per car, and hits that can't be faked.

### 3.2 Jump high + glide
- High jump: `Humanoid.UseJumpPower = true`, `JumpPower ≈ 90–110`.
- Glide: when the player holds jump while falling, enable a `VectorForce` (or clamp `AssemblyLinearVelocity.Y`
  to e.g. `-8` in a client `Heartbeat`) and play a flapping animation. Movement is owned by the client (characters
  already are), so this feels instant. A stamina bar stops infinite glide.
- Mobile: a dedicated glide button via `ContextActionService:BindAction(..., true)`.

### 3.3 Butt eggs
- Client: on click, plays animation + spawns a **visual** egg immediately (no lag feel), and fires
  `RemoteEvent ShootEgg(origin, direction)`.
- Server: validates (cooldown, origin near the character, alive, in round), then simulates the projectile with
  **raycast stepping** (FastCast-style: each frame, raycast from last position to new position with gravity),
  so fast eggs never pass through targets.
- Server tells all other clients to draw the egg (with the shooter's equipped **egg skin**).
- On hit → server applies the effect (see open question: knockback vs. damage vs. instant out) and fires the hit
  effect with the shooter's **hit effect** cosmetic.

### 3.4 Elimination & spectating
On death the server marks `player:SetAttribute("Alive", false)`, the mode's `onEliminated` runs, and the client
switches to a spectate camera cycling living players. When the round ends everyone is respawned in the lobby.

---

## 4. Cosmetics

| Slot | What it changes | How |
|---|---|---|
| Chicken skin | Character model | Custom `StarterCharacter`-style rig per skin, swapped via `player:LoadCharacter()` with `HumanoidDescription` off; or one rig + texture/MeshPart swaps |
| Egg skin | Projectile mesh/material/trail | Look-up by id when drawing eggs |
| Hit effect | Particles/sound where an egg lands | `ParticleEmitter:Emit(n)` at hit point |
| Win effect | Celebration on the winner | Fireworks/confetti + camera focus on winner during Results |
| Emotes | Animations | `AnimationTrack`s from an emote wheel (keys 1–8 / mobile wheel) |

All cosmetics are defined in **one data table** (`Shared/Cosmetics.luau`): `id, slot, name, rarity, price, assetRef`.
Shop, inventory, equipping, and rendering all read from it.

---

## 5. Data saving
- Use **ProfileStore** (the maintained successor to ProfileService) for player data: coins, owned cosmetics,
  equipped cosmetics, wins, stats. It handles session locking so items can't be duplicated.
- Coins earned per round (participation + placement + egg hits). Robux sales through **Developer Products**
  (coins bundles) and **Game Passes** (e.g. VIP), handled with `MarketplaceService.ProcessReceipt`.

---

## 6. Recommended project setup
- **Rojo** to sync code from this Git repo into Roblox Studio (lets us version everything in Git).
- **Luau** with `--!strict` types.
- **Wally** for packages (ProfileStore, a signal lib).
- Folder layout:
```
src/
  server/         RoundService, ModeService, TrafficService, EggService, DataService, ShopService
    Modes/        Solo, Teams, RushHour, RoadRage, ...
  client/         RoundUI, VoteUI, GlideController, EggController, TrafficRenderer, SpectateCamera, EmoteWheel
  shared/         Cosmetics, Config (speeds, cooldowns), TrafficSchedule (pure functions used by client+server), Remotes
```
- Security rule: **client never decides who got hit or what it owns** — client only asks, server decides.

---

## 7. Build order (milestones)
1. Map greybox + chicken character + jump/glide.
2. Traffic system (deterministic cars + server hit checks).
3. Round state machine + Solo mode + lobby/spectate.
4. Eggs (shoot, hit, knockback/elimination).
5. Voting + Teams mode + 1–2 extra modes.
6. Data saving, coins, shop, cosmetics.
7. Polish: sounds, VFX, mobile controls, UI art.

---

## 8. Decisions
| Question | Decision |
|---|---|
| What does an egg hit do? | **Knockback.** Eggs shove chickens (ideally into traffic). Only cars eliminate. |
| Why cross the road in Solo? | **Shrinking sides.** Sidewalks/safe zones crumble over time, forcing players across. |
| Workflow | **Rojo + this Git repo.** Code lives here, synced into Studio. |
| Cosmetic economy | **Coins + Robux.** Earn coins by playing; sell coin packs + a few Robux-exclusive items. No paid random crates. |

| Max players | **16** per server. |
| Art | Made separately (another Claude chat) following [`ASSETS.md`](ASSETS.md); the game falls back to generated shapes. |
| Mobile | **Supported at launch**: egg button, hold-jump to glide, on-screen driver controls. |
| First extra modes | **Rush Hour** and **Road Rage**. |

## 9. Build status

| Milestone | Status |
|---|---|
| 1. Greybox map, jump + glide | ✅ built (map generated in code) |
| 2. Deterministic traffic + server hit checks | ✅ built, schedule unit-tested |
| 3. Round loop, Solo, lobby, spectate | ✅ built |
| 4. Eggs with knockback | ✅ built |
| 5. Voting, Teams, Rush Hour, Road Rage | ✅ built |
| 6. Data saving, coins, shop, cosmetics | ✅ built (ProfileStore, Robux products, VIP, 5 cosmetic slots) |
| 7. Polish: Studio-built low-poly world + GUI, sprite-sheet UI art, 40 SFX, 3 music loops, tweens | ✅ built |

### Economy (built)
Golden eggs per round: 10 for playing, 5 per 30 s survived, 25 per knockout (the last chicken
to egg someone gets the kill whenever and however they die; the board shows each round's KOs),
50 for a Solo win / 30 each for a team win. VIP doubles round rewards.

Crossings: everyone must reach the other sidewalk before the one they left crumbles. As soon as
every chicken still in the round is across (after at least 3 s), the next crossing starts right
away instead of waiting out the timer.
Shop prices run from 200 (common) to 8000 (legendary); one exclusive per slot is Robux-only.
All numbers are in `Config.Rewards` and `src/shared/Cosmetics.luau`.

### Power-ups and bounty (built)
Every few seconds a glowing pickup appears, mostly in a lane (risky to grab) and sometimes on the
median, near the chickens. Power-ups: **Speed Boots** (faster for 6 s), **Shield** (the next car
only shoves you out of its lane), **Mega Egg** (next egg is huge and hits much harder),
**Extra Feather** (glide refilled and doubled for 8 s). Rarer special eggs load your next 3 eggs:
**Sticky** (target slowed and grounded for 3 s), **Bouncy** (ricochets once off the ground or a car
towards the nearest chicken), **Explosive** (knocks back everyone within 10 studs), **Golden**
(steals 5 golden eggs from the target). The HUD shows what you hold above the egg/stamina bars.
The chicken with the most knockouts this round (2+) wears a crown with a bounty on its head:
20 golden eggs + 10 per knockout it had, paid to whoever knocks it out.
Code: `PowerupService`, `BountyService`, `Shared/Powerups`; numbers in `Config.Powerups` / `Config.Bounty`.

Not yet play-tested in Studio: the code type-checks and builds with Rojo, but Roblox physics and
feel (jump height, glide, car speed, knockback) need tuning in `src/shared/Config.luau`.
