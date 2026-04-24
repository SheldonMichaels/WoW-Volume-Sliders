-------------------------------------------------------------------------------
-- spec/PresetReordering_spec.lua
-- Verifies move-up/move-down swap behavior through real settings handlers.
-------------------------------------------------------------------------------

local assert = require("luassert")
local spy = require("luassert.spy")
require("spec.setup")

describe("Preset reordering integration", function()
    local VS

    local function bootAutomationSettings()
        _G.VolumeSlidersMMDB = {
            automation = {
                fishingPresetIndex = 2,
                lfgPresetIndex = 3,
                activeManualPresets = { [2] = 200, [3] = 300 },
                presets = {
                    { name = "Preset 1", priority = 10, zones = {}, volumes = {}, ignored = {}, mutes = {}, modes = {}, showInDropdown = true },
                    { name = "Preset 2", priority = 20, zones = {}, volumes = {}, ignored = {}, mutes = {}, modes = {}, showInDropdown = true },
                    { name = "Preset 3", priority = 30, zones = {}, volumes = {}, ignored = {}, mutes = {}, modes = {}, showInDropdown = true },
                    { name = "Preset 4", priority = 40, zones = {}, volumes = {}, ignored = {}, mutes = {}, modes = {}, showInDropdown = true },
                }
            },
            channels = { ["Sound_MasterVolume"] = true },
            minimap = {
                mouseActions = {
                    { trigger = "Ctrl+LeftButton", effect = "TOGGLE_PRESET", stringTarget = "2" },
                    { trigger = "Alt+LeftButton", effect = "TOGGLE_PRESET", stringTarget = "3" },
                }
            },
            toggles = {},
            layout = {},
            appearance = {},
            voice = {},
            hardware = {},
        }

        VS = {
            session = {
                activeRegistry = { manual = { [2] = { name = "Preset 2" }, [3] = { name = "Preset 3" } } },
                manualActivationTimes = { [2] = 200, [3] = 300 },
            },
            AddTooltip = function() end,
            Presets = { RefreshEventState = spy.new(function() end) },
            Fishing = { Initialize = function() end },
            LFGQueue = { Initialize = function() end },
            RefreshPopupDropdown = spy.new(function() end),
        }

        loadfile("VolumeSliders/Core.lua")("VolumeSliders", VS)
        loadfile("VolumeSliders/SliderWidgets.lua")("VolumeSliders", VS)
        loadfile("VolumeSliders/Settings_Automation.lua")("VolumeSliders", VS)
        VS:CreateAutomationSettingsContents(CreateFrame("Frame"))
    end

    local function selectPreset(index)
        local menuIndex = index + 1 -- +1 for "Create New Preset"
        VS.automationPresetDropdown:SelectMenuButton(menuIndex)
    end

    before_each(function()
        bootAutomationSettings()
    end)

    it("swaps pointers and bindings when moving a preset up", function()
        selectPreset(2)
        VS.automationBtnMoveUpPreset:GetScript("OnClick")(VS.automationBtnMoveUpPreset)

        local db = _G.VolumeSlidersMMDB
        assert.are.equal(1, db.automation.fishingPresetIndex)
        assert.are.equal(3, db.automation.lfgPresetIndex)
        assert.are.equal("1", db.minimap.mouseActions[1].stringTarget)
        assert.are.equal("3", db.minimap.mouseActions[2].stringTarget)
        assert.are.equal("Preset 2", db.automation.presets[1].name)
    end)

    it("swaps pointers and bindings when moving a preset down", function()
        selectPreset(3)
        VS.automationBtnMoveDownPreset:GetScript("OnClick")(VS.automationBtnMoveDownPreset)

        local db = _G.VolumeSlidersMMDB
        assert.are.equal(2, db.automation.fishingPresetIndex)
        assert.are.equal(4, db.automation.lfgPresetIndex)
        assert.are.equal("2", db.minimap.mouseActions[1].stringTarget)
        assert.are.equal("4", db.minimap.mouseActions[2].stringTarget)
        assert.are.equal("Preset 3", db.automation.presets[4].name)
    end)
end)
