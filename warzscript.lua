-- Language: Lua (Luau) | Pro Hub | ProScript v4.1 (Mobile & PC Optimized)
-- Home / Minimize = เปิด/ปิด หรือย่อ UI | E = ล็อคเป้า

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

local T = {
    BG=Color3.fromRGB(10,18,12), CARD=Color3.fromRGB(16,28,18),
    CARD2=Color3.fromRGB(22,38,24), ACCENT=Color3.fromRGB(0,215,90),
    ACCENTLIT=Color3.fromRGB(0,255,120), TAB_OFF=Color3.fromRGB(18,30,20),
    TEXT=Color3.fromRGB(235,255,240), SUBTEXT=Color3.fromRGB(130,170,140),
    TRACK=Color3.fromRGB(32,60,38), GREEN=Color3.fromRGB(0,210,85),
    RED=Color3.fromRGB(255,60,60),
}

local CFG = {
    AimbotEnabled=true, AimbotKey=Enum.KeyCode.E, AimbotMode="กดค้าง",
    AimbotFOV=180, AimbotSmooth=0.50, AimbotTeamCheck=false,
    AimbotWallCheck=false, AimbotPart="Head",
    HeadOffsetX=0.0, HeadOffsetY=-0.0,
    ShowFOVCircle=true,
    ESPEnabled=true, ESPBox=true, ESPName=true,
    ESPDistance=true, ESPHealth=true, ESPTracers=true,
    ESPMaxDist=1500, ESPWallCheck=false,
    ColorEnemy=Color3.fromRGB(255,65,65), ColorTeammate=Color3.fromRGB(60,190,255),
    ColorTracer=Color3.fromRGB(0,250,120), ColorText=Color3.fromRGB(255,255,255),
    ColorHP=Color3.fromRGB(0,240,90), ColorHPLow=Color3.fromRGB(255,60,60),
    ColorFOV=Color3.fromRGB(0,255,120),
}

local MODE_CYCLE={"กดค้าง","สลับเปิดปิด"}
local MODE_LABELS={["กดค้าง"]="กดค้าง",["สลับเปิดปิด"]="สลับเปิดปิด"}
local PART_CYCLE={"Head","UpperTorso","LowerTorso","HumanoidRootPart"}
local PART_LABELS={Head="หัว",UpperTorso="ลำตัว",LowerTorso="สะโพก",HumanoidRootPart="แกนกลาง"}
local PART_FALLBACK={
    Head={"Head"}, UpperTorso={"UpperTorso","Torso"},
    LowerTorso={"LowerTorso","Torso"}, HumanoidRootPart={"HumanoidRootPart"},
}

----------------------------------------------------------------
-- DRAWING (ESP)
----------------------------------------------------------------
local function D_Square(filled, thick)
    local success, d = pcall(function()
        local obj = Drawing.new("Square")
        obj.Visible = false
        obj.Filled = filled or false
        obj.Thickness = thick or 1
        obj.Transparency = 1
        return obj
    end)
    return success and d or nil
end

local function D_Text(size)
    local success, d = pcall(function()
        local obj = Drawing.new("Text")
        obj.Visible = false
        obj.Size = size or 13
        obj.Outline = true
        obj.OutlineColor = Color3.new(0,0,0)
        obj.Transparency = 1
        obj.Center = true
        return obj
    end)
    return success and d or nil
end

local function D_Line()
    local success, d = pcall(function()
        local obj = Drawing.new("Line")
        obj.Visible = false
        obj.Thickness = 1
        obj.Transparency = 1
        return obj
    end)
    return success and d or nil
end

local function D_Circle()
    local success, d = pcall(function()
        local obj = Drawing.new("Circle")
        obj.Visible = false
        obj.Thickness = 1
        obj.Transparency = 1
        obj.Filled = false
        return obj
    end)
    return success and d or nil
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function getParts(p)
    local c = p.Character
    if not c then return nil, nil, nil end
    local hum = c:FindFirstChildWhichIsA("Humanoid", true)
    local root = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    local head = c:FindFirstChild("Head")
    if not head then head = root end
    return root, head, hum
