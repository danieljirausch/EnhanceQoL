# Changelog

## [8.1.1] - 2026-02-27

### 🐛 Fixed

- Edit Mode/Profile sync: Fixed multiple cases where outdated Edit Mode data could overwrite current AddOn profile values after login or `/reload`.
- Data Panels: Fixed panel settings/position occasionally being restored from stale Edit Mode data instead of the active EQoL profile.
- Mythic+ BR Tracker: Fixed tracker position/size resets caused by stale Edit Mode records.
- Mythic+ Talent Reminder: Fixed Active Build text anchor/size occasionally resetting after profile migration.
- Food Reminder: Fixed anchor/scale resets caused by old Edit Mode values being reapplied.
- Loot Toast anchors: Fixed toast/group loot/renown anchors occasionally jumping back to outdated positions.
- Container Actions button: Fixed anchor position being overwritten by legacy Edit Mode state.
- GCD Bar, Action Tracker, Combat Text: Fixed startup cases where old Edit Mode payloads could reapply outdated layout/style values.
- Resource Bars: Hardened initial Edit Mode apply so current spec/profile settings are kept as the authoritative source.

---

## [8.1.0] - 2026-02-27

### ✨ Added

- Loot Toasts (Major Factions): Added Edit Mode support for the Renown toast anchor, so the toast can be repositioned directly in Edit Mode.

### 🐛 Fixed

- Datapanel: Clamp to screen to avoid out of screen movement.

---

## [8.0.0] - 2026-02-27

### ⚠️ Important Profile Notice

- We changed how profile data is handled to make behavior more consistent and avoid unexpected overwrites when switching Edit Mode layouts.
- In rare cases after updating, some users may notice that parts of their layout-based setup look different than before.
- If that happens, please verify your active EQoL profile and re-import or restore your preferred profile setup once.
- Going forward, profile changes should be easier to understand and more predictable for users.

### ✨ Added

- Unit Frames: Added a full UF profile system.
- Unit Frames (Profiles): You can now set an `Active profile` (per character) and a `Global profile` fallback.
- Unit Frames (Profiles): Added optional spec mapping, so each specialization can auto-switch to a selected UF profile.
- Unit Frames (Profiles): Added create/copy/delete actions on the Profiles page.
- Unit Frames (Profiles): Added quick UF profile switching in the minimap right-click menu.
- Group Frames (Party/Raid): Added optional integration with `HarreksAdvancedRaidFrames`.
- Group Frames (Party/Raid): Added a new `Healer Buff Placement` editor to place healer spell indicators exactly where you want them on frames.
- Group Frames (Party/Raid): You can now create custom indicators with different visual styles (Icon, Square, Bar, Border, Tint) and assign healer spells to them.
- Group Frames (Party/Raid): Indicators can now also be used as reminders when important buffs are missing.
- Group Frames (Party/Raid): Added `/eqol hbp` as a quick shortcut to open the Healer Buff Placement editor, even outside Edit Mode.
- Unit Frames (Player/Class Resources): Added per-resource settings via a new `Resource` dropdown, so anchor/strata/frame level offset/offset/scale can be configured per supported resource type.
- Unit Frames (Player/Class Resources): Added `Visible resources` multi-select listing all supported resources, so you can preconfigure visibility on one character for every resource type.
- Cooldown Panels (Edit Mode): Added support for Macro entries (`MACRO`) via drag & drop (macro list and action bar slots).
- Cooldown Panels: Added support for assisted highlighting.
- Combat Text: Added `Always show combat text` with mode selection (`Only while in combat (+Combat)` or `Always show status (+/-Combat)`).
- Data Panels (Gold stream): Added configurable `Left-click action` (`Toggle gold display` / `Open bags`) and a direct `Gold display` selector (`Character` / `Warband gold`) in stream options.
- Textures: Added a cropped version of Blizzards default texture.
- Font: Added Expressway as a font option.

### 🐛 Fixed

