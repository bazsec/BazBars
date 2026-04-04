-- BazBars Dialogs
-- Macrotext editor, export/import dialogs (extracted from EditSettings)

local addon = BazCore:GetAddon("BazBars")
local Dialogs = {}
addon.Dialogs = Dialogs

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

    local btnLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    btnLabel:SetPoint("TOP", helpText, "BOTTOM", 0, -8)
    btnLabel:SetText("No button selected")
    f.btnLabel = btnLabel

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

function Dialogs:OpenMacrotextEditor(barFrame)
    if not macrotextFrame then
        macrotextFrame = CreateMacrotextFrame()
    end

    macrotextTarget = nil
    macrotextFrame.btnLabel:SetText("Click a button on the bar to select it")
    macrotextFrame.editBox:SetText("")
    macrotextFrame:Show()

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
-- Export Dialog
---------------------------------------------------------------------------

local exportFrame = nil

function Dialogs:ShowExportString(str)
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

---------------------------------------------------------------------------
-- Import Dialog
---------------------------------------------------------------------------

local importFrame = nil

function Dialogs:ShowImportDialog()
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
