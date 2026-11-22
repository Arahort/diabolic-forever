# Diabolic UI Forever changelog

## [6.6.6-r9] - 2026-11-22

Hotfix for **WoW Forever 1.60.1 (71037), Interface 16001**.

### Fixed

- Fixed the repeated Party.lua:136 "attempt to index field 'Private' (a nil value)" error introduced in r8, including updates triggered by Edit Mode and the gamepad HUD.
- Removed the group portrait's dependency on the unexported oUF.Private table.
- Matched identical public unit tokens directly and used guarded public Blizzard APIs for aliases, rejecting unavailable, restricted or secret comparison results.
- Retained exclusive 3D/2D visibility and unchanged-unit animation continuity for party, focus and focus-target portraits.

### Validation

- Reproduced the original error without an exported oUF private table and passed Lua 5.1 checks on the correction.
- Checked player/party/focus/focus-target updates, including 182 polling updates per unit, aliases, secret values, unavailable comparisons and offline recovery.
- In-client confirmation after the hotfix remains pending.

## [6.6.6-r8] - 2026-11-22

Release for **WoW Forever 1.60.1 (70938), Interface 16001**.

### Fixed

- Prevented 3D models and 2D fallback portraits from appearing together on party, focus and focus-target frames in all themes.
- Replaced the group portrait's conflicting post-update path with a single owner for model loading and fallback visibility.
- Kept the 2D fallback on a separate parent so it remains visible while the model is transparent; hid it before showing a ready 3D model.
- Hid the Stone-family target's 3D portrait until model readiness is confirmed, eliminating the overlapping loading state.
- Preserved 2D fallback for unavailable/restricted unit identities and failed model loads, and avoided restarting animations on unchanged-unit polling.

### Validation

- Passed Lua 5.1 syntax and isolated transition checks for synchronous/asynchronous loading, repeated updates, unit changes, offline/out-of-range recovery, restricted/secret values and failed loads.
- Checked exclusive visibility after every visibility setter in the controlled scenarios.
- These checks are not an in-client reproduction; further visual and combat-transition testing remains ongoing.

## [6.6.6-r7] - 2026-11-17

Release for **WoW Forever 1.60.1 (70938), Interface 16001**.

### Changed

- Added theme-matched group-finder eye borders for Stone Light, Stone Dark, Succubus, Stone and Bronze, and Stone and Cupper.
- Matched border brightness and metal hues to each theme's actual minimap frame, including the bronze contour lines.
- Preserved the original yellow iris, pupil, texture dimensions and transparency. Legacy and Diablo 2 retain their original eye artwork and tint.
- Restricted the new themes' pulsing glow to the iris so the metal border keeps its intended colour.
- Refreshed the eye artwork when switching themes or when the native group-finder button becomes available; native queue clicks and status handling remain unchanged.

### Validation

- Reviewed static assemblies of all seven minimap/eye combinations.
- Verified Lua 5.1 syntax, theme-switch texture/tint routing, unchanged iris/alpha data and release archive contents.
- Static previews and controlled checks do not replace testing native queue transitions in the client.

## [6.6.6-r6] - 2026-11-16

Release for **WoW Forever 1.60.1 (70938), Interface 16001**.

### Added

- Added **Stone and Bronze** and **Stone and Cupper** to the style selector, including matching action bars, menus, target/group frames, minimap, pet orb and class-themed pet bar.
- Stone and Bronze combines dark stone with bronze contours and inlays, plus new angel/demon sculptures, pulsing eye layers and calibrated artwork/button placement.
- Stone and Cupper uses a separate warm copper palette, including its angel and demon.

### Changed

- Gave Legacy and Diablo 2 combo-point chains their own darker metal palettes while preserving their shapes and transparency.
- Added dedicated dark Legacy Damage Meter borders, skulls, chains, header and row textures. Native class-coloured fills and Blizzard data handling remain unchanged.
- Updated the combo-point setting description in all 12 locales.

### Fixed

- Fixed a texture-ID/RGB overload error when restoring target bars after leaving a Stone-family theme. Single numeric texture IDs, including negative cached IDs, now remain textures.
- Initialized combo points before optional target styling and refreshed point visibility before dependent placement updates, restoring the orb display in Legacy and Diablo 2.
- Corrected Stone and Bronze hand/rim layering and the lower angel/socket junction.
- Added combo-point frame/settings state to diagnostic snapshots.

### Validation

- Reviewed the new themes and combo-point visibility in game; checked the dedicated Legacy meter palette, preserved texture dimensions/alpha, Lua 5.1 syntax and release packaging.
- Developer-only artwork positioning tools are excluded from the public release. Public pet preview commands remain available.
- Wider class, real-pet and combat-transition testing remains ongoing.

## [6.6.6-r5] - 2026-11-15

Release for **WoW Forever 1.60.1 (70938), Interface 16001**.

### Added

- Restored the pet health orb in Forever, including the supported hunter happiness indicator.
- Added compact Trophy Rail pet-bar artwork for all five themes, with hunter, warlock and default class variants and theme-matched metal colours.
- Added a movable pet-bar selection and scale slider in Edit Mode, including a visible preview without an active pet.
- Kept `/diabolicpet` visual testing commands for future development: class previews, adjustable preview health, saved bar/orb positions, automatic orb-position reset and status output. Command help is translated in all 12 locales.
- Added the custom pet unit frame and pet-bar anchor to Forever diagnostic snapshots.

### Fixed

- Retained Blizzard's native pet buttons, event handlers, keybinds, cooldowns and autocast beneath the custom pet-bar artwork.
- Attached each decorative slot to its actual button and scaled the end decorations with button size; added an opaque backing across the full row.
- Kept the pet orb's Retail geometry and exact border alpha mask. Stone Light, Stone Dark and Succubus use their matching border material without additional darkening.
- Matched the pet-orb preview's parent, scale and background layering to the live orb, and refreshed its Retail position when switching between one, two and three action-bar rows.
- Removed the preview's dependence on hidden native button anchors and raised the Edit Mode selection above the preview.
- Restricted protected position/layout changes to out-of-combat execution and automatically closed visual previews when combat starts.

### Validation

- Pet-orb and pet-bar previews were reviewed in game; focused Lua 5.1, layout, command and combat-deferral checks passed.
- Visual previews do not simulate pet actions. Hunter/warlock summon, dismiss, autocast and combat transitions still require testing with a real pet.

## [6.6.6-r4] - 2026-11-14

Release for **WoW Forever 1.60.1 (70938), Interface 16001**.

### Changed

- Promoted the distribution status from Alpha prerelease to Release.
- Updated the GitHub workflow to publish ordinary releases and mark the current release as Latest.
- Updated the status badge, addon metadata and public documentation to match the release status.
- Kept the gameplay code, artwork, defaults and existing testing limitations unchanged from `6.6.6-r3`.

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