end

local function getAimPart(char)
    if not char then return nil end
    for _, name in ipairs(PART_FALLBACK[CFG.AimbotPart] or {"Head"}) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local function w2s(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    if not on or v.Z <= 0 then return Vector2.new(v.X, v.Y), false end
    local vp = Camera.ViewportSize
    if v.X < 0 or v.Y < 0 or v.X > vp.X or v.Y > vp.Y then return Vector2.new(v.X, v.Y), false end
    return Vector2.new(v.X, v.Y), true
end

local function screenCenter() 
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) 
end

local function isEnemy(p)
    if not CFG.AimbotTeamCheck then return true end
    return p.Team ~= LocalPlayer.Team
end

local _rp = RaycastParams.new()
_rp.FilterType = Enum.RaycastFilterType.Exclude
local function hasLOS(from, to, extra)
    local char = LocalPlayer.Character
    local ig = char and {char} or {}
    if extra then table.insert(ig, extra) end
    _rp.FilterDescendantsInstances = ig
    return workspace:Raycast(from, to - from, _rp) == nil
end

local function getAimPos(part)
    if not part then return nil end
    return (part.CFrame * CFrame.new(CFG.HeadOffsetX, CFG.HeadOffsetY, 0)).Position
end

----------------------------------------------------------------
-- ALIVE CHECK
----------------------------------------------------------------
local deadFlags = {}
local humRegistry = {}

local function isAliveRaw(p)
    local char = p.Character
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid", true)
    if not hum or not hum.Parent then return false end
    if hum.Health <= 0 then return false end
    local ok, state = pcall(function() return hum:GetState() end)
    if ok and state == Enum.HumanoidStateType.Dead then return false end
    if char:FindFirstChild("Dead") or char:FindFirstChild("IsDead") then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root.Anchored then return false end
    return true
end

----------------------------------------------------------------
-- ESP POOL
----------------------------------------------------------------
local pool = {}
local fovCircle = D_Circle()
if fovCircle then fovCircle.Color = CFG.ColorFOV end

local function alloc(p)
    if pool[p] then return end
    pool[p] = {
        box = D_Square(false, 1),
        name = D_Text(13),
        dist = D_Text(11),
        hpBg = D_Square(true, 1),
        hpBar = D_Square(true, 1),
        tracer = D_Line(),
    }
end

local function free(p)
    if not pool[p] then return end
    for _, d in pairs(pool[p]) do
        pcall(function() if d then d:Remove() end end)
    end
    pool[p] = nil
    deadFlags[p] = nil
    humRegistry[p] = nil
end

local function hideAll(e)
    if not e then return end
    for _, d in pairs(e) do
        if d then d.Visible = false end
    end
end

