-------------------------------------------------------------------------------
-- spec/MigrationV8_spec.lua
-- Tests the V7 to V8 database migration.
-------------------------------------------------------------------------------

describe("V7 to V8 Database Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        VS = {}

        -- Mock a pristine V7 Database
        _G.VolumeSlidersMMDB = {
            schemaVersion = 7,
            toggles = {},
            appearance = {},
            minimap = {},
            layout = { footerOrder = {} }
        }

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

        local f1 = assert(loadfile("VolumeSliders/Core.lua"))
        f1("VolumeSliders", VS)

        -- Stub Dependencies
        VS.LDBIcon = { Register = function() end, IsRegistered = function() return false end }
        VS.LDB = { NewDataObject = function() return {} end }
        VS.VolumeSlidersObject = {}
        VS.InitializeSettings = function() end
        VS.UpdateMiniMapButtonVisibility = function() end
        VS.AdjustVolume = function() end
        _G.C_AddOns = { IsAddOnLoaded = function() return false end }

        local f2 = assert(loadfile("VolumeSliders/Init.lua"))
        f2("VolumeSliders", VS)

        _G.CreateFrame = realCreateFrame
    end)

    it("should initialize playSampleSound to false and sampleSound to 856, and stamp version 8", function()
        local db = _G.VolumeSlidersMMDB
        
        -- Logic is executed during PLAYER_LOGIN
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(8, db.schemaVersion)
        assert.is_false(db.toggles.playSampleSound)
        assert.are.equal(856, db.appearance.sampleSound)
    end)

    it("should not overwrite existing sample sound variables if migrating from higher versions or manually set", function()
        local db = _G.VolumeSlidersMMDB
        db.toggles.playSampleSound = true
        db.appearance.sampleSound = "Sound/MyCustomSound.ogg"
        
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(8, db.schemaVersion)
        assert.is_true(db.toggles.playSampleSound)
        assert.are.equal("Sound/MyCustomSound.ogg", db.appearance.sampleSound)
    end)
end)
