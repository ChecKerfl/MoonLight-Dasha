-- ============================================================
-- Violence District ESP
-- ============================================================
print("MoonLight: Dasha v1.2.1 Loading...")
task.wait(3.59)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui   -- форвард-декларация

-- ============================================================
-- CONFIG
-- ============================================================
local defaultSubject = {
	box       = { enabled = false, color = Color3.fromRGB(255, 0, 0), transparency = 0 },
	offScreen = { enabled = false, color = Color3.fromRGB(255, 0, 0), transparency = 0 },
	tracer    = { enabled = false, color = Color3.fromRGB(255, 255, 255), transparency = 0 },
	skeleton  = { enabled = false, color = Color3.fromRGB(255, 255, 255), transparency = 0 },
	dName     = { enabled = false, color = Color3.fromRGB(0, 255, 0), transparency = 0 },
	uName     = { enabled = false, color = Color3.fromRGB(0, 0, 255), transparency = 0 },
	avatar    = { enabled = false },
	stroke    = { enabled = true,  color = Color3.fromRGB(255, 0, 0), transparency = 0 },
	fill      = { enabled = true,  color = Color3.fromRGB(255, 0, 0), transparency = 0.5 },
}

local function cloneSubject(src)
	local d = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			d[k] = {}
			for k2, v2 in pairs(v) do d[k][k2] = v2 end
		else
			d[k] = v
		end
	end
	return d
end

local config = {
	playersESP = true,
	killerESP  = true,
	subject    = "Killer",
	killer     = cloneSubject(defaultSubject),
	players    = cloneSubject(defaultSubject),
}
config.players.box.color       = Color3.fromRGB(0, 255, 255)
config.players.offScreen.color = Color3.fromRGB(0, 255, 255)
config.players.stroke.color    = Color3.fromRGB(0, 255, 0)
config.players.fill.color      = Color3.fromRGB(0, 255, 0)

local TOGGLE_ON  = Color3.fromRGB(0, 200, 0)
local TOGGLE_OFF = Color3.fromRGB(150, 150, 150)
local TOGGLE_LOCKED = Color3.fromRGB(70, 70, 70)
local TOGGLE_KNOB_ON_POS  = UDim2.new(0, 16, 0, 1)
local TOGGLE_KNOB_OFF_POS = UDim2.new(0, 1, 0, 1)
local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ============================================================
-- HELPERS
-- ============================================================
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency, mode)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(100, 100, 100)
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.75
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	pcall(function()
		s.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end)
	s.Parent = parent
	return s
end

local function font(size, weight, style)
	return Font.new("rbxasset://fonts/families/Ubuntu.json",
		weight or Enum.FontWeight.Bold,
		style or Enum.FontStyle.Normal)
end

-- ============================================================
-- ПЛАВНОЕ ПОЯВЛЕНИЕ/ИСЧЕЗНОВЕНИЕ
-- ============================================================
local panelOriginals = {}

local function collectTransparency(root)
	local data = {}
	local function scan(o)
		if o:IsA("GuiObject") then
			data[o] = {
				bg   = o.BackgroundTransparency,
				text = (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox"))
					and o.TextTransparency or nil,
				img  = (o:IsA("ImageLabel") or o:IsA("ImageButton"))
					and o.ImageTransparency or nil,
			}
		elseif o:IsA("UIStroke") then
			data[o] = { stroke = o.Transparency }
		end
		for _, child in ipairs(o:GetChildren()) do
			scan(child)
		end
	end
	scan(root)
	return data
end

local function ensureOriginals(panel)
	if not panelOriginals[panel] then
		panelOriginals[panel] = collectTransparency(panel)
	end
	return panelOriginals[panel]
end

local function fadePanel(panel, fadeOut, duration, callback)
	duration = duration or 0.2
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local data = ensureOriginals(panel)
	local tweens = {}

	if not fadeOut then panel.Visible = true end

	for obj, d in pairs(data) do
		if not obj.Parent then continue end
		local props = {}
		if d.bg ~= nil then
			if not fadeOut then obj.BackgroundTransparency = 1 end
			props.BackgroundTransparency = fadeOut and 1 or d.bg
		end
		if d.text ~= nil then
			if not fadeOut then obj.TextTransparency = 1 end
			props.TextTransparency = fadeOut and 1 or d.text
		end
		if d.img ~= nil then
			if not fadeOut then obj.ImageTransparency = 1 end
			props.ImageTransparency = fadeOut and 1 or d.img
		end
		if d.stroke ~= nil then
			if not fadeOut then obj.Transparency = 1 end
			props.Transparency = fadeOut and 1 or d.stroke
		end
		if next(props) then
			table.insert(tweens, TweenService:Create(obj, info, props))
		end
	end

	for _, t in ipairs(tweens) do t:Play() end

	task.delay(duration, function()
		if fadeOut then panel.Visible = false end
		if callback then callback() end
	end)
end

-- ============================================================
-- ESP CORE
-- ============================================================
local highlights = {}
local espObjects = {}

local function isKiller(plr)
	if plr == player then return false end
	if plr.Team and plr.Team.Name:lower():find("killer") then return true end
	local char = plr.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				local name = child.Name:lower()
				if name:find("knife") or name:find("sword") or name:find("weapon")
					or name:find("gun") or name:find("axe") or name:find("blade") then
					return true
				end
			end
		end
	end
	return false
end

local function getConfigFor(plr)
	return isKiller(plr) and config.killer or config.players
end

local function shouldShow(plr)
	if plr == player then return false end
	local k = isKiller(plr)
	if k and not config.killerESP then return false end
	if (not k) and not config.playersESP then return false end
	return true
end

local function updateHighlight(plr)
	if not shouldShow(plr) then
		if highlights[plr] then
			highlights[plr]:Destroy()
			highlights[plr] = nil
		end
		return
	end
	local char = plr.Character
	if not char then
		if highlights[plr] then
			highlights[plr]:Destroy()
			highlights[plr] = nil
		end
		return
	end

	local hl = highlights[plr]
	if not hl or not hl.Parent then
		hl = Instance.new("Highlight")
		hl.Name = "ESP_Highlight"
		hl.Adornee = char
		hl.Parent = char
		highlights[plr] = hl
	end

	hl.Adornee = char
	hl.Enabled = true

	local cfg = getConfigFor(plr)
	hl.OutlineColor        = cfg.stroke.color
	hl.OutlineTransparency = cfg.stroke.enabled and cfg.stroke.transparency or 1
	hl.FillColor           = cfg.fill.color
	hl.FillTransparency    = cfg.fill.enabled and cfg.fill.transparency or 1
end

local function refreshAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		updateHighlight(plr)
	end
end

-- ============================================================
-- ESP RENDER SYSTEM
-- ============================================================
local function cleanupESP(plr)
	local objs = espObjects[plr]
	if not objs then return end
	for _, v in pairs(objs) do
		if typeof(v) == "Instance" then
			pcall(function() v:Destroy() end)
		elseif type(v) == "table" then
			for _, v2 in pairs(v) do
				if typeof(v2) == "Instance" then
					pcall(function() v2:Destroy() end)
				end
			end
		end
	end
	espObjects[plr] = nil
end

local function setupESP(plr)
	if plr == player then return end
	cleanupESP(plr)

	local objs = {}

	objs.box = {}
	for _, name in ipairs({"Top", "Bottom", "Left", "Right"}) do
		local f = Instance.new("Frame")
		f.Name = "ESP_Box_" .. name
		f.BorderSizePixel = 0
		f.Visible = false
		f.ZIndex = 0
		f.Parent = screenGui
		objs.box[name] = f
	end

	local tr = Instance.new("Frame")
	tr.Name = "ESP_Tracer"
	tr.BorderSizePixel = 0
	tr.AnchorPoint = Vector2.new(0, 0.5)
	tr.Visible = false
	tr.ZIndex = 0
	tr.Parent = screenGui
	objs.tracer = tr

	local off = Instance.new("Frame")
	off.Name = "ESP_OffScreen"
	off.Size = UDim2.new(0, 22, 0, 22)
	off.AnchorPoint = Vector2.new(0.5, 0.5)
	off.BorderSizePixel = 0
	off.Visible = false
	off.ZIndex = 0
	off.Parent = screenGui
	corner(off, 30)
	objs.offScreen = off

	-- ⚡ BillboardGui теперь в playerGui, а не в screenGui
	local dn = Instance.new("BillboardGui")
	dn.Name = "ESP_DName"
	dn.Size = UDim2.new(0, 200, 0, 20)
	dn.StudsOffset = Vector3.new(0, 3.2, 0)
	dn.AlwaysOnTop = true
	dn.Enabled = false
	dn.Parent = playerGui
	local dnL = Instance.new("TextLabel")
	dnL.Size = UDim2.new(1, 0, 1, 0)
	dnL.BackgroundTransparency = 1
	dnL.TextScaled = true
	dnL.TextStrokeTransparency = 0.5
	dnL.Font = Enum.Font.SourceSansBold
	dnL.Text = plr.DisplayName
	dnL.Parent = dn
	objs.dName = dn
	objs.dNameLabel = dnL

	local un = Instance.new("BillboardGui")
	un.Name = "ESP_UName"
	un.Size = UDim2.new(0, 200, 0, 20)
	un.StudsOffset = Vector3.new(0, 2.9, 0)
	un.AlwaysOnTop = true
	un.Enabled = false
	un.Parent = playerGui
	local unL = Instance.new("TextLabel")
	unL.Size = UDim2.new(1, 0, 1, 0)
	unL.BackgroundTransparency = 1
	unL.TextScaled = true
	unL.TextStrokeTransparency = 0.5
	unL.Font = Enum.Font.SansSerif
	unL.Text = plr.Name
	unL.Parent = un
	objs.uName = un
	objs.uNameLabel = unL

	local av = Instance.new("BillboardGui")
	av.Name = "ESP_Avatar"
	av.Size = UDim2.new(0, 50, 0, 50)
	av.StudsOffset = Vector3.new(0, 4.5, 0)
	av.AlwaysOnTop = true
	av.Enabled = false
	av.Parent = playerGui
	local avImg = Instance.new("ImageLabel")
	avImg.Size = UDim2.new(1, 0, 1, 0)
	avImg.BackgroundTransparency = 1
	avImg.Parent = av
	corner(avImg, 8)
	objs.avatar = av
	objs.avatarImg = avImg

	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and thumb and avImg.Parent then
			avImg.Image = thumb
		end
	end)

	espObjects[plr] = objs
