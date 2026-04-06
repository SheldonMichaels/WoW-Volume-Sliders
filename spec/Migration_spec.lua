-------------------------------------------------------------------------------
-- spec/Migration_spec.lua
-- Tests the V1 to V2 database migration and verification of namespaced routing.
-------------------------------------------------------------------------------

describe("V1 to V2 Database Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        VS = {}

        -- Mock a dirty V1 Database exactly as it would appear prior to updating
        _G.VolumeSlidersMMDB = {
            -- Transient keys (should be purged)
            originalVolumes = { ["Sound_MasterVolume"] = 1 },
            originalMutes = { ["Sound_MasterVolume"] = "1" },
            layoutDirty = true,

            -- Flat appearance
            bgColorR = 0.5, bgColorG = 0.5, bgColorB = 0.5, bgColorA = 1,
            titleColor = "ffffff",
            windowWidth = 200,

            -- Flat layout
            sliderOrder = { "Sound_MasterVolume" },
            maxFooterCols = 3,

            -- Flat toggles
            showTitle = true,
            showMute = false,
            isLocked = true,

            -- Channel visibility mapping
            showMaster = true,
            showVoiceChat = false,

            -- Minimap
            minimapPos = 45,
            minimalistMinimap = true,

            -- Hardware
            deviceVolumes = { ["Test_Device"] = 0.5 },

            -- Automation
            enableTriggers = true,
            fishingPresetIndex = 2,

            -- Deprecated legacy keys (should be purged)
            triggers = { "Elwynn" },
            presets = {
                {
                    ignored = { ["Sound_MasterVolume"] = true }
                },
                {
                    -- Preset with NO ignored table (should be initialized by migration)
                    name = "Bare Bones",
                    volumes = { ["Sound_MasterVolume"] = 0.5 }
                }
            },
            enableFishingMaster = true,
            mouseActions = { preset = 1, sliders = {} },
            minimapScrollBindings = { 
                ["Shift"] = "Sound_MasterVolume",
                ["None"] = "Sound_MusicVolume",
                ["Ctrl"] = "Disabled"
            },

            -- Voice mute states
            MuteState_Voice_ChatVolume = "1",
            SavedVol_Voice_ChatVolume = "0.5",
        }

        -- Stub out create frame to catch the Init event script
        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function(frameType, name, parent, template)
            local f = realCreateFrame(frameType, name, parent, template)
            local oldSetScript = f.SetScript
            f.SetScript = function(self, evt, handler)
                if evt == "OnEvent" then
                    initFrameScript = handler
                end
                if oldSetScript then oldSetScript(self, evt, handler) end
            end
            return f
        end

        -- Load Core
        local f1 = assert(loadfile("VolumeSliders/Core.lua"))
        f1("VolumeSliders", VS)

        -- Mock LDB and other initialization dependencies
        VS.LDBIcon = { Register = function() end, IsRegistered = function() return false end }
        VS.LDB = { NewDataObject = function() return {} end }
        VS.VolumeSlidersObject = {}
        VS.InitializeSettings = function() end
        VS.UpdateMiniMapButtonVisibility = function() end
        VS.AdjustVolume = function() end

        -- Load Init.lua to prime the migration event
        local f2 = assert(loadfile("VolumeSliders/Init.lua"))
        f2("VolumeSliders", VS)
        
        -- Restore original
        _G.CreateFrame = realCreateFrame
    end)

    it("should successfully migrate flat keys to namespaces and stamp schema version", function()
        -- Fire migration
        assert.is_function(initFrameScript)
        initFrameScript({UnregisterEvent = function() end}, "PLAYER_LOGIN")

        local db = _G.VolumeSlidersMMDB

        -- Assert Version Label
        assert.are.equal(4, db.schemaVersion)

        -- Assert transient keys are completely purged
        assert.is_nil(db.originalVolumes)
        assert.is_nil(db.originalMutes)
        assert.is_nil(db.layoutDirty)

        -- Assert deprecated keys are purged
        assert.is_nil(db.triggers)
        assert.is_nil(db.enableFishingMaster)
        assert.is_nil(db.mouseActions) -- Root mouseActions must be split and removed

        -- Assert mouseActions split routing
        assert.is_table(db.layout.mouseActions)
        assert.is_table(db.layout.mouseActions.sliders)
        assert.is_table(db.minimap.mouseActions)

        -- Assert Appearance routing
        assert.is_table(db.appearance)
        assert.are.equal(0.5, db.appearance.bgColor.r)
        assert.are.equal("ffffff", db.appearance.titleColor)
        assert.are.equal(200, db.appearance.windowWidth)
        assert.is_nil(db.bgColorR) -- Root key must be gone

        -- Assert Layout routing
        assert.is_table(db.layout)
        assert.are.equal("Sound_MasterVolume", db.layout.sliderOrder[1])
        assert.are.equal(3, db.layout.maxFooterCols)
        assert.is_nil(db.sliderOrder) -- Root key must be gone

        -- Assert Toggles routing
        assert.is_table(db.toggles)
        assert.is_true(db.toggles.showTitle)
        assert.is_false(db.toggles.showMute)
        assert.is_true(db.toggles.isLocked)
        assert.is_nil(db.showTitle) -- Root key must be gone

        -- Assert Channels routing
        assert.is_table(db.channels)
        assert.is_true(db.channels["Sound_MasterVolume"])
        assert.is_false(db.channels["Voice_ChatVolume"])
        assert.is_nil(db.showMaster) -- Root key must be gone

        -- Assert Minimap routing
        assert.is_table(db.minimap)
        assert.are.equal(45, db.minimap.minimapPos)
        assert.is_true(db.minimap.minimalistMinimap)
        assert.is_nil(db.minimapPos) -- Root key must be gone
        
        -- Assert Migrated Scroll Actions
        assert.is_table(db.minimap.mouseActions)
        local shiftScrollFound = false
        local noneScrollFound = false
        for _, action in ipairs(db.minimap.mouseActions) do
            if action.trigger == "Shift+Scroll" and action.effect == "SCROLL_VOLUME" and action.stringTarget == "Sound_MasterVolume" then
                shiftScrollFound = true
            end
            if action.trigger == "Scroll" and action.effect == "SCROLL_VOLUME" and action.stringTarget == "Sound_MusicVolume" then
                noneScrollFound = true
            end
            -- Disabled bindings should not exist
            assert.is_not.equal("Ctrl+Scroll", action.trigger)
        end
        assert.is_true(shiftScrollFound)
        assert.is_true(noneScrollFound)
        assert.is_nil(db.minimapScrollBindings)

        -- Assert Hardware routing
        assert.is_table(db.hardware)
        assert.are.equal(0.5, db.hardware.deviceVolumes["Test_Device"])
        assert.is_nil(db.deviceVolumes)

        -- Assert Automation routing
        assert.is_table(db.automation)
        assert.is_true(db.automation.enableTriggers)
        assert.are.equal(2, db.automation.fishingPresetIndex)
        assert.is_nil(db.enableTriggers)

        -- Assert Voice routing
        assert.is_table(db.voice)
        assert.are.equal("1", db.voice.MuteState_Voice_ChatVolume)
        assert.are.equal("0.5", db.voice.SavedVol_Voice_ChatVolume)
        assert.is_nil(db.MuteState_Voice_ChatVolume) -- Root key must be gone
        assert.is_nil(db.SavedVol_Voice_ChatVolume) -- Root key must be gone

        -- Assert Preset Ignore Migration
        assert.is_nil(db.presets) -- Root key must be gone
        assert.is_table(db.automation.presets)
        assert.is_true(db.automation.presets[1].ignored["Sound_GameplaySFX"])
        assert.is_true(db.automation.presets[1].ignored["Sound_PingVolume"])
        assert.is_true(db.automation.presets[1].ignored["Sound_EncounterWarningsVolume"])

        -- Assert regression for preset without existing ignored table
        assert.is_table(db.automation.presets[2].ignored)
        assert.is_true(db.automation.presets[2].ignored["Sound_GameplaySFX"])
        assert.is_true(db.automation.presets[2].ignored["Sound_PingVolume"])
        assert.is_true(db.automation.presets[2].ignored["Sound_EncounterWarningsVolume"])
        assert.is_true(db.automation.presets[1].ignored["Sound_EncounterWarningsVolume"])
        assert.is_true(db.automation.presets[1].ignored["Sound_MasterVolume"]) -- Original should be preserved
    end)
end)