- Unit Frames (Target): Range fade now refreshes correctly when switching directly between out-of-range targets without losing target first.
- Unit Frames: Dead indicator wasn't showing
- Character Frame (Item Comparison): Item level text in the Alt comparison flyout now respects the configured character item-level anchor position instead of defaulting to top-right.
- Character/Inspect Frame: Enchant text now uses the selected item-detail font and outline settings.
- Chat Frame: `Enable chat fading` now applies correctly to additional/undocked chat windows instead of only `ChatFrame1`.
- Data Panels (Item Level stream): Equipped-slot tooltip values now use current equipped item-level detection first, preventing incorrect per-slot values for some items.
- Data Panels (Time stream): Font and text-scale style changes now redraw immediately instead of waiting for the next time tick or `/reload`.
- Tooltips (Raider.IO compatibility): Raider.IO unit-tooltip sections now update reliably while hovering when pressing/releasing modifier keys (`showScoreModifier`), including with EQoL tooltip anchoring enabled.
- Chat History: Missed CHAT_MSG_PARTY_LEADER.

---

## [7.20.0] - 2026-02-22

### ✨ Added

- Unit Frames (Player): Added a primary power type multi-select in Power settings to control which primary resources are allowed to show.
- Unit Frames (Player): Added a secondary power section with the same bar options as Power settings (including detach options) plus a secondary type multi-select.
- Castbars (Unit Frames + Standalone): Added `Use gradient` with `Gradient start color` and `Gradient end color` for cast fill colors.
- Castbars (Unit Frames + Standalone): Added interrupt feedback options for `Show interrupt feedback glow` and `Interrupt feedback color` (default: glow enabled, red feedback color).
- Standalone Castbar: Added `Raid frame` as a relative anchor target; it now auto-anchors to EQOL Raid Frames when enabled, otherwise to Blizzard raid frames.
- Economy (Bank): Added automatic gold balancing with the Warband bank.
- Economy (Bank): Added optional per-character target values and automatic withdraw.
- Economy (Vendor): Added `Ignore Equipment Sets` to Auto-Sell Rules (Uncommon/Rare/Epic) to prevent selling items assigned to equipment sets.
- Cooldown Panels: Keybind display now supports Dominos, Bartender4 and ElvUI action bars (in addition to Blizzard).
- Cooldown Panels (Edit Mode): Added per-panel `Show when` multi-select visibility rules (`combat`, `target`, `group`, `casting`, `mounted`, `skyriding`, `always hidden`).
- Cooldown Panels (Edit Mode): Added visibility rules for `flying` and `not flying`.
- Action Bars (Visibility): Added `When I have a target` as a show rule.
- UI (Frames): Added `Unclamp Blizzard damage meter` to allow moving Blizzard damage meter windows beyond screen edges.
- UI (Frames): Added `Buff Frame` and `Debuff Frame` visibility rules (`No override`, `Mouseover`, `Always hide`).
- Mover: Added `Queue Status Button` as movable frame entry (default: off).
- Resource Bars (Maelstrom Weapon): Added `Separated offset` for segmented/separated bar spacing.
- Resource Bars (Maelstrom Weapon): Added `Keep 5-stack fill above 5` option under `Use 5-stack color` (only enabled when `Use 5-stack color` is active).
- Macros & Consumables (Flask Macro): Added role/spec Flask preferences with `Use role setting` overrides, fleeting-first selection via `Prefer cauldrons`, and usable rank fallback across legacy + Midnight flask tiers.
- Data Panels: Added Time left-click Calendar option, Currency/Talents color options (including separate Talent prefix color).
- Data Panels: Increased max panel width to `5000` to make a screenwide panel.‚

### 🐛 Fixed

- Character Frame: The selected font for item details now applies correctly again (item level, gems, enchants).
- Data Panels: Time stream font and text scale updates now apply reliably.
- Mythic+ (World Map Dungeon Portals): Equippable teleport items now restore the previously worn gear after teleport/zone transition instead of staying equipped.
- Group Frames (Raid): Dynamic layout/viewport scaling now refreshes immediately when roster count crosses `unitsPerColumn`/`maxColumns` thresholds.
- Group Frames: Added missing `Absorb overlay height` and `Heal absorb overlay height` support in Edit Mode settings; both overlay heights now apply correctly and are included in copy/import/export flows.
- Group Frames: Offline/DC visuals (name/status/range fade) now refresh reliably.
- Group Frames (Party/Raid): `CompactRaidFrameManager` is no longer hard-hidden while EQoL group frames are enabled, so Blizzard raid tools can auto-show again based on group state.
- Group Frames (Raid, Edit Mode): `Toggle sample frames` now uses the correct start corner for combined `Growth` + `Group Growth` directions (e.g. `Left` + `Up` starts at bottom-right, matching live raid layout).
- Resource Bars: `Separated offset` now separates segment frames.
- Unit Frames (Profiles): `Profile scope` now includes Party/Raid/Main Tank/Main Assist, and import/export correctly handles Group Frame settings.

