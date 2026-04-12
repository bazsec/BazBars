-- BazBars Bar Module
-- Handles bar creation, layout, Edit Mode dragging, and visual presentation

local addon = BazCore:GetAddon("BazBars")
local Bar = {}
local Masque = LibStub and LibStub("Masque", true) -- optional dependency
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
    frame:SetScale(BazBars.GetBarSetting(barData, "scale") or BazBars.DEFAULT_SCALE)

    -- Create buttons grid
    Bar:CreateButtons(frame, barData)

    -- Layout buttons
    Bar:LayoutButtons(frame, barData)

    -- Position: restore saved or default
    Bar:RestorePosition(frame, barData)

    -- Register with BazCore Edit Mode framework
    Bar:RegisterEditMode(frame, barData)

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
    -- Match Blizzard's ActionButton click registration exactly (see
    -- Blizzard_ActionBar/Shared/ActionButton.lua:458). Registering for
    -- AnyUp + the two main-button down events means the secure
    -- dispatcher fires correctly in both modes of the global
    -- `ActionButtonUseKeyDown` CVar:
    --   CVar=0 → dispatch on key-up, drag-drop works on plain click-drag
    --            (the mouseup is consumed by the active drag so the
    --            secure cast is never triggered)
    --   CVar=1 → dispatch on LeftButton/RightButton down, matching
    --            Blizzard's default bars. Plain click-drag would fire
    --            the spell before the drag started, so Shift+drag is
    --            required to pick up buttons — shift-type1/shift-type2
    --            are set to "noop" in Registry.lua so shift-click /
    --            shift-drag never dispatches anything.
    btn:RegisterForClicks("AnyUp", "LeftButtonDown", "RightButtonDown")

    -- Prevent the secure action from firing when the cursor has contents.
    -- Without this, clicking a button with something on the cursor would
    -- both cast/use the button's action AND trigger OnReceiveDrag. We stash
    -- the type attribute in PreClick and restore it in PostClick.
    -- Custom SecureActionButtons don't auto-fire OnReceiveDrag on click
    -- when the cursor has contents, the way Blizzard's action buttons do.
    -- We intercept the click: PreClick clears the type attribute to prevent
    -- the secure cast, and PostClick manually triggers the drop handling.
    btn:HookScript("PreClick", function(self)
        if InCombatLockdown() then return end
        if GetCursorInfo() then
            self._bazStashedType = self:GetAttribute("type") or false
            self:SetAttribute("type", nil)
        end
    end)
    btn:HookScript("PostClick", function(self)
        if InCombatLockdown() then return end
        if self._bazStashedType == nil then return end

        self._bazStashedType = nil

        -- If cursor has contents, this was a drop attempt — handle it
        if GetCursorInfo() then
            addon.Button:ReceiveDrag(self)
        end
        -- ReceiveDrag (if it ran) will have reset the button's type attribute
        -- via SetActionFromHandler, so we don't need to restore the stash.
    end)

    btn.bbBarID = barData.id
    btn.bbBarData = barData
    btn.bbRow = r
    btn.bbCol = c
    btn.action = nil
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
        if not self.action then return end

        -- Route events to generic update functions; they check the action
        -- handler internally.
        if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
            addon.Button:UpdateCooldown(self)
        elseif event == "BAG_UPDATE" then
            addon.Button:UpdateCount(self)
            addon.Button:UpdateUsable(self)
        elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
            or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
            addon.Button:UpdateGlow(self)
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            addon.Button:UpdateEquipped(self)
        elseif event == "SPELL_UPDATE_USABLE" then
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
    local spacing = BazBars.GetBarSetting(barData, "spacing") or BazBars.DEFAULT_SPACING
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
-- Edit Mode Registration (via BazCore EditMode framework)
---------------------------------------------------------------------------

