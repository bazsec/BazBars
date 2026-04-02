-- BazBars Options Module
-- AceConfig-based settings panel in the WoW Settings UI

local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")
local Options = {}
addon.Options = Options

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

---------------------------------------------------------------------------
-- Build options table dynamically (reflects current bars)
---------------------------------------------------------------------------

local BuildBarOptions -- forward declaration

local function GetOptionsTable()
    local options = {
        name = "BazBars",
        type = "group",
        args = {
            header = {
                order = 1,
                type = "description",
                name = "|cff66bbffBazBars|r - Custom extra action bars\n",
                fontSize = "medium",
            },
            createBar = {
                order = 2,
                type = "execute",
                name = "Create New Bar",
                desc = "Create a new action bar with default settings",
                func = function()
                    addon:CreateNewBar()
                end,
            },
            spacer1 = {
                order = 3,
                type = "description",
                name = "\n",
            },
            bars = {
                order = 10,
                type = "group",
                name = "Bars",
                inline = false,
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
                width = "full",
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
                width = "full",
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
            sp1 = { order = 3, type = "description", name = " " },
            columns = {
                order = 4,
                type = "range",
                name = "# of Icons",
                width = "full",
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
            sp2 = { order = 5, type = "description", name = " " },
            rows = {
                order = 6,
                type = "range",
                name = "# of Rows",
                width = "full",
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
            sp3 = { order = 11, type = "description", name = " " },
            scale = {
                order = 12,
                type = "range",
                name = "Icon Size",
                width = "full",
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
            sp4 = { order = 13, type = "description", name = " " },
            spacing = {
                order = 14,
                type = "range",
                name = "Icon Padding",
                width = "full",
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
            sp5 = { order = 15, type = "description", name = " " },
            barAlpha = {
                order = 16,
                type = "range",
                name = "Bar Opacity",
                width = "full",
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
                order = 20.5,
                type = "toggle",
                name = "Mouseover Fade",
                desc = "Bar fades out when mouse is not hovering over it",
                width = "full",
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
                order = 21,
                type = "toggle",
                name = "Always Show Buttons",
                desc = "Show empty button slots even when no ability is assigned",
                width = "full",
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
                order = 22,
                type = "toggle",
                name = "Show Slot Art",
                desc = "Show the background texture on each button slot",
                width = "full",
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
                name = "Use WoW macro conditionals to control when this bar is visible. Leave empty for always visible.\n",
            },
            visibilityMacro = {
                order = 32,
                type = "input",
                name = "Visibility Condition",
                desc = "Examples:\n[combat] show; hide\n[nocombat] hide; show\n[mod:shift] show; hide\n[target=focus,exists] show; hide",
                width = "full",
                get = function() return barData.visibilityMacro or "" end,
                set = function(_, val)
                    barData.visibilityMacro = val
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:SetVisibilityMacro(frame, val)
                    end
                end,
            },
            visibilityExamples = {
                order = 33,
                type = "description",
                name = "|cff888888Examples:\n  [combat] show; hide — Show only in combat\n  [nocombat] hide; show — Hide in combat\n  [mod:shift] show; hide — Show while holding Shift\n  [pet] show; hide — Show when you have a pet|r\n",
            },
            nudgeHeader = {
                order = 40,
                type = "header",
                name = "Position",
            },
            nudgeDesc = {
                order = 41,
                type = "description",
                name = "Fine-tune bar position by 1 pixel per click.\n",
            },
            nudgeUp = {
                order = 42,
                type = "execute",
                name = "Up",
                width = 0.5,
                func = function()
                    local frame = addon.Bar:Get(id)
                    if frame then addon.Bar:Nudge(frame, 0, 1) end
                end,
            },
            nudgeDown = {
                order = 43,
                type = "execute",
                name = "Down",
                width = 0.5,
                func = function()
                    local frame = addon.Bar:Get(id)
                    if frame then addon.Bar:Nudge(frame, 0, -1) end
                end,
            },
            nudgeLeft = {
                order = 44,
                type = "execute",
                name = "Left",
                width = 0.5,
                func = function()
                    local frame = addon.Bar:Get(id)
                    if frame then addon.Bar:Nudge(frame, -1, 0) end
                end,
            },
            nudgeRight = {
                order = 45,
                type = "execute",
                name = "Right",
                width = 0.5,
                func = function()
                    local frame = addon.Bar:Get(id)
                    if frame then addon.Bar:Nudge(frame, 1, 0) end
                end,
            },
            actionsHeader = {
                order = 90,
                type = "header",
                name = "",
            },
            editModeNote = {
                order = 91,
                type = "description",
                name = "\n|cff888888Use Edit Mode (Esc > Edit Mode) to reposition bars and access Quick Keybind Mode.|r\n\n",
            },
            deleteBar = {
                order = 100,
                type = "execute",
                name = "|cffff4444Delete This Bar|r",
                width = "full",
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
-- Register with AceConfig
---------------------------------------------------------------------------

function Options:Setup()
    AceConfig:RegisterOptionsTable("BazBars", GetOptionsTable)
    addon.optionsFrame = AceConfigDialog:AddToBlizOptions("BazBars", "BazBars")

    -- Profile management panel
    AceConfig:RegisterOptionsTable("BazBars-Profiles", AceDBOptions:GetOptionsTable(addon.db))
    AceConfigDialog:AddToBlizOptions("BazBars-Profiles", "Profiles", "BazBars")
end

function Options:Refresh()
    AceConfig:RegisterOptionsTable("BazBars", GetOptionsTable)
end

function Options:Open()
    AceConfigDialog:Open("BazBars")
end
