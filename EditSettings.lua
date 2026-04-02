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
local BTN_WIDTH = PANEL_WIDTH - 30

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
    btn:SetSize(BTN_WIDTH, 28)
    btn:SetText(label)
    return btn
end

---------------------------------------------------------------------------
-- Collapsible Section Builder
---------------------------------------------------------------------------

local function CreateSection(parent, label, startExpanded)
    local section = CreateFrame("Frame", nil, parent)
    section:SetWidth(PANEL_WIDTH - 20)
    section.children = {}
    section.expanded = startExpanded ~= false

    -- Header button
    local header = CreateFrame("Button", nil, section)
    header:SetSize(PANEL_WIDTH - 20, 24)
    header:SetPoint("TOP")

    local arrowDown = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    arrowDown:SetPoint("LEFT", 5, 0)
    arrowDown:SetText("|TInterface\\Buttons\\Arrow-Down-Up:14:14|t")
    section.arrowDown = arrowDown

    local arrowRight = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    arrowRight:SetPoint("LEFT", 5, 0)
    arrowRight:SetText("|TInterface\\ChatFrame\\ChatFrameExpandArrow:14:14|t")
    section.arrowRight = arrowRight

    local headerText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerText:SetPoint("LEFT", arrowDown, "RIGHT", 4, 0)
    headerText:SetText(label)
    headerText:SetTextColor(1, 0.82, 0)

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", headerText, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", header, "RIGHT", -5, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.4)

    section.header = header

    function section:AddChild(child)
        self.children[#self.children + 1] = child
        child:SetParent(self)
    end

    function section:Layout(yStart)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", 10, yStart)

        if self.expanded then
            self.arrowDown:Show()
            self.arrowRight:Hide()
            local y = -28
            for _, child in ipairs(self.children) do
                child:ClearAllPoints()
                child:SetPoint("TOPLEFT", self, "TOPLEFT", 5, y)
                child:Show()
                y = y - (child:GetHeight() + ROW_SPACING)
            end
            local totalHeight = -y + 28
            self:SetHeight(totalHeight)
            return totalHeight
        else
            self.arrowDown:Hide()
            self.arrowRight:Show()
            for _, child in ipairs(self.children) do
                child:Hide()
            end
            self:SetHeight(24)
            return 24
        end
    end

    header:SetScript("OnClick", function()
        section.expanded = not section.expanded
        if parent.LayoutSections then
            parent:LayoutSections()
        end
    end)

    return section
end

---------------------------------------------------------------------------
-- Build the Settings Frame
---------------------------------------------------------------------------

local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "BazBarsEditSettingsFrame", UIParent)
    f:SetSize(PANEL_WIDTH, 600)
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

    -- Bar Name input (always visible, above sections)
    local nameRow = CreateFrame("Frame", nil, f)
    nameRow:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)
    nameRow:SetPoint("TOP", title, "BOTTOM", 0, -12)

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
            addon.Bar:SetCustomName(attachedBar, self:GetText())
            f.title:SetText(addon.Bar:GetDisplayName(attachedBar))
        end
    end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.nameBox = nameBox

    ---------------------------------------------------------------------------
    -- Section: Layout
    ---------------------------------------------------------------------------
    local secLayout = CreateSection(f, "Layout", true)
    f.secLayout = secLayout

    f.orientation = CreateSettingDropdown(f, "Orientation", {
        { label = "Horizontal", value = "horizontal" },
        { label = "Vertical", value = "vertical" },
    })
    f.orientation.onChange = function(val)
        if attachedBar then
            attachedBar.barData.orientation = val
            addon.db.profile.bars[attachedBar.barData.id].orientation = val
            addon.Bar:LayoutButtons(attachedBar, attachedBar.barData)
        end
    end
    secLayout:AddChild(f.orientation)

    f.rowsSlider = CreateSettingSlider(f, "# of Rows", 1, BazBars.MAX_ROWS, 1)
    f.rowsSlider.onChange = function(val)
        if attachedBar then
            local bd = attachedBar.barData
            addon.Bar:Resize(attachedBar, val, bd.cols, bd.spacing)
            addon.db.profile.bars[bd.id].rows = val
        end
    end
    secLayout:AddChild(f.rowsSlider)

    f.colsSlider = CreateSettingSlider(f, "# of Icons", 1, BazBars.MAX_COLS, 1)
    f.colsSlider.onChange = function(val)
        if attachedBar then
            local bd = attachedBar.barData
            addon.Bar:Resize(attachedBar, bd.rows, val, bd.spacing)
            addon.db.profile.bars[bd.id].cols = val
        end
    end
    secLayout:AddChild(f.colsSlider)

    f.scaleSlider = CreateSettingSlider(f, "Icon Size", 50, 250, 5, function(v)
        return math.floor(v + 0.5) .. "%"
    end)
    f.scaleSlider.onChange = function(val)
        if attachedBar then
            addon.Bar:SetScale(attachedBar, val / 100)
        end
    end
    secLayout:AddChild(f.scaleSlider)

    f.paddingSlider = CreateSettingSlider(f, "Icon Padding", 0, 20, 1)
    f.paddingSlider.onChange = function(val)
        if attachedBar then
            local bd = attachedBar.barData
            addon.Bar:Resize(attachedBar, bd.rows, bd.cols, val)
            addon.db.profile.bars[bd.id].spacing = val
        end
    end
    secLayout:AddChild(f.paddingSlider)

    -- Nudge (inline: Label + U D L R buttons in a row)
    local nudgeRow = CreateFrame("Frame", nil, f)
    nudgeRow:SetSize(PANEL_WIDTH - 30, ROW_HEIGHT)

    local nudgeLabel = nudgeRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    nudgeLabel:SetPoint("LEFT")
    nudgeLabel:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    nudgeLabel:SetJustifyH("LEFT")
    nudgeLabel:SetText("Nudge")

    local NUDGE_SIZE = 26
    local function MakeNudgeBtn(parent, anchorTo, rotation, dx, dy)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(NUDGE_SIZE, NUDGE_SIZE)
        btn:SetPoint("LEFT", anchorTo, "RIGHT", 4, 0)
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

    local b1 = MakeNudgeBtn(nudgeRow, nudgeLabel, math.pi / 2, -1, 0)    -- Left
    local b2 = MakeNudgeBtn(nudgeRow, b1, -math.pi / 2, 1, 0)            -- Right
    local b3 = MakeNudgeBtn(nudgeRow, b2, 0, 0, 1)                        -- Up
    local b4 = MakeNudgeBtn(nudgeRow, b3, math.pi, 0, -1)                 -- Down
    secLayout:AddChild(nudgeRow)

    ---------------------------------------------------------------------------
    -- Section: Appearance
    ---------------------------------------------------------------------------
    local secAppearance = CreateSection(f, "Appearance", false)
    f.secAppearance = secAppearance

    f.showButtons = CreateSettingCheckbox(f, "Always Show Buttons")
    f.showButtons.onChange = function(val)
        if attachedBar then
            attachedBar.barData.alwaysShowButtons = val
            addon.db.profile.bars[attachedBar.barData.id].alwaysShowButtons = val
            addon.Bar:UpdateButtonVisibility(attachedBar)
        end
    end
    secAppearance:AddChild(f.showButtons)

    f.showSlotArt = CreateSettingCheckbox(f, "Show Slot Art")
    f.showSlotArt.onChange = function(val)
        if attachedBar then
            attachedBar.barData.showSlotArt = val
            addon.db.profile.bars[attachedBar.barData.id].showSlotArt = val
            addon.Bar:UpdateSlotArt(attachedBar)
        end
    end
    secAppearance:AddChild(f.showSlotArt)

    f.alphaSlider = CreateSettingSlider(f, "Bar Opacity", 0, 100, 5, function(v)
        return math.floor(v + 0.5) .. "%"
    end)
    f.alphaSlider.onChange = function(val)
        if attachedBar then
            addon.Bar:SetBarAlpha(attachedBar, val / 100)
        end
    end
    secAppearance:AddChild(f.alphaSlider)

    f.mouseoverFade = CreateSettingCheckbox(f, "Mouseover Fade")
    f.mouseoverFade.onChange = function(val)
        if attachedBar then
            attachedBar.barData.mouseoverFade = val
            addon.db.profile.bars[attachedBar.barData.id].mouseoverFade = val
            addon.Bar:ApplyMouseoverFade(attachedBar)
        end
    end
    secAppearance:AddChild(f.mouseoverFade)

    f.visibilityDropdown = CreateSettingDropdown(f, "Bar Visible", {
        { label = "Always Visible", value = "" },
        { label = "In Combat", value = "[combat] show; hide" },
        { label = "Out of Combat", value = "[nocombat] show; hide" },
        { label = "With Target", value = "[exists] show; hide" },
        { label = "On Mouseover", value = "[mod:shift] show; hide" },
    })
    f.visibilityDropdown.onChange = function(val)
        if attachedBar then
            addon.Bar:SetVisibilityMacro(attachedBar, val)
        end
    end
    secAppearance:AddChild(f.visibilityDropdown)

    ---------------------------------------------------------------------------
    -- Section: Behavior
    ---------------------------------------------------------------------------
    local secBehavior = CreateSection(f, "Behavior", false)
    f.secBehavior = secBehavior

    f.selfCast = CreateSettingCheckbox(f, "Right-Click Self-Cast")
    f.selfCast.onChange = function(val)
        if attachedBar then
            attachedBar.barData.rightClickSelfCast = val
            addon.db.profile.bars[attachedBar.barData.id].rightClickSelfCast = val
            addon.Button:ApplySelfCast(attachedBar)
        end
    end
    secBehavior:AddChild(f.selfCast)

    local keybindBtn = CreateExtraButton(f, "Quick Keybind Mode")
    keybindBtn:SetScript("OnClick", function() addon.Keybinds:EnterMode() end)
    f.keybindBtn = keybindBtn
    secBehavior:AddChild(keybindBtn)

    local macrotextBtn = CreateExtraButton(f, "Edit Button Macrotext")
    macrotextBtn:SetScript("OnClick", function()
        if attachedBar then EditSettings:OpenMacrotextEditor(attachedBar) end
    end)
    f.macrotextBtn = macrotextBtn
    secBehavior:AddChild(macrotextBtn)

    ---------------------------------------------------------------------------
    -- Section: Actions
    ---------------------------------------------------------------------------
    local secActions = CreateSection(f, "Actions", false)
    f.secActions = secActions

    f.revertBtn = CreateExtraButton(f, "Revert Changes")
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
            EditSettings:PopulateValues(attachedBar)
        end
    end)
    secActions:AddChild(f.revertBtn)

    f.resetPosBtn = CreateExtraButton(f, "Reset Position")
    f.resetPosBtn:SetScript("OnClick", function()
        if attachedBar then
            local bd = attachedBar.barData
            bd.pos = nil
            addon.db.profile.bars[bd.id].pos = nil
            addon.Bar:RestorePosition(attachedBar, bd)
        end
    end)
    secActions:AddChild(f.resetPosBtn)

    f.settingsBtn = CreateExtraButton(f, "BazBars Settings")
    f.settingsBtn:SetScript("OnClick", function() addon.Options:Open() end)
    secActions:AddChild(f.settingsBtn)

    f.exportBtn = CreateExtraButton(f, "Export Bar Config")
    f.exportBtn:SetScript("OnClick", function()
        if attachedBar then
            local str = addon:ExportBar(attachedBar.barData.id)
            if str then EditSettings:ShowExportString(str) end
        end
    end)
    secActions:AddChild(f.exportBtn)

    f.duplicateBtn = CreateExtraButton(f, "Duplicate This Bar")
    f.duplicateBtn:SetScript("OnClick", function()
        if attachedBar then
            local sourceID = attachedBar.barData.id
            local newID = addon:DuplicateBar(sourceID)
            if newID then
                addon:Print(("Duplicated Bar %d as Bar %d."):format(sourceID, newID))
            end
        end
    end)
    secActions:AddChild(f.duplicateBtn)

    f.deleteBtn = CreateExtraButton(f, "|cffff4444Delete This Bar|r")
    f.deleteBtn:SetScript("OnClick", function()
        if attachedBar then
            local id = attachedBar.barData.id
            EditSettings:Hide()
            addon:DeleteBar(id)
        end
    end)
    secActions:AddChild(f.deleteBtn)

    ---------------------------------------------------------------------------
    -- Section layout engine
    ---------------------------------------------------------------------------
    f.sections = { secLayout, secAppearance, secBehavior, secActions }

    function f:LayoutSections()
        local y = -(nameRow:GetHeight() + 50) -- below title + name
        for _, sec in ipairs(self.sections) do
            local h = sec:Layout(y)
            y = y - h - 4
        end
        -- Resize frame to fit
        self:SetHeight(math.abs(y) + 20)
    end

    f:LayoutSections()

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
    settingsFrame.selfCast:SetValue(bd.rightClickSelfCast or false)
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
        rightClickSelfCast = bd.rightClickSelfCast,
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

