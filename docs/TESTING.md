# Getting the game into Studio and testing it

## 1. Get the whole project folder

Rojo needs the **whole folder** with `default.project.json` at the top, not loose files.
Easiest: on GitHub open the repo, switch to the branch `claude/youthful-turing-mc07jj`,
click **Code → Download ZIP**, unzip it, and open that folder in VS Code (**File → Open Folder**).

The folder should look like this:

```
default.project.json
rokit.toml
src/
  client/
  server/
  shared/
docs/
tests/
```

## 2. Start Rojo

Pick **one** of these:

- **VS Code extension** (easiest): install the "Rojo - Roblox Studio Sync" extension, then
  press `Ctrl+Shift+P` → **Rojo: Open menu** → click `default.project.json` to start the server.
- **Terminal**: open a terminal in the project folder and run `rojo serve`.
  You should see `Rojo server listening on port 34872`.

## 3. Connect Studio and build

Follow **`docs/STUDIO_SETUP.md`**: connect Rojo, run the one-line build command in the
command bar, and (optionally) upload the 5 asset files and paste their ids.

**It worked if** the Explorer shows `Workspace > Arena`, `Workspace > Lobby` and
`StarterGui > Hud / Shop / Emotes / Driver`.

## 4. Play

1. Open **View → Output** (errors show up there in red).
2. Press **Play** (F5).

You should see:

- A farm lobby on a floating island, looking down at two 4-lane, two-way roads in the sky.
- A top bar saying **VOTE!** with a timer, and mode cards at the bottom (Solo and Rush Hour;
  Teams and Road Rage need 2 players).
- After the vote and a 5 s countdown, you're on a sidewalk, cars fly past, and the bar says
  **Cross the road!**
- Shop and Emotes buttons on the left, coins above them.

Press **Stop** to end the test.

## 5. Test multiplayer (Teams, Road Rage, eggs hitting people)

**Test** tab → set the dropdown to **2 Players** (or more) → **Start**. Studio opens a server
window plus one window per player. Close them all with **Cleanup** when done.

## 6. Make data save in Studio (optional)

Publish the place once (**File → Publish to Roblox**), then **Game Settings → Security →
Enable Studio Access to API Services**. Without it, coins and items reset every test (that's
fine for testing).

## 7. Save your place

**File → Save to File** (`.rbxl`) or publish it. The place keeps the map art; the code always
comes from this folder through Rojo.

## Test checklist

Tick these off and send back anything that's wrong, plus any red text from Output.

**Lobby and rounds**
- [ ] You spawn in the lobby as a chicken (white body, orange beak, red comb, tail).
- [ ] Voting works and the chosen mode starts after the countdown.
- [ ] Getting hit by a car squashes you (feathers), and you respawn in the lobby.
- [ ] After the round, everyone is back in the lobby and voting starts again.

**Movement**
- [ ] Jumping feels high enough to clear a car with good timing.
- [ ] Holding jump while falling glides; the stamina bar drains and refills on the ground.
- [ ] Cars' lane warning lights turn red just before a car comes out.

**Sidewalks**
- [ ] Solo: around 20 s in, one sidewalk flashes red and drops; falling kills you.
- [ ] Teams: the outer row of both sidewalks crumbles every 25 s.

**Eggs (2+ players)**
- [ ] Clicking shoots an egg from your butt toward the mouse.
- [ ] Hitting another chicken knocks it back; teammates can't be pushed in Teams.
- [ ] Knocking someone into traffic shows "X egged Y to their doom!" and gives coins.

**Modes**
- [ ] Rush Hour: traffic visibly speeds up over time.
- [ ] Road Rage: after dying you get a top-down view; W/S pick a lane, A/D send a red car.

**Look and sound** (after uploading the 5 asset files)
- [ ] Icons show as cartoon images, not emoji.
- [ ] Lobby music, round music, and sudden-death music switch at the right times.
- [ ] Cars have engine sounds, whoosh past you, and lanes beep before a car comes out.
- [ ] Buttons grow on hover and squish when clicked, with click sounds.
- [ ] 3-2-1-GO countdown, results screen with coins counting up, sudden death banner.
- [ ] Sidewalk tiles shake red, then tumble away and rise back up.
- [ ] Windmills spin, islands bob, clouds drift.

**Shop and cosmetics**
- [ ] You get coins after a round ("+10 🪙 for playing" toasts).
- [ ] Buying and equipping a chicken skin respawns you in it.
- [ ] Egg skins, hit effects and win effects show up in game.
- [ ] Emotes play with keys 1–4 or the Emotes button.

**Levels, quests and season pass** (PASS button, bottom left)
- [ ] "+XP" pops above the PASS button after crossings, knockouts and at round end.
- [ ] Levelling up shows the LEVEL UP card, golden sparkles on your chicken and pays eggs.
- [ ] Other players see a small level + title plate above your chicken; WEAR a title in LEVEL.
- [ ] QUESTS shows 3 quests with progress; finishing one pays out with a toast; SWAP works once a day.
- [ ] PASS: tiers fill with XP, CLAIM gives the reward, premium cells stay locked without the pass.
- [ ] Claimed season items appear in the shop (and can be equipped); unclaimed ones don't.

**Phone (Studio: Test tab → Device → pick a phone)**
- [ ] The egg button appears in a round and shoots.
- [ ] Holding the jump button glides.
- [ ] Shop and vote buttons are tappable and fit on screen.

**Tuning**: if something feels too easy or hard (car speed, jump height, glide, knockback,
round length, coin rewards, prices), say which. The numbers are in
`src/shared/Config.luau` and `src/shared/Cosmetics.luau`.
