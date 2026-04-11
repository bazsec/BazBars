-- BazBars Item Action Handler
-- Handles bag items. Toys are a separate handler (Actions/Toy.lua) with
-- higher priority so it intercepts items that are actually toys before this
-- handler sees them.

local Actions = BazBars.Actions

---------------------------------------------------------------------------
-- Local helpers
---------------------------------------------------------------------------

local function GetItemName(itemID)
    local info = C_Item.GetItemInfo(itemID)
    return info and info.itemName or nil
end

-- SecureActionButton accepts the item by name OR "item:<id>". Prefer name
-- when available (works immediately) and fall back to the item: syntax for
-- items whose info isn't cached yet.
local function GetItemAttribute(itemID)
    return GetItemName(itemID) or ("item:" .. itemID)
end

---------------------------------------------------------------------------
-- Handler
---------------------------------------------------------------------------

local Item = {
    type = "item",
    priority = 80, -- runs after Toy (which has lower priority number)
}

---------------------------------------------------------------------------
-- Cursor
---------------------------------------------------------------------------

function Item.fromCursor()
    local cType, itemID = GetCursorInfo()
    if cType ~= "item" or not itemID then return end
    -- Skip toys — they have cursor type "item" but must be cast by name.
    -- Leave them for the Toy handler (when registered) or the legacy path.
    if PlayerHasToy and PlayerHasToy(itemID) then return end
    return { id = itemID }
end

function Item.pickup(data)
    if data and data.id then
        C_Item.PickupItem(data.id)
    end
end

---------------------------------------------------------------------------
-- Button attributes
---------------------------------------------------------------------------

function Item.apply(button, data)
    button:SetAttribute("type", "item")
    button:SetAttribute("item", GetItemAttribute(data.id))
end

function Item.applySelfCast(button, data)
    button:SetAttribute("type2", "item")
    button:SetAttribute("item2", GetItemAttribute(data.id))
    button:SetAttribute("unit2", "player")
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

function Item.getIcon(data)
    return C_Item.GetItemIconByID(data.id)
end

function Item.getName(data)
    return GetItemName(data.id)
end

function Item.getCount(data)
    local count = C_Item.GetItemCount(data.id, false, true) or 0
    if count <= 1 then return "" end
    if count > 999 then return "*" end
    return tostring(count)
end

function Item.getCooldown(data)
    local start, duration, enable = C_Item.GetItemCooldown(data.id)
    if not start then return end
    return start, duration, enable
end

function Item.isUsable(data)
    local usable = C_Item.IsUsableItem(data.id)
    return usable, false
end

function Item.isInRange(data, unit)
    if not unit or not UnitExists(unit) then return nil end
    return C_Item.IsItemInRange(data.id, unit)
end

function Item.showTooltip(data)
    GameTooltip:SetItemByID(data.id)
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Item.serialize(data)
    return { id = data.id }
end

function Item.deserialize(saved)
    if not saved or not saved.id then return nil end
    -- Items can be unknown when the user hasn't loaded them yet (not in
    -- bags, not encountered). We DON'T reject here — the cache will fill
    -- in eventually and the button will just show ? until it does.
    return { id = saved.id }
end

---------------------------------------------------------------------------
-- Legacy migration
-- Old format: { command = "item", value = itemID }
-- Note: legacy code also stored toys as "item" + id. The Toy handler's
-- migrate runs first (lower priority = checked first in Registry order),
-- so if the legacy row was actually a toy it gets claimed there.
---------------------------------------------------------------------------

function Item.migrate(legacy)
    if legacy.command ~= "item" then return nil end
    local id = tonumber(legacy.value)
    if not id then return nil end
    return { id = id }
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

Actions:Register(Item)
