-- BazBars Bar Module
-- Handles bar creation, layout, Edit Mode dragging, and visual presentation

local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")
local Bar = {}
local Masque = LibStub("Masque", true) -- optional dependency
addon.Bar = Bar

-- Localized globals
local pairs = pairs
local type = type
local math = math
local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide

local bars = {}
Bar.bars = bars

local buttonCount = 0

---------------------------------------------------------------------------
-- Bar Creation
---------------------------------------------------------------------------

function Bar:Create(barData)
    local id = barData.id
    local name = "BazBarsBar" .. id

    -- Main container: invisible frame, buttons float on their own
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame.barID = id
    frame.barData = barData
    frame.buttons = {}

    -- Masque group for this bar
    if Masque then
        frame.masqueGroup = Masque:Group("BazBars", "Bar " .. id)
    end

    -- Scale
    frame:SetScale(barData.scale or BazBars.DEFAULT_SCALE)

    -- Create buttons grid
    Bar:CreateButtons(frame, barData)

    -- Layout buttons
    Bar:LayoutButtons(frame, barData)

    -- Position: restore saved or default
    Bar:RestorePosition(frame, barData)

    -- Edit Mode drag overlay (hidden by default, shown in Edit Mode)
    Bar:CreateDragOverlay(frame)

    -- Check if Edit Mode is currently active
    local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    Bar:SetEditMode(frame, editing)

    bars[id] = frame
    frame:Show()

    return frame
end

---------------------------------------------------------------------------
-- Button Grid
---------------------------------------------------------------------------

