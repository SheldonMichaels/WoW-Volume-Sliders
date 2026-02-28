-------------------------------------------------------------------------------
-- spec/Core_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Core Module", function()
    local VS

    before_each(function()
        VS = {}
        -- Load the Core file exactly as WoW would (passing addonName and addonTable)
        local f = assert(loadfile("VolumeSliders/Core.lua"))
        f("VolumeSliders", VS)
    end)

    it("should instantiate LibDataBroker and LibDBIcon", function()
        assert.is_table(VS.LDB)
        assert.is_table(VS.LDBIcon)
    end)

    it("should define constant configuration values", function()
        assert.is_number(VS.FRAME_HEIGHT)
        assert.is_number(VS.SLIDER_COLUMN_WIDTH)
    end)
end)