---

## [7.19.3] - 2026-02-19

### 🐛 Fixed

- Castbars: Texture secret error
- Mover: Added the missing `Currency Transfer`, so the frame is now available in mover settings.

---

## [7.19.2] - 2026-02-19

### 🐛 Fixed

- Standalone Castbar: Improved performance by only reacting to your own cast events.
- Standalone Castbar: `Failed/Interrupted` feedback now only appears when a cast was actually active.
- Standalone Castbar: `Interrupted` feedback now matches the regular Unit Frame castbar look and timing.
- Standalone Castbar: Empower casts now progress correctly (no reverse behavior) and show stage effects like the regular Unit Frame castbar.
- Castbars (Blizzard style): Fixed Empower visuals so the first segment no longer looks incorrect.
- Standalone Castbar: Fixed duration text visibility during Empower casts.
- Castbars: Releasing Evoker Empower casts now no longer shows an incorrect `Interrupted` message.
- Castbars: `Interrupted` now uses Blizzard interrupt art only for Blizzard default castbar textures; custom textures keep their own look.
- Castbars (UF + Standalone): Missing cast icon textures (e.g. heirloom upgrade casts) now fall back to the Blizzard question mark icon.
- Unit Frames (Target): Detached power bar `Grow from center` now stays correctly centered on the full frame when portrait mode is enabled.
- Unit Frames: Added missing `Strong drop shadow` font outline option in Unit Frame settings and implemented the stronger shadow rendering for text.
- Tooltips: Fixed unit info lines (class color, mount, targeting, item level/spec) sometimes using current target data when hovering the Player frame.
- Tooltips: Re-applied tooltip scale after Login UI scaling on startup to prevent wrong tooltip size after relog/reload.
- Container Actions: Fixed an infinite auto-open retry loop when a container cannot be looted.
- Action Bars: Full button out-of-range coloring now respects the action icon mask again, so the old unmasked rectangle no longer renders over button art.
- Cooldown Panels: Edit Mode font dropdowns now rebuild dynamically from SharedMedia when opened.
- Sound: `Personal crafting order added` extra notification now triggers reliably.

---

## [7.19.1] - 2026-02-18

### 🐛 Fixed

- Standalone Castbar: removed a debug value that hides the setting to enable it

---

## [7.19.0] - 2026-02-18

### ✨ Added

- Button Sink (Minimap toggle): Added an optional click-toggle mode so the flyout opens/closes with left-click instead of hover.
- Combat Text: Added separate Edit Mode color settings for entering combat and leaving combat text.
- Unit Frames: Added detached power bar options `Match health width` and `Grow from center`.
- Unit Frames: Added `Use class color for health backdrop (players)` option for health bar backdrops.
- Unit Frames / Group Frames: Added `Clamp backdrop to missing health` option to switch between legacy full backdrop and clamped backdrop style.
- Unit Frames: Added `Use reaction color for NPC names` option (Target/ToT/Focus/Boss) when custom name color is disabled.
- Unit Frames: Added a `Copy settings` dialog for Player/Target/ToT/Pet/Focus/Boss with selectable sections.
- Cooldown Panels: Added an option to configure the border
- Group Frames: Added `Copy settings` with selectable sections, including copy from Unit Frames (Player/Target/ToT/Pet/Focus/Boss) and cross-copy between Party/Raid/MT/MA.
- Group Frames: Added a dedicated `Settings` section at the top of Edit Mode settings for `Copy settings`.
- Group Frames: Added a `Target highlight` layer selector (`Above border` / `Behind border`) with the current behavior kept as default.
- Standalone Castbar implemented to move and configure in Edit Mode.

### 🐛 Fixed

