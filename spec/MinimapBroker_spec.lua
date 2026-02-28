-------------------------------------------------------------------------------
-- spec/MinimapBroker_spec.lua
-------------------------------------------------------------------------------

describe("MinimapBroker Module", function()
    local VS

    before_each(function()
        VS = {}
        local f1 = assert(loadfile("VolumeSliders/Core.lua"))
        f1("VolumeSliders", VS)
        
        -- Mock the GetVolumeText dependency which is usually in another file
        VS.GetVolumeText = function() return "50%" end
        VS.VolumeSliders_ToggleMute = function()
            local current = _G.GetCVar("Sound_EnableAllSound")
            _G.SetCVar("Sound_EnableAllSound", current == "1" and "0" or "1")
        end
        VS.CreateOptionsFrame = function() 
            VS.container = _G.CreateFrame("Frame") 
            VS.container:Hide()
        end
        VS.SetScroll = function() end
        VS.Reposition = function() end
        
        local f2 = assert(loadfile("VolumeSliders/MinimapBroker.lua"))
        f2("VolumeSliders", VS)
    end)

    it("should register an LDB data object", function()
        assert.is_table(VS.VolumeSlidersObject)
        assert.are.equal("launcher", VS.VolumeSlidersObject.type)
        assert.are.equal("50%", VS.VolumeSlidersObject.text)
    end)

    it("should handle icon RightClick to toggle mute", function()
        _G.SetCVar("Sound_EnableAllSound", "1")
        
        -- Fire the right click wrapper on brokerObj
        VS.VolumeSlidersObject.OnClick(nil, "RightButton")
        
        assert.are.equal("0", _G.GetCVar("Sound_EnableAllSound"))
        
        -- Fire again
        VS.VolumeSlidersObject.OnClick(nil, "RightButton")
        assert.are.equal("1", _G.GetCVar("Sound_EnableAllSound"))
    end)
    
    it("should toggle the options frame on LeftClick", function()
        -- Click 1: create and show
        VS.VolumeSlidersObject.OnClick(nil, "LeftButton")
        assert.is_table(VS.container)
        assert.is_true(VS.container:IsShown())
        
        -- Click 2: hide
        VS.VolumeSlidersObject.OnClick(nil, "LeftButton")
        assert.is_false(VS.container:IsShown())
    end)
end)
