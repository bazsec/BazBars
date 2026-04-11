-- BazBars Spell Action Handler
-- Handles spells picked up from the spellbook. Covers regular spells, flyout
-- spells, and profession spells — they're all just "spell" to WoW's cursor.

local Actions = BazBars.Actions

---------------------------------------------------------------------------
-- Local helpers
---------------------------------------------------------------------------

-- Midnight secret-taint-safe string copy. C_Spell returns can carry hardware
-- event taint; pcall(string.format, "%s", s) produces a clean copy.
local function SafeString(s)
    if not s then return nil end
    local ok, clean = pcall(string.format, "%s", s)
    return ok and clean or s
end

-- Same pattern for numbers. C_Spell.GetSpellCooldown returns secret values
-- that can't be compared to numeric literals directly; round-trip through
-- string.format("%d", ...) to strip the taint.
local function SafeNumber(n)
    if n == nil then return nil end
    local ok, clean = pcall(string.format, "%d", n)
    if not ok then return nil end
    return tonumber(clean)
end

local function GetSpellName(spellID)
    if not spellID then return nil end
    local info = C_Spell.GetSpellInfo(spellID)
    return info and SafeString(info.name) or nil
end

---------------------------------------------------------------------------
-- Handler
---------------------------------------------------------------------------

local Spell = {
    type = "spell",
    priority = 50,
}

---------------------------------------------------------------------------
-- Cursor
---------------------------------------------------------------------------

function Spell.fromCursor()
    local cType, _, _, spellID = GetCursorInfo()
    if cType == "spell" and spellID then
        return { id = spellID }
    end
end

function Spell.pickup(data)
    if data and data.id then
        C_Spell.PickupSpell(data.id)
    end
end

---------------------------------------------------------------------------
-- Button attributes
---------------------------------------------------------------------------

function Spell.apply(button, data)
    local name = GetSpellName(data.id)
    if not name then return end
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", name)
end

function Spell.applySelfCast(button, data)
    local name = GetSpellName(data.id)
    if not name then return end
    button:SetAttribute("type2", "spell")
    button:SetAttribute("spell2", name)
    button:SetAttribute("unit2", "player")
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

function Spell.getIcon(data)
    return C_Spell.GetSpellTexture(data.id)
end

function Spell.getName(data)
    return GetSpellName(data.id)
end

function Spell.getCount(data)
    local info = C_Spell.GetSpellCharges(data.id)
    if info and info.maxCharges and info.maxCharges > 1 then
        return tostring(info.currentCharges)
    end
    return ""
end

function Spell.getCooldown(data)
    if not C_Spell.GetSpellCooldown then return end
    local info = C_Spell.GetSpellCooldown(data.id)
    if not info then return end
    return SafeNumber(info.startTime), SafeNumber(info.duration), info.isEnabled
end

function Spell.isUsable(data)
    return C_Spell.IsSpellUsable(data.id)
end

function Spell.isInRange(data, unit)
    if not unit or not UnitExists(unit) then return nil end
    return C_Spell.IsSpellInRange(data.id, unit)
end

function Spell.hasProcGlow(data)
    return C_Spell.IsSpellOverlayed and C_Spell.IsSpellOverlayed(data.id) or false
end

function Spell.showTooltip(data)
    GameTooltip:SetSpellByID(data.id)
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Spell.serialize(data)
    return { id = data.id }
end

function Spell.deserialize(saved)
    if not saved or not saved.id then return nil end
    if not C_Spell.GetSpellInfo(saved.id) then
        return nil -- spell no longer exists in this version / character
    end
    return { id = saved.id }
end

---------------------------------------------------------------------------
-- Legacy migration (old bbCommand/bbValue/bbID format)
-- Legacy spell buttons had { command="spell", value=spellName, id=spellID }.
-- We prefer the stored id but fall back to looking it up by name.
---------------------------------------------------------------------------

function Spell.migrate(legacy)
    if legacy.command ~= "spell" then return nil end

    local id = legacy.id
    if id and C_Spell.GetSpellInfo(id) then
        return { id = id }
    end

    -- Fallback: resolve name → id
    if legacy.value then
        local info = C_Spell.GetSpellInfo(legacy.value)
        if info and info.spellID then
            return { id = info.spellID }
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

Actions:Register(Spell)
