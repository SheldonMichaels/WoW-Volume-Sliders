local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("LFG Queue volume tests", function()
    local VS
    local mockLFGFrame

    before_each(function()
        -- Reset state
        _G.VolumeSlidersMMDB = {
            schemaVersion = 2,
            automation = {
                enableLfgVolume = true,
            },
            toggles = {}, channels = {}, layout = {}, voice = {}, minimap = {}, appearance = {}, hardware = {}
        }
        
        -- Mock CreateFrame
        mockLFGFrame = {
            scripts = {},
            Hide = function(self) end,
            SetScript = function(self, event, handler)
                self.scripts[event] = handler
            end,
            events = {},
            RegisterEvent = function(self, event) 
                self.events[event] = true
            end,
            UnregisterEvent = function(self, event)
                self.events[event] = false
            end,
            UnregisterAllEvents = function(self)
                self.events = {}
            end,
        }
        _G.CreateFrame = function() return mockLFGFrame end

        -- Mock CVars and Spy
        _G.cvarStorage = {
            ["Sound_MasterVolume"] = 0.5,
            ["Sound_SFXVolume"] = 0.5,
        }
        _G.GetCVar = function(name) return tostring(_G.cvarStorage[name] or 1) end
        
        _G.setCvarSpy = spy.new(function(name, val)
            _G.cvarStorage[name] = val
        end)
        _G.SetCVar = _G.setCvarSpy
        
        -- Mock LFG APIs
        _G.NUM_LE_LFG_CATEGORYS = 5
        _G.activeLFGCategory = nil
        _G.activeLFGProposal = false
        
        _G.GetLFGProposal = function()
            return _G.activeLFGProposal
        end
        
        _G.C_Timer = {
            After = function(delay, callback) 
                -- Just store the callback so we can manually invoke it in tests if needed
                _G.mockTimerCallback = callback
            end
        }

        _G.GetLFGQueueStats = function(category)
            if _G.activeLFGCategory == category then
                return true
            end
            return false
        end

        local addonName = "VolumeSliders"
        local addonTable = {
            Presets = {
                SetStateActive = spy.new(function() end),
                RefreshEventState = function() end
            }
        }
        
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        
        local lfgChunk = loadfile("VolumeSliders/LFGQueue.lua")
        lfgChunk(addonName, addonTable)

        VS = addonTable
        
        -- Initialize
        VS.LFGQueue:Initialize()
    end)

    it("does nothing if lfg volume is disabled", function()
        _G.VolumeSlidersMMDB.automation.enableLfgVolume = false
        VS.LFGQueue:Initialize()
        
        assert.is_false(mockLFGFrame.events["LFG_UPDATE"] == true)
        
        -- Trigger event even if disabled
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_UPDATE")
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_PROPOSAL_SHOW")
        
        assert.spy(VS.Presets.SetStateActive).was_not_called()
    end)
    
    it("registers proposal events only when actively queued", function()
        -- Initial state is not queued
        assert.is_false(mockLFGFrame.events["LFG_PROPOSAL_SHOW"] == true)
        
        -- Start queueing
        _G.activeLFGCategory = 1
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_UPDATE")
        
        assert.is_true(mockLFGFrame.events["LFG_PROPOSAL_SHOW"])
        
        -- Stop queueing
        _G.activeLFGCategory = nil
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_UPDATE")
        
        assert.is_false(mockLFGFrame.events["LFG_PROPOSAL_SHOW"] == true)
    end)
    
    it("toggles LFG state on Proposal Show and restores on conclusion", function()
        -- Queue pops
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_PROPOSAL_SHOW")
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "lfg", true)
        
        -- Proposal succeeds
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_PROPOSAL_SUCCEEDED")
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "lfg", false)
    end)
    
    it("toggles state off on LFG Proposal Failed", function()
        -- Queue pops
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_PROPOSAL_SHOW")
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "lfg", true)
        
        -- Proposal fails
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_PROPOSAL_FAILED")
        
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "lfg", false)
    end)

    it("should still trigger state if soundID might be a secret value (logic is now in Presets)", function()
        -- The check is now in Presets.lua which handles the PlaySound hook.
        -- LFGQueue.lua just listens for LFG_PROPOSAL_SHOW event which is not impacted.
        mockLFGFrame.scripts["OnEvent"](mockLFGFrame, "LFG_PROPOSAL_SHOW")
        assert.spy(VS.Presets.SetStateActive).was_called_with(VS.Presets, "lfg", true)
    end)
end)