local function renderPlayer(p, e)
    if not isAliveRaw(p) then hideAll(e) return end
    local root, head, hum = getParts(p)
    if not root then
        local char = p.Character
        if char then root = char:FindFirstChildWhichIsA("BasePart") end
    end
    if not head then head = root end
    if not root or not hum then hideAll(e) return end

    local dist3D = (root.Position - Camera.CFrame.Position).Magnitude
    if dist3D > CFG.ESPMaxDist then hideAll(e) return end
    if CFG.ESPWallCheck and not hasLOS(Camera.CFrame.Position, head.Position, p.Character) then hideAll(e) return end

    local topSP, topOn = w2s(head.Position + Vector3.new(0, 0.7, 0))
    local botSP, botOn = w2s(root.Position - Vector3.new(0, 3.0, 0))
    if not topOn and not botOn then hideAll(e) return end

    local bH = math.max(math.abs(topSP.Y - botSP.Y), 1)
    local bW = bH * 0.6
    local bX = topSP.X - bW / 2
    local col = isEnemy(p) and CFG.ColorEnemy or CFG.ColorTeammate

    if e.box then
        e.box.Visible = CFG.ESPBox
        e.box.Color = col
        e.box.Position = Vector2.new(bX, topSP.Y)
        e.box.Size = Vector2.new(bW, bH)
    end

    if e.name then
        e.name.Visible = CFG.ESPName
        e.name.Color = CFG.ColorText
        e.name.Text = p.Name
        e.name.Position = Vector2.new(topSP.X, topSP.Y - 16)
    end

    if e.dist then
        e.dist.Visible = CFG.ESPDistance
        e.dist.Text = string.format("[%dm]", math.floor(dist3D / 4))
        e.dist.Position = Vector2.new(topSP.X, topSP.Y - 28)
    end

    local hpR = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
    if e.hpBg then
        e.hpBg.Visible = CFG.ESPHealth
        e.hpBg.Position = Vector2.new(bX - 6, topSP.Y)
        e.hpBg.Size = Vector2.new(3, bH)
    end

    if e.hpBar then
        e.hpBar.Visible = CFG.ESPHealth
        e.hpBar.Color = hpR > 0.4 and CFG.ColorHP or CFG.ColorHPLow
        e.hpBar.Position = Vector2.new(bX - 6, topSP.Y + bH - bH * hpR)
        e.hpBar.Size = Vector2.new(3, math.max(bH * hpR, 1))
    end

    if e.tracer then
        e.tracer.Visible = CFG.ESPTracers
        e.tracer.Color = CFG.ColorTracer
        e.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        e.tracer.To = botSP
    end
end

local function hookCharacter(p, char)
    task.spawn(function()
        local hum
        pcall(function() hum = char:WaitForChild("Humanoid", 8) end)
        if not hum then hum = char:FindFirstChildWhichIsA("Humanoid", true) end
        if not hum then return end
        humRegistry[p] = hum
        hum.Died:Connect(function() deadFlags[p] = true end)
        hum.HealthChanged:Connect(function(hp) if hp <= 0 then deadFlags[p] = true end end)
    end)
end

local function hookPlayer(p)
    if p.Character then alloc(p); hookCharacter(p, p.Character) end
    p.CharacterAdded:Connect(function(char)
        deadFlags[p] = nil; humRegistry[p] = nil
        char:WaitForChild("HumanoidRootPart", 5)
        alloc(p); hookCharacter(p, char)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then hookPlayer(p) end
end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(free)

----------------------------------------------------------------
-- AIMBOT LOGIC (Supports Mobile Camera & Mouse Move)
----------------------------------------------------------------
local aimbotTarget = nil
local aimbotTargetPlayer = nil
local aimbotToggleActive = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        -- กด Home ซ่อน/แสดง UI
    end
    if not gameProcessed and CFG.AimbotMode == "สลับเปิดปิด" and input.KeyCode == CFG.AimbotKey then
        aimbotToggleActive = not aimbotToggleActive
    end
end)

local function isAimbotFiring()
    if not CFG.AimbotEnabled then return false end
    if CFG.AimbotMode == "สลับเปิดปิด" then return aimbotToggleActive end
    return UserInputService:IsKeyDown(CFG.AimbotKey) or UserInputService.TouchEnabled -- บนมือถือช่วยรันเมื่อเปิดใช้งาน
end

local function getClosestTarget()
    local bestPlayer, bestPart = nil, nil
    local bestDistance = CFG.AimbotFOV
    local center = screenCenter()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isEnemy(p) and isAliveRaw(p) then
            local char = p.Character
            local aimPart = char and getAimPart(char)
            if aimPart and aimPart:IsA("BasePart") then
                local aimPos = getAimPos(aimPart)
                local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
                if onScreen and screenPos.Z > 0 then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if distance <= bestDistance then
                        local wallOK = not CFG.AimbotWallCheck or hasLOS(Camera.CFrame.Position, aimPos, char)
                        if wallOK then
                            bestDistance = distance
                            bestPlayer = p
                            bestPart = aimPart
                        end
                    end
                end
            end
        end
    end
    return bestPlayer, bestPart