function Bar:RegisterEditMode(frame, barData)
    local bd = barData

    BazCore:RegisterEditModeFrame(frame, {
        label = Bar:GetDisplayName(frame),
        addonName = "BazBars",
        positionKey = false, -- BazBars manages its own barData.pos

        settings = {
            -- Layout
            { type = "input", key = "customName", label = "Bar Name", section = "Layout",
              get = function() return bd.customName or "" end,
              set = function(v)
                  Bar:SetCustomName(frame, v)
              end },
            { type = "dropdown", key = "orientation", label = "Orientation", section = "Layout",
              options = { { label = "Horizontal", value = "horizontal" }, { label = "Vertical", value = "vertical" } },
              get = function() return bd.orientation or "horizontal" end,
              set = function(v)
                  bd.orientation = v
                  addon.db.profile.bars[bd.id].orientation = v
                  Bar:LayoutButtons(frame, bd)
              end },
            { type = "slider", key = "rows", label = "# of Rows", section = "Layout",
              min = 1, max = BazBars.MAX_ROWS, step = 1,
              get = function() return bd.rows end,
              set = function(v)
                  Bar:Resize(frame, v, bd.cols, bd.spacing)
              end },
            { type = "slider", key = "cols", label = "# of Icons", section = "Layout",
              min = 1, max = BazBars.MAX_COLS, step = 1,
              get = function() return bd.cols end,
              set = function(v)
                  Bar:Resize(frame, bd.rows, v, bd.spacing)
              end },
            { type = "slider", key = "scale", label = "Icon Size", section = "Layout",
              min = 50, max = 250, step = 5,
              format = function(v) return math.floor(v + 0.5) .. "%" end,
              get = function() return (BazBars.GetBarSetting(bd, "scale") or 1) * 100 end,
              set = function(v)
                  Bar:SetScale(frame, v / 100)
              end },
            { type = "slider", key = "spacing", label = "Icon Padding", section = "Layout",
              min = 0, max = 20, step = 1,
              get = function() return BazBars.GetBarSetting(bd, "spacing") end,
              set = function(v)
                  Bar:Resize(frame, bd.rows, bd.cols, v)
              end },
            { type = "nudge", section = "Layout" },

            -- Appearance
            { type = "checkbox", key = "alwaysShowButtons", label = "Always Show Buttons", section = "Appearance",
              get = function() return BazBars.GetBarSetting(bd, "alwaysShowButtons") ~= false end,
              set = function(v)
                  bd.alwaysShowButtons = v
                  addon.db.profile.bars[bd.id].alwaysShowButtons = v
                  Bar:UpdateButtonVisibility(frame)
              end },
            { type = "checkbox", key = "showSlotArt", label = "Show Slot Art", section = "Appearance",
              get = function() return BazBars.GetBarSetting(bd, "showSlotArt") ~= false end,
              set = function(v)
                  bd.showSlotArt = v
                  addon.db.profile.bars[bd.id].showSlotArt = v
                  Bar:UpdateSlotArt(frame)
              end },
            { type = "slider", key = "alpha", label = "Bar Opacity", section = "Appearance",
              min = 0, max = 100, step = 5,
              format = function(v) return math.floor(v + 0.5) .. "%" end,
              get = function() return (BazBars.GetBarSetting(bd, "alpha") or 1.0) * 100 end,
              set = function(v)
                  Bar:SetBarAlpha(frame, v / 100)
              end },
            { type = "checkbox", key = "mouseoverFade", label = "Mouseover Fade", section = "Appearance",
              get = function() return BazBars.GetBarSetting(bd, "mouseoverFade") or false end,
              set = function(v)
                  bd.mouseoverFade = v
                  addon.db.profile.bars[bd.id].mouseoverFade = v
                  Bar:ApplyMouseoverFade(frame)
              end },
            { type = "dropdown", key = "visibilityMacro", label = "Bar Visible", section = "Appearance",
              options = {
                  { label = "Always Visible", value = "" },
                  { label = "In Combat", value = "[combat] show; hide" },
                  { label = "Out of Combat", value = "[nocombat] show; hide" },
                  { label = "With Target", value = "[exists] show; hide" },
                  { label = "On Mouseover", value = "[mod:shift] show; hide" },
              },
              get = function() return bd.visibilityMacro or "" end,
              set = function(v)
                  Bar:SetVisibilityMacro(frame, v)
              end },

            -- Behavior
            { type = "checkbox", key = "locked", label = "Lock Buttons", section = "Behavior",
              get = function() return bd.locked or false end,
              set = function(v)
                  bd.locked = v
                  addon.db.profile.bars[bd.id].locked = v
              end },
            { type = "checkbox", key = "rightClickSelfCast", label = "Right-Click Self-Cast", section = "Behavior",
              get = function() return bd.rightClickSelfCast or false end,
              set = function(v)
                  bd.rightClickSelfCast = v
                  addon.db.profile.bars[bd.id].rightClickSelfCast = v
                  addon.Button:ApplySelfCast(frame)
              end },
        },

        actions = {
            { label = "Revert Changes", builtin = "revert" },
            { label = "Reset Position", builtin = "resetPosition" },
            { label = "Quick Keybind Mode", onClick = function() addon.Keybinds:EnterMode() end },
            { label = "Edit Button Macrotext", onClick = function()
                if addon.Dialogs then addon.Dialogs:OpenMacrotextEditor(frame) end
            end },
            { label = "BazBars Settings", onClick = function() addon.Options:Open() end },
            { label = "Export Bar Config", onClick = function()
                local str = addon:ExportBar(bd.id)
                if str and addon.Dialogs then addon.Dialogs:ShowExportString(str) end
            end },
            { label = "Duplicate This Bar", onClick = function()
                local newID = addon:DuplicateBar(bd.id)
                if newID then
                    addon:Print(("Duplicated Bar %d as Bar %d."):format(bd.id, newID))
                end
            end },
            { label = "|cffff4444Delete This Bar|r", onClick = function()
                BazCore:DeselectEditFrame(frame)
                addon:DeleteBar(bd.id)
            end },
        },

        onPositionChanged = function(f) Bar:SavePosition(f) end,
    })
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
-- Edit Mode (delegated to BazCore)
---------------------------------------------------------------------------

