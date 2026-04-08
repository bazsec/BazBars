-- BazBars Options Module
-- Now powered by BazCore OptionsPanel

local addon = BazCore:GetAddon("BazBars")
local Options = {}
addon.Options = Options

---------------------------------------------------------------------------
-- Build options table dynamically (reflects current bars)
---------------------------------------------------------------------------

local BuildBarOptions -- forward declaration

local function GetOptionsTable()
    local options = {
        name = "BazBars",
        subtitle = "Custom extra action bars",
        type = "group",
        args = {
            bars = {
                order = 10,
                type = "group",
                name = "Bars",
                args = {},
            },
        },
    }

    -- Build per-bar options
    local dbBars = addon.db and addon.db.profile and addon.db.profile.bars or {}
    for id, barData in pairs(dbBars) do
        if type(barData) == "table" then
            options.args.bars.args["bar" .. id] = BuildBarOptions(id, barData)
        end
    end

    return options
end

---------------------------------------------------------------------------
-- Per-bar options group
---------------------------------------------------------------------------

BuildBarOptions = function(id, barData)
    return {
        order = id,
        type = "group",
        name = "Bar " .. id,
        desc = "Configure Bar " .. id,
        args = {
            barName = {
                order = 0,
                type = "input",
                name = "Bar Name",
                desc = "Custom name for this bar",
                get = function() return barData.customName or "" end,
                set = function(_, val)
                    barData.customName = (val ~= "") and val or nil
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:SetCustomName(frame, barData.customName)
                    end
                end,
            },
            layoutHeader = {
                order = 1,
                type = "header",
                name = "Layout",
            },
            orientation = {
                order = 2,
                type = "select",
                name = "Orientation",
                values = { horizontal = "Horizontal", vertical = "Vertical" },
                get = function() return barData.orientation or "horizontal" end,
                set = function(_, val)
                    barData.orientation = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:LayoutButtons(frame, barData)
                    end
                end,
            },
            columns = {
                order = 4,
                type = "range",
                name = "# of Icons",
                min = 1, max = BazBars.MAX_COLS, step = 1,
                get = function() return barData.cols end,
                set = function(_, val)
                    barData.cols = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:Resize(frame, barData.rows, val, barData.spacing)
                    end
                end,
            },
            rows = {
                order = 6,
                type = "range",
                name = "# of Rows",
                min = 1, max = BazBars.MAX_ROWS, step = 1,
                get = function() return barData.rows end,
                set = function(_, val)
                    barData.rows = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:Resize(frame, val, barData.cols, barData.spacing)
                    end
                end,
            },
            appearanceHeader = {
                order = 10,
                type = "header",
                name = "Appearance",
            },
            scale = {
                order = 12,
                type = "range",
                name = "Icon Size",
                min = BazBars.MIN_SCALE, max = BazBars.MAX_SCALE, step = 0.05,
                isPercent = true,
                get = function() return barData.scale end,
                set = function(_, val)
                    barData.scale = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:SetScale(frame, val)
                    end
                end,
            },
            spacing = {
                order = 14,
                type = "range",
                name = "Icon Padding",
                min = 0, max = 20, step = 1,
                get = function() return barData.spacing end,
                set = function(_, val)
                    barData.spacing = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:Resize(frame, barData.rows, barData.cols, val)
                    end
                end,
            },
            barAlpha = {
                order = 16,
                type = "range",
                name = "Bar Opacity",
                min = 0, max = 1, step = 0.05,
                isPercent = true,
                get = function() return barData.alpha or 1.0 end,
                set = function(_, val)
                    barData.alpha = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:SetBarAlpha(frame, val)
                    end
                end,
            },
            visibilityHeader = {
                order = 20,
                type = "header",
                name = "Visibility",
            },
            mouseoverFade = {
                order = 21,
                type = "toggle",
                name = "Mouseover Fade",
                desc = "Bar fades out when mouse is not hovering over it",
                get = function() return barData.mouseoverFade or false end,
                set = function(_, val)
                    barData.mouseoverFade = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:ApplyMouseoverFade(frame)
                    end
                end,
            },
            alwaysShowButtons = {
                order = 22,
                type = "toggle",
                name = "Always Show Buttons",
                desc = "Show empty button slots even when no ability is assigned",
                get = function() return barData.alwaysShowButtons ~= false end,
                set = function(_, val)
                    barData.alwaysShowButtons = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:UpdateButtonVisibility(frame)
                    end
                end,
            },
            showSlotArt = {
                order = 23,
                type = "toggle",
                name = "Show Slot Art",
                desc = "Show the background texture on each button slot",
                get = function() return barData.showSlotArt ~= false end,
                set = function(_, val)
                    barData.showSlotArt = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:UpdateSlotArt(frame)
                    end
                end,
            },
            visibilityMacroHeader = {
                order = 30,
                type = "header",
                name = "Visibility Macro",
            },
            visibilityDesc = {
                order = 31,
                type = "description",
                name = "Use WoW macro conditionals to control when this bar is visible.\n",
            },
            visibilityMacro = {
                order = 32,
                type = "input",
                name = "Visibility Condition",
                desc = "Examples:\n[combat] show; hide\n[nocombat] hide; show",
                get = function() return barData.visibilityMacro or "" end,
                set = function(_, val)
                    barData.visibilityMacro = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:SetVisibilityMacro(frame, val)
                    end
                end,
            },
            actionsHeader = {
                order = 90,
                type = "header",
                name = "",
            },
            deleteBar = {
                order = 100,
                type = "execute",
                name = "|cffff4444Delete This Bar|r",
                confirm = true,
                confirmText = "Are you sure you want to delete Bar " .. id .. "?",
                func = function()
                    addon:DeleteBar(id)
                end,
            },
        },
    }
