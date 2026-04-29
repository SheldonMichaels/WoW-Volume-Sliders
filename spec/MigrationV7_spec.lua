-------------------------------------------------------------------------------
-- spec/MigrationV7_spec.lua
-- Isolated unit test for the Schema V7 migration path (Emote Sounds).
-------------------------------------------------------------------------------

describe("Schema V6 to V7 Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        _G.C_VoiceChat = {
            GetOutputVolume = function() return 100 end,
            GetMasterVolumeScale = function() return 1 end,
            GetInputVolume = function() return 100 end,
            GetVADSensitivity = function() return 0 end
        }
        _G.GetCVar = function() return "1" end
        _G.SetCVar = function() end
        _G.C_AddOns = { IsAddOnLoaded = function() return false end }

        VS = {
            DEFAULT_CVAR_ORDER = { "Sound_MasterVolume" },
            CHANNEL_MUTE_CVAR = { ["Sound_MasterVolume"] = "Sound_EnableAllSound" },
            DEFAULT_DB = {
                schemaVersion = 7,
                toggles = { showEmoteSounds = false },
                layout = {
                    footerOrder = { "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground", "showCharacter", "showEmoteSounds", "showOutput", "showVoiceMode" }
                }
            },
            DEFAULT_FOOTER_ORDER = { "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground", "showCharacter", "showEmoteSounds", "showOutput", "showVoiceMode" },
            session = {
                baselineVolumes = {},
                baselineMutes = {},
                activeRegistry = { manual = {} },
                manualActivationTimes = {}
            },
            LDBIcon = { Register = function() end, IsRegistered = function() return false end },
            InitializeSettings = function() end,
            UpdateMiniMapButtonVisibility = function() end
        }

        -- Mock a V6 Database
        _G.VolumeSlidersMMDB = {
            schemaVersion = 6,
            toggles = {
                showZoneTriggers = true,
                showFishingSplash = true,
                showLfgPop = true,
                showBackground = true,
                showCharacter = true,
                showOutput = true,
                showVoiceMode = true
                -- showEmoteSounds is MISSING
            },
            layout = {
                footerOrder = {
                    "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground", "showCharacter", "showOutput", "showVoiceMode"
                }
            },
            minimap = {}, -- Added to prevent Init.lua crash at line 401
            automation = {} -- Preventive
        }

        -- Stub out create frame to catch the Init event script
        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function(frameType, name, parent, template)
            return {
                RegisterEvent = function() end,
                UnregisterEvent = function() end,
                SetScript = function(self, evt, handler)
                    if evt == "OnEvent" then initFrameScript = handler end
                end
            }
        end

        local f = assert(loadfile("VolumeSliders/Init.lua"))
        f("VolumeSliders", VS)
        _G.CreateFrame = realCreateFrame
    end)

    it("should initialize showEmoteSounds and inject it into footerOrder", function()
        local db = _G.VolumeSlidersMMDB

        -- Logic is executed during PLAYER_LOGIN
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(7, db.schemaVersion)
        assert.is_false(db.toggles.showEmoteSounds)
        
        -- Check if it was injected at index 6 (before showOutput)
        assert.are.equal("showEmoteSounds", db.layout.footerOrder[6])
        assert.are.equal(8, #db.layout.footerOrder)
    end)
end)

