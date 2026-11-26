--[[ Photon VD — Visuals Tab (ESP) ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local COLORS = {}
local COLOR_NAMES = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local masterESP = { enabled = false }
local masterEnabled = false

local DEPTH_MODES = { "alwaysontop", "occluded" }
local DEPTH_MAP = {
	alwaysontop = Enum.HighlightDepthMode.AlwaysOnTop,
	occluded    = Enum.HighlightDepthMode.Occluded,
}

local playerTrack = {
	enabled = false,
	color = "white",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	ignoreSpectator = false,
	depthMode = "alwaysontop",
}

local selfTrack = {
	enabled = false,
	color = "white",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	depthMode = "alwaysontop",
}

local teamESP = {
	enabled = false,
	colors = {
		Spectator = "white",
		Survivors = "blue",
		Killer = "red",
	},
	survivorHealth = {
		enabled = false,
		healthy = "green",
		injured = "yellow",
		downed = "red",
	},
}

local botTrack = {
	enabled = false,
	color = "white",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	depthMode = "alwaysontop",
}

local trapTrack = {
	enabled = false,
	color = "orange",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	depthMode = "alwaysontop",
}

local zombieTrack = {
	enabled = false,
	color = "maroon",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	depthMode = "alwaysontop",
	ignoreInactive = false,
	ignoreDead = false,
}

local windowTrack = {
	enabled = false,
	color = "cyan",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	depthMode = "alwaysontop",
}

local palletTrack = {
	enabled = false,
	color = "yellow",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	depthMode = "alwaysontop",
}

local HubRef = nil

local espData = {}
local selfEspData = nil
local botEspData = {}
local botWatchers = {}
local trapEspData = {}
local zombieEspData = {}
local windowEspData = {}
local palletEspData = {}
local highlightFolder = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function getHighlightParent()
	if highlightFolder and highlightFolder.Parent then return highlightFolder end
	highlightFolder = Instance.new("Folder")
	highlightFolder.Name = "_"
	pcall(function()
		if gethui then
			highlightFolder.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(highlightFolder)
			highlightFolder.Parent = game:GetService("CoreGui")
		else
			highlightFolder.Parent = game:GetService("CoreGui")
		end
	end)
	if not highlightFolder.Parent then
		highlightFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	return highlightFolder
end

local function getTeamName(player)
	local ok, team = pcall(function() return player.Team end)
	if ok and team then return team.Name end
	return nil
end

local function getHealthState(char)
	if not char then return "healthy" end
	local ok, knocked = pcall(char.GetAttribute, char, "Knocked")
	if ok and knocked == true then return "downed" end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health < hum.MaxHealth then return "injured" end
	return "healthy"
end

local function getPlayerColor(player)
	if teamESP.enabled then
		local teamName = getTeamName(player)
		if teamName == "Survivors" and teamESP.survivorHealth.enabled then
			local state = getHealthState(player.Character)
			local colorName = teamESP.survivorHealth[state]
			if colorName then return COLORS[colorName] or COLORS.white end
		end
		if teamName and teamESP.colors[teamName] then
			return COLORS[teamESP.colors[teamName]] or COLORS.white
		end
	end
	return COLORS[playerTrack.color] or COLORS.white
end

local function applyPlayerHighlight(hl, player)
	local c = getPlayerColor(player)
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = playerTrack.outlineTransparency
	hl.FillTransparency = playerTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[playerTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function applySelfHighlight(hl)
	local c = COLORS[selfTrack.color] or COLORS.white
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = selfTrack.outlineTransparency
	hl.FillTransparency = selfTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[selfTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function getBotColor(model)
	if teamESP.enabled and teamESP.survivorHealth.enabled then
		local state = getHealthState(model)
		local colorName = teamESP.survivorHealth[state]
		if colorName then return COLORS[colorName] or COLORS.white end
	end
	return COLORS[botTrack.color] or COLORS.white
end

local function applyBotHighlight(hl, model)
	local c = getBotColor(model)
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = botTrack.outlineTransparency
	hl.FillTransparency = botTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[botTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function refreshPlayerHighlights()
	for player, data in pairs(espData) do
		if data.highlight then
			applyPlayerHighlight(data.highlight, player)
		end
	end
end

local function refreshSelfHighlight()
	if selfEspData and selfEspData.highlight then
		applySelfHighlight(selfEspData.highlight)
	end
end

local function refreshBotHighlights()
	for model, data in pairs(botEspData) do
		if data.highlight then
			applyBotHighlight(data.highlight, model)
		end
	end
end

local function applyTrapHighlight(hl)
	local c = COLORS[trapTrack.color] or COLORS.white
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = trapTrack.outlineTransparency
	hl.FillTransparency = trapTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[trapTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function refreshTrapHighlights()
	for _, data in pairs(trapEspData) do
		if data.highlight then
			applyTrapHighlight(data.highlight)
		end
	end
end

local function applyZombieHighlight(hl)
	local c = COLORS[zombieTrack.color] or COLORS.white
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = zombieTrack.outlineTransparency
	hl.FillTransparency = zombieTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[zombieTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function refreshZombieHighlights()
	for _, data in pairs(zombieEspData) do
		if data.highlight then
			applyZombieHighlight(data.highlight)
		end
	end
end

local function applyWindowHighlight(hl)
	local c = COLORS[windowTrack.color] or COLORS.white
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = windowTrack.outlineTransparency
	hl.FillTransparency = windowTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[windowTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function refreshWindowHighlights()
	for _, data in pairs(windowEspData) do
		if data.highlight then
			applyWindowHighlight(data.highlight)
		end
	end
end

local function dimColor(c)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, v * 0.55)
end

local function applyPalletHighlight(hl, model)
	local c = COLORS[palletTrack.color] or COLORS.white
	local state = model:GetAttribute("PalletState")
	if state == "Dropped" then c = dimColor(c) end
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = palletTrack.outlineTransparency
	hl.FillTransparency = palletTrack.fillTransparency
	hl.DepthMode = DEPTH_MAP[palletTrack.depthMode] or Enum.HighlightDepthMode.AlwaysOnTop
end

local function refreshPalletHighlights()
	for model, data in pairs(palletEspData) do
		if data.highlight then
			applyPalletHighlight(data.highlight, model)
		end
	end
end

---------------------------------------------------------------------------
-- Player ESP lifecycle
---------------------------------------------------------------------------
local function createESP(player)
	if player == LocalPlayer then return end
	if espData[player] then return end

	local data = {
		highlight = nil,
		text = Drawing.new("Text"),
		connections = {},
	}
	data.text.Visible = false
	data.text.Center = true
	data.text.Size = 13
	data.text.Font = 3
	data.text.Color = Color3.new(1, 1, 1)
	data.text.Outline = true
	data.text.OutlineColor = Color3.new(0, 0, 0)

	table.insert(data.connections, player.CharacterAdded:Connect(function(char)
		if data.highlight then
			data.highlight.Adornee = char
		end
	end))

	table.insert(data.connections, player:GetPropertyChangedSignal("Team"):Connect(function()
		if data.highlight then
			applyPlayerHighlight(data.highlight, player)
		end
	end))

	espData[player] = data
end

local function removeESP(player)
	local data = espData[player]
	if not data then return end
	for _, conn in ipairs(data.connections) do
		conn:Disconnect()
	end
	data.connections = nil
	if data.highlight then pcall(data.highlight.Destroy, data.highlight) end
	if data.text then pcall(data.text.Remove, data.text) end
	espData[player] = nil
end

---------------------------------------------------------------------------
-- Self ESP lifecycle
---------------------------------------------------------------------------
local function createSelfESP()
	if selfEspData then return end
	selfEspData = {
		highlight = nil,
		connections = {},
	}
	table.insert(selfEspData.connections, LocalPlayer.CharacterAdded:Connect(function(char)
		if selfEspData and selfEspData.highlight then
			selfEspData.highlight.Adornee = char
		end
	end))
end

local function removeSelfESP()
	if not selfEspData then return end
	for _, conn in ipairs(selfEspData.connections) do
		conn:Disconnect()
	end
	if selfEspData.highlight then pcall(selfEspData.highlight.Destroy, selfEspData.highlight) end
	selfEspData = nil
end

---------------------------------------------------------------------------
-- Bot ESP lifecycle
---------------------------------------------------------------------------
local function removeBotESP(model)
	local data = botEspData[model]
	if not data then return end
	for _, conn in ipairs(data.connections) do
		conn:Disconnect()
	end
	data.connections = nil
	if data.highlight then pcall(data.highlight.Destroy, data.highlight) end
	if data.text then pcall(data.text.Remove, data.text) end
	botEspData[model] = nil
end

local function createBotESP(model)
	if botEspData[model] then return end

	local data = {
		highlight = nil,
		text = Drawing.new("Text"),
		connections = {},
	}
	data.text.Visible = false
	data.text.Center = true
	data.text.Size = 13
	data.text.Font = 3
	data.text.Color = Color3.new(1, 1, 1)
	data.text.Outline = true
	data.text.OutlineColor = Color3.new(0, 0, 0)

	table.insert(data.connections, model:GetAttributeChangedSignal("RoundBot"):Connect(function()
		if model:GetAttribute("RoundBot") ~= true then
			removeBotESP(model)
		end
	end))

	table.insert(data.connections, model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeBotESP(model)
		end
	end))

	botEspData[model] = data
end

local function clearBotWatcher(model)
	local w = botWatchers[model]
	if not w then return end
	if w.attr then w.attr:Disconnect() end
	if w.ancestry then w.ancestry:Disconnect() end
	botWatchers[model] = nil
end

local function watchForBot(model)
	if botWatchers[model] or botEspData[model] then return end
	local w = {}
	w.attr = model:GetAttributeChangedSignal("RoundBot"):Connect(function()
		if model:GetAttribute("RoundBot") == true then
			clearBotWatcher(model)
			createBotESP(model)
		end
	end)
	w.ancestry = model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clearBotWatcher(model)
		end
	end)
	botWatchers[model] = w
end

local function scanWorkspaceChild(child)
	if not child:IsA("Model") then return end
	if child:GetAttribute("RoundBot") == true then
		createBotESP(child)
	else
		watchForBot(child)
	end
end

---------------------------------------------------------------------------
-- Bear Trap ESP lifecycle
---------------------------------------------------------------------------
local function isTrap(inst)
	if not inst:IsA("Model") then return false end
	local name = string.lower(inst.Name)
	return string.find(name, "bear") ~= nil and string.find(name, "trap") ~= nil
end

local function removeTrapESP(model)
	local data = trapEspData[model]
	if not data then return end
	if data.conn then data.conn:Disconnect() end
	if data.highlight then pcall(data.highlight.Destroy, data.highlight) end
	if data.text then pcall(data.text.Remove, data.text) end
	trapEspData[model] = nil
end

local function createTrapESP(model)
	if trapEspData[model] then return end

	local data = {
		highlight = nil,
		text = Drawing.new("Text"),
		conn = nil,
	}
	data.text.Visible = false
	data.text.Center = true
	data.text.Size = 13
	data.text.Font = 3
	data.text.Color = Color3.new(1, 1, 1)
	data.text.Outline = true
	data.text.OutlineColor = Color3.new(0, 0, 0)

	data.conn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then removeTrapESP(model) end
	end)

	trapEspData[model] = data
end

local function isZombie(inst)
	if not inst:IsA("Model") then return false end
	if not string.match(inst.Name, "^scp%d*$") then return false end
	return inst:FindFirstChildWhichIsA("Humanoid") ~= nil
end

local function removeZombieESP(model)
	local data = zombieEspData[model]
	if not data then return end
	if data.conn then data.conn:Disconnect() end
	if data.attrConn then data.attrConn:Disconnect() end
	if data.highlight then pcall(data.highlight.Destroy, data.highlight) end
	if data.text then pcall(data.text.Remove, data.text) end
	zombieEspData[model] = nil
end

local function createZombieESP(model)
	if zombieEspData[model] then return end

	local data = {
		highlight = nil,
		text = Drawing.new("Text"),
		conn = nil,
		attrConn = nil,
	}
	data.text.Visible = false
	data.text.Center = true
	data.text.Size = 13
	data.text.Font = 3
	data.text.Color = Color3.new(1, 1, 1)
	data.text.Outline = true
	data.text.OutlineColor = Color3.new(0, 0, 0)

	data.conn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then removeZombieESP(model) end
	end)

	zombieEspData[model] = data
end

local function isWindow(inst)
	if not inst:IsA("Model") then return false end
	if inst.Name ~= "Window" then return false end
	return inst:FindFirstChild("Bottom") ~= nil
		and inst:FindFirstChild("VaultTrigger") ~= nil
end

local function removeWindowESP(model)
	local data = windowEspData[model]
	if not data then return end
	if data.conn then data.conn:Disconnect() end
	if data.highlight then pcall(data.highlight.Destroy, data.highlight) end
	if data.text then pcall(data.text.Remove, data.text) end
	local bottom = model:FindFirstChild("Bottom")
	if bottom and data.origTransparency ~= nil then
		bottom.Transparency = data.origTransparency
	end
	windowEspData[model] = nil
end

local function createWindowESP(model)
	if windowEspData[model] then return end

	local bottom = model:FindFirstChild("Bottom")
	local data = {
		highlight = nil,
		text = Drawing.new("Text"),
		conn = nil,
		origTransparency = bottom and bottom.Transparency or 1,
	}
	data.text.Visible = false
	data.text.Center = true
	data.text.Size = 13
	data.text.Font = 3
	data.text.Color = Color3.new(1, 1, 1)
	data.text.Outline = true
	data.text.OutlineColor = Color3.new(0, 0, 0)

	data.conn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then removeWindowESP(model) end
	end)

	windowEspData[model] = data
end

local function isPallet(inst)
	if not inst:IsA("Model") then return false end
	return inst.Name == "Newpallet"
end

local function removePalletESP(model)
	local data = palletEspData[model]
	if not data then return end
	if data.conn then data.conn:Disconnect() end
	if data.attrConn then data.attrConn:Disconnect() end
	if data.highlight then pcall(data.highlight.Destroy, data.highlight) end
	if data.text then pcall(data.text.Remove, data.text) end
	palletEspData[model] = nil
end

local function createPalletESP(model)
	if palletEspData[model] then return end

	local data = {
		highlight = nil,
		text = Drawing.new("Text"),
		conn = nil,
		attrConn = nil,
	}
	data.text.Visible = false
	data.text.Center = true
	data.text.Size = 13
	data.text.Font = 3
	data.text.Color = Color3.new(1, 1, 1)
	data.text.Outline = true
	data.text.OutlineColor = Color3.new(0, 0, 0)

	data.conn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then removePalletESP(model) end
	end)

	data.attrConn = model.AttributeChanged:Connect(function(attr)
		if attr == "PalletState" and data.highlight then
			applyPalletHighlight(data.highlight, model)
		end
	end)

	palletEspData[model] = data
end

---------------------------------------------------------------------------
-- Range / opacity helpers
---------------------------------------------------------------------------
local function espRangeCheck(dist, rangeEnabled, rangeMax)
	if rangeEnabled and dist > rangeMax then return false end
	return true
end

local function espDistFill(baseFill, dist, rangeMax, distOpacity)
	if not distOpacity then return baseFill end
	local t = math.clamp(dist / rangeMax, 0, 1)
	return baseFill + (1 - baseFill) * t
end

---------------------------------------------------------------------------
-- Render loop
---------------------------------------------------------------------------
local function updateESP()
	if not masterEnabled then
		for _, data in pairs(espData) do
			if data.highlight then data.highlight.Enabled = false end
			if data.text then data.text.Visible = false end
		end
		if selfEspData and selfEspData.highlight then
			selfEspData.highlight.Enabled = false
		end
		for _, data in pairs(botEspData) do
			if data.highlight then data.highlight.Enabled = false end
			if data.text then data.text.Visible = false end
		end
		for _, data in pairs(trapEspData) do
			if data.highlight then data.highlight.Enabled = false end
			if data.text then data.text.Visible = false end
		end
		for _, data in pairs(zombieEspData) do
			if data.highlight then data.highlight.Enabled = false end
			if data.text then data.text.Visible = false end
		end
		for model, data in pairs(windowEspData) do
			if data.highlight then data.highlight.Enabled = false end
			if data.text then data.text.Visible = false end
			local bottom = model:FindFirstChild("Bottom")
			if bottom and data.origTransparency ~= nil then
				bottom.Transparency = data.origTransparency
			end
		end
		for _, data in pairs(palletEspData) do
			if data.highlight then data.highlight.Enabled = false end
			if data.text then data.text.Visible = false end
		end
		return
	end

	local camPos = Camera.CFrame.Position
	local localHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local refPos = localHrp and localHrp.Position or camPos

	local perf = HubRef and HubRef._perfESP
	local rangeEnabled = perf and perf.espRange
	local rangeMax = perf and perf.espRangeMax or 200
	local distOpacity = perf and perf.espDistOpacity

	-- player ESP
	for player, data in pairs(espData) do
		local char = player.Character
		local skip = playerTrack.ignoreSpectator and getTeamName(player) == "Spectator"
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local dist = hrp and (hrp.Position - refPos).Magnitude or 0
		local inRange = espRangeCheck(dist, rangeEnabled, rangeMax)
		local active = playerTrack.enabled and char and not skip and inRange

		if active then
			if not data.highlight then
				data.highlight = Instance.new("Highlight")
				applyPlayerHighlight(data.highlight, player)
				data.highlight.Adornee = char
				data.highlight.Parent = getHighlightParent()
			end
			if data.highlight.Adornee ~= char then
				data.highlight.Adornee = char
			end
			data.highlight.Enabled = true
			data.highlight.FillTransparency = espDistFill(playerTrack.fillTransparency, dist, rangeMax, distOpacity)
			data.highlight.OutlineTransparency = espDistFill(playerTrack.outlineTransparency, dist, rangeMax, distOpacity)

			if teamESP.enabled and teamESP.survivorHealth.enabled and getTeamName(player) == "Survivors" then
				applyPlayerHighlight(data.highlight, player)
				data.highlight.FillTransparency = espDistFill(data.highlight.FillTransparency, dist, rangeMax, distOpacity)
				data.highlight.OutlineTransparency = espDistFill(data.highlight.OutlineTransparency, dist, rangeMax, distOpacity)
			end
		else
			if data.highlight then data.highlight.Enabled = false end
		end

		if active and playerTrack.textOverlay then
			local head = char:FindFirstChild("Head")
			if head then
				local pos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))
				if onScreen then
					local label = player.DisplayName
					if playerTrack.showDistance then
						label = label .. " [" .. math.floor(dist) .. "m]"
					end
					data.text.Text = label
					data.text.Position = Vector2.new(pos.X, pos.Y - 20)
					data.text.Color = getPlayerColor(player)
					data.text.Visible = true
				else
					data.text.Visible = false
				end
			else
				data.text.Visible = false
			end
		else
			if data.text then data.text.Visible = false end
		end
	end

	-- self ESP
	if selfEspData then
		local char = LocalPlayer.Character
		local active = selfTrack.enabled and char

		if active then
			if not selfEspData.highlight then
				selfEspData.highlight = Instance.new("Highlight")
				applySelfHighlight(selfEspData.highlight)
				selfEspData.highlight.Adornee = char
				selfEspData.highlight.Parent = getHighlightParent()
			end
			if selfEspData.highlight.Adornee ~= char then
				selfEspData.highlight.Adornee = char
			end
			selfEspData.highlight.Enabled = true
		else
			if selfEspData.highlight then selfEspData.highlight.Enabled = false end
		end
	end

	-- bot ESP
	for model, data in pairs(botEspData) do
		local bHrp = model:FindFirstChild("HumanoidRootPart")
		local bDist = bHrp and (bHrp.Position - refPos).Magnitude or 0
		local bInRange = espRangeCheck(bDist, rangeEnabled, rangeMax)
		local active = botTrack.enabled and model.Parent ~= nil and bInRange

		if active then
			if not data.highlight then
				data.highlight = Instance.new("Highlight")
				applyBotHighlight(data.highlight, model)
				data.highlight.Adornee = model
				data.highlight.Parent = getHighlightParent()
			end
			data.highlight.Enabled = true
			data.highlight.FillTransparency = espDistFill(botTrack.fillTransparency, bDist, rangeMax, distOpacity)
			data.highlight.OutlineTransparency = espDistFill(botTrack.outlineTransparency, bDist, rangeMax, distOpacity)

			if teamESP.enabled and teamESP.survivorHealth.enabled then
				applyBotHighlight(data.highlight, model)
				data.highlight.FillTransparency = espDistFill(data.highlight.FillTransparency, bDist, rangeMax, distOpacity)
				data.highlight.OutlineTransparency = espDistFill(data.highlight.OutlineTransparency, bDist, rangeMax, distOpacity)
			end
		else
			if data.highlight then data.highlight.Enabled = false end
		end

		if active and botTrack.textOverlay then
			local head = model:FindFirstChild("Head")
			if head then
				local pos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))
				if onScreen then
					local label = model.Name .. " [BOT]"
					if botTrack.showDistance then
						label = label .. " [" .. math.floor(bDist) .. "m]"
					end
					data.text.Text = label
					data.text.Position = Vector2.new(pos.X, pos.Y - 20)
					data.text.Color = getBotColor(model)
					data.text.Visible = true
				else
					data.text.Visible = false
				end
			else
				data.text.Visible = false
			end
		else
			if data.text then data.text.Visible = false end
		end
	end

	-- trap ESP
	for model, data in pairs(trapEspData) do
		local tPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		local tDist = tPart and (tPart.Position - refPos).Magnitude or 0
		local tInRange = espRangeCheck(tDist, rangeEnabled, rangeMax)
		local active = trapTrack.enabled and model.Parent ~= nil and tInRange

		if active then
			if not data.highlight then
				data.highlight = Instance.new("Highlight")
				applyTrapHighlight(data.highlight)
				data.highlight.Adornee = model
				data.highlight.Parent = getHighlightParent()
			end
			data.highlight.Enabled = true
			data.highlight.FillTransparency = espDistFill(trapTrack.fillTransparency, tDist, rangeMax, distOpacity)
			data.highlight.OutlineTransparency = espDistFill(trapTrack.outlineTransparency, tDist, rangeMax, distOpacity)
		else
			if data.highlight then data.highlight.Enabled = false end
		end

		if active and trapTrack.textOverlay then
			if tPart then
				local pos, onScreen = Camera:WorldToViewportPoint(tPart.Position + Vector3.new(0, 1.5, 0))
				if onScreen then
					local label = "[Bear Trap]"
					if trapTrack.showDistance then
						label = label .. " [" .. math.floor(tDist) .. "m]"
					end
					data.text.Text = label
					data.text.Position = Vector2.new(pos.X, pos.Y - 20)
					data.text.Color = COLORS[trapTrack.color] or COLORS.white
					data.text.Visible = true
				else
					data.text.Visible = false
				end
			else
				data.text.Visible = false
			end
		else
			if data.text then data.text.Visible = false end
		end
	end

	-- zombie ESP
	for model, data in pairs(zombieEspData) do
		local isActive = model:GetAttribute("CorpseCreated0492") == true
		local isDead = model:GetAttribute("Ragdolled") == true
		local skip = false
		if zombieTrack.ignoreInactive and not isActive then skip = true end
		if zombieTrack.ignoreDead and isDead then skip = true end
		local zPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		local zDist = zPart and (zPart.Position - refPos).Magnitude or 0
		local zInRange = espRangeCheck(zDist, rangeEnabled, rangeMax)
		local active = zombieTrack.enabled and model.Parent ~= nil and not skip and zInRange

		if active then
			if not data.highlight then
				data.highlight = Instance.new("Highlight")
				applyZombieHighlight(data.highlight)
				data.highlight.Adornee = model
				data.highlight.Parent = getHighlightParent()
			end
			data.highlight.Enabled = true
			data.highlight.FillTransparency = espDistFill(zombieTrack.fillTransparency, zDist, rangeMax, distOpacity)
			data.highlight.OutlineTransparency = espDistFill(zombieTrack.outlineTransparency, zDist, rangeMax, distOpacity)
		else
			if data.highlight then data.highlight.Enabled = false end
		end

		if active and zombieTrack.textOverlay then
			if zPart then
				local pos, onScreen = Camera:WorldToViewportPoint(zPart.Position + Vector3.new(0, 2, 0))
				if onScreen then
					local label = "[SCP 049-2]"
					if isDead then label = "[SCP 049-2] (dead)" end
					if not isActive and not isDead then label = "[SCP 049-2] (inactive)" end
					if zombieTrack.showDistance then
						label = label .. " [" .. math.floor(zDist) .. "m]"
					end
					data.text.Text = label
					data.text.Position = Vector2.new(pos.X, pos.Y - 20)
					data.text.Color = COLORS[zombieTrack.color] or COLORS.white
					data.text.Visible = true
				else
					data.text.Visible = false
				end
			else
				data.text.Visible = false
			end
		else
			if data.text then data.text.Visible = false end
		end
	end

	-- window ESP
	for model, data in pairs(windowEspData) do
		local bottom = model:FindFirstChild("Bottom")
		local wPart = bottom or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		local wDist = wPart and (wPart.Position - refPos).Magnitude or 0
		local wInRange = espRangeCheck(wDist, rangeEnabled, rangeMax)
		local active = windowTrack.enabled and model.Parent ~= nil and wInRange

		if active then
			if bottom then bottom.Transparency = 0 end
			if not data.highlight then
				data.highlight = Instance.new("Highlight")
				applyWindowHighlight(data.highlight)
				data.highlight.Adornee = bottom or model
				data.highlight.Parent = getHighlightParent()
			end
			data.highlight.Enabled = true
			data.highlight.FillTransparency = espDistFill(windowTrack.fillTransparency, wDist, rangeMax, distOpacity)
			data.highlight.OutlineTransparency = espDistFill(windowTrack.outlineTransparency, wDist, rangeMax, distOpacity)
		else
			if data.highlight then data.highlight.Enabled = false end
			if bottom and data.origTransparency ~= nil then
				bottom.Transparency = data.origTransparency
			end
		end

		if active and windowTrack.textOverlay then
			if wPart then
				local pos, onScreen = Camera:WorldToViewportPoint(wPart.Position + Vector3.new(0, 1.5, 0))
				if onScreen then
					local label = "[Window]"
					if windowTrack.showDistance then
						label = label .. " [" .. math.floor(wDist) .. "m]"
					end
					data.text.Text = label
					data.text.Position = Vector2.new(pos.X, pos.Y - 20)
					data.text.Color = COLORS[windowTrack.color] or COLORS.white
					data.text.Visible = true
				else
					data.text.Visible = false
				end
			else
				data.text.Visible = false
			end
		else
			if data.text then data.text.Visible = false end
		end
	end

	-- pallet ESP
	for model, data in pairs(palletEspData) do
		local pPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		local pDist = pPart and (pPart.Position - refPos).Magnitude or 0
		local pInRange = espRangeCheck(pDist, rangeEnabled, rangeMax)
		local active = palletTrack.enabled and model.Parent ~= nil and pInRange

		if active then
			if not data.highlight then
				data.highlight = Instance.new("Highlight")
				applyPalletHighlight(data.highlight, model)
				data.highlight.Adornee = model
				data.highlight.Parent = getHighlightParent()
			else
				applyPalletHighlight(data.highlight, model)
			end
			data.highlight.Enabled = true
			data.highlight.FillTransparency = espDistFill(data.highlight.FillTransparency, pDist, rangeMax, distOpacity)
			data.highlight.OutlineTransparency = espDistFill(data.highlight.OutlineTransparency, pDist, rangeMax, distOpacity)
		else
			if data.highlight then data.highlight.Enabled = false end
		end

		if active and palletTrack.textOverlay then
			if pPart then
				local pos, onScreen = Camera:WorldToViewportPoint(pPart.Position + Vector3.new(0, 2, 0))
				if onScreen then
					local state = model:GetAttribute("PalletState")
					local dropped = state == "Dropped"
					local label = dropped and "[Pallet] (dropped)" or "[Pallet]"
					if palletTrack.showDistance then
						label = label .. " [" .. math.floor(pDist) .. "m]"
					end
					data.text.Text = label
					data.text.Position = Vector2.new(pos.X, pos.Y - 20)
					local c = COLORS[palletTrack.color] or COLORS.white
					if dropped then c = dimColor(c) end
					data.text.Color = c
					data.text.Visible = true
				else
					data.text.Visible = false
				end
			else
				data.text.Visible = false
			end
		else
			if data.text then data.text.Visible = false end
		end
	end
