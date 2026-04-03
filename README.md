<p align="center">
  <img src="https://raw.githubusercontent.com/bazsec/BazBars/master/logo.png" alt="BazBars Logo" width="300"/>
</p>

<h1 align="center">BazBars</h1>

<p align="center">
  <strong>Custom extra action bars for World of Warcraft</strong><br/>
  Independent of Blizzard's action bar system — no slot limits, no restrictions.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-12.0%20Midnight-blue" alt="WoW Version"/>
  <img src="https://img.shields.io/badge/License-GPL%20v2-green" alt="License"/>
  <img src="https://img.shields.io/badge/Version-009-orange" alt="Version"/>
</p>

---

## What is BazBars?

BazBars lets you create as many action bars as you need, with fully customizable layouts, and place them anywhere on your screen. Unlike standard action bars, BazBars buttons don't consume any of WoW's 120 action slot IDs — the same spell can live on both your default bars and a BazBar simultaneously, with no conflicts.

Buttons look and feel identical to Blizzard's default action bars, using the same atlas textures, icon masks, cooldown animations, and proc glows. BazBars integrates directly with WoW's Edit Mode system, so configuring your bars feels native.

<p align="center">
  <img src="https://raw.githubusercontent.com/bazsec/BazBars/master/screenshot.png" alt="BazBars Screenshot" width="800"/>
  <br/>
  <em>Stress-testing the 24x24 grid — because why not?</em>
</p>

---

## Features

### Unlimited Custom Bars
- Up to **24 x 24** button grids (576 buttons per bar)
- Create as many bars as you need
- Horizontal or vertical orientation
- Fully independent — no action slot limits

### Drag & Drop Everything
- Spells, items, macros, toys, mounts, battle pets, and equipment sets
- Items display live bag counts (great for tracking materials while farming)
- Usable items (potions, trinkets) work on click
- Toys from your toy box
- Mounts from your journal (including Random Favorite Mount)
- **Shift+Drag** to remove, **Shift+Right-Click** to clear

### Blizzard-Native Appearance
- Identical button styling using Blizzard's atlas textures
- Spell proc glow overlays
- Cooldown sweep animations (Midnight 12.0 API compatible)
- Usability shading and out-of-range icon tinting
- Charge counts, item stack counts, equipped item borders
- Macro name display
- Masque skinning support

### Full Edit Mode Integration
- Native cyan/yellow selection states matching Blizzard's UI
- Grid snapping with live preview lines
- Pixel-precise nudge controls
- "Create New BazBar" button added to the Edit Mode panel
- Blizzard-styled settings popup with collapsible sections

### Settings Popup
Click any bar in Edit Mode to access collapsible settings sections:

**Layout**

| Setting | Description |
|---------|-------------|
| Bar Name | Custom display name |
| Orientation | Horizontal or Vertical |
| Rows / Icons | Resize the button grid |
| Icon Size | Scale from 50% to 250% |
| Icon Padding | Spacing between buttons |
| Nudge | Pixel-precise positioning (L/R/U/D) |

**Appearance**

| Setting | Description |
|---------|-------------|
| Always Show Buttons | Toggle empty slot visibility |
| Show Slot Art | Toggle background texture |
| Bar Opacity | Overall transparency |
| Mouseover Fade | Fade out when not hovered |
| Bar Visible | Visibility condition presets |

**Behavior**

| Setting | Description |
|---------|-------------|
| Right-Click Self-Cast | Cast spells/use items on yourself with right-click |
| Quick Keybind Mode | Hover + press key to bind |
| Edit Button Macrotext | Write custom macro conditionals per button |

**Actions**

| Setting | Description |
|---------|-------------|
| Revert Changes | Undo changes since selecting the bar |
| Reset Position | Snap bar back to center |
| BazBars Settings | Open full options panel |
| Export Bar Config | Copy a shareable string |
| Duplicate This Bar | Clone bar with all buttons |
| Delete This Bar | Remove the bar permanently |

### Quick Keybind Mode
- Hover any button and press a key to bind it
- Press ESC while hovering to unbind
- Keybindings persist across sessions
- Combat-safe via `SetOverrideBindingClick`

### Macrotext Editor
- Write custom `/cast` conditionals for any button on your bar
- Supports `#showtooltip SpellName` — the button icon and tooltip update to show the specified spell
- Open via Edit Mode → Behavior → Edit Button Macrotext
- Click any button on the bar to select it, then type your macrotext

### Import / Export
- Export any bar's complete configuration (layout, buttons, settings) as a shareable string
- Import a string to recreate a bar on any character
- Available in Edit Mode → Actions → Export Bar Config, or via `/bb export <id>` and `/bb import`

### Duplicate Bar
- Clone any bar with all its button assignments in one click
- Available in Edit Mode → Actions → Duplicate This Bar, or via `/bb duplicate <id>`

### Visibility Macros
Control when bars appear using WoW macro conditionals:
```
[combat] show; hide          -- Only in combat
[nocombat] show; hide        -- Hide during combat
[exists] show; hide          -- When you have a target
[mod:shift] show; hide       -- While holding Shift
[pet] show; hide             -- When you have a pet
```

### Profiles (AceDB)
- Switch between named profiles (PvE, PvP, Raid, etc.)
- Copy bar configurations between characters
- Reset profiles to defaults
- Each profile stores its own complete bar setup and keybinds

### Minimap Button
- **Left-click**: Open settings panel
- **Right-click**: Create a new bar instantly
- Toggle visibility in BazBars Settings

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/bb` | Open settings panel |
| `/bb create [cols] [rows]` | Create a new bar |
| `/bb delete <id>` | Delete a bar |
| `/bb duplicate <id>` | Duplicate a bar |
| `/bb export <id>` | Export bar config as string |
| `/bb import` | Open import dialog |
| `/bb scale <id> <value>` | Set bar scale |
| `/bb padding <id> <pixels>` | Set button spacing |
| `/bb reset` | Reset all bars (reloads UI) |
| `/bb help` | Show all commands |

---

## Installation

### CurseForge / WoW Addon Manager
Search for **BazBars** in your addon manager of choice.

### Manual Installation
1. Download the latest release
2. Extract to `World of Warcraft/_retail_/Interface/AddOns/BazBars/`
3. Restart WoW or `/reload`

---

## Compatibility

| | |
|---|---|
| **WoW Version** | Retail 12.0.1 (Midnight) |
| **API Safety** | Midnight-compatible (`SetCooldownFromDurationObject`, direct button `OnEvent` handlers) |
| **Masque** | Full support with per-bar skinning groups |
| **Edit Mode** | Native integration with snapping, selection sync, and grid alignment |
| **Combat** | Secure actions via `SecureActionButtonTemplate` |

---

## Dependencies

**Required:** None — all libraries are embedded.

**Optional:**
- [Masque](https://www.curseforge.com/wow/addons/masque) — for button skinning

### Embedded Libraries
| Library | License |
|---------|---------|
| Ace3 (AceAddon, AceDB, AceDBOptions, AceConfig, AceConsole, AceEvent, AceGUI) | BSD |
| CallbackHandler-1.0 | BSD |
| LibStub | Public Domain |
| LibButtonGlow-1.0 | BSD |
| LibDataBroker-1.1 | BSD |
| LibDBIcon-1.0 | BSD |

---

## License

BazBars is licensed under the [GNU General Public License v2](LICENSE) (GPL v2).

---

<p align="center">
  <sub>Built with engineering precision by <strong>Baz4k</strong></sub>
</p>