function Bar:CreateSingleButton(frame, barData, r, c)
    buttonCount = buttonCount + 1
    local btnName = "BazBarsButton" .. buttonCount
    local btn = CreateFrame("Button", btnName, frame, "BazBarsButtonTemplate")
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyDown", "AnyUp")

    btn.bbBarID = barData.id
    btn.bbBarData = barData
    btn.bbRow = r
    btn.bbCol = c
    btn.bbCommand = nil
    btn.bbValue = nil
    btn.bbSubValue = nil
    btn.bbID = nil
    btn.bbShowEmpty = false

    -- Start clean (template provides SlotBackground, SlotArt, NormalTexture, mask)
    btn.icon:Hide()
    btn.cooldown:Hide()
    btn.Count:SetText("")

    -- Direct event handler (avoids taint from AceEvent callbacks)
    btn:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    btn:RegisterEvent("BAG_UPDATE")
    btn:RegisterEvent("BAG_UPDATE_COOLDOWN")
    btn:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    btn:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    btn:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    btn:RegisterEvent("SPELL_UPDATE_USABLE")

    btn:SetScript("OnEvent", function(self, event, arg1)
        local cmd = self.bbCommand
        if not cmd then return end

        -- Spell cooldown
        if event == "SPELL_UPDATE_COOLDOWN" and cmd == "spell" and self.bbID then
            if C_Spell.GetSpellCooldownDuration then
                local durationObj = C_Spell.GetSpellCooldownDuration(self.bbID)
                if durationObj then
                    self.cooldown:SetCooldownFromDurationObject(durationObj)
                    self.cooldown:Show()
                else
                    self.cooldown:Clear()
                end
            end
        end

        -- Item cooldown
        if event == "BAG_UPDATE_COOLDOWN" and cmd == "item" then
            local start, duration, enable = GetItemCooldown(self.bbValue)
            if start and duration and duration > 0 then
                self.cooldown:SetCooldown(start, duration)
                self.cooldown:Show()
            else
                self.cooldown:Hide()
            end
        end

        -- Item count
        if event == "BAG_UPDATE" and cmd == "item" then
            addon.Button:UpdateCount(self)
            addon.Button:UpdateUsable(self)
        end

        -- Spell proc glow
        if (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") then
            if cmd == "spell" and self.bbID then
                addon.Button:UpdateGlow(self)
            end
        end

        -- Equipped item border
        if event == "PLAYER_EQUIPMENT_CHANGED" and cmd == "item" then
            addon.Button:UpdateEquipped(self)
        end

        -- Usability
        if event == "SPELL_UPDATE_USABLE" and cmd == "spell" then
            addon.Button:UpdateUsable(self)
        end
    end)

    frame.buttons[r] = frame.buttons[r] or {}
    frame.buttons[r][c] = btn

    -- Register with Masque
    if frame.masqueGroup then
        frame.masqueGroup:AddButton(btn, {
            Icon = btn.icon,
            Cooldown = btn.cooldown,
            Normal = btn.NormalTexture,
            Pushed = btn.PushedTexture,
            Highlight = btn.HighlightTexture,
            Count = btn.Count,
            HotKey = btn.HotKey,
            SlotBackground = btn.SlotBackground,
            SlotArt = btn.SlotArt,
        }, "Action")
    end

    return btn
end

function Bar:CreateButtons(frame, barData)
    for r = 1, barData.rows do
        for c = 1, barData.cols do
            Bar:CreateSingleButton(frame, barData, r, c)
        end
    end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

function Bar:LayoutButtons(frame, barData)
    local size = BazBars.DEFAULT_BUTTON_SIZE
    local spacing = barData.spacing or BazBars.DEFAULT_SPACING
    local rows = barData.rows
    local cols = barData.cols
    local padding = 2
    local vertical = (barData.orientation == "vertical")

    -- For vertical: swap how rows/cols map to screen axes
    local gridW, gridH
    if vertical then
        gridW = padding * 2 + rows * size + (rows - 1) * spacing
        gridH = padding * 2 + cols * size + (cols - 1) * spacing
    else
        gridW = padding * 2 + cols * size + (cols - 1) * spacing
        gridH = padding * 2 + rows * size + (rows - 1) * spacing
    end
    frame:SetSize(gridW, gridH)

    local startX = -gridW / 2 + padding
    local startY = gridH / 2 - padding

    for r = 1, rows do
        for c = 1, cols do
            local btn = frame.buttons[r] and frame.buttons[r][c]
            if btn then
                btn:SetSize(size, size)
                btn:ClearAllPoints()
                local xOff, yOff
                if vertical then
                    xOff = startX + (r - 1) * (size + spacing)
                    yOff = startY - (c - 1) * (size + spacing)
                else
                    xOff = startX + (c - 1) * (size + spacing)
                    yOff = startY - (r - 1) * (size + spacing)
                end
                btn:SetPoint("TOPLEFT", frame, "CENTER", xOff, yOff)
                btn:Show()
            end
        end
    end

    -- Hide buttons outside current grid
    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            if r > rows or c > cols then
                btn:Hide()
                btn:ClearAllPoints()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Edit Mode Drag Overlay
---------------------------------------------------------------------------

-- Blizzard Edit Mode nine-slice layout (matches EditModeSystemSelectionLayout)
local EditModeNineSliceLayout = {
    ["TopRightCorner"]  = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    ["TopLeftCorner"]   = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    ["BottomLeftCorner"]  = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    ["BottomRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    ["TopEdge"]    = { atlas = "_%s-NineSlice-EdgeTop" },
    ["BottomEdge"] = { atlas = "_%s-NineSlice-EdgeBottom" },
    ["LeftEdge"]   = { atlas = "!%s-NineSlice-EdgeLeft" },
    ["RightEdge"]  = { atlas = "!%s-NineSlice-EdgeRight" },
    ["Center"]     = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local selectedBar = nil -- only one bar can be selected at a time

-- Snap preview lines
local snapLineH, snapLineV

local function GetSnapLines()
    if not snapLineH then
        snapLineH = UIParent:CreateTexture(nil, "OVERLAY")
        snapLineH:SetColorTexture(0.8, 0, 0, 0.8)
        snapLineH:SetHeight(2)
        snapLineH:Hide()
    end
    if not snapLineV then
        snapLineV = UIParent:CreateTexture(nil, "OVERLAY")
        snapLineV:SetColorTexture(0.8, 0, 0, 0.8)
        snapLineV:SetWidth(2)
        snapLineV:Hide()
    end
    return snapLineH, snapLineV
end

local function ShowSnapPreview(frame)
    if not (EditModeManagerFrame and EditModeManagerFrame.Grid
        and EditModeManagerFrame.Grid:IsShown()
        and EditModeManagerFrame.Grid.gridSpacing) then
        return
    end

    local spacing = EditModeManagerFrame.Grid.gridSpacing
    local cx, cy = frame:GetCenter()
    local scale = frame:GetScale()
    if not (cx and cy and spacing > 0) then return end

    cx = cx * scale
    cy = cy * scale

    -- Grid is drawn from center of UIParent, so snap relative to that origin
    local gridCX, gridCY = EditModeManagerFrame.Grid:GetCenter()

    -- Offset from grid center, snap to nearest grid line, then back to absolute
    local relX = cx - gridCX
    local relY = cy - gridCY
    local snapX = gridCX + math.floor(relX / spacing + 0.5) * spacing
    local snapY = gridCY + math.floor(relY / spacing + 0.5) * spacing

    local hLine, vLine = GetSnapLines()

    -- Horizontal line (shows the Y snap)
    hLine:ClearAllPoints()
    hLine:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, snapY)
    hLine:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, snapY)
    hLine:Show()

    -- Vertical line (shows the X snap)
    vLine:ClearAllPoints()
    vLine:SetPoint("TOP", UIParent, "BOTTOMLEFT", snapX, UIParent:GetHeight())
    vLine:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", snapX, 0)
    vLine:Show()
end

local function HideSnapPreview()
    if snapLineH then snapLineH:Hide() end
    if snapLineV then snapLineV:Hide() end
end

function Bar:CreateDragOverlay(frame)
    local overlay = CreateFrame("Frame", nil, frame, "NineSliceCodeTemplate")
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    overlay.isSelected = false
    overlay.barFrame = frame

    -- Start with highlight (cyan) style, no label
    NineSliceUtil.ApplyLayout(overlay, EditModeNineSliceLayout, "editmode-actionbar-highlight")

    -- Label: hidden by default, shown on hover/select
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    label:SetPoint("CENTER")
    label:SetText("")
    label:Hide()
    overlay.label = label

    -- Mouse interaction
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")

    -- DRAG
    overlay:SetScript("OnDragStart", function(self)
        local parent = self:GetParent()
        parent:SetMovable(true)
        parent:StartMoving()
        parent.isDragging = true

        -- Start OnUpdate for live snap preview
        self:SetScript("OnUpdate", function()
            if parent.isDragging then
                ShowSnapPreview(parent)
            end
        end)
    end)

    overlay:SetScript("OnDragStop", function(self)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()
        parent:SetMovable(false)
        parent.isDragging = false

        -- Stop live preview
        self:SetScript("OnUpdate", nil)
        HideSnapPreview()

        -- Snap to grid if Edit Mode grid is shown
        if EditModeManagerFrame and EditModeManagerFrame.Grid
            and EditModeManagerFrame.Grid:IsShown()
            and EditModeManagerFrame.Grid.gridSpacing then
            local spacing = EditModeManagerFrame.Grid.gridSpacing
            local cx, cy = parent:GetCenter()
            local scale = parent:GetScale()
            if cx and cy and spacing > 0 then
                cx = cx * scale
                cy = cy * scale
                -- Snap relative to grid center (same as preview)
                local gridCX, gridCY = EditModeManagerFrame.Grid:GetCenter()
                local relX = cx - gridCX
                local relY = cy - gridCY
                local snapX = gridCX + math.floor(relX / spacing + 0.5) * spacing
                local snapY = gridCY + math.floor(relY / spacing + 0.5) * spacing
                parent:ClearAllPoints()
                parent:SetPoint("CENTER", UIParent, "BOTTOMLEFT", snapX / scale, snapY / scale)
            end
        end

        Bar:SavePosition(parent)
    end)

    -- HOVER
    overlay:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.label:SetText("Click to Edit")
            self.label:Show()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(Bar:GetDisplayName(frame), 1, 1, 1)
        GameTooltip:Show()
    end)

    overlay:SetScript("OnLeave", function(self)
        if not self.isSelected then
            self.label:Hide()
        end
        GameTooltip_Hide()
    end)

    -- CLICK: toggle selection
    overlay:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if self.isSelected then
                Bar:Deselect(frame)
            else
                Bar:Select(frame)
            end
        end
    end)

    overlay:Hide()
    frame.dragOverlay = overlay