- LFG additional dungeon filter had a secret error
- Unit Frames (Party): Custom sort was always reset
- Unit Frames (Player): `Always hide in party/raid` now only hides the Player Frame while actually grouped; solo visibility is no longer affected.
- Unit Frames: Absorb/heal-absorb layering now stays below the health border, fixing cases where absorb textures could appear above the border.
- Unit Frames: NPC colors were sometimes wrong
- Group Frames (Party/Raid): Added `Use Edit Mode tooltip position` so unit tooltips can follow the configured Edit Mode anchor instead of showing at the cursor.
- Group Frames (Party): Role icons are now anchored to the frame container instead of the health bar, so icons stay in the correct corner when power bars are hidden for selected roles.
- Group Frames (Party/Raid): Dispel overlay border now stays aligned to the health area when power bars are shown, so it no longer renders outside the frame.
- Chat Frame: Move editbox to top had a secret caching error

---

## [7.18.0] - 2026-02-16

### ✨ Added

- GCD Bar: Added vertical fill directions in Edit Mode (`Bottom to top` and `Top to bottom`).
- Group Frames (Main Tank): Added `Hide myself` option to hide your own unit from MT frames.
- DataPanel: Added LibDataBroker (LDB) stream integration. LDB data objects can now be selected and used directly in Data Panels.

### 🔄 Changed

- GCD Bar: Increased width/height limits for both dimensions.
- GCD Bar: Width and height sliders now allow direct numeric input.

### 🐛 Fixed

- Chat: Fixed a Lua error in `chatEditBoxOnTop` (`'for' limit must be a number`) when temporary chat windows open and edit box anchor points are cached.
- Unit Frames (Auras): Custom aura borders now apply to Target/Boss buffs as expected (not only debuffs), including configured border texture/size/offset behavior.
- Unit Frames (Auras): Fixed a secret-value/taint Lua error in aura border color fallback handling (`canActivePlayerDispel`) during aura updates.
- Group Frames: Name text anchoring no longer shifts upward when a power bar is shown; non-bottom name anchors now stay stable on the full bar group.

---

## [7.17.1] - 2026-02-16

### 🐛 Fixed

- Group Frames: Border offset now expands the border outward, so increasing it no longer makes the actual frame content area smaller.
- Resource Bars: Max color now stays active more reliably on affected classes/specs.
- Unit Frames: Name/level text layering now stays above absorb clip layers, preventing status text from being hidden behind absorb bars.

---

## [7.17.0] - 2026-02-16

### ✨ Added

- Baganator support for Vendor features.
  - The Destroy Queue button is now available directly in the Baganator bag window.
  - Items marked for Auto-Sell or Destroy now show their EnhanceQoL marker in Baganator.
  - The `EnhanceQoL Sell/Destroy` marker can be positioned by the player in Baganator via `Icon Corners`.

### 🐛 Fixed

- Resource Bars: `Use max color` now works reliably.

---

## [7.16.1] - 2026-02-15

### 🐛 Fixed

- Unit Frames: Edit Mode settings max height is now dynamic via screen height.
- Resource Bars: Fixed an issue where changing one spec could overwrite mana/power bar position and size in another spec after reload/spec switches.
- Resource Bars: Improved spec handling so each specialization now keeps its own bar settings reliably.

---

## [7.16.0] - 2026-02-15

### 🔄 Changed

- Button Sink: Increased max columns to 99
- Cooldown Panels: CPE bars can now be anchored directly to Essential and Utility cooldown viewers.

### 🐛 Fixed

- Missing locale
- Resource Bars: Fixed a spec crossover on `/reload` where Edit Mode layout writes could copy spec specific settings to other specs.
- Resource Bars: Edit Mode layout IDs and apply handling are now spec-specific, preventing cross-spec overwrite of bar anchors/sizes.
- Resource Bars: `Use max color` now also works for Runes when all 6 runes are ready.
- Resource Bars: Auto-enable now seeds default bar configs when no global template exists, so new chars/profiles still get bars.

---

## [7.15.5] - 2026-02-14

### 🐛 Fixed

- Group Frames (Party): `Index` sorting now follows the expected party order again (`Player -> party1 -> party2 -> party3 -> party4`).
- Group Frames (Party): `Edit custom sort order` is now available again in Party Edit Mode.

---

## [7.15.4] - 2026-02-14

### 🐛 Fixed

- Cooldown Panels: Anchors to other Cooldown Panels now resolve reliably after reload/login.
- Unit Frames: Fixed overlap issues between detached power bars and class resources by allowing class resource strata/frame level offset adjustments.
- Minimap: After switching Covenants in Shadowlands, the minimap icon now stays in the correct position.
- Auto accept Res: Now checking the ressing unit for combat state
- Resource Bars: Segment color wasn't working
- Resource Bars: Backdrop alpha wasn't working

