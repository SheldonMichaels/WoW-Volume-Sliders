local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Login Restoration Regression", function()
    local VS
    local initFrameScript

    before_each(function()
        -- Reset global state
        _G.VolumeSlidersMMDB = {
            schemaVersion = 5,
            automation = {
                presets = {
                    { name = "Test Preset", priority = 5, volumes = { ["Sound_MasterVolume"] = 0.5 } }
                },
                activeManualPresets = { ["1"] = 1000 }, -- Preset 1 is active
                persistedBaseline = { ["Sound_MasterVolume"] = 1.0 },
                lastAppliedState = { ["Sound_MasterVolume"] = 1.0 }
            },
            minimap = {},
            layout = { sliderOrder = {}, footerOrder = {} },
            channels = {},
            toggles = {},
            voice = {},
            hardware = {}
        }
        
        _G.GetCVar = function() return "1.0" end
        _G.SetCVar = spy.new(function() end)
        _G.GetTime = function() return 2000 end

        _G.GetRealZoneText = function() return "Elwynn Forest" end
        _G.GetSubZoneText = function() return "Goldshire" end
        _G.GetMinimapZoneText = function() return "Lion's Pride Inn" end
        
        _G.C_VoiceChat = {
            GetOutputVolume = function() return 100 end,
            GetMasterVolumeScale = function() return 1 end,
            GetInputVolume = function() return 100 end,
            GetVADSensitivity = function() return 0 end
        }

        -- Load modules
        local addonName, addonTable = "VolumeSliders", {}
        
        -- Load Core (for constants)
        loadfile("VolumeSliders/Core.lua")(addonName, addonTable)
        -- Load Presets (the engine)
        loadfile("VolumeSliders/Presets.lua")(addonName, addonTable)
        
        VS = addonTable
        VS.InitializeSettings = function() end
        VS.UpdateMiniMapButtonVisibility = function() end
        VS.HandlePTT_OnMouseUp = function() end
        VS.HandlePTT_OnMouseDown = function() end
        VS.UpdateMiniMapVolumeIcon = function() end
        VS.HookBrokerScroll = function() end
        VS.LDBIcon = { Register = function() end }
        VS.Fishing = { Initialize = function() end }
        VS.LFGQueue = { Initialize = function() end }
        VS.VolumeSlidersObject = {}
        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function()
            return {
                RegisterEvent = function() end,
                UnregisterEvent = function() end,
                SetScript = function(self, evt, handler)
                    if evt == "OnEvent" then initFrameScript = handler end
                end,
                RegisterForClicks = function() end,
                EnableMouseWheel = function() end,
                EnableMouse = function() end,
                HookScript = function() end
            }
        end

        -- Load Init
        loadfile("VolumeSliders/Init.lua")(addonName, VS)
        _G.CreateFrame = realCreateFrame
    end)

    it("should restore manual presets as objects and avoid crashing in EvaluateAllPresets", function()
        -- Directly trigger PLAYER_LOGIN
        -- This will trigger RefreshEventState -> OnPresetEvent -> EvaluateAllPresets
        assert.has_no.errors(function()
            initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")
        end)

        -- Verify the session state holds the actual preset object
        local restoredPreset = VS.session.activeRegistry.manual[1]
        assert.is_table(restoredPreset)
        assert.are.equal("Test Preset", restoredPreset.name)
        assert.are.equal(0.5, restoredPreset.volumes["Sound_MasterVolume"])
        
        -- Verify that SetCVar was eventually called with the preset volume (0.5)
        assert.spy(_G.SetCVar).was_called_with("Sound_MasterVolume", 0.5)
    end)
end)