end

---------------------------------------------------------------------------
-- Selection State
---------------------------------------------------------------------------

function Bar:Select(frame)
    -- Deselect any previously selected BazBar
    if selectedBar and selectedBar ~= frame then
        Bar:Deselect(selectedBar)
    end

    -- Deselect any Blizzard Edit Mode selection
    if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        EditModeManagerFrame:ClearSelectedSystem()
    end

    local overlay = frame.dragOverlay
    overlay.isSelected = true
    selectedBar = frame

    -- Switch to selected (yellow) nine-slice
    NineSliceUtil.ApplyLayout(overlay, EditModeNineSliceLayout, "editmode-actionbar-selected")

    -- Show bar name
    overlay.label:SetText(Bar:GetDisplayName(frame))
    overlay.label:Show()

    -- Show settings popup
    local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")
    if addon.EditSettings then
        addon.EditSettings:AttachToBar(frame)
    end
end

function Bar:Deselect(frame)
    if not frame then return end

    local overlay = frame.dragOverlay
    overlay.isSelected = false

    -- Revert to highlight (cyan) nine-slice
    NineSliceUtil.ApplyLayout(overlay, EditModeNineSliceLayout, "editmode-actionbar-highlight")

    -- Hide label
    overlay.label:Hide()

    if selectedBar == frame then
        selectedBar = nil
    end

    -- Hide settings popup
    local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")
    if addon.EditSettings then
        addon.EditSettings:Hide()
    end