---

## [7.15.3] - 2026-02-14

### 🐛 Fixed

- Action Bars: Visibility with `Hide while skyriding` is reliable again. Bars no longer remain incorrectly visible after mouseover.
- Instant Messenger: Shift-click links (item/quest/spell) now insert correctly in the IM edit box, including links from bags and the Objective Tracker.
- Resource Bars: Non existend anchor frame could destroy settings config

---

## [7.15.2] - 2026-02-13

- Resource Bar: Separator backdrop was not working

---

## [7.15.1] - 2026-02-13

### 🐛 Fixed

- XML Error

---

## [7.15.0] - 2026-02-13

### ✨ Added

- Unit Frames (Auras): Added sliders to change aura border size and position.
- Unit Frames (Auras): Expanded the slider ranges for more control.
- UI: Added a `4K` login UI scaling preset (`0.3556`).

### 🐛 Fixed

- Resource Bars: Fixed a visual issue where one Holy Power divider could look out of place at certain UI scales.
- Resource Bars: New class/spec bars now keep the position and size from your saved global profile.
- Resource Bars: Edit Mode layouts are now separated by class, so switching classes/profiles no longer mixes bar positions and sizes.
- Resource Bars: Removed legacy layout fallback to prevent old shared layout data from overriding current class-specific settings.
- Action Bars: Added `Always hidden` to action bar visibility rules (including Stance Bar) and fixed Pet Action Bar/Stance Bar visibility resolution so both bars are reliably affected by visibility settings.

---

## [7.14.0] - 2026-02-13

### ✨ Added

- Resource Bars: Added a new text option `Hide percent (%)` for percentage display across health/power/resource bars.

### 🐛 Fixed

- CVar persistence: Removed forced persistence handling for `raidFramesDisplayClassColor` and `pvpFramesDisplayClassColor` to avoid UI update errors while Blizzard unit/nameplate frames refresh.

---

## [7.13.2] - 2026-02-13

### 🐛 Fixed

- Resource Bars: Soul Shards now show correct full values for Affliction and Demonology; decimal shard values remain only for Destruction.
- Vendor: CraftShopper no longer forces to hide `Track recipe`
- Forbidden table error fixes

---

## [7.13.1] - 2026-02-12

### 🐛 Fixed

- Unit Frames: Party/Raid-Frames were not clickthrough for auras and private auras

---

## [7.13.0] - 2026-02-12

### ✨ Added

- Group Frames (Party/Raid/MT/MA): Added Edit Mode `Status icons` section for Ready Check, Summon, Resurrect, and Phasing with per-icon enable, sample toggle, size, anchor, and X/Y offsets.

### 🐛 Fixed

- Unit Frames: Border settings not working
- Unit Frames: Removed raid-style party leader icon hooks (`showLeaderIconRaidFrame`) to prevent taint involving `secureexecuterange`.
- Resource Bars: Atlas texture wasn't applying

---

## [7.12.0] - 2026-02-11

### ✨ Added

- Unit Frames: Added configurable `Castbar strata` + `Castbar frame level offset` (Player/Target/Focus/Boss).
- Unit Frames: Added configurable `Level text strata` + `Level text frame level offset`.
- Unit Frames: Added optional `Party leader icon` indicator for Player/Target/Focus.
- GCD Bar: Added `Match relative frame width` for anchored layouts, including live width sync with the selected relative frame.
- GCD Bar: Anchor target list now focuses on supported EQoL anchors (legacy ActionBar/StanceBar entries removed).
- Unit Frames: Added per-frame `Hide in vehicles` visibility option.
- Cooldown Panels: Added per-panel `Hide in vehicles` display option.
- Aura: Added per-module `Hide in pet battles` options for Unit Frames, Cooldown Panels, Resource Bars, and GCD Bar.
- Aura: Added `Hide in client scenes` (e.g. minigames) for Unit Frames, Cooldown Panels, and Resource Bars (default enabled).
- Resource Bars: Added per-bar `Click-through` option in Edit Mode
- World Map Teleport: Added Ever-Shifting Mirror
- Vendor: Added configurable auto-sell rules for `Poor` items (including `Ignore BoE`), hide crafting-expansion filtering for `Poor`, and disable global `Automatically sell all junk items` when `Poor` auto-sell is enabled.

