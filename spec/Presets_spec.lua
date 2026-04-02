local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Registry-based Preset Logic (Unified State Stack)", function()
    local VS

    before_each(function()
        _G.VolumeSlidersMMDB = {
            schemaVersion = 3,
            automation = {
                enableTriggers = true,
                presets = {}
            },
            voice = {}
        }
        
        _G.zoneStates = { real = "Elwynn Forest", sub = "Goldshire", mini = "Lion's Pride Inn" }
        _G.GetRealZoneText = function() return _G.zoneStates.real end
        _G.GetSubZoneText = function() return _G.zoneStates.sub end
        _G.GetMinimapZoneText = function() return _G.zoneStates.mini end

        _G.cvarStorage = {
            ["Sound_MasterVolume"] = "1.0",
            ["Sound_EnableAllSound"] = "1",
        }
        _G.GetCVar = function(name) return _G.cvarStorage[name] or "1" end
        _G.setCvarSpy = spy.new(function(name, val) _G.cvarStorage[name] = tostring(val) end)
        _G.SetCVar = _G.setCvarSpy

        local addonName, addonTable = "VolumeSliders", {}
        loadfile("VolumeSliders/Core.lua")(addonName, addonTable)
        loadfile("VolumeSliders/Presets.lua")(addonName, addonTable)
        
        VS = addonTable
        
        -- Simulate Baseline Initialization (as done in Init.lua)
        VS.session.baselineVolumes["Sound_MasterVolume"] = 1.0
        VS.session.baselineMutes["Sound_MasterVolume"] = "1"
    end)

    it("layers automation over baseline successfully", function()
        _G.VolumeSlidersMMDB.automation.presets = {
            {
                name = "Zone Preset", priority = 10,
                zones = {"Elwynn Forest"},
                volumes = { ["Sound_MasterVolume"] = 0.5 },
                ignored = {}
            }
        }
        
        VS.Presets:RefreshEventState()
        
        -- Should have applied the preset volume
        assert.are.equal("0.5", _G.cvarStorage["Sound_MasterVolume"])
    end)

    it("respects priority: Manual Toggles override Automation", function()
        local zonePreset = {
            name = "Zone Low", priority = 10,
            zones = {"Elwynn Forest"},
            volumes = { ["Sound_MasterVolume"] = 0.5 },
            ignored = {}
        }
        local manualPreset = {
            name = "Manual High", priority = 1, -- Manual layer is hardcoded higher than auto
            volumes = { ["Sound_MasterVolume"] = 0.2 },
            ignored = {}
        }
        _G.VolumeSlidersMMDB.automation.presets = { zonePreset, manualPreset }
        
        -- 1. Zone matches
        VS.Presets:RefreshEventState()
        assert.are.equal("0.5", _G.cvarStorage["Sound_MasterVolume"])
        
        -- 2. Toggle Manual Preset (Layer 2)
        VS.Presets:TogglePreset(manualPreset, 2)
        assert.are.equal("0.2", _G.cvarStorage["Sound_MasterVolume"])
        
        -- 3. Untoggle Manual -> Falls back to Zone (Layer 1)
        VS.Presets:TogglePreset(manualPreset, 2)
        assert.are.equal("0.5", _G.cvarStorage["Sound_MasterVolume"])
    end)

    it("implements the Kill-Switch: Overrides clear when all presets deactivate", function()
        local preset = {
            name = "Test", priority = 10,
            zones = {"Elwynn Forest"},
            volumes = { ["Sound_MasterVolume"] = 0.5 },
            ignored = {}
        }
        _G.VolumeSlidersMMDB.automation.presets = { preset }
        
        -- 1. Preset is active
        VS.Presets:RefreshEventState()
        assert.are.equal("0.5", _G.cvarStorage["Sound_MasterVolume"])
        
        -- 2. User moves the slider manually -> Sets override
        VS:SyncBaseline("Sound_MasterVolume", 0.7)
        assert.is_true(VS.session.manualOverrides["Sound_MasterVolume"])
        -- Volume should be 0.7 (baseline) because of override
        assert.are.equal("0.7", _G.cvarStorage["Sound_MasterVolume"])
        
        -- 3. Leave the zone -> Registry becomes empty -> Kill-Switch fires
        _G.zoneStates.real = "Unknown"
        VS.Presets:RefreshEventState()
        
        -- Overrides should be wiped
        assert.is_nil(VS.session.manualOverrides["Sound_MasterVolume"])
        -- Volume should be 0.7 (the new baseline set in step 2)
        assert.are.equal("0.7", _G.cvarStorage["Sound_MasterVolume"])
    end)

    it("filters CVAR_UPDATE to prevent infinite loops", function()
        -- Simulate Blizzard UI changing a volume
        VS.session.isSettingInternal = false
        
        -- This should trigger SyncBaseline -> Evaluate -> SetCVar (with isSettingInternal = true)
        VS.Presets:RefreshEventState() -- Ensure something is active to test override
        
        local preset = { name = "P", priority = 1, zones = {"X"}, volumes = {["Sound_MasterVolume"] = 0.5} }
        VS.Presets:RegisterActivePreset("manual", 1, preset)
        
        -- Reset capture
        _G.setCvarSpy:clear()
        
        -- Simulate external CVar update
        VS:SyncBaseline("Sound_MasterVolume", 0.9)
        
        -- Evaluate should have run and called SetCVar with 0.9 (since override is now active)
        assert.spy(_G.setCvarSpy).was_called_with("Sound_MasterVolume", 0.9)
    end)
end)
