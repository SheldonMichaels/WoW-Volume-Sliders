-------------------------------------------------------------------------------
-- spec/PresetShifting_spec.lua
-- Verifies automation pointer/index shifting through real settings handlers.
-------------------------------------------------------------------------------

local assert = require("luassert")
local spy = require("luassert.spy")
require("spec.setup")

describe("Preset shifting integration", function()
    local VS

    local function bootAutomationSettings()
        _G.VolumeSlidersMMDB = {
            automation = {
                fishingPresetIndex = 2,
                lfgPresetIndex = 4,
                activeManualPresets = { [2] = 200, [4] = 400 },
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
                    { trigger = "Alt+LeftButton", effect = "TOGGLE_PRESET", stringTarget = "4" },
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
                activeRegistry = { manual = { [2] = { name = "Preset 2" }, [4] = { name = "Preset 4" } } },
                manualActivationTimes = { [2] = 200, [4] = 400 },
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

    it("shifts pointers and bindings when a preset is reordered via save", function()
        selectPreset(2)
        VS.automationInputListOrder:SetText("4")
        VS.automationBtnSavePreset:GetScript("OnClick")(VS.automationBtnSavePreset)

        local db = _G.VolumeSlidersMMDB
        assert.are.equal(4, db.automation.fishingPresetIndex)
        assert.are.equal(3, db.automation.lfgPresetIndex)
        assert.are.equal(200, db.automation.activeManualPresets[4])
        assert.are.equal(400, db.automation.activeManualPresets[3])
        assert.are.equal("4", db.minimap.mouseActions[1].stringTarget)
        assert.are.equal("3", db.minimap.mouseActions[2].stringTarget)
    end)

    it("cleans deleted pointers and shifts downstream indexes on delete", function()
        selectPreset(2)
        _G.StaticPopupDialogs["VolumeSlidersDeletePresetConfirm"].OnAccept()

        local db = _G.VolumeSlidersMMDB
        assert.is_nil(db.automation.fishingPresetIndex)
        assert.are.equal(3, db.automation.lfgPresetIndex)
        assert.is_nil(db.automation.activeManualPresets[2])
        assert.are.equal(400, db.automation.activeManualPresets[3])
        assert.is_nil(db.minimap.mouseActions[1].stringTarget)
        assert.are.equal("3", db.minimap.mouseActions[2].stringTarget)
    end)
end)