end

RunService.RenderStepped:Connect(function()
    if fovCircle then
        fovCircle.Visible = CFG.ShowFOVCircle
        fovCircle.Position = screenCenter()
        fovCircle.Radius = CFG.AimbotFOV
        fovCircle.Color = CFG.ColorFOV
    end

    if not CFG.ESPEnabled then
        for _, e in pairs(pool) do hideAll(e) end
    else
        for p, e in pairs(pool) do renderPlayer(p, e) end
    end

    if not isAimbotFiring() then return end

    local player, part = getClosestTarget()
    if player and part then
        local aimPos = getAimPos(part)
        if aimPos then
            -- ปรับมุมมองกล้องโดยตรง (รองรับทั้ง PC และ มือถือ 100%)
            local smooth = math.clamp(CFG.AimbotSmooth, 0.01, 1)
            local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smooth)
        end
    end
end)

----------------------------------------------------------------
-- GUI (Modern Green Theme, Draggable, Resizable, Minimizable)
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ProScriptUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local WIN_W, WIN_H = 340, 520
local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Window.BackgroundColor3 = T.BG
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
Window.Parent = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 14)

local Stroke = Instance.new("UIStroke", Window)
Stroke.Color = T.ACCENT
Stroke.Thickness = 1.8
Stroke.Transparency = 0.3

local Accent = Instance.new("Frame")
Accent.Size = UDim2.new(1, 0, 0, 4)
Accent.BackgroundColor3 = T.ACCENT
Accent.BorderSizePixel = 0
Accent.Parent = Window

local AG = Instance.new("UIGradient", Accent)
AG.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, T.ACCENT), ColorSequenceKeypoint.new(1, T.ACCENTLIT)}

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.Position = UDim2.new(0, 0, 0, 4)
TitleBar.BackgroundColor3 = T.CARD
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 9, 0, 9)
Dot.Position = UDim2.new(0, 14, 0.5, -4.5)
Dot.BackgroundColor3 = T.ACCENTLIT
Dot.BorderSizePixel = 0
Dot.Parent = TitleBar
Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -120, 1, 0)
TitleLbl.Position = UDim2.new(0, 30, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "Pro Hub"
TitleLbl.TextColor3 = T.TEXT
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 16
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

local VerLbl = Instance.new("TextLabel")
VerLbl.Size = UDim2.new(0, 80, 1, 0)
VerLbl.Position = UDim2.new(0, 95, 0, 0)
VerLbl.BackgroundTransparency = 1
VerLbl.Text = "v4.1"
VerLbl.TextColor3 = T.SUBTEXT
VerLbl.Font = Enum.Font.Gotham
VerLbl.TextSize = 10
VerLbl.TextXAlignment = Enum.TextXAlignment.Left
VerLbl.Parent = TitleBar

-- ปุ่มปิด (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
end)

-- ปุ่มย่อ/ขยายส่วน (- / +)
local minimized = false
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinBtn.BackgroundColor3 = T.TRACK
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

----------------------------------------------------------------
-- DRAGGING & RESIZING
----------------------------------------------------------------
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        local delta = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 16, 0, 16)
ResizeHandle.Position = UDim2.new(1, -16, 1, -16)
ResizeHandle.BackgroundColor3 = T.ACCENT
ResizeHandle.Text = ""
ResizeHandle.BorderSizePixel = 0
ResizeHandle.ZIndex = 15
ResizeHandle.Parent = Window
Instance.new("UICorner", ResizeHandle).CornerRadius = UDim.new(0, 4)

