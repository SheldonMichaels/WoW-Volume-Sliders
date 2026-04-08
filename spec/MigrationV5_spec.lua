-------------------------------------------------------------------------------
-- spec/MigrationV5_spec.lua
-- Isolated unit test for the v3.2.0 (Schema V5) migration path.
-------------------------------------------------------------------------------

describe("Schema V4 to V5 Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        _G.GetTime = function() return 1000 end
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
                schemaVersion = 5,
                automation = { activeManualPresets = {} },
                minimap = { minimalistMinimap = true },
                layout = { sliderOrder = {}, footerOrder = {} }
            },
            session = {
                baselineVolumes = {},
                baselineMutes = {},
                activeRegistry = { manual = {} },
                manualActivationTimes = {}
            },
            LDBIcon = { Register = function() end },
            InitializeSettings = function() end,
            UpdateMiniMapButtonVisibility = function() end
        }

        -- Mock a V4 Database with legacy snapshot data
        _G.VolumeSlidersMMDB = {
            schemaVersion = 4,
            automation = {
                manualToggleState = {
                    ["1"] = { name = "Old Snapshot", volumes = { ["Sound_MasterVolume"] = 0.5 } }
                }
            },
            minimap = {}
        }

        -- Stub out CreateFrame for Init.lua
        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function()
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

    it("should destroy legacy manualToggleState and initialize activeManualPresets", function()
        local db = _G.VolumeSlidersMMDB
        
        -- Logic is executed during PLAYER_LOGIN
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(5, db.schemaVersion)
        assert.is_nil(db.automation.manualToggleState)
        assert.is_table(db.automation.activeManualPresets)
    end)

    it("should restore session state from activeManualPresets during login", function()
        -- Seed the V4 DB with an active manual preset index
        _G.VolumeSlidersMMDB.automation.activeManualPresets = { ["1"] = 5000 }
        _G.VolumeSlidersMMDB.automation.presets = {
            { name = "Test Preset", priority = 5, volumes = {} }
        }

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        -- Check session recovery
        assert.is_table(VS.session.activeRegistry.manual)
        assert.is_true(VS.session.activeRegistry.manual[1])
        assert.are.equal(5000, VS.session.manualActivationTimes[1])
    end)

    it("should cleanup orphaned manual preset indices (Iron Fist Rule 10)", function()
        -- Seed index 2 which is NOT in the presets array
        _G.VolumeSlidersMMDB.automation.activeManualPresets = { ["2"] = 5000 }
        _G.VolumeSlidersMMDB.automation.presets = {
            { name = "Legal Preset", priority = 5, volumes = {} } -- Index 1 only
        }

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        -- Registry should be empty for index 2
        assert.is_nil(VS.session.activeRegistry.manual[2])
        -- DB should be cleaned up
        assert.is_nil(_G.VolumeSlidersMMDB.automation.activeManualPresets[2])
    end)
end)
