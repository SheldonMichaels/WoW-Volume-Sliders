local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Presets tests", function()
    local VS

    before_each(function()
        -- Reset state
        _G.VolumeSlidersMMDB = {
            schemaVersion = 2,
            automation = {
                enableTriggers = true,
                presets = {},
                manualToggleState = {}
            },
            toggles = {}, channels = {}, layout = {}, voice = {}, minimap = {}, appearance = {}, hardware = {}
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
        
        local presetsChunk = loadfile("VolumeSliders/Presets.lua")
        presetsChunk(addonName, addonTable)

        VS = addonTable
    end)

    it("does nothing returning instantly if triggers are disabled", function()
        _G.VolumeSlidersMMDB.automation.enableTriggers = false
        VS.Presets:RefreshEventState()
        
        assert.spy(_G.setCvarSpy).was_not_called()
    end)
    
    it("sorts and overrides volumes correctly and restores them", function()
        _G.VolumeSlidersMMDB.automation.presets = {
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
        
        VS.Presets:RefreshEventState()
        
        -- Goldshire (Priority 100) should override Elwynn Forest (Priority 10)
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 0.2)
        -- The volume should now be 0.2
        assert.are.equal(0.2, _G.cvarStorage["Sound_MasterVolume"])
        -- It should have saved the original volume of 1.0
        assert.are.equal(1.0, VS.session.originalVolumes["Sound_MasterVolume"])
        
        -- Now let's simulate leaving Goldshire, meaning only Elwynn is active
        _G.zoneStates.sub = "Unknown"
        VS.Presets:RefreshEventState()
        
        -- Should have overridden with 0.5 this time
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 0.5)
        
        -- Now leaving Elwynn Forest (no triggers apply)
        _G.zoneStates.real = "Unknown"
        VS.Presets:RefreshEventState()
        
        -- Should have restored the original volume (1.0)
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 1.0)
        assert.is_nil(VS.session.originalVolumes["Sound_MasterVolume"])
    end)

    it("handles automation states and priority interactions", function()
        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "Zone Preset", priority = 10,
                zones = {"Elwynn Forest"},
                volumes = { ["Sound_MasterVolume"] = 0.5 },
                ignored = {}
            },
            {
                name = "Fishing Preset", priority = 50,
                zones = {},
                volumes = { ["Sound_MasterVolume"] = 0.8 },
                ignored = {}
            }
        }
        _G.VolumeSlidersMMDB.automation.fishingPresetIndex = 2
        _G.VolumeSlidersMMDB.automation.enableFishingVolume = true
        
        -- 1. Only zone active
        VS.Presets:RefreshEventState()
        assert.are.equal(0.5, _G.cvarStorage["Sound_MasterVolume"])
        
        -- 2. Activate fishing state (higher priority than zone)
        VS.Presets:SetStateActive("fishing", true)
        assert.are.equal(0.8, _G.cvarStorage["Sound_MasterVolume"])
        
        -- 3. Deactivate fishing (should fall back to zone)
        VS.Presets:SetStateActive("fishing", false)
        assert.are.equal(0.5, _G.cvarStorage["Sound_MasterVolume"])
        
        -- 4. Move away from zone (should restore original 1.0)
        _G.zoneStates.real = "Unknown"
        VS.Presets:RefreshEventState()
        assert.are.equal(1.0, _G.cvarStorage["Sound_MasterVolume"])
    end)

    it("evaluates and returns the names of active presets dynamically", function()
        _G.VolumeSlidersMMDB.automation.presets = {
            { name = "Elwynn Tier", zones = {"Elwynn Forest"}, volumes = {} },
            { name = "Inn Tier", zones = {"Lion's Pride Inn"}, volumes = {} },
            { name = "Fishing Setup", zones = {}, volumes = {} }
        }
        _G.VolumeSlidersMMDB.automation.enableFishingVolume = true
        _G.VolumeSlidersMMDB.automation.fishingPresetIndex = 3

        -- 1. No triggers
        _G.zoneStates.real = "Unknown"
        _G.zoneStates.sub = "Unknown"
        _G.zoneStates.mini = "Unknown"
        VS.Presets:SetStateActive("fishing", false)
        VS.Presets:RefreshEventState()
        assert.are.equal("None", VS.Presets:GetActiveTriggersString())

        -- 2. Enter Elwynn AND Inn
        _G.zoneStates.real = "Elwynn Forest"
        _G.zoneStates.sub = "Goldshire"
        _G.zoneStates.mini = "Lion's Pride Inn"
        VS.Presets:RefreshEventState()
        
        -- Tests multi-zone concatenation
        assert.are.equal("Elwynn Tier, Inn Tier", VS.Presets:GetActiveTriggersString())

        -- 3. Trigger Fishing globally
        VS.Presets:SetStateActive("fishing", true)
        assert.are.equal("Elwynn Tier, Inn Tier, Fishing Setup", VS.Presets:GetActiveTriggersString())

        -- 4. Manual Preset Toggle
        -- Even if fishing is active, manual toggle should be added (and deduplicated if necessary)
        _G.VolumeSlidersMMDB.automation.manualToggleState[1] = { volumes = {} } -- "Elwynn Tier"
        assert.are.equal("Elwynn Tier, Inn Tier, Fishing Setup", VS.Presets:GetActiveTriggersString())

        -- Add a NEW manual preset
        _G.VolumeSlidersMMDB.automation.manualToggleState[4] = { volumes = {} } -- Non-existent name check
        _G.VolumeSlidersMMDB.automation.presets[4] = { name = "Manual High Ground" }
        assert.are.equal("Elwynn Tier, Inn Tier, Fishing Setup, Manual High Ground", VS.Presets:GetActiveTriggersString())
    end)

    ---------------------------------------------------------------------------
    -- Toggle Behavior Tests
    ---------------------------------------------------------------------------

    it("toggles a preset on and off, restoring original values", function()
        _G.cvarStorage["Sound_MasterVolume"] = 1.0
        _G.cvarStorage["Sound_MusicVolume"] = 0.8

        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "Test Toggle",
                volumes = { ["Sound_MasterVolume"] = 0.3, ["Sound_MusicVolume"] = 0.2 },
                ignored = {}
            }
        }

        -- 1. Apply (toggle ON)
        local isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_true(isActive)
        assert.are.equal(0.3, _G.cvarStorage["Sound_MasterVolume"])
        assert.are.equal(0.2, _G.cvarStorage["Sound_MusicVolume"])

        -- 2. Toggle OFF (volumes unchanged, so restore)
        isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_false(isActive)
        assert.are.equal(1.0, _G.cvarStorage["Sound_MasterVolume"])
        assert.are.equal(0.8, _G.cvarStorage["Sound_MusicVolume"])
    end)

    it("re-applies a toggled preset when channels have been modified", function()
        _G.cvarStorage["Sound_MasterVolume"] = 1.0

        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "Re-Apply Test",
                volumes = { ["Sound_MasterVolume"] = 0.5 },
                ignored = {}
            }
        }

        -- 1. Apply (toggle ON)
        local isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_true(isActive)
        assert.are.equal(0.5, _G.cvarStorage["Sound_MasterVolume"])

        -- 2. Manually change the channel
        _G.cvarStorage["Sound_MasterVolume"] = 0.7

        -- 3. Toggle again → should re-apply (not restore), since value changed
        isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_true(isActive)
        assert.are.equal(0.5, _G.cvarStorage["Sound_MasterVolume"])

        -- 4. Now toggle OFF (nothing changed this time)
        isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_false(isActive)
        -- Should restore to 0.7 (the fresh snapshot from step 3)
        assert.are.equal(0.7, _G.cvarStorage["Sound_MasterVolume"])
    end)

    it("applies mute overrides when preset has mutes configured", function()
        _G.cvarStorage["Sound_MusicVolume"] = 0.8
        _G.cvarStorage["Sound_EnableMusic"] = "1"

        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "Mute Test",
                volumes = { ["Sound_MusicVolume"] = 0.5 },
                mutes = { ["Sound_MusicVolume"] = true },
                ignored = {}
            }
        }

        VS.Presets:ApplyPreset(_G.VolumeSlidersMMDB.automation.presets[1])

        assert.are.equal(0.5, _G.cvarStorage["Sound_MusicVolume"])
        assert.spy(_G.setCvarSpy).was_called_with("Sound_EnableMusic", 0)
    end)

    it("toggles mute on and off, restoring original mute state on un-toggle", function()
        _G.cvarStorage["Sound_MusicVolume"] = 0.8
        _G.cvarStorage["Sound_EnableMusic"] = "1"

        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "Mute Toggle Test",
                volumes = { ["Sound_MusicVolume"] = 0.3 },
                mutes = { ["Sound_MusicVolume"] = true },
                ignored = {}
            }
        }

        -- 1. Toggle ON → should mute
        local isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_true(isActive)
        assert.are.equal(0.3, _G.cvarStorage["Sound_MusicVolume"])
        assert.spy(_G.setCvarSpy).was_called_with("Sound_EnableMusic", 0)

        -- 2. Toggle OFF → should restore volume AND mute state
        isActive = VS.Presets:TogglePreset(_G.VolumeSlidersMMDB.automation.presets[1], 1)
        assert.is_false(isActive)
        assert.are.equal(0.8, _G.cvarStorage["Sound_MusicVolume"])
        -- Should restore the original enable state
        assert.spy(_G.setCvarSpy).was_called_with("Sound_EnableMusic", "1")
    end)

    it("applies presets with expanded channel coverage", function()
        _G.cvarStorage["Sound_MasterVolume"] = 1.0
        _G.cvarStorage["Sound_SFXVolume"] = 1.0
        _G.cvarStorage["Sound_MusicVolume"] = 1.0
        _G.cvarStorage["Sound_AmbienceVolume"] = 1.0
        _G.cvarStorage["Sound_DialogVolume"] = 1.0
        _G.cvarStorage["Sound_EncounterWarningsVolume"] = 1.0
        _G.cvarStorage["Sound_GameplaySFX"] = 1.0
        _G.cvarStorage["Sound_PingVolume"] = 1.0

        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "All Channels",
                volumes = {
                    ["Sound_MasterVolume"] = 0.5,
                    ["Sound_SFXVolume"] = 0.4,
                    ["Sound_MusicVolume"] = 0.3,
                    ["Sound_AmbienceVolume"] = 0.2,
                    ["Sound_DialogVolume"] = 0.1,
                    ["Sound_EncounterWarningsVolume"] = 0.6,
                    ["Sound_GameplaySFX"] = 0.7,
                    ["Sound_PingVolume"] = 0.8
                },
                ignored = {}
            }
        }

        VS.Presets:ApplyPreset(_G.VolumeSlidersMMDB.automation.presets[1])

        assert.are.equal(0.5, _G.cvarStorage["Sound_MasterVolume"])
        assert.are.equal(0.4, _G.cvarStorage["Sound_SFXVolume"])
        assert.are.equal(0.3, _G.cvarStorage["Sound_MusicVolume"])
        assert.are.equal(0.2, _G.cvarStorage["Sound_AmbienceVolume"])
        assert.are.equal(0.1, _G.cvarStorage["Sound_DialogVolume"])
        assert.are.equal(0.6, _G.cvarStorage["Sound_EncounterWarningsVolume"])
        assert.are.equal(0.7, _G.cvarStorage["Sound_GameplaySFX"])
        assert.are.equal(0.8, _G.cvarStorage["Sound_PingVolume"])
    end)
end)