end

RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local viewport = cam.ViewportSize

	for plr, objs in pairs(espObjects) do
		local char = plr.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		local head = char and char:FindFirstChild("Head")

		if hrp then
			local cfg = getConfigFor(plr)

			local rootPos = hrp.Position
			local topPos  = rootPos + Vector3.new(0, 3, 0)
			local botPos  = rootPos - Vector3.new(0, 3, 0)

			local topScreen, topOn = cam:WorldToViewportPoint(topPos)
			local botScreen, botOn = cam:WorldToViewportPoint(botPos)
			local hrpScreen, hrpOn = cam:WorldToViewportPoint(rootPos)

			local onScreen = topOn and botOn and hrpOn and hrpScreen.Z > 0

			if cfg.box.enabled and onScreen then
				local h = math.abs(botScreen.Y - topScreen.Y)
				local w = h * 0.5
				local x = topScreen.X - w / 2
				local y = topScreen.Y

				local c = cfg.box.color
				local t = cfg.box.transparency

				objs.box.Top.Position = UDim2.new(0, x, 0, y)
				objs.box.Top.Size = UDim2.new(0, w, 0, 1)
				objs.box.Top.BackgroundColor3 = c
				objs.box.Top.BackgroundTransparency = t
				objs.box.Top.Visible = true

				objs.box.Bottom.Position = UDim2.new(0, x, 0, y + h)
				objs.box.Bottom.Size = UDim2.new(0, w, 0, 1)
				objs.box.Bottom.BackgroundColor3 = c
				objs.box.Bottom.BackgroundTransparency = t
				objs.box.Bottom.Visible = true

				objs.box.Left.Position = UDim2.new(0, x, 0, y)
				objs.box.Left.Size = UDim2.new(0, 1, 0, h)
				objs.box.Left.BackgroundColor3 = c
				objs.box.Left.BackgroundTransparency = t
				objs.box.Left.Visible = true

				objs.box.Right.Position = UDim2.new(0, x + w, 0, y)
				objs.box.Right.Size = UDim2.new(0, 1, 0, h)
				objs.box.Right.BackgroundColor3 = c
				objs.box.Right.BackgroundTransparency = t
				objs.box.Right.Visible = true
			else
				objs.box.Top.Visible = false
				objs.box.Bottom.Visible = false
				objs.box.Left.Visible = false
				objs.box.Right.Visible = false
			end

			if cfg.tracer.enabled and onScreen then
				local startX = viewport.X / 2
				local startY = viewport.Y
				local endX = hrpScreen.X
				local endY = hrpScreen.Y

				local dx = endX - startX
				local dy = endY - startY
				local dist = math.sqrt(dx * dx + dy * dy)
				local angle = math.deg(math.atan2(dy, dx))

				objs.tracer.Position = UDim2.new(0, startX, 0, startY)
				objs.tracer.Size = UDim2.new(0, dist, 0, 1)
				objs.tracer.Rotation = angle
				objs.tracer.BackgroundColor3 = cfg.tracer.color
				objs.tracer.BackgroundTransparency = cfg.tracer.transparency
				objs.tracer.Visible = true
			else
				objs.tracer.Visible = false
			end

			if cfg.offScreen.enabled and not onScreen then
				local dx, dy
				if hrpScreen.Z < 0 then
					dx = -(hrpScreen.X - viewport.X / 2)
					dy = -(hrpScreen.Y - viewport.Y / 2)
				else
					dx = hrpScreen.X - viewport.X / 2
					dy = hrpScreen.Y - viewport.Y / 2
				end

				local len = math.sqrt(dx * dx + dy * dy)
				if len > 0 then
					dx, dy = dx / len, dy / len
					local edgeX = viewport.X / 2 + dx * (viewport.X / 2 - 40)
					local edgeY = viewport.Y / 2 + dy * (viewport.Y / 2 - 40)

					objs.offScreen.Position = UDim2.new(0, edgeX, 0, edgeY)
					objs.offScreen.BackgroundColor3 = cfg.offScreen.color
					objs.offScreen.BackgroundTransparency = cfg.offScreen.transparency
					objs.offScreen.Visible = true
				end
			else
				objs.offScreen.Visible = false
			end

			if head then
				objs.dName.Adornee = head
				objs.uName.Adornee = head
				objs.avatar.Adornee = head
			end

			objs.dName.Enabled = cfg.dName.enabled
			objs.dNameLabel.TextColor3 = cfg.dName.color
			objs.dNameLabel.TextTransparency = cfg.dName.transparency

			objs.uName.Enabled = cfg.uName.enabled
			objs.uNameLabel.TextColor3 = cfg.uName.color
			objs.uNameLabel.TextTransparency = cfg.uName.transparency

			objs.avatar.Enabled = cfg.avatar.enabled
		else
			objs.box.Top.Visible = false
			objs.box.Bottom.Visible = false
			objs.box.Left.Visible = false
			objs.box.Right.Visible = false
			objs.tracer.Visible = false
			objs.offScreen.Visible = false
			objs.dName.Enabled = false
			objs.uName.Enabled = false
			objs.avatar.Enabled = false
		end
	end
end)

-- ============================================================
-- DESTROY OLD
-- ============================================================
local oldGui = playerGui:FindFirstChild("ScreenGui")
if oldGui then oldGui:Destroy() end
local starterGui = game.StarterGui:FindFirstChild("ScreenGui")
if starterGui then starterGui:Destroy() end

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local ColorPicker
local allColorButtons = {}

