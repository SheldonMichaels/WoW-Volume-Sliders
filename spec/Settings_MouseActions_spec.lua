-------------------------------------------------------------------------------
-- spec/Settings_MouseActions_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Settings MouseActions Module", function()
    local VS

    before_each(function()
        VS = {
            AddTooltip = function() end,
            RefreshMouseActionsUI = function() end, -- Will be overwritten by module
        }
        _G.VolumeSlidersMMDB = {
            layout = {
                mouseActions = {
                    sliders = {
                        { trigger = "LeftButton", effect = "ADJUST_5" }
                    },
                    scrollWheel = {
                        { trigger = "None", effect = "ADJUST_1" }
                    }
                }
            },
            minimap = {
                mouseActions = {
                    { trigger = "LeftButton", effect = "TOGGLE_WINDOW" }
                }
            },
            automation = {
                presets = {
                    { name = "Test Preset" }
                }
            }
        }

        -- Load dependencies
        local fCore = assert(loadfile("VolumeSliders/Core.lua"))
        fCore("VolumeSliders", VS)

        local fMouse = assert(loadfile("VolumeSliders/Settings_MouseActions.lua"))
        fMouse("VolumeSliders", VS)
    end)

    it("CreateMouseActionsSettingsContents should initialize UI components", function()
        local parent = CreateFrame("Frame")
        VS:CreateMouseActionsSettingsContents(parent)

        assert.is_not_nil(_G.VSMouseActionsSettingsScrollFrame)
        assert.is_not_nil(_G.VSMouseActionsSettingsContentFrame)
    end)

    it("RefreshMouseActionsUI should update dropdown default text", function()
        local parent = CreateFrame("Frame")
        VS:CreateMouseActionsSettingsContents(parent)

        -- In our module, RefreshMouseActionsUI is set on VS
        assert.is_not_nil(VS.RefreshMouseActionsUI)

        -- Trigger refresh (already called at end of Init)
        VS.RefreshMouseActionsUI()
        assert.are.equal("ADJUST_5", _G.VolumeSlidersMMDB.layout.mouseActions.sliders[1].effect)
        assert.are.equal("TOGGLE_WINDOW", _G.VolumeSlidersMMDB.minimap.mouseActions[1].effect)
    end)

    it("RefreshMouseActionsUI is idempotent for existing bindings", function()
        local parent = CreateFrame("Frame")
        VS:CreateMouseActionsSettingsContents(parent)

        VS.RefreshMouseActionsUI()
        VS.RefreshMouseActionsUI()

        assert.are.equal(1, #_G.VolumeSlidersMMDB.layout.mouseActions.sliders)
        assert.are.equal(1, #_G.VolumeSlidersMMDB.layout.mouseActions.scrollWheel)
        assert.are.equal(1, #_G.VolumeSlidersMMDB.minimap.mouseActions)
    end)
end)
