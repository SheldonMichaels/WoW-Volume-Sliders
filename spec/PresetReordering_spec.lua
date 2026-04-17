-------------------------------------------------------------------------------
-- spec/PresetReordering_spec.lua
-- Tests automation pointer (fishing/lfg) synchronization during preset reordering.
-------------------------------------------------------------------------------

describe("Preset Reordering Synchronization", function()
    local db
    local ShiftAutomationIndexes
    local SwapPresets

    before_each(function()
        db = {
            automation = {
                fishingPresetIndex = 2,
                lfgPresetIndex = 3,
                presets = {
                    { name = "Preset 1" },
                    { name = "Preset 2" },
                    { name = "Preset 3" },
                    { name = "Preset 4" },
                    { name = "Preset 5" }
                }
            }
        }

        -- Mock the functions from Settings.lua
        -- We'll use the logic we just implemented

        ShiftAutomationIndexes = function(deletedIndex, insertedIndex)
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

        SwapPresets = function(idxA, idxB)
            local keys = {"fishingPresetIndex", "lfgPresetIndex"}
            for _, key in ipairs(keys) do
                if db.automation[key] == idxA then
                    db.automation[key] = idxB
                elseif db.automation[key] == idxB then
                    db.automation[key] = idxA
                end
            end
            local temp = db.automation.presets[idxA]
            db.automation.presets[idxA] = db.automation.presets[idxB]
            db.automation.presets[idxB] = temp
        end
    end)

    it("should swap pointers when moving a preset up", function()
        -- Move Preset 2 (index 2) to index 1 (Up)
        -- Fishing is at 2
        SwapPresets(2, 1)
        assert.are.equal(1, db.automation.fishingPresetIndex)
        assert.are.equal(3, db.automation.lfgPresetIndex) -- Unchanged
    end)

    it("should swap pointers when moving a preset down", function()
        -- Move Preset 3 (index 3) to index 4 (Down)
        -- LFG is at 3
        SwapPresets(3, 4)
        assert.are.equal(4, db.automation.lfgPresetIndex)
        assert.are.equal(2, db.automation.fishingPresetIndex) -- Unchanged
    end)

    it("should shift pointers correctly during a List Order change (Move Forward)", function()
        -- Move Preset 2 (index 2) to position 4
        -- Shifts: #2 -> 4, #3 -> 2, #4 -> 3
        -- Fishing is at 2, LFG is at 3
        ShiftAutomationIndexes(2, 4)
        assert.are.equal(4, db.automation.fishingPresetIndex)
        assert.are.equal(2, db.automation.lfgPresetIndex)
    end)

    it("should shift pointers correctly during a List Order change (Move Backward)", function()
        -- Move Preset 4 (index 4) to position 2
        -- Shifts: #4 -> 2, #2 -> 3, #3 -> 4
        -- Fishing is at 2 (now 3), LFG is at 3 (now 4)
        ShiftAutomationIndexes(4, 2)
        assert.are.equal(4, db.automation.lfgPresetIndex)
        -- No, let's re-read the code.
        -- fishing was 2. lfg was 3.
        -- We move 4 to 2.
        -- ShiftAutomationIndexes(4, 2): deletedIndex=4, insertedIndex=2.
        -- idx=2: idx >= 2 and idx < 4? Yes. 2 becomes 3. (Fishing)
        -- idx=3: idx >= 2 and idx < 4? Yes. 3 becomes 4. (LFG)
        -- idx=4: idx == 4? Yes. Assigned to insertedIndex (2).
    end)

    it("should verify correct values after Move Backward", function()
        -- Start: Fish at 2, LFG at 3. Move 4 to 2.
        ShiftAutomationIndexes(4, 2)
        -- LFG (3) should be 4.
        -- Fish (2) should be 3.
        -- The item that was at 4 is now at 2.
        assert.are.equal(4, db.automation.lfgPresetIndex)
        assert.are.equal(3, db.automation.fishingPresetIndex)
    end)
end)
