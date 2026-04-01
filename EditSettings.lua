-- BazBars Edit Mode Settings Popup
-- Matches Blizzard's EditModeSystemSettingsDialog visual style

local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")
local EditSettings = {}
addon.EditSettings = EditSettings

local settingsFrame = nil
local attachedBar = nil
local savedState = nil -- for revert

local PANEL_WIDTH = 340
local LABEL_WIDTH = 100
local SLIDER_WIDTH = 140
local ROW_HEIGHT = 32
local ROW_SPACING = 2

---------------------------------------------------------------------------
-- Widget Builders
---------------------------------------------------------------------------

local function CreateSettingSlider(parent, label, minVal, maxVal, step, formatFunc)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    text:SetPoint("LEFT")
    text:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    text:SetJustifyH("LEFT")
    text:SetText(label)

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", text, "RIGHT", 5, 0)
    slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)

    local valText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    valText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valText:SetWidth(50)
    valText:SetJustifyH("RIGHT")
    valText:SetTextColor(1, 0.82, 0) -- yellow like Blizzard

    row.slider = slider
    row.valText = valText
    row.formatFunc = formatFunc or function(v) return tostring(math.floor(v + 0.5)) end

    slider.Slider:SetMinMaxValues(minVal, maxVal)
    slider.Slider:SetValueStep(step)
    slider.Slider:SetObeyStepOnDrag(true)

    slider.Slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valText:SetText(row.formatFunc(value))
        if row.onChange then
            row.onChange(value)
        end
    end)

    row.SetValue = function(self, val)
        slider.Slider:SetValue(val)
        valText:SetText(self.formatFunc(val))
    end

    row.GetValue = function(self)
        return slider.Slider:GetValue()
    end

    return row
end

local function CreateSettingCheckbox(parent, label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)

    local cb = CreateFrame("CheckButton", nil, row)
    cb:SetSize(26, 26)
    cb:SetPoint("LEFT", 0, 0)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if row.onChange then
            row.onChange(self:GetChecked())
        end
    end)

    row.checkbox = cb

    row.SetValue = function(self, val)
        cb:SetChecked(val)
    end

    row.GetValue = function(self)
        return cb:GetChecked()
    end

    return row
end

local function CreateSettingDropdown(parent, label, options)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    text:SetPoint("LEFT")
    text:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    text:SetJustifyH("LEFT")
    text:SetText(label)

    local btn = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    btn:SetPoint("LEFT", text, "RIGHT", 5, 0)
    btn:SetWidth(SLIDER_WIDTH)

    row.dropdown = btn
    row.options = options
    row.selectedValue = nil

    row.SetValue = function(self, val)
        self.selectedValue = val
        local found = false
        for _, opt in ipairs(options) do
            if opt.value == val then
                btn:SetDefaultText(opt.label)
                found = true
                break
            end
        end
        if not found then
            btn:SetDefaultText("Custom")
        end
    end

    row.Setup = function(self)
        btn:SetupMenu(function(dropdown, rootDescription)
            for _, opt in ipairs(options) do
                rootDescription:CreateRadio(opt.label, function() return row.selectedValue == opt.value end, function()
                    row.selectedValue = opt.value
                    btn:SetDefaultText(opt.label)
                    if row.onChange then
                        row.onChange(opt.value)
                    end
                end)
            end
        end)
    end

    return row
end

local function CreateExtraButton(parent, label)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(PANEL_WIDTH - 20, 28)
    btn:SetText(label)
    return btn
end

---------------------------------------------------------------------------
-- Build the Settings Frame
---------------------------------------------------------------------------