local function isClickInsideColorPicker(input)
	if not ColorPicker or not ColorPicker.Visible then return false end
	if not input or not input.Position then return false end
	local mx, my = input.Position.X, input.Position.Y
	local p = ColorPicker.AbsolutePosition
	local s = ColorPicker.AbsoluteSize
	return mx >= p.X and mx <= p.X + s.X and my >= p.Y and my <= p.Y + s.Y
end

-- ============================================================
-- GUI
-- ============================================================
screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScreenGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 450, 0, 300)
Main.Position = UDim2.new(0, 50, 0, 50)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.BackgroundTransparency = 0.5
Main.BorderSizePixel = 0
Main.Active = true
Main.ZIndex = 1
Main.Parent = screenGui
corner(Main, 12)

local Dasha = Instance.new("TextLabel")
Dasha.Size = UDim2.new(0, 100, 0, 50)
Dasha.BackgroundTransparency = 1
Dasha.Text = "Dasha"
Dasha.TextColor3 = Color3.fromRGB(255, 255, 255)
Dasha.TextSize = 27
Dasha.FontFace = font(27, Enum.FontWeight.Bold, Enum.FontStyle.Italic)
Dasha.TextXAlignment = Enum.TextXAlignment.Center
Dasha.Parent = Main

-- Visuals tab
local VisualsButton = Instance.new("TextButton")
VisualsButton.Size = UDim2.new(0, 90, 0, 30)
VisualsButton.Position = UDim2.new(0, 5, 0, 50)
VisualsButton.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
VisualsButton.BackgroundTransparency = 0.8
VisualsButton.Text = "    Visuals"
VisualsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
VisualsButton.TextSize = 14
VisualsButton.FontFace = font(14)
VisualsButton.TextXAlignment = Enum.TextXAlignment.Left
VisualsButton.BorderSizePixel = 0
VisualsButton.AutoButtonColor = false
VisualsButton.Parent = Main
corner(VisualsButton, 8)
local visIndicator = Instance.new("Frame")
visIndicator.Size = UDim2.new(0, 3, 0, 18)
visIndicator.Position = UDim2.new(0, 3, 0, 6)
visIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
visIndicator.BorderSizePixel = 0
visIndicator.Parent = VisualsButton
corner(visIndicator, 6)
local visStroke = stroke(VisualsButton, Color3.fromRGB(100, 100, 100), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

-- Settings tab (заблокирована)
local SettingsButton = Instance.new("TextButton")
SettingsButton.Size = UDim2.new(0, 90, 0, 30)
SettingsButton.Position = UDim2.new(0, 5, 0, 85)
SettingsButton.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
SettingsButton.BackgroundTransparency = 1
SettingsButton.Text = "    Settings!"
SettingsButton.TextColor3 = Color3.fromRGB(255, 170, 0)
SettingsButton.TextSize = 14
SettingsButton.FontFace = font(14)
SettingsButton.TextXAlignment = Enum.TextXAlignment.Left
SettingsButton.BorderSizePixel = 0
SettingsButton.AutoButtonColor = false
SettingsButton.Parent = Main
corner(SettingsButton, 8)
local setIndicator = Instance.new("Frame")
setIndicator.Size = UDim2.new(0, 3, 0, 18)
setIndicator.Position = UDim2.new(0, 3, 0, 6)
setIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
setIndicator.BackgroundTransparency = 1
setIndicator.BorderSizePixel = 0
setIndicator.Parent = SettingsButton
corner(setIndicator, 6)
local setStroke = stroke(SettingsButton, Color3.fromRGB(100, 100, 100), 1.5, 1, Enum.ApplyStrokeMode.Border)

-- Close
local CloseScript = Instance.new("ImageButton")
CloseScript.Size = UDim2.new(0, 21, 0, 21)
CloseScript.Position = UDim2.new(1, -31, 0, 6)
CloseScript.BackgroundTransparency = 1
CloseScript.Image = "rbxassetid://119112691086376"
CloseScript.BorderSizePixel = 0
CloseScript.AutoButtonColor = false
CloseScript.Parent = Main

-- OwnWindow
local OwnWindow = Instance.new("Frame")
OwnWindow.Size = UDim2.new(0, 350, 0, 265)
OwnWindow.Position = UDim2.new(0, 100, 0, 35)
OwnWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
OwnWindow.BackgroundTransparency = 0.6
OwnWindow.BorderSizePixel = 0
OwnWindow.Parent = Main
corner(OwnWindow, 12)

-- Visuals Scrolling
local VisualsScrollingFrame = Instance.new("ScrollingFrame")
VisualsScrollingFrame.Size = UDim2.new(0, 350, 0, 247)
VisualsScrollingFrame.Position = UDim2.new(0, 0, 0, 9)
VisualsScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 309)
VisualsScrollingFrame.ScrollBarThickness = 3
VisualsScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
VisualsScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.XY
VisualsScrollingFrame.BackgroundTransparency = 1
VisualsScrollingFrame.BorderSizePixel = 0
VisualsScrollingFrame.Visible = true
VisualsScrollingFrame.Active = false
VisualsScrollingFrame.Parent = OwnWindow
corner(VisualsScrollingFrame, 12)

-- Settings Scrolling
local SettingsScrollingFrame = Instance.new("ScrollingFrame")
SettingsScrollingFrame.Size = UDim2.new(0, 350, 0, 247)
SettingsScrollingFrame.Position = UDim2.new(0, 0, 0, 9)
SettingsScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 293)
SettingsScrollingFrame.ScrollBarThickness = 3
SettingsScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
SettingsScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.XY
SettingsScrollingFrame.BackgroundTransparency = 1
SettingsScrollingFrame.BorderSizePixel = 0
SettingsScrollingFrame.Visible = false
SettingsScrollingFrame.Active = false
SettingsScrollingFrame.Parent = OwnWindow
corner(SettingsScrollingFrame, 12)

-- ============================================================
-- PANEL HELPERS
-- ============================================================
local function makePanel(parent, name, posX, posY, sizeX, sizeY)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = UDim2.new(0, sizeX, 0, sizeY)
	panel.Position = UDim2.new(0, posX, 0, posY)
	panel.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
	panel.BackgroundTransparency = 0.8
	panel.BorderSizePixel = 0
	panel.Parent = parent
	corner(panel, 8)
	stroke(panel)
	return panel
end

local function makeLabel(parent, name, text, posX, posY, textSize, textColor)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = UDim2.new(0, 155, 0, 25)
	lbl.Position = UDim2.new(0, posX, 0, posY)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	lbl.TextSize = textSize or 14
	lbl.FontFace = font(textSize or 14)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BorderSizePixel = 0
	lbl.Parent = parent
	return lbl
end

-- ============================================================
-- TOGGLE
-- ============================================================
local function makeToggle(parent, bgColor, posX, posY, initialState, onChange, locked)
	local toggle = Instance.new("Frame")
	toggle.Size = UDim2.new(0, 35, 0, 20)
	toggle.Position = UDim2.new(0, posX, 0, posY)
	toggle.BackgroundColor3 = locked and TOGGLE_LOCKED or (bgColor or TOGGLE_OFF)
	toggle.BorderSizePixel = 0
	toggle.Active = not locked
	toggle.Parent = parent
	corner(toggle, 30)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 18, 0, 18)
	frame.Position = TOGGLE_KNOB_OFF_POS
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = locked and 0.5 or 0
	frame.BorderSizePixel = 0
	frame.Parent = toggle
	corner(frame, 30)

	local state = (not locked) and (initialState and true or false) or false

	local function apply(animated)
		local targetBg = state and TOGGLE_ON or (locked and TOGGLE_LOCKED or TOGGLE_OFF)
		local targetPos = state and TOGGLE_KNOB_ON_POS or TOGGLE_KNOB_OFF_POS
		if animated then
			TweenService:Create(toggle, TWEEN_INFO, { BackgroundColor3 = targetBg }):Play()
			TweenService:Create(frame, TWEEN_INFO, { Position = targetPos }):Play()
		else
			toggle.BackgroundColor3 = targetBg
			frame.Position = targetPos
		end
	end

	apply(false)

	local function setState(v, fire)
		if locked then return end
		state = v and true or false
		apply(true)
		if fire and onChange then onChange(state) end
	end

	if not locked then
		toggle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if isClickInsideColorPicker(input) then return end

				state = not state
				apply(true)
				if onChange then onChange(state) end
			end
		end)
	end

	return toggle, setState
