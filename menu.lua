local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- хелпер для плавных переходов
local function tween(obj, props, dur)
	local t = TweenService:Create(obj,
		TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props)
	t:Play()
	return t
end

local ON_COLOR = Color3.fromRGB(0, 150, 0)
local OFF_COLOR = Color3.fromRGB(120, 40, 40)

----------------------------------------------------------------
-- ЗАГРУЗКА (без фона, поверх игры)
----------------------------------------------------------------
local loadGui = Instance.new("ScreenGui")
loadGui.Name = "LoadingScreen"
loadGui.IgnoreGuiInset = true
loadGui.DisplayOrder = 999
loadGui.ResetOnSpawn = false
loadGui.Parent = game.CoreGui

local loadText = Instance.new("TextLabel")
loadText.AnchorPoint = Vector2.new(0.5, 0.5)
loadText.Position = UDim2.new(0.5, 0, 0.45, -15)
loadText.Size = UDim2.fromOffset(400, 50)
loadText.BackgroundTransparency = 1
loadText.Text = "LOADING"
loadText.Font = Enum.Font.GothamBold
loadText.TextSize = 34
loadText.TextColor3 = Color3.new(1, 1, 1)
loadText.TextStrokeTransparency = 0.6
loadText.Parent = loadGui

local loadGrad = Instance.new("UIGradient")
loadGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 170)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
}
loadGrad.Parent = loadText

task.spawn(function()
	local dots = 0
	local t = 0
	while loadGui.Parent do
		dots = (dots + 1) % 4
		loadText.Text = "LOADING" .. string.rep(".", dots)
		t += task.wait(1)
		loadGrad.Offset = Vector2.new(math.sin(t * 2) * 0.5, 0)
	end
end)

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.new(0.5, 0, 0.45, 30)
barBack.Size = UDim2.fromOffset(260, 8)
barBack.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
barBack.BackgroundTransparency = 0.3
barBack.BorderSizePixel = 0
barBack.Parent = loadGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 170)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

-- СТРАХОВКА: если что-то пойдёт не так, загрузка всё равно закроется
task.spawn(function()
	task.wait(3)
	if loadGui.Parent then
		warn("[MergedMenu] Загрузка закрыта принудительно (смотри ошибки в консоли F9)")
		loadGui:Destroy()
	end
end)

----------------------------------------------------------------
-- ВСЯ ОСНОВНАЯ ЛОГИКА — внутри init(), чтобы ошибка не вешала загрузку
----------------------------------------------------------------
local Frame

