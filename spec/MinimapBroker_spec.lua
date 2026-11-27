-------------------------------------------------------------------------------
-- spec/MinimapBroker_spec.lua
-------------------------------------------------------------------------------

describe("MinimapBroker Module", function()
    local VS

    before_each(function()
        VS = {}
        _G.IsShiftKeyDown = function() return false end
        _G.IsControlKeyDown = function() return false end
        _G.IsAltKeyDown = function() return false end
        _G.SetCVar("Sound_MasterVolume", "1")
        _G.SetCVar("Sound_EnableAllSound", "1")

        local f1 = assert(loadfile("VolumeSliders/Core.lua"))
        f1("VolumeSliders", VS)

        _G.VolumeSlidersMMDB = {
            toggles = { showMinimapTooltip = true },
            appearance = { volumeDisplayFormat = "percentage" },
            minimap = {
                minimalistMinimap = true,
                bindToMinimap = true,
                mouseActions = {
                    {
                        trigger = VS.DEFAULT_DB.minimap.mouseActions[1].trigger,
                        effect = VS.DEFAULT_DB.minimap.mouseActions[1].effect,
                        stringTarget = VS.DEFAULT_DB.minimap.mouseActions[1].stringTarget,
                        numStep = VS.DEFAULT_DB.minimap.mouseActions[1].numStep,
                    }
                },
                minimapTooltipOrder = {},
            },
            automation = { persistedBaseline = {}, presets = {} },
        }

        -- Mock the GetVolumeText dependency which is usually in another file
        VS.GetVolumeText = function() return "50%" end
        VS.CreateOptionsFrame = function()
            VS.container = _G.CreateFrame("Frame")
            VS.container:Hide()
        end
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

    it("should hook OnMouseWheel on the display frame during OnTooltipShow", function()
        -- Create a mock display frame (the LDB text panel in e.g. ElvUI)
        local displayFrame = _G.CreateFrame("Frame")

        -- Verify no OnMouseWheel handler exists yet
        assert.is_nil(displayFrame:GetScript("OnMouseWheel"))

        -- Create a tooltip mock that reports the display frame as its owner
        local tooltip = _G.CreateFrame("GameTooltip")
        tooltip.GetOwner = function() return displayFrame end
        tooltip.AddLine = function() end

        -- Fire OnTooltipShow (simulating a hover over the LDB display)
        VS.VolumeSlidersObject.OnTooltipShow(tooltip)

        -- Verify that OnMouseWheel was hooked on the display frame
        assert.is_function(displayFrame:GetScript("OnMouseWheel"))
    end)

    it("should not double-hook OnMouseWheel when hovering multiple times", function()
        local displayFrame = _G.CreateFrame("Frame")
        local hookCount = 0

        -- Spy on HookScript to count calls
        local originalHookScript = displayFrame.HookScript
        displayFrame.HookScript = function(self, event, handler)
            if event == "OnMouseWheel" then
                hookCount = hookCount + 1
            end
            originalHookScript(self, event, handler)
        end

        local tooltip = _G.CreateFrame("GameTooltip")
        tooltip.GetOwner = function() return displayFrame end
        tooltip.AddLine = function() end

        -- Hover twice
        VS.VolumeSlidersObject.OnTooltipShow(tooltip)
        VS.VolumeSlidersObject.OnTooltipShow(tooltip)

        -- Should only have been hooked once
        assert.are.equal(1, hookCount)
    end)

    it("adjusts master volume when scrolling the hooked LDB display frame with default settings", function()
        local displayFrame = _G.CreateFrame("Frame")
        local tooltip = _G.CreateFrame("GameTooltip")
        tooltip.GetOwner = function() return displayFrame end
        tooltip.AddLine = function() end

        VS.VolumeSlidersObject.OnTooltipShow(tooltip)
        local onWheel = displayFrame:GetScript("OnMouseWheel")
        assert.is_function(onWheel)

        _G.SetCVar("Sound_MasterVolume", "0.5")
        onWheel(displayFrame, 1)
        assert.are.equal("0.55", _G.GetCVar("Sound_MasterVolume"))

        onWheel(displayFrame, -1)
        assert.are.equal("0.5", _G.GetCVar("Sound_MasterVolume"))
    end)

    it("adjusts master volume when scrolling the minimalist minimap button with default settings", function()
        VS:CreateMinimalistButton()
        local onWheel = VS.minimalistButton:GetScript("OnMouseWheel")
        assert.is_function(onWheel)

        _G.SetCVar("Sound_MasterVolume", "0.5")
        onWheel(VS.minimalistButton, 1)
        assert.are.equal("0.55", _G.GetCVar("Sound_MasterVolume"))

        onWheel(VS.minimalistButton, -1)
        assert.are.equal("0.5", _G.GetCVar("Sound_MasterVolume"))
    end)
end)