---------------------------------------------------------------------------
-- Macrotext Editor Dialog
---------------------------------------------------------------------------

local macrotextFrame = nil
local macrotextTarget = nil -- the button being edited

local function CreateMacrotextFrame()
    local f = CreateFrame("Frame", "BazBarsMacrotextFrame", UIParent, "DialogBorderTranslucentTemplate")
    f:SetSize(400, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Edit Button Macrotext")
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    local helpText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    helpText:SetPoint("TOP", title, "BOTTOM", 0, -6)
    helpText:SetWidth(360)
    helpText:SetText("Click a button on the bar, then type your macrotext below.\nUse #showtooltip SpellName on the first line to set the icon.")
    helpText:SetTextColor(0.7, 0.7, 0.7)
    f.helpText = helpText

    -- Button label (shows which button is selected)
    local btnLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    btnLabel:SetPoint("TOP", helpText, "BOTTOM", 0, -8)
    btnLabel:SetText("No button selected")
    f.btnLabel = btnLabel

    -- Multiline editbox
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOP", btnLabel, "BOTTOM", 0, -8)
    scrollFrame:SetPoint("LEFT", 15, 0)
    scrollFrame:SetPoint("RIGHT", -30, 0)
    scrollFrame:SetHeight(150)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox

    -- Background for the editbox area
    local bg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", 4, -4)
    bg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bg:SetBackdropColor(0, 0, 0, 0.5)
    bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    bg:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)

    -- Save button
    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(120, 28)
    saveBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -5, 15)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        if macrotextTarget then
            local text = editBox:GetText()
            if text == "" then text = nil end
            addon.Button:SetAction(macrotextTarget, macrotextTarget.bbCommand,
                macrotextTarget.bbValue, macrotextTarget.bbSubValue,
                macrotextTarget.bbID, text)
        end
        f:Hide()
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(120, 28)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 5, 15)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        editBox:SetText("")
        if macrotextTarget then
            addon.Button:SetAction(macrotextTarget, macrotextTarget.bbCommand,
                macrotextTarget.bbValue, macrotextTarget.bbSubValue,
                macrotextTarget.bbID, nil)
        end
        f:Hide()
    end)

    f:Hide()
    return f