### ⚡ Performance

- Unit Frames: `setBackdrop`/`applyBarBackdrop` now run with style-diff caching, so unchanged backdrop styles are skipped instead of being reapplied every refresh.
- Unit Frames: Edit Mode registration now batches refresh requests and skips no-op anchor `onApply` refreshes, reducing load-time spikes during UF frame/settings registration.
- Health/Power percent: Removed some pcalls
- Drinks: Improved sorting
- Unit Frames: Health updates now cache absorb/heal-absorb values and refresh them on absorb events instead of querying absorb APIs every health tick.
- Unit Frames: `formatPercentMode` was moved out of `formatText` hot-path to avoid per-update closure allocations.
- Resource Bars: `configureSpecialTexture` now caches special atlas state (`atlas` + normalize mode) and skips redundant texture/color reconfiguration.

### 🐛 Fixed

- Tooltip: Fixed a rare error when hovering unit tooltips.
- Objective Tracker: Hiding of M+ timer fixed
- Unit Frames: Main frame strata fallback is now stable `LOW` (instead of inheriting Blizzard `PlayerFrame` strata), preventing addon interaction from unexpectedly forcing Player/Target/ToT/Focus frames to `MEDIUM`.
- LibButtonGlow Update - Secret error
- World Map Teleport: Fixed restricted-content taint (`ScrollBar.lua` secret `scrollPercentage`) by suppressing the EQoL teleport display mode/interactions while restricted.

---

## [7.11.4] - 2026-02-09

### 🐛 Fixed

- Unit Frames: Power colors/textures now resolve by numeric power type first.
- Item Inventory (Inspect): Improved `INSPECT_READY` handling and reliability.
- Item Inventory (Inspect): Performance improvements for inspect updates.
- Tooltip: Fixed an error when showing additional unit info in restricted situations.
- Chat: `Chat window history: 2000 lines` now reapplies correctly after reload.
- Unit Frames: Some borders used the wrong draw type

---

## [7.11.3] - 2026-02-08

### 🐛 Fixed

- Missing locale

---

## [7.11.2] - 2026-02-08

### 🐛 Fixed

- Group Frames (Party/Raid): `Name class color` now persists correctly after `/reload`.
- Cooldown Panels: Edit Mode overlay strata now follows panel strata correctly.
- Cooldown Panels: `Copy settings` now refreshes Edit Mode settings and correctly updates layout mode/radial options.

---

## [7.11.1] - 2026-02-08

### 🐛 Fixed

- Cooldown Panels: Anchoring to other addons wasn't working

---

## [7.11.0] - 2026-02-08

### ✨ Added

- Data Panels: Panel-wide stream text scale option in Edit Mode.
- Data Panels: Panel-wide class text color option for stream payload text.
- Data Panels: Equipment Sets stream now has right-click options for text size and class/custom text color.

### 🔄 Changed

- Data Panels: Stream options windows now show the active stream name in the header instead of only "Options".
- Data Panels: Equipment Sets stream icon size now follows the configured text size.
- Mounts: Added tooltip hints for class/race-specific mount options (Mage/Priest/Dracthyr) when shown globally in settings.

### 🐛 Fixed

- Action Tracker: Removed some DK, Evoker and Priest fake spells
- Cooldown Panels: Improved reliability when changing spec and entering/leaving instances.
- Cooldown Panels: Fixed cases where hidden panels or cursor overlays could remain visible.
- Cooldown Panels: Improved static text behavior for multi-entry panels.
- Cooldown Panels: Simplified Static Text options in Edit Mode to reduce confusion.
- Unit Frames: Raid frame color change was wrong

---

## [7.10.0] - 2026-02-07

### ✨ Added

