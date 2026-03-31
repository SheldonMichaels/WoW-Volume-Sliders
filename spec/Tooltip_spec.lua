-------------------------------------------------------------------------------
-- spec/Tooltip_spec.lua
-- Tests tooltip action name resolution (getEffectName) in Core.lua.
-------------------------------------------------------------------------------

describe("Tooltip Action Resolution", function()
    local VS
    local mockTooltip

    before_each(function()
        -- Reset global state
        _G.VolumeSlidersMMDB = {
            minimap = {
                mouseActions = {}
            },
            layout = {
                mouseActions = {
                    sliders = {},
                    scrollWheel = {}
                }
            },
            automation = {
                presets = {
                    { name = "Test Preset" }
                }
            }
        }

        mockTooltip = {
            lines = {},
            AddLine = function(self, text)
                table.insert(self.lines, text)
            end
        }

        -- Load VS core
        local addonName = "VolumeSliders"
        local addonTable = {}
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        VS = addonTable
    end)

    it("should correctly resolve TOGGLE_WINDOW for minimap", function()
        _G.VolumeSlidersMMDB.minimap.mouseActions = {
            { trigger = "LeftButton", effect = "TOGGLE_WINDOW" }
        }
        VS:AppendActionTooltipLines(mockTooltip, "minimap")
        assert.are.equal("|cff00ff00LeftButton|r to Toggle Slider Window", mockTooltip.lines[1])
    end)

    it("should correctly resolve parameterized TOGGLE_PRESET for minimap", function()
        _G.VolumeSlidersMMDB.minimap.mouseActions = {
            { trigger = "Alt+LeftButton", effect = "TOGGLE_PRESET", stringTarget = "1" }
        }
        VS:AppendActionTooltipLines(mockTooltip, "minimap")
        assert.are.equal("|cff00ff00Alt+LeftButton|r to Toggle Preset: Test Preset", mockTooltip.lines[1])
    end)

    it("should correctly resolve ADJUST_5 for scroll wheel", function()
        _G.VolumeSlidersMMDB.layout.mouseActions.scrollWheel = {
            { trigger = "Scroll", effect = "ADJUST_5" }
        }
        VS:AppendActionTooltipLines(mockTooltip, "scrollWheel")
        assert.are.equal("|cff00ff00Scroll|r to Change by 5%", mockTooltip.lines[1])
    end)

    it("should correctly resolve ADJUST_10 for sliders", function()
        _G.VolumeSlidersMMDB.layout.mouseActions.sliders = {
            { trigger = "Ctrl+LeftButton", effect = "ADJUST_10" }
        }
        VS:AppendActionTooltipLines(mockTooltip, "sliders")
        assert.are.equal("|cff00ff00Ctrl+LeftButton|r to Change by 10%", mockTooltip.lines[1])
    end)

    it("should correctly resolve SCROLL_VOLUME for minimap", function()
        _G.VolumeSlidersMMDB.minimap.mouseActions = {
            { trigger = "Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_MusicVolume", numStep = 0.1 }
        }
        VS:AppendActionTooltipLines(mockTooltip, "minimap")
        assert.are.equal("|cff00ff00Scroll|r to Adjust Music (10%)", mockTooltip.lines[1])
    end)

    it("should return Unknown Action for unresolved effects", function()
        _G.VolumeSlidersMMDB.minimap.mouseActions = {
            { trigger = "Button4", effect = "NOT_A_REAL_EFFECT" }
        }
        VS:AppendActionTooltipLines(mockTooltip, "minimap")
        assert.are.equal("|cff00ff00Button4|r to Unknown Action", mockTooltip.lines[1])
    end)
end)
