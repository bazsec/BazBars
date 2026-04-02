-- BazBars Core Module
-- AceAddon init, event handling, Edit Mode hooks, slash commands

local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")

---------------------------------------------------------------------------
-- AceDB Defaults
---------------------------------------------------------------------------

local defaults = {
    profile = {
        bars = {},
        keybinds = {},
        minimap = { hide = false },
    },
}

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

function addon:OnInitialize()
    -- Setup saved variables via AceDB
    self.db = LibStub("AceDB-3.0"):New("BazBarsDB", defaults, true)

    -- Profile callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnNewProfile", "OnProfileChanged")

    -- Register slash commands
    self:RegisterChatCommand("bb", "SlashCommand")
    self:RegisterChatCommand("bazbars", "SlashCommand")

    -- Setup AceConfig options panel
    self.Options:Setup()

    -- Minimap button
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and LDBIcon then
        local dataObj = LDB:NewDataObject("BazBars", {
            type = "launcher",
            text = "BazBars",
            icon = 5213776,
            OnClick = function(_, button)
                if button == "LeftButton" then
                    self.Options:Open()
                elseif button == "RightButton" then
                    if not InCombatLockdown() then
                        local id = self:CreateNewBar()
                        if id then
                            self:Print("Created Bar " .. id .. ". Enter Edit Mode to configure.")
                        end
                    end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:SetText("|cff66bbffBazBars|r", 1, 1, 1)
                tooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
                tooltip:AddLine("Right-click: Create new bar", 0.8, 0.8, 0.8)
            end,
        })
        LDBIcon:Register("BazBars", dataObj, self.db.profile.minimap)
    end
end

function addon:OnEnable()
    -- Load bars from saved data
    self.Bar:LoadAll()

    -- Register for button update events
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "OnUpdateEvent")
    self:RegisterEvent("SPELL_UPDATE_USABLE", "OnUpdateEvent")
    self:RegisterEvent("BAG_UPDATE", "OnUpdateEvent")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnUpdateEvent")
    self:RegisterEvent("ACTIONBAR_UPDATE_STATE", "OnUpdateEvent")
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "OnUpdateEvent")
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "OnUpdateEvent")
    self:RegisterEvent("UPDATE_MACROS", "OnUpdateEvent")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnRangeEvent")
    self:RegisterEvent("UNIT_POWER_UPDATE", "OnUpdateEvent")

    -- Edit Mode integration
    self:SetupEditMode()

    -- Initial update and restore keybinds
    C_Timer.After(1, function()
        self:UpdateAllButtons()
        self.Keybinds:RestoreAll()
    end)
end

---------------------------------------------------------------------------
-- Edit Mode Integration (Bartender4 pattern)
---------------------------------------------------------------------------

function addon:SetupEditMode()
    if not EditModeManagerFrame then return end

    -- Unlock all bars when entering Edit Mode
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        addon:OnEditModeEnter()
    end)

    -- Re-lock bars when exiting Edit Mode
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        addon:OnEditModeExit()
    end)

    -- Deselect our bars when Blizzard selects one of theirs
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        addon.Bar:DeselectAll()
    end)

    -- Add "Create New BazBar" button to Edit Mode panel
    local createBtn = CreateFrame("Button", nil, EditModeManagerFrame, "UIPanelButtonTemplate")
    createBtn:SetSize(330, 28)
    createBtn:SetText("Create New BazBar")
    createBtn:SetPoint("BOTTOM", EditModeManagerFrame, "BOTTOM", 0, -36)
    createBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            local id = addon:CreateNewBar()
            if id then
                addon:Print("Created Bar " .. id)
            end
        end
    end)
end

function addon:OnEditModeEnter()
    self.Bar:EnterEditMode()
end

function addon:OnEditModeExit()
    self.Bar:ExitEditMode()
end

---------------------------------------------------------------------------
-- Profile Change Handler
---------------------------------------------------------------------------

function addon:OnProfileChanged()
    -- Clear all keybinds
    if self.Keybinds then
        local keybindOwner = _G["BazBarsKeybindOwner"]
        if keybindOwner then
            ClearOverrideBindings(keybindOwner)
        end
    end

    -- Destroy all existing bars
    self.Bar:DeselectAll()
    self.Bar:DestroyAll()

    -- Recreate from new profile data
    self.Bar:LoadAll()

    -- Restore keybinds for new profile
    if self.Keybinds then
        self.Keybinds:RestoreAll()
    end

    -- Refresh options panel
    self.Options:Refresh()

    self:Print("Profile changed. Bars reloaded.")
end

---------------------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------------------

function addon:OnUpdateEvent()
    self:UpdateAllButtons()
end