end

function EditSettings:OpenMacrotextEditor(barFrame)
    if not macrotextFrame then
        macrotextFrame = CreateMacrotextFrame()
    end

    macrotextTarget = nil
    macrotextFrame.btnLabel:SetText("Click a button on the bar to select it")
    macrotextFrame.editBox:SetText("")
    macrotextFrame:Show()

    -- Hook button clicks on this bar to select for editing
    for r, row in pairs(barFrame.buttons) do
        for c, btn in pairs(row) do
            if not btn.bbMacrotextHooked then
                btn:HookScript("OnClick", function(self)
                    if macrotextFrame and macrotextFrame:IsShown() then
                        macrotextTarget = self
                        local label = string.format("Button [%d, %d]", self.bbRow, self.bbCol)
                        if self.bbCommand then
                            label = label .. " - " .. (self.bbValue or self.bbCommand)
                        end
                        macrotextFrame.btnLabel:SetText(label)
                        macrotextFrame.editBox:SetText(self.bbMacrotext or "")
                        macrotextFrame.editBox:SetFocus()
                    end
                end)
                btn.bbMacrotextHooked = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- Export / Import Dialogs
---------------------------------------------------------------------------

local exportFrame = nil

function EditSettings:ShowExportString(str)
    if not exportFrame then
        local f = CreateFrame("Frame", "BazBarsExportFrame", UIParent, "DialogBorderTranslucentTemplate")
        f:SetSize(450, 180)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Export Bar Config")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
        close:SetScript("OnClick", function() f:Hide() end)

        local helpText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        helpText:SetPoint("TOP", title, "BOTTOM", 0, -6)
        helpText:SetText("Copy the string below (Ctrl+A, Ctrl+C):")
        helpText:SetTextColor(0.7, 0.7, 0.7)

        local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        editBox:SetSize(400, 20)
        editBox:SetPoint("TOP", helpText, "BOTTOM", 0, -10)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        f.editBox = editBox

        exportFrame = f
    end

    exportFrame.editBox:SetText(str)
    exportFrame:Show()
    exportFrame.editBox:HighlightText()
    exportFrame.editBox:SetFocus()
end

local importFrame = nil

function EditSettings:ShowImportDialog()
    if not importFrame then
        local f = CreateFrame("Frame", "BazBarsImportFrame", UIParent, "DialogBorderTranslucentTemplate")
        f:SetSize(450, 180)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Import Bar Config")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
        close:SetScript("OnClick", function() f:Hide() end)

        local helpText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        helpText:SetPoint("TOP", title, "BOTTOM", 0, -6)
        helpText:SetText("Paste a BazBars export string below:")
        helpText:SetTextColor(0.7, 0.7, 0.7)

        local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        editBox:SetSize(400, 20)
        editBox:SetPoint("TOP", helpText, "BOTTOM", 0, -10)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        f.editBox = editBox

        local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        importBtn:SetSize(120, 28)
        importBtn:SetPoint("TOP", editBox, "BOTTOM", 0, -10)
        importBtn:SetText("Import")
        importBtn:SetScript("OnClick", function()
            local str = editBox:GetText()
            if str and str ~= "" then
                addon:ImportBar(str)
            end
            f:Hide()
        end)

        importFrame = f
    end

    importFrame.editBox:SetText("")
    importFrame:Show()
    importFrame.editBox:SetFocus()
end
