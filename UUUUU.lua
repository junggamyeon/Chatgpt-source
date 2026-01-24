print("AUTO TRADE STICKER SYSTEM")

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Events = RS:WaitForChild("Events")
local StickerTypes = require(RS.Stickers.StickerTypes)

local CONFIG = getgenv().Config or {}
local MAIN_CFG = tostring(CONFIG["Main Account"] or "")
local WANT = CONFIG["Sticker Trade"] or {}

local function waitForFind(root, name)
    while true do
        local obj = root:FindFirstChild(name, true)
        if obj then return obj end
        task.wait(0.3)
    end
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

local function isMainAccount(plr)
    if tostring(plr.UserId) == MAIN_CFG then return true end
    if plr.Name == MAIN_CFG then return true end
    if plr.DisplayName == MAIN_CFG then return true end
    return false
end

local function findMainPlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        if isMainAccount(p) then
            return p
        end
    end
end

local NameToImage = {}

local function scan(tbl)
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if v.Image and type(k) == "string" then
                NameToImage[k] = tostring(v.Image)
            end
            scan(v)
        end
    end
end

scan(StickerTypes)

local TARGET_IMAGES = {}
for _, name in ipairs(WANT) do
    local img = NameToImage[name]
    if img then
        TARGET_IMAGES[img] = name
        print("CONFIG OK:", name, "->", img)
    else
        warn("CONFIG NOT FOUND:", name)
    end
end

local function writeStatus(text)
    pcall(function()
        writefile(LP.Name .. ".txt", text)
    end)
end

local PlayerGui = LP:WaitForChild("PlayerGui")
local ScreenGui = waitForFind(PlayerGui, "ScreenGui")

local function waitIncoming()
    return waitForFind(ScreenGui, "IncomingTradeRequestFrame")
end

local function waitTradeAnchor()
    return waitForFind(ScreenGui, "TradeAnchorFrame")
end

local function getAcceptButton(anchor)
    local ok, btn = pcall(function()
        return anchor.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok then return btn end
end

local function autoAddStickers(anchor)
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
            local name = TARGET_IMAGES[guiImg]

            if name then
                print("ADD:", name)
                local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if btn and smartClick(btn) then
                    added += 1
                    task.wait(0.4)
                end
            end
        end
    end

    return added
end

task.spawn(function()
    if isMainAccount(LP) then
        print("MODE: MAIN")

        while true do
            local incoming = waitIncoming()
            local acceptBtn = incoming:FindFirstChild("ButtonAccept", true)
            if acceptBtn then
                smartClick(acceptBtn)
            end

            local anchor = waitTradeAnchor()
            print("TRADE OPEN")

            while anchor and anchor.Parent do
                local btn = getAcceptButton(anchor)
                if btn then
                    smartClick(btn)
                end
                task.wait(1)
            end

            print("TRADE CLOSED")
            task.wait(1)
        end
    else
        print("MODE: ALT")

        while true do
            local mainPlr = findMainPlayer()
            if not mainPlr then
                warn("MAIN NOT IN SERVER")
                task.wait(2)
            else
                print("SEND TRADE TO:", mainPlr.Name)

                pcall(function()
                    Events.TradePlayerRequestStart:FireServer(mainPlr.UserId)
                end)

                local anchor = waitTradeAnchor()
                print("TRADE OPEN")

                autoAddStickers(anchor)

                local btn = getAcceptButton(anchor)
                if btn then
                    smartClick(btn)
                end

                while anchor and anchor.Parent do
                    task.wait(1)
                end

                print("TRADE DONE")
                writeStatus("Completed-TradeStarSign")
                break
            end
        end
    end
end)