local resizing = false, resizeStart, startSize
ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startSize = Window.Size
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and resizing then
        local delta = input.Position - resizeStart
        local newW = math.clamp(startSize.X.Offset + delta.X, 300, 600)
        local newH = math.clamp(startSize.Y.Offset + delta.Y, 350, 700)
        Window.Size = UDim2.new(0, newW, 0, newH)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end)

----------------------------------------------------------------
-- TABS & CONTENT CONTAINER
----------------------------------------------------------------
local TAB_H = 36
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, TAB_H)
TabBar.Position = UDim2.new(0, 0, 0, 48)
TabBar.BackgroundColor3 = T.CARD
TabBar.BorderSizePixel = 0
TabBar.Parent = Window

local TabSep = Instance.new("Frame")
TabSep.Size = UDim2.new(1, 0, 0, 1)
TabSep.Position = UDim2.new(0, 0, 1, -1)
TabSep.BackgroundColor3 = T.ACCENT
TabSep.BorderSizePixel = 0
TabSep.Parent = TabBar

local CONTENT_Y = 48 + TAB_H + 1
local FOOTER_H = 28
local ContentHolder = Instance.new("Frame")
ContentHolder.Size = UDim2.new(1, 0, 1, -(CONTENT_Y + FOOTER_H))
ContentHolder.Position = UDim2.new(0, 0, 0, CONTENT_Y)
ContentHolder.BackgroundTransparency = 1
ContentHolder.ClipsDescendants = true
ContentHolder.Parent = Window

-- ฟังก์ชันปุ่มย่อ/ขยาย
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    MinBtn.Text = minimized and "+" : "-"
    TweenService:Create(Window, TweenInfo.new(0.2), {
        Size = minimized and UDim2.new(0, WIN_W, 0, 48) or UDim2.new(0, WIN_W, 0, WIN_H)
    }):Play()
    ContentHolder.Visible = not minimized
end)

local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, 0, 0, FOOTER_H)
Footer.Position = UDim2.new(0, 0, 1, -FOOTER_H)
Footer.BackgroundColor3 = T.CARD
Footer.BorderSizePixel = 0
Footer.Parent = Window

local CreditLbl = Instance.new("TextLabel")
CreditLbl.Size = UDim2.new(1, 0, 1, 0)
CreditLbl.BackgroundTransparency = 1
CreditLbl.Text = "ยูทูป ช่องนี้เรื่องโปร"
CreditLbl.TextColor3 = T.ACCENTLIT
CreditLbl.Font = Enum.Font.GothamBold
CreditLbl.TextSize = 11
CreditLbl.Parent = Footer

local _lo = {}
local function nextLO(p) _lo[p] = (_lo[p] or 0) + 1 return _lo[p] end

local function makeTabFrame()
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = T.ACCENT
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = false
    sf.Parent = ContentHolder
    local ll = Instance.new("UIListLayout", sf)
    ll.Padding = UDim.new(0, 6)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    return sf
end

local TabMain = makeTabFrame()
local TabESP = makeTabFrame()
local TabOther = makeTabFrame()
TabMain.Visible = true

local TABS = {
    {label="หลัก", frame=TabMain},
    {label="มองทะลุ", frame=TabESP},
    {label="อื่นๆ", frame=TabOther},
}
local activeTab = 1
local tabBtns = {}
local tabW = 1 / #TABS

for i, def in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(tabW, -4, 1, -8)
    btn.Position = UDim2.new((i-1)*tabW, 2, 0, 4)
    btn.BackgroundColor3 = (i == 1) and T.ACCENT or T.TAB_OFF
    btn.Text = def.label
    btn.TextColor3 = T.TEXT
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    tabBtns[i] = btn
    local idx = i
    btn.MouseButton1Click:Connect(function()
        if activeTab == idx then return end
        TweenService:Create(tabBtns[activeTab], TweenInfo.new(0.15), {BackgroundColor3=T.TAB_OFF}):Play()
        TABS[activeTab].frame.Visible = false
        activeTab = idx
        TweenService:Create(tabBtns[activeTab], TweenInfo.new(0.15), {BackgroundColor3=T.ACCENT}):Play()
        TABS[activeTab].frame.Visible = true
    end)
