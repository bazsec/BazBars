-- BazBars Constants and Defaults

BazBars = BazBars or {}

BazBars.ADDON_NAME = "BazBars"
BazBars.VERSION = C_AddOns.GetAddOnMetadata("BazBars", "Version") or "?"

-- Button defaults
BazBars.DEFAULT_BUTTON_SIZE = 45
BazBars.DEFAULT_SPACING = 2
BazBars.DEFAULT_SCALE = 1.0
BazBars.DEFAULT_COLS = 6
BazBars.DEFAULT_ROWS = 1
BazBars.MAX_COLS = 24
BazBars.MAX_ROWS = 24
BazBars.MIN_SCALE = 0.5
BazBars.MAX_SCALE = 2.5

-- Visual
BazBars.BAR_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
BazBars.BAR_BG_COLOR = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
BazBars.BAR_BORDER_COLOR = { r = 0.3, g = 0.3, b = 0.3, a = 0.8 }
BazBars.BAR_BG_UNLOCKED = { r = 0.15, g = 0.15, b = 0.3, a = 0.7 }

-- Accepted cursor types for drag-and-drop
BazBars.ACCEPTED_TYPES = {
    spell = true,
    item = true,
    macro = true,
    mount = true,
    companion = true,
    battlepet = true,
    equipmentset = true,
}

---------------------------------------------------------------------------
-- Global Override Helpers
---------------------------------------------------------------------------

-- Read a per-bar setting, respecting global overrides
function BazBars.GetBarSetting(barData, key)
    local bbAddon = BazCore:GetAddon("BazBars")
    if bbAddon and bbAddon.db then
        local overrides = bbAddon.db.profile.globalOverrides
        if overrides then
            local override = overrides[key]
            if override and override.enabled then
                return override.value
            end
        end
    end
    return barData[key]
end

-- Check if a global override is active for a given key
function BazBars.IsGlobalOverrideActive(key)
    local bbAddon = BazCore:GetAddon("BazBars")
    if not bbAddon or not bbAddon.db then return false end
    local overrides = bbAddon.db.profile.globalOverrides
    if not overrides then return false end
    return overrides[key] and overrides[key].enabled or false
end

---------------------------------------------------------------------------
-- Defaults for new bar saved data
---------------------------------------------------------------------------

-- Defaults for new bar saved data
function BazBars.DefaultBarData(id)
    return {
        id = id,
        cols = BazBars.DEFAULT_COLS,
        rows = BazBars.DEFAULT_ROWS,
        spacing = BazBars.DEFAULT_SPACING,
        scale = BazBars.DEFAULT_SCALE,
        alpha = 1.0,
        locked = false,
        buttons = {},
        pos = nil,
        customName = nil,
        mouseoverFade = false,
        mouseoverAlpha = 0.3,
        rightClickSelfCast = false,
    }
end
