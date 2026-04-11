# BazBars Changelog

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
