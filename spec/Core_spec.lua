-------------------------------------------------------------------------------
-- spec/Core_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Core Module", function()
    local VS

    before_each(function()
        VS = {}
        
        -- Mock WoW globals BEFORE loading Core.lua (because Core.lua localizes them)
        _G.PlaySound = spy.new(function() return true, 123 end)
        _G.PlaySoundFile = spy.new(function() return true, 123 end)
        _G.StopSound = spy.new(function() end)
        _G.C_Timer = { NewTimer = function(delay, cb) cb() return { Cancel = function() end } end }
        
        -- Mock dependencies that Core.lua expects to exist or call
        _G.VolumeSlidersMMDB = {
            schemaVersion = 8,
            appearance = { windowWidth = 375, windowHeight = 440, sampleSound = 856, sampleSoundMinimap = 850 },
            layout = { sliderOrder = {}, footerOrder = {}, mouseActions = { sliders = {}, scrollWheel = {} } },
            toggles = { showMinimapTooltip = true, playSampleSound = true, playSampleSoundMinimap = true },
            channels = {},
            minimap = { mouseActions = {}, minimapTooltipOrder = {} },
            automation = { persistedBaseline = {}, presets = {} },
        }

        -- Mock external functions called by Core.lua
        VS.UpdateMiniMapVolumeIcon = function() end
        VS.RefreshMinimapTooltip = function() end
        
        -- Load the Core file exactly as WoW would (passing addonName and addonTable)
        local f = assert(loadfile("VolumeSliders/Core.lua"))
        f("VolumeSliders", VS)
    end)

    it("should instantiate LibDataBroker and LibDBIcon", function()
        assert.is_table(VS.LDB)
        assert.is_table(VS.LDBIcon)
    end)

    describe("Volume Utilities", function()
        it("GetMasterVolume should return numeric CVar value", function()
            _G.SetCVar("Sound_MasterVolume", "0.5")
            assert.equal(0.5, VS:GetMasterVolume())
        end)

        it("GetVolumeText should return percentage string", function()
            _G.SetCVar("Sound_MasterVolume", "0.45")
            assert.equal("45%", VS:GetVolumeText())
        end)

        it("AdjustVolume should clamp to [0, 1]", function()
            _G.SetCVar("Sound_MasterVolume", "0.98")
            VS:AdjustVolume(1)
            assert.equal("1", GetCVar("Sound_MasterVolume"))
        end)
    end)

    describe("Syncing", function()
        it("SyncBaseline should store values in persistedBaseline", function()
            VS:SyncBaseline("Sound_MasterVolume", 0.5)
            assert.equal(0.5, _G.VolumeSlidersMMDB.automation.persistedBaseline["Sound_MasterVolume"])
        end)
    end)

    describe("Sample Sound System", function()
        before_each(function()
            -- Clear spies for each test in this sub-block
            _G.PlaySound:clear()
            _G.PlaySoundFile:clear()
            VS.session.soundDebounceTimers = {}
        end)

        it("AdjustVolume should trigger PlaySampleSound with isMinimap = true", function()
            spy.on(VS, "PlaySampleSound")
            VS:AdjustVolume(1)
            assert.spy(VS.PlaySampleSound).was_called_with(match.is_table(), match.is_string(), match.is_number(), true)
        end)

        it("PlaySampleSound should distinguish between Slider and Minimap settings", function()
            -- Test Slider
            _G.VolumeSlidersMMDB.toggles.playSampleSound = true
            _G.VolumeSlidersMMDB.toggles.playSampleSoundMinimap = false
            
            VS:PlaySampleSound("Sound_MasterVolume", 0.5, false)
            assert.spy(_G.PlaySound).was_called()
            
            _G.PlaySound:clear()
            
            -- Test Minimap (disabled)
            VS:PlaySampleSound("Sound_MasterVolume", 0.5, true)
            assert.spy(_G.PlaySound).was_not_called()
            
            -- Enable and test
            _G.VolumeSlidersMMDB.toggles.playSampleSoundMinimap = true
            VS:PlaySampleSound("Sound_MasterVolume", 0.5, true)
            assert.spy(_G.PlaySound).was_called()
        end)
    end)
end)