end

-- ============================================================
-- COLOR PICKER (forward)
-- ============================================================
local openColorPicker

local function makeColorButton(parent, color, posX, posY, getAlpha, onApply)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 18, 0, 18)
	btn.Position = UDim2.new(0, posX, 0, posY)
	btn.BackgroundColor3 = color
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = parent
	corner(btn, 30)
	stroke(btn, Color3.fromRGB(100, 100, 100), 1.5, 0.75, Enum.ApplyStrokeMode.Border)
	table.insert(allColorButtons, btn)

	local currentColor = color

	btn.MouseButton1Click:Connect(function()
		local initialAlpha = getAlpha and getAlpha() or 0
		openColorPicker(currentColor, function(newColor, newAlpha)
			currentColor = newColor
			btn.BackgroundColor3 = newColor
			if onApply then onApply(newColor, newAlpha) end
			refreshAll()
		end, initialAlpha, btn)
	end)

	local function setColor(c)
		currentColor = c
		btn.BackgroundColor3 = c
	end

	return btn, setColor
end

-- ============================================================
-- MASTER PANEL
-- ============================================================
local ESPMasterPanel = makePanel(VisualsScrollingFrame, "ESPMasterPanel", 9, 0, 160, 75)
local ESP_Master = makeLabel(ESPMasterPanel, "ESP_Master", "   ESP Master", 0, 0, 14, Color3.fromRGB(200, 200, 200))
ESP_Master.Size = UDim2.new(0, 160, 0, 25)
makeLabel(ESPMasterPanel, "Players_ESP", "   Players ESP", 5, 25, 14)
makeLabel(ESPMasterPanel, "Killer_ESP", "   Killer ESP", 5, 50, 14)
makeToggle(ESPMasterPanel, TOGGLE_OFF, 120, 27, config.playersESP, function(v)
	config.playersESP = v; refreshAll()
end)
makeToggle(ESPMasterPanel, TOGGLE_OFF, 120, 52, config.killerESP, function(v)
	config.killerESP = v; refreshAll()
end)

-- ============================================================
-- RENDER PANEL
-- ============================================================
local ESPRenderPanel = makePanel(VisualsScrollingFrame, "ESPRenderPanel", 178, 0, 160, 225)
local ESP_Render = makeLabel(ESPRenderPanel, "ESP_Render", "   ESP Render", 0, 0, 14, Color3.fromRGB(200, 200, 200))
ESP_Render.Size = UDim2.new(0, 160, 0, 25)

makeLabel(ESPRenderPanel, "Subject",   "   Subject",   5, 25)
makeLabel(ESPRenderPanel, "Box",       "   Box!",      5, 50, 14, Color3.fromRGB(255, 170, 0))
makeLabel(ESPRenderPanel, "Off_Screen","   Off Screen!",5, 75, 14, Color3.fromRGB(255, 170, 0))
makeLabel(ESPRenderPanel, "Tracer",    "   Tracer!",   5, 100, 14, Color3.fromRGB(255, 170, 0))
makeLabel(ESPRenderPanel, "Skeleton",  "   Skeleton!", 5, 125, 14, Color3.fromRGB(255, 170, 0))
makeLabel(ESPRenderPanel, "DName",     "   DName",     5, 150)
makeLabel(ESPRenderPanel, "UName",     "   UName!",    5, 175, 14, Color3.fromRGB(255, 170, 0))
makeLabel(ESPRenderPanel, "Avatar",    "   Avatar!",   5, 200, 14, Color3.fromRGB(255, 170, 0))

-- Subject switch
local subjToggle = Instance.new("Frame")
subjToggle.Size = UDim2.new(0, 82, 0, 20)
subjToggle.Position = UDim2.new(0, 73, 0, 27)
subjToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
subjToggle.BorderSizePixel = 0
subjToggle.Active = true
subjToggle.Parent = ESPRenderPanel
corner(subjToggle, 30)

local subjInner = Instance.new("Frame")
subjInner.Size = UDim2.new(0, 40, 0, 18)
subjInner.Position = UDim2.new(0, 1, 0, 1)
subjInner.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
subjInner.BackgroundTransparency = 0.5
subjInner.BorderSizePixel = 0
subjInner.Parent = subjToggle
corner(subjInner, 30)

local killerLbl = Instance.new("TextLabel")
killerLbl.Size = UDim2.new(0, 40, 0, 20)
killerLbl.BackgroundTransparency = 1
killerLbl.Text = "Killer"
killerLbl.TextColor3 = Color3.new(1, 1, 1)
killerLbl.TextSize = 11
killerLbl.FontFace = font(11)
killerLbl.Parent = subjToggle

local playerLbl = Instance.new("TextLabel")
playerLbl.Size = UDim2.new(0, 40, 0, 20)
playerLbl.Position = UDim2.new(0, 40, 0, 0)
playerLbl.BackgroundTransparency = 1
playerLbl.Text = "player"
playerLbl.TextColor3 = Color3.new(1, 1, 1)
playerLbl.TextSize = 11
playerLbl.FontFace = font(11)
playerLbl.Parent = subjToggle

-- ============================================================
-- REFS
-- ============================================================
local togglesRefs = {}
local colorsRefs = {}

local function currentCfg()
	return config.subject == "Killer" and config.killer or config.players
end

local function regToggle(key, frame, setState)
	togglesRefs[key] = frame
	togglesRefs[key.."SetState"] = setState
end
local function regColor(key, setColor)
	colorsRefs[key] = true
	colorsRefs[key.."SetColor"] = setColor
end

local function syncPanelWithSubject()
	local tc = currentCfg()
	local function sT(key, v)
		local s = togglesRefs[key.."SetState"]
		if s then s(v, false) end
	end
	local function sC(key, c)
		local s = colorsRefs[key.."SetColor"]
		if s then s(c) end
	end

	sT("box",       tc.box.enabled)
	sT("offScreen", tc.offScreen.enabled)
	sT("tracer",    tc.tracer.enabled)
	sT("skeleton",  tc.skeleton.enabled)
	sT("dName",     tc.dName.enabled)
	sT("uName",     tc.uName.enabled)
	sT("avatar",    tc.avatar.enabled)
	sT("stroke",    tc.stroke.enabled)
	sT("fill",      tc.fill.enabled)

	sC("box",       tc.box.color)
	sC("offScreen", tc.offScreen.color)
	sC("tracer",    tc.tracer.color)
	sC("skeleton",  tc.skeleton.color)
	sC("dName",     tc.dName.color)
	sC("uName",     tc.uName.color)
	sC("stroke",    tc.stroke.color)
	sC("fill",      tc.fill.color)
end

-- ============================================================
-- RENDER toggles
-- ============================================================
local tBox, sBox = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 52, currentCfg().box.enabled,
	function(v) currentCfg().box.enabled = v end, true)
regToggle("box", tBox, sBox)

local tOS, sOS = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 77, currentCfg().offScreen.enabled,
	function(v) currentCfg().offScreen.enabled = v end, true)
regToggle("offScreen", tOS, sOS)

local tTr, sTr = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 102, currentCfg().tracer.enabled,
	function(v) currentCfg().tracer.enabled = v end, true)
regToggle("tracer", tTr, sTr)

local tSk, sSk = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 127, currentCfg().skeleton.enabled,
	function(v) currentCfg().skeleton.enabled = v end, true)
regToggle("skeleton", tSk, sSk)

