getgenv().Config = {
    ["Main Account"] = "HwanMyung1",
    ["Sticker Trade"] = {
        "Lyrate Leaf",
        "Pises Star Sign"
    }
}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Events = RS:WaitForChild("Events")
local StickerTypes = require(RS.Stickers.StickerTypes)

local function writeStatus(text)
    pcall(function()
        writefile(LP.Name .. ".txt", text)
    end)
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

local function waitForPath(root, path)
    local cur = root
    for _, n in ipairs(path) do
        cur = cur:WaitForChild(n, math.huge)
    end
    return cur
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
for _, name in ipairs(getgenv().Config["Sticker Trade"] or {}) do
    local img = NameToImage[name]
    if img then
        TargetImages[img] = name
        print("CONFIG:", name, "->", img)
    else
        warn("CONFIG NOT FOUND:", name)
    end
end

local guiRoot = waitForPath(LP.PlayerGui, {
    "ScreenGui",
    "TradeLayer",
    "TradeAnchorFrame"
})

local grid = guiRoot
    :WaitForChild("TradeInventory")
    :WaitForChild("InventoryFrame")
    :WaitForChild("ScrollingFrame")
    :WaitForChild("GuiGrid")
    :WaitForChild("GridSlotStage")

local function getAcceptButton()
    local ok, btn = pcall(function()
        return guiRoot.TradeFrame.ButtonAccept.ButtonTop
    end)
    if ok then return btn end
end

local function waitTradeFrame()
    return LP.PlayerGui.ScreenGui.TradeLayer:WaitForChild("TradeAnchorFrame", math.huge)
end

local function tradeGone()
    return not LP.PlayerGui.ScreenGui.TradeLayer:FindFirstChild("TradeAnchorFrame", true)
end

local function getMainUserId(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then
            return p.UserId
        end
    end
end

local function autoAddStickers()
    local added = 0
    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            local guiImg = tostring(img.Image)
            local name = TargetImages[guiImg]

            if name then
                print("MATCH:", name)
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

local function acceptTrade()
    local btn = getAcceptButton()
    if btn then
        smartClick(btn)
        return true
    end
end

task.spawn(function()
    local isMain = LP.Name == getgenv().Config["Main Account"]

    if isMain then
        print("MODE: MAIN")

        while true do
            local tradeLayer = LP.PlayerGui.ScreenGui.TradeLayer
            local incoming = tradeLayer:FindFirstChild("IncomingTradeRequestFrame", true)

            if incoming then
                local acceptBtn = incoming:FindFirstChild("ButtonAccept", true)
                if acceptBtn then
                    print("MAIN ACCEPT REQUEST")
                    smartClick(acceptBtn)
                    task.wait(3)

                    waitTradeFrame()

                    while true do
                        acceptTrade()
                        if tradeGone() then break end
                        task.wait(1)
                    end
                end
            end

            task.wait(0.5)
        end
    else
        print("MODE: ALT")

        local mainId = getMainUserId(getgenv().Config["Main Account"])
        if not mainId then
            warn("MAIN NOT IN SERVER")
            return
        end

        Events.TradePlayerRequestStart:FireServer(mainId)
        print("TRADE REQUEST SENT TO:", mainId)

        waitTradeFrame()
        task.wait(1)

        local count = autoAddStickers()
        print("STICKERS ADDED:", count)

        task.wait(1)
        acceptTrade()

        while not tradeGone() do
            task.wait(1)
        end

        writeStatus("Completed-TradeStarSign")
        print("TRADE DONE")
    end
end)
