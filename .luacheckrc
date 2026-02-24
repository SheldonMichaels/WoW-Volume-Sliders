-- .luacheckrc for World of Warcraft addons

std = "lua51"

-- Ignore stylistic warnings that are common/unavoidable in WoW
ignore = {
    "211", -- Unused Local Variables (e.g. `local _addonName = ...`)
    "212", -- Unused argument (common in event handlers where we need argument N but not 1..N-1)
    "122", -- Setting a read-only global variable (sometimes needed for hooking/overriding)
    "611", -- Line contains only whitespace
    "631", -- Line is too long
    "431", -- Shadowing an upvalue
    "432"  -- Shadowing an upvalue argument
}

-- Exclude external libraries embedded in the addon
exclude_files = {
    "VolumeSliders/Libs/**/*.lua"
}

-- Add common WoW globals that Volume Sliders uses.
-- We can expand this list as needed.
read_globals = {
    -- Core API
    "CreateFrame",
    "UIParent",
    "hooksecurefunc",
    "GetCursorPosition",
    "PlaySound",
    "SOUNDKIT",
    "GameTooltip",
    "ScriptErrorsFrame",
    
    -- Sound API
    "C_Sound",
    "Sound_GameSystem_GetOutputDevices",
    "Sound_GameSystem_RestartSoundSystem",

    -- Settings / Options
    "Settings",
    "SettingsPanel",

    -- Slash Commands
    "SLASH_VOLSLIDERS1",
    "SlashCmdList",

    -- Locals specific to UI templates/libs loaded
    "LibStub",
    "VolumeSlidersDB",
    
    -- Other base WoW globals
    "print",
    "pairs",
    "ipairs",
    "tonumber",
    "tostring",
    "type",
    "unpack",
    "math",
    "string",
    "table",
    "bit",
    "wipe",
    "GetBuildInfo",
    "GetCVar",
    "SetCVar",
    "IsControlKeyDown",
    "C_Texture",
    "C_Timer",
    "NORMAL_FONT_COLOR",
    "HIGHLIGHT_FONT_COLOR",
    "VERY_LIGHT_GRAY_COLOR",
    "UISpecialFrames",
    "tinsert",
    "Sound_GameSystem_GetOutputDriverNameByIndex",
    "Sound_GameSystem_GetNumOutputDrivers",
    "Sound_GameSystem_GetRestartSoundSystem",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    
    -- Modern ScrollBox / DataProvider API
    "Mixin",
    "BackdropTemplate",
    "CreateDataProvider",
    "CreateScrollBoxListLinearView",
    "ScrollUtil",
    "DragIntersectionArea",
    "FrameUtil",
    "InputUtil"
}

-- Globals that the addon creates and assigns values to
globals = {
    "VolumeSlidersMMDB", -- Our saved variables
    "VolumeSliders_OnAddonCompartmentClick",
    "VolumeSlidersOutputDropdown"
}
