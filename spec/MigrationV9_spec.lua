-------------------------------------------------------------------------------
-- spec/MigrationV9_spec.lua
-- Tests the V8 to V9 database migration.
-------------------------------------------------------------------------------

describe("V8 to V9 Database Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        VS = {}

        -- Mock a pristine V8 Database
        _G.VolumeSlidersMMDB = {
            schemaVersion = 8,
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

    it("should initialize volumeDisplayFormat to percentage and stamp version 9", function()
        local db = _G.VolumeSlidersMMDB

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(9, db.schemaVersion)
        assert.are.equal("percentage", db.appearance.volumeDisplayFormat)
    end)

    it("should not overwrite an existing volumeDisplayFormat", function()
        local db = _G.VolumeSlidersMMDB
        db.appearance.volumeDisplayFormat = "decibel"

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(9, db.schemaVersion)
        assert.are.equal("decibel", db.appearance.volumeDisplayFormat)
    end)
end)
