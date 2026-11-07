# Testing Diabolic UI Forever

This guide covers public alpha **6.6.6-r1** on **WoW Forever 1.60.1 (70862), Interface 16001**. Test in the Forever client. Compatibility with another client or build is not implied.

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
| Orbs | Health/resource changes, death, resurrection and switching resource types. |
| Prediction | Begin and cancel a heal at partial health; finish a heal; check absorbs, heal absorbs and maximum-health changes. |
| 3D models | Enable/disable models, choose a model and change speed. Report unavailable models by selection/name. |
| Action bars | Icons, keybinds, cooldowns/charges, flyouts, out-of-range/usability colours and temporary action pages. |
| Native controls | Pet summon/dismiss, autocast, possession, forms/stances and shaman totems, as applicable to your class. |
| Party | Join/leave, invite/remove members during combat, change leader and check that frames retain their size. |
| Auras | Apply/remove debuffs and check duration/count updates. Change icon size, spacing and growth in Edit Mode. |
| Castbar | Normal casts, channels, cancellation and interruption. Move it in Edit Mode; exit while casting and confirm progress/time remain correct. |
| Minimap | Coordinates, tracking, mail and native group-finder clicks after layout changes. |
| XP ring | Gain XP, gain rested XP, change minimap scale, then adjust thickness/transparency live in the Minimap Edit Mode window. Check 0% and 100% transparency. |
| Other bars | Confirm reputation and other native status bars remain available; the replaced XP presentation should not leave an extra movable region. |
| Menus | Hover the toggle, open/close the custom MicroMenu, then enter/leave combat; check native button clicks and the backpack's circular hover art. |
| Edit Mode | Select, drag, reset and reopen supported elements. Verify shared labels, settings and positions without secret-coordinate errors. |

There are known secret-value comparison reports in Blizzard's Damage Meter while this alpha is enabled. Capture the full stack and conditions if they recur; do not treat them as a resolved issue.

## Diagnostics

Diagnostic recording is enabled in this alpha and keeps the latest **150 snapshots**. These include client/build information, available APIs, active library versions, relevant frame state and chosen native fallbacks. Secret values are marked rather than evaluated.

| Command | Effect |
|---|---|
| `/diabolicforever snapshot` | Enable recording and add a manual snapshot. |
| `/diabolicforever stop` | Stop ordinary snapshot recording. |
| `/diabolicforever clear` | Clear stored diagnostic snapshots. |
| `/diabolicforever taint` | Start optional detailed native taint capture. |
| `/diabolicforever taintstop` | Stop native taint capture and restore its previous setting. |

After reproducing a problem, capture a snapshot and use `/reload` or a normal logout to write SavedVariables. The addon cannot force an immediate file write.

- Diagnostic variable: `DiabolicUI3_ForeverLog` inside `_forever_/WTF/Account/<account>/SavedVariables/DiabolicUI3.lua`.
- If BugGrabber is installed, its errors are in the neighbouring `!BugGrabber.lua` file. BugSack can show/copy the error stack in game.
- Optional native capture is written by the client to `_forever_/Logs/taint.log`. Stop capture after reproducing the problem, then `/reload`. The previous taint-log setting is also restored on reload/logout.

## Reporting a problem

Open an issue at [Arahort/diabolic-forever](https://github.com/Arahort/diabolic-forever/issues) with:

- Addon version and exact Forever build.
- Class and relevant pet/form/totem state; whether you were in combat or Edit Mode.
- Reproduction steps, expected result and actual result.
- Screenshots, the complete error stack and the diagnostic snapshots from that attempt.
- Enabled addons, and whether the issue also occurs with only Diabolic UI and optional error-reporting addons enabled.

Review diagnostic attachments before sharing. Do not post your full account settings or unrelated private files.
