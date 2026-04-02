local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Fishing volume tests", function()
    local VS
    local mockFishingFrame

    before_each(function()
        -- Reset state
        _G.VolumeSlidersMMDB = {
            schemaVersion = 3,
            automation = {
                enableFishingVolume = true,
            },
            toggles = {}, channels = {}, layout = {}, voice = {}, minimap = {}, appearance = {}, hardware = {}
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
        local addonTable = {
            Presets = {
                SetStateActive = spy.new(function() end),
                RefreshEventState = function() end
            }
        }
        
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        
        local fishingChunk = loadfile("VolumeSliders/Fishing.lua")
        fishingChunk(addonName, addonTable)

        VS = addonTable
        
        -- Initialize
        VS.Fishing:Initialize()
    end)

    it("does nothing returning instantly if fishing volume is disabled", function()
        _G.VolumeSlidersMMDB.automation.enableFishingVolume = false
        VS.Fishing:Initialize()
        
        -- Trigger event
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        
        assert.spy(VS.Presets.SetStateActive).was_not_called()
    end)
    
    it("toggles fishing state on cast and stop", function()
        -- Start cast
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "fishing", true)
        
        -- Stop cast
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "fishing", false)
    end)

    it("does not trigger state if in combat", function()
        _G.affectingCombat = true
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        assert.spy(VS.Presets.SetStateActive).was_not_called()
    end)

    it("clears state aggressively if combat starts", function()
        -- Start cast
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131474)
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "fishing", true)
        
        -- Combat starts
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "PLAYER_REGEN_DISABLED")
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "fishing", false)
    end)

    it("ignores non-fishing spells", function()
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 1234)
        assert.spy(VS.Presets.SetStateActive).was_not_called()
    end)

    it("handles Void Hole Fishing even if flagged as secret (engine comparison fallback)", function()
        local voidHoleID = 1224771
        local voidHoleName = "Void Hole Fishing"
        
        -- Mock spell info
        local oldGetSpellInfo = _G.C_Spell.GetSpellInfo
        _G.C_Spell.GetSpellInfo = function(id)
            if id == voidHoleID then return {name = voidHoleName} end
            return oldGetSpellInfo(id)
        end
        
        -- Trigger event
        mockFishingFrame.scripts["OnEvent"](mockFishingFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", voidHoleID)
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "fishing", true)
        
        -- Cleanup
        _G.C_Spell.GetSpellInfo = oldGetSpellInfo
    end)
end)
