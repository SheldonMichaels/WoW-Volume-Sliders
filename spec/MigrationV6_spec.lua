-------------------------------------------------------------------------------
-- spec/MigrationV6_spec.lua
-- Isolated unit test for the Schema V6 migration path.
-------------------------------------------------------------------------------

describe("Schema V5 to V6 Migration", function()
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
            DEFAULT_FOOTER_ORDER = {
                "showZoneTriggers",
                "showFishingSplash",
                "showLfgPop",
                "showCharacter",
                "showBackground",
                "showEmoteSounds",
                "showOutput",
                "showVoiceMode",
            },
            DEFAULT_DB = {
                schemaVersion = 7,
                automation = {
                    enableDeviceVolumes = true,
                    activeManualPresets = {}
                },
                minimap = { minimalistMinimap = true },
                layout = { sliderOrder = {}, footerOrder = {} }
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

        -- Mock a V5 Database
        _G.VolumeSlidersMMDB = {
            schemaVersion = 5,
            automation = {
                activeManualPresets = {}
            },
            minimap = {}
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

    it("should initialize enableDeviceVolumes and stamp version 6", function()
        local db = _G.VolumeSlidersMMDB

        -- Logic is executed during PLAYER_LOGIN
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(7, db.schemaVersion)
        assert.is_true(db.automation.enableDeviceVolumes)
    end)

    it("should not overwrite enableDeviceVolumes if already present", function()
        local db = _G.VolumeSlidersMMDB
        -- Pre-seed with false (user manually set it before login somehow, or testing idempotency)
        db.automation.enableDeviceVolumes = false
        
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(7, db.schemaVersion)
        assert.is_false(db.automation.enableDeviceVolumes)
    end)
end)
