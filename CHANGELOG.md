# Changelog

## [9.0.0] - 2026-03-15 (planned release)

### ✨ Added

- Instant Messenger (Minimap Menu): Added a `Instant Chats` submenu to the existing EnhanceQoL minimap button. It lists all open whisper tabs, sorts unread conversations first, and lets you jump straight into a chat with the input box focused.
- Square Minimap Stats: Added an optional `Tracking Button` element that reuses the Blizzard tracking dropdown on the minimap with configurable anchor, X/Y offset, and scale. While active, the default tracking slot stays hidden and the button can be positioned directly via Minimap Stats.
- Cooldown Panels (Tracked Buffs): Added support for tracking player buffs directly from Blizzard Cooldown Manager (`Buff Icon` / `Buff Bar`) via the new `Tracked Buff (CDM)` entry type.
- Cooldown Panels (Radial Layout): Added a configurable `Arc degrees` slider/input for radial panels, so icons can be distributed across custom arcs (for example semicircles) instead of always using a full `360°` circle.
- Cooldown Panels (Items): Added automatic rank-group support for Health/Combat Potions and Flasks/Fleeting Flasks. Item entries now store the lowest-rank ID as canonical and can still resolve to higher ranks.
- Cooldown Panels (Overlays): Added panel-wide `Ready glow color` customization (`Edit Mode -> Overlays`). Ready glows now use the configured panel color through the internal glow system.
- Cooldown Panels (Overlays): Added panel-wide `No desaturation` (`Edit Mode -> Overlays`) to keep icons fully colored while still tracking cooldown state.
- Cooldown Panels (Cooldown text): Added panel-wide static `Cooldown text color` customization (`Edit Mode -> Cooldown text`) with opacity support.
- Unit Frames (Secondary Power / Stagger): Added a dedicated top-level `Stagger colors` section so Brewmaster stagger color settings are no longer nested under `Secondary Power Bar`.
- Group Frames (Portraits): Added portrait support for Party/MT/MA frames with configurable side, square background, separator (toggle/size/texture/custom color), and optional `Extend border over portrait`.
- Group Frames (Role Icons): Added new role icon style `FRAME` using legacy atlas icons (`UI-Frame-TankIcon`, `UI-Frame-HealerIcon`, `UI-Frame-DpsIcon`).
- Group Frames (Border): Added an option to change the Strata and level of the border.
- Group Frames (Range Fade): Added Edit Mode controls for `Range fade` (`Enable range fade`, `Out of range opacity`, `Offline opacity`) plus sample-frame preview states so in-range, out-of-range, and offline fading is directly visible in `Sample frames`.
- Group Frames (Incoming Heals): Added an optional incoming-heal prediction bar for group frames with configurable texture, color, opacity, and sample preview.
- Group Frames (Healer Buff Placement): Added per-indicator border controls for `Icon`/`Square` styles: `Indicator Border`, `Border Texture` (SharedMedia), `Border Size`, `Border Offset`, and `Border Color`.
- Unit Frames (Health / Absorb): Added `Don't overflow health bar` (available when `Reverse fill` is enabled). When active, overflow rendering is suppressed so only the missing-health portion is shown; at full health no reverse-overflow absorb segment is visible.
- Unit Frames (Player / Target / Focus): Added a dedicated `Dispel indicator` overlay with its own expandable settings section (`Tint`, fill opacity/color, sample preview, and optional glow customization), based on the existing Group Frames dispel indicator behavior.
- Economy (Crafting Orders): Added a separate `Place Crafting Orders` section with an `Always set the filter for "Current expansion"` option, matching the existing Auction House behavior.
- Resource Bars (Hunter Survival): Added support for `Tip of the Spear` (`260286`) as an aura-based secondary resource bar.
- Resource Bars (Text): Added a new `Current - Percent` text display option for supported bar types.
- Resource Bars (Threshold Colors): Added per-resource threshold color overrides with up to `10` configurable points (value + color), including Secret-safe handling for power types that expose secret values.
- Standalone Castbar: Added configurable `Reverse fill` in `Bar style`.
- Group Frames (Party / Growth): Added `Center vertical` and `Center horizontal` growth modes for center-outward party expansion from the anchor midpoint.
- Mythic+ (Teleports): Added the Engineering wormhole to Quel'Thalas to the teleport list.
- Mover: Added PvPMatchResults Frame
- Mouse Ring: Added a separate `Show cast progress outside combat` toggle so cast progress can stay visible even when `Show ring only in combat` is enabled.
- Resource Bars (Runes / Essence): `Separated offset` now renders real standalone segmented bars with individual backgrounds/borders, matching other segmented resources such as Holy Power and Maelstrom Weapon.
- Square Minimap Stats (Location): Added `Show subzone below zone` so zone and subzone can optionally render as two lines with the subzone shown beneath the zone.
- Visibility & Fading: Added the missing `Hide while flying` visibility rule to the remaining settings/editors that already supported `Skyriding`, including Cooldown Viewer, Spell Activation Overlay and Action Bars.
- Sound: Added new mute toggles for `Abundance (Dundun talking head only)` and `Delves (Valeera in-combat comments)`.