- Unit Frames: Aura icons can use custom border textures (boss frames included)
- Mount Keybinding: Random mount can shift into Ghost Wolf for shamans while moving (requires Ghost Wolf known).
- MythicPlus: Added a keybind for random Hearthstone usage (picks from available Hearthstone items/toys).
- Unit Frames: Option to round percent values for health/power text
- Unit Frames: Castbar border options (texture/color/size/offset)
- Unit Frames: Option to disable interrupt feedback on castbars
- Unit Frames: Castbar can use class color instead of custom cast color
- Unit Frames: Per-frame smooth fill option for health/power/absorb bars (default off)
- Group Frames (Party/Raid): **BETA** (performance test) for feedback on missing features or breakage. Aura filters require 12.0.1; on 12.0.0 you will see more auras (e.g., Externals filtering won’t work yet).
- Group Frames (Raid): Optional split blocks for Main Tank and Main Assist with separate anchors and full raid-style appearance settings.
- Cooldown Panels: Optional radial layout with radius/rotation controls (layout fields auto-hide on switch)
- Cooldown Panels: Cursor anchor mode with Edit Mode preview and live cursor follow
- Cooldown Panels: Hide on CD option for cooldown icons
- Cooldown Panels: Show on CD option for cooldown icons
- Cooldown Panels: Per-entry static text with Edit Mode font/anchor/offset controls
- System: Optional `/rl` slash command to reload the UI (skips if the command is already claimed)
- Unit Frames: Combat feedback text with configurable font/anchor/events
- Skinner: Character Frame flat skin (buttons, dropdowns, title pane hover/selection)
- Data Panels: Background and border textures/colors are now configurable via SharedMedia.
- Data Panels: Durability stream now has an option to hide the critical warning text (`Items < 50%`).
- Data Panels: Gold stream now supports a custom text color and optional silver/copper display in addition to gold.
- Data Panels: Durability stream now has customizable high/mid/low colors.

### 🔄 Changed

- Data Panels: **Hide Border** now hides only the border. Migration sets background alpha to 0 if Hide Border was previously enabled, so you may need to re-adjust background alpha.
- Unit Frames: Increased offset slider range in UF settings from ±400 to ±1000.

### ⚡ Performance

- Unit Frames: Cache aura container height/visibility updates to reduce UI calls
- Tooltips: Skip unit tooltip processing and health bar updates when all tooltip options are disabled
- MythicPlus: World Map teleport panel events now register only when the feature is enabled
- Food: Drink/health macro updates and Recuperate checks now run only when the macros are enabled
- Unit Frames: Truncate-name hooks now register only when the feature is enabled
- Action Bars: Visibility watcher now disables when no bar visibility rules are active

### ❌ Removed

- Aura Tracker (BuffTracker module + settings/UI)
- Legacy AceGUI options window (tree-based settings UI)
- Mover: Individual bag frame entries (Bag 1–6)

### 🐛 Fixed

- Tooltips: Guard secret values when resolving unit names (prevents secret boolean test errors)
- Group Frames: Guard missing Edit Mode registration IDs on disable
- Unit Frames: Boss cast bar interrupt texture now resets on new casts
- Unit Frames: Aura cooldown text size no longer defaults to ultra-small "Auto"; default now uses a readable size
- Resource Bars: Smooth fill now uses status bar interpolation (fixes legacy smooth update behavior)
- ChatIM: Disabling instant messenger restores whispers in normal chat
- Vendor: Disable destroy-queue Add button when the feature is off
- MythicPlus: ConsolePort left-click on World Map teleports now triggers the cast correctly
- Visibility: Skyriding stance check no longer triggers for non-druids (e.g., paladin auras)
- World Map Teleport: Mixed Alliance and Horde for Tol Barad Portal
- World Map Teleport: Tab selector was hidden
- Cooldown Panels: Specs were not correctly checked
- Itemlevel in Bags and Characterpanel are now correct
- Missing locales

---

## [7.9.1] - 2026-02-02

### 🐛 Fixed

- Wrong default font for zhTW

---

## [7.9.0] - 2026-02-02

### ✨ Added

- Keybinding: Toggle friendly NPC nameplates (nameplateShowFriendlyNpcs)
- UF Plus: Unit status group number format options (e.g., Group 1, (1), | 1 |, G1)
- UF Plus: Target range fade via spell range events (configurable opacity)

### 🔁 Changed

- Resource Bars: Bar width min value changed to 10

### 🐛 Fixed

- Secret error: LFG List sorting by mythic+ score is now ignored in restricted content
- Questing: Guard UnitGUID secret values when checking ignored quest NPCs (prevents secret conversion errors)
- Health Text: Text was shown when unit is dead
- Nameplates: Class colors on nameplates now work in 12.0.1 (updated CVar)
- Cooldown Panels: Guarding against a protection state produced by anchoring protected frames to CDPanels