local function init()
	tween(barFill, {Size = UDim2.fromScale(1, 1)}, 0.6) -- полоска бежит 0.6 сек

	local S = {
		items = {
			enabled = false,
			targets = {
				["USP Match"] = true,
				["SMG"] = true,
				["Remington 870"] = true,
				["SPAS-12"] = true,
				["AR2"] = true,
				["Colt Python"] = true,
			},
		},
		zombies = {
			enabled = false,
			targets = {
				["ClassicHeadcrab"] = true,
				["FastHeadcrab"] = true,
				["FastZombie"] = true,
				["ClassicZombie"] = true,
				["PoisonHeadcrab"] = true,
			},
		},
		hitbox = {
			enabled = false,
			size = 5,
			min = 1,
			max = 6,
		},
		esp = {
			enabled = false,
			hp = true,
			names = true,
			teamColor = true,
			direction = false,
			transparency = 0.5,
		},
		head = {
			enabled = false,
			size = 2.9,
			min = 0.5,
			max = 6,
		},
		keybind = {
			key = Enum.KeyCode.L,
			waiting = false,
		},
	}

	-- список выделенных по нику игроков (нужен и ESP, и модулю выделения)
	local highlightedPlayers = {} -- [Name] = true

	----------------------------------------------------------------
	-- МОДУЛЬ 1: ПОДСВЕТКА ОРУЖИЯ (Items)
	----------------------------------------------------------------
	local itemsFolder = nil

	local function itemScan(folder)
		for _, item in ipairs(folder:GetChildren()) do
			if S.items.targets[item.Name] then
				local h = item:FindFirstChild("ItemHighlight")
				if not h then
					h = Instance.new("Highlight")
					h.Name = "ItemHighlight"
					h.FillColor = Color3.fromRGB(0, 255, 255)
					h.OutlineColor = Color3.fromRGB(0, 255, 0)
					h.FillTransparency = 0.5
					h.OutlineTransparency = 0
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = item
				end
				h.Enabled = S.items.enabled
			end
		end
	end

	local function setItemsEnabled(value)
		S.items.enabled = value
		if itemsFolder then itemScan(itemsFolder) end
	end

	task.spawn(function()
		itemsFolder = Workspace:WaitForChild("Items", 10)
		if itemsFolder then
			itemScan(itemsFolder)
			itemsFolder.ChildAdded:Connect(function(item)
				if S.items.targets[item.Name] then
					task.defer(itemScan, itemsFolder)
				end
			end)
			itemsFolder.ChildRemoved:Connect(function(item)
				local h = item:FindFirstChild("ItemHighlight")
				if h then h:Destroy() end
			end)
		end
	end)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Items" then
			task.wait(0.1)
			itemsFolder = child
			itemScan(child)
		end
	end)

	----------------------------------------------------------------
	-- МОДУЛЬ 4: ПОДСВЕТКА ЗОМБИ (Zombies)
	----------------------------------------------------------------
	local zombiesFolder = nil

	local function zombieScan(folder)
		for _, z in ipairs(folder:GetChildren()) do
			if S.zombies.targets[z.Name] then
				local h = z:FindFirstChild("ZombieHighlight")
				if not h then
					h = Instance.new("Highlight")
					h.Name = "ZombieHighlight"
					h.FillColor = Color3.fromRGB(255, 40, 90)
					h.OutlineColor = Color3.fromRGB(170, 0, 255)
					h.FillTransparency = 0.5
					h.OutlineTransparency = 0
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = z
				end
				h.Enabled = S.zombies.enabled
			end
		end
	end

	local function setZombiesEnabled(value)
		S.zombies.enabled = value
		if zombiesFolder then zombieScan(zombiesFolder) end
	end

	task.spawn(function()
		zombiesFolder = Workspace:WaitForChild("Zombies", 10)
		if zombiesFolder then
			zombieScan(zombiesFolder)
			zombiesFolder.ChildAdded:Connect(function(z)
				if S.zombies.targets[z.Name] then
					task.defer(zombieScan, zombiesFolder)
				end
			end)
			zombiesFolder.ChildRemoved:Connect(function(z)
				local h = z:FindFirstChild("ZombieHighlight")
				if h then h:Destroy() end
			end)
		end
	end)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Zombies" then
			task.wait(0.1)
			zombiesFolder = child
			zombieScan(child)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if zombiesFolder and zombiesFolder.Parent then
				for _, z in ipairs(zombiesFolder:GetChildren()) do
					if S.zombies.targets[z.Name] then
						local h = z:FindFirstChild("ZombieHighlight")
						if not h then
							zombieScan(zombiesFolder)
						elseif h.Enabled ~= S.zombies.enabled then
							h.Enabled = S.zombies.enabled
						end
					end
				end
			end
		end
	end)

	----------------------------------------------------------------
	-- МОДУЛЬ 5: ХИТБОКС ЗОМБИ (увеличение зоны попадания)
	----------------------------------------------------------------
	local function getZombieRoot(zombie)
		return zombie:FindFirstChild("HumanoidRootPart")
			or zombie:FindFirstChild("Torso")
			or zombie.PrimaryPart
	end

	local function setZombieHitbox(zombie, size)
		local root = getZombieRoot(zombie)
		if not root then return end
		pcall(function()
			if not root:GetAttribute("OriginalHitboxSize") then
				root:SetAttribute("OriginalHitboxSize", root.Size)
			end
			root.Size = Vector3.new(size, size, size)
			root.Transparency = 1
			root.CanCollide = false
			root.Massless = true
		end)
	end

	local function restoreZombieHitbox(zombie)
		local root = getZombieRoot(zombie)
		if not root then return end
		local orig = root:GetAttribute("OriginalHitboxSize")
		if orig then
			pcall(function()
				root.Size = orig
				root.CanCollide = true
			end)
		end
	end

	local function disableHitboxes()
		if zombiesFolder and zombiesFolder.Parent then
			for _, z in ipairs(zombiesFolder:GetChildren()) do
				restoreZombieHitbox(z)
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		if not S.hitbox.enabled then return end
		if zombiesFolder and zombiesFolder.Parent then
			for _, z in ipairs(zombiesFolder:GetChildren()) do
				if S.zombies.targets[z.Name] then
					setZombieHitbox(z, S.hitbox.size)
				end
			end
		end
	end)

	----------------------------------------------------------------
	-- МОДУЛЬ 2: ESP (подсветка игроков + HP, имена, направление взгляда)
	----------------------------------------------------------------
	local refreshers = {}

	local function getTeamColor(target)
		if target.Team then
			return target.Team.TeamColor.Color
		end
		return Color3.new(1, 1, 1)
	end

	local function addHighlight(character, target)
		local old = character:FindFirstChild("TeamHighlight")
		if old then old:Destroy() end

		local h = Instance.new("Highlight")
		h.Name = "TeamHighlight"
		h.FillColor = getTeamColor(target)
		h.OutlineColor = Color3.new(1, 1, 1)
		h.FillTransparency = S.esp.transparency
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Enabled = S.esp.enabled and not highlightedPlayers[target.Name]
		h.Parent = character
	end

	local function addHealthTag(character, target)
		local head = character:FindFirstChild("Head")
		if not head or head:FindFirstChild("TeamHealthTag") then return end
		local humanoid = character:WaitForChild("Humanoid", 5)
		head = character:WaitForChild("Head", 5)
		if not humanoid or not head then return end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TeamHealthTag"
		billboard.Size = UDim2.new(0, 150, 0, 22)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.AlwaysOnTop = true
		billboard.Enabled = S.esp.hp

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextSize = 12
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard

		local function update()
			if not humanoid.Parent then return end
			label.Text = "HP: " .. math.ceil(humanoid.Health)
				.. (S.esp.names and (" | " .. target.DisplayName) or "")
			label.TextColor3 = S.esp.teamColor and getTeamColor(target) or Color3.new(1, 1, 1)
		end

		humanoid.HealthChanged:Connect(update)
		humanoid.Died:Connect(update)
		update()
		refreshers[target] = update
		billboard.Parent = head
	end

	-- стрелка направления взгляда (видна сквозь стены)
	local function addLookArrow(character, target)
		local head = character:FindFirstChild("Head")
		if not head or head:FindFirstChild("LookArrow") then return end

		local arrow = Instance.new("Part")
		arrow.Name = "LookArrow"
		arrow.Size = Vector3.new(0.12, 0.12, 3)
		arrow.Material = Enum.Material.Neon
		arrow.Color = getTeamColor(target)
		arrow.Transparency = S.esp.direction and 0.35 or 1
		arrow.CanCollide = false
		arrow.CanQuery = false
		arrow.CanTouch = false
		arrow.Massless = true
		arrow.Parent = head

		local hl = Instance.new("Highlight")
		hl.Name = "LookArrowHighlight"
		hl.FillColor = getTeamColor(target)
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.2
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Enabled = S.esp.direction
		hl.Parent = arrow

		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = arrow
		weld.C0 = CFrame.new(0, 1.2, -1.8)
		weld.Parent = arrow
	end

	local function setupCharacter(character, target)
		addHighlight(character, target)
		addHealthTag(character, target)
		addLookArrow(character, target)
	end

	local function watchPlayer(target)
		target.CharacterAdded:Connect(function(character)
			setupCharacter(character, target)
		end)
		if target.Character then
			setupCharacter(target.Character, target)
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then watchPlayer(p) end
	end
	Players.PlayerAdded:Connect(watchPlayer)

	local function refreshESP()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				refreshers[p] = nil
				if p.Character then
					local c = p.Character
					local h = c:FindFirstChild("TeamHighlight")
					if h then h:Destroy() end
					local head = c:FindFirstChild("Head")
					if head then
						local tag = head:FindFirstChild("TeamHealthTag")
						if tag then tag:Destroy() end
						local arrow = head:FindFirstChild("LookArrow")
						if arrow then arrow:Destroy() end
					end
					setupCharacter(c, p)
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, target in ipairs(Players:GetPlayers()) do
				if target ~= player and target.Character then
					local character = target.Character

					local h = character:FindFirstChild("TeamHighlight")
					if not h then
						addHighlight(character, target)
					else
						h.Enabled = S.esp.enabled and not highlightedPlayers[target.Name]
						h.FillColor = getTeamColor(target)
						h.FillTransparency = S.esp.transparency
					end

					local head = character:FindFirstChild("Head")
					local tag = head and head:FindFirstChild("TeamHealthTag")
					if not tag then
						addHealthTag(character, target)
					else
						tag.Enabled = S.esp.hp
					end

					local arrow = head and head:FindFirstChild("LookArrow")
					if not arrow and head then
						addLookArrow(character, target)
					elseif arrow then
						arrow.Transparency = S.esp.direction and 0.35 or 1
						arrow.Color = getTeamColor(target)
						local hl = arrow:FindFirstChild("LookArrowHighlight")
						if hl then
							hl.Enabled = S.esp.direction
							hl.FillColor = getTeamColor(target)
						end
					end

					local update = refreshers[target]
					if update then update() end
				end
			end

			for tp in pairs(refreshers) do
				if not tp.Parent then
					refreshers[tp] = nil
				end
			end
		end
	end)

	----------------------------------------------------------------
	-- МОДУЛЬ 3: HEAD SIZE
	----------------------------------------------------------------
	local function setHeadSize(character, size)
		local head = character:FindFirstChild("Head")
		if not head then return end
		pcall(function()
			if not head:GetAttribute("OriginalSize") then
				head:SetAttribute("OriginalSize", head.Size.X)
			end
			head.Size = Vector3.new(size, size, size)
			head.Transparency = 0.95
			head.BrickColor = BrickColor.new("Really red")
			head.Material = Enum.Material.Neon
			head.CanCollide = false
		end)
	end

	RunService.RenderStepped:Connect(function()
		if not S.head.enabled then return end
		for _, v in ipairs(Players:GetPlayers()) do
			if v ~= player and v.Team ~= player.Team and v.Character then
				setHeadSize(v.Character, S.head.size)
			end
		end
	end)

	local function disableHeads()
		for _, v in ipairs(Players:GetPlayers()) do
			if v ~= player and v.Character then
				local head = v.Character:FindFirstChild("Head")
				if head and head:GetAttribute("OriginalSize") then
					pcall(function()
						head.Size = Vector3.new(
							head:GetAttribute("OriginalSize"),
							head:GetAttribute("OriginalSize"),
							head:GetAttribute("OriginalSize")
						)
						head.Transparency = 0
						head.Material = Enum.Material.SmoothPlastic
					end)
				end
			end
		end
	end

	----------------------------------------------------------------
	-- МОДУЛЬ 6: ВЫДЕЛЕНИЕ ИГРОКА ПО НИКУ (зелёная подсветка)
	----------------------------------------------------------------
	local refreshHighlightList = nil -- назначим позже, в UI

	local function highlightOnPlayer(target)
		local char = target.Character
		if not char then return end
		local h = char:FindFirstChild("PlayerSelectHighlight")
		if not h then
			h = Instance.new("Highlight")
			h.Name = "PlayerSelectHighlight"
			h.FillColor = Color3.fromRGB(0, 255, 0)
			h.OutlineColor = Color3.fromRGB(0, 255, 0)
			h.FillTransparency = 0.4
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = char
		end
		h.Enabled = true
		-- гасим ESP-подсветку, чтобы Highlight'ы не конфликтовали
		local esp = char:FindFirstChild("TeamHighlight")
		if esp then esp.Enabled = false end
	end

	local function clearHighlightFrom(target)
		local char = target.Character
		if char then
			local h = char:FindFirstChild("PlayerSelectHighlight")
			if h then h:Destroy() end
			-- возвращаем ESP-подсветку
			local esp = char:FindFirstChild("TeamHighlight")
			if esp then esp.Enabled = S.esp.enabled end
		end
	end

	local function findPlayerByNick(nick)
		nick = nick:lower()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and (p.Name:lower() == nick or p.DisplayName:lower() == nick) then
				return p
			end
		end
		return nil
	end

	local function addHighlighted(target)
		if highlightedPlayers[target.Name] then return end
		highlightedPlayers[target.Name] = true
		highlightOnPlayer(target)
	end

	local function removeHighlighted(name)
		highlightedPlayers[name] = nil
		local p = Players:FindFirstChild(name)
		if p then clearHighlightFrom(p) end
	end

	-- держим подсветку на месте (новый персонаж / перезаход) и чистим список от вышедших
	task.spawn(function()
		while true do
			task.wait(0.5)
			local seen = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if highlightedPlayers[p.Name] then
					seen[p.Name] = true
					if p.Character then
						local h = p.Character:FindFirstChild("PlayerSelectHighlight")
						if not h then highlightOnPlayer(p) end
					end
				end
			end
			local changed = false
			for name in pairs(highlightedPlayers) do
				if not seen[name] then
					highlightedPlayers[name] = nil
					changed = true
				end
			end
			if changed and refreshHighlightList then refreshHighlightList() end
		end
	end)

	----------------------------------------------------------------
	-- ЕДИНОЕ МЕНЮ
	----------------------------------------------------------------
	Frame = Instance.new("ImageLabel")
	Frame.Parent = nil
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.Position = UDim2.new(0.157, 0, 0.07, 0)
	Frame.Size = UDim2.new(0, 190, 0, 420)
	Frame.Visible = false
	Frame.Image = "rbxassetid://3570695787"
	Frame.ImageColor3 = Color3.fromRGB(49, 49, 49)
	Frame.ScaleType = Enum.ScaleType.Slice
	Frame.SliceCenter = Rect.new(100, 100, 100, 100)
	Frame.SliceScale = 0.04
	Frame.Active = true
	Frame.Draggable = true

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "MergedMenu"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = game.CoreGui
	Frame.Parent = ScreenGui

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = Color3.fromRGB(0, 255, 170)
	menuStroke.Thickness = 1.5
	menuStroke.Transparency = 0.6
	menuStroke.Parent = Frame
	task.spawn(function()
		while ScreenGui.Parent do
			tween(menuStroke, {Transparency = 0.3}, 1.2)
			task.wait(1.2)
			tween(menuStroke, {Transparency = 0.7}, 1.2)
			task.wait(1.2)
		end
	end)

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, 0, 0, 28)
	Title.BackgroundTransparency = 1
	Title.Text = "Merged Menu"
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 16
	Title.Parent = Frame

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}
	titleGrad.Parent = Title
	task.spawn(function()
		local t = 0
		while ScreenGui.Parent do
			t += task.wait(0.03)
			titleGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.5, 0)
		end
	end)

	local function addHoverEffect(btn)
		local us = Instance.new("UIScale")
		us.Parent = btn

		btn.MouseEnter:Connect(function()
			tween(btn, {BackgroundColor3 = btn.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.18)})
		end)
		btn.MouseLeave:Connect(function()
			if btn:GetAttribute("BaseColor") then
				tween(btn, {BackgroundColor3 = btn:GetAttribute("BaseColor")})
			end
		end)
		btn.MouseButton1Click:Connect(function()
			tween(us, {Scale = 0.93}, 0.06)
			task.delay(0.07, function()
				tween(us, {Scale = 1}, 0.18)
			end)
		end)
	end

	local function makeToggle(name, pos, getState, onSet)
		local btn = Instance.new("TextButton")
		btn.Parent = Frame
		btn.Size = UDim2.new(0.9, 0, 0, 30)
		btn.Position = pos
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 15
		btn.BorderSizePixel = 0
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = name

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = btn

		local function refresh()
			local on = getState()
			btn.Text = name .. (on and ": ВКЛ" or ": ВЫКЛ")
			btn:SetAttribute("BaseColor", on and ON_COLOR or OFF_COLOR)
			tween(btn, {BackgroundColor3 = on and ON_COLOR or OFF_COLOR})
		end
		btn.MouseButton1Click:Connect(function()
			onSet(not getState())
			refresh()
		end)
		refresh()
		addHoverEffect(btn)
		return btn
	end

	makeToggle("Подсветка Гунов", UDim2.new(0.05, 0, 0, 32),
		function() return S.items.enabled end,
		function(v) setItemsEnabled(v) end)

	makeToggle("ESP", UDim2.new(0.05, 0, 0, 66),
		function() return S.esp.enabled end,
		function(v)
			S.esp.enabled = v
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character then
					local h = p.Character:FindFirstChild("TeamHighlight")
					if h then h.Enabled = v and not highlightedPlayers[p.Name] end
				end
			end
		end)

	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Parent = Frame
	settingsBtn.Size = UDim2.new(0.9, 0, 0, 26)
	settingsBtn.Position = UDim2.new(0.05, 0, 0, 100)
	settingsBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	settingsBtn.TextColor3 = Color3.new(1, 1, 1)
	settingsBtn.Font = Enum.Font.GothamBold
	settingsBtn.TextSize = 14
	settingsBtn.Text = "Настройки ESP ▶"
	settingsBtn:SetAttribute("BaseColor", Color3.fromRGB(70, 70, 70))
	local c0 = Instance.new("UICorner")
	c0.CornerRadius = UDim.new(0, 8)
	c0.Parent = settingsBtn
	addHoverEffect(settingsBtn)

	local settingsFrame = Instance.new("Frame")
	settingsFrame.Size = UDim2.new(0, 170, 0, 194)
	settingsFrame.Position = UDim2.new(1, 6, 0, 0)
	settingsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	settingsFrame.BackgroundTransparency = 0.2
	settingsFrame.Visible = false
	settingsFrame.Parent = Frame
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(0, 8)
	c1.Parent = settingsFrame

	local SETTINGS_POS_OPEN = UDim2.new(1, 6, 0, 0)
	local SETTINGS_POS_CLOSED = UDim2.new(1, 20, 0, 0)

	local function makeSmallToggle(parent, text, pos, getState, onSet)
		local btn = Instance.new("TextButton")
		btn.Parent = parent
		btn.Size = UDim2.new(1, -12, 0, 26)
		btn.Position = pos
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.BorderSizePixel = 0
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = text
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn
		local function refresh()
			local on = getState()
			btn.Text = text .. (on and ": ВКЛ" or ": ВЫКЛ")
			btn:SetAttribute("BaseColor", on and ON_COLOR or OFF_COLOR)
			tween(btn, {BackgroundColor3 = on and ON_COLOR or OFF_COLOR})
		end
		btn.MouseButton1Click:Connect(function()
			onSet(not getState())
			refresh()
		end)
		refresh()
		addHoverEffect(btn)
	end

	makeSmallToggle(settingsFrame, "Показ HP", UDim2.new(0, 6, 0, 5),
		function() return S.esp.hp end,
		function(v)
			S.esp.hp = v
			for _, p in ipairs(Players:GetPlayers()) do
				local head = p.Character and p.Character:FindFirstChild("Head")
				local tag = head and head:FindFirstChild("TeamHealthTag")
				if tag then tag.Enabled = v end
			end
		end)

	makeSmallToggle(settingsFrame, "Показ имён", UDim2.new(0, 6, 0, 34),
		function() return S.esp.names end,
		function(v)
			S.esp.names = v
			for _, update in pairs(refreshers) do update() end
		end)

	makeSmallToggle(settingsFrame, "Цвет команды", UDim2.new(0, 6, 0, 63),
		function() return S.esp.teamColor end,
		function(v)
			S.esp.teamColor = v
			for _, update in pairs(refreshers) do update() end
		end)

	makeSmallToggle(settingsFrame, "Направление взгляда", UDim2.new(0, 6, 0, 92),
		function() return S.esp.direction end,
		function(v)
			S.esp.direction = v
			for _, p in ipairs(Players:GetPlayers()) do
				local head = p.Character and p.Character:FindFirstChild("Head")
				local arrow = head and head:FindFirstChild("LookArrow")
				if arrow then
					arrow.Transparency = v and 0.35 or 1
					local hl = arrow:FindFirstChild("LookArrowHighlight")
					if hl then hl.Enabled = v end
				end
			end
		end)

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Parent = settingsFrame
	refreshBtn.Size = UDim2.new(1, -12, 0, 26)
	refreshBtn.Position = UDim2.new(0, 6, 0, 122)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	refreshBtn.TextColor3 = Color3.new(1, 1, 1)
	refreshBtn.Font = Enum.Font.GothamBold
	refreshBtn.TextSize = 13
	refreshBtn.Text = "Обновить ESP"
	refreshBtn:SetAttribute("BaseColor", Color3.fromRGB(70, 70, 70))
	local cR = Instance.new("UICorner")
	cR.CornerRadius = UDim.new(0, 6)
	cR.Parent = refreshBtn
	addHoverEffect(refreshBtn)
	refreshBtn.MouseButton1Click:Connect(function()
		refreshESP()
	end)

	local sliderLabel = Instance.new("TextLabel")
	sliderLabel.Size = UDim2.new(1, -12, 0, 16)
	sliderLabel.Position = UDim2.new(0, 6, 0, 154)
	sliderLabel.BackgroundTransparency = 1
	sliderLabel.TextColor3 = Color3.new(1, 1, 1)
	sliderLabel.Font = Enum.Font.Gotham
	sliderLabel.TextSize = 12
	sliderLabel.Text = "Прозрачность: 50%"
	sliderLabel.Parent = settingsFrame

	local sliderBack = Instance.new("Frame")
	sliderBack.Size = UDim2.new(1, -12, 0, 10)
	sliderBack.Position = UDim2.new(0, 6, 0, 172)
	sliderBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	sliderBack.Parent = settingsFrame
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 6)
	c2.Parent = sliderBack

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
	sliderFill.Parent = sliderBack
	local c3 = Instance.new("UICorner")
	c3.CornerRadius = UDim.new(0, 6)
	c3.Parent = sliderFill

	local function setTransparency(v)
		S.esp.transparency = math.clamp(v, 0, 1)
		sliderFill.Size = UDim2.new(1 - S.esp.transparency, 0, 1, 0)
		sliderLabel.Text = "Прозрачность: " .. math.floor(S.esp.transparency * 100 + 0.5) .. "%"
		for _, p in ipairs(Players:GetPlayers()) do
			local h = p.Character and p.Character:FindFirstChild("TeamHighlight")
			if h then h.FillTransparency = S.esp.transparency end
		end
	end
	setTransparency(S.esp.transparency)

	-- ---- блок Head Size ----
	makeToggle("Head Size", UDim2.new(0.05, 0, 0, 130),
		function() return S.head.enabled end,
		function(v)
			S.head.enabled = v
			if not v then disableHeads() end
		end)

	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(1, -12, 0, 16)
	sizeLabel.Position = UDim2.new(0, 6, 0, 164)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.TextColor3 = Color3.new(1, 1, 1)
	sizeLabel.Font = Enum.Font.Gotham
	sizeLabel.TextSize = 12
	sizeLabel.Text = "Размер головы: 2.9"
	sizeLabel.Parent = Frame

	local sizeBack = Instance.new("Frame")
	sizeBack.Size = UDim2.new(0.9, 0, 0, 10)
	sizeBack.Position = UDim2.new(0.05, 0, 0, 184)
	sizeBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	sizeBack.Parent = Frame
	local c4 = Instance.new("UICorner")
	c4.CornerRadius = UDim.new(0, 6)
	c4.Parent = sizeBack

	local sizeFill = Instance.new("Frame")
	sizeFill.Size = UDim2.new(0.5, 0, 1, 0)
	sizeFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	sizeFill.Parent = sizeBack
	local c5 = Instance.new("UICorner")
	c5.CornerRadius = UDim.new(0, 6)
	c5.Parent = sizeFill

	local function setSize(v)
		if not S.head.enabled then return end
		S.head.size = math.clamp(v, S.head.min, S.head.max)
		sizeLabel.Text = ("Размер головы: %.1f"):format(S.head.size)
		sizeFill.Size = UDim2.new((S.head.size - S.head.min) / (S.head.max - S.head.min), 0, 1, 0)
	end

	-- ---- подсветка зомби ----
	makeToggle("Подсветка Зомби", UDim2.new(0.05, 0, 0, 200),
		function() return S.zombies.enabled end,
		function(v) setZombiesEnabled(v) end)

	-- ---- блок Hitbox Зомби ----
	makeToggle("Hitbox Зомби", UDim2.new(0.05, 0, 0, 236),
		function() return S.hitbox.enabled end,
		function(v)
			S.hitbox.enabled = v
			if not v then disableHitboxes() end
		end)

	local hitboxLabel = Instance.new("TextLabel")
	hitboxLabel.Size = UDim2.new(1, -12, 0, 16)
	hitboxLabel.Position = UDim2.new(0, 6, 0, 272)
	hitboxLabel.BackgroundTransparency = 1
	hitboxLabel.TextColor3 = Color3.new(1, 1, 1)
	hitboxLabel.Font = Enum.Font.Gotham
	hitboxLabel.TextSize = 12
	hitboxLabel.Text = "Размер хитбокса краба WARN! (W.I.P): 5.0"
	hitboxLabel.Parent = Frame

	local hitboxBack = Instance.new("Frame")
	hitboxBack.Size = UDim2.new(0.9, 0, 0, 10)
	hitboxBack.Position = UDim2.new(0.05, 0, 0, 292)
	hitboxBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	hitboxBack.Parent = Frame
	local c7 = Instance.new("UICorner")
	c7.CornerRadius = UDim.new(0, 6)
	c7.Parent = hitboxBack

	local hitboxFill = Instance.new("Frame")
	hitboxFill.Size = UDim2.new(0.8, 0, 1, 0)
	hitboxFill.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
	hitboxFill.Parent = hitboxBack
	local c8 = Instance.new("UICorner")
	c8.CornerRadius = UDim.new(0, 6)
	c8.Parent = hitboxFill

	local function setSizeHitbox(v)
		S.hitbox.size = math.clamp(v, S.hitbox.min, S.hitbox.max)
		hitboxLabel.Text = ("Размер хитбокса краба (W.I.P): %.1f"):format(S.hitbox.size)
		hitboxFill.Size = UDim2.new((S.hitbox.size - S.hitbox.min) / (S.hitbox.max - S.hitbox.min), 0, 1, 0)
	end

	-- ---- блок Выделение игрока ----
	local hlBtn = Instance.new("TextButton")
	hlBtn.Parent = Frame
	hlBtn.Size = UDim2.new(0.9, 0, 0, 26)
	hlBtn.Position = UDim2.new(0.05, 0, 0, 312)
	hlBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	hlBtn.TextColor3 = Color3.new(1, 1, 1)
	hlBtn.Font = Enum.Font.GothamBold
	hlBtn.TextSize = 14
	hlBtn.Text = "Выделение игрока ▶"
	hlBtn:SetAttribute("BaseColor", Color3.fromRGB(70, 70, 70))
	local chl = Instance.new("UICorner")
	chl.CornerRadius = UDim.new(0, 8)
	chl.Parent = hlBtn
	addHoverEffect(hlBtn)

	local hlFrame = Instance.new("Frame")
	hlFrame.Size = UDim2.new(0, 170, 0, 168)
	hlFrame.Position = UDim2.new(1, 20, 0, 200)
	hlFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	hlFrame.BackgroundTransparency = 0.2
	hlFrame.Visible = false
	hlFrame.Parent = Frame
	local chl2 = Instance.new("UICorner")
	chl2.CornerRadius = UDim.new(0, 8)
	chl2.Parent = hlFrame

	local HL_OPEN = UDim2.new(1, 6, 0, 200)
	local HL_CLOSED = UDim2.new(1, 20, 0, 200)

	local nickBox = Instance.new("TextBox")
	nickBox.Parent = hlFrame
	nickBox.Size = UDim2.new(1, -12, 0, 24)
	nickBox.Position = UDim2.new(0, 6, 0, 6)
	nickBox.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	nickBox.TextColor3 = Color3.new(1, 1, 1)
	nickBox.PlaceholderText = "Ник игрока..."
	nickBox.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
	nickBox.Font = Enum.Font.Gotham
	nickBox.TextSize = 13
	nickBox.Text = ""
	nickBox.ClearTextOnFocus = false
	local cnb = Instance.new("UICorner")
	cnb.CornerRadius = UDim.new(0, 6)
	cnb.Parent = nickBox

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -12, 0, 14)
	statusLabel.Position = UDim2.new(0, 6, 0, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 11
	statusLabel.Text = ""
	statusLabel.Parent = hlFrame

	local addBtn = Instance.new("TextButton")
	addBtn.Parent = hlFrame
	addBtn.Size = UDim2.new(1, -12, 0, 24)
	addBtn.Position = UDim2.new(0, 6, 0, 48)
	addBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 60)
	addBtn.TextColor3 = Color3.new(1, 1, 1)
	addBtn.Font = Enum.Font.GothamBold
	addBtn.TextSize = 13
	addBtn.Text = "Выделить"
	addBtn:SetAttribute("BaseColor", Color3.fromRGB(0, 130, 60))
	local cab = Instance.new("UICorner")
	cab.CornerRadius = UDim.new(0, 6)
	cab.Parent = addBtn
	addHoverEffect(addBtn)

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, -12, 0, 80)
	listFrame.Position = UDim2.new(0, 6, 0, 78)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 3
	listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = hlFrame
	local hlLayout = Instance.new("UIListLayout")
	hlLayout.Padding = UDim.new(0, 3)
	hlLayout.Parent = listFrame

	refreshHighlightList = function()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local names = {}
		for name in pairs(highlightedPlayers) do
			table.insert(names, name)
		end
		table.sort(names)
		if #names == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, -4, 0, 18)
			empty.BackgroundTransparency = 1
			empty.TextColor3 = Color3.fromRGB(160, 160, 160)
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 12
			empty.Text = "Никого не выделено"
			empty.Parent = listFrame
			return
		end
		for _, name in ipairs(names) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -4, 0, 20)
			row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			row.Parent = listFrame
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 4)
			rc.Parent = row
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -26, 1, 0)
			lbl.Position = UDim2.new(0, 4, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.TextColor3 = Color3.fromRGB(120, 255, 120)
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 12
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Text = name
			lbl.Parent = row
			local rm = Instance.new("TextButton")
			rm.Size = UDim2.new(0, 18, 1, 0)
			rm.Position = UDim2.new(1, -20, 0, 0)
			rm.BackgroundTransparency = 1
			rm.TextColor3 = Color3.fromRGB(255, 90, 90)
			rm.Font = Enum.Font.GothamBold
			rm.TextSize = 13
			rm.Text = "X"
			rm.Parent = row
			rm.MouseButton1Click:Connect(function()
				removeHighlighted(name)
				refreshHighlightList()
			end)
		end
	end

	local function tryAdd()
		local nick = nickBox.Text
		if nick == "" then
			statusLabel.Text = "Введите ник"
			return
		end
		local target = findPlayerByNick(nick)
		if target then
			addHighlighted(target)
			statusLabel.Text = ""
			nickBox.Text = ""
			refreshHighlightList()
		else
			statusLabel.Text = "Игрок не найден"
		end
	end

	addBtn.MouseButton1Click:Connect(tryAdd)
	nickBox.FocusLost:Connect(function(enter)
		if enter then tryAdd() end -- Enter тоже добавляет
	end)

	local hlOpen = false
	hlBtn.MouseButton1Click:Connect(function()
		hlOpen = not hlOpen
		hlBtn.Text = "Выделение игрока " .. (hlOpen and "◀" or "▶")
		if hlOpen then
			hlFrame.Visible = true
			hlFrame.Position = HL_CLOSED
			tween(hlFrame, {Position = HL_OPEN}, 0.22)
			refreshHighlightList()
		else
			local t = tween(hlFrame, {Position = HL_CLOSED}, 0.18)
			t.Completed:Once(function()
				hlFrame.Visible = false
				hlFrame.Position = HL_OPEN
			end)
		end
	end)

	-- ---- кнопка закрыть ----
	local Close = Instance.new("TextButton")
	Close.Parent = Frame
	Close.Size = UDim2.new(0.9, 0, 0, 26)
	Close.Position = UDim2.new(0.05, 0, 1, -34)
	Close.BackgroundColor3 = Color3.fromRGB(76, 76, 76)
	Close.Font = Enum.Font.GothamBold
	Close.TextSize = 14
	Close.TextColor3 = Color3.new(1, 1, 1)
	Close.Text = "Close GUI (клавиша " .. S.keybind.key.Name:upper() .. ")"
	Close:SetAttribute("BaseColor", Color3.fromRGB(76, 76, 76))
	local c6 = Instance.new("UICorner")
	c6.CornerRadius = UDim.new(0, 8)
	c6.Parent = Close
	addHoverEffect(Close)

	local function toggleMenu()
		if Frame.Visible then
			local cur = Frame.Position
			local t = tween(Frame, {Position = cur + UDim2.fromOffset(-30, 0)}, 0.2)
			t.Completed:Once(function()
				Frame.Visible = false
				Frame.Position = cur
			end)
		else
			Frame.Visible = true
			local cur = Frame.Position
			Frame.Position = cur + UDim2.fromOffset(-30, 0)
			tween(Frame, {Position = cur}, 0.25)
		end
	end

	Close.MouseButton1Click:Connect(toggleMenu)

	-- ---- блок Настройки меню (светлая кнопка-шестерёнка) ----
	local gearBtn = Instance.new("TextButton")
	gearBtn.Parent = Frame
	gearBtn.Size = UDim2.new(0, 26, 0, 26)
	gearBtn.Position = UDim2.new(1, -30, 0, 1)
	gearBtn.BackgroundColor3 = Color3.fromRGB(228, 228, 228)
	gearBtn.TextColor3 = Color3.fromRGB(45, 45, 45)
	gearBtn.Font = Enum.Font.GothamBold
	gearBtn.TextSize = 16
	gearBtn.Text = "⚙"
	gearBtn:SetAttribute("BaseColor", Color3.fromRGB(228, 228, 228))
	local cg = Instance.new("UICorner")
	cg.CornerRadius = UDim.new(0, 8)
	cg.Parent = gearBtn
	addHoverEffect(gearBtn)

	local keyFrame = Instance.new("Frame")
	keyFrame.Size = UDim2.new(0, 175, 0, 96)
	keyFrame.Position = UDim2.new(1, 6, 0, 0)
	keyFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	keyFrame.BackgroundTransparency = 0.2
	keyFrame.Visible = false
	keyFrame.Parent = Frame
	local ckf = Instance.new("UICorner")
	ckf.CornerRadius = UDim.new(0, 8)
	ckf.Parent = keyFrame

	local KEY_OPEN = UDim2.new(1, 6, 0, 0)
	local KEY_CLOSED = UDim2.new(1, 20, 0, 0)

	local keyTitle = Instance.new("TextLabel")
	keyTitle.Size = UDim2.new(1, -12, 0, 16)
	keyTitle.Position = UDim2.new(0, 6, 0, 5)
	keyTitle.BackgroundTransparency = 1
	keyTitle.TextColor3 = Color3.new(1, 1, 1)
	keyTitle.Font = Enum.Font.GothamBold
	keyTitle.TextSize = 13
	keyTitle.Text = "Настройки меню"
	keyTitle.Parent = keyFrame

	local bindBtn = Instance.new("TextButton")
	bindBtn.Parent = keyFrame
	bindBtn.Size = UDim2.new(1, -12, 0, 26)
	bindBtn.Position = UDim2.new(0, 6, 0, 24)
	bindBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	bindBtn.TextColor3 = Color3.new(1, 1, 1)
	bindBtn.Font = Enum.Font.GothamBold
	bindBtn.TextSize = 13
	bindBtn.Text = "Клавиша меню: " .. S.keybind.key.Name:upper()
	bindBtn:SetAttribute("BaseColor", Color3.fromRGB(70, 70, 70))
	local cbb = Instance.new("UICorner")
	cbb.CornerRadius = UDim.new(0, 6)
	cbb.Parent = bindBtn
	addHoverEffect(bindBtn)

	local keyHint = Instance.new("TextLabel")
	keyHint.Size = UDim2.new(1, -12, 0, 32)
	keyHint.Position = UDim2.new(0, 6, 0, 54)
	keyHint.BackgroundTransparency = 1
	keyHint.TextColor3 = Color3.fromRGB(160, 160, 160)
	keyHint.Font = Enum.Font.Gotham
	keyHint.TextSize = 11
	keyHint.TextWrapped = true
	keyHint.Text = "Нажми кнопку, затем новую клавишу. Повторный клик — отмена."
	keyHint.Parent = keyFrame

	bindBtn.MouseButton1Click:Connect(function()
		if S.keybind.waiting then
			S.keybind.waiting = false
			bindBtn.Text = "Клавиша меню: " .. S.keybind.key.Name:upper()
		else
			S.keybind.waiting = true
			bindBtn.Text = "Нажмите клавишу..."
		end
	end)

	local keyOpen = false
	gearBtn.MouseButton1Click:Connect(function()
		keyOpen = not keyOpen
		if keyOpen then
			S.keybind.waiting = false
			bindBtn.Text = "Клавиша меню: " .. S.keybind.key.Name:upper()
			keyFrame.Visible = true
			keyFrame.Position = KEY_CLOSED
			tween(keyFrame, {Position = KEY_OPEN}, 0.22)
		else
			local t = tween(keyFrame, {Position = KEY_CLOSED}, 0.18)
			t.Completed:Once(function()
				keyFrame.Visible = false
				keyFrame.Position = KEY_OPEN
			end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if S.keybind.waiting then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				S.keybind.waiting = false
				S.keybind.key = input.KeyCode
				bindBtn.Text = "Клавиша меню: " .. input.KeyCode.Name:upper()
				Close.Text = "Close GUI (клавиша " .. input.KeyCode.Name:upper() .. ")"
			end
			return
		end
		if not gpe
			and input.UserInputType == Enum.UserInputType.Keyboard
			and input.KeyCode == S.keybind.key then
			toggleMenu()
		end
	end)

	local settingsOpen = false
	settingsBtn.MouseButton1Click:Connect(function()
		settingsOpen = not settingsOpen
		settingsBtn.Text = "Настройки ESP " .. (settingsOpen and "◀" or "▶")
		if settingsOpen then
			settingsFrame.Visible = true
			settingsFrame.Position = SETTINGS_POS_CLOSED
			tween(settingsFrame, {Position = SETTINGS_POS_OPEN}, 0.22)
		else
			local t = tween(settingsFrame, {Position = SETTINGS_POS_CLOSED}, 0.18)
			t.Completed:Once(function()
				settingsFrame.Visible = false
				settingsFrame.Position = SETTINGS_POS_OPEN
			end)
		end
	end)

	local function bindSlider(backFrame, fillFrame, onUpdate)
		local dragging = false
		local function fromX(x)
			local ratio = math.clamp((x - backFrame.AbsolutePosition.X) / backFrame.AbsoluteSize.X, 0, 1)
			onUpdate(ratio)
		end
		backFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				fromX(input.Position.X)
			end
		end)
		backFrame.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				fromX(input.Position.X)
			end
		end)
	end

	bindSlider(sliderBack, sliderFill, function(r) setTransparency(1 - r) end)
	bindSlider(sizeBack, sizeFill, function(r) setSize(S.head.min + r * (S.head.max - S.head.min)) end)
	bindSlider(hitboxBack, hitboxFill, function(r) setSizeHitbox(S.hitbox.min + r * (S.hitbox.max - S.hitbox.min)) end)
end

----------------------------------------------------------------
-- ЗАПУСК: init -> закрытие загрузки -> появление меню
----------------------------------------------------------------
task.spawn(function()
	local ok, err = pcall(init)
	if not ok then
		warn("[MergedMenu] Ошибка запуска: " .. tostring(err))
	end

	pcall(function()
		tween(loadText, {TextTransparency = 1, TextStrokeTransparency = 1}, 0.2)
		tween(barBack, {BackgroundTransparency = 1}, 0.2)
		tween(barFill, {BackgroundTransparency = 1}, 0.2)
	end)
	task.wait(1)
	if loadGui.Parent then
		loadGui:Destroy()
	end

	pcall(function()
		Frame.Visible = true
		local menuScale = Instance.new("UIScale")
		menuScale.Scale = 0.8
		menuScale.Parent = Frame
		tween(menuScale, {Scale = 1}, 0.25)
		local cur = Frame.Position
		Frame.Position = cur + UDim2.fromOffset(-30, 0)
		tween(Frame, {Position = cur}, 0.25)
	end)
end)
