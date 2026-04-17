-------------------------------------------------------------------------------
-- spec/Core_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Core Module", function()
    local VS

    before_each(function()
        VS = {}
        -- Mock dependencies that Core.lua expects to exist or call
        _G.VolumeSlidersMMDB = {
            schemaVersion = 5,
            appearance = { windowWidth = 375, windowHeight = 440 },
            layout = { sliderOrder = {}, footerOrder = {}, mouseActions = { sliders = {}, scrollWheel = {} } },
            toggles = { showMinimapTooltip = true },
            channels = {},
            minimap = { mouseActions = {}, minimapTooltipOrder = {} },
            automation = { persistedBaseline = {}, presets = {} },
        }

        -- Load the Core file exactly as WoW would (passing addonName and addonTable)
        local f = assert(loadfile("VolumeSliders/Core.lua"))
        f("VolumeSliders", VS)

        -- Mock external functions called by Core.lua
        _G.VolumeSliders_ToggleWindow = spy.new(function() end)
        _G.VolumeSliders_ToggleMuteMaster = spy.new(function() end)
        _G.VolumeSliders_ToggleMute = VS.VolumeSliders_ToggleMute -- Keep the original for testing
        VS.RefreshMinimapTooltip = function() end
    end)

    it("should instantiate LibDataBroker and LibDBIcon", function()
        assert.is_table(VS.LDB)
        assert.is_table(VS.LDBIcon)
    end)

    it("should define constant configuration values", function()
        assert.is_number(VS.DEFAULT_WINDOW_WIDTH)
        assert.is_number(VS.MIN_SLIDER_TRACK_HEIGHT)
        assert.is_number(VS.SLIDER_COLUMN_WIDTH)
    end)

    describe("Volume Utilities", function()
        it("GetMasterVolume should return numeric CVar value", function()
            _G.SetCVar("Sound_MasterVolume", "0.5")
            assert.equal(0.5, VS:GetMasterVolume())

            _G.SetCVar("Sound_MasterVolume", "invalid")
            assert.equal(1, VS:GetMasterVolume())
        end)

        it("GetVolumeText should return percentage string", function()
            _G.SetCVar("Sound_MasterVolume", "0.75")
            assert.equal("75%", VS:GetVolumeText())

            _G.SetCVar("Sound_MasterVolume", "0.123")
            assert.equal("12%", VS:GetVolumeText())
        end)

        it("AdjustVolume should handle up/down delta", function()
            _G.SetCVar("Sound_MasterVolume", "0.5")
            VS:AdjustVolume(1) -- Default step 0.05
            assert.equal("0.55", _G.GetCVar("Sound_MasterVolume"))

            VS:AdjustVolume(-1)
            assert.equal("0.5", _G.GetCVar("Sound_MasterVolume"))
        end)

        it("AdjustVolume should handle custom steps", function()
            _G.SetCVar("Sound_MasterVolume", "0.5")
            VS:AdjustVolume(1, 0.1)
            assert.equal("0.6", _G.GetCVar("Sound_MasterVolume"))
        end)

        it("AdjustVolume should clamp to [0, 1]", function()
            _G.SetCVar("Sound_MasterVolume", "0.98")
            VS:AdjustVolume(1)
            assert.equal("1", _G.GetCVar("Sound_MasterVolume"))

            _G.SetCVar("Sound_MasterVolume", "0.01")
            VS:AdjustVolume(-1)
            assert.equal("0", _G.GetCVar("Sound_MasterVolume"))
        end)
    end)

    describe("Baseline Synchronization", function()
        it("SyncBaseline should update session and DB for volume", function()
            VS:SyncBaseline("Sound_SFXVolume", 0.4)
            assert.equal(0.4, VS.session.baselineVolumes["Sound_SFXVolume"])
            assert.equal(0.4, _G.VolumeSlidersMMDB.automation.persistedBaseline["Sound_SFXVolume"])
        end)

        it("SyncBaseline should update session and DB for mute CVars", function()
            VS:SyncBaseline("Sound_EnableSFX", "0")
            assert.equal("0", VS.session.baselineMutes["Sound_SFXVolume"])
            assert.equal("0", _G.VolumeSlidersMMDB.automation.persistedBaseline["Sound_SFXVolume_Mute"])
        end)
    end)

    describe("Input Parsing", function()
        it("GetActiveTriggerString should detect modifiers", function()
            _G.IsShiftKeyDown = function() return true end
            _G.IsControlKeyDown = function() return false end
            _G.IsAltKeyDown = function() return false end

            assert.equal("Shift+LeftButton", VS:GetActiveTriggerString("LeftButton"))
            assert.equal("Shift+Scroll", VS:GetActiveTriggerString(nil, 1))
        end)

        it("GetActiveTriggerString should handle empty modifiers", function()
            _G.IsShiftKeyDown = function() return false end
            _G.IsControlKeyDown = function() return false end
            _G.IsAltKeyDown = function() return false end

            assert.equal("RightButton", VS:GetActiveTriggerString("RightButton"))
        end)
    end)

    describe("Action Processing", function()
        it("ProcessMinimapAction should execute mapped effects", function()
            table.insert(_G.VolumeSlidersMMDB.minimap.mouseActions, {
                trigger = "LeftButton",
                effect = "TOGGLE_WINDOW"
            })

            local result = VS:ProcessMinimapAction("LeftButton", {})
            assert.is_true(result)
            assert.spy(_G.VolumeSliders_ToggleWindow).was_called()
        end)

        it("ProcessSliderAction should return correct increments", function()
            table.insert(_G.VolumeSlidersMMDB.layout.mouseActions.sliders, {
                trigger = "Shift+LeftButton",
                effect = "ADJUST_1"
            })

            assert.equal(0.01, VS:ProcessSliderAction("Shift+LeftButton"))
            assert.is_nil(VS:ProcessSliderAction("Alt+LeftButton"))
        end)
    end)
end)
