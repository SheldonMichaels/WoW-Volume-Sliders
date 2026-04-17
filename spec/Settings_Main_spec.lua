-------------------------------------------------------------------------------
-- spec/Settings_Main_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Settings Main Module", function()
    local VS

    before_each(function()
        VS = {
            CreateSettingsContents = function() end,
            CreateMinimapSettingsContents = function() end,
            CreateSlidersSettingsContents = function() end,
            CreateWindowSettingsContents = function() end,
            CreateAutomationSettingsContents = function() end,
            CreateMouseActionsSettingsContents = function() end,
        }

        -- Load Settings_Main
        local f = assert(loadfile("VolumeSliders/Settings_Main.lua"))
        f("VolumeSliders", VS)

        -- Spy on the registered methods
        spy.on(VS, "CreateSettingsContents")
        spy.on(VS, "CreateMinimapSettingsContents")
        spy.on(VS, "CreateSlidersSettingsContents")
        spy.on(VS, "CreateWindowSettingsContents")
        spy.on(VS, "CreateAutomationSettingsContents")
        spy.on(VS, "CreateMouseActionsSettingsContents")
    end)

    it("InitializeSettings should register main and subcategories", function()
        VS:InitializeSettings()

        assert.spy(VS.CreateSettingsContents).was_called()
        assert.spy(VS.CreateMinimapSettingsContents).was_called()
        assert.spy(VS.CreateSlidersSettingsContents).was_called()
        assert.spy(VS.CreateWindowSettingsContents).was_called()
        assert.spy(VS.CreateAutomationSettingsContents).was_called()
        assert.spy(VS.CreateMouseActionsSettingsContents).was_called()
    end)

    it("should define the VOLUME_SLIDERS_COPY_URL popup", function()
        assert.is_table(_G.StaticPopupDialogs["VOLUME_SLIDERS_COPY_URL"])
    end)

    it("CreateSettingsContents should build the landing page UI", function()
        -- Reload to test actual function logic instead of spy
        local actualVS = {
            CreateSettingsContents = nil -- Use the one from the file
        }
        local f = assert(loadfile("VolumeSliders/Settings_Main.lua"))
        f("VolumeSliders", actualVS)

        local parent = CreateFrame("Frame")
        actualVS:CreateSettingsContents(parent)

        -- Verify UI components exist
        assert.is_not_nil(_G.VolumeSlidersSettingsScrollFrame)
        assert.is_not_nil(_G.VolumeSlidersSettingsContentFrame)
    end)
end)
