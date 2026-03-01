local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Triggers tests", function()
    local VS

    before_each(function()
        -- Reset state
        _G.VolumeSlidersMMDB = {
            enableTriggers = true,
            originalVolumes = {},
            triggers = {}
        }
        
        -- Mock GetRealZoneText using mutable references
        _G.zoneStates = {
            real = "Elwynn Forest",
            sub = "Goldshire",
            mini = "Lion's Pride Inn"
        }
        _G.GetRealZoneText = function() return _G.zoneStates.real end
        _G.GetSubZoneText = function() return _G.zoneStates.sub end
        _G.GetMinimapZoneText = function() return _G.zoneStates.mini end

        -- Mock CVars and Spy before file is loaded to capture locals correctly
        _G.cvarStorage = {
            ["Sound_MasterVolume"] = 1.0,
        }
        _G.GetCVar = function(name) return tostring(_G.cvarStorage[name] or 1) end
        
        _G.setCvarSpy = spy.new(function(name, val)
            _G.cvarStorage[name] = val
        end)
        _G.SetCVar = _G.setCvarSpy

        local addonName = "VolumeSliders"
        local addonTable = {}
        
        -- Re-evaluate with mock arguments
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        
        local triggersChunk = loadfile("VolumeSliders/Triggers.lua")
        triggersChunk(addonName, addonTable)

        VS = addonTable
    end)

    it("does nothing returning instantly if triggers are disabled", function()
        _G.VolumeSlidersMMDB.enableTriggers = false
        VS.Triggers:RefreshEventState()
        
        assert.spy(_G.setCvarSpy).was_not_called()
    end)
    
    it("sorts and overrides volumes correctly and restores them", function()
        _G.VolumeSlidersMMDB.triggers = {
            {
                name = "Test 1", priority = 10,
                zones = {"Elwynn Forest"},
                volumes = { ["Sound_MasterVolume"] = 0.5 },
                ignored = {}
            },
            {
                name = "Test 2", priority = 100,
                zones = {"Goldshire"},
                volumes = { ["Sound_MasterVolume"] = 0.2 },
                ignored = {}
            }
        }
        
        VS.Triggers:RefreshEventState()
        
        -- Goldshire (Priority 100) should override Elwynn Forest (Priority 10)
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 0.2)
        -- The volume should now be 0.2
        assert.are.equal(0.2, _G.cvarStorage["Sound_MasterVolume"])
        -- It should have saved the original volume of 1.0
        assert.are.equal(1.0, _G.VolumeSlidersMMDB.originalVolumes["Sound_MasterVolume"])
        
        -- Now let's simulate leaving Goldshire, meaning only Elwynn is active
        _G.zoneStates.sub = "Unknown"
        VS.Triggers:RefreshEventState()
        
        -- Should have overridden with 0.5 this time
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 0.5)
        
        -- Now leaving Elwynn Forest (no triggers apply)
        _G.zoneStates.real = "Unknown"
        VS.Triggers:RefreshEventState()
        
        -- Should have restored the original volume (1.0)
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 1.0)
        assert.is_nil(_G.VolumeSlidersMMDB.originalVolumes["Sound_MasterVolume"])
    end)
end)
