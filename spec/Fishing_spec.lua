local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Fishing volume tests", function()
    local VS
    local mockFishingFrame

    before_each(function()
        -- Reset state
        _G.VolumeSlidersMMDB = {
            enableFishingVolume = true,
            enableFishingMaster = true,
            enableFishingSFX = true,
            fishingTargetMaster = 1.0,
            fishingTargetSFX = 1.0,
            originalVolumes = {},
        }
        
        -- Mock CreateFrame
        mockFishingFrame = {
            scripts = {},
            Hide = function(self) end,
            SetScript = function(self, event, handler)
                self.scripts[event] = handler
            end,
            RegisterEvent = function(self, event) end,
            UnregisterAllEvents = function(self) end,
        }
        _G.CreateFrame = function() return mockFishingFrame end

        -- Mock CVars and Spy
        _G.cvarStorage = {
            ["Sound_SFXVolume"] = 0.5,
        }
        _G.GetCVar = function(name) return tostring(_G.cvarStorage[name] or 1) end
        
        _G.setCvarSpy = spy.new(function(name, val)
            _G.cvarStorage[name] = val
        end)
        _G.SetCVar = _G.setCvarSpy

        -- Mock combat
        _G.affectingCombat = false
        _G.UnitAffectingCombat = function(unit) return _G.affectingCombat end

        -- Mock GetSpellInfo and C_Spell
        _G.GetSpellInfo = function(id)
            if id == 131474 then return "Fishing" end
            return "Unknown"
        end
        _G.C_Spell = {
            GetSpellInfo = function(id)
                if id == 131474 then return {name = "Fishing"} end
                if id == 1234 then return {name = "Not Fishing"} end
                return nil
            end
        }

        local addonName = "VolumeSliders"
        local addonTable = {}
        
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        
        local fishingChunk = loadfile("VolumeSliders/Fishing.lua")
        fishingChunk(addonName, addonTable)

        VS = addonTable
        
        -- Initialize
        VS.Fishing:Initialize()
    end)

    it("does nothing returning instantly if fishing volume is disabled", function()
        _G.VolumeSlidersMMDB.enableFishingVolume = false
        VS.Fishing:Initialize()
        
        -- Trigger event
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        
        assert.spy(_G.setCvarSpy).was_not_called()
    end)
    
    it("boosts volume on fishing cast and restores on stop", function()
        -- Start cast
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        
        assert.spy(_G.setCvarSpy).was_called_with("Sound_SFXVolume", 1.0)
        assert.are.equal(1.0, _G.cvarStorage["Sound_SFXVolume"])
        assert.are.equal(0.5, _G.VolumeSlidersMMDB.originalVolumes["Sound_SFXVolume"])
        
        -- Stop cast
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
        
        assert.spy(_G.setCvarSpy).was_called_with("Sound_SFXVolume", 0.5)
        assert.is_nil(_G.VolumeSlidersMMDB.originalVolumes["Sound_SFXVolume"])
    end)

    it("does not boost if in combat", function()
        _G.affectingCombat = true
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        assert.spy(_G.setCvarSpy).was_not_called()
    end)

    it("restores volume aggressively if combat starts", function()
        -- Start cast
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        assert.spy(_G.setCvarSpy).was_called_with("Sound_SFXVolume", 1.0)
        
        -- Combat starts
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "PLAYER_REGEN_DISABLED")
        
        assert.spy(_G.setCvarSpy).was_called_with("Sound_SFXVolume", 0.5)
        assert.is_nil(_G.VolumeSlidersMMDB.originalVolumes["Sound_SFXVolume"])
    end)

    it("ignores non-fishing spells", function()
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 1234)
        assert.spy(_G.setCvarSpy).was_not_called()
    end)
end)