function addon:OnRangeEvent()
    for id, frame in pairs(self.Bar:GetAll()) do
        for r, row in pairs(frame.buttons) do
            for c, btn in pairs(row) do
                if btn.bbCommand then
                    self.Button:UpdateRange(btn)
                end
            end
        end
    end
end

function addon:UpdateAllButtons()
    for id, frame in pairs(self.Bar:GetAll()) do
        for r, row in pairs(frame.buttons) do
            for c, btn in pairs(row) do
                if btn.bbCommand then
                    self.Button:UpdateButton(btn)
                end
            end
        end
    end
end

-- Range ticker: check range every 0.2s (like Blizzard action bars)
local rangeTimer = 0
local RANGE_INTERVAL = 0.2

local rangeFrame = CreateFrame("Frame")
rangeFrame:SetScript("OnUpdate", function(self, elapsed)
    rangeTimer = rangeTimer + elapsed
    if rangeTimer >= RANGE_INTERVAL then
        rangeTimer = 0
        if addon.Bar then
            for id, frame in pairs(addon.Bar:GetAll()) do
                for r, row in pairs(frame.buttons) do
                    for c, btn in pairs(row) do
                        if btn.bbCommand then
                            addon.Button:UpdateRange(btn)
                        end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Slash Commands
---------------------------------------------------------------------------

function addon:SlashCommand(input)
    local args = {}
    for word in input:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    local cmd = args[1]

    if not cmd or cmd == "options" or cmd == "config" then
        self.Options:Open()

    elseif cmd == "create" then
        local cols = tonumber(args[2]) or BazBars.DEFAULT_COLS
        local rows = tonumber(args[3]) or BazBars.DEFAULT_ROWS
        cols = math.max(1, math.min(BazBars.MAX_COLS, cols))
        rows = math.max(1, math.min(BazBars.MAX_ROWS, rows))
        local id = self:CreateNewBar(cols, rows)
        self:Print(("Created Bar %d (%dx%d). Use Edit Mode or /bb to configure."):format(id, cols, rows))

    elseif cmd == "export" then
        local id = tonumber(args[2])
        if id then
            local str = self:ExportBar(id)
            if str then
                -- Show in a copyable popup
                self.EditSettings:ShowExportString(str)
            else
                self:Print("Bar " .. id .. " not found.")
            end
        else
            self:Print("Usage: /bb export <bar id>")
        end

    elseif cmd == "import" then
        -- Everything after "import " is the string
        local importStr = input:match("^%S+%s+(.+)$")
        if importStr then
            self:ImportBar(importStr)
        else
            self.EditSettings:ShowImportDialog()
        end

    elseif cmd == "duplicate" or cmd == "dup" or cmd == "copy" then
        local id = tonumber(args[2])
        if id then
            local newID = self:DuplicateBar(id)
            if newID then
                self:Print(("Duplicated Bar %d as Bar %d."):format(id, newID))
            end
        else
            self:Print("Usage: /bb duplicate <bar id>")
        end

    elseif cmd == "delete" or cmd == "remove" then
        local id = tonumber(args[2])
        if id then
            self:DeleteBar(id)
        else
            self:Print("Usage: /bb delete <bar id>")
        end

    elseif cmd == "lock" or cmd == "unlock" then
        self:Print("Use Edit Mode (Esc > Edit Mode) to move and reposition bars.")

    elseif cmd == "scale" then
        local id = tonumber(args[2])
        local scale = tonumber(args[3])
        if id and scale then
            local frame = self.Bar:Get(id)
            if frame then
                self.Bar:SetScale(frame, scale)
                self:Print(("Bar %d scale set to %.2f"):format(id, scale))
            else
                self:Print("Bar " .. id .. " not found.")
            end
        else
            self:Print("Usage: /bb scale <bar id> <scale>")
        end

    elseif cmd == "padding" or cmd == "spacing" then
        local id = tonumber(args[2])
        local spacing = tonumber(args[3])
        if id and spacing then
            local frame = self.Bar:Get(id)
            if frame then
                self.Bar:Resize(frame, frame.barData.rows, frame.barData.cols, spacing)
                self:Print(("Bar %d spacing set to %d"):format(id, spacing))
            else
                self:Print("Bar " .. id .. " not found.")
            end
        else
            self:Print("Usage: /bb padding <bar id> <pixels>")
        end

    elseif cmd == "reset" then
        self:Print("Resetting all bars. Reload UI to apply.")
        self.db.profile.bars = {}
        ReloadUI()

    elseif cmd == "help" then
        self:Print("|cff66bbffBazBars Commands:|r")
        self:Print("  /bb - Open options panel")
        self:Print("  /bb create [cols] [rows] - Create a new bar")
        self:Print("  /bb delete <id> - Delete a bar")
        self:Print("  /bb lock - Lock all bars")
        self:Print("  /bb unlock - Unlock all bars")
        self:Print("  /bb scale <id> <scale> - Set bar scale")
        self:Print("  /bb padding <id> <pixels> - Set button spacing")
        self:Print("  /bb reset - Reset all bars (reloads UI)")

    else
        self:Print("Unknown command. Type /bb help for usage.")
    end
end

---------------------------------------------------------------------------
-- Import / Export
---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
        return B64:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function base64decode(data)
    data = data:gsub('[^' .. B64 .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (B64:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function serializeValue(val, depth)
    depth = depth or 0
    if depth > 10 then return "nil" end
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local key
            if type(k) == "number" then
                key = "[" .. k .. "]"
            else
                key = "[" .. string.format("%q", k) .. "]"
            end
            parts[#parts + 1] = key .. "=" .. serializeValue(v, depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

function addon:ExportBar(barID)
    local barData = self.db.profile.bars[barID]
    if not barData then return nil end

    local exportData = CopyTable(barData)
    exportData.pos = nil -- don't export position
    exportData.id = nil  -- will be reassigned on import

    local serialized = "BAZBAR1:" .. serializeValue(exportData)
    return base64encode(serialized)
end

function addon:ImportBar(encodedString)
    if not encodedString or encodedString == "" then
        self:Print("No import string provided.")
        return
    end

    local decoded = base64decode(encodedString)
    if not decoded or not decoded:match("^BAZBAR1:") then
        self:Print("Invalid import string.")
        return
    end

    local tableStr = decoded:sub(9) -- strip "BAZBAR1:"
    local func, err = loadstring("return " .. tableStr)
    if not func then
        self:Print("Failed to parse import data.")
        return
    end

    -- Sandbox: run in empty environment
    setfenv(func, {})
    local ok, barData = pcall(func)
    if not ok or type(barData) ~= "table" then
        self:Print("Invalid bar data in import string.")
        return
    end

    -- Assign new ID and create
    local newID = self.Bar:GetNextID()
    barData.id = newID
    barData.pos = nil -- center of screen

    self.db.profile.bars[newID] = barData
    local frame = self.Bar:Create(barData)

    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            self.Button:LoadButton(btn)
        end
    end

    self.Bar:ApplyVisibility(frame)
    self.Bar:UpdateSlotArt(frame)
    self.Bar:UpdateButtonVisibility(frame)
    self.Bar:SetBarAlpha(frame, barData.alpha or 1.0)
    self.Bar:ApplyMouseoverFade(frame)
    self.Options:Refresh()

    self:Print("Imported as Bar " .. newID .. ".")
    return newID
end

---------------------------------------------------------------------------
-- Bar Management (called from commands and options)
---------------------------------------------------------------------------

function addon:CreateNewBar(cols, rows)
    if InCombatLockdown() then
        self:Print("Cannot create bars during combat.")
        return
    end

    local id = self.Bar:GetNextID()
    local barData = BazBars.DefaultBarData(id)
    barData.cols = cols or BazBars.DEFAULT_COLS
    barData.rows = rows or BazBars.DEFAULT_ROWS

    self.db.profile.bars[id] = barData
    self.Bar:Create(barData)
    self.Options:Refresh()

    return id
end

function addon:DuplicateBar(sourceID)
    if InCombatLockdown() then
        self:Print("Cannot duplicate bars during combat.")
        return
    end

    local sourceData = self.db.profile.bars[sourceID]
    if not sourceData then
        self:Print("Bar " .. sourceID .. " not found.")
        return
    end

    local newID = self.Bar:GetNextID()
    local newData = CopyTable(sourceData)
    newData.id = newID
    newData.pos = nil -- reset position so it doesn't overlap
    newData.customName = (newData.customName or ("Bar " .. sourceID)) .. " (Copy)"

    self.db.profile.bars[newID] = newData
    local frame = self.Bar:Create(newData)

    -- Load duplicated button assignments
    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            self.Button:LoadButton(btn)
        end
    end

    self.Bar:ApplyVisibility(frame)
    self.Bar:UpdateSlotArt(frame)
    self.Bar:UpdateButtonVisibility(frame)
    self.Bar:SetBarAlpha(frame, newData.alpha or 1.0)
    self.Bar:ApplyMouseoverFade(frame)
    self.Options:Refresh()

    return newID
end

function addon:DeleteBar(id)
    if InCombatLockdown() then
        self:Print("Cannot delete bars during combat.")
        return
    end

    if self.Bar:Destroy(id) then
        self.db.profile.bars[id] = nil
        self.Options:Refresh()
        self:Print("Bar " .. id .. " deleted.")
    else
        self:Print("Bar " .. id .. " not found.")
    end
end

