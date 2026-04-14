---------------------------------------------------------------------------
-- BazBars User Guide
-- Registered with BazCore so it appears in the User Manual tab.
---------------------------------------------------------------------------

if not BazCore or not BazCore.RegisterUserGuide then return end

BazCore:RegisterUserGuide("BazBars", {
    title = "BazBars",
    intro = "Custom extra action bars that don't consume Blizzard's 120 action slot IDs. Create as many bars as you want, place them anywhere, configure through Blizzard's native Edit Mode.",
    pages = {
        {
            title = "Welcome",
            blocks = {
                { type = "lead", text = "BazBars lets you build action bars that live alongside Blizzard's defaults without conflicting. The same spell can sit on both your default bar and a BazBar simultaneously — buttons are independent of WoW's 1–120 action slot system." },
                { type = "h2", text = "Why BazBars?" },
                { type = "list", items = {
                    "Up to 24x24 button grids per bar (576 buttons each)",
                    "Unlimited number of bars",
                    "Native Blizzard look — same atlases, cooldown sweeps, proc glow, range tinting",
                    "Full Edit Mode integration with grid snap and pixel-precise nudge",
                    "Optional Masque skinning per bar",
                }},
                { type = "note", style = "tip", text = "Drag-and-drop accepts spells, items, macros, toys, mounts, pets, and equipment sets. Items show live bag counts." },
            },
        },
        {
            title = "Creating a Bar",
            blocks = {
                { type = "paragraph", text = "Open Blizzard's |cffffd700Edit Mode|r (default key Shift+F11)." },
                { type = "list", ordered = true, items = {
                    "Look at the top of the Edit Mode panel",
                    "Click the |cffffd700Create New BazBar|r button",
                    "A new bar spawns at the center of your screen",
                    "Drag it where you want, then click it again to open settings",
                }},
                { type = "note", style = "info", text = "You can repeat this as many times as you want. Each bar is independent — its own size, position, layout, and contents." },
            },
        },
        {
            title = "Placing Buttons",
            blocks = {
                { type = "lead", text = "Drag almost anything onto a button slot." },
                { type = "h3", text = "Drag sources" },
                { type = "table",
                  columns = { "Source", "Behavior" },
                  rows = {
                      { "Spells",          "From your spellbook" },
                      { "Items",           "From your bags — shows live stack counts" },
                      { "Macros",          "From the macro window — name displays under icon" },
                      { "Toys",            "From your toy box" },
                      { "Mounts",          "From the mount journal, including Random Favorite" },
                      { "Battle Pets",     "From your pet collection" },
                      { "Equipment Sets",  "From the character pane" },
                  },
                },
                { type = "h3", text = "Removing buttons" },
                { type = "list", items = {
                    "|cffffd700Shift+Drag|r off the button to remove it",
                    "|cffffd700Shift+Right-Click|r to clear in place",
                }},
            },
        },
        {
            title = "Editing a Bar",
            blocks = {
                { type = "paragraph", text = "While in Edit Mode, click any BazBar to select it (yellow highlight). Click again to open its settings popup." },
                { type = "h3", text = "Settings sections" },
                { type = "collapsible", title = "Layout", style = "h4", blocks = {
                    { type = "list", items = {
                        "|cffffd700Bar Name|r — custom display name",
                        "|cffffd700Orientation|r — horizontal or vertical",
                        "|cffffd700Rows / Icons|r — resize the button grid (up to 24x24)",
                        "|cffffd700Icon Size|r — scale from 50% to 250%",
                        "|cffffd700Icon Padding|r — spacing between buttons",
                    }},
                }},
                { type = "collapsible", title = "Visibility", style = "h4", blocks = {
                    { type = "paragraph", text = "Use Blizzard macro conditionals to control when the bar appears." },
                    { type = "code", text = "[combat] show; hide" },
                    { type = "paragraph", text = "Examples: |cffffd700[stance:1]|r, |cffffd700[vehicleui]|r, |cffffd700[group]|r, |cffffd700[mod:shift]|r." },
                }},
                { type = "collapsible", title = "Keybinds", style = "h4", blocks = {
                    { type = "paragraph", text = "Quick Keybind mode lets you bind keys directly to buttons by hovering and pressing. No macros or AddOn dependencies." },
                }},
                { type = "collapsible", title = "Appearance", style = "h4", blocks = {
                    { type = "list", items = {
                        "Per-bar Masque skinning (when Masque is installed)",
                        "Button styling overrides",
                        "Cooldown sweep visibility",
                        "Hotkey text visibility",
                    }},
                }},
            },
        },
        {
            title = "Edit Mode Tools",
            blocks = {
                { type = "paragraph", text = "Bars play by Edit Mode's rules:" },
                { type = "list", items = {
                    "Drag to move",
                    "Snap to the grid",
                    "Nudge with arrow keys for pixel-precise placement",
                    "Selection states use Blizzard's native cyan/yellow highlight art",
                }},
                { type = "note", style = "info", text = "Bar positions save to your active Edit Mode layout. Switching layouts in Edit Mode loads the matching bar positions." },
            },
        },
        {
            title = "Slash Commands",
            blocks = {
                { type = "table",
                  columns = { "Command", "Effect" },
                  rows = {
                      { "/bazbars",       "Open the BazBars settings page" },
                  },
                },
            },
        },
        {
            title = "Tips",
            blocks = {
                { type = "list", items = {
                    "Use a visibility macro like |cffffd700[combat] show; hide|r to make a bar appear only in combat",
                    "Items show live bag counts — handy for tracking herbs, ore, or potion stacks while farming",
                    "Random Favorite Mount works as a button — one click to roll a random mount",
                    "Bars don't take action slots, so all 120 default slots stay free",
                }},
                { type = "note", style = "tip", text = "Combine BazBars with BazWidgetDrawers for a fully customized UI without Blizzard slot constraints." },
            },
        },
    },
})
