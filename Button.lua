-- BazBars Button Module
-- Handles button creation, drag-and-drop, textures, cooldowns, tooltips, usability, and range

local addon = BazCore:GetAddon("BazBars")
local Button = {}
addon.Button = Button

-- Localized globals for performance
local pairs = pairs
local type = type
local tonumber = tonumber
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor
local GameTooltip = GameTooltip
local GetItemCount = C_Item.GetItemCount
local GetItemCooldown = C_Item.GetItemCooldown
local IsUsableItem = C_Item.IsUsableItem
local IsItemInRange = C_Item.IsItemInRange
local IsEquippedItem = C_Item.IsEquippedItem
local PlayerHasToy = PlayerHasToy

-- Textures
local EMPTY_SLOT = 136511 -- Interface\PaperDoll\UI-Backpack-EmptySlot
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Parse #showtooltip from macrotext to get the spell/item name
local function ParseShowtooltip(macrotext)
    if not macrotext then return nil end
    local line = macrotext:match("^#showtooltip%s*(.-)\n") or macrotext:match("^#showtooltip%s*(.-)$")
    if line and line ~= "" then
        -- Strip any conditionals like [spec:1] and get the spell name
        -- For now, just grab the first non-conditional word(s)
        local name = line:match("%]%s*(.+)") or line
        -- If multiple spells separated by ;, take the first
        name = name:match("^([^;]+)")
        if name then
            return name:match("^%s*(.-)%s*$") -- trim
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Helpers: Get spell/item info via modern APIs
---------------------------------------------------------------------------