### 🔄 Changed

- Cooldown Panels (Glow): Reworked panel glow handling to use the new internal glow system for Ready/Active/Pandemic visuals, including selectable glow styles, panel/entry glow-style overrides, and configurable glow insets.

### ❌ Removed

- UI (Frames): Removed the `Unclamp Blizzard damage meter` option and its custom unclamp handling to avoid taint issues; Blizzard damage meter windows now use the default screen clamping again.

### 🐛 Fixed

- Unit Frames / Group Frames: Reworked the Single UF settings layout to match the Group Frames structure more closely, including split `Buffs` / `Debuffs` sections and clearer top-level ordering.
- Unit Frames (Player / Target / Focus / Dispel Indicator): Fixed several follow-up issues in the new single-frame dispel indicator implementation, including wrong locale placement, a Blizzard overlay-orientation error on custom unit frames, stale clears on target/focus swaps, and target/focus indicators appearing on hostile units instead of friendly units only.
- Group Frames (Party Auras / Tooltips): Fixed dungeon tooltip flicker caused by party-frame aura updates repeatedly toggling aura-button mouse state while hovered, which could also disrupt other visible tooltips that shared the global `GameTooltip`.
- Group Frames (Aura Tooltip Anchors): Fixed inconsistent party/healer-buff aura tooltip positioning so aura tooltips now follow the same Edit Mode tooltip anchor behavior as the unit tooltip instead of mixing HUD-anchor and icon-anchor placement.
- Group Frames (Health / Absorb): Fixed stale absorb overlays on shield refreshes where a new absorb could be applied before the previous one fully expired, causing party/raid frames to stop updating the absorb bar until a later change.
- Group Frames (Localization): Fixed multiple visible Group Frame settings labels and editor action buttons not using Aura locale keys, and added payload entries for all supported locales.
- Economy (Craft Shopper): Fixed an intermittent error while tracking recipe reagents where some profession reagent slots could resolve without a valid item ID and crash the shopping-list rebuild.
- Instant Messenger (Whisper Focus): Unified conversation focusing when opening whispers from the chat edit box or outgoing whisper events. Battle.net whispers now consistently focus the correct conversation tab.
- Unit Frames (Absorb Glow): Fixed absorb glow placement and clipping for reverse/overflow layouts. The glow is now anchored to the health-frame edge while being clipped to the health fill region.
- Cooldown Panels (Ready Glow): Fixed inconsistent/stuck ready-glow behavior for Items and Slot-based Trinkets. Ready glow now initializes correctly on reload, clears reliably when cooldown starts, and stays in sync when toggling `Glow` or changing `Glow duration` in Edit Mode.
- GCD Bar / SharedMedia: Fixed a login/reload issue where the bar could appear empty because late SharedMedia statusbar/border registrations were not reapplied to the frame.
- Mythic+ (Party Keystone): Fixed an issue where opening the party keystone panel could trigger an error instead of showing the entries correctly.
- Class Buff Reminder: Fixed reminders showing while your character is dead or a ghost.
- Food Reminder: Fixed the mage-food leave button appearing in non-follower LFG dungeons. It now only shows inside follower dungeons.
- Resource Bars: Newly auto-enabled bars for fresh characters/specs no longer spawn on top of each other on first initialization; default anchors now stack vertically from the start.
- Resource Bars (Essence): Fixed Evoker Essence `Separated offset` behavior so the option no longer only inserts spacing into the legacy essence layout and instead uses the proper segmented renderer.
- Resource Bars (Gradient / Edit Mode): Fixed a Retail Lua error when switching from specs without resource bars to specs with them, especially on fresh characters. Gradient refreshes now skip protected/invalid bar colors instead of crashing when opening, moving, or configuring the bar.
- Resource Bars (Vertical Orientation): Fixed a bug where vertical bars could revert to horizontal sizing after being moved in Edit Mode because stale layout width/height values were written back into the bar config.
- Resource Bars (Health / Absorb): Fixed vertical absorb rendering on health bars so the absorb segment now follows the bar orientation correctly instead of appearing as a horizontal strip across the bar.
- Resource Bars (Threshold Colors / Max Color): Fixed percent-based secret/curve resource bars (for example Fury) so `Use max color` no longer suppresses `Threshold colors`. Threshold colors now evaluate through a step color curve for protected percentage values, while `Max color` still applies cleanly at full resource.
- Ignore List: Fixed a Retail secret-value error while scanning party/raid members for ignored players.
- Minimap Button Bin: Fixed `GatherMatePin*` minimap pins being treated as minimap buttons, so they no longer appear in the Button Sink or its exclude list.
- Item Upgrades: Fixed upgrade indicators and upgrade-only checks suggesting off-armor-type gear (for example Cloth on Leather classes). Bag, merchant, and loot-toast upgrade checks now respect the current spec's actual armor proficiency.
- Sound: Fixed mute selections for direct sound groups so they are reapplied correctly after login or `/reload`.
- Experience Bar: Fixed rested text values being capped to the XP remaining in the current level. Text modes now show the real banked rested XP from `GetXPExhaustion()`, while the overlay remains limited to the current level segment.

