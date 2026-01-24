

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local StickerTypes = require(RS.Stickers.StickerTypes)
local TradeEvent = RS.Events.TradePlayerRequestStart

------------------------------------------------
-- UTILS
------------------------------------------------
local function fireConnections(signal)
    local ok, conns = pcall(function()
        return getconnections(signal)
    end)
    if not ok or not conns then return false end
    local fired = false
    for _, c in ipairs(conns) do
        if typeof(c.Function) == "function" then
            pcall(c.Function)
            fired = true
        end
    end
    return fired
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
    if btn:IsA("GuiButton") then
        if fireConnections(btn.Activated) then return true end
        if fireConnections(btn.MouseButton1Click) then return true end
    end
    if clickByEnter(btn) then return true end
    return clickByMouse(btn)
end

local function waitForPath(root, path)
    local cur = root
    for _, p in ipairs(path) do
        cur = cur:WaitForChild(p)
    end
    return cur
end

------------------------------------------------
-- FIND MAIN
------------------------------------------------
local function findMain()
    local target = tostring(getgenv().Config["Main Account"])
    for _, plr in ipairs(Players:GetPlayers()) do
        if tostring(plr.UserId) == target then return plr end
        if plr.Name == target then return plr end
        if plr.DisplayName == target then return plr end
    end
end

local isMain = false
do
    local me = LP
    local t = tostring(getgenv().Config["Main Account"])
    if tostring(me.UserId) == t or me.Name == t or me.DisplayName == t then
        isMain = true
    end
end

------------------------------------------------
-- STICKER IMAGE MAP
------------------------------------------------
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

task.wait(2)
scan(StickerTypes)

local TargetImages = {}
for _, name in ipairs(getgenv().Config["Sticker Trade"] or {}) do
    local img = NameToImage[name]
    if img then
        TargetImages[img] = name
        print("CONFIG:", name, "->", img)
    else
        warn("CONFIG NOT FOUND:", name)
    end
end

------------------------------------------------
-- GUI PATHS
------------------------------------------------
local function getTradeLayer()
    return LP.PlayerGui:WaitForChild("ScreenGui"):WaitForChild("TradeLayer")
end

local function getTradeAnchor()
    local tl = getTradeLayer()
    return tl:FindFirstChild("TradeAnchorFrame")
end

local function getAcceptButton(anchor)
    local ok, btn = pcall(function()
        return anchor.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok then return btn end
end

------------------------------------------------
-- MAIN LOGIC
------------------------------------------------
if isMain then
    print("MODE: MAIN")

    while true do
        local tradeLayer = getTradeLayer()
        local incoming = tradeLayer:WaitForChild("IncomingTradeRequestFrame")
        local accept = incoming:WaitForChild("ButtonAccept", true)

        smartClick(accept)
        print("MAIN ACCEPTED REQUEST")

        repeat task.wait(0.5) until getTradeAnchor()
        local anchor = getTradeAnchor()

        while anchor and anchor.Parent do
            local btn = getAcceptButton(anchor)
            if btn then
                smartClick(btn)
                print("MAIN TRADE ACCEPT")
            end
            task.wait(1)
            anchor = getTradeAnchor()
        end

        print("TRADE CLOSED, WAITING AGAIN")
        task.wait(1)
    end

------------------------------------------------
-- ALT LOGIC
------------------------------------------------
else
    print("MODE: ALT")

    local mainPlr
    repeat
        mainPlr = findMain()
        if not mainPlr then
            warn("MAIN NOT FOUND")
            task.wait(2)
        end
    until mainPlr

    print("FOUND MAIN:", mainPlr.Name, mainPlr.UserId)

    TradeEvent:FireServer(mainPlr.UserId)
    print("TRADE SENT")

    repeat task.wait(0.5) until getTradeAnchor()
    local anchor = getTradeAnchor()

    local grid = waitForPath(anchor, {
        "TradeInventory",
        "InventoryFrame",
        "ScrollingFrame",
        "GuiGrid",
        "GridSlotStage"
    })

    local Clicked = {}

    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            local guiImg = tostring(img.Image)
            if TargetImages[guiImg] and not Clicked[slot] then
                local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if btn then
                    smartClick(btn)
                    Clicked[slot] = true
                    print("ADDED:", TargetImages[guiImg])
                    task.wait(0.4)
                end
            end
        end
    end

    local btn = getAcceptButton(anchor)
    if btn then
        smartClick(btn)
        print("ALT ACCEPTED TRADE")
    end

    repeat task.wait(0.5) until not getTradeAnchor()

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-TradeStarSign")
    end)

    print("DONE")
end
