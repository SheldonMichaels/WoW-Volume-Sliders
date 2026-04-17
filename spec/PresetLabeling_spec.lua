local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Preset Labeling & Truncation Logic", function()
    local VS

    before_each(function()
        _G.VolumeSlidersMMDB = {
            automation = {
                presets = {}
            }
        }
        local addonName, addonTable = CreateAddonContext()
        loadfile("VolumeSliders/Core.lua")(addonName, addonTable)
        loadfile("VolumeSliders/Presets.lua")(addonName, addonTable)
        VS = addonTable

        -- Mock UI elements
        VS.presetDropdown = {
            GetWidth = function() return 200 end,
            Text = {
                SetText = function() end,
                GetStringWidth = function() return 50 end,
            },
            CreateFontString = function()
                return {
                    SetText = function(self, t) self.text = t end,
                    GetStringWidth = function(self)
                        -- Mock realistic widths: 5px per character for tests
                        return (self.text or ""):len() * 5
                    end,
                    Hide = function() end
                }
            end
        }
    end)

    it("returns 'Presets' when no presets are active", function()
        VS.session.activeRegistry = {}
        local text = VS.Presets:GetActivePresetsButtonText()
        assert.are.equal("Presets", text)
    end)

    it("returns the exact name when only one preset is active", function()
        VS.Presets:RegisterActivePreset("manual", 1, { name = "Fishing", volumes = {} })
        local text = VS.Presets:GetActivePresetsButtonText()
        assert.are.equal("Fishing", text)
    end)

    it("shows comma-separated names when they fit the width", function()
        -- 200px width - 26px padding = 174px maxWidth
        -- "Fishing, Questing" = 17 chars * 5px = 85px (Should fit)
        VS.Presets:RegisterActivePreset("manual", 1, { name = "Fishing", volumes = {} })
        VS.Presets:RegisterActivePreset("manual", 2, { name = "Questing", volumes = {} })

        local text = VS.Presets:GetActivePresetsButtonText()
        assert.are.equal("Fishing, Questing", text)
    end)

    it("returns a count when names exceed the width", function()
        -- 200px width - 26px padding = 174px maxWidth
        -- Force a very narrow button
        VS.presetDropdown.GetWidth = function() return 50 end
        -- 50px - 26px = 24px maxWidth.
        -- "Fishing, Questing" = 17 chars * 5px = 85px (Should NOT fit)

        VS.Presets:RegisterActivePreset("manual", 1, { name = "Fishing", volumes = {} })
        VS.Presets:RegisterActivePreset("manual", 2, { name = "Questing", volumes = {} })

        local text = VS.Presets:GetActivePresetsButtonText()
        assert.are.equal("2 Presets Active", text)
    end)

    it("caches the result until the registry changes", function()
        VS.Presets:RegisterActivePreset("manual", 1, { name = "Fishing", volumes = {} })
        VS.Presets:RegisterActivePreset("manual", 2, { name = "Questing", volumes = {} })

        local s = spy.on(table, "concat")

        -- First call: Rebuilds
        VS.Presets:GetActivePresetsButtonText()
        assert.spy(s).was_called(1)

        -- Second call: Cached
        VS.Presets:GetActivePresetsButtonText()
        assert.spy(s).was_called(1)

        -- Change registry
        VS.Presets:RegisterActivePreset("manual", 3, { name = "Dungeon", volumes = {} })
        VS.Presets:GetActivePresetsButtonText()
        assert.spy(s).was_called(2)

        s:revert()
    end)

    it("sorts names alphabetically for deterministic output", function()
        VS.Presets:RegisterActivePreset("manual", 1, { name = "Z", volumes = {} })
        VS.Presets:RegisterActivePreset("manual", 2, { name = "A", volumes = {} })

        local text = VS.Presets:GetActivePresetsButtonText()
        assert.are.equal("A, Z", text)
    end)
end)
