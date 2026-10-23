-- Flamethrower 服务端脚本
-- 战利品投放：把火焰喷射器与燃料罐加入军械库、枪店、消防局等容器的刷新列表。
-- 所有插入都做了空值保护，列表名在不同版本不存在时会被安全跳过。

local function insertIntoList(listName, item, chance)
    local ok, err = pcall(function()
        local list = ProceduralDistributions and ProceduralDistributions.list[listName]
        if list and list.items then
            table.insert(list.items, item)
            table.insert(list.items, chance)
        end
    end)
    return ok
end

local function addFlamethrowerLoot()
    -- 火焰喷射器本体（稀有）
    insertIntoList("ArmyStorageGuns",   "Flamethrower.Flamethrower", 1.5)
    insertIntoList("GunStoreGuns",      "Flamethrower.Flamethrower", 1.0)
    insertIntoList("FireStorageTools",  "Flamethrower.Flamethrower", 1.0)
    insertIntoList("GarageFirearms",    "Flamethrower.Flamethrower", 0.5)
    insertIntoList("SurvivalGear",      "Flamethrower.Flamethrower", 0.5)

    -- 燃料罐（相对常见）
    insertIntoList("ArmyStorageGuns",   "Flamethrower.FlameFuel", 8)
    insertIntoList("GunStoreGuns",      "Flamethrower.FlameFuel", 6)
    insertIntoList("FireStorageTools",  "Flamethrower.FlameFuel", 6)
    insertIntoList("GarageTools",       "Flamethrower.FlameFuel", 3)
    insertIntoList("ToolStoreMisc",     "Flamethrower.FlameFuel", 3)
    insertIntoList("SurvivalGear",      "Flamethrower.FlameFuel", 2)
end

Events.OnPreDistributionMerge.Add(addFlamethrowerLoot)
