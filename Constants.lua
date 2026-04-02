-- BazBars Constants and Defaults

BazBars = BazBars or {}

-- Create the AceAddon early so all modules can GetAddon() it
local addon = LibStub("AceAddon-3.0"):NewAddon("BazBars", "AceConsole-3.0", "AceEvent-3.0")

BazBars.ADDON_NAME = "BazBars"
BazBars.VERSION = "008"

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
    battlepet = true,
    equipmentset = true,
}

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
        pos = nil, -- will store { point, relPoint, x, y }
        customName = nil,
        mouseoverFade = false,
        mouseoverAlpha = 0.3,
        rightClickSelfCast = false,
    }
end

-- Attach to addon object now that the table exists
addon.ACCEPTED_TYPES = BazBars.ACCEPTED_TYPES
