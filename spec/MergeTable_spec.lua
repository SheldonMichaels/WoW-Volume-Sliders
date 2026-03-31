-------------------------------------------------------------------------------
-- spec/MergeTable_spec.lua
-- Verifies the array-aware deep-merge fix in Init.lua.
-------------------------------------------------------------------------------

local function MergeTable(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            -- If the source value is an array, we treat it as an atomic list.
            -- We do not deep-merge arrays to prevent re-inserting deleted items 
            -- or re-shuffling user-defined orders.
            if v[1] ~= nil then
                if target[k] == nil then
                    target[k] = v -- Copy the entire default array
                end
            else
                -- Source is a dictionary (namespaces like 'layout' or 'appearance')
                if type(target[k]) ~= "table" then
                    target[k] = {}
                end
                MergeTable(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

describe("MergeTable Array-Aware Logic", function()
    it("should NOT append default items to a user's shorter array", function()
        local target = {
            layout = {
                sliderOrder = { "Master" } -- User only wants Master
            }
        }
        local source = {
            layout = {
                sliderOrder = { "Master", "SFX", "Music" } -- Default has many
            }
        }

        MergeTable(target, source)

        assert.are.equal(1, #target.layout.sliderOrder)
        assert.are.equal("Master", target.layout.sliderOrder[1])
        assert.is_nil(target.layout.sliderOrder[2])
    end)

    it("should correctly initialize a whole array if it is missing from the target", function()
        local target = {
            layout = {} -- missing sliderOrder
        }
        local source = {
            layout = {
                sliderOrder = { "Master", "SFX" }
            }
        }

        MergeTable(target, source)

        assert.is_table(target.layout.sliderOrder)
        assert.are.equal(2, #target.layout.sliderOrder)
        assert.are.equal("Master", target.layout.sliderOrder[1])
        assert.are.equal("SFX", target.layout.sliderOrder[2])
    end)

    it("should still deep-merge dictionaries correctly", function()
        local target = {
            appearance = {
                bgColor = { r = 1, g = 1, b = 1 } -- missing Alpha
            }
        }
        local source = {
            appearance = {
                bgColor = { r = 0, g = 0, b = 0, a = 0.5 },
                titleColor = "Gold"
            }
        }

        MergeTable(target, source)

        -- Dictionary keys should still merge
        assert.are.equal(1, target.appearance.bgColor.r) -- Target wins
        assert.are.equal(0.5, target.appearance.bgColor.a) -- Source fills in
        assert.are.equal("Gold", target.appearance.titleColor) -- Source fills in
    end)
    
    it("should handle empty tables in source correctly (treat as dictionaries)", function()
        -- Empty tables are treated as dictionaries because v[1] is nil.
        -- This is fine because there's nothing to merge into them anyway.
        local target = {
            layout = {
                sliderOrder = { "Master" }
            }
        }
        local source = {
            layout = {
                sliderOrder = {} -- empty default (theoretically)
            }
        }
        
        MergeTable(target, source)
        assert.are.equal(1, #target.layout.sliderOrder)
        assert.are.equal("Master", target.layout.sliderOrder[1])
    end)
end)
