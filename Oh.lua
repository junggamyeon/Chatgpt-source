loadstring(game:HttpGet("https://raw.githubusercontent.com/junggamyeon/Chatgpt-source/refs/heads/main/check.lua"))()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Config = getgenv().Config or {}
local MainAcc = tostring(Config["Main Account"] or "")

local StickerTypes = require(RS.Stickers.StickerTypes)

local function waitForPath(root, path)
    local cur = root
    for _, name in ipairs(path) do
        cur = cur:WaitForChild(name)
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

local function clickByEnter(obj)
    if not obj then return false end
    pcall(function()
        GuiService.SelectedObject = obj
        task.wait(0.05)
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        GuiService.SelectedObject = nil
    end)
    return true
end

local function clickByMouse(obj)
    if not obj then return false end
    local ok, pos = pcall(function()
        return obj.AbsolutePosition + (obj.AbsoluteSize / 2)
    end)
    if not ok then return false end
    VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    return true
end

local function smartClick(btn)
    if not btn then return false end
    if btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton") then
        if fireConnections(btn.Activated) then return true end
        if fireConnections(btn.MouseButton1Click) then return true end
    end
    if clickByEnter(btn) then return true end
    if clickByMouse(btn) then return true end
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
        print("CONFIG:", name, "->", img)
    else
        warn("CONFIG NOT FOUND:", name)
    end
end

local function getTradeLayer()
    return LP.PlayerGui:WaitForChild("ScreenGui"):WaitForChild("TradeLayer")
end

local function getTradeAnchor()
    local ok, anchor = pcall(function()
        return getTradeLayer():WaitForChild("TradeAnchorFrame")
    end)
    if ok then return anchor end
end

local function getAcceptButton(anchor)
    local ok, btn = pcall(function()
        return anchor.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok then return btn end
end

local function mainLoop()
    print("MODE: MAIN")
    local tradeLayer = getTradeLayer()

    while true do
        local incoming = tradeLayer:FindFirstChild("IncomingTradeRequestFrame", true)
        if incoming then
            local accept = incoming:FindFirstChild("ButtonAccept", true)
            if accept then
                smartClick(accept)
            end

            task.wait(2)

            local anchor = tradeLayer:FindFirstChild("TradeAnchorFrame", true)
            if anchor then
                while anchor.Parent do
                    local btn = getAcceptButton(anchor)
                    if btn and shouldAccept(btn) then
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
    print("MODE: ALT")

    local mainPlr
    repeat
        mainPlr = findMainPlayer()
        if not mainPlr then
            warn("ALT: Main not in server, waiting...")
            task.wait(2)
        end
    until mainPlr

    print("ALT: Found main:", mainPlr.Name, mainPlr.UserId)

    local lastSend = 0

    repeat
        if tick() - lastSend >= 2 then
            lastSend = tick()
            pcall(function()
                RS.Events.TradePlayerRequestStart:FireServer(mainPlr.UserId)
            end)
            print("ALT: Sent trade request")
        end
        task.wait(0.5)
    until getTradeAnchor()

    print("ALT: Trade opened")

    local anchor = getTradeAnchor()

    local grid = anchor
        :WaitForChild("TradeInventory")
        :WaitForChild("InventoryFrame")
        :WaitForChild("ScrollingFrame")
        :WaitForChild("GuiGrid")
        :WaitForChild("GridSlotStage")

    local added = 0

    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            local guiImg = tostring(img.Image)
            local name = TargetImages[guiImg]

            if name then
                local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if btn and smartClick(btn) then
                    added += 1
                    task.wait(0.3)
                end
            end
        end
    end

    print("ALT: Total added =", added)

    while anchor.Parent do
        local btn = getAcceptButton(anchor)
        if btn and shouldAccept(btn) then
            smartClick(btn)
        end
        task.wait(0.5)
    end

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-TradeStarSign")
    end)
end

task.spawn(function()
    if isMainAccount() then
        mainLoop()
    else
        altLoop()
    end
end)
