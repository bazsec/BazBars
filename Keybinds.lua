-- BazBars Quick Keybind Mode
-- Hover a button, press a key to bind it

local addon = BazCore:GetAddon("BazBars")
local Keybinds = {}
addon.Keybinds = Keybinds

local keybindFrame = nil
local keybindOwner = nil -- secure header for override bindings
local hoveredButton = nil
local isActive = false

-- Keys to ignore (modifiers only)
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true,
    LCTRL = true, RCTRL = true,
    LALT = true, RALT = true,
}

---------------------------------------------------------------------------
-- Key text formatting (matches Blizzard style)
---------------------------------------------------------------------------

local function FormatKeyText(key)
    if not key then return "" end
    -- Shorten common names
    key = key:gsub("CTRL%-", "C-")
    key = key:gsub("SHIFT%-", "S-")
    key = key:gsub("ALT%-", "A-")
    key = key:gsub("MOUSEWHEELUP", "MWU")
    key = key:gsub("MOUSEWHEELDOWN", "MWD")
    key = key:gsub("BUTTON", "M")
    key = key:gsub("NUMPAD", "N")
    return key
end

---------------------------------------------------------------------------
-- Binding management
---------------------------------------------------------------------------

function Keybinds:SetBinding(buttonName, key)
    if not keybindOwner then
        keybindOwner = CreateFrame("Frame", "BazBarsKeybindOwner", UIParent, "SecureHandlerBaseTemplate")
    end

    -- Clear any existing binding for this button
    local oldKey = addon.db.profile.keybinds and addon.db.profile.keybinds[buttonName]
    if oldKey then
        SetOverrideBindingClick(keybindOwner, true, oldKey, nil)
    end

    -- Clear any existing action on this key
    if key then
        for name, boundKey in pairs(addon.db.profile.keybinds or {}) do
            if boundKey == key and name ~= buttonName then
                addon.db.profile.keybinds[name] = nil
                -- Update hotkey text on the old button
                local btn = _G[name]
                if btn and btn.HotKey then
                    btn.HotKey:SetText("")
                    btn.HotKey:Hide()
                end
            end
        end
    end

    -- Set new binding
    addon.db.profile.keybinds = addon.db.profile.keybinds or {}
    if key then
        SetOverrideBindingClick(keybindOwner, true, key, buttonName, "LeftButton")
        addon.db.profile.keybinds[buttonName] = key
    else
        addon.db.profile.keybinds[buttonName] = nil
    end

    -- Update hotkey text
    local btn = _G[buttonName]
    if btn and btn.HotKey then
        if key then
            btn.HotKey:SetText(FormatKeyText(key))
            btn.HotKey:Show()
        else
            btn.HotKey:SetText("")
            btn.HotKey:Hide()
        end
    end
end

function Keybinds:ClearBinding(buttonName)
    Keybinds:SetBinding(buttonName, nil)
end

function Keybinds:RestoreAll()
    if not addon.db.profile.keybinds then return end
    if InCombatLockdown() then
        -- Defer until combat ends
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            Keybinds:RestoreAll()
        end)
        return
    end

    if not keybindOwner then
        keybindOwner = CreateFrame("Frame", "BazBarsKeybindOwner", UIParent, "SecureHandlerBaseTemplate")
    end

    -- Clear all existing overrides first to avoid stale bindings
    ClearOverrideBindings(keybindOwner)

    for buttonName, key in pairs(addon.db.profile.keybinds) do
        if key and _G[buttonName] then
            SetOverrideBindingClick(keybindOwner, true, key, buttonName, "LeftButton")
            local btn = _G[buttonName]
            if btn and btn.HotKey then
                btn.HotKey:SetText(FormatKeyText(key))
                btn.HotKey:Show()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Quick Keybind Mode UI
---------------------------------------------------------------------------