end

----------------------------------------------------------------
-- GUI BUILDERS (UI Components)
----------------------------------------------------------------
local function makeSection(title, parent)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.LayoutOrder = nextLO(parent)
    f.Parent = parent

    local lL = Instance.new("Frame")
    lL.Size = UDim2.new(0.22, 0, 0, 1)
    lL.Position = UDim2.new(0, 0, 0.5, 0)
    lL.BackgroundColor3 = T.ACCENT
    lL.BorderSizePixel = 0
    lL.Parent = f

    local lR = Instance.new("Frame")
    lR.Size = UDim2.new(0.22, 0, 0, 1)
    lR.Position = UDim2.new(0.78, 0, 0.5, 0)
    lR.BackgroundColor3 = T.ACCENT
    lR.BorderSizePixel = 0
    lR.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.56, 0, 1, 0)
    lbl.Position = UDim2.new(0.22, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = T.ACCENTLIT
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = f
end

local function makeToggle(labelText, state, onChange, parent)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = T.CARD2
    f.BorderSizePixel = 0
    f.LayoutOrder = nextLO(parent)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -64, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TEXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 42, 0, 22)
    track.Position = UDim2.new(1, -52, 0.5, -11)
    track.BackgroundColor3 = state and T.ACCENT or T.TRACK
    track.BorderSizePixel = 0
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local val = state
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = f
    btn.MouseButton1Click:Connect(function()
        val = not val
        TweenService:Create(track, TweenInfo.new(0.14), {BackgroundColor3 = val and T.ACCENT or T.TRACK}):Play()
        TweenService:Create(knob, TweenInfo.new(0.14), {Position = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
        onChange(val)
    end)
end

local function makeSlider(labelText, min, max, current, step, onChange, parent)
    step = step or 1
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 54)
    f.BackgroundColor3 = T.CARD2
    f.BorderSizePixel = 0
    f.LayoutOrder = nextLO(parent)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 0, 24)
    lbl.Position = UDim2.new(0, 14, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TEXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, -14, 0, 24)
    valLbl.Position = UDim2.new(0.6, 0, 0, 5)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = string.format(step < 1 and "%.2f" or "%d", current)
    valLbl.TextColor3 = T.ACCENTLIT
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 6)
    track.Position = UDim2.new(0, 14, 0, 34)
    track.BackgroundColor3 = T.TRACK
    track.BorderSizePixel = 0
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((current - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = T.ACCENT
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new((current - min) / (max - min), 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 3
    thumb.Parent = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function upd(px)
        local rel = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + rel * (max - min)) / step + 0.5) * step
        v = math.clamp(v, min, max)
        local frac = (v - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        thumb.Position = UDim2.new(frac, 0, 0.5, 0)
        valLbl.Text = string.format(step < 1 and "%.2f" or "%d", v)
        onChange(v)
    end

    local hb = Instance.new("TextButton")
    hb.Size = UDim2.new(1, 0, 0, 24)
    hb.Position = UDim2.new(0, 0, -1.5, 0)
    hb.BackgroundTransparency = 1
    hb.Text = ""
    hb.Parent = track
    hb.MouseButton1Down:Connect(function(x) dragging = true; upd(x) end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            upd(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function makeCycle(labelText, options, labels, current, onChange, parent)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = T.CARD2
    f.BorderSizePixel = 0
    f.LayoutOrder = nextLO(parent)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TEXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local idx = 1
    for i, v in ipairs(options) do if v == current then idx = i break end end

    local valBtn = Instance.new("TextButton")
    valBtn.Size = UDim2.new(0, 120, 0, 26)
    valBtn.Position = UDim2.new(1, -128, 0.5, -13)
    valBtn.BackgroundColor3 = T.ACCENT
    valBtn.BorderSizePixel = 0
    valBtn.Text = labels[options[idx]] or options[idx]
    valBtn.TextColor3 = Color3.new(1, 1, 1)
    valBtn.Font = Enum.Font.GothamBold
    valBtn.TextSize = 11
    valBtn.Parent = f
    Instance.new("UICorner", valBtn).CornerRadius = UDim.new(0, 6)

    valBtn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        local nv = options[idx]
        valBtn.Text = labels[nv] or nv
        onChange(nv)
    end)
end

----------------------------------------------------------------
-- BUILD TABS CONTENT
----------------------------------------------------------------
makeSection("ระบบล็อคเป้า", TabMain)
makeToggle("เปิดใช้งานล็อคเป้า", CFG.AimbotEnabled, function(v) CFG.AimbotEnabled = v end, TabMain)
makeCycle("โหมดการทำงาน", MODE_CYCLE, MODE_LABELS, CFG.AimbotMode, function(v) CFG.AimbotMode = v; aimbotToggleActive = false end, TabMain)
makeToggle("เช็คทีมเดียวกัน", CFG.AimbotTeamCheck, function(v) CFG.AimbotTeamCheck = v end, TabMain)
makeToggle("เช็คสิ่งกีดขวาง (กำแพง)", CFG.AimbotWallCheck, function(v) CFG.AimbotWallCheck = v end, TabMain)
makeToggle("แสดงวงกลมขอบเขต", CFG.ShowFOVCircle, function(v) CFG.ShowFOVCircle = v end, TabMain)
makeCycle("ส่วนที่ต้องการล็อค", PART_CYCLE, PART_LABELS, CFG.AimbotPart, function(v) CFG.AimbotPart = v end, TabMain)
makeSlider("ขนาดขอบเขต (FOV)", 20, 500, CFG.AimbotFOV, 1, function(v) CFG.AimbotFOV = v end, TabMain)
makeSlider("ความหน่วง/นุ่มนวล (x100)", 1, 100, math.floor(CFG.AimbotSmooth * 100), 1, function(v) CFG.AimbotSmooth = v / 100 end, TabMain)
makeSlider("ปรับเป้าแกน X", -1.0, 1.0, CFG.HeadOffsetX, 0.05, function(v) CFG.HeadOffsetX = v end, TabMain)
makeSlider("ปรับเป้าแกน Y", -1.0, 1.0, CFG.HeadOffsetY, 0.05, function(v) CFG.HeadOffsetY = v end, TabMain)

makeSection("ระบบมองทะลุ (ESP)", TabESP)
makeToggle("เปิดใช้งาน ESP", CFG.ESPEnabled, function(v) CFG.ESPEnabled = v end, TabESP)
makeToggle("แสดงกรอบสี่เหลี่ยม", CFG.ESPBox, function(v) CFG.ESPBox = v end, TabESP)
makeToggle("แสดงชื่อผู้เล่น", CFG.ESPName, function(v) CFG.ESPName = v end, TabESP)
makeToggle("แสดงระยะทาง", CFG.ESPDistance, function(v) CFG.ESPDistance = v end, TabESP)
makeToggle("แสดงพลังชีวิต", CFG.ESPHealth, function(v) CFG.ESPHealth = v end, TabESP)
makeToggle("แสดงเส้นนำทาง", CFG.ESPTracers, function(v) CFG.ESPTracers = v end, TabESP)
makeToggle("เช็คสิ่งกีดขวาง ESP", CFG.ESPWallCheck, function(v) CFG.ESPWallCheck = v end, TabESP)
makeSlider("ระยะทางสูงสุด", 100, 5000, CFG.ESPMaxDist, 50, function(v) CFG.ESPMaxDist = v end, TabESP)
