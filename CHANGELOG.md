# BazBars Changelog

## 058 — Per-bar endcaps + Bar 1 hide toggles

**Per-bar side endcaps.** A new "Side Endcaps" dropdown in each bar's
Edit Mode popup adds Alliance gryphon or Horde wyvern art on the
left and right sides of the bar (vertically centered, rendered above
the buttons). Two extra controls go with it:
- "Scale Endcaps with Bar Height" — off by default; on for the
  multi-row "giant gryphons" look.
- "Endcap Size" slider (50% – 200%) for fine-tuning when the
  auto-scale is off.

**Hide the default Blizzard Bar 1.** New options under General
Settings → Blizzard UI:
- **Hide Default Action Bar (Bar 1)** — hides Bar 1 entirely (buttons
  + chrome + endcaps). Edit Mode covers Bars 2-8 already; this fills
  the gap for Bar 1. Keybinds 1-12 still fire whatever's slotted on
  those buttons.
- **Hide Bar 1 Art Only** — hides just the gryphon/wyvern endcaps and
  the dark border frame on Bar 1, leaving the buttons visible. Useful
  if you still use Bar 1's slots but want the decorative chrome gone.

Both toggles apply live (no /reload). Toggling in combat is deferred
until combat ends.

**Combat-safe edits.** Bar resize and rescale now bail with a print
during combat instead of erroring with `ADDON_ACTION_BLOCKED`.
