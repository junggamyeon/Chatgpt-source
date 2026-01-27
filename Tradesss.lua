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

local DEBUG = true
local function dprint(...)
    if DEBUG then
        print("[ALT-DEBUG]", ...)
    end
end

-------------------------------------------------
-- UTILS
-------------------------------------------------
local function waitForPath(root, path, timeout)
    local cur = root
    local t0 = tick()
    for _, name in ipairs(path) do
        while cur and not cur:FindFirstChild(name) do
            if timeout and tick() - t0 > timeout then
                dprint("waitForPath TIMEOUT at", name)
                return nil
            end
            task.wait(0.1)
        end
        cur = cur:FindFirstChild(name)
    end
    dprint("waitForPath OK:", cur:GetFullName())
    return cur
end

local function fireConnections(signal)
    local ok, conns = pcall(function()
        return getconnections(signal)
    end)
    if not ok or not conns then
        dprint("getconnections FAILED")
        return false
    end
    for _, c in ipairs(conns) do
        if typeof(c.Function) == "function" then
            dprint("Firing connection")
            pcall(c.Function)
            return true
        end
    end
    dprint("No valid connections")
    return false
end

local function safeClick(btn)
    if not btn then
        dprint("safeClick: btn nil")
        return false
    end
    if not btn.Visible then
        dprint("safeClick: btn not visible", btn:GetFullName())
        return false
    end
    if not btn.Active then
        dprint("safeClick: btn not active", btn:GetFullName())
        return false
    end
    if tick() - LAST_CLICK < CLICK_DELAY then
        return false
    end

    LAST_CLICK = tick()
    dprint("Clicking:", btn:GetFullName())

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
        dprint("Accept label text:", label.Text)
        return label.Text:lower() == "accept"
    end
    return false
end

-------------------------------------------------
-- MAIN DETECT
-------------------------------------------------
local function normalize(str)
    return tostring(str):lower():gsub("%s+", "")
end

local MAIN_NORM = normalize(MAIN_ID)

local function isMainPlayer(p)
    if not p then return false end

    local uid = normalize(p.UserId)
    local name = normalize(p.Name)
    local dname = normalize(p.DisplayName)

    return uid == MAIN_NORM
        or name == MAIN_NORM
        or dname == MAIN_NORM
end

local function findMain()
    for _, p in ipairs(Players:GetPlayers()) do
        dprint("Checking:", p.Name, p.UserId, p.DisplayName)
        if isMainPlayer(p) then
            dprint("FOUND MAIN:", p.Name, p.UserId, p.DisplayName)
            return p
        end
    end
    dprint("Main not found in player list")
end

local function isMain()
    return isMainPlayer(LP)
end

-------------------------------------------------
-- STICKER MAP
-------------------------------------------------
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
        dprint("Target sticker:", name, "=>", img)
    else
        dprint("Sticker NOT FOUND in map:", name)
    end
end

-------------------------------------------------
-- BOOK COUNT
-------------------------------------------------
local function getStickerSlotCount()
    local ok, cache = pcall(function()
        return require(RS.ClientStatCache):Get()
    end)
    if not ok or not cache then
        dprint("ClientStatCache FAILED")
        return 0
    end

    local book = cache.Stickers and cache.Stickers.Book
    if type(book) ~= "table" then
        dprint("Sticker book missing")
        return 0
    end

    local maxIndex = 0
    for k in pairs(book) do
        local num = tonumber(k)
        if num and num > maxIndex then
            maxIndex = num
        end
    end

    dprint("Sticker slots:", maxIndex)
    return maxIndex
end

-------------------------------------------------
-- GUI
-------------------------------------------------
local function tradeLayer()
    local gui = LP.PlayerGui:FindFirstChild("ScreenGui")
    if not gui then
        dprint("ScreenGui not found")
        return
    end
    local layer = gui:FindFirstChild("TradeLayer")
    if not layer then
        dprint("TradeLayer not found")
    end
    return layer
end

local function tradeAnchor()
    local layer = tradeLayer()
    if not layer then return end
    local anchor = layer:FindFirstChild("TradeAnchorFrame", true)
    if anchor then
        dprint("TradeAnchor found")
    end
    return anchor
end

local function acceptButton(anchor)
    local ok, btn = pcall(function()
        return anchor.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok and btn then
        return btn
    end
    dprint("Accept button not found")
end

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------
local function mainLoop()
    while true do
        local layer = tradeLayer()
        if layer then
            local incoming = layer:FindFirstChild("IncomingTradeRequestFrame", true)
            if incoming then
                dprint("Incoming trade detected")
                local btn = incoming:FindFirstChild("ButtonAccept", true)
                if btn then
                    safeClick(btn)
                else
                    dprint("Incoming Accept button missing")
                end
            end
        end
        task.wait(0.25)
    end
end

-------------------------------------------------
-- ALT LOOP
-------------------------------------------------
local function altLoop()
    dprint("ALT LOOP START")

    local main
    repeat
        main = findMain()
        task.wait(1)
    until main

    local lastSend = 0

    repeat
        if tick() - lastSend >= 2 then
            lastSend = tick()
            dprint("Sending trade request to", main.UserId)
            pcall(function()
                RS.Events.TradePlayerRequestStart:FireServer(main.UserId)
            end)
        end
        task.wait(0.25)
    until tradeAnchor()

    local anchor = tradeAnchor()
    if not anchor then
        dprint("Anchor still nil, abort")
        return
    end

    local grid = waitForPath(anchor, {
        "TradeInventory",
        "InventoryFrame",
        "ScrollingFrame",
        "GuiGrid",
        "GridSlotStage"
    }, 10)

    if not grid then
        dprint("Grid NOT FOUND")
        return
    end

    dprint("Scanning slots:", #grid:GetChildren())

    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            local imageId = tostring(img.Image)
            dprint("Slot image:", imageId)

            if TargetImages[imageId] then
                dprint("MATCH -> adding sticker")
                local btn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if btn then
                    safeClick(btn)
                    task.wait(0.4)
                else
                    dprint("AddButton missing in slot")
                end
            end
        else
            dprint("Slot image not readable")
        end
    end

    local start = tick()
    while anchor.Parent do
        local btn = acceptButton(anchor)
        if btn then
            safeClick(btn)
        end
        if tick() - start > TRADE_TIMEOUT then
            dprint("Trade timeout")
            break
        end
        task.wait(0.25)
    end

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-TradeStarSign")
    end)

    dprint("ALT LOOP END")
end

-------------------------------------------------
-- START
-------------------------------------------------
task.spawn(function()
    if isMain() then
        mainLoop()
    else
        altLoop()
    end
end)
