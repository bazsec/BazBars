-- BazBars BattlePet Action Handler
-- Battle pets from the pet journal. Cursor type is "battlepet" and the
-- identifier is the pet's GUID (a string). Secure casting uses a
-- "/summonpet <PetName>" macro.

local Actions = BazBars.Actions

---------------------------------------------------------------------------
-- Local helpers
---------------------------------------------------------------------------

local function GetPetName(petGUID)
    if not petGUID then return nil end
    local speciesID, customName = C_PetJournal.GetPetInfoByPetID(petGUID)
    -- Prefer custom name, fall back to species name
    if customName and type(customName) == "string" and customName ~= "" then
        return customName
    end
    if speciesID then
        local speciesName = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        if speciesName and type(speciesName) == "string" then
            return speciesName
        end
    end
    return nil
end

local function GetPetIcon(petGUID)
    if not petGUID then return nil end
    return select(9, C_PetJournal.GetPetInfoByPetID(petGUID))
end

---------------------------------------------------------------------------
-- Handler
---------------------------------------------------------------------------

local BattlePet = {
    type = "battlepet",
    priority = 60,
}

---------------------------------------------------------------------------
-- Cursor
---------------------------------------------------------------------------

function BattlePet.fromCursor()
    local cType, petGUID = GetCursorInfo()
    if cType == "battlepet" and petGUID then
        return { id = petGUID }
    end
end

function BattlePet.pickup(data)
    if not data or not data.id then return end
    C_PetJournal.PickupPet(data.id)
end

---------------------------------------------------------------------------
-- Button attributes
---------------------------------------------------------------------------

function BattlePet.apply(button, data)
    local name = GetPetName(data.id)
    if name then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/summonpet " .. name)
    end
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

function BattlePet.getIcon(data)
    return GetPetIcon(data.id)
end

function BattlePet.getName(data)
    return GetPetName(data.id)
end

function BattlePet.showTooltip(data)
    local link = C_PetJournal.GetBattlePetLink(data.id)
    if link then
        GameTooltip:SetHyperlink(link)
    else
        local name = GetPetName(data.id)
        if name then GameTooltip:SetText(name, 1, 1, 1) end
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function BattlePet.serialize(data)
    return { id = data.id }
end

function BattlePet.deserialize(saved)
    if not saved or not saved.id then return nil end
    -- Don't reject — the pet might be on another character; just show the
    -- button and let the cast fail at runtime if it's truly gone.
    return { id = saved.id }
end

---------------------------------------------------------------------------
-- Legacy migration
-- Old format: { command = "battlepet", value = petGUID }
---------------------------------------------------------------------------

function BattlePet.migrate(legacy)
    if legacy.command ~= "battlepet" then return nil end
    if not legacy.value then return nil end
    return { id = legacy.value }
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

Actions:Register(BattlePet)
