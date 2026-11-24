--[[ Photon VD — Visuals Tab (ESP) ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local COLORS = {
	white  = Color3.new(1, 1, 1),
	red    = Color3.fromRGB(255, 50, 50),
	blue   = Color3.fromRGB(50, 120, 255),
	green  = Color3.fromRGB(50, 255, 100),
	yellow = Color3.fromRGB(255, 255, 50),
	purple = Color3.fromRGB(180, 50, 255),
	cyan   = Color3.fromRGB(50, 255, 255),
}
local COLOR_NAMES = {"white", "red", "blue", "green", "yellow", "purple", "cyan"}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local masterEnabled = false

local playerTrack = {
	enabled = false,
	color = "white",
	fillTransparency = 0.7,
	outlineTransparency = 0,
	textOverlay = true,
	showDistance = true,
	ignoreSpectator = false,
}

local selfTrack = {
	enabled = false,
	color = "white",
	fillTransparency = 0.7,
	outlineTransparency = 0,
}

local teamESP = {
	enabled = false,
	colors = {
		Spectator = "white",
		Survivor = "blue",
		Killer = "red",
	},
}

local espData = {}
local selfEspData = nil
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

local function getPlayerColor(player)
	if teamESP.enabled then
		local teamName = getTeamName(player)
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
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function applySelfHighlight(hl)
	local c = COLORS[selfTrack.color] or COLORS.white
	hl.OutlineColor = c
	hl.FillColor = c
	hl.OutlineTransparency = selfTrack.outlineTransparency
	hl.FillTransparency = selfTrack.fillTransparency
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
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
		return
	end

	local camPos = Camera.CFrame.Position
	local localHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local refPos = localHrp and localHrp.Position or camPos

	for player, data in pairs(espData) do
		local char = player.Character
		local skip = playerTrack.ignoreSpectator and getTeamName(player) == "Spectator"
		local active = playerTrack.enabled and char and not skip

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
						local dist = (head.Position - refPos).Magnitude
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
end

local function destroyAll()
	for player in pairs(espData) do
		removeESP(player)
	end
	removeSelfESP()
	if highlightFolder then
		pcall(highlightFolder.Destroy, highlightFolder)
		highlightFolder = nil
	end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function init(Hub, UI)
	local T = UI.Theme
	local H = UI.Helpers
	local C = UI.Constants
	local ROW_H = C.ROW_H

	local tab = Hub:Tab("visuals")

	tab:Section("esp")
	tab:Toggle("master esp", false, function(on)
		masterEnabled = on
		Hub:Log(on and "esp enabled" or "esp disabled")
	end)

	local function track(name, state, buildContent, onToggle)
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
		H.Text(hit, name, {Position = H.U(36, 0), Size = UDim2.new(1, -120, 1, 0), TextColor3 = T.text})

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

		local expanded = false
		local function toggleExpand()
			expanded = not expanded
			content.Visible = expanded
			caret.Text = expanded and "[-]" or "[+]"
		end

		hit.MouseButton1Click:Connect(function()
			local mouseX = game:GetService("UserInputService"):GetMouseLocation().X
			local toggleRegionStart = row.AbsolutePosition.X + row.AbsoluteSize.X - 80
			if mouseX >= toggleRegionStart then
				state.enabled = not state.enabled
				renderToggle()
				if onToggle then pcall(onToggle, state.enabled) end
			else
				toggleExpand()
			end
		end)

		buildContent(sub)
		return state
	end

	track("team esp", teamESP, function(sub)
		sub:Choice("spectator", COLOR_NAMES, teamESP.colors.Spectator, function(c)
			teamESP.colors.Spectator = c
			refreshPlayerHighlights()
		end)
		sub:Choice("survivor", COLOR_NAMES, teamESP.colors.Survivor, function(c)
			teamESP.colors.Survivor = c
			refreshPlayerHighlights()
		end)
		sub:Choice("killer", COLOR_NAMES, teamESP.colors.Killer, function(c)
			teamESP.colors.Killer = c
			refreshPlayerHighlights()
		end)
	end, function()
		refreshPlayerHighlights()
	end)

	tab:Section("tracks")

	track("player esp", playerTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, playerTrack.color, function(c)
			playerTrack.color = c
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
	end)

	track("self esp", selfTrack, function(sub)
		sub:Choice("color", COLOR_NAMES, selfTrack.color, function(c)
			selfTrack.color = c
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

	for _, player in ipairs(Players:GetPlayers()) do
		createESP(player)
	end
	createSelfESP()

	Hub:_track(Players.PlayerAdded:Connect(function(player)
		createESP(player)
	end))

	Hub:_track(Players.PlayerRemoving:Connect(removeESP))
	Hub:_track(RunService.RenderStepped:Connect(updateESP))
end

return { init = init }
