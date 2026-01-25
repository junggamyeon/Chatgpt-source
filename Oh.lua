print("v4")
loadstring(game:HttpGet("https://raw.githubusercontent.com/junggamyeon/Chatgpt-source/refs/heads/main/check.lua"))()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local Config = getgenv().Config or {}
local MainAcc = tostring(Config["Main Account"] or "")

local StickerTypes = require(RS.Stickers.StickerTypes)
local LAST_CLICK = 0
local CLICK_COOLDOWN = 1.2

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

local function shouldAccept(btn)
    local ok, label = pcall(function()
        return btn:FindFirstChild("TextLabel", true)
    end)
    if ok and label and label.Text then
        return label.Text:lower() == "accept"
    end
    return true
end

local function smartClick(btn)
    if not btn then return false end
    if tick() - LAST_CLICK < CLICK_COOLDOWN then return false end
    if not shouldAccept(btn) then return false end

    LAST_CLICK = tick()

    if btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton") then
        if fireConnections(btn.Activated) then return true end
        if fireConnections(btn.MouseButton1Click) then return true end
    end

    pcall(function()
        btn:Activate()
    end)

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
        TargetImages[img] = name
    end
end


local function mainLoop()
    while true do
        local incoming = getIncomingFrame()
        if incoming then
            local acceptBtn = incoming:FindFirstChild("ButtonAccept", true)
            if acceptBtn then
                smartClick(acceptBtn)
            end

            task.wait(1)

            local anchor = getTradeAnchor()
            if anchor then
                while anchor.Parent do
                    local btn = getAcceptButton(anchor)
                    if btn then
                        smartClick(btn)
                    end
                    task.wait(0.5)
                end
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
            local guiImg = tostring(img.Image)
            if TargetImages[guiImg] then
                local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if btn then
                    smartClick(btn)
                    task.wait(0.3)
                end
            end
        end
    end

    while anchor.Parent do
        local btn = getAcceptButton(anchor)
        if btn then
            smartClick(btn)
        end
        task.wait(0.5)
    end

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-TradeStarSign")
    end)
end

-------------------------------------------------
-- START
-------------------------------------------------
task.spawn(function()
    if isMainAccount() then
        mainLoop()
    else
        altLoop()
    end
end)