---

## [8.8.1] - 2026-03-04

### 🐛 Fixed

- Resource Bars (Druid): Fixed Cat/Bear shapeshift flicker in combat when combining `Show in` (form filters) with `Show when` visibility rules by merging form-based hides into the secure visibility driver.
- Mythic+ (Teleports): Added missing Haranir racial teleport `Rootwalking` (`1238686`) to class/race teleports (only shown for Haranir/Harronir).
- Shared Media (Performance): Fixed settings freezes with very large SharedMedia libraries by introducing a global, sorted media cache for `sound`/`font`/`border`/`statusbar`/`background` instead of rebuilding lists on each settings open.
- Shared Media (Live Updates): New media registrations now invalidate the relevant cache via the `LibSharedMedia_Registered` callback, so newly added sounds/fonts/textures appear without repeated full rescans.
- Settings Dropdowns: Reworked affected dropdown providers (including Mythic+ Bloodlust Tracker, Class Buff Reminder, UI/Aura/Food/Sound related settings) to consume cached values directly, preventing repeated per-open sorting and list reconstruction.
- Group Frames (Healer Buff Placement): Sometimes stale buffs were shown

---

## [8.8.0] - 2026-03-03

### ✨ Added

- Group Frames (Healer Buff Placement): Added new Shaman buffs (`Ancestral Vigor`, `Earthliving Weapon`, `Hydrobubble`) and additional shared class-buff families in the rule editor.
- Unit Frames (Aura Ignore): Added a new global aura-ignore editor to quickly hide selected buffs/debuffs in `Player`, `Target`, `Focus`, `Party`, and `Raid` frames.
- Unit Frames (Aura Ignore): Added simple per-frame ignore categories for `Sated/Exhaustion Debuffs` and `Deserter Debuffs` (enabled by default).
- Unit Frames (Aura Ignore): Added a spell-family ignore list (same families as the Healer Buff editor) with cleaner name-only labels.
- Mythic+: Added a new Bloodlust lockout tracker for `Sated/Exhaustion` debuffs.
- Mythic+ (Edit Mode): Bloodlust tracker is now fully movable and customizable (icon, text, border, sounds).
- Shared Media: Added new sound `Wrestling Bell`.
- Class Buff Reminder: Added `Grow from center` and expanded self-buff/enchant coverage for Paladin (`Rites`), Rogue (`Lethal + Non-lethal Poisons`), and Shaman (`Skyfury`, `Earthliving`, `Tidecaller's Guard`).
- Class Buff Reminder (Evoker): Added `Source of Magic` tracking with healer-target-aware logic (only when at least one other healer target exists).
- Class Buff Reminder: Added optional flask tracking (shared with Flask Macro preferences), only showing when a matching flask is available in bags.
- Resource Bars (Rogue): Added charged combo point styling with Rogue-only options (toggle, custom fill/background colors, highlight strength, and alpha).

### 🐛 Fixed

- Group Frames (Healer Buff Placement): `NOT (active when missing)` now only considers buffs the current class/spec can provide.
- Combat Text: `-Combat` now reliably uses the correct color after login and instance transitions.

---

