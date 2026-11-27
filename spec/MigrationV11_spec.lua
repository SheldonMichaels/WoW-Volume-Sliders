-------------------------------------------------------------------------------
-- spec/MigrationV11_spec.lua
-- Tests the V10 to V11 database migration (None+Scroll -> Scroll).
-------------------------------------------------------------------------------

describe("V10 to V11 Database Migration", function()
    local VS
    local initFrameScript

    before_each(function()
        VS = {}

        _G.VolumeSlidersMMDB = {
            schemaVersion = 10,
            toggles = {},
            appearance = {},
            minimap = {
                minimalistMinimap = true,
                mouseActions = {
                    { trigger = "None+Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_MasterVolume", numStep = 0.05 },
                    { trigger = "Ctrl+LeftButton", effect = "TOGGLE_WINDOW" },
                }
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

    it("normalizes None+Scroll to Scroll and stamps schemaVersion 11", function()
        local db = _G.VolumeSlidersMMDB

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(11, db.schemaVersion)
        assert.are.equal(2, #db.minimap.mouseActions)
        assert.are.equal("Scroll", db.minimap.mouseActions[1].trigger)
        assert.are.equal("SCROLL_VOLUME", db.minimap.mouseActions[1].effect)
        assert.are.equal("Sound_MasterVolume", db.minimap.mouseActions[1].stringTarget)
        assert.are.equal(0.05, db.minimap.mouseActions[1].numStep)
        assert.are.equal("Ctrl+LeftButton", db.minimap.mouseActions[2].trigger)
    end)

    it("preserves custom channel and step on migrated None+Scroll bindings", function()
        local db = _G.VolumeSlidersMMDB
        db.minimap.mouseActions = {
            { trigger = "None+Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_SFXVolume", numStep = 0.10 }
        }

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(11, db.schemaVersion)
        assert.are.equal("Scroll", db.minimap.mouseActions[1].trigger)
        assert.are.equal("Sound_SFXVolume", db.minimap.mouseActions[1].stringTarget)
        assert.are.equal(0.10, db.minimap.mouseActions[1].numStep)
    end)

    it("removes redundant None+Scroll when a Scroll binding already exists", function()
        local db = _G.VolumeSlidersMMDB
        db.minimap.mouseActions = {
            { trigger = "Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_MusicVolume", numStep = 0.10 },
            { trigger = "None+Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_MasterVolume", numStep = 0.05 },
        }

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(11, db.schemaVersion)
        assert.are.equal(1, #db.minimap.mouseActions)
        assert.are.equal("Scroll", db.minimap.mouseActions[1].trigger)
        assert.are.equal("Sound_MusicVolume", db.minimap.mouseActions[1].stringTarget)
    end)

    it("migrates None+Scroll when an unfinished Scroll action exists", function()
        local db = _G.VolumeSlidersMMDB
        db.minimap.mouseActions = {
            { trigger = "None+Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_SFXVolume", numStep = 0.10 },
            { trigger = "Scroll" },
        }

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(11, db.schemaVersion)
        assert.are.same({
            { trigger = "Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_SFXVolume", numStep = 0.10 },
            { trigger = "Scroll" },
        }, db.minimap.mouseActions)
    end)

    it("handles missing minimap mouseActions cleanly and remains idempotent", function()
        local db = _G.VolumeSlidersMMDB
        db.minimap = nil

        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")
        assert.are.equal(11, db.schemaVersion)
        assert.is_table(db.minimap.mouseActions)
        assert.are.equal("Scroll", db.minimap.mouseActions[1].trigger)

        db.minimap.mouseActions[1].stringTarget = "Sound_AmbienceVolume"
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")

        assert.are.equal(11, db.schemaVersion)
        assert.are.equal("Scroll", db.minimap.mouseActions[1].trigger)
        assert.are.equal("Sound_AmbienceVolume", db.minimap.mouseActions[1].stringTarget)
    end)
end)
