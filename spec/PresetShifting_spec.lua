-------------------------------------------------------------------------------
-- spec/PresetShifting_spec.lua
-- Verifies the automation index shifting logic in Settings.lua.
-------------------------------------------------------------------------------

describe("Preset Shifting Logic", function()
    local db = {
        automation = {
            fishingPresetIndex = nil,
            lfgPresetIndex = nil,
            presets = {}
        }
    }

    -- Local implementation of the logic from Settings.lua
    local function ShiftAutomationIndexes(deletedIndex, insertedIndex)
        local keys = {"fishingPresetIndex", "lfgPresetIndex"}
        for _, key in ipairs(keys) do
            local idx = db.automation[key]
            if idx then
                if idx == deletedIndex then
                    if insertedIndex then
                        db.automation[key] = insertedIndex
                    else
                        db.automation[key] = nil
                    end
                elseif not insertedIndex then
                    if idx > deletedIndex then
                        db.automation[key] = idx - 1
                    end
                else
                    if deletedIndex < insertedIndex then
                        if idx > deletedIndex and idx <= insertedIndex then
                            db.automation[key] = idx - 1
                        end
                    elseif deletedIndex > insertedIndex then
                        if idx >= insertedIndex and idx < deletedIndex then
                            db.automation[key] = idx + 1
                        end
                    end
                end
            end
        end
    end

    before_each(function()
        db.automation.fishingPresetIndex = 3
        db.automation.lfgPresetIndex = 5
    end)

    it("should shift downstream indexes during a PURE deletion", function()
        -- Delete index 1. Index 3 -> 2, Index 5 -> 4
        ShiftAutomationIndexes(1, nil)
        assert.are.equal(2, db.automation.fishingPresetIndex)
        assert.are.equal(4, db.automation.lfgPresetIndex)
    end)

    it("should CLEAR the pointer if the assigned preset is deleted", function()
        ShiftAutomationIndexes(3, nil)
        assert.is_nil(db.automation.fishingPresetIndex)
        assert.are.equal(4, db.automation.lfgPresetIndex) -- 5 shifted to 4
    end)

    it("should FOLLOW the preset during a REORDER (Move Down)", function()
        -- Move index 3 to index 5.
        -- Index 3 is now at 5. (Fishing)
        -- Index 5 is now at 4. (LFG)
        ShiftAutomationIndexes(3, 5)
        assert.are.equal(5, db.automation.fishingPresetIndex)
        assert.are.equal(4, db.automation.lfgPresetIndex)
    end)

    it("should FOLLOW the preset during a REORDER (Move Up)", function()
        -- Move index 5 to index 2.
        -- Index 3 is now at 4. (Fishing)
        -- Index 5 is now at 2. (LFG)
        ShiftAutomationIndexes(5, 2)
        assert.are.equal(4, db.automation.fishingPresetIndex)
        assert.are.equal(2, db.automation.lfgPresetIndex)
    end)
    
    it("should stay put if deletion occurs ABOVE the indexes", function()
        -- Delete index 6. 3 and 5 are unchanged.
        ShiftAutomationIndexes(6, nil)
        assert.are.equal(3, db.automation.fishingPresetIndex)
        assert.are.equal(5, db.automation.lfgPresetIndex)
    end)
end)