end

function Bar:DeselectAll()
    if selectedBar then
        Bar:Deselect(selectedBar)
    end
end

function Bar:GetSelected()
    return selectedBar
end

---------------------------------------------------------------------------
-- Edit Mode Toggle
---------------------------------------------------------------------------

function Bar:SetEditMode(frame, editing)
    if editing then
        frame.dragOverlay:Show()
    else
        frame.dragOverlay:Hide()
    end
end

---------------------------------------------------------------------------
-- Position Save / Restore
---------------------------------------------------------------------------

function Bar:SavePosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint()
    local barData = frame.barData
    barData.pos = { point = point, relPoint = relPoint, x = x, y = y }

    -- Persist to DB
    local db = addon.db.profile.bars[barData.id]
    if db then
        db.pos = barData.pos
    end
end

function Bar:RestorePosition(frame, barData)
    frame:ClearAllPoints()
    if barData.pos then
        frame:SetPoint(
            barData.pos.point or "CENTER",
            UIParent,
            barData.pos.relPoint or "CENTER",
            barData.pos.x or 0,
            barData.pos.y or 0
        )
    else
        -- Default: center of screen, stagger by bar ID
        local offsetY = (barData.id - 1) * -60
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
    end
end

---------------------------------------------------------------------------
-- Edit Mode Integration
---------------------------------------------------------------------------

function Bar:EnterEditMode()
    for id, frame in pairs(bars) do
        Bar:SetEditMode(frame, true)
    end
end

function Bar:ExitEditMode()
    Bar:DeselectAll()
    for id, frame in pairs(bars) do
        Bar:SetEditMode(frame, false)
    end
end

---------------------------------------------------------------------------
-- Resize (change rows/cols)
---------------------------------------------------------------------------

