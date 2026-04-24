-------------------------------------------------------------------------------
-- spec/Settings_Minimap_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Settings Minimap Module", function()
    local VS

    before_each(function()
        VS = {
            AddTooltip = function() end,
            UpdateMiniMapButtonVisibility = spy.new(function() end),
        }
        _G.VolumeSlidersMMDB = {
            minimap = {
                minimapIconLocked = true,
                minimalistMinimap = false,
                bindToMinimap = true,
                minimapTooltipOrder = {
                    { type = "OutputDevice" }
                }
            },
            toggles = { showMinimapTooltip = true }
        }

        -- Load dependencies
        local fCore = assert(loadfile("VolumeSliders/Core.lua"))
        fCore("VolumeSliders", VS)

        local fMinimap = assert(loadfile("VolumeSliders/Settings_Minimap.lua"))
        fMinimap("VolumeSliders", VS)
    end)

    it("CreateMinimapSettingsContents should initialize UI components", function()
        local parent = CreateFrame("Frame")
        VS:CreateMinimapSettingsContents(parent)

        assert.is_not_nil(_G.VSMinimapSettingsScrollFrame)
        assert.is_not_nil(_G.VSMinimapSettingsContentFrame)
    end)

    it("RefreshMinimapSettingsUI should execute without errors", function()
        local parent = CreateFrame("Frame")
        VS:CreateMinimapSettingsContents(parent)

        -- Should not crash even if ScrollBox logic is complex
        assert.has_no.errors(function()
            VS:RefreshMinimapSettingsUI()
        end)
    end)

    it("Reset Position button restores default minimalist offsets", function()
        local parent = CreateFrame("Frame")
        VS:CreateMinimapSettingsContents(parent)

        _G.VolumeSlidersMMDB.minimap.minimalistOffsetX = 123
        _G.VolumeSlidersMMDB.minimap.minimalistOffsetY = 456

        local resetBtn = _G.VolumeSlidersMinimapResetPositionButton
        assert.is_not_nil(resetBtn)
        resetBtn:GetScript("OnClick")(resetBtn)

        assert.are.equal(-35, _G.VolumeSlidersMMDB.minimap.minimalistOffsetX)
        assert.are.equal(-5, _G.VolumeSlidersMMDB.minimap.minimalistOffsetY)
    end)
end)
