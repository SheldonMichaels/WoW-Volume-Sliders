-------------------------------------------------------------------------------
-- spec/MigrationV10_spec.lua
-- Tests the V9 to V10 database migration.
-------------------------------------------------------------------------------

describe("V9 to V10 Database Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        VS = {}

        -- Mock a pristine V9 Database
        _G.VolumeSlidersMMDB = {
            schemaVersion = 9,
            toggles = {},
            appearance = {},
            minimap = {
                minimalistMinimap = true,
                minimalistOffsetX = 5,
                minimalistOffsetY = -5
            },
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

    it("should migrate schemaVersion from 9 to 10 and inject defaults", function()
        local db = _G.VolumeSlidersMMDB

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(10, db.schemaVersion)
        
        -- Ensure old keys were untouched
        assert.is_true(db.minimap.minimalistMinimap)
        assert.are.equal(5, db.minimap.minimalistOffsetX)
        assert.are.equal(-5, db.minimap.minimalistOffsetY)
        
        -- Check newly injected defaults
        assert.are.equal(1.0, db.minimap.iconScale)
        assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, db.minimap.iconColor)
        assert.are.equal(0.2, db.minimap.fadeSpeed)
        assert.is_false(db.minimap.minimalistClampMode)
        assert.are.equal(225, db.minimap.minimalistAngle)
        assert.are.equal(10, db.minimap.minimalistRadius)
    end)

    it("should not overwrite existing fields if already set", function()
        local db = _G.VolumeSlidersMMDB
        db.minimap.iconScale = 1.5
        db.minimap.iconColor = { r = 0, g = 0, b = 0, a = 1 }
        db.minimap.fadeSpeed = 0.5
        db.minimap.minimalistClampMode = true
        db.minimap.minimalistAngle = 90
        db.minimap.minimalistRadius = 50

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(10, db.schemaVersion)
        assert.are.equal(1.5, db.minimap.iconScale)
        assert.are.same({ r = 0, g = 0, b = 0, a = 1 }, db.minimap.iconColor)
        assert.are.equal(0.5, db.minimap.fadeSpeed)
        assert.is_true(db.minimap.minimalistClampMode)
        assert.are.equal(90, db.minimap.minimalistAngle)
        assert.are.equal(50, db.minimap.minimalistRadius)
    end)
end)