## [8.7.1] - 2026-03-02

### 🐛 Fixed

- Resource Bars: Bugfix migration of settings

---

## [8.7.0] - 2026-03-02

### ✨ Added

- Mythic+ (World Map Dungeon Portals): Added `Abundant Beacon`.
- Mythic+ (Hearthstone): Added `Preferred Hearthstone` dropdown in Teleport settings to pick a fixed owned Hearthstone instead of random.
- Group Frames (Healer Buff Placement): Added new Indicator options for `Icon`/`Square`: `Cooldown Swipe`, `Draw Edge`, `Draw Bling`, `Hide Cooldown Text`, and `Hide Charge Text`.
- Group Frames (Healer Buff Placement): Added `Cooldown Size` and `Charge Size` sliders (up to `64`) for `Icon`/`Square` indicators.
- Group Frames (Healer Buff Placement): Added `Loop Live Preview` toggle in the editor.
- Visibility & Fading (Frames): Added a `Minimap` visibility rule entry with rule options `Always out of combat` and `Always hidden`.
- Unit Frames / Castbars: Added a separate `Backdrop texture` selector (SharedMedia statusbar) for `Health`, `Power`, and `Cast` backdrops, including Standalone Castbar and Group Frames.
- Data Panels (Bag Space): Added `Current/Max` display mode and `Ignore components bag` option.
- Fonts (Global): Added `Global font` under `Profiles -> AddOn` plus `Use global font config` at the top of supported font dropdowns; defaults now follow the global font setting with locale fallback and SharedMedia updates.

### 🔄 Changed

- Group Frames (Healer Buff Placement): Improved editor spacing/alignment for labels, checkboxes, and color pickers to avoid overlaps and improve readability.

### 🐛 Fixed

- Health Macro: Updated outdated post-squish heal values for older health potions so current Midnight potions are prioritized correctly.
- Health Macro: Corrected `Algari Healing Potion` ranking values (`211878`, `211879`, `211880`) to match current in-game magnitudes.
- Group Frames (Healer Buff Placement): Fixed Indicator Settings scroll behavior when switching from long to short indicator styles (for example `Tint`), so settings are no longer hidden off-screen.
- Group Frames (Private Auras): Fixed private aura anchor drift when a power bar is shown by anchoring to the frame container consistently.
- Square Minimap Stats (Location): In `subzone only` mode, location text now automatically falls back to zone text when no subzone name is available.
- Experience Bar: Fixed a visible seam between normal XP fill and rested overlay fill, so both segments now blend continuously at the transition.

---

## [8.6.0] - 2026-03-01

### ✨ Added

- Aura (Experience Bar): Added optional progression text modes for `Left / Center / Right` slots: `Time this level`, `XP per hour`, `Leveling in`, and `Leveling in (+XP/h)`.

### 🐛 Fixed

- Action Bars (Button text): Fixed an interaction where enabling `Change keybind font` could make keybind labels visible again on bars selected in `Hide keybinds per bar`. Per-bar hide now always takes precedence.
- Group Frames (Healer Buff Placement): Fixed Color Picker alpha/cancel behavior for indicator and per-spell square colors, so opacity now applies correctly and `Cancel` reliably restores the previous color.
- Group Frames (Healer Buff Placement): Fixed numeric slider inputs (including `X Offset`/`Y Offset`) to stay in sync with sliders and apply precise clamped values consistently.
- Resource Bars: Bugfix migration of settings
- Tooltips (Unit / Modifier refresh): Fixed taint/secret-value errors while updating visible unit tooltips on modifier key changes.

---

## [8.5.1] - 2026-03-01

### 🐛 Fixed

- Mythic+ (World Map Dungeon Portals): Added missing data for `Personal Key to the Arcantina`.
- Character/Inspect Frame (Enchants): Fixed a regression where missing-enchant warnings could appear on non-enchantable slots.

---

## [8.5.0] - 2026-03-01

### ✨ Added

- Castbars (Unit Frames + Standalone): Added `Cast name anchor` (`LEFT` / `CENTER` / `RIGHT`) so the spell name can be centered or right-aligned instead of always being left-aligned.
- Character/Inspect Frame (Enchants): Added `Enchant display` mode selector with `Full`, `Badge (E)`, and `Warning only`.

### 🐛 Fixed

- Mouse (Crosshair): Fixed crosshair registration in Edit Mode while the feature is disabled.
- Group Frames (Healer Buff Placement): Fixed delayed self Earth Shield tracking (`383648`).
- Health Macro: Added support for `Potent Healing Potion` (`258138`).