local function CreateKeybindFrame()
    local f = CreateFrame("Frame", "BazBarsKeybindFrame", UIParent, "BackdropTemplate")
    f:SetSize(400, 200)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(300)

    -- Blizzard dialog border
    local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()

    -- Title bar
    local titleBG = CreateFrame("Frame", nil, f, "DialogHeaderTemplate")
    titleBG:SetPoint("TOP", 0, 12)
    titleBG.Text:SetText("Quick Keybind Mode")

    -- Description text
    local desc1 = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc1:SetPoint("TOP", 0, -25)
    desc1:SetWidth(360)
    desc1:SetText("You are in Quick Keybind Mode. Mouse over a button and press the desired key to set the binding for that button.")

    local desc2 = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc2:SetPoint("TOP", desc1, "BOTTOM", 0, -12)
    desc2:SetWidth(360)
    desc2:SetText("Canceling will remove you from Quick Keybind Mode.")

    -- Character specific checkbox
    local charCB = CreateFrame("CheckButton", nil, f)
    charCB:SetSize(26, 26)
    charCB:SetPoint("BOTTOM", 0, 60)
    charCB:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    charCB:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    charCB:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    charCB:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local cbLabel = charCB:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbLabel:SetPoint("LEFT", charCB, "RIGHT", 4, 0)
    cbLabel:SetText("Character Specific Keybindings")

    -- Buttons row
    local okayBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okayBtn:SetSize(120, 28)
    okayBtn:SetPoint("BOTTOMLEFT", 20, 18)
    okayBtn:SetText("Okay")
    okayBtn:SetScript("OnClick", function()
        Keybinds:ExitMode()
    end)

    local defaultsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    defaultsBtn:SetSize(120, 28)
    defaultsBtn:SetPoint("BOTTOM", 0, 18)
    defaultsBtn:SetText("Reset To Default")
    defaultsBtn:SetScript("OnClick", function()
        -- Clear all BazBars keybinds
        if addon.db.profile.keybinds then
            for buttonName, _ in pairs(addon.db.profile.keybinds) do
                Keybinds:ClearBinding(buttonName)
            end
        end
        addon.db.profile.keybinds = {}
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(120, 28)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 18)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        Keybinds:ExitMode()
    end)

    -- Use the dialog frame itself as the key listener
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(true)

    f:SetScript("OnKeyDown", function(self, key)
        if MODIFIER_KEYS[key] then return end
        if not hoveredButton then
            -- If not hovering a button, let ESC close the dialog
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                Keybinds:ExitMode()
            end
            return
        end

        -- Don't propagate this key press
        self:SetPropagateKeyboardInput(false)

        -- Build chord with modifiers
        local chord = ""
        if IsShiftKeyDown() then chord = chord .. "SHIFT-" end
        if IsControlKeyDown() then chord = chord .. "CTRL-" end
        if IsAltKeyDown() then chord = chord .. "ALT-" end

        -- ESC unbinds
        if key == "ESCAPE" then
            Keybinds:ClearBinding(hoveredButton:GetName())
            return
        end

        chord = chord .. key
        Keybinds:SetBinding(hoveredButton:GetName(), chord)
    end)

    f:SetScript("OnKeyUp", function(self)
        self:SetPropagateKeyboardInput(true)
    end)
    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- Enter / Exit keybind mode
---------------------------------------------------------------------------

function Keybinds:EnterMode()
    if isActive then return end

    if not keybindFrame then
        keybindFrame = CreateKeybindFrame()
    end

    isActive = true

    -- Deselect bar and hide edit overlays so they don't clutter keybind mode
    addon.Bar:DeselectAll()
    for id, frame in pairs(addon.Bar:GetAll()) do
        frame._bazEditOverlay:Hide()
    end

    keybindFrame:Show()

    -- Hook all BazBars buttons for hover detection
    for id, frame in pairs(addon.Bar:GetAll()) do
        local barData = frame.barData
        for r, row in pairs(frame.buttons) do
            for c, btn in pairs(row) do
                if r <= barData.rows and c <= barData.cols then
                    -- Show highlight border
                    if not btn.bbKeybindHighlight then
                        local hl = btn:CreateTexture(nil, "OVERLAY")
                        hl:SetAllPoints()
                        hl:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
                        hl:SetAlpha(0.3)
                        btn.bbKeybindHighlight = hl
                    end
                    btn.bbKeybindHighlight:Show()

                    -- Override enter/leave for keybind mode
                    btn.bbOldOnEnter = btn:GetScript("OnEnter")
                    btn.bbOldOnLeave = btn:GetScript("OnLeave")

                    btn:SetScript("OnEnter", function(self)
                        hoveredButton = self
                        if self.bbKeybindHighlight then
                            self.bbKeybindHighlight:SetAlpha(1.0)
                        end
                        -- Show current binding in tooltip
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        local name = self:GetName()
                        local key = addon.db.profile.keybinds and addon.db.profile.keybinds[name]
                        if key then
                            GameTooltip:SetText("Current: " .. key, 1, 1, 1)
                            GameTooltip:AddLine("Press a key to rebind, ESC to clear", 0.8, 0.8, 0.8)
                        else
                            GameTooltip:SetText("Press a key to bind", 1, 1, 1)
                        end
                        GameTooltip:Show()
                    end)

                    btn:SetScript("OnLeave", function(self)
                        hoveredButton = nil
                        if self.bbKeybindHighlight then
                            self.bbKeybindHighlight:SetAlpha(0.3)
                        end
                        GameTooltip_Hide()
                    end)
                end
            end
        end
    end
end

function Keybinds:ExitMode()
    if not isActive then return end

    isActive = false
    hoveredButton = nil

    if keybindFrame then
        keybindFrame:Hide()
    end

    -- Restore original button scripts and hide highlights
    for id, frame in pairs(addon.Bar:GetAll()) do
        for r, row in pairs(frame.buttons) do
            for c, btn in pairs(row) do
                if btn.bbKeybindHighlight then
                    btn.bbKeybindHighlight:Hide()
                end
                if btn.bbOldOnEnter then
                    btn:SetScript("OnEnter", btn.bbOldOnEnter)
                    btn.bbOldOnEnter = nil
                end
                if btn.bbOldOnLeave then
                    btn:SetScript("OnLeave", btn.bbOldOnLeave)
                    btn.bbOldOnLeave = nil
                end
            end
        end
    end

    -- Restore Edit Mode overlays if still in Edit Mode
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        for id, frame in pairs(addon.Bar:GetAll()) do
            frame._bazEditOverlay:Show()
        end
    end
end

function Keybinds:IsActive()
    return isActive
end