local tDN, sDN = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 152, currentCfg().dName.enabled,
	function(v) currentCfg().dName.enabled = v end)
regToggle("dName", tDN, sDN)

local tUN, sUN = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 177, currentCfg().uName.enabled,
	function(v) currentCfg().uName.enabled = v end, true)
regToggle("uName", tUN, sUN)

local tAv, sAv = makeToggle(ESPRenderPanel, TOGGLE_OFF, 120, 202, currentCfg().avatar.enabled,
	function(v) currentCfg().avatar.enabled = v end, true)
regToggle("avatar", tAv, sAv)

local _, setBoxColor = makeColorButton(ESPRenderPanel, currentCfg().box.color, 98, 52,
	function() return currentCfg().box.transparency end,
	function(c, a) currentCfg().box.color = c; currentCfg().box.transparency = a or 0 end)
regColor("box", setBoxColor)

local _, setOSColor = makeColorButton(ESPRenderPanel, currentCfg().offScreen.color, 98, 78,
	function() return currentCfg().offScreen.transparency end,
	function(c, a) currentCfg().offScreen.color = c; currentCfg().offScreen.transparency = a or 0 end)
regColor("offScreen", setOSColor)

local _, setTrColor = makeColorButton(ESPRenderPanel, currentCfg().tracer.color, 98, 103,
	function() return currentCfg().tracer.transparency end,
	function(c, a) currentCfg().tracer.color = c; currentCfg().tracer.transparency = a or 0 end)
regColor("tracer", setTrColor)

local _, setSkColor = makeColorButton(ESPRenderPanel, currentCfg().skeleton.color, 98, 128,
	function() return currentCfg().skeleton.transparency end,
	function(c, a) currentCfg().skeleton.color = c; currentCfg().skeleton.transparency = a or 0 end)
regColor("skeleton", setSkColor)

local _, setDNColor = makeColorButton(ESPRenderPanel, currentCfg().dName.color, 98, 153,
	function() return currentCfg().dName.transparency end,
	function(c, a) currentCfg().dName.color = c; currentCfg().dName.transparency = a or 0 end)
regColor("dName", setDNColor)

local _, setUNColor = makeColorButton(ESPRenderPanel, currentCfg().uName.color, 98, 178,
	function() return currentCfg().uName.transparency end,
	function(c, a) currentCfg().uName.color = c; currentCfg().uName.transparency = a or 0 end)
regColor("uName", setUNColor)

-- ============================================================
-- HIGHLIGHT PANEL
-- ============================================================
local ESPHightlightPanel = makePanel(VisualsScrollingFrame, "ESPHightlightPanel", 9, 84, 160, 75)
local ESP_Hightlight = makeLabel(ESPHightlightPanel, "ESP_Hightlight", "   ESP Highlight", 0, 0, 14, Color3.fromRGB(200, 200, 200))
ESP_Hightlight.Size = UDim2.new(0, 160, 0, 25)
makeLabel(ESPHightlightPanel, "Stroke", "   Stroke", 5, 25)
makeLabel(ESPHightlightPanel, "Fill",   "   Fill",   5, 50)

local tSt, sSt = makeToggle(ESPHightlightPanel, TOGGLE_OFF, 120, 27, currentCfg().stroke.enabled,
	function(v) currentCfg().stroke.enabled = v; refreshAll() end)
regToggle("stroke", tSt, sSt)

local tFi, sFi = makeToggle(ESPHightlightPanel, TOGGLE_OFF, 120, 52, currentCfg().fill.enabled,
	function(v) currentCfg().fill.enabled = v; refreshAll() end)
regToggle("fill", tFi, sFi)

local _, setStrokeColor = makeColorButton(ESPHightlightPanel, currentCfg().stroke.color, 98, 28,
	function() return currentCfg().stroke.transparency end,
	function(c, a) currentCfg().stroke.color = c; currentCfg().stroke.transparency = a or 0; refreshAll() end)
regColor("stroke", setStrokeColor)

local _, setFillColor = makeColorButton(ESPHightlightPanel, currentCfg().fill.color, 98, 53,
	function() return currentCfg().fill.transparency end,
	function(c, a) currentCfg().fill.color = c; currentCfg().fill.transparency = a or 0; refreshAll() end)
regColor("fill", setFillColor)

-- ============================================================
-- SUBJECT SWITCH
-- ============================================================
subjToggle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isClickInsideColorPicker(input) then return end

		if config.subject == "Killer" then
			config.subject = "player"
			TweenService:Create(subjInner, TWEEN_INFO, { Position = UDim2.new(0, 41, 0, 1) }):Play()
		else
			config.subject = "Killer"
			TweenService:Create(subjInner, TWEEN_INFO, { Position = UDim2.new(0, 1, 0, 1) }):Play()
		end
		syncPanelWithSubject()
	end
end)

-- ============================================================
-- SETTINGS (заглушки)
-- ============================================================
local WinDesign = makePanel(SettingsScrollingFrame, "Window&Design", 9, 0, 329, 125)
local WinDesignTitle = makeLabel(WinDesign, "Title", "   Window&Design (UPD)", 0, 0, 14, Color3.fromRGB(200, 200, 200))
WinDesignTitle.Size = UDim2.new(0, 160, 0, 25)
makeLabel(WinDesign, "Size", "   Size", 5, 25)
makeLabel(WinDesign, "Language", "   Language", 5, 50)
makeLabel(WinDesign, "Colour", "   Colour", 5, 75)
makeLabel(WinDesign, "Show_FPS", "   Show Stats", 5, 100)

local InfoSub = makePanel(SettingsScrollingFrame, "Info", 9, 134, 329, 150)
local InfoTitle = makeLabel(InfoSub, "Title", "   Info&Subscription", 0, 0, 14, Color3.fromRGB(200, 200, 200))
InfoTitle.Size = UDim2.new(0, 160, 0, 25)
local infoLabels = {
	{Text="   Version 1.0 ALPHA", Y=25, Color=Color3.fromRGB(255, 170, 0)},
	{Text="   Violence District", Y=50, Color=Color3.fromRGB(0, 150, 255)},
	{Text="   Subscription is active", Y=75, Color=Color3.fromRGB(0, 255, 0)},
	{Text="   Expires on November 21", Y=100, Color=Color3.fromRGB(0, 255, 0)},
	{Text="   Full set of the script", Y=125, Color=Color3.fromRGB(0, 255, 0)},
}
for i, il in ipairs(infoLabels) do
	local lbl = makeLabel(InfoSub, "Info"..i, il.Text, 5, il.Y, 14, il.Color)
	lbl.Size = UDim2.new(0, 163, 0, 25)
end

-- ============================================================
-- TAB SWITCH
-- ============================================================
local indicatorTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

VisualsButton.MouseButton1Click:Connect(function()
	-- Visuals всегда активна
end)

-- ============================================================
-- EXIT
-- ============================================================
local ExitWindow = Instance.new("Frame")
ExitWindow.Size = UDim2.new(0, 200, 0, 130)
ExitWindow.Position = UDim2.new(0, 125, 0, 85)
ExitWindow.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ExitWindow.Visible = false
ExitWindow.BorderSizePixel = 0
ExitWindow.Parent = Main
corner(ExitWindow, 12)

local QuitLabel = Instance.new("TextLabel")
QuitLabel.Size = UDim2.new(0, 200, 0, 30)
QuitLabel.BackgroundTransparency = 1
QuitLabel.Text = "Quit?"
QuitLabel.TextColor3 = Color3.new(1, 1, 1)
QuitLabel.TextSize = 27
QuitLabel.FontFace = font(27)
QuitLabel.Parent = ExitWindow

local DescLabel = Instance.new("TextLabel")
DescLabel.Size = UDim2.new(0, 180, 0, 50)
DescLabel.Position = UDim2.new(0, 10, 0, 30)
DescLabel.BackgroundTransparency = 1
DescLabel.Text = "Do you want to close this script and remove it from the game?"
DescLabel.TextColor3 = Color3.new(1, 1, 1)
DescLabel.TextSize = 14
DescLabel.FontFace = font(14)
DescLabel.TextWrapped = true
DescLabel.Parent = ExitWindow