function Bar:Resize(frame, newRows, newCols, newSpacing)
    local barData = frame.barData
    local oldRows = barData.rows
    local oldCols = barData.cols

    barData.rows = newRows or oldRows
    barData.cols = newCols or oldCols
    barData.spacing = newSpacing or barData.spacing

    -- Create new buttons if grid expanded
    for r = 1, barData.rows do
        for c = 1, barData.cols do
            if not (frame.buttons[r] and frame.buttons[r][c]) then
                Bar:CreateSingleButton(frame, barData, r, c)
            end
        end
    end

    -- Re-layout (also hides buttons outside grid)
    Bar:LayoutButtons(frame, barData)

    -- Update DB
    local db = addon.db.profile.bars[barData.id]
    if db then
        db.rows = barData.rows
        db.cols = barData.cols
        db.spacing = barData.spacing
    end
end

---------------------------------------------------------------------------
-- Scale
---------------------------------------------------------------------------

function Bar:SetScale(frame, scale)
    scale = math.max(BazBars.MIN_SCALE, math.min(BazBars.MAX_SCALE, scale))

    -- Get center position before scaling
    local cx, cy = frame:GetCenter()
    local oldScale = frame:GetScale()
    if cx and cy then
        cx = cx * oldScale
        cy = cy * oldScale
    end

    frame:SetScale(scale)
    frame.barData.scale = scale

    -- Re-anchor to keep the center in the same place
    if cx and cy then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        Bar:SavePosition(frame)
    end

    local db = addon.db.profile.bars[frame.barData.id]
    if db then
        db.scale = scale
    end
end

---------------------------------------------------------------------------
-- Bar Alpha
---------------------------------------------------------------------------

function Bar:SetBarAlpha(frame, alpha)
    alpha = math.max(0, math.min(1, alpha))
    frame.barData.alpha = alpha
    frame:SetAlpha(alpha)
    local db = addon.db.profile.bars[frame.barData.id]
    if db then
        db.alpha = alpha
    end
end

---------------------------------------------------------------------------
-- Mouseover Fade
---------------------------------------------------------------------------

function Bar:ApplyMouseoverFade(frame)
    local barData = frame.barData

    if barData.mouseoverFade then
        local fadeAlpha = barData.mouseoverAlpha or 0.3
        local fullAlpha = barData.alpha or 1.0

        -- Start at faded alpha
        frame:SetAlpha(fadeAlpha)

        -- Use a container-level approach: track mouse via OnUpdate
        -- to avoid flickering when moving between child buttons
        if not frame.bbFadeFrame then
            frame.bbFadeFrame = CreateFrame("Frame", nil, frame)
            frame.bbFadeFrame:SetAllPoints()
        end

        frame.bbFadeFrame:SetScript("OnUpdate", function()
            local isOver = frame:IsMouseOver()
            if isOver and not frame.bbFadedIn then
                frame.bbFadedIn = true
                UIFrameFadeIn(frame, 0.2, frame:GetAlpha(), fullAlpha)
            elseif not isOver and frame.bbFadedIn then
                frame.bbFadedIn = false
                UIFrameFadeOut(frame, 0.3, frame:GetAlpha(), fadeAlpha)
            end
        end)
    else
        -- Disable fade: restore full alpha, remove OnUpdate
        if frame.bbFadeFrame then
            frame.bbFadeFrame:SetScript("OnUpdate", nil)
        end
        frame.bbFadedIn = nil
        frame:SetAlpha(barData.alpha or 1.0)
    end
end

---------------------------------------------------------------------------
-- Bar Display Name
---------------------------------------------------------------------------

function Bar:GetDisplayName(frame)
    local barData = frame.barData
    if barData.customName and barData.customName ~= "" then
        return barData.customName
    end
    return "BazBar " .. barData.id
end

function Bar:SetCustomName(frame, name)
    frame.barData.customName = name
    local db = addon.db.profile.bars[frame.barData.id]
    if db then
        db.customName = name
    end
    -- Update overlay label if selected
    if frame.dragOverlay and frame.dragOverlay.isSelected then
        frame.dragOverlay.label:SetText(Bar:GetDisplayName(frame))
    end