---

## [8.4.0] - 2026-03-01

### ✨ Added

- Mouse (Crosshair): Added `Enable screen crosshair` in regular Settings (`General -> Mouse & Accessibility`) to globally toggle the feature.
- Resource Bars (Mage Frost): Added support for `Icicles` as an aura-based resource bar.
- Resource Bars (Edit Mode): Added per-bar `Show when` (same visibility rules as Cooldown Panels) directly under `Frame`, including migration from legacy mounted/combat hide settings.
- Aura (Experience Bar): Added a fully customizable Experience Bar with Edit Mode integration (anchor target/point/offset, optional match-width, texture/background/border, and hide options for pet battles + Blizzard tracking bars).
- Aura (Experience Bar): Added text customization with independent `Left / Center / Right` slots and selectable content (`Level`, `Current/Max`, `Percent`, rested variants), plus font, size, outline, and text color controls.
- Aura (Experience Bar): Added separate fill colors for rested and non-rested XP states.
- Mythic+ (World Map Dungeon Portals): Added Midnight spells `Teleport: Silvermoon City` (`1259190`), `Portal: Silvermoon City` (`1259194`), and `Personal Key to the Arcantina` (`1255801`).

### 🔄 Changed

- Castbars (Unit Frames + Standalone): Increased `Cast bar height` slider maximum from `40` to `200`.
- Square Minimap Stats: Added configurable coordinate precision (`0-3` decimals) and automatic location text truncation (`...`) to fit minimap width.
- Unit Frames (Focus/ToT/Pet): Extended `Show when` rules with player-scoped conditions such as `Mounted`, `Not mounted`, `Player is casting`, `When I have a target`, and `In party/raid` (same rule handling as Player/Target).

### 🐛 Fixed

- Action Bars (Button text): Fixed a regression where custom keybind text colors could reset to default white/red after action state updates (for example during combat/range checks or key presses).
- Class Buff Reminder: Fix for 5man content showing missing buff

---

## [8.3.2] - 2026-02-28

### 🐛 Fixed

- Minimap: Fixed slight position drift when changing Minimap Cluster scale.

---

## [8.3.1] - 2026-02-28

### 🐛 Fixed

- Unit Frames (Class Resource): Fixed a regression where Class Resource settings used resource IDs from all classes in the selector/visibility options. Changes now correctly apply to the active class resource again, so moving and adjusting it (anchor/offset/scale/strata/frame level) works as expected.

---

## [8.3.0] - 2026-02-27

### ✨ Added

- Unit Frames (Health): Added `Use health percent gradient` with configurable curve type (`Cosine`, `Linear`, `Step`) and up to 5 custom gradient points (each with percent + color). The max-health color remains driven by class/custom/default health color.
- Action Bars (Button text): Added color pickers for macro name, keybind, and charge/stack text when their font overrides are enabled.
- Cooldown Panels (Edit Mode): Added a `Static text color` option for static entry text.
- Cooldown Panels (Edit Mode): Added `Stance` entries under `Add more` with class submenus for `Druid`, `Rogue`, `Paladin`, and `Warrior`, including `Show when missing` + `Glow`.
- Square Minimap Stats (Location): Added `Show zone` so zone and subzone can be toggled independently (`zone only`, `subzone only`, or both).

### 🔄 Changed

- Cooldown Panels (Edit Mode): Renamed `Add Slot` to `Add more`.

### 🐛 Fixed

- Character/Inspect Frame: Enchant text now clears correctly when swapping from an enchanted item to an unenchanted item.

---

## [8.2.0] - 2026-02-27

### ✨ Added

- Group Frames (Party/Raid): Added a new Buff filter dropdown in Edit Mode (`Buffs`) options: `Healer buffs` and `Helpful effects`.
- Class Buff Reminder: Added a standalone reminder for class-provided group buffs with full Edit Mode support.

### 🔄 Changed

- Group Frames: Removed obsolete external raid-frame integration hooks.

---

## [8.1.2] - 2026-02-27

### 🐛 Fixed

- Edit Mode: EQoL now only stores frame positions there. All other settings remain fully in the active AddOn profile.
- Profile stability: Switching Blizzard Edit Mode layouts no longer overwrites EQoL frame settings with old layout data.
- Craft Shopper: Fixed cases where the custom 1:n recipe tracking control did not appear in Professions and the default "Track Recipe" checkbox stayed visible.

---

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
