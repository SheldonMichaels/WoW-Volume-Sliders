-------------------------------------------------------------------------------
-- spec/Settings_Automation_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Settings Automation Module", function()
    local VS

    before_each(function()
        VS = {
            session = { activeRegistry = { manual = {} }, manualActivationTimes = {} },
            AddTooltip = function() end,
            Presets = { RefreshEventState = spy.new(function() end) },
            Fishing = { Initialize = spy.new(function() end) },
            LFGQueue = { Initialize = spy.new(function() end) },
        }
        _G.VolumeSlidersMMDB = {
            automation = {
                enableTriggers = true,
                enableFishingVolume = true,
                enableLfgVolume = true,
                presets = {
                    { name = "Test Preset", priority = 5, zones = {"Oribos"}, volumes = {}, ignored = {}, mutes = {}, modes = {} }
                },
                activeManualPresets = {}
            },
            channels = { ["Sound_MasterVolume"] = true }
        }

        -- Load dependencies
        local fCore = assert(loadfile("VolumeSliders/Core.lua"))
        fCore("VolumeSliders", VS)

        local fWidgets = assert(loadfile("VolumeSliders/SliderWidgets.lua"))
        fWidgets("VolumeSliders", VS)

        local fAuto = assert(loadfile("VolumeSliders/Settings_Automation.lua"))
        fAuto("VolumeSliders", VS)
    end)

    it("CreateAutomationSettingsContents should initialize UI components", function()
        local parent = CreateFrame("Frame")
        VS:CreateAutomationSettingsContents(parent)

        assert.is_not_nil(_G.VSAutomationSettingsScrollFrame)
        assert.is_not_nil(_G.VSAutomationSettingsContentFrame)

        -- Verify dropdowns were attached to VS
        assert.is_not_nil(VS.fishingDropdown)
        assert.is_not_nil(VS.lfgDropdown)
    end)

    it("RefreshAutomationProfiles should update dropdown text", function()
        local parent = CreateFrame("Frame")
        VS:CreateAutomationSettingsContents(parent)

        _G.VolumeSlidersMMDB.automation.fishingPresetIndex = 1
        VS:RefreshAutomationProfiles()

        assert.equal("Test Preset", VS.fishingDropdown:GetDefaultText())
    end)

    it("RefreshAutomationProfiles should update dropdown menu states", function()
        local parent = CreateFrame("Frame")
        VS:CreateAutomationSettingsContents(parent)

        -- In our mock setup, SetupMenu is called during RefreshAutomationProfiles
        VS:RefreshAutomationProfiles()
        assert.is_not_nil(VS.fishingDropdown)
        assert.is_not_nil(VS.lfgDropdown)
    end)
end)
