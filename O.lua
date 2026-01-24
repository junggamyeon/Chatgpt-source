print("Auto Feed Script - Jung Split Version")
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Config = getgenv().Config or {}
local FeedConfig = Config["Auto Feed"] or {}

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local Cache = { data = nil, last = 0 }

local ITEM_KEYS = {
    MoonCharm = "MoonCharm",
    Pineapple = "Pineapple",
    Strawberry = "Strawberry",
    Blueberry = "Blueberry",
    SunflowerSeed = "SunflowerSeed",
    Bitterberry = "Bitterberry",
    Neonberry = "Neonberry",
    GingerbreadBear = "GingerbreadBear",
    Treat = "Treat"
}

local BOND_ITEMS = {
    { Name = "Neonberry", Value = 500 },
    { Name = "MoonCharm", Value = 250 },
    { Name = "GingerbreadBear", Value = 250 },
    { Name = "Bitterberry", Value = 100 },
    { Name = "Pineapple", Value = 50 },
    { Name = "Strawberry", Value = 50 },
    { Name = "Blueberry", Value = 50 },
    { Name = "SunflowerSeed", Value = 50 },
    { Name = "Treat", Value = 10 }
}

local function getCache()
    if tick() - Cache.last > 1 then
        local ok, res = pcall(function()
            return require(RS.ClientStatCache):Get()
        end)
        if ok then
            Cache.data = res
            Cache.last = tick()
        end
    end
    return Cache.data
end

local function getInventory()
    local cache = getCache()
    if not cache or not cache.Eggs then return {} end

    local inv = {}
    for name, key in pairs(ITEM_KEYS) do
        inv[name] = tonumber(cache.Eggs[key]) or 0
    end
    return inv
end

local function getBees()
    local cache = getCache()
    local bees = {}
    if not cache or not cache.Honeycomb then return bees end

    for cx, col in pairs(cache.Honeycomb) do
        for cy, bee in pairs(col) do
            if bee and bee.Lvl then
                local x = tonumber(tostring(cx):match("%d+"))
                local y = tonumber(tostring(cy):match("%d+"))
                if x and y then
                    table.insert(bees, {
                        col = x,
                        row = y,
                        level = bee.Lvl
                    })
                end
            end
        end
    end
    return bees
end

local function getBondLeft(col, row)
    local result
    pcall(function()
        result = Events.GetBondToLevel:InvokeServer(col, row)
    end)

    if type(result) == "number" then return result end
    if type(result) == "table" then
        for _, v in pairs(result) do
            if type(v) == "number" then return v end
        end
    end
end

local function buyTreat(amount)
    if not FeedConfig["Auto Buy Treat"] then return end

    local honey = Player.CoreStats.Honey.Value
    local cost = amount * 10000
    if honey < cost then return end

    Events.ItemPackageEvent:InvokeServer("Purchase", {
        Type = "Treat",
        Amount = amount,
        Category = "Eggs"
    })
end

local function feedBee(col, row, bondLeft)
    local remaining = bondLeft
    local inv = getInventory()

    for _, item in ipairs(BOND_ITEMS) do
        if remaining <= 0 then break end
        if FeedConfig["Bee Food"] and FeedConfig["Bee Food"][item.Name] then
            local have = inv[item.Name] or 0
            if have > 0 then
                local need = math.ceil(remaining / item.Value)
                local use = math.min(have, need)

                if use > 0 then
                    Events.ConstructHiveCellFromEgg:InvokeServer(
                        col,
                        row,
                        ITEM_KEYS[item.Name],
                        use,
                        false
                    )

                    remaining -= (use * item.Value)
                    task.wait(2)
                end
            end
        end
    end

    if remaining > 0 and FeedConfig["Auto Buy Treat"] then
        local needTreat = math.ceil(remaining / 10)
        buyTreat(needTreat)
    end
end

local function autoFeed()
    if not FeedConfig["Enable"] then return end

    local bees = getBees()
    if #bees == 0 then return end

    table.sort(bees, function(a, b)
        return a.level < b.level
    end)

    local maxCount = FeedConfig["Bee Amount"] or 7

    for i = 1, math.min(maxCount, #bees) do
        local b = bees[i]
        local bondLeft = getBondLeft(b.col, b.row)

        if bondLeft and bondLeft > 0 then
            feedBee(b.col, b.row, bondLeft)
            return
        end
    end
end

while true do
    autoFeed()
    task.wait(5)
end