local StayButton = Instance.new("TextButton")
StayButton.Size = UDim2.new(0, 85, 0, 30)
StayButton.Position = UDim2.new(0, 10, 0, 90)
StayButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
StayButton.Text = "Stay"
StayButton.TextColor3 = Color3.fromRGB(220, 220, 220)
StayButton.TextSize = 18
StayButton.FontFace = font(18)
StayButton.Parent = ExitWindow
corner(StayButton, 8)
stroke(StayButton, Color3.fromRGB(100, 100, 100), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local ConfirmButton = Instance.new("TextButton")
ConfirmButton.Size = UDim2.new(0, 85, 0, 30)
ConfirmButton.Position = UDim2.new(0, 105, 0, 90)
ConfirmButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
ConfirmButton.Text = "Confirm"
ConfirmButton.TextColor3 = Color3.fromRGB(220, 220, 220)
ConfirmButton.TextSize = 18
ConfirmButton.FontFace = font(18)
ConfirmButton.Parent = ExitWindow
corner(ConfirmButton, 8)
stroke(ConfirmButton, Color3.fromRGB(100, 100, 100), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

CloseScript.MouseButton1Click:Connect(function() ExitWindow.Visible = true end)
StayButton.MouseButton1Click:Connect(function() ExitWindow.Visible = false end)

-- ⚡ Улучшенная очистка при Confirm
ConfirmButton.MouseButton1Click:Connect(function()
	for _, h in pairs(highlights) do
		if h and typeof(h) == "Instance" then
			pcall(function() h:Destroy() end)
		end
	end
	highlights = {}

	-- Добить все ESP_Highlight на персонажах
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			for _, obj in ipairs(char:GetChildren()) do
				if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
					pcall(function() obj:Destroy() end)
				end
			end
		end
	end

	for _, objs in pairs(espObjects) do
		for _, v in pairs(objs) do
			if typeof(v) == "Instance" then v:Destroy()
			elseif type(v) == "table" then
				for _, v2 in pairs(v) do
					if typeof(v2) == "Instance" then v2:Destroy() end
				end
			end
		end
	end
	espObjects = {}

	screenGui:Destroy()
end)

-- ⚡ Авто-очистка при уничтожении GUI (X экзекутора, кик, рестарт)
if screenGui then
	screenGui.Destroying:Connect(function()
		for plr, h in pairs(highlights) do
			if h and typeof(h) == "Instance" and h.Parent then
				pcall(function() h:Destroy() end)
			end
		end
		highlights = {}

		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			if char then
				for _, obj in ipairs(char:GetChildren()) do
					if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
						pcall(function() obj:Destroy() end)
					end
				end
			end
		end

		for _, objs in pairs(espObjects) do
			for _, v in pairs(objs) do
				if typeof(v) == "Instance" then
					pcall(function() v:Destroy() end)
				elseif type(v) == "table" then
					for _, v2 in pairs(v) do
						if typeof(v2) == "Instance" then
							pcall(function() v2:Destroy() end)
						end
					end
				end
			end
		end
		espObjects = {}
	end)
end

-- ============================================================
-- COLOR PICKER
-- ============================================================
ColorPicker = Instance.new("Frame")
ColorPicker.Size = UDim2.new(0, 200, 0, 235)
ColorPicker.Position = UDim2.new(0, 250, 0, 100)
ColorPicker.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ColorPicker.BackgroundTransparency = 0
ColorPicker.Visible = false
ColorPicker.Active = true
ColorPicker.BorderSizePixel = 0
ColorPicker.ZIndex = 10
ColorPicker.Parent = screenGui
corner(ColorPicker, 10)

local SetColour = Instance.new("TextLabel")
SetColour.Name = "Set_colour"
SetColour.Size = UDim2.new(1, -20, 0, 22)
SetColour.Position = UDim2.new(0, 10, 0, 6)
SetColour.BackgroundTransparency = 1
SetColour.Text = "Set colour"
SetColour.TextColor3 = Color3.fromRGB(230, 230, 230)
SetColour.TextSize = 15
SetColour.FontFace = font(15)
SetColour.TextXAlignment = Enum.TextXAlignment.Left
SetColour.Parent = ColorPicker

local svArea = Instance.new("Frame")
svArea.Size = UDim2.new(0, 125, 0, 105)
svArea.Position = UDim2.new(0, 10, 0, 32)
svArea.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
svArea.BorderSizePixel = 0
svArea.Active = true
svArea.Parent = ColorPicker
corner(svArea, 6)
stroke(svArea, Color3.fromRGB(70, 70, 70), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local svWhite = Instance.new("Frame")
svWhite.Size = UDim2.new(1, 0, 1, 0)
svWhite.BackgroundColor3 = Color3.new(1, 1, 1)
svWhite.BorderSizePixel = 0
svWhite.Parent = svArea
corner(svWhite, 4)

local svWhiteGrad = Instance.new("UIGradient")
svWhiteGrad.Rotation = 0
svWhiteGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})
svWhiteGrad.Parent = svWhite

local svBlack = Instance.new("Frame")
svBlack.Size = UDim2.new(1, 0, 1, 0)
svBlack.BackgroundColor3 = Color3.new(0, 0, 0)
svBlack.BorderSizePixel = 0
svBlack.Parent = svArea
corner(svBlack, 4)

local svBlackGrad = Instance.new("UIGradient")
svBlackGrad.Rotation = 90
svBlackGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0),
})
svBlackGrad.Parent = svBlack

local svPicker = Instance.new("Frame")
svPicker.Size = UDim2.new(0, 12, 0, 12)
svPicker.AnchorPoint = Vector2.new(0.5, 0.5)
svPicker.BackgroundTransparency = 1
svPicker.Parent = svArea

local svDot = Instance.new("Frame")
svDot.Size = UDim2.new(1, 0, 1, 0)
svDot.BackgroundColor3 = Color3.new(1, 1, 1)
svDot.BorderSizePixel = 0
svDot.Parent = svPicker
corner(svDot, 10)

local hueBar = Instance.new("Frame")
hueBar.Size = UDim2.new(0, 18, 0, 105)
hueBar.Position = UDim2.new(0, 142, 0, 32)
hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
hueBar.BorderSizePixel = 0
hueBar.Active = true
hueBar.Parent = ColorPicker
corner(hueBar, 4)
stroke(hueBar, Color3.fromRGB(70, 70, 70), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local hueGradient = Instance.new("UIGradient")
hueGradient.Rotation = -90
hueGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 4)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 0)),
})
hueGradient.Parent = hueBar

local huePicker = Instance.new("Frame")
huePicker.Size = UDim2.new(1, 4, 0, 3)
huePicker.AnchorPoint = Vector2.new(0.5, 0.5)
huePicker.Position = UDim2.new(0.5, 0, 0, 0)
huePicker.BackgroundColor3 = Color3.new(1, 1, 1)
huePicker.BorderSizePixel = 0
huePicker.Parent = hueBar
corner(huePicker, 2)
stroke(huePicker, Color3.new(0, 0, 0), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local alphaBar = Instance.new("Frame")
alphaBar.Size = UDim2.new(0, 18, 0, 105)
alphaBar.Position = UDim2.new(0, 168, 0, 32)
alphaBar.BackgroundTransparency = 1
alphaBar.BorderSizePixel = 0
alphaBar.Active = true
alphaBar.Parent = ColorPicker
corner(alphaBar, 4)

local alphaChecker = Instance.new("ImageLabel")
alphaChecker.Size = UDim2.new(1, 0, 1, 0)
alphaChecker.BackgroundTransparency = 1
alphaChecker.Image = "rbxassetid://135630237073631"
alphaChecker.BorderSizePixel = 0
alphaChecker.Parent = alphaBar
corner(alphaChecker, 4)
stroke(alphaChecker, Color3.fromRGB(70, 70, 70), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local alphaFill = Instance.new("Frame")
alphaFill.Size = UDim2.new(1, 0, 1, 0)
alphaFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
alphaFill.BorderSizePixel = 0
alphaFill.Parent = alphaBar
corner(alphaFill, 4)

local alphaGrad = Instance.new("UIGradient")
alphaGrad.Rotation = 90
alphaGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})
alphaGrad.Parent = alphaFill

