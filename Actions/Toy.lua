-- BazBars Toy Action Handler
-- Toys appear as "item" on the cursor, same as bag items. We detect them via
-- C_ToyBox.GetToyInfo and take priority OVER the Item handler so regular
-- items still work.

local Actions = BazBars.Actions

---------------------------------------------------------------------------
-- Local helpers
---------------------------------------------------------------------------

local function GetToyInfo(itemID)
    if not C_ToyBox or not C_ToyBox.GetToyInfo then return end
    return C_ToyBox.GetToyInfo(itemID)  -- returns itemID, toyName, icon, isFavorite, itemQuality
end

local function IsToy(itemID)
    if not itemID then return false end
    local id = GetToyInfo(itemID)
    return id ~= nil
end

---------------------------------------------------------------------------
-- Handler
---------------------------------------------------------------------------

local Toy = {
    type = "toy",
    priority = 40, -- before Item (80) so toys are claimed first
}

---------------------------------------------------------------------------
-- Cursor
---------------------------------------------------------------------------

function Toy.fromCursor()
    local cType, itemID = GetCursorInfo()
    if cType ~= "item" or not itemID then return end
    if not IsToy(itemID) then return end
    return { id = itemID }
end

function Toy.pickup(data)
    if not data or not data.id then return end
    if C_ToyBox and C_ToyBox.PickupToyBoxItem then
        C_ToyBox.PickupToyBoxItem(data.id)
    end
end

---------------------------------------------------------------------------
-- Button attributes
-- Use type="toy" for the cleanest secure cast. Fall back to a /cast macro
-- if the toy name isn't available yet.
---------------------------------------------------------------------------

function Toy.apply(button, data)
    local _, toyName = GetToyInfo(data.id)
    if toyName then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/cast " .. toyName)
    else
        button:SetAttribute("type", "toy")
        button:SetAttribute("toy", data.id)
    end
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

function Toy.getIcon(data)
    local _, _, icon = GetToyInfo(data.id)
    return icon
end

function Toy.getName(data)
    local _, name = GetToyInfo(data.id)
    return name
end

function Toy.getCount(data)
    return "" -- toys don't have stacks/charges
end

function Toy.getCooldown(data)
    local start, duration, enable = C_Item.GetItemCooldown(data.id)
    if not start then return end
    return start, duration, enable
end

function Toy.isUsable(data)
    -- Toys are "usable" if the player has them (owning implies usability).
    -- Cooldowns and combat restrictions are handled separately.
    return PlayerHasToy and PlayerHasToy(data.id) or false, false
end

function Toy.showTooltip(data)
    if GameTooltip.SetToyByItemID then
        GameTooltip:SetToyByItemID(data.id)
    else
        GameTooltip:SetItemByID(data.id)
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Toy.serialize(data)
    return { id = data.id }
end

function Toy.deserialize(saved)
    if not saved or not saved.id then return nil end
    return { id = saved.id }
end

---------------------------------------------------------------------------
-- Legacy migration
-- Old format: toys were stored as { command = "item", value = toyItemID }.
-- We check if the legacy "item" is actually a toy and claim it.
---------------------------------------------------------------------------

function Toy.migrate(legacy)
    if legacy.command ~= "item" then return nil end
    local id = tonumber(legacy.value)
    if not id then return nil end
    if not IsToy(id) then return nil end
    return { id = id }
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

Actions:Register(Toy)