function Bar:DeselectAll()
    local sel = BazCore:GetSelectedEditFrame()
    if sel then
        BazCore:DeselectEditFrame(sel)
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
    scale = BazCore:SetScaleFromCenter(frame, scale, BazBars.MIN_SCALE, BazBars.MAX_SCALE)
    frame.barData.scale = scale
    Bar:SavePosition(frame)

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

    if BazBars.GetBarSetting(barData, "mouseoverFade") then
        local fadeAlpha = BazBars.GetBarSetting(barData, "mouseoverAlpha") or 0.3
        local fullAlpha = BazBars.GetBarSetting(barData, "alpha") or 1.0

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
        frame:SetAlpha(BazBars.GetBarSetting(barData, "alpha") or 1.0)
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
    BazCore:UpdateEditModeLabel(frame, Bar:GetDisplayName(frame))
end

---------------------------------------------------------------------------
-- Destroy
---------------------------------------------------------------------------

function Bar:Destroy(id)
    local frame = bars[id]
    if not frame then return false end

    -- Unregister from Edit Mode
    BazCore:UnregisterEditModeFrame(frame)

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
    local showEmpty = BazBars.GetBarSetting(frame.barData, "alwaysShowButtons") ~= false
    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            if r <= frame.barData.rows and c <= frame.barData.cols then
                if btn.action or showEmpty then
                    btn:Show()
                else
                    btn:Hide()
                end
            end
        end
    end
end

function Bar:UpdateSlotArt(frame)
    local show = BazBars.GetBarSetting(frame.barData, "showSlotArt") ~= false
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
            -- Apply settings
            Bar:ApplyVisibility(frame)
            Bar:UpdateSlotArt(frame)
            Bar:UpdateButtonVisibility(frame)
            Bar:SetBarAlpha(frame, BazBars.GetBarSetting(barData, "alpha") or 1.0)
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
