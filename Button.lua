-- BazBars Button Module
-- Handles button creation, drag-and-drop, textures, cooldowns, tooltips, usability, and range

local addon = LibStub("AceAddon-3.0"):GetAddon("BazBars")
local Button = {}
addon.Button = Button
local LBG = LibStub("LibButtonGlow-1.0", true)

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
local GetItemCount = GetItemCount
local GetItemCooldown = GetItemCooldown
local IsUsableItem = IsUsableItem
local IsItemInRange = IsItemInRange
local IsEquippedItem = IsEquippedItem
local PlayerHasToy = PlayerHasToy

-- Textures
local EMPTY_SLOT = 136511 -- Interface\PaperDoll\UI-Backpack-EmptySlot
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

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
    if C_Item and C_Item.GetItemInfo then
        local info = C_Item.GetItemInfo(itemID)
        return info and info.itemName
    end
    -- Fallback
    local name = GetItemInfo(itemID)
    return name
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
        if C_Macro and C_Macro.GetMacroInfo then
            local info = C_Macro.GetMacroInfo(value)
            return info and info.iconID
        end
        local _, texture = GetMacroInfo(value)
        return texture
    elseif cmd == "mount" then
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
    local value = btn.bbValue
    local inRange = nil

    if cmd == "spell" then
        inRange = C_Spell.IsSpellInRange(value, "target")
    elseif cmd == "item" then
        inRange = IsItemInRange(value, "target")
    end

    -- Color both hotkey text and icon when out of range
    if inRange == false then
        btn.icon:SetVertexColor(1.0, 0.3, 0.3)
        if btn.HotKey then btn.HotKey:SetVertexColor(1.0, 0.1, 0.1) end
    elseif inRange == true then
        btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        if btn.HotKey then btn.HotKey:SetVertexColor(0.6, 0.6, 0.6) end
    else
        -- No range info (no target, no range requirement) — reset to usability color
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

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

    local cmd = btn.bbCommand
    local value = btn.bbValue
    local id = btn.bbID

    if cmd == "spell" then
        GameTooltip:SetSpellByID(id or value)
    elseif cmd == "item" then
        GameTooltip:SetItemByID(value)
    elseif cmd == "macro" then
        GameTooltip:SetText(value)
    elseif cmd == "mount" then
        local name = C_MountJournal.GetMountInfoByID(value)
        GameTooltip:SetText(name or "Mount")
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
    if not LBG then return end
    if btn.bbCommand == "spell" and btn.bbID then
        if C_Spell.IsSpellOverlayed and C_Spell.IsSpellOverlayed(btn.bbID) then
            LBG.ShowOverlayGlow(btn)
        else
            LBG.HideOverlayGlow(btn)
        end
    elseif btn.bbCommand == "macro" and btn.bbSubValue then
        -- For macros, check if the underlying spell has a proc
        local spellID = btn.bbID
        if spellID and C_Spell.IsSpellOverlayed and C_Spell.IsSpellOverlayed(spellID) then
            LBG.ShowOverlayGlow(btn)
        else
            LBG.HideOverlayGlow(btn)
        end
    else
        LBG.HideOverlayGlow(btn)
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
    if btn.bbCommand == "macro" and btn.bbValue then
        local name
        if C_Macro and C_Macro.GetMacroInfo then
            local info = C_Macro.GetMacroInfo(btn.bbValue)
            name = info and info.name
        else
            name = GetMacroInfo(btn.bbValue)
        end
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

    -- print("BazBars cursor:", cursorCommand, cursorValue, cursorSubValue, cursorID)

    -- Normalize spell: GetCursorInfo returns (spell, slotIndex, "spell", spellID)
    -- We want to store the spellID and resolve the name from it
    if cursorCommand == "spell" then
        -- cursorValue = slot index, cursorID = spellID
        local spellID = cursorID
        local spellName = GetSpellName(spellID)
        cursorValue = spellName or cursorValue
        cursorID = spellID
    end

    if not addon.ACCEPTED_TYPES[cursorCommand] then
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
        Button:PickUp(btn)
        Button:ClearAction(btn)
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
            if C_Item and C_Item.PickupItem then
                C_Item.PickupItem(value)
            else
                PickupItem(value)
            end
        end
    elseif cmd == "macro" then
        if C_Macro and C_Macro.PickupMacro then
            C_Macro.PickupMacro(value)
        else
            PickupMacro(value)
        end
    elseif cmd == "mount" then
        C_MountJournal.Pickup(0) -- index, not ideal but fallback
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

function Button:SetAction(btn, command, value, subValue, id)
    btn.bbCommand = command
    btn.bbValue = value
    btn.bbSubValue = subValue
    btn.bbID = id

    -- Set secure attributes for combat
    if command == "spell" then
        btn:SetAttribute("type", "spell")
        -- Use spell name for the attribute (works reliably with SecureActionButton)
        local spellName = value
        if id then
            spellName = GetSpellName(id) or value
        end
        btn:SetAttribute("spell", spellName)
        -- print("BazBars SetAction: type=spell, spell=" .. tostring(spellName) .. ", id=" .. tostring(id))
    elseif command == "item" then
        local itemName = GetItemName(value) or value
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", itemName)
    elseif command == "macro" then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macro", value)
    elseif command == "mount" then
        -- Use mount via macro
        local name = C_MountJournal.GetMountInfoByID(value)
        if name then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/cast " .. name)
        end
    elseif command == "battlepet" then
        local speciesID, customName, level, xp, maxXp, displayID, petName = C_PetJournal.GetPetInfoByPetID(value)
        if petName then
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

    btn:SetAttribute("type", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("item", nil)
    btn:SetAttribute("macro", nil)
    btn:SetAttribute("macrotext", nil)

    Button:UpdateButton(btn)
    Button:SaveButton(btn)
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
        Button:SetAction(btn, data.command, data.value, data.subValue, data.id)
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
