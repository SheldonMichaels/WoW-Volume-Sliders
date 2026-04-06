-------------------------------------------------------------------------------
-- spec/Performance_spec.lua
-- Tests performance edge-cases like OnUpdate layout loops and dynamic yielding.
-------------------------------------------------------------------------------

describe("Performance & Event Overhead", function()
    local VS

    before_each(function()
        VS = {}
        _G.VolumeSlidersMMDB = { schemaVersion=4, minimap = { bindToMinimap = true, minimalistMinimap = true }, toggles={}, channels={}, layout={}, voice={}, appearance={}, hardware={}, automation={} }
        
        local f1 = assert(loadfile("VolumeSliders/Core.lua"))
        f1("VolumeSliders", VS)
        
        VS.GetVolumeText = function() return "50%" end
        VS.CreateOptionsFrame = function() VS.container = _G.CreateFrame("Frame") VS.container:Hide() end
        VS.SetScroll = function() end
        VS.Reposition = function() end
        VS.FlagLayoutDirty = function() end
        
        local f2 = assert(loadfile("VolumeSliders/MinimapBroker.lua"))
        f2("VolumeSliders", VS)
    end)

    it("should throttle HoverPolling_OnUpdate when mouse is far away", function()
        VS:CreateMinimalistButton()
        VS:StartHoverPolling()
        
        local onUpdate = VS.minimalistButton:GetScript("OnUpdate")
        assert.is_function(onUpdate, "OnUpdate should be registered")
        
        -- Override mock IsMouseOver to force "not hovering"
        VS.minimalistButton.IsMouseOver = function() return false end
        _G.Minimap.IsMouseOver = function() return false end
        
        -- Tick the engine forward. It should drop to the 0.5s slow poll rate.
        -- We can't inspect locals directly, but we can verify it doesn't crash 
        -- and the alpha sets to 0 correctly when off-target.
        onUpdate(VS.minimalistButton, 0.2)
        assert.are.equal(0, VS.minimalistButton:GetAlpha())
        
        -- The OnUpdate should unregister itself entirely when dropping alpha to 0
        assert.is_nil(VS.minimalistButton:GetScript("OnUpdate"))
    end)
end)