local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "BazBarsEditSettingsFrame", UIParent)
    f:SetSize(PANEL_WIDTH, 800)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Blizzard translucent dialog border
    local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    f.border = border

    -- Drag
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Title
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    f.title = title

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function()
        local barFrame = attachedBar
        EditSettings:Hide()
        if barFrame then
            addon.Bar:Deselect(barFrame)
        end
    end)

    -- Settings area start
    local anchor = title
    local yOff = -16

    -- Bar Name input
    local nameRow = CreateFrame("Frame", nil, f)
    nameRow:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)
    nameRow:SetPoint("TOP", anchor, "BOTTOM", 0, yOff)

    local nameLabel = nameRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    nameLabel:SetPoint("LEFT")
    nameLabel:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText("Bar Name")

    local nameBox = CreateFrame("EditBox", nil, nameRow, "InputBoxTemplate")
    nameBox:SetSize(SLIDER_WIDTH, 20)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if attachedBar then
            local name = self:GetText()
            addon.Bar:SetCustomName(attachedBar, name)
            f.title:SetText(addon.Bar:GetDisplayName(attachedBar))
        end
    end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.nameBox = nameBox
    anchor = nameRow

    -- Orientation dropdown
    f.orientation = CreateSettingDropdown(f, "Orientation", {
        { label = "Horizontal", value = "horizontal" },
        { label = "Vertical", value = "vertical" },
    })
    f.orientation:SetPoint("TOP", anchor, "BOTTOM", 0, yOff)
    f.orientation.onChange = function(val)
        if attachedBar then
            attachedBar.barData.orientation = val
            addon.db.profile.bars[attachedBar.barData.id].orientation = val
            addon.Bar:LayoutButtons(attachedBar, attachedBar.barData)
        end
    end
    anchor = f.orientation

    -- # of Rows
    f.rowsSlider = CreateSettingSlider(f, "# of Rows", 1, BazBars.MAX_ROWS, 1)
    f.rowsSlider:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.rowsSlider.onChange = function(val)
        if attachedBar then
            local bd = attachedBar.barData
            addon.Bar:Resize(attachedBar, val, bd.cols, bd.spacing)
            addon.db.profile.bars[bd.id].rows = val
        end
    end
    anchor = f.rowsSlider

    -- # of Icons (columns)
    f.colsSlider = CreateSettingSlider(f, "# of Icons", 1, BazBars.MAX_COLS, 1)
    f.colsSlider:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.colsSlider.onChange = function(val)
        if attachedBar then
            local bd = attachedBar.barData
            addon.Bar:Resize(attachedBar, bd.rows, val, bd.spacing)
            addon.db.profile.bars[bd.id].cols = val
        end
    end
    anchor = f.colsSlider

    -- Icon Size (scale as percentage)
    f.scaleSlider = CreateSettingSlider(f, "Icon Size", 50, 250, 5, function(v)
        return math.floor(v + 0.5) .. "%"
    end)
    f.scaleSlider:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.scaleSlider.onChange = function(val)
        if attachedBar then
            addon.Bar:SetScale(attachedBar, val / 100)
        end
    end
    anchor = f.scaleSlider

    -- Icon Padding
    f.paddingSlider = CreateSettingSlider(f, "Icon Padding", 0, 20, 1)
    f.paddingSlider:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.paddingSlider.onChange = function(val)
        if attachedBar then
            local bd = attachedBar.barData
            addon.Bar:Resize(attachedBar, bd.rows, bd.cols, val)
            addon.db.profile.bars[bd.id].spacing = val
        end
    end
    anchor = f.paddingSlider

    -- Always Show Buttons (show empty slots even when no ability assigned)
    f.showButtons = CreateSettingCheckbox(f, "Always Show Buttons")
    f.showButtons:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.showButtons.onChange = function(val)
        if attachedBar then
            attachedBar.barData.alwaysShowButtons = val
            addon.db.profile.bars[attachedBar.barData.id].alwaysShowButtons = val
            addon.Bar:UpdateButtonVisibility(attachedBar)
        end
    end
    anchor = f.showButtons

    -- Show Slot Art (the background texture on each button)
    f.showSlotArt = CreateSettingCheckbox(f, "Show Slot Art")
    f.showSlotArt:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.showSlotArt.onChange = function(val)
        if attachedBar then
            attachedBar.barData.showSlotArt = val
            addon.db.profile.bars[attachedBar.barData.id].showSlotArt = val
            addon.Bar:UpdateSlotArt(attachedBar)
        end
    end
    anchor = f.showSlotArt

    -- Bar Opacity slider (0-100, maps to 0.0-1.0)
    f.alphaSlider = CreateSettingSlider(f, "Bar Opacity", 0, 100, 5, function(v)
        return math.floor(v + 0.5) .. "%"
    end)
    f.alphaSlider:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.alphaSlider.onChange = function(val)
        if attachedBar then
            addon.Bar:SetBarAlpha(attachedBar, val / 100)
        end
    end
    anchor = f.alphaSlider

    -- Mouseover Fade checkbox
    f.mouseoverFade = CreateSettingCheckbox(f, "Mouseover Fade")
    f.mouseoverFade:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.mouseoverFade.onChange = function(val)
        if attachedBar then
            attachedBar.barData.mouseoverFade = val
            addon.db.profile.bars[attachedBar.barData.id].mouseoverFade = val
            addon.Bar:ApplyMouseoverFade(attachedBar)
        end
    end
    anchor = f.mouseoverFade

    -- Bar Visible dropdown (common presets)
    f.visibilityDropdown = CreateSettingDropdown(f, "Bar Visible", {
        { label = "Always Visible", value = "" },
        { label = "In Combat", value = "[combat] show; hide" },
        { label = "Out of Combat", value = "[nocombat] show; hide" },
        { label = "With Target", value = "[exists] show; hide" },
        { label = "On Mouseover", value = "[mod:shift] show; hide" },
    })
    f.visibilityDropdown:SetPoint("TOP", anchor, "BOTTOM", 0, -ROW_SPACING)
    f.visibilityDropdown.onChange = function(val)
        if attachedBar then
            addon.Bar:SetVisibilityMacro(attachedBar, val)
        end
    end
    anchor = f.visibilityDropdown

    -- Divider
    local divider1 = f:CreateTexture(nil, "ARTWORK")
    divider1:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    divider1:SetSize(PANEL_WIDTH - 40, 1)
    divider1:SetColorTexture(0.5, 0.5, 0.5, 0.3)

    -- Revert Changes button
    f.revertBtn = CreateExtraButton(f, "Revert Changes")
    f.revertBtn:SetPoint("TOP", divider1, "BOTTOM", 0, -8)
    f.revertBtn:SetScript("OnClick", function()
        if attachedBar and savedState then
            local bd = attachedBar.barData
            local id = bd.id
            addon.Bar:Resize(attachedBar, savedState.rows, savedState.cols, savedState.spacing)
            addon.Bar:SetScale(attachedBar, savedState.scale)
            bd.orientation = savedState.orientation
            bd.alwaysShowButtons = savedState.alwaysShowButtons
            addon.db.profile.bars[id] = CopyTable(bd)
            addon.Bar:LayoutButtons(attachedBar, bd)
            -- Refresh sliders
            EditSettings:PopulateValues(attachedBar)
        end
    end)

    -- Divider 2
    local divider2 = f:CreateTexture(nil, "ARTWORK")
    divider2:SetPoint("TOP", f.revertBtn, "BOTTOM", 0, -8)
    divider2:SetSize(PANEL_WIDTH - 40, 1)
    divider2:SetColorTexture(0.5, 0.5, 0.5, 0.3)

    -- Reset To Default Position
    f.resetPosBtn = CreateExtraButton(f, "Reset To Default Position")
    f.resetPosBtn:SetPoint("TOP", divider2, "BOTTOM", 0, -8)
    f.resetPosBtn:SetScript("OnClick", function()
        if attachedBar then
            local bd = attachedBar.barData
            bd.pos = nil
            addon.db.profile.bars[bd.id].pos = nil
            addon.Bar:RestorePosition(attachedBar, bd)
        end
    end)

    -- Nudge controls
    local nudgeLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    nudgeLabel:SetPoint("TOP", f.resetPosBtn, "BOTTOM", 0, -10)
    nudgeLabel:SetText("Nudge Position")

    local NUDGE_SIZE = 26
    local nudgeContainer = CreateFrame("Frame", nil, f)
    nudgeContainer:SetSize(NUDGE_SIZE * 3 + 8, NUDGE_SIZE * 3 + 8)
    nudgeContainer:SetPoint("TOP", nudgeLabel, "BOTTOM", 0, -4)

    -- Arrow rotation: UP=0, DOWN=pi, LEFT=pi/2, RIGHT=-pi/2
    local function MakeNudgeBtn(parent, rotation, xOff, yOff, dx, dy)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(NUDGE_SIZE, NUDGE_SIZE)
        btn:SetPoint("CENTER", parent, "CENTER", xOff, yOff)
        btn:SetText("")
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("CENTER")
        arrow:SetAtlas("NPE_ArrowUp")
        arrow:SetRotation(rotation)
        btn:SetScript("OnClick", function()
            if attachedBar then
                addon.Bar:Nudge(attachedBar, dx, dy)
            end
        end)
        return btn
    end

    local step = NUDGE_SIZE + 2
    MakeNudgeBtn(nudgeContainer, 0, 0, step, 0, 1)                    -- Up
    MakeNudgeBtn(nudgeContainer, math.pi, 0, -step, 0, -1)            -- Down
    MakeNudgeBtn(nudgeContainer, math.pi / 2, -step, 0, -1, 0)        -- Left
    MakeNudgeBtn(nudgeContainer, -math.pi / 2, step, 0, 1, 0)         -- Right

    f.nudgeContainer = nudgeContainer

    -- Quick Keybind Mode
    f.keybindBtn = CreateExtraButton(f, "Quick Keybind Mode")
    f.keybindBtn:SetPoint("TOP", nudgeContainer, "BOTTOM", 0, -8)
    f.keybindBtn:SetScript("OnClick", function()
        addon.Keybinds:EnterMode()
    end)

    -- BazBars Settings (opens AceConfig options)
    f.settingsBtn = CreateExtraButton(f, "BazBars Settings")
    f.settingsBtn:SetPoint("TOP", f.keybindBtn, "BOTTOM", 0, -4)
    f.settingsBtn:SetScript("OnClick", function()
        addon.Options:Open()
    end)

    -- Delete This Bar
    f.deleteBtn = CreateExtraButton(f, "|cffff4444Delete This Bar|r")
    f.deleteBtn:SetPoint("TOP", f.settingsBtn, "BOTTOM", 0, -4)
    f.deleteBtn:SetScript("OnClick", function()
        if attachedBar then
            local id = attachedBar.barData.id
            EditSettings:Hide()
            addon:DeleteBar(id)
        end
    end)

    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- Populate values from bar data