describe("Schema V6 to V7 Migration (empty footerOrder)", function()
    local VS
    local initFrameScript

    before_each(function()
        _G.C_VoiceChat = {
            GetOutputVolume = function() return 100 end,
            GetMasterVolumeScale = function() return 1 end,
            GetInputVolume = function() return 100 end,
            GetVADSensitivity = function() return 0 end
        }
        _G.GetCVar = function() return "1" end
        _G.SetCVar = function() end
        _G.C_AddOns = { IsAddOnLoaded = function() return false end }

        VS = {
            DEFAULT_CVAR_ORDER = { "Sound_MasterVolume" },
            CHANNEL_MUTE_CVAR = { ["Sound_MasterVolume"] = "Sound_EnableAllSound" },
            DEFAULT_DB = {
                schemaVersion = 7,
                toggles = { showEmoteSounds = false },
                layout = {
                    footerOrder = {
                        "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground",
                        "showCharacter", "showEmoteSounds", "showOutput", "showVoiceMode"
                    }
                }
            },
            DEFAULT_FOOTER_ORDER = {
                "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground",
                "showCharacter", "showEmoteSounds", "showOutput", "showVoiceMode"
            },
            session = {
                baselineVolumes = {},
                baselineMutes = {},
                activeRegistry = { manual = {} },
                manualActivationTimes = {}
            },
            LDBIcon = { Register = function() end, IsRegistered = function() return false end },
            InitializeSettings = function() end,
            UpdateMiniMapButtonVisibility = function() end
        }

        _G.VolumeSlidersMMDB = {
            schemaVersion = 6,
            toggles = {
                showZoneTriggers = true,
                showFishingSplash = true,
                showLfgPop = true,
                showBackground = true,
                showCharacter = true,
                showOutput = true,
                showVoiceMode = true
            },
            layout = {
                footerOrder = {}
            },
            minimap = {},
            automation = {}
        }

        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function(frameType, name, parent, template)
            return {
                RegisterEvent = function() end,
                UnregisterEvent = function() end,
                SetScript = function(self, evt, handler)
                    if evt == "OnEvent" then initFrameScript = handler end
                end
            }
        end

        assert(loadfile("VolumeSliders/Init.lua"))("VolumeSliders", VS)
        _G.CreateFrame = realCreateFrame
    end)

    it("replaces empty footerOrder with a full default array (no sparse insert)", function()
        local db = _G.VolumeSlidersMMDB
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(7, db.schemaVersion)
        assert.are.equal(8, #db.layout.footerOrder)
        assert.are.equal("showZoneTriggers", db.layout.footerOrder[1])
        assert.are.equal("showEmoteSounds", db.layout.footerOrder[6])
    end)
end)

describe("Schema V6 to V7 Migration (short footerOrder)", function()
    local VS
    local initFrameScript

    before_each(function()
        _G.C_VoiceChat = {
            GetOutputVolume = function() return 100 end,
            GetMasterVolumeScale = function() return 1 end,
            GetInputVolume = function() return 100 end,
            GetVADSensitivity = function() return 0 end
        }
        _G.GetCVar = function() return "1" end
        _G.SetCVar = function() end
        _G.C_AddOns = { IsAddOnLoaded = function() return false end }

        VS = {
            DEFAULT_CVAR_ORDER = { "Sound_MasterVolume" },
            CHANNEL_MUTE_CVAR = { ["Sound_MasterVolume"] = "Sound_EnableAllSound" },
            DEFAULT_DB = {
                schemaVersion = 7,
                toggles = { showEmoteSounds = false },
                layout = {
                    footerOrder = {
                        "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground",
                        "showCharacter", "showEmoteSounds", "showOutput", "showVoiceMode"
                    }
                }
            },
            DEFAULT_FOOTER_ORDER = {
                "showZoneTriggers", "showFishingSplash", "showLfgPop", "showBackground",
                "showCharacter", "showEmoteSounds", "showOutput", "showVoiceMode"
            },
            session = {
                baselineVolumes = {},
                baselineMutes = {},
                activeRegistry = { manual = {} },
                manualActivationTimes = {}
            },
            LDBIcon = { Register = function() end, IsRegistered = function() return false end },
            InitializeSettings = function() end,
            UpdateMiniMapButtonVisibility = function() end
        }

        _G.VolumeSlidersMMDB = {
            schemaVersion = 6,
            toggles = {
                showZoneTriggers = true,
                showFishingSplash = true,
                showLfgPop = true,
                showBackground = true,
                showCharacter = true,
                showOutput = true,
                showVoiceMode = true
            },
            layout = {
                footerOrder = {
                    "showZoneTriggers",
                    "showFishingSplash",
                    "showLfgPop",
                    "showCharacter"
                }
            },
            minimap = {},
            automation = {}
        }

        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function(frameType, name, parent, template)
            return {
                RegisterEvent = function() end,
                UnregisterEvent = function() end,
                SetScript = function(self, evt, handler)
                    if evt == "OnEvent" then initFrameScript = handler end
                end
            }
        end

        assert(loadfile("VolumeSliders/Init.lua"))("VolumeSliders", VS)
        _G.CreateFrame = realCreateFrame
    end)

    it("appends showEmoteSounds without creating a gap when fewer than 5 entries exist", function()
        local db = _G.VolumeSlidersMMDB
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(7, db.schemaVersion)
        assert.are.equal("showEmoteSounds", db.layout.footerOrder[5])
        local n = 0
        for _ in ipairs(db.layout.footerOrder) do
            n = n + 1
        end
        assert.are.equal(8, n)
    end)
end)