end

---------------------------------------------------------------------------
-- Destroy
---------------------------------------------------------------------------

function Bar:Destroy(id)
    local frame = bars[id]
    if not frame then return false end

    -- Hide and clear all buttons
    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            btn:Hide()
            btn:SetParent(nil)
        end
    end

    frame:Hide()
    frame:SetParent(nil)
    bars[id] = nil

    return true
end

function Bar:DestroyAll()
    for id in pairs(bars) do
        Bar:Destroy(id)
    end
    -- Clear the table in place (don't reassign, Bar.bars references it)
    wipe(bars)
end

---------------------------------------------------------------------------
-- Button Visibility & Slot Art
---------------------------------------------------------------------------

function Bar:UpdateButtonVisibility(frame)
    local showEmpty = frame.barData.alwaysShowButtons ~= false
    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            if r <= frame.barData.rows and c <= frame.barData.cols then
                if btn.bbCommand then
                    btn:Show()
                elseif showEmpty then
                    btn:Show()
                else
                    btn:Hide()
                end
            end
        end
    end
end

function Bar:UpdateSlotArt(frame)
    local show = frame.barData.showSlotArt ~= false
    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            -- Only toggle the eagle/slot art texture
            -- Keep SlotBackground (semi-transparent fill) always visible
            if btn.SlotArt then
                btn.SlotArt:SetShown(show)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Nudge (pixel-precise positioning)
---------------------------------------------------------------------------

function Bar:Nudge(frame, dx, dy)
    local scale = frame:GetScale()
    local cx, cy = frame:GetCenter()
    if not (cx and cy) then return end

    cx = cx * scale + dx
    cy = cy * scale + dy

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    Bar:SavePosition(frame)
end

---------------------------------------------------------------------------
-- Visibility State Driver
---------------------------------------------------------------------------

function Bar:SetVisibilityMacro(frame, macro)
    frame.barData.visibilityMacro = macro
    local db = addon.db.profile.bars[frame.barData.id]
    if db then
        db.visibilityMacro = macro
    end
    Bar:ApplyVisibility(frame)
end

function Bar:ApplyVisibility(frame)
    local macro = frame.barData.visibilityMacro
    -- Unregister any existing driver
    UnregisterStateDriver(frame, "visibility")

    if macro and macro ~= "" then
        -- RegisterStateDriver with "visibility" attribute natively understands "show"/"hide"
        RegisterStateDriver(frame, "visibility", macro)
    else
        -- Default: always visible
        frame:Show()
    end
end

---------------------------------------------------------------------------
-- Load all bars from DB
---------------------------------------------------------------------------

function Bar:LoadAll()
    local dbBars = addon.db.profile.bars
    if not dbBars then return end

    for id, barData in pairs(dbBars) do
        if type(barData) == "table" and barData.id then
            local frame = Bar:Create(barData)
            -- Load button assignments
            for r, row in pairs(frame.buttons) do
                for c, btn in pairs(row) do
                    addon.Button:LoadButton(btn)
                end
            end
            -- Default to locked (Edit Mode controls unlocking)
            Bar:SetEditMode(frame, false)
            -- Apply settings
            Bar:ApplyVisibility(frame)
            Bar:UpdateSlotArt(frame)
            Bar:UpdateButtonVisibility(frame)
            Bar:SetBarAlpha(frame, barData.alpha or 1.0)
            Bar:ApplyMouseoverFade(frame)
        end
    end
end

---------------------------------------------------------------------------
-- Get bar by ID
---------------------------------------------------------------------------

function Bar:Get(id)
    return bars[id]
end

function Bar:GetAll()
    return bars
end

function Bar:GetNextID()
    local maxID = 0
    for id in pairs(addon.db.profile.bars) do
        if type(id) == "number" and id > maxID then maxID = id end
    end
    return maxID + 1
end
