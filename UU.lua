local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local StickerTypes = require(RS.Stickers.StickerTypes)

local function resolveMainUserId(input)
    if not input then return nil end
    input = tostring(input)

    if tonumber(input) then
        return tonumber(input)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == input:lower() then
            return p.UserId
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName:lower() == input:lower() then
            return p.UserId
        end
    end

    return nil
end

local function waitForPath(root, path)
    local obj = root
    for _, name in ipairs(path) do
        obj = obj:WaitForChild(name, math.huge)
    end
    return obj
end

local function fireConnections(signal)
    local ok, conns = pcall(function()
        return getconnections(signal)
    end)
    if not ok or not conns then return false end

    local fired = false
    for _, c in ipairs(conns) do
        if typeof(c.Function) == "function" then
            pcall(function()
                c.Function()
                fired = true
            end)
        end
    end
    return fired
end

local function clickByEnter(obj)
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

local MAIN_UID
while not MAIN_UID do
    MAIN_UID = resolveMainUserId(getgenv().Config["Main Account"])
    task.wait(1)
end

local function isMain()
    return LP.UserId == MAIN_UID
end

local function sendTrade()
    RS.Events.TradePlayerRequestStart:FireServer(MAIN_UID)
end

local function buildTargetImages()
    local map = {}
    for _, name in ipairs(getgenv().Config["Sticker Trade"] or {}) do
        local data = StickerTypes[name]
        if data and data.Image then
            map[tostring(data.Image)] = name
        end
    end
    return map
end

local TargetImages = buildTargetImages()

local function waitTradeFrame()
    return waitForPath(LP.PlayerGui, {
        "ScreenGui",
        "TradeLayer",
        "TradeAnchorFrame"
    })
end

local function autoAddStickers()
    local grid = waitForPath(LP.PlayerGui, {
        "ScreenGui",
        "TradeLayer",
        "TradeAnchorFrame",
        "TradeInventory",
        "InventoryFrame",
        "ScrollingFrame",
        "GuiGrid",
        "GridSlotStage"
    })

    for _, slot in ipairs(grid:GetChildren()) do
        local ok, img = pcall(function()
            return slot.ObjImage.GuiTile.StageGrow.StagePop.StageFlip.ObjCard.ObjContent.ObjImage
        end)

        if ok and img and img:IsA("ImageLabel") then
            local guiImg = tostring(img.Image)
            local name = TargetImages[guiImg]

            if name then
                local addBtn = slot.ObjImage.GuiTile.StageOverlay:FindFirstChild("AddButton", true)
                if addBtn then
                    smartClick(addBtn)
                    task.wait(0.25)
                end
            end
        end
    end
end

local function clickTradeAccept()
    local btn = waitForPath(LP.PlayerGui, {
        "ScreenGui",
        "TradeLayer",
        "TradeAnchorFrame",
        "TradeFrame",
        "ButtonAccept",
        "ButtonTop"
    })
    smartClick(btn)
end

if isMain() then
    print("RUNNING AS MAIN ACCOUNT")

    task.spawn(function()
        local tradeLayer = waitForPath(LP.PlayerGui, {
            "ScreenGui",
            "TradeLayer"
        })

        while true do
            local frame = tradeLayer:FindFirstChild("IncomingTradeRequestFrame", true)
            if frame then
                local btn = frame:FindFirstChild("ButtonAccept", true)
                if btn then
                    smartClick(btn)
                    task.wait(3)

                    if tradeLayer:FindFirstChild("TradeAnchorFrame", true) then
                        clickTradeAccept()
                    end

                    repeat task.wait(1)
                    until not tradeLayer:FindFirstChild("TradeAnchorFrame", true)
                end
            end
            task.wait(0.5)
        end
    end)
else
    print("RUNNING AS CLONE ACCOUNT")

    sendTrade()

    waitTradeFrame()
    task.wait(1)

    autoAddStickers()
    task.wait(1)

    clickTradeAccept()

    repeat task.wait(1)
    until not LP.PlayerGui:FindFirstChild("TradeAnchorFrame", true)

    pcall(function()
        writefile(LP.Name .. ".txt", "Completed-TradeStarSign")
    end)

    print("TRADE COMPLETED")
end
