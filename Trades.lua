repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
local Config = getgenv().Config or {}
local MAIN_ID = tostring(Config["Main Account"] or "")
local CHANGE_MAIN_AT = tonumber(Config["Change Acc Main When Has Sticker"] or 0)

local StickerTypes = require(RS.Stickers.StickerTypes)

local CLICK_DELAY = 0.75
local TRADE_TIMEOUT = 30

local LAST_CLICK = 0
local TRADE_OPEN = false
local WROTE_MAIN_FILE = false

local function waitForPath(root, path, timeout)
    local cur = root
    local t0 = tick()
    for _, name in ipairs(path) do
        while cur and not cur:FindFirstChild(name) do
            if timeout and tick() - t0 > timeout then
                return nil
            end
            task.wait(0.1)
        end
        cur = cur:FindFirstChild(name)
    end
    return cur
end

local function fireConnections(signal)
    local ok, conns = pcall(function()
        return getconnections(signal)
    end)
    if not ok or not conns then return false end
    for _, c in ipairs(conns) do
        if typeof(c.Function) == "function" then
            pcall(c.Function)
            return true
        end
    end
    return false
end

local function safeClick(btn)
    if not btn then return false end
    if not btn.Visible or not btn.Active then return false end
    if tick() - LAST_CLICK < CLICK_DELAY then return false end

    LAST_CLICK = tick()

    if btn:IsA("GuiButton") then
        if fireConnections(btn.Activated) then return true end
        if fireConnections(btn.MouseButton1Click) then return true end
        pcall(function()
            btn:Activate()
        end)
        return true
    end
    return false
end

local function shouldAccept(btn)
    local label = btn:FindFirstChild("TextLabel", true)
    if label and label.Text then
        return label.Text:lower() == "accept"
    end
    return false
end

local function isMain()
    if tostring(LP.UserId) == MAIN_ID then return true end
    if LP.Name == MAIN_ID then return true end
    if LP.DisplayName == MAIN_ID then return true end
    return false
end

local function findMain()
    for _, p in ipairs(Players:GetPlayers()) do
        if tostring(p.UserId) == MAIN_ID then return p end
        if p.Name == MAIN_ID then return p end
        if p.DisplayName == MAIN_ID then return p end
    end
end

local NameToImage = {}

local function scan(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            if v.Image and type(k) == "string" then
                NameToImage[k] = tostring(v.Image)
            end
            scan(v)
        end
    end
end

scan(StickerTypes)

local TargetImages = {}
for _, name in ipairs(Config["Sticker Trade"] or {}) do
    local img = NameToImage[name]
    if img then
        TargetImages[img] = true
    end
end

local function getStickerSlotCount()
    local ok, cache = pcall(function()
        return require(RS.ClientStatCache):Get()
    end)
    if not ok or not cache then return 0 end

    local book = cache.Stickers and cache.Stickers.Book
    if type(book) ~= "table" then return 0 end

    local maxIndex = 0
    for k in pairs(book) do
        local num = tonumber(k)
        if num and num > maxIndex then
            maxIndex = num
        end
    end

    return maxIndex
end

local function checkMainStickerCount()
    if CHANGE_MAIN_AT <= 0 then return end
    if WROTE_MAIN_FILE then return end

    local total = getStickerSlotCount()
    if total >= CHANGE_MAIN_AT then
        WROTE_MAIN_FILE = true
        pcall(function()
            writefile(LP.Name .. ".txt", "Completed-MainAutoTrade")
        end)
    end
end

local function tradeLayer()
    return LP.PlayerGui:FindFirstChild("ScreenGui")
        and LP.PlayerGui.ScreenGui:FindFirstChild("TradeLayer")
end

local function tradeAnchor()
    local layer = tradeLayer()
    if not layer then return end
    return layer:FindFirstChild("TradeAnchorFrame", true)
end

local function acceptButton(anchor)
    local ok, btn = pcall(function()
        return anchor.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok then return btn end
end

task.spawn(function()
    while true do
        task.wait(5)
        if TRADE_OPEN and not tradeAnchor() then
            LAST_CLICK = 0
            TRADE_OPEN = false
        end
    end
end)

local function mainLoop()
    while true do
        checkMainStickerCount()

        local layer = tradeLayer()
        if layer then
            local incoming = layer:FindFirstChild("IncomingTradeRequestFrame", true)

            if incoming then
                local btn = incoming:FindFirstChild("ButtonAccept", true)
                if btn then
                    safeClick(btn)
                end
            end

            local anchor = tradeAnchor()
            if anchor then
                TRADE_OPEN = true
                local start = tick()

                while anchor.Parent do
                    local btn = acceptButton(anchor)
                    if btn and shouldAccept(btn) then
                        safeClick(btn)
                    end

                    if tick() - start > TRADE_TIMEOUT then
                        break
                    end
                    task.wait(0.25)
                end

                TRADE_OPEN = false
                LAST_CLICK = 0
            end
        end

        task.wait(0.25)
    end
end

local function altLoop()
    local main
    repeat
        main = findMain()
        task.wait(1)
    until main

    local lastSend = 0

    repeat
        if tick() - lastSend >= 2 then
            lastSend = tick()
            pcall(function()
                RS.Events.TradePlayerRequestStart:FireServer(main.UserId)
            end)
        end
        task.wait(0.25)
    until tradeAnchor()

    local anchor = tradeAnchor()
    if not anchor then return end

    local grid = waitForPath(anchor, {
        "TradeInventory",
        "InventoryFrame",
        "ScrollingFrame",
        "GuiGrid",
        "GridSlotStage"
    }, 10)

    if not grid then return end

    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            if TargetImages[tostring(img.Image)] then
                local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if btn then
                    safeClick(btn)
                    task.wait(0.4)
                end
            end
        end
    end

    local start = tick()
    while anchor.Parent do
        local btn = acceptButton(anchor)
        if btn and shouldAccept(btn) then
            safeClick(btn)
        end

        if tick() - start > TRADE_TIMEOUT then
            break
        end
        task.wait(0.25)
    end

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-TradeStarSign")
    end)
end

task.spawn(function()
    if isMain() then
        mainLoop()
    else
        altLoop()
    end
end)