local alphaPicker = Instance.new("Frame")
alphaPicker.Size = UDim2.new(1, 4, 0, 3)
alphaPicker.AnchorPoint = Vector2.new(0.5, 0.5)
alphaPicker.Position = UDim2.new(0.5, 0, 0, 0)
alphaPicker.BackgroundColor3 = Color3.new(1, 1, 1)
alphaPicker.BorderSizePixel = 0
alphaPicker.Parent = alphaBar
corner(alphaPicker, 2)
stroke(alphaPicker, Color3.new(0, 0, 0), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local function makeSmallLabel(parent, text, posX, posY, width)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, width or 35, 0, 16)
	lbl.Position = UDim2.new(0, posX, 0, posY)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextSize = 14
	lbl.FontFace = font(14)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Parent = parent
	return lbl
end

makeSmallLabel(ColorPicker, "Hue", 10, 143)
makeSmallLabel(ColorPicker, "Sat", 52, 143)
makeSmallLabel(ColorPicker, "Val", 94, 143)
makeSmallLabel(ColorPicker, "Alp", 136, 143)

local function makeTextBox(parent, posX, posY, sizeX)
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(0, sizeX or 35, 0, 22)
	tb.Position = UDim2.new(0, posX, 0, posY)
	tb.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tb.BackgroundTransparency = 0.5
	tb.Text = ""
	tb.TextColor3 = Color3.new(1, 1, 1)
	tb.TextSize = 14
	tb.FontFace = font(14)
	tb.BorderSizePixel = 0
	tb.Parent = parent
	corner(tb, 4)
	return tb
end

local hueBox = makeTextBox(ColorPicker, 10, 161, 36)
local satBox = makeTextBox(ColorPicker, 52, 161, 36)
local valBox = makeTextBox(ColorPicker, 94, 161, 36)
local alpBox = makeTextBox(ColorPicker, 136, 161, 36)

makeSmallLabel(ColorPicker, "HEX", 10, 187, 60)
local hexBox = makeTextBox(ColorPicker, 10, 204, 70)
hexBox.Size = UDim2.new(0, 70, 0, 22)

local cpConfirm = Instance.new("TextButton")
cpConfirm.Size = UDim2.new(0, 85, 0, 26)
cpConfirm.Position = UDim2.new(1, -10, 1, -8)
cpConfirm.AnchorPoint = Vector2.new(1, 1)
cpConfirm.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
cpConfirm.Text = "Confirm"
cpConfirm.TextColor3 = Color3.fromRGB(220, 220, 220)
cpConfirm.TextSize = 17
cpConfirm.FontFace = font(17)
cpConfirm.BorderSizePixel = 0
cpConfirm.AutoButtonColor = false
cpConfirm.Parent = ColorPicker
corner(cpConfirm, 8)
stroke(cpConfirm, Color3.fromRGB(100, 100, 100), 1.5, 0.75, Enum.ApplyStrokeMode.Border)

local cpState = { hue = 0, sat = 1, val = 1, alpha = 0, target = nil }
local updatingBoxes = false

local function cpGetColor()
	return Color3.fromHSV(cpState.hue / 360, cpState.sat, cpState.val)
end

local function cpUpdateUI()
	local color = cpGetColor()
	local hueColor = Color3.fromHSV(cpState.hue / 360, 1, 1)

	svArea.BackgroundColor3 = hueColor
	alphaFill.BackgroundColor3 = color

	svPicker.Position = UDim2.new(cpState.sat, 0, 1 - cpState.val, 0)
	huePicker.Position = UDim2.new(0.5, 0, cpState.hue / 360, 0)
	alphaPicker.Position = UDim2.new(0.5, 0, cpState.alpha, 0)

	updatingBoxes = true
	hueBox.Text = tostring(math.floor(cpState.hue + 0.5))
	satBox.Text = tostring(math.floor(cpState.sat * 100 + 0.5))
	valBox.Text = tostring(math.floor(cpState.val * 100 + 0.5))
	alpBox.Text = tostring(math.floor(cpState.alpha * 100 + 0.5))
	local r = math.floor(color.R * 255 + 0.5)
	local g = math.floor(color.G * 255 + 0.5)
	local b = math.floor(color.B * 255 + 0.5)
	hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
	updatingBoxes = false
end

openColorPicker = function(currentColor, callback, initialAlpha, sourceButton)
	cpState.target = callback
	local h, s, v = Color3.toHSV(currentColor)
	cpState.hue = h * 360
	cpState.sat = s
	cpState.val = v
	cpState.alpha = initialAlpha or 0

	if sourceButton and sourceButton.Parent then
		local absPos   = sourceButton.AbsolutePosition
		local absSize  = sourceButton.AbsoluteSize
		local viewport = Workspace.CurrentCamera.ViewportSize
		local pickerSize = Vector2.new(200, 235)

		local targetX = absPos.X + absSize.X + 80
		local targetY = absPos.Y - 10

		if targetX + pickerSize.X > viewport.X then
			targetX = absPos.X - pickerSize.X - 80
		end
		if targetX < 0 then targetX = 10 end
		if targetY < 0 then targetY = 10 end
		if targetY + pickerSize.Y > viewport.Y then
			targetY = viewport.Y - pickerSize.Y - 10
		end

		ColorPicker.Position = UDim2.new(0, targetX, 0, targetY)
	end

	fadePanel(ColorPicker, false, 0.2)
	cpUpdateUI()
end

local draggingSV, draggingHue, draggingAlpha = false, false, false

local function updateSV(input)
	local relX = math.clamp((input.Position.X - svArea.AbsolutePosition.X) / svArea.AbsoluteSize.X, 0, 1)
	local relY = math.clamp((input.Position.Y - svArea.AbsolutePosition.Y) / svArea.AbsoluteSize.Y, 0, 1)
	cpState.sat = relX
	cpState.val = 1 - relY
	cpUpdateUI()
end
local function updateHue(input)
	local relY = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
	cpState.hue = relY * 360
	cpUpdateUI()
end
local function updateAlpha(input)
	local relY = math.clamp((input.Position.Y - alphaBar.AbsolutePosition.Y) / alphaBar.AbsoluteSize.Y, 0, 1)
	cpState.alpha = relY
	cpUpdateUI()
end

svArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSV = true; updateSV(input)
	end
end)
hueBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingHue = true; updateHue(input)
	end
end)
alphaBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingAlpha = true; updateAlpha(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateSV(input)
	elseif draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateHue(input)
	elseif draggingAlpha and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateAlpha(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSV, draggingHue, draggingAlpha = false, false, false
	end
end)

local function handleBoxFocusLost(box, minV, maxV, scale, setter)
	box.FocusLost:Connect(function()
		if updatingBoxes then return end
		local n = tonumber(box.Text)
		if n then
			n = math.clamp(n, minV, maxV)
			setter(n / scale)
			cpUpdateUI()
		else
			cpUpdateUI()
		end
	end)
end

handleBoxFocusLost(hueBox, 0, 360, 1, function(v) cpState.hue = v end)
handleBoxFocusLost(satBox, 0, 100, 100, function(v) cpState.sat = v end)
handleBoxFocusLost(valBox, 0, 100, 100, function(v) cpState.val = v end)
handleBoxFocusLost(alpBox, 0, 100, 100, function(v) cpState.alpha = v end)

hexBox.FocusLost:Connect(function()
	if updatingBoxes then return end
	local hex = hexBox.Text:gsub("#", "")
	if #hex == 6 then
		local r = tonumber(hex:sub(1,2), 16)
		local g = tonumber(hex:sub(3,4), 16)
		local b = tonumber(hex:sub(5,6), 16)
		if r and g and b then
			local color = Color3.fromRGB(r, g, b)
			local h, s, v = Color3.toHSV(color)
			cpState.hue = h * 360
			cpState.sat = s
			cpState.val = v
			cpUpdateUI()
			return
		end
	end
	cpUpdateUI()
end)

cpConfirm.MouseButton1Click:Connect(function()
	if cpState.target then cpState.target(cpGetColor(), cpState.alpha) end
	fadePanel(ColorPicker, true, 0.2)
end)

-- ============================================================
-- STATS
-- ============================================================
local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 200, 0, 60)
StatsFrame.Position = UDim2.new(0, 5, 1, -5)
StatsFrame.AnchorPoint = Vector2.new(0, 1)
StatsFrame.BackgroundTransparency = 1
StatsFrame.Parent = screenGui

