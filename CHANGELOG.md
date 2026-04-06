# BazBars Changelog

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