end

local function destroyAll()
	for player in pairs(espData) do
		removeESP(player)
	end
	removeSelfESP()
	for model in pairs(botEspData) do
		removeBotESP(model)
	end
	for model in pairs(botWatchers) do
		clearBotWatcher(model)
	end
	for model in pairs(trapEspData) do
		removeTrapESP(model)
	end
	for model in pairs(zombieEspData) do
		removeZombieESP(model)
	end
	for model in pairs(windowEspData) do
		removeWindowESP(model)
	end
	for model in pairs(palletEspData) do
		removePalletESP(model)
	end
	if highlightFolder then
		pcall(highlightFolder.Destroy, highlightFolder)
		highlightFolder = nil
	end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function init(Hub, UI)
	HubRef = Hub
	local T = UI.Theme
	local H = UI.Helpers
	local C = UI.Constants
	local ROW_H = C.ROW_H

	for name, entry in pairs(UI.Colors) do
		COLORS[name] = entry.color
	end
	for _, name in ipairs(UI.ColorList) do
		table.insert(COLOR_NAMES, name)
	end

	local tab = Hub:Tab("visuals")

	tab:Section("esp")
	local masterToggle = tab:Toggle("master esp", false, function(on)
		masterEnabled = on
		masterESP.enabled = on
		Hub:Log(on and "esp enabled" or "esp disabled")
	end, "masterESP")

	local function track(name, state, buildContent, onToggle, bindId)
		tab.Order = tab.Order + 1
		local headerOrder = tab.Order
		local row = H.Frame(tab.Page, {
			Name = "Track_" .. name,
			LayoutOrder = headerOrder,
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundTransparency = 1,
		})
		local hit = H.Button(row, "", {Name = "Hit", Size = UDim2.fromScale(1, 1)})
		hit.MouseEnter:Connect(function() H.tween(hit, {BackgroundTransparency = 0.35}) end)
		hit.MouseLeave:Connect(function() H.tween(hit, {BackgroundTransparency = 1}) end)

		local caret = H.Text(hit, "[+]", {Position = H.U(8, 0), Size = H.U(24, ROW_H), TextColor3 = T.dim})
		local nameEnd = bindId and -172 or -120
		H.Text(hit, name, {Position = H.U(36, 0), Size = UDim2.new(1, nameEnd, 1, 0), TextColor3 = T.text})

		local toggleBox = H.Text(hit, "[ ]", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = H.U(28, ROW_H),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = T.dim,
		})
		local toggleVal = H.Text(hit, "off", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -40, 0, 0),
			Size = H.U(32, ROW_H),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 11,
			TextColor3 = T.dim,
		})

		local function renderToggle()
			toggleBox.Text = state.enabled and "[x]" or "[ ]"
			toggleBox.TextColor3 = state.enabled and T.white or T.dim
			toggleVal.Text = state.enabled and "on" or "off"
			toggleVal.TextColor3 = state.enabled and T.white or T.dim
		end
		renderToggle()

		if bindId then
			local bindBox = H.Button(hit, "", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -74, 0.5, 0),
				Size = H.U(46, 16),
				TextSize = 10,
				FontFace = UI.Fonts.Medium,
				TextColor3 = T.mid,
				BackgroundColor3 = T.raised,
				BackgroundTransparency = 0,
			})
			H.Stroke(bindBox, T.line)
			Hub._keybindRenders = Hub._keybindRenders or {}
			local function renderBind()
				if Hub._keybindListening == bindId then
					bindBox.Text = "..."
					bindBox.TextColor3 = T.accent
				else
					local k = Hub._keybinds[bindId]
					bindBox.Text = k or "none"
					bindBox.TextColor3 = k and T.text or T.dim
				end
			end
			Hub._keybindRenders[bindId] = renderBind
			renderBind()
			bindBox.MouseButton1Click:Connect(function()
				Hub:StartListening(bindId)
			end)
			bindBox.MouseButton2Click:Connect(function()
				Hub:ClearKeybind(bindId)
			end)
			local toggleHandle = {
				Set = function(_, v)
					state.enabled = v == true
					renderToggle()
					if onToggle then pcall(onToggle, state.enabled) end
				end,
				Get = function() return state.enabled end,
			}
			Hub:RegisterKeybind(bindId, toggleHandle, name)
		end

		tab.Order = tab.Order + 1
		local content = H.Frame(tab.Page, {
			Name = "Track_" .. name .. "_Content",
			LayoutOrder = tab.Order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = false,
		})
		H.List(content, 2)
		local contentOrder = 0

		local sub = {}

		function sub:Row(h)
			contentOrder = contentOrder + 1
			return H.Frame(content, {
				Name = "SubRow",
				LayoutOrder = contentOrder,
				Size = UDim2.new(1, 0, 0, h or 22),
				BackgroundTransparency = 1,
			})
		end

		function sub:Toggle(label, default, callback)
			local sRow = sub:Row(22)
			local sState = default == true
			local pad = H.Frame(sRow, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
			H.Pad(pad, 0, 0, 0, 20)
			local sHit = H.Button(pad, "", {Size = UDim2.fromScale(1, 1)})
			sHit.MouseEnter:Connect(function() H.tween(sHit, {BackgroundTransparency = 0.35}) end)
			sHit.MouseLeave:Connect(function() H.tween(sHit, {BackgroundTransparency = 1}) end)
			local box = H.Text(sHit, "", {Position = H.U(8, 0), Size = H.U(28, 22), TextColor3 = T.white})
			H.Text(sHit, label, {Position = H.U(36, 0), Size = UDim2.new(1, -80, 1, 0), TextSize = 11})
			local val = H.Text(sHit, "", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = H.U(32, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 11,
			})
			local function render()
				box.Text = sState and "[x]" or "[ ]"
				box.TextColor3 = sState and T.white or T.dim
				val.Text = sState and "on" or "off"
				val.TextColor3 = sState and T.white or T.dim
			end
			render()
			sHit.MouseButton1Click:Connect(function()
				sState = not sState
				render()
				if callback then pcall(callback, sState) end
			end)
			return { Get = function() return sState end, Set = function(_, v) sState = v; render() end }
		end

		function sub:Choice(label, options, default, callback)
			local sRow = sub:Row(22)
			local index = table.find(options, default) or 1
			local pad = H.Frame(sRow, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
			H.Pad(pad, 0, 0, 0, 20)
			H.Text(pad, label, {Position = H.U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
			local val = H.Button(pad, tostring(options[index]), {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = H.U(80, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = UI.Fonts.Medium,
				TextColor3 = T.white,
				TextSize = 11,
			})
			val.MouseEnter:Connect(function() val.TextColor3 = T.white end)
			val.MouseLeave:Connect(function() val.TextColor3 = T.mid end)
			val.MouseButton1Click:Connect(function()
				index = (index % #options) + 1
				val.Text = tostring(options[index])
				if callback then pcall(callback, options[index]) end
			end)
			return { Get = function() return options[index] end }
		end

		function sub:Slider(label, min, max, default, callback, opts)
			opts = opts or {}
			local step = opts.Step or 0.1
			local sRow = sub:Row(22)
			local value = math.clamp(default or min, min, max)
			local pad = H.Frame(sRow, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
			H.Pad(pad, 0, 0, 0, 20)
			H.Text(pad, label, {Position = H.U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
			local valLabel = H.Text(pad, string.format("%.1f", value), {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = H.U(40, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 11,
				TextColor3 = T.white,
			})
			local BAR = 10
			local bar = H.Button(pad, "", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -50, 0.5, 0),
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				RichText = true,
				TextColor3 = T.dim,
				TextSize = 12,
			})
			local function render()
				local filled = math.floor((value - min) / (max - min) * BAR + 0.5)
				bar.Text = '[<font color="#E2E2E2">' .. string.rep("#", filled) .. '</font><font color="#3A3A3A">' .. string.rep("-", BAR - filled) .. '</font>]'
				valLabel.Text = string.format("%.1f", value)
			end
			local function set(v)
				v = math.clamp(min + math.floor((v - min) / step + 0.5) * step, min, max)
				if v == value then return end
				value = v
				render()
				if callback then pcall(callback, value) end
			end
			render()
			local dragging = false
			bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					local size = bar.AbsoluteSize.X
					local cw = size / (BAR + 2)
					local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X - cw) / (size - 2 * cw), 0, 1)
					set(min + (max - min) * ratio)
				end
			end)
			local UIS = game:GetService("UserInputService")
			Hub:_track(UIS.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					local size = bar.AbsoluteSize.X
					local cw = size / (BAR + 2)
					local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X - cw) / (size - 2 * cw), 0, 1)
					set(min + (max - min) * ratio)
				end
			end))
			Hub:_track(UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end))
			return { Get = function() return value end, Set = function(_, v) set(v) end }
		end

		function sub:Track(tName, tState, buildInner, tOnToggle)
			local sRow = sub:Row(22)
			local sHit = H.Button(sRow, "", {Name = "Hit", Size = UDim2.fromScale(1, 1)})
			sHit.MouseEnter:Connect(function() H.tween(sHit, {BackgroundTransparency = 0.35}) end)
			sHit.MouseLeave:Connect(function() H.tween(sHit, {BackgroundTransparency = 1}) end)

			local iPad = H.Frame(sHit, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
			H.Pad(iPad, 0, 0, 0, 20)

			local sCaret = H.Text(iPad, "[+]", {Position = H.U(8, 0), Size = H.U(24, 22), TextColor3 = T.dim})
			H.Text(iPad, tName, {Position = H.U(36, 0), Size = UDim2.new(1, -120, 1, 0), TextSize = 11, TextColor3 = T.text})

			local sToggleBox = H.Text(iPad, "[ ]", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = H.U(28, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = T.dim,
			})
			local sToggleVal = H.Text(iPad, "off", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -40, 0, 0),
				Size = H.U(32, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 11,
				TextColor3 = T.dim,
			})

			local function sRenderToggle()
				sToggleBox.Text = tState.enabled and "[x]" or "[ ]"
				sToggleBox.TextColor3 = tState.enabled and T.white or T.dim
				sToggleVal.Text = tState.enabled and "on" or "off"
				sToggleVal.TextColor3 = tState.enabled and T.white or T.dim
			end
			sRenderToggle()

			contentOrder = contentOrder + 1
			local innerContent = H.Frame(content, {
				Name = "SubTrack_" .. tName,
				LayoutOrder = contentOrder,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = false,
			})
			H.List(innerContent, 2)
			local innerOrder = 0

			local inner = {}

			function inner:Choice(label, options, default, callback)
				innerOrder = innerOrder + 1
				local iRow = H.Frame(innerContent, {
					LayoutOrder = innerOrder,
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
				})
				local index = table.find(options, default) or 1
				local ipad = H.Frame(iRow, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
				H.Pad(ipad, 0, 0, 0, 40)
				H.Text(ipad, label, {Position = H.U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
				local ival = H.Button(ipad, tostring(options[index]), {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 0),
					Size = H.U(80, 22),
					TextXAlignment = Enum.TextXAlignment.Right,
					FontFace = UI.Fonts.Medium,
					TextColor3 = T.white,
					TextSize = 11,
				})
				ival.MouseEnter:Connect(function() ival.TextColor3 = T.white end)
				ival.MouseLeave:Connect(function() ival.TextColor3 = T.mid end)
				ival.MouseButton1Click:Connect(function()
					index = (index % #options) + 1
					ival.Text = tostring(options[index])
					if callback then pcall(callback, options[index]) end
				end)
				return { Get = function() return options[index] end }
			end

			local sExpanded = false
			sHit.MouseButton1Click:Connect(function()
				local mouseX = game:GetService("UserInputService"):GetMouseLocation().X
				local toggleRegionStart = sRow.AbsolutePosition.X + sRow.AbsoluteSize.X - 80
				if mouseX >= toggleRegionStart then
					tState.enabled = not tState.enabled
					sRenderToggle()
					if tOnToggle then pcall(tOnToggle, tState.enabled) end
				else
					sExpanded = not sExpanded
					innerContent.Visible = sExpanded
					sCaret.Text = sExpanded and "[-]" or "[+]"
				end
			end)

			buildInner(inner)
			return tState
		end

		local expanded = false
		local function toggleExpand()
			expanded = not expanded
			content.Visible = expanded
			caret.Text = expanded and "[-]" or "[+]"
		end

		hit.MouseButton1Click:Connect(function()
			local mouseX = game:GetService("UserInputService"):GetMouseLocation().X
			local rowRight = row.AbsolutePosition.X + row.AbsoluteSize.X
			if bindId then
				local bindStart = rowRight - 120
				local bindEnd = rowRight - 74
				if mouseX >= bindStart and mouseX <= bindEnd then return end
			end
			local toggleRegionStart = rowRight - 80
			if mouseX >= toggleRegionStart then
				state.enabled = not state.enabled
				renderToggle()
				if onToggle then pcall(onToggle, state.enabled) end
			else
				toggleExpand()
			end
		end)

		buildContent(sub)
		return { state = state, sync = renderToggle }
	end

	-- team ESP
	local teamHandle = track("team esp", teamESP, function(sub)
		sub:Choice("spectator", COLOR_NAMES, teamESP.colors.Spectator, function(c)
			teamESP.colors.Spectator = c
			refreshPlayerHighlights()
		end)
		sub:Choice("survivors", COLOR_NAMES, teamESP.colors.Survivors, function(c)
			teamESP.colors.Survivors = c
			refreshPlayerHighlights()
			refreshBotHighlights()
		end)
		sub:Choice("killer", COLOR_NAMES, teamESP.colors.Killer, function(c)
			teamESP.colors.Killer = c
			refreshPlayerHighlights()
		end)

		sub:Track("health state esp", teamESP.survivorHealth, function(inner)
			inner:Choice("healthy", COLOR_NAMES, teamESP.survivorHealth.healthy, function(c)
				teamESP.survivorHealth.healthy = c
				refreshPlayerHighlights()
				refreshBotHighlights()
			end)
			inner:Choice("injured", COLOR_NAMES, teamESP.survivorHealth.injured, function(c)
				teamESP.survivorHealth.injured = c
				refreshPlayerHighlights()
				refreshBotHighlights()
			end)
			inner:Choice("downed", COLOR_NAMES, teamESP.survivorHealth.downed, function(c)
				teamESP.survivorHealth.downed = c
				refreshPlayerHighlights()
				refreshBotHighlights()
			end)
		end, function()
			refreshPlayerHighlights()
			refreshBotHighlights()
		end)
	end, function()
		refreshPlayerHighlights()
		refreshBotHighlights()
	end, "teamESP")

	-- tracks
	tab:Section("tracks")

	local playerHandle = track("player esp", playerTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, playerTrack.color, function(c)
			playerTrack.color = c
			refreshPlayerHighlights()
		end)

		sub:Choice("depth mode", DEPTH_MODES, playerTrack.depthMode, function(v)
			playerTrack.depthMode = v
			refreshPlayerHighlights()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - playerTrack.fillTransparency, function(v)
			playerTrack.fillTransparency = 1 - v
			refreshPlayerHighlights()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - playerTrack.outlineTransparency, function(v)
			playerTrack.outlineTransparency = 1 - v
			refreshPlayerHighlights()
		end, { Step = 0.1 })

		sub:Toggle("text overlay", playerTrack.textOverlay, function(on)
			playerTrack.textOverlay = on
		end)

		sub:Toggle("show distance", playerTrack.showDistance, function(on)
			playerTrack.showDistance = on
		end)

		sub:Toggle("ignore spectator", playerTrack.ignoreSpectator, function(on)
			playerTrack.ignoreSpectator = on
		end)
	end, nil, "playerESP")

	local botHandle = track("bot esp", botTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, botTrack.color, function(c)
			botTrack.color = c
			refreshBotHighlights()
		end)

		sub:Choice("depth mode", DEPTH_MODES, botTrack.depthMode, function(v)
			botTrack.depthMode = v
			refreshBotHighlights()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - botTrack.fillTransparency, function(v)
			botTrack.fillTransparency = 1 - v
			refreshBotHighlights()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - botTrack.outlineTransparency, function(v)
			botTrack.outlineTransparency = 1 - v
			refreshBotHighlights()
		end, { Step = 0.1 })

		sub:Toggle("text overlay", botTrack.textOverlay, function(on)
			botTrack.textOverlay = on
		end)

		sub:Toggle("show distance", botTrack.showDistance, function(on)
			botTrack.showDistance = on
		end)
	end)

	local selfHandle = track("self esp", selfTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, selfTrack.color, function(c)
			selfTrack.color = c
			refreshSelfHighlight()
		end)

		sub:Choice("depth mode", DEPTH_MODES, selfTrack.depthMode, function(v)
			selfTrack.depthMode = v
			refreshSelfHighlight()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - selfTrack.fillTransparency, function(v)
			selfTrack.fillTransparency = 1 - v
			refreshSelfHighlight()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - selfTrack.outlineTransparency, function(v)
			selfTrack.outlineTransparency = 1 - v
			refreshSelfHighlight()
		end, { Step = 0.1 })
	end)

	local palletHandle = track("pallet esp", palletTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, palletTrack.color, function(c)
			palletTrack.color = c
			refreshPalletHighlights()
		end)

		sub:Choice("depth mode", DEPTH_MODES, palletTrack.depthMode, function(v)
			palletTrack.depthMode = v
			refreshPalletHighlights()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - palletTrack.fillTransparency, function(v)
			palletTrack.fillTransparency = 1 - v
			refreshPalletHighlights()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - palletTrack.outlineTransparency, function(v)
			palletTrack.outlineTransparency = 1 - v
			refreshPalletHighlights()
		end, { Step = 0.1 })

		sub:Toggle("text overlay", palletTrack.textOverlay, function(on)
			palletTrack.textOverlay = on
		end)

		sub:Toggle("show distance", palletTrack.showDistance, function(on)
			palletTrack.showDistance = on
		end)
	end)

	local windowHandle = track("window esp", windowTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, windowTrack.color, function(c)
			windowTrack.color = c
			refreshWindowHighlights()
		end)

		sub:Choice("depth mode", DEPTH_MODES, windowTrack.depthMode, function(v)
			windowTrack.depthMode = v
			refreshWindowHighlights()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - windowTrack.fillTransparency, function(v)
			windowTrack.fillTransparency = 1 - v
			refreshWindowHighlights()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - windowTrack.outlineTransparency, function(v)
			windowTrack.outlineTransparency = 1 - v
			refreshWindowHighlights()
		end, { Step = 0.1 })

		sub:Toggle("text overlay", windowTrack.textOverlay, function(on)
			windowTrack.textOverlay = on
		end)

		sub:Toggle("show distance", windowTrack.showDistance, function(on)
			windowTrack.showDistance = on
		end)
	end)

	local zombieHandle = track("scp 049-2 esp", zombieTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, zombieTrack.color, function(c)
			zombieTrack.color = c
			refreshZombieHighlights()
		end)

		sub:Choice("depth mode", DEPTH_MODES, zombieTrack.depthMode, function(v)
			zombieTrack.depthMode = v
			refreshZombieHighlights()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - zombieTrack.fillTransparency, function(v)
			zombieTrack.fillTransparency = 1 - v
			refreshZombieHighlights()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - zombieTrack.outlineTransparency, function(v)
			zombieTrack.outlineTransparency = 1 - v
			refreshZombieHighlights()
		end, { Step = 0.1 })

		sub:Toggle("text overlay", zombieTrack.textOverlay, function(on)
			zombieTrack.textOverlay = on
		end)

		sub:Toggle("show distance", zombieTrack.showDistance, function(on)
			zombieTrack.showDistance = on
		end)

		sub:Toggle("ignore inactive", zombieTrack.ignoreInactive, function(on)
			zombieTrack.ignoreInactive = on
		end)

		sub:Toggle("ignore dead", zombieTrack.ignoreDead, function(on)
			zombieTrack.ignoreDead = on
		end)
	end)

	local trapHandle = track("bear trap esp", trapTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, trapTrack.color, function(c)
			trapTrack.color = c
			refreshTrapHighlights()
		end)

		sub:Choice("depth mode", DEPTH_MODES, trapTrack.depthMode, function(v)
			trapTrack.depthMode = v
			refreshTrapHighlights()
		end)

		sub:Slider("fill opacity", 0, 1, 1 - trapTrack.fillTransparency, function(v)
			trapTrack.fillTransparency = 1 - v
			refreshTrapHighlights()
		end, { Step = 0.1 })

		sub:Slider("outline opacity", 0, 1, 1 - trapTrack.outlineTransparency, function(v)
			trapTrack.outlineTransparency = 1 - v
			refreshTrapHighlights()
		end, { Step = 0.1 })

		sub:Toggle("text overlay", trapTrack.textOverlay, function(on)
			trapTrack.textOverlay = on
		end)

		sub:Toggle("show distance", trapTrack.showDistance, function(on)
			trapTrack.showDistance = on
		end)
	end)

	-- connect players
	for _, player in ipairs(Players:GetPlayers()) do
		createESP(player)
	end
	createSelfESP()

	Hub:_track(Players.PlayerAdded:Connect(function(player)
		createESP(player)
	end))
	Hub:_track(Players.PlayerRemoving:Connect(removeESP))

	-- scan workspace for bots
	for _, child in ipairs(workspace:GetChildren()) do
		scanWorkspaceChild(child)
	end
	Hub:_track(workspace.ChildAdded:Connect(scanWorkspaceChild))

	-- scan workspace for bear traps
	for _, desc in ipairs(workspace:GetDescendants()) do
		if isTrap(desc) then createTrapESP(desc) end
	end
	Hub:_track(workspace.DescendantAdded:Connect(function(desc)
		if isTrap(desc) then createTrapESP(desc) end
		if isZombie(desc) then createZombieESP(desc) end
		if isWindow(desc) then createWindowESP(desc) end
		if isPallet(desc) then createPalletESP(desc) end
	end))

	-- scan workspace for zombies, windows, pallets
	for _, desc in ipairs(workspace:GetDescendants()) do
		if isZombie(desc) then createZombieESP(desc) end
		if isWindow(desc) then createWindowESP(desc) end
		if isPallet(desc) then createPalletESP(desc) end
	end

	Hub:_track(RunService.RenderStepped:Connect(updateESP))

	local function refreshAll()
		refreshPlayerHighlights()
		refreshSelfHighlight()
		refreshBotHighlights()
		refreshTrapHighlights()
		refreshZombieHighlights()
		refreshWindowHighlights()
		refreshPalletHighlights()
	end

	Hub:RegisterConfig("masterESP", masterESP)
	Hub:RegisterConfig("playerTrack", playerTrack, refreshAll)
	Hub:RegisterConfig("selfTrack", selfTrack, refreshAll)
	Hub:RegisterConfig("teamESP", teamESP, refreshAll)
	Hub:RegisterConfig("botTrack", botTrack, refreshAll)
	Hub:RegisterConfig("trapTrack", trapTrack, refreshAll)
	Hub:RegisterConfig("zombieTrack", zombieTrack, refreshAll)
	Hub:RegisterConfig("windowTrack", windowTrack, refreshAll)
	Hub:RegisterConfig("palletTrack", palletTrack, refreshAll)
	Hub:OnConfigLoad(function()
		masterEnabled = masterESP.enabled
		masterToggle:Set(masterESP.enabled)
		teamHandle.sync()
		playerHandle.sync()
		selfHandle.sync()
		botHandle.sync()
		trapHandle.sync()
		zombieHandle.sync()
		windowHandle.sync()
		palletHandle.sync()
	end)
	Hub:RegisterCleanup(destroyAll)
end

return { init = init }
