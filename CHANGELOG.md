# BazBars Changelog

## 029 - Keybind Conflict Eviction, Fix Unbind Error, Smaller Edit Mode Button
- **Fixed Blizzard keybind conflict:** when Quick Keybind Mode claims a key (e.g. `E`) that already has a Blizzard binding, BazBars now automatically evicts the Blizzard binding so the key isn't double-bound silently
  - Previously, setting `E` in Quick Keybind Mode installed a secure override on top of Blizzard's existing `E` binding — the override took priority so only the BazBars click fired, but the Blizzard binding stayed attached and would reactivate if the BazBars binding was cleared
  - New `EvictBlizzardBinding(key)` helper calls `GetBindingAction(key)` + `SetBinding(key, nil)` + `SaveBindings` to cleanly remove the Blizzard side of the conflict; Blizzard-binding clears that happen during combat are queued and processed on `PLAYER_REGEN_ENABLED`
  - Surfaces feedback in chat: `|cffffd700E|r was bound to |cff00ff00ACTIONBUTTON5|r - cleared so the BazBars button can claim it.`
  - Skips eviction when the existing action starts with `CLICK BazBars` (that's another BazBars button handled by the existing override-clearing path)
- **Fixed `Usage: SetOverrideBindingClick(...)` error when clearing a keybind via ESC** in Quick Keybind Mode
  - The old code called `SetOverrideBindingClick(owner, true, oldKey, nil)` to clear an override, but the click variant doesn't accept `nil` for `buttonName` in Midnight — it throws the usage error instead
  - Switched to `SetOverrideBinding(owner, true, oldKey, nil)` (the generic non-click variant) which accepts `nil` as "clear this key" and works for click-overrides as well
- **Shrunk the "Create New BazBar" button in the Edit Mode panel** — previously a 330px-wide stretched bar, now auto-sizes to the text width + padding at 1.2x scale so it hugs its label instead of dominating the panel

## 028 - Fix Spell Cooldown Sweep Not Showing In Combat
- Fixed spell cooldown animations not displaying during combat (v025 regression)
  - The v025 drag-drop rewrite moved cooldown logic into per-type action handlers and switched spells from Midnight's taint-safe `C_Spell.GetSpellCooldownDuration` + `Cooldown:SetCooldownFromDurationObject` duration-object API to the older raw-numbers path (`C_Spell.GetSpellCooldown` → startTime/duration numbers)
  - v026's `SafeNumber` taint-stripping silenced the taint comparison error but didn't solve the underlying problem: `Cooldown:SetCooldown(start, duration)` silently refuses to display when called with tainted numeric arguments in the secure combat environment
  - Restored the duration-object pipeline via a new `handler.applyCooldown(data, cooldownFrame)` method — `Spell.applyCooldown` uses `SetCooldownFromDurationObject` which is the only path that reliably drives the Cooldown frame in combat
  - `Button:UpdateCooldown` now prefers `applyCooldown` over the legacy `getCooldown` raw-numbers path; Item and Toy handlers keep using `getCooldown` since `C_Item.GetItemCooldown` isn't subject to the same taint
- Added a pristine `CooldownPrototype = CreateFrame("Cooldown")` for the legacy fallback path, matching Blizzard's own pattern in `Blizzard_ActionBar/Shared/ActionButton.lua:890`: *"Create a pristine instance of Cooldown frame to mitigate potential secret leaks through overwriting methods"*

## 027 - Fix Buttons Not Firing With Cast on Key Down Enabled
- Fixed BazBars buttons doing nothing when `ActionButtonUseKeyDown` (Cast on Key Down) is enabled
  - Buttons animated on click but never actually fired the ability, because `RegisterForClicks("AnyUp")` only registered for key-up events while the global CVar was directing the secure dispatcher to fire on key-down
  - `ActionButtonUseKeyDown` is a global CVar — BazBars buttons live in the same secure dispatch path as Blizzard's action bars and cannot be independently "locked to up" while Blizzard's stay on down
  - Changed button registration to match Blizzard's own ActionButton: `RegisterForClicks("AnyUp", "LeftButtonDown", "RightButtonDown")` (Blizzard_ActionBar/Shared/ActionButton.lua:458)
  - Result: BazBars buttons now fire correctly in both CVar modes, exactly like Blizzard's default bars
- **Note on drag-drop with Cast on Key Down enabled:** plain click-drag on a BazBars button will fire the ability on mouse-down before the drag starts, matching Blizzard's behavior on their own bars. Use **Shift+drag** to rearrange buttons when Cast on Key Down is on — `shift-type1` / `shift-type2` are set to `"noop"` so shift-click never dispatches anything.

## 026 - Cast on Key Down Toggle, Midnight Taint Fix
- Added "Cast on Key Down" toggle to the Settings page so you can enable cast-on-down for Blizzard default bars (required for One Button Combat's hold-to-cast feature) while BazBars buttons stay on cast-on-up
- Fixed "attempt to compare local 'duration' (a secret number value tainted by 'BazBars')" error from C_Spell.GetSpellCooldown in Midnight
  - Spell cooldown startTime and duration now round-trip through string.format("%d", ...) to strip the taint before being compared

## 025 - Drag & Drop Rewrite
- Completely rewrote the drag & drop system as modular per-type action handlers
- New handlers: Spell, Item, Toy, Mount, BattlePet, Macro, EquipmentSet, MacroText
- Each handler lives in Actions/ and owns cursor detection, pickup, secure attributes, visuals, and persistence for its type
- Bars are now unlocked by default — drag without holding Shift
- Added per-bar "Lock Buttons" toggle (Edit Mode popup + bar options panel)
- Drag-fires-cast bug fixed for all types
- Mount swaps preserve the exact variant (skin/color) instead of collapsing to the canonical mountID
- First-run warning offers to change "Cast on key down" CVar so drag-and-drop works consistently
- Old flat storage format (bbCommand/bbValue/bbSubValue/bbID/bbMacrotext) auto-migrates to the new `{ type, data }` format
- Dropped ~700 lines of legacy code from Button.lua

## 024 - Use BazCore:SetScaleFromCenter
- Bar scaling now uses shared BazCore:SetScaleFromCenter() utility

## 023 - Unified Profiles
- Profiles now managed centrally in BazCore settings
- Removed per-addon Profiles subcategory

## 022 - Global Options + Settings Page
- Added Global Options page with per-bar overrides for scale, opacity, spacing, slot art, always show buttons, and mouseover fade
- When a global override is enabled, per-bar settings are grayed out
- Moved display settings (range color, tooltips, keybind text, macro names) to new Settings subcategory
- Subcategory order: Settings, Profiles, Global Options, Bar Options

## 020 - Macro Fixes + Button Move System
- Fixed #showtooltip in macros now displays proper spell/item tooltips
- Fixed macros shifting when other macros deleted (stored by name instead of index)
- Auto-migration for existing users with index-based macro saves
- Unified internal move system for all button types (spells, items, macros, mounts, pets)
- Button swaps: drop A on B, B goes to cursor, click to place
- Drag from BazBar to default action bars works
- Removed dead PickUp-based drag code

## 019 - Audit Fixes
- Range ticker frame now stored with reference (can be paused)
- Category changed to "Baz Suite"

## 018 - Range Indicator & Keybind Fixes
- Unified range/usability coloring (out of range always takes priority)
- Full button range color option: tint entire button red or just hotkey text
- Keybinds now always override default WoW bindings
- Fixed secret string taint in spell names
- Fixed NormalTexture reset causing inconsistent range tinting

## 017 - Global Options Panel
- Added Global Options subcategory with Display settings
- Full Button Range Color, Show Tooltips, Show Keybind Text, Show Macro Names
- Parent settings page shows addon description, quick guide, and slash commands

## 016 - Range Indicator Improvements
- Full button range coloring (icon, frame, hotkey, macro name)
- Range state tracking prevents flashing at boundaries
- Target existence check prevents stuck red state

## 015 - Secret String & Item Fixes
- Fixed Midnight secret string taint in loot/currency chat messages
- Fixed uncached item crash using item:ID format
- Spell range check uses spellID instead of spell name

## 014
- Version now reads from TOC dynamically

## 013 - Mount, Pet & Drag Fixes
- Fixed mount shift-drag turning mounts into Random Mount
- Fixed battlepet SetAction crash (API return value change in Midnight)
- Mounts and battlepets now use internal move system with floating cursor icon
- Added companion cursor type support for mount journal compatibility
- Shift+RightClick still removes mounts/battlepets from buttons

## 012 - Edit Mode Framework
- Edit Mode now powered by BazCore's shared EditMode framework
- Grid snapping, selection sync, and settings popup handled by BazCore
- ESC key closes the Edit Mode settings popup
- Settings popup smart-positions to avoid going off-screen
- Bar name changes update overlay and popup title live
- Consolidated range update ticker for cleaner performance
- Removed ~500 lines of redundant Edit Mode code

## 011 - BazCore Migration
- Migrated from Ace3 libraries to BazCore framework
- Reduced addon size from ~8MB to ~50KB (libraries no longer bundled)
- BazCore is now a required dependency
- Automatic migration of existing saved data from Ace3 format
- All existing features preserved
