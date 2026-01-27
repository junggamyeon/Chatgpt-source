loadstring(game:HttpGet("https://raw.githubusercontent.com/junggamyeon/Chatgpt-source/refs/heads/main/check.lua"))()
print("v1")
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Config = getgenv().Config or {}

local MainAcc = tostring(Config["Main Account"] or "")
local CHANGE_MAIN_AT = tonumber(Config["Change Acc Main When Has Sticker"] or 0)

local LAST_CLICK = 0
local WROTE_MAIN_FILE = false
local TRADE_OPEN = false

local function smartClick(btn)
    if not btn then return false end
    if not btn.Visible then return false end
    if not btn.Active then return false end
    if tick() - LAST_CLICK < 0.3 then return false end

    LAST_CLICK = tick()

    local absPos = btn.AbsolutePosition
    local absSize = btn.AbsoluteSize

    local x = absPos.X + absSize.X / 2
    local y = absPos.Y + absSize.Y / 2

    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)

    return true
end

local function isMainAccount()
    if tostring(LP.UserId) == MainAcc then return true end
    if LP.Name == MainAcc then return true end
    if LP.DisplayName == MainAcc then return true end
    return false
end

local function findMainPlayer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if tostring(plr.UserId) == MainAcc then return plr end
        if plr.Name == MainAcc then return plr end
        if plr.DisplayName == MainAcc then return plr end
    end
end

local function getTradeLayer()
    return LP.PlayerGui
        :WaitForChild("ScreenGui")
        :WaitForChild("TradeLayer")
end

local function getTradeAnchor()
    local layer = getTradeLayer()
    return layer:FindFirstChild("TradeAnchorFrame", true)
end

local function getIncomingFrame()
    local layer = getTradeLayer()
    return layer:FindFirstChild("IncomingTradeRequestFrame", true)
end

local function getAcceptButton(anchor)
    local ok, btn = pcall(function()
        return anchor.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok then return btn end
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

task.spawn(function()
    while true do
        task.wait(10)
        if TRADE_OPEN and not getTradeAnchor() then
            LAST_CLICK = 0
            TRADE_OPEN = false
        end
    end
end)

local function mainLoop()
    while true do
        checkMainStickerCount()

        local incoming = getIncomingFrame()
        if incoming then
            local acceptBtn = incoming:FindFirstChild("ButtonAccept", true)
            if acceptBtn then
                smartClick(acceptBtn)
            end

            task.wait(1)

            local anchor = getTradeAnchor()
            if anchor then
                TRADE_OPEN = true
                while anchor.Parent do
                    local btn = getAcceptButton(anchor)
                    if btn then
                        smartClick(btn)
                    end
                    task.wait(0.4)
                end
                TRADE_OPEN = false
                LAST_CLICK = 0
            end
        end

        task.wait(0.5)
    end
end

local function altLoop()
    local mainPlr
    repeat
        mainPlr = findMainPlayer()
        task.wait(2)
    until mainPlr

    local lastSend = 0

    repeat
        if tick() - lastSend >= 2 then
            lastSend = tick()
            pcall(function()
                RS.Events.TradePlayerRequestStart:FireServer(mainPlr.UserId)
            end)
        end
        task.wait(0.3)
    until getTradeAnchor()

    local anchor = getTradeAnchor()
    if not anchor then return end

    local grid = anchor
        :WaitForChild("TradeInventory")
        :WaitForChild("InventoryFrame")
        :WaitForChild("ScrollingFrame")
        :WaitForChild("GuiGrid")
        :WaitForChild("GridSlotStage")

    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
            if btn then
                smartClick(btn)
                task.wait(0.25)
            end
        end
    end

    while anchor.Parent do
        local btn = getAcceptButton(anchor)
        if btn then
            smartClick(btn)
        end
        task.wait(0.4)
    end

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-Trade")
    end)
end

task.spawn(function()
    if isMainAccount() then
        mainLoop()
    else
        altLoop()
    end
end)