---------------------------------------------------------------------------

function EditSettings:PopulateValues(barFrame)
    if not settingsFrame then return end
    local bd = barFrame.barData

    settingsFrame.orientation:SetValue(bd.orientation or "horizontal")
    settingsFrame.orientation:Setup()
    settingsFrame.rowsSlider:SetValue(bd.rows)
    settingsFrame.colsSlider:SetValue(bd.cols)
    settingsFrame.scaleSlider:SetValue((bd.scale or 1) * 100)
    settingsFrame.paddingSlider:SetValue(bd.spacing)
    settingsFrame.showButtons:SetValue(bd.alwaysShowButtons ~= false)
    settingsFrame.showSlotArt:SetValue(bd.showSlotArt ~= false)
    settingsFrame.alphaSlider:SetValue((bd.alpha or 1.0) * 100)
    settingsFrame.mouseoverFade:SetValue(bd.mouseoverFade or false)
    settingsFrame.nameBox:SetText(bd.customName or "")
    settingsFrame.visibilityDropdown:SetValue(bd.visibilityMacro or "")
    settingsFrame.visibilityDropdown:Setup()
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function EditSettings:AttachToBar(barFrame)
    if not settingsFrame then
        settingsFrame = CreateSettingsFrame()
    end

    attachedBar = barFrame
    local bd = barFrame.barData

    -- Save state for revert
    savedState = {
        rows = bd.rows,
        cols = bd.cols,
        spacing = bd.spacing,
        scale = bd.scale,
        orientation = bd.orientation,
        alwaysShowButtons = bd.alwaysShowButtons,
        showSlotArt = bd.showSlotArt,
        visibilityMacro = bd.visibilityMacro,
        alpha = bd.alpha,
        mouseoverFade = bd.mouseoverFade,
        customName = bd.customName,
    }

    settingsFrame.title:SetText(addon.Bar:GetDisplayName(barFrame))
    EditSettings:PopulateValues(barFrame)

    -- Anchor to a fixed screen position (not the bar) so resizing doesn't move the panel
    local barRight = barFrame:GetRight() * barFrame:GetEffectiveScale()
    local barTop = barFrame:GetTop() * barFrame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    settingsFrame:ClearAllPoints()
    settingsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", barRight / uiScale + 10, barTop / uiScale + 10)
    settingsFrame:Show()
end

function EditSettings:Hide()
    if settingsFrame then
        settingsFrame:Hide()
    end
    attachedBar = nil
    savedState = nil
end

function EditSettings:IsShown()
    return settingsFrame and settingsFrame:IsShown()
end