local function makeStatLabel(parent, text, posY)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 200, 0, 15)
	lbl.Position = UDim2.new(0, 0, 0, posY)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(255, 0, 0)
	lbl.TextSize = 15
	lbl.Font = Enum.Font.Code
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

local fpsLbl    = makeStatLabel(StatsFrame, "fps: 0", 0)
local memLbl    = makeStatLabel(StatsFrame, "memory: 0", 15)
local pingLbl   = makeStatLabel(StatsFrame, "ping: 0", 30)
local timeLbl   = makeStatLabel(StatsFrame, "hh:mm:ss", 45)
timeLbl.TextColor3 = Color3.fromRGB(255, 255, 255)

local RED    = Color3.fromRGB(255, 0, 0)
local ORANGE = Color3.fromRGB(255, 165, 0)
local GREEN  = Color3.fromRGB(0, 255, 0)

local function getFPSColor(fps)
	if fps < 41 then return RED
	elseif fps < 76 then return ORANGE
	else return GREEN end
end
local function getPingColor(ping)
	if ping < 71 then return GREEN
	elseif ping < 101 then return ORANGE
	else return RED end
end
local function getMemoryColor(mem)
	if mem < 4501 then return GREEN
	elseif mem < 7501 then return ORANGE
	else return RED end
end

local fpsFrames = 0
local fpsTimer = 0
local currentFPS = 0
RunService.Heartbeat:Connect(function(dt)
	fpsFrames += 1
	fpsTimer += dt
	if fpsTimer >= 0.5 then
		currentFPS = math.floor(fpsFrames / fpsTimer)
		fpsFrames = 0
		fpsTimer = 0
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		fpsLbl.Text = "fps: " .. currentFPS
		fpsLbl.TextColor3 = getFPSColor(currentFPS)

		local ping = 0
		pcall(function()
			ping = math.floor(player:GetNetworkPing() * 1000)
		end)
		pingLbl.Text = "ping: " .. ping
		pingLbl.TextColor3 = getPingColor(ping)

		local memory = math.floor(Stats:GetTotalMemoryUsageMb())
		memLbl.Text = "memory: " .. memory
		memLbl.TextColor3 = getMemoryColor(memory)

		timeLbl.Text = os.date("%H:%M:%S")
	end
end)

-- ============================================================
-- ПЛАВНОЕ ПЕРЕТАСКИВАНИЕ
-- ============================================================
local activeDrags = {}

RunService.RenderStepped:Connect(function(dt)
	for target, data in pairs(activeDrags) do
		if not target.Parent then
			activeDrags[target] = nil
			continue
		end
		local tp = data.targetPos
		if not tp then continue end

		local current = target.Position
		local alpha = 1 - math.exp(-dt * data.speed)
		local newX = current.X.Offset + (tp.X.Offset - current.X.Offset) * alpha
		local newY = current.Y.Offset + (tp.Y.Offset - current.Y.Offset) * alpha

		target.Position = UDim2.new(current.X.Scale, newX, current.Y.Scale, newY)

		if math.abs(tp.X.Offset - newX) < 0.5 and math.abs(tp.Y.Offset - newY) < 0.5 then
			target.Position = tp
			activeDrags[target] = nil
		end
	end
end)

local function isPointInside(guiObj, point)
	if not guiObj or not guiObj.Parent or not guiObj.Visible then return false end
	local p = guiObj.AbsolutePosition
	local s = guiObj.AbsoluteSize
	return point.X >= p.X and point.X <= p.X + s.X
		and point.Y >= p.Y and point.Y <= p.Y + s.Y
end

local mainDragging = false
local mainDragStart = nil
local mainStartPos = nil

Main.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		local pos = Vector2.new(input.Position.X, input.Position.Y)

		if ColorPicker.Visible and isPointInside(ColorPicker, pos) then
			return
		end

		if ColorPicker.Visible then
			local clickedOnColorButton = false
			for _, btn in ipairs(allColorButtons) do
				if isPointInside(btn, pos) then
					clickedOnColorButton = true
					break
				end
			end
			if not clickedOnColorButton then
				fadePanel(ColorPicker, true, 0.15)
			end
		end

		mainDragging = true
		mainDragStart = input.Position
		mainStartPos = Main.Position
		activeDrags[Main] = {
			targetPos = Main.Position,
			speed = 18,
		}
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if mainDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - mainDragStart
		local newPos = UDim2.new(
			mainStartPos.X.Scale, mainStartPos.X.Offset + delta.X,
			mainStartPos.Y.Scale, mainStartPos.Y.Offset + delta.Y
		)
		if activeDrags[Main] then
			activeDrags[Main].targetPos = newPos
		else
			activeDrags[Main] = { targetPos = newPos, speed = 18 }
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		mainDragging = false
		task.delay(0.4, function()
			if not mainDragging and activeDrags[Main] then
				activeDrags[Main] = nil
			end
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if not ColorPicker.Visible then return end

	local pos = Vector2.new(input.Position.X, input.Position.Y)

	if isPointInside(ColorPicker, pos) then return end

	for _, btn in ipairs(allColorButtons) do
		if isPointInside(btn, pos) then return end
	end

	fadePanel(ColorPicker, true, 0.15)
end)

-- ============================================================
-- EVENTS
-- ============================================================
Players.PlayerAdded:Connect(function(plr)
	setupESP(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.5)
		updateHighlight(plr)
	end)
	updateHighlight(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	if highlights[plr] then
		highlights[plr]:Destroy()
		highlights[plr] = nil
	end
	cleanupESP(plr)
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	refreshAll()
end)

task.spawn(function()
	while task.wait(1) do refreshAll() end
end)

-- ============================================================
-- INIT
-- ============================================================
syncPanelWithSubject()
for _, plr in ipairs(Players:GetPlayers()) do
	updateHighlight(plr)
	setupESP(plr)
end

local function elevateZIndex(root, baseZ)
	local function scan(obj)
		if obj:IsA("GuiObject") then
			obj.ZIndex = baseZ + 1
		end
		for _, child in ipairs(obj:GetChildren()) do
			scan(child)
		end
	end
	scan(root)
end
elevateZIndex(ColorPicker, 10)

print("MoonLight: Dasha v1.2.1 Successfully")

-- ============================================================
-- SMOOTH HIDE / SHOW
-- ============================================================
local mainHidden = false
local mainTweening = false

local function toggleMainWindow()
	if mainTweening then return end
	mainTweening = true

	if mainHidden then
		mainHidden = false
		fadePanel(Main, false, 0.10, function()
			mainTweening = false
		end)
	else
		mainHidden = true
		fadePanel(Main, true, 0.10, function()
			mainTweening = false
		end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		toggleMainWindow()
	end
end)

-- ============================================================
-- ⚡ CURSOR TOGGLE (клавиша B) — свободный курсор во время игры
-- ============================================================
local cursorUnlocked = false

RunService.RenderStepped:Connect(function()
	if cursorUnlocked then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		cursorUnlocked = not cursorUnlocked

		if cursorUnlocked then
			UserInputService.MouseIconEnabled = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		else
			UserInputService.MouseIconEnabled = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
end)