end

---------------------------------------------------------------------------
-- Register with BazCore OptionsPanel
---------------------------------------------------------------------------

local function GetGlobalOptionsTable()
    return {
        name = "Global Options",
        subtitle = "Settings that apply to all bars",
        type = "group",
        args = {
            displayHeader = {
                order = 1,
                type = "header",
                name = "Display",
            },
            fullRangeColor = {
                order = 2,
                type = "toggle",
                name = "Full Button Range Color",
                desc = "Tint the entire button red when out of range (icon, frame, hotkey). When off, only the hotkey text turns red.",
                get = function() return addon.db.profile.fullRangeColor ~= false end,
                set = function(_, val) addon.db.profile.fullRangeColor = val end,
            },
            showTooltips = {
                order = 3,
                type = "toggle",
                name = "Show Tooltips",
                desc = "Show spell/item tooltips when hovering buttons",
                get = function() return addon.db.profile.showTooltips ~= false end,
                set = function(_, val) addon.db.profile.showTooltips = val end,
            },
            showKeybindText = {
                order = 4,
                type = "toggle",
                name = "Show Keybind Text",
                desc = "Display hotkey text on buttons",
                get = function() return addon.db.profile.showKeybindText ~= false end,
                set = function(_, val)
                    addon.db.profile.showKeybindText = val
                    for _, frame in pairs(addon.Bar:GetAll()) do
                        for r, row in pairs(frame.buttons) do
                            for c, btn in pairs(row) do
                                if btn.HotKey then
                                    btn.HotKey:SetShown(val and btn.HotKey:GetText() ~= "")
                                end
                            end
                        end
                    end
                end,
            },
            showMacroNames = {
                order = 5,
                type = "toggle",
                name = "Show Macro Names",
                desc = "Display macro name text on buttons",
                get = function() return addon.db.profile.showMacroNames ~= false end,
                set = function(_, val)
                    addon.db.profile.showMacroNames = val
                    for _, frame in pairs(addon.Bar:GetAll()) do
                        for r, row in pairs(frame.buttons) do
                            for c, btn in pairs(row) do
                                if btn.Name then
                                    btn.Name:SetShown(val and btn.bbCommand == "macro")
                                end
                            end
                        end
                    end
                end,
            },
        },
    }
end

function Options:Setup()
    -- Parent category — addon info and quick guide
    BazCore:RegisterOptionsTable("BazBars", function()
        return BazCore:CreateLandingPage("BazBars", {
            subtitle = "Custom extra action bars",
            description = "Create unlimited custom action bars, completely independent of Blizzard's action bar system. " ..
                "Drag spells, items, macros, toys, mounts, and battle pets onto your bars.",
            features = "Unlimited bars with up to 24x24 button grids. " ..
                "Blizzard-native button styling with cooldowns, proc glows, and range tinting. " ..
                "Full Edit Mode integration with grid snapping and settings popup. " ..
                "Quick keybind mode, import/export, bar duplication, visibility macros, and mouseover fade. " ..
                "Masque skinning support.",
            guide = {
                { "Creating Bars", "Open Edit Mode and click \"Create New BazBar\", or use |cff00ff00/bb create|r" },
                { "Adding Actions", "Drag spells, items, macros, toys, or mounts onto any button" },
                { "Removing", "Shift+Drag to remove. Shift+Right-Click for mounts and pets" },
                { "Settings", "Edit Mode > click bar > settings popup, or |cff00ff00/bb|r for full options" },
                { "Keybinds", "Edit Mode > select bar > Quick Keybind Mode. Hover + press key to bind" },
            },
            commands = {
                { "/bb", "Open settings" },
                { "/bb create [cols] [rows]", "Create a new bar" },
                { "/bb delete <id>", "Delete a bar" },
                { "/bb duplicate <id>", "Duplicate a bar" },
                { "/bb export <id>", "Export bar config" },
                { "/bb import", "Import bar config" },
                { "/bb reset", "Reset all bars" },
            },
        })
    end)
    BazCore:AddToSettings("BazBars", "BazBars")

    -- Global Options subcategory
    BazCore:RegisterOptionsTable("BazBars-Global", GetGlobalOptionsTable)
    BazCore:AddToSettings("BazBars-Global", "Global Options", "BazBars")

    -- Bar Options subcategory
    BazCore:RegisterOptionsTable("BazBars-Bars", GetOptionsTable)
    BazCore:AddToSettings("BazBars-Bars", "Bar Options", "BazBars")

    -- Profiles subcategory
    BazCore:RegisterOptionsTable("BazBars-Profiles", function()
        return BazCore:GetProfileOptionsTable("BazBars")
    end)
    BazCore:AddToSettings("BazBars-Profiles", "Profiles", "BazBars")
end

function Options:Refresh()
    BazCore:RegisterOptionsTable("BazBars-Bars", GetOptionsTable)
    BazCore:RefreshOptions("BazBars-Bars")
end

function Options:Open()
    BazCore:OpenOptionsPanel("BazBars")
end
