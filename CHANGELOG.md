# Diabolic UI Forever changelog

## [6.6.6-r3] - 2026-11-14

Alpha prerelease for **WoW Forever 1.60.1 (70938), Interface 16001**.

### Added

- **Stone Light, Stone Dark and Succubus** styles, including orb sculptures, matching action bars, menus, tooltips, stance buttons, minimap and native Damage Meter artwork.
- Compact Crypt Reliquary target and group frames, a centered 3D target portrait with a 2D fallback, and an integrated target-of-target panel.
- Independent combo-point displays at the resource/health orb and, for Stone-family styles, below hostile targets. Point count follows the supported resource maximum.
- Saved per-character artwork positioning with `/succubus X Y` and `/succubusbuttons X Y`, including localized help and reset commands.
- A toggle for retaining Blizzard's standard Damage Meter appearance.

### Changed

- Replaced the separate Diablo 2/effect checkboxes with a live style dropdown, and the secondary/third action-bar checkboxes with a live one/two/three-row dropdown.
- Reworked the minimap XP/rested arc with defined ends, brass edge rails and dividers, hover-only display, and live thickness/transparency settings.
- Added matching Stone-family castbar artwork, larger overlapping icons and consistent side-panel borders.
- Made target aura size independent of target-frame scale and adjusted aura spacing dynamically around the target-of-target frame and castbar.
- Applied the tested Succubus default layout, two action-bar rows, revised scales, frame positions and minimap-button collection settings. World-map player coordinates remain enabled by default.
- Unified Settings and Edit Mode reset values with the canonical addon defaults; preserved explicit pre-dropdown Legacy/Diablo 2 selections during migration.
- Kept native class-resource color selection for the resource orb and native cast-time visibility settings.
- Temporarily disabled the custom player-debuff frame while retaining its saved settings.

### Fixed

- Removed the player-castbar write to Blizzard's `showCastTimeSetting` that tainted the shared Edit Mode refresh and led to native aura/Damage Meter secret-value errors.
- Avoided native Edit Mode scale/anchor overrides that write shared manager state.
- Restored cooldown/state refresh across action-page and druid-form changes, and respected Blizzard's cooldown-number setting.
- Added native incoming-heal prediction to target and group-frame health bars.
- Corrected target level/name/health-text alignment, native level-difficulty colors and player-faction icon placement.
- Corrected side-panel button/slot alignment, hover states, tooltip cursor clearance and party leader-icon positioning.
- Prevented the replaced honor presentation from returning after battleground transitions.
- Made `/diabolicforever taintstop` explicitly disable native capture and report its actual state.

### Validation and remaining limitations

- The reported Edit Mode plus combat reproduction passed on build 70938 after the castbar fix: no new BugGrabber errors or new taint in the checked aura/Damage Meter fields.
- The new defaults were checked with the bundled AceDB for clean installs, new characters and an existing character save; this is separate from in-game testing.
- This remains an alpha. Other classes, extended dungeon/raid combat, combat group changes and individual 3D models still require broader testing.
- The older protected `PlayerSpellsFrame:SetWidth()` report remains pending reproduction.

## [6.6.6-r1] - 2026-11-08

First public **alpha prerelease**, targeting **WoW Forever 1.60.1 (70862), Interface 16001**. This entry consolidates the local Forever development builds into one public release. Broader combat and class-specific testing is still required.

### Added

- Explicit Forever/Camelot detection and modern UI capabilities without changing the client's project identity.
- Diablo-style player health/resource orbs and optional 3D orb models with a visual picker and animation-speed controls.
- Incoming-heal, absorb and heal-absorb rendering using native prediction-calculator outputs.
- A clockwise XP/rested ring inside the minimap, with an empty transparent arc and no shadow.
- Live XP-ring thickness and transparency sliders in the minimap's Edit Mode window, translated in all 12 locales.
- Independent Edit Mode movers for the styled native player castbar and player debuffs, with saved positions and shared selection controls.
- Bounded SavedVariables diagnostics, `/diabolicforever` commands and optional native taint-log capture.

### Changed

- Adapted the interface from the Arahort Edition baseline to Forever's modern aura, cooldown, role and unit-frame APIs.
- Kept native pet controls, stances/forms, totem controls and raid frames where custom replacements are not validated.
- Replaced the native XP bar's visible presentation while preserving its updates, reputation and other status bars; removed the replaced XP system's Edit Mode selection.
- Kept native cast progress, channels and timing while applying custom artwork and enabling cast-time text.
- Retained native minimap rotation, group-finder clicks and menu behavior beneath the custom presentation.
- Updated LibActionButton to pinned upstream minor 168 and Ace3 to a Forever-aware snapshot; retained the custom action-button usability callback.
- Kept oUF 14.2.1 and namespaced LibEditMode 19 with local compatibility patches; isolated Forever proc glow from ordinary shared copies.

### Fixed

- Deferred hiding default main action bars until the replacement bars finish initializing.
- Corrected Forever keybinding-dialog templates and the action-bar settings icon.
- Restored minimap setup, coordinates, tracking and group-finder positioning around native layout updates.
- Corrected castbar artwork sizing, duplicate artwork, timer visibility and Edit Mode selection layering.
- Replaced direct editing of the secret-sized player aura container with a plain configuration-sized mover while retaining native aura contents and cooldowns.
- Reworked MicroMenu hosting, vertical layout, scale, toggle and combat initialization while preserving native button ownership and clicks.
- Corrected backpack/keyring presentation and circular hover, pushed and checked artwork.
- Prepared secure party-header scaling so members created during combat inherit the configured size; deferred initial header creation when loading in combat.
- Updated native error-message and voice handling, including the current vocal-sound API.

### Known issues and testing

- Native Damage Meter paths can still report secret-value comparison errors; this remains under investigation.
- Combat group changes, class mechanics, aura behavior and model availability need more in-game coverage.
- Diagnostic recording is enabled for this alpha and keeps the most recent 150 snapshots. See [TESTING.md](TESTING.md) for checks and reporting instructions.
