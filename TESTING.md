# Testing Diabolic UI Forever

This guide covers public release **6.6.6-r9** on **WoW Forever 1.60.1 (71037), Interface 16001**. Test in the Forever client. Compatibility with another client or build is not implied.

## Before testing

1. Close Forever and back up your current `_forever_/Interface/AddOns/DiabolicUI3/` folder and its SavedVariables if you have used an earlier build.
2. Install the release with the folder name `DiabolicUI3`, then restart the client.
3. Record your class, exact client build, addon version and enabled addons. Keep your existing profile for the first test; compare with a backed-up clean profile only when needed.
4. Start out of combat. Confirm the orbs, target frame, action bars, minimap and Settings panel load before checking combat behavior.

Saved settings normally live at `_forever_/WTF/Account/<account>/SavedVariables/DiabolicUI3.lua`. Preserve them before any reset or profile experiment. Existing settings should survive `/reload` and a normal logout/login.

## In-game checks

| Area | Check |
|---|---|
| Startup | Login, `/reload`, zone changes and logout/login; confirm settings and positions persist. |
| Orbs and styles | Switch styles out of combat and after a queued combat change. Check health/resource colors, death/resurrection and Succubus / Stone and Bronze artwork/eye alignment. Check all seven styles, including pet artwork and one/two/three-row panels. |
| Combo points | Check Legacy/Diablo 2 orb chains and their darker palettes; switch between Stone and non-Stone themes. Confirm hostile-target-only display and the resource-orb option. |
| Damage Meter | In Legacy, confirm the dark metal frame/rows and native player names, values and class colours. Toggle custom styling off/on and check Edit Mode. |
| Prediction | Begin and cancel a heal at partial health; finish a heal; check absorbs, heal absorbs and maximum-health changes. |
| Portrait fallback | Check target, party, focus and focus-target portraits while switching units and when members go offline/out of range and return. Only the 2D fallback should be visible while loading, then only the ready 3D model. Check repeated updates and combat transitions. Enter/leave Edit Mode with both keyboard/mouse and gamepad HUD styles; confirm the r8 Private error does not recur. |
| 3D models | Enable/disable models, choose a model and change speed. Report unavailable models by selection/name. |
| Action bars | Icons, keybinds, cooldowns/charges, flyouts, out-of-range/usability colours and temporary action pages. |
| Native controls | Pet summon/dismiss, autocast, possession, forms/stances and shaman totems, as applicable to your class. |
| Party | Join/leave, invite/remove members during combat, change leader and check that frames retain their size. |
| Auras | Apply/remove auras and check duration/count updates. Change target aura size independently of frame scale. The custom player-debuff frame is currently disabled. |
| Castbar | Normal casts, channels, cancellation and interruption. Move it in Edit Mode; exit while casting and confirm progress/time remain correct. |
| Minimap | Coordinates, tracking, mail and native group-finder clicks after layout changes. Switch all seven themes while the queue eye is visible; check the yellow iris, matching metal border and pulse. Legacy/Diablo 2 retain their original appearance. |
| XP arc | Hover/leave the minimap; gain XP/rested XP; change minimap scale, thickness and transparency live. Check end caps, brass rails and 0%/100% transparency. |
| Other bars | Confirm reputation and other native status bars remain available; the replaced XP presentation should not leave an extra movable region. |
| Menus | Hover the toggle, open/close the custom MicroMenu, then enter/leave combat; check native button clicks and the backpack's circular hover art. |
| Edit Mode | Select, drag, reset and reopen supported elements. Verify shared labels, settings and positions without secret-coordinate errors. |

The previously reported Edit Mode/combat taint reproduction passed after the player-castbar fix on build 70938. Capture fresh logs if aura or Damage Meter secret-value errors recur; this result does not establish compatibility with every class or combat scenario.

## Pet previews

The visual preview commands remain available on every class without an active pet. Select **Diabolic: Pet Bar** in Edit Mode to move the bar or change its scale.

| Command | Effect |
|---|---|
| `/diabolicpet show hunter` | Show the hunter bar and pet orb. |
| `/diabolicpet show warlock` | Show the warlock bar and pet orb. |
| `/diabolicpet show default` | Show the default class variant and pet orb. |
| `/diabolicpet bar hunter` | Show the bar; `warlock` and `default` are also accepted. |
| `/diabolicpet orb 50` | Show the orb at a specified health percentage, from 0 to 100. |
| `/diabolicpet hide` | Close both previews; a real pet remains governed by normal visibility. |
| `/diabolicpet status` | Print the selected preview class, bar position and orb size. |
| `/diabolicpet barpos X Y` | Save the bar's position relative to the bottom centre of the screen. |
| `/diabolicpet orbpos X Y` | Save a manual orb position relative to the bottom centre of the screen. |
| `/diabolicpet orbpos reset` | Restore automatic Retail-style placement beside the health orb for one/two/three rows. |

Preview labels and sample icons are test-only. Preview mode closes when combat starts. A visual preview cannot verify real pet clicks, cooldowns, autocast or summon/dismiss transitions; check those separately with a real pet.

## Diagnostics

Diagnostic recording is enabled in this release and keeps the latest **150 snapshots**. These include client/build information, available APIs, active library versions, relevant frame state and chosen native fallbacks. Secret values are marked rather than evaluated.

| Command | Effect |
|---|---|
| `/diabolicforever snapshot` | Enable recording and add a manual snapshot. |
| `/diabolicforever stop` | Stop ordinary snapshot recording. |
| `/diabolicforever clear` | Clear stored diagnostic snapshots. |
| `/diabolicforever taint` | Start optional detailed native taint capture. |
| `/diabolicforever taintstop` | Disable native taint capture (`taintLog=0`) and print its actual state. |

For a short capture, finish `/reload` first, then enter `/diabolicforever taint` and confirm that the message reports `taintLog=2`. Reproduce the issue, enter `/diabolicforever taintstop`, and then `/reload`. Some addons reset native taint logging during loading, so enable capture after the interface has loaded.

After reproducing a problem, capture a snapshot and use `/reload` or a normal logout to write SavedVariables. The addon cannot force an immediate file write.

- Diagnostic variable: `DiabolicUI3_ForeverLog` inside `_forever_/WTF/Account/<account>/SavedVariables/DiabolicUI3.lua`.
- If BugGrabber is installed, its errors are in the neighbouring `!BugGrabber.lua` file. BugSack can show/copy the error stack in game.
- Optional native capture is written by the client to `_forever_/Logs/taint.log`. Stop capture after reproducing the problem, then `/reload`. If capture is still active, the previous taint-log setting is restored on reload/logout; explicit `taintstop` always disables it.

## Reporting a problem

Open an issue at [Arahort/diabolic-forever](https://github.com/Arahort/diabolic-forever/issues) with:

- Addon version and exact Forever build.
- Class and relevant pet/form/totem state; whether you were in combat or Edit Mode.
- Reproduction steps, expected result and actual result.
- Screenshots, the complete error stack and the diagnostic snapshots from that attempt.
- Enabled addons, and whether the issue also occurs with only Diabolic UI and optional error-reporting addons enabled.

Review diagnostic attachments before sharing. Do not post your full account settings or unrelated private files.