local function GetSpellName(spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name
end

local function GetSpellIcon(nameOrID)
    return C_Spell.GetSpellTexture(nameOrID)
end

local function GetItemIcon(itemID)
    return C_Item.GetItemIconByID(itemID)
end

local function GetItemName(itemID)
    local info = C_Item.GetItemInfo(itemID)
    return info and info.itemName
end

---------------------------------------------------------------------------
-- Button Texture
---------------------------------------------------------------------------

function Button:UpdateTexture(btn)
    local icon = btn.icon
    if not btn.bbCommand then
        icon:Hide()
        btn.cooldown:Hide()
        if btn.bbShowEmpty then
            btn:SetNormalTexture(EMPTY_SLOT)
        else
            btn:SetNormalTexture("")
        end
        return
    end

    local texture = Button:GetTexture(btn)
    if texture then
        icon:SetTexture(texture)
        icon:Show()
        btn:SetNormalTexture("")
    else
        icon:SetTexture(QUESTION_MARK)
        icon:Show()
        btn:SetNormalTexture("")
    end
end

function Button:GetTexture(btn)
    local cmd = btn.bbCommand
    local value = btn.bbValue
    local id = btn.bbID

    if cmd == "spell" then
        -- Prefer spellID for texture lookup (more reliable than name)
        local tex
        if id then
            tex = GetSpellIcon(id)
        end
        if not tex then
            tex = GetSpellIcon(value)
        end
        return tex
    elseif cmd == "item" then
        if PlayerHasToy and PlayerHasToy(value) then
            local _, _, icon = C_ToyBox.GetToyInfo(value)
            return icon
        end
        return GetItemIcon(value)
    elseif cmd == "macro" then
        -- Check for #showtooltip in custom macrotext
        if btn.bbMacrotext then
            local showName = ParseShowtooltip(btn.bbMacrotext)
            if showName then
                -- Try as spell first, then item
                local tex = GetSpellIcon(showName)
                if tex then return tex end
                tex = C_Item.GetItemIconByID(showName)
                if tex then return tex end
            end
        end
        -- Fall back to the macro's own icon
        local _, iconID = GetMacroInfo(value)
        return iconID
    elseif cmd == "mount" then
        if value == 268435455 then
            -- Random Favorite Mount icon
            return 413588 -- Interface\Icons\Mount_Random
        end
        local name, spellID, icon = C_MountJournal.GetMountInfoByID(value)
        return icon
    elseif cmd == "battlepet" then
        local icon = select(9, C_PetJournal.GetPetInfoByPetID(value))
        return icon
    elseif cmd == "equipmentset" then
        if id then
            local _, texture = C_EquipmentSet.GetEquipmentSetInfo(id)
            return texture
        end
    end
end

---------------------------------------------------------------------------
-- Cooldown
---------------------------------------------------------------------------

function Button:UpdateCooldown(btn)
    if not btn.bbCommand then
        btn.cooldown:Hide()
        return
    end

    local cmd = btn.bbCommand
    local value = btn.bbValue

    if cmd == "spell" then
        -- Spell cooldowns are handled by each button's own OnEvent handler
        -- (see Bar.lua CreateSingleButton) to avoid secret value taint
        -- Trigger an initial update
        if btn.bbID and C_Spell.GetSpellCooldownDuration then
            local durationObj = C_Spell.GetSpellCooldownDuration(btn.bbID)
            if durationObj then
                btn.cooldown:SetCooldownFromDurationObject(durationObj)
                btn.cooldown:Show()
            else
                btn.cooldown:Clear()
            end
        end
    elseif cmd == "item" then
        local start, duration, enable = GetItemCooldown(value)
        if start and duration and duration > 0 then
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown:Show()
        else
            btn.cooldown:Hide()
        end
    else
        btn.cooldown:Hide()
    end
end

---------------------------------------------------------------------------
-- Usability (desaturation)
---------------------------------------------------------------------------

function Button:UpdateUsable(btn)
    if not btn.bbCommand then return end

    local cmd = btn.bbCommand
    local value = btn.bbValue

    if cmd == "spell" then
        local isUsable, insufficientPower = C_Spell.IsSpellUsable(value)
        if isUsable then
            btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        elseif insufficientPower then
            btn.icon:SetVertexColor(0.5, 0.5, 1.0)
        else
            btn.icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    elseif cmd == "item" then
        local isUsable = IsUsableItem(value)
        if isUsable or (PlayerHasToy and PlayerHasToy(value)) then
            btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        else
            btn.icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    else
        btn.icon:SetVertexColor(1.0, 1.0, 1.0)
    end
end

---------------------------------------------------------------------------
-- Range check
---------------------------------------------------------------------------

function Button:UpdateRange(btn)
    if not btn.bbCommand then return end

    local cmd = btn.bbCommand
    local inRange = nil

    if not UnitExists("target") then
        -- No target — clear range state and reset color
        if btn._lastRange ~= nil then
            btn._lastRange = nil
            Button:UpdateUsable(btn)
        end
        return
    end

    if cmd == "spell" then
        local spellID = btn.bbID
        if spellID then
            inRange = C_Spell.IsSpellInRange(spellID, "target")
        end
    elseif cmd == "item" then
        inRange = IsItemInRange(btn.bbValue, "target")
    end

    -- Only update visuals if state changed
    if inRange == btn._lastRange then return end
    btn._lastRange = inRange

    local full = addon.db.profile.fullRangeColor ~= false

    if inRange == false then
        btn.icon:SetVertexColor(1.0, 0.3, 0.3)
        if btn.HotKey then btn.HotKey:SetVertexColor(1.0, 0.1, 0.1) end
        if full then
            if btn.NormalTexture then btn.NormalTexture:SetVertexColor(1.0, 0.3, 0.3) end
            if btn.Name then btn.Name:SetVertexColor(1.0, 0.3, 0.3) end
        end
    elseif inRange == true then
        btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        if btn.HotKey then btn.HotKey:SetVertexColor(0.6, 0.6, 0.6) end
        if full then
            if btn.NormalTexture then btn.NormalTexture:SetVertexColor(1.0, 1.0, 1.0) end
            if btn.Name then btn.Name:SetVertexColor(1.0, 1.0, 1.0) end
        end
    else
        Button:UpdateUsable(btn)
    end
end

---------------------------------------------------------------------------
-- Count (charges / item stacks)
---------------------------------------------------------------------------

function Button:UpdateCount(btn)
    if not btn.bbCommand then
        btn.Count:SetText("")
        return
    end

    local cmd = btn.bbCommand
    local value = btn.bbValue
    local text = ""

    if cmd == "spell" then
        local chargeInfo = C_Spell.GetSpellCharges(value)
        if chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1 then
            text = chargeInfo.currentCharges
        end
    elseif cmd == "item" then
        if not (PlayerHasToy and PlayerHasToy(value)) then
            local count = GetItemCount(value, false, true) or 0
            text = (count > 999) and "*" or count
        end
    end

    btn.Count:SetText(text)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

function Button:ShowTooltip(btn)
    if not btn.bbCommand then return end
    if addon.db.profile.showTooltips == false then return end

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

    local cmd = btn.bbCommand
    local value = btn.bbValue
    local id = btn.bbID

    if cmd == "spell" then
        GameTooltip:SetSpellByID(id or value)
    elseif cmd == "item" then
        GameTooltip:SetItemByID(value)
    elseif cmd == "macro" then
        -- Show resolved spell tooltip if #showtooltip is set
        local macroName = GetMacroInfo(value) or value
        if btn.bbMacrotext then
            local showName = ParseShowtooltip(btn.bbMacrotext)
            if showName then
                local spellInfo = C_Spell.GetSpellInfo(showName)
                if spellInfo then
                    GameTooltip:SetSpellByID(spellInfo.spellID)
                else
                    GameTooltip:SetText(showName)
                end
            else
                GameTooltip:SetText(macroName)
            end
        else
            GameTooltip:SetText(macroName)
        end
    elseif cmd == "mount" then
        if value == 268435455 then
            GameTooltip:SetText("Summon Random Favorite Mount")
        else
            local name = C_MountJournal.GetMountInfoByID(value)
            GameTooltip:SetText(name or "Mount")
        end
    elseif cmd == "battlepet" then
        local link = C_PetJournal.GetBattlePetLink(value)
        if link then
            GameTooltip:SetHyperlink(link)
        end
    elseif cmd == "equipmentset" then
        GameTooltip:SetText(value)
    end

    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Spell Proc Glow (Activation Overlay)
---------------------------------------------------------------------------

function Button:UpdateGlow(btn)
    if btn.bbCommand == "spell" and btn.bbID then
        if C_Spell.IsSpellOverlayed and C_Spell.IsSpellOverlayed(btn.bbID) then
            BazCore:ShowGlow(btn)
        else
            BazCore:HideGlow(btn)
        end
    elseif btn.bbCommand == "macro" and btn.bbSubValue then
        local spellID = btn.bbID
        if spellID and C_Spell.IsSpellOverlayed and C_Spell.IsSpellOverlayed(spellID) then
            BazCore:ShowGlow(btn)
        else
            BazCore:HideGlow(btn)
        end
    else
        BazCore:HideGlow(btn)
    end
end

---------------------------------------------------------------------------
-- Equipped Item Green Border
---------------------------------------------------------------------------

function Button:UpdateEquipped(btn)
    if btn.bbCommand == "item" and btn.bbValue then
        if IsEquippedItem(btn.bbValue) then
            if not btn.bbEquipBorder then
                btn.bbEquipBorder = btn:CreateTexture(nil, "OVERLAY")
                btn.bbEquipBorder:SetAtlas("UI-HUD-ActionBar-IconFrame-Border")
                btn.bbEquipBorder:SetAllPoints()
            end
            btn.bbEquipBorder:SetVertexColor(0, 1.0, 0, 0.5)
            btn.bbEquipBorder:Show()
        else
            if btn.bbEquipBorder then
                btn.bbEquipBorder:Hide()
            end
        end
    else
        if btn.bbEquipBorder then
            btn.bbEquipBorder:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Macro Name Text
---------------------------------------------------------------------------

function Button:UpdateMacroName(btn)
    if not btn.Name then return end
    if addon.db.profile.showMacroNames == false then
        btn.Name:SetText("")
        btn.Name:Hide()
        return
    end
    if btn.bbCommand == "macro" and btn.bbValue then
        local name = GetMacroInfo(btn.bbValue)
        if name then
            btn.Name:SetText(name)
            btn.Name:Show()
        else
            btn.Name:SetText("")
        end
    else
        btn.Name:SetText("")
    end
end

---------------------------------------------------------------------------
-- Full button update (called on events)
---------------------------------------------------------------------------

function Button:UpdateButton(btn)
    Button:UpdateTexture(btn)
    Button:UpdateCooldown(btn)
    Button:UpdateUsable(btn)
    Button:UpdateCount(btn)
    Button:UpdateGlow(btn)
    Button:UpdateEquipped(btn)
    Button:UpdateMacroName(btn)
end

---------------------------------------------------------------------------
-- Drag and Drop: Receive
---------------------------------------------------------------------------

function Button:ReceiveDrag(btn)
    if InCombatLockdown() then
        ClearCursor()
        return
    end

    local cursorCommand, cursorValue, cursorSubValue, cursorID = GetCursorInfo()
    if not cursorCommand then return end

    -- Normalize spell: GetCursorInfo returns (spell, slotIndex, "spell", spellID)
    -- We want to store the spellID and resolve the name from it
    if cursorCommand == "spell" then
        local spellID = cursorID
        local spellName = GetSpellName(spellID)
        cursorValue = spellName or cursorValue
        cursorID = spellID
    end


    -- Normalize companion → mount (older API compat)
    if cursorCommand == "companion" then
        cursorCommand = "mount"
    end

    if not BazBars.ACCEPTED_TYPES[cursorCommand] then
        ClearCursor()
        return
    end

    ClearCursor()

    -- If button already has something, pick it up
    if btn.bbCommand then
        Button:PickUp(btn)
    end

    -- Set the new action
    Button:SetAction(btn, cursorCommand, cursorValue, cursorSubValue, cursorID)
end

---------------------------------------------------------------------------
-- Drag and Drop: Start drag (pick up from button)
---------------------------------------------------------------------------

function Button:StartDrag(btn)
    if InCombatLockdown() then return end

    -- Require Shift to drag icons off buttons
    if not IsShiftKeyDown() then return end

    if btn.bbCommand then
        if btn.bbCommand == "mount" or btn.bbCommand == "battlepet" then
            -- Can't use WoW cursor for these — use internal move
            local iconTex = btn.icon and btn.icon:GetTexture()
            Button.pendingMove = {
                command = btn.bbCommand,
                value = btn.bbValue,
                subValue = btn.bbSubValue,
                id = btn.bbID,
                macrotext = btn.bbMacrotext,
            }
            Button:ClearAction(btn)
            Button:ShowCursorIcon(iconTex)
        else
            Button:PickUp(btn)
            Button:ClearAction(btn)
        end
    end
end

function Button:PickUp(btn)
    local cmd = btn.bbCommand
    local value = btn.bbValue
    local id = btn.bbID

    ClearCursor()
    if cmd == "spell" then
        C_Spell.PickupSpell(id or value)
    elseif cmd == "item" then
        if PlayerHasToy and PlayerHasToy(value) then
            C_ToyBox.PickupToyBoxItem(value)
        else
            C_Item.PickupItem(value)
        end
    elseif cmd == "macro" then
        PickupMacro(value)
    elseif cmd == "mount" then
        -- Can't reliably pick up mounts onto cursor — just clear the button
        -- User can re-drag from mount journal
    elseif cmd == "battlepet" then
        C_PetJournal.PickupPet(value)
    elseif cmd == "equipmentset" then
        if id then
            C_EquipmentSet.PickupEquipmentSet(id)
        end
    end
end

---------------------------------------------------------------------------
-- Set / Clear button action
---------------------------------------------------------------------------

function Button:SetAction(btn, command, value, subValue, id, macrotext)
    -- Block actions while Shift is held (prevents firing during Shift+Drag removal)
    btn:SetAttribute("shift-type1", "noop")
    btn:SetAttribute("shift-type2", "noop")

    btn.bbCommand = command
    btn.bbValue = value
    btn.bbSubValue = subValue
    btn.bbID = id
    btn.bbMacrotext = macrotext

    -- Set secure attributes for combat
    if command == "spell" then
        btn:SetAttribute("type", "spell")
        local spellName = value
        if id then
            spellName = GetSpellName(id) or value
        end
        btn:SetAttribute("spell", spellName)
        -- Right-click self-cast
        if btn.bbBarData and btn.bbBarData.rightClickSelfCast then
            btn:SetAttribute("type2", "spell")
            btn:SetAttribute("spell2", spellName)
            btn:SetAttribute("unit2", "player")
        end
    elseif command == "item" then
        if PlayerHasToy and PlayerHasToy(tonumber(value) or 0) then
            -- Toys: get name from ToyBox API and use via macrotext
            local _, toyName = C_ToyBox.GetToyInfo(tonumber(value))
            if toyName then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/cast " .. toyName)
            else
                btn:SetAttribute("type", "toy")
                btn:SetAttribute("toy", tonumber(value))
            end
        else
            local itemName = GetItemName(value) or value
            btn:SetAttribute("type", "item")
            btn:SetAttribute("item", itemName)
            -- Right-click self-cast
            if btn.bbBarData and btn.bbBarData.rightClickSelfCast then
                btn:SetAttribute("type2", "item")
                btn:SetAttribute("item2", itemName)
                btn:SetAttribute("unit2", "player")
            end
        end
    elseif command == "macro" then
        if macrotext and macrotext ~= "" then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", macrotext)
            btn:SetAttribute("macro", nil)
        else
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macro", value)
            btn:SetAttribute("macrotext", nil)
        end
    elseif command == "mount" then
        -- Use mount via macro
        if value == 268435455 then
            -- Special "Random Favorite Mount" ID
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/run C_MountJournal.SummonByID(0)")
        else
            local name = C_MountJournal.GetMountInfoByID(value)
            if name then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/cast " .. name)
            end
        end
    elseif command == "battlepet" then
        local speciesID, customName = C_PetJournal.GetPetInfoByPetID(value)
        local petName = customName
        if not petName or type(petName) ~= "string" or petName == "" then
            -- Fall back to species name
            if speciesID then
                petName = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
            end
        end
        if petName and type(petName) == "string" then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/summonpet " .. petName)
        end
    elseif command == "equipmentset" then
        id = Button:GetEquipmentSetID(value)
        btn.bbID = id
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/equipset " .. value)
    end

    Button:UpdateButton(btn)
    Button:SaveButton(btn)
end

function Button:ClearAction(btn)
    btn.bbCommand = nil
    btn.bbValue = nil
    btn.bbSubValue = nil
    btn.bbID = nil
    btn.bbMacrotext = nil

    btn:SetAttribute("type", nil)
    btn:SetAttribute("type2", nil)
    btn:SetAttribute("shift-type1", nil)
    btn:SetAttribute("shift-type2", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("spell2", nil)
    btn:SetAttribute("item", nil)
    btn:SetAttribute("item2", nil)
    btn:SetAttribute("unit2", nil)
    btn:SetAttribute("macro", nil)
    btn:SetAttribute("macrotext", nil)

    Button:UpdateButton(btn)
    Button:SaveButton(btn)
end

---------------------------------------------------------------------------
-- Re-apply self-cast attributes to all buttons on a bar
---------------------------------------------------------------------------

function Button:ApplySelfCast(barFrame)
    local enabled = barFrame.barData.rightClickSelfCast
    for r, row in pairs(barFrame.buttons) do
        for c, btn in pairs(row) do
            if btn.bbCommand then
                if enabled and btn.bbCommand == "spell" then
                    local spellName = btn.bbValue
                    if btn.bbID then spellName = GetSpellName(btn.bbID) or btn.bbValue end
                    btn:SetAttribute("type2", "spell")
                    btn:SetAttribute("spell2", spellName)
                    btn:SetAttribute("unit2", "player")
                elseif enabled and btn.bbCommand == "item" then
                    local itemName = GetItemName(btn.bbValue) or btn.bbValue
                    btn:SetAttribute("type2", "item")
                    btn:SetAttribute("item2", itemName)
                    btn:SetAttribute("unit2", "player")
                else
                    btn:SetAttribute("type2", nil)
                    btn:SetAttribute("spell2", nil)
                    btn:SetAttribute("item2", nil)
                    btn:SetAttribute("unit2", nil)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Equipment set helper
---------------------------------------------------------------------------

function Button:GetEquipmentSetID(name)
    local ids = C_EquipmentSet.GetEquipmentSetIDs()
    for _, id in ipairs(ids) do
        local setName = C_EquipmentSet.GetEquipmentSetInfo(id)
        if setName == name then
            return id
        end
    end
end

---------------------------------------------------------------------------
-- Save / Load button to DB
---------------------------------------------------------------------------

function Button:SaveButton(btn)
    local barID = btn.bbBarID
    local row = btn.bbRow
    local col = btn.bbCol

    local db = addon.db.profile.bars[barID]
    if not db then return end

    db.buttons = db.buttons or {}
    local key = row .. ":" .. col

    if btn.bbCommand then
        db.buttons[key] = {
            command = btn.bbCommand,
            value = btn.bbValue,
            subValue = btn.bbSubValue,
            id = btn.bbID,
            macrotext = btn.bbMacrotext,
        }
    else
        db.buttons[key] = nil
    end
end

function Button:LoadButton(btn)
    local barID = btn.bbBarID
    local row = btn.bbRow
    local col = btn.bbCol

    local db = addon.db.profile.bars[barID]
    if not db or not db.buttons then return end

    local key = row .. ":" .. col
    local data = db.buttons[key]

    if data then
        Button:SetAction(btn, data.command, data.value, data.subValue, data.id, data.macrotext)
    end
end

---------------------------------------------------------------------------
-- Cursor icon for internal moves (mounts/battlepets)
---------------------------------------------------------------------------

local cursorIcon = nil

function Button:ShowCursorIcon(texture)
    if not cursorIcon then
        cursorIcon = CreateFrame("Frame", nil, UIParent)
        cursorIcon:SetSize(32, 32)
        cursorIcon:SetFrameStrata("TOOLTIP")
        cursorIcon:SetFrameLevel(9999)
        cursorIcon.tex = cursorIcon:CreateTexture(nil, "ARTWORK")
        cursorIcon.tex:SetAllPoints()
    end
    cursorIcon.tex:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    cursorIcon:Show()
    cursorIcon:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)
end

function Button:HideCursorIcon()
    if cursorIcon then
        cursorIcon:SetScript("OnUpdate", nil)
        cursorIcon:Hide()
    end
end

---------------------------------------------------------------------------
-- Global handlers (called from XML)
---------------------------------------------------------------------------

function BazBarsButton_OnEnter(self)
    Button:ShowTooltip(self)
end

function BazBarsButton_OnReceiveDrag(self)
    Button:ReceiveDrag(self)
end

function BazBarsButton_OnDragStart(self)
    Button:StartDrag(self)
end

function BazBarsButton_PostClick(self, button)
    -- Handle pending internal move (mounts/battlepets)
    if Button.pendingMove and button == "LeftButton" and not InCombatLockdown() then
        local move = Button.pendingMove
        Button.pendingMove = nil
        Button:HideCursorIcon()
        Button:SetAction(self, move.command, move.value, move.subValue, move.id, move.macrotext)
        return
    end

    -- Shift+Right-click: clear the button
    if button == "RightButton" and IsShiftKeyDown() and not InCombatLockdown() then
        if self.bbCommand then
            Button:ClearAction(self)
        end
        return
    end
    -- Update after click (cooldowns etc.)
    Button:UpdateButton(self)
end
