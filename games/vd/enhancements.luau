--[[ Photon VD — Enhancements Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local SPEED_METHODS = { "cframe", "attribute" }

local function init(Hub, UI)
	local tab = Hub:Tab("enhancements")

	local T = UI.Theme
	local H = UI.Helpers
	local C = UI.Constants
	local ROW_H = C.ROW_H

	local COLOR_MAP = {}
	local COLOR_NAMES = {}
	for name, entry in pairs(UI.Colors) do
		COLOR_MAP[name] = entry.color
	end
	for _, name in ipairs(UI.ColorList) do
		table.insert(COLOR_NAMES, name)
	end

	----------------------------------------------------------------
	-- State
	----------------------------------------------------------------
	local enhState = {
		speedEnabled = false,
		speedMultiplier = 1.05,
		speedMethod = "cframe",
		vaultSpeedEnabled = false,
		vaultSpeedMultiplier = 1.5,
		alwaysFastVault = false,
		preset1 = 1.03,
		preset2 = 1.05,
		preset3 = 1.08,
		spearTrajectory = false,
		trajColor = "cyan",
		trajOnTargetColor = "green",
		trajTransparency = 0.5,
		trajNoclip = false,
	}

	local speedConn = nil
	local vaultSpeedConn = nil
	local savedVaultEvaluate = nil
	local vaultModule = nil
	local activePreset = 0
	local presetGuard = false

	----------------------------------------------------------------
	-- Helpers
	----------------------------------------------------------------
	local function getCharacter()
		return LocalPlayer.Character
	end

	local function getVaultModule()
		if vaultModule then return vaultModule end
		local ok, mod = pcall(function()
			return require(ReplicatedStorage.Modules.Survivors.SurvivorVault)
		end)
		if ok and mod then vaultModule = mod end
		return vaultModule
	end

	----------------------------------------------------------------
	-- Speed apply
	----------------------------------------------------------------
	local function applySpeed()
		if speedConn then speedConn:Disconnect(); speedConn = nil end
		if enhState.speedEnabled then
			if enhState.speedMethod == "cframe" then
				speedConn = RunService.Heartbeat:Connect(function(dt)
					local c = getCharacter()
					if not c then return end
					local root = c:FindFirstChild("HumanoidRootPart")
					if not root then return end
					local vel = root.AssemblyLinearVelocity
					local h = Vector3.new(vel.X, 0, vel.Z)
					if h.Magnitude < 0.5 then return end
					root.CFrame = root.CFrame + h.Unit * (enhState.speedMultiplier - 1) * h.Magnitude * dt
				end)
			else
				speedConn = RunService.Heartbeat:Connect(function()
					local c = getCharacter()
					if c then c:SetAttribute("speedboost", enhState.speedMultiplier) end
				end)
			end
		else
			if enhState.speedMethod == "attribute" then
				local c = getCharacter()
				if c then c:SetAttribute("speedboost", 1) end
			end
		end
	end

	----------------------------------------------------------------
	-- Vault apply
	----------------------------------------------------------------
	local function applyVaultSpeed()
		if vaultSpeedConn then vaultSpeedConn:Disconnect(); vaultSpeedConn = nil end
		if enhState.vaultSpeedEnabled then
			vaultSpeedConn = RunService.Heartbeat:Connect(function()
				local c = getCharacter()
				if c then c:SetAttribute("vaultspeed", enhState.vaultSpeedMultiplier) end
			end)
		else
			local c = getCharacter()
			if c then c:SetAttribute("vaultspeed", 1) end
		end
	end

	local function applyFastVault()
		local mod = getVaultModule()
		if not mod then return end
		if enhState.alwaysFastVault then
			if not savedVaultEvaluate then
				savedVaultEvaluate = mod.evaluate
			end
			mod.evaluate = function(_, state)
				if state.blocked then return false, "locked" end
				return true, "ready", mod.DISTANCE or 3.5
			end
		else
			if savedVaultEvaluate then
				mod.evaluate = savedVaultEvaluate
				savedVaultEvaluate = nil
			end
		end
	end

	----------------------------------------------------------------
	-- Speed section
	----------------------------------------------------------------
	tab:Section("speed")

	local speedSlider
	local preset1Toggle, preset2Toggle, preset3Toggle

	local speedToggle = tab:Toggle("speed modifier", false, function(on)
		if presetGuard then return end
		enhState.speedEnabled = on
		if not on then
			presetGuard = true
			activePreset = 0
			if preset1Toggle then preset1Toggle:Set(false) end
			if preset2Toggle then preset2Toggle:Set(false) end
			if preset3Toggle then preset3Toggle:Set(false) end
			presetGuard = false
		end
		applySpeed()
	end, "speedMod")

	speedSlider = tab:Slider("speed multiplier", 1.0, 1.50, enhState.speedMultiplier, function(v)
		enhState.speedMultiplier = v
	end, { Step = 0.01, Suffix = "x" })

	local methodChoice = tab:Choice("method", SPEED_METHODS, enhState.speedMethod, function(v)
		enhState.speedMethod = v
		if enhState.speedEnabled then applySpeed() end
	end)

	tab:Label("cframe nudges position — less detectable. attribute sets speedboost — more detectable, rubber bands above ~1.08x.")

	----------------------------------------------------------------
	-- Speed presets
	----------------------------------------------------------------
	tab:Section("speed presets")

	local function onPreset(n, getVal, others)
		return function(on)
			if presetGuard then return end
			presetGuard = true
			if on then
				activePreset = n
				enhState.speedMultiplier = getVal()
				enhState.speedEnabled = true
				speedSlider:Set(getVal())
				speedToggle:Set(true)
				for _, t in ipairs(others()) do t:Set(false) end
			else
				if activePreset == n then
					activePreset = 0
					enhState.speedEnabled = false
					speedToggle:Set(false)
				end
			end
			applySpeed()
			presetGuard = false
		end
	end

	preset1Toggle = tab:Toggle("preset 1", false,
		onPreset(1, function() return enhState.preset1 end, function() return {preset2Toggle, preset3Toggle} end),
		"speedP1")

	tab:Slider("preset 1 value", 1.0, 1.50, enhState.preset1, function(v)
		enhState.preset1 = v
		if activePreset == 1 then
			enhState.speedMultiplier = v
			speedSlider:Set(v)
		end
	end, { Step = 0.01, Suffix = "x" })

	preset2Toggle = tab:Toggle("preset 2", false,
		onPreset(2, function() return enhState.preset2 end, function() return {preset1Toggle, preset3Toggle} end),
		"speedP2")

	tab:Slider("preset 2 value", 1.0, 1.50, enhState.preset2, function(v)
		enhState.preset2 = v
		if activePreset == 2 then
			enhState.speedMultiplier = v
			speedSlider:Set(v)
		end
	end, { Step = 0.01, Suffix = "x" })

	preset3Toggle = tab:Toggle("preset 3", false,
		onPreset(3, function() return enhState.preset3 end, function() return {preset1Toggle, preset2Toggle} end),
		"speedP3")

	tab:Slider("preset 3 value", 1.0, 1.50, enhState.preset3, function(v)
		enhState.preset3 = v
		if activePreset == 3 then
			enhState.speedMultiplier = v
			speedSlider:Set(v)
		end
	end, { Step = 0.01, Suffix = "x" })

	----------------------------------------------------------------
	-- Vault section
	----------------------------------------------------------------
	tab:Section("vault")

	local vaultSpeedToggle = tab:Toggle("vault speed modifier", false, function(on)
		enhState.vaultSpeedEnabled = on
		applyVaultSpeed()
	end, "vaultMod")

	local vaultSlider = tab:Slider("vault speed multiplier", 1.0, 3.0, enhState.vaultSpeedMultiplier, function(v)
		enhState.vaultSpeedMultiplier = v
	end, { Step = 0.01, Suffix = "x" })

	local fastVaultToggle = tab:Toggle("always fast vault", false, function(on)
		enhState.alwaysFastVault = on
		applyFastVault()
		if on and not vaultModule then
			Hub:Log("vault module not loaded — may not take effect until next vault", "warn")
		end
	end, "fastVault")

	----------------------------------------------------------------
	-- Veil — spear trajectory (3D)
	----------------------------------------------------------------
	tab:Section("veil")

	local SPEAR = {
		Speed = 165,
		Gravity = Vector3.new(0, -98.1, 0),
		MaxLife = 4,
		SpawnOffset = 3,
	}
	local TRAJ_SEGMENTS = 30

	local trajParts = {}
	local impactSphere = nil
	local trajConn = nil
	local chargeStart = {}

	local function createTrajParts()
		for i = 1, TRAJ_SEGMENTS do
			local part = Instance.new("Part")
			part.Name = "PhotonTraj"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Transparency = 1
			part.Parent = workspace
			trajParts[i] = part
		end
		impactSphere = Instance.new("Part")
		impactSphere.Name = "PhotonTrajImpact"
		impactSphere.Shape = Enum.PartType.Ball
		impactSphere.Anchored = true
		impactSphere.CanCollide = false
		impactSphere.CanQuery = false
		impactSphere.CastShadow = false
		impactSphere.Material = Enum.Material.Neon
		impactSphere.Size = Vector3.new(1.2, 1.2, 1.2)
		impactSphere.Transparency = 1
		impactSphere.Parent = workspace
	end

	local function destroyTrajParts()
		for _, part in ipairs(trajParts) do
			pcall(part.Destroy, part)
		end
		table.clear(trajParts)
		if impactSphere then
			pcall(impactSphere.Destroy, impactSphere)
			impactSphere = nil
		end
	end

	local function hideTrajectory()
		for _, part in ipairs(trajParts) do
			part.Transparency = 1
		end
		if impactSphere then impactSphere.Transparency = 1 end
	end

	local function getTeam(player)
		local ok, team = pcall(function() return player.Team end)
		return ok and team and team.Name or nil
	end

	local function findChargingVeil()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local char = player.Character
				if char and char:GetAttribute("spearmode") == true then
					return player, char
				end
			end
		end
		return nil, nil
	end

	local trajRayParams = RaycastParams.new()
	trajRayParams.FilterType = Enum.RaycastFilterType.Exclude
	local targetRayParams = RaycastParams.new()
	targetRayParams.FilterType = Enum.RaycastFilterType.Include

	local function updateTrajectory()
		if #trajParts == 0 then return end
		local localChar = getCharacter()
		if not localChar then hideTrajectory() return end

		for player, _ in pairs(chargeStart) do
			local c = player.Character
			if not c or c:GetAttribute("spearmode") ~= true then
				chargeStart[player] = nil
			end
		end

		local origin, direction, power
		local isLocalVeil = false

		if localChar:GetAttribute("spearmode") == true then
			isLocalVeil = true
			local cam = workspace.CurrentCamera
			if not cam then hideTrajectory() return end
			origin = cam.CFrame.Position
			direction = cam.CFrame.LookVector
			if not chargeStart[LocalPlayer] then chargeStart[LocalPlayer] = tick() end
			power = math.clamp((tick() - chargeStart[LocalPlayer]) * SPEAR.Speed, 1, SPEAR.Speed)
		else
			local vp, vc = findChargingVeil()
			if not vp then hideTrajectory() return end
			local head = vc:FindFirstChild("Head")
			if not head then hideTrajectory() return end
			origin = head.Position
			direction = head.CFrame.LookVector
			if not chargeStart[vp] then chargeStart[vp] = tick() end
			power = math.clamp((tick() - chargeStart[vp]) * SPEAR.Speed, 1, SPEAR.Speed)
		end

		origin = origin + direction * SPEAR.SpawnOffset

		local excludeList = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then table.insert(excludeList, p.Character) end
		end
		trajRayParams.FilterDescendantsInstances = excludeList

		local points = {}
		local dt = SPEAR.MaxLife / TRAJ_SEGMENTS
		local vel = direction * power
		local hitGround = false

		for i = 0, TRAJ_SEGMENTS do
			local t = i * dt
			local pos = origin + vel * t + SPEAR.Gravity * (0.5 * t * t)
			if i > 0 and not enhState.trajNoclip and not hitGround then
				local prev = points[#points]
				local seg = pos - prev
				local result = workspace:Raycast(prev, seg, trajRayParams)
				if result then
					table.insert(points, result.Position)
					hitGround = true
				else
					table.insert(points, pos)
				end
			else
				table.insert(points, pos)
			end
			if hitGround then break end
		end

		local onTarget = false
		if isLocalVeil then
			local survivorChars = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and getTeam(p) == "Survivors" and p.Character then
					table.insert(survivorChars, p.Character)
				end
			end
			for _, child in ipairs(workspace:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute("RoundBot") == true then
					table.insert(survivorChars, child)
				end
			end
			if #survivorChars > 0 then
				targetRayParams.FilterDescendantsInstances = survivorChars
				for i = 1, #points - 1 do
					local seg = points[i + 1] - points[i]
					local result = workspace:Raycast(points[i], seg, targetRayParams)
					if result then onTarget = true; break end
				end
			end
		end

		local color = COLOR_MAP[onTarget and enhState.trajOnTargetColor or enhState.trajColor] or Color3.new(1, 1, 1)
		local trans = enhState.trajTransparency

		for i = 1, TRAJ_SEGMENTS do
			local part = trajParts[i]
			if i < #points then
				local p1, p2 = points[i], points[i + 1]
				local mid = (p1 + p2) / 2
				local dist = (p2 - p1).Magnitude
				part.Size = Vector3.new(0.15, 0.15, dist)
				part.CFrame = CFrame.lookAt(mid, p2)
				part.Color = color
				part.Transparency = trans
			else
				part.Transparency = 1
			end
		end

		if impactSphere then
			if hitGround and not enhState.trajNoclip and #points > 0 then
				impactSphere.Position = points[#points]
				impactSphere.Color = color
				impactSphere.Transparency = trans
			else
				impactSphere.Transparency = 1
			end
		end
	end

	local function applyTrajectory()
		if trajConn then trajConn:Disconnect(); trajConn = nil end
		if enhState.spearTrajectory then
			if #trajParts == 0 then createTrajParts() end
			trajConn = RunService.RenderStepped:Connect(updateTrajectory)
		else
			hideTrajectory()
			chargeStart = {}
		end
	end

	----------------------------------------------------------------
	-- Veil — track dropdown UI
	----------------------------------------------------------------
	tab.Order = tab.Order + 1
	local trajRow = H.Frame(tab.Page, {
		Name = "Track_spear_trajectory",
		LayoutOrder = tab.Order,
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
	})
	local trajHit = H.Button(trajRow, "", {Name = "Hit", Size = UDim2.fromScale(1, 1)})
	trajHit.MouseEnter:Connect(function() H.tween(trajHit, {BackgroundTransparency = 0.35}) end)
	trajHit.MouseLeave:Connect(function() H.tween(trajHit, {BackgroundTransparency = 1}) end)

	local trajCaret = H.Text(trajHit, "[+]", {Position = H.U(8, 0), Size = H.U(24, ROW_H), TextColor3 = T.dim})
	H.Text(trajHit, "spear trajectory", {Position = H.U(36, 0), Size = UDim2.new(1, -172, 1, 0), TextColor3 = T.text})

	local trajToggleBox = H.Text(trajHit, "[ ]", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = H.U(28, ROW_H),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.dim,
	})
	local trajToggleVal = H.Text(trajHit, "off", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 0),
		Size = H.U(32, ROW_H),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 11,
		TextColor3 = T.dim,
	})

	local function trajRenderToggle()
		trajToggleBox.Text = enhState.spearTrajectory and "[x]" or "[ ]"
		trajToggleBox.TextColor3 = enhState.spearTrajectory and T.white or T.dim
		trajToggleVal.Text = enhState.spearTrajectory and "on" or "off"
		trajToggleVal.TextColor3 = enhState.spearTrajectory and T.white or T.dim
	end
	trajRenderToggle()

	local trajBindId = "spearTraj"
	local trajBindBox = H.Button(trajHit, "", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -74, 0.5, 0),
		Size = H.U(46, 16),
		TextSize = 10,
		FontFace = UI.Fonts.Medium,
		TextColor3 = T.mid,
		BackgroundColor3 = T.raised,
		BackgroundTransparency = 0,
	})
	H.Stroke(trajBindBox, T.line)
	Hub._keybindRenders = Hub._keybindRenders or {}
	local function trajRenderBind()
		if Hub._keybindListening == trajBindId then
			trajBindBox.Text = "..."
			trajBindBox.TextColor3 = T.accent
		else
			local k = Hub._keybinds[trajBindId]
			trajBindBox.Text = k or "none"
			trajBindBox.TextColor3 = k and T.text or T.dim
		end
	end
	Hub._keybindRenders[trajBindId] = trajRenderBind
	trajRenderBind()
	trajBindBox.MouseButton1Click:Connect(function()
		Hub:StartListening(trajBindId)
	end)
	trajBindBox.MouseButton2Click:Connect(function()
		Hub:ClearKeybind(trajBindId)
	end)

	local trajToggleHandle = {
		Set = function(_, v)
			enhState.spearTrajectory = v == true
			trajRenderToggle()
			applyTrajectory()
		end,
		Get = function() return enhState.spearTrajectory end,
	}
	Hub:RegisterKeybind(trajBindId, trajToggleHandle, "spear trajectory")

	-- collapsible content
	tab.Order = tab.Order + 1
	local trajContent = H.Frame(tab.Page, {
		Name = "Track_spear_trajectory_Content",
		LayoutOrder = tab.Order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	})
	H.List(trajContent, 2)
	local trajSubOrder = 0

	local function trajSubRow(h)
		trajSubOrder = trajSubOrder + 1
		return H.Frame(trajContent, {
			Name = "SubRow",
			LayoutOrder = trajSubOrder,
			Size = UDim2.new(1, 0, 0, h or 22),
			BackgroundTransparency = 1,
		})
	end

	local function trajSubChoice(label, options, default, callback)
		local row = trajSubRow(22)
		local idx = table.find(options, default) or 1
		local pad = H.Frame(row, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
		H.Pad(pad, 0, 0, 0, 20)
		H.Text(pad, label, {Position = H.U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
		local val = H.Button(pad, tostring(options[idx]), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = H.U(80, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = UI.Fonts.Medium,
			TextColor3 = T.mid,
			TextSize = 11,
		})
		val.MouseEnter:Connect(function() val.TextColor3 = T.white end)
		val.MouseLeave:Connect(function() val.TextColor3 = T.mid end)
		val.MouseButton1Click:Connect(function()
			idx = (idx % #options) + 1
			val.Text = tostring(options[idx])
			if callback then pcall(callback, options[idx]) end
		end)
		return {
			Get = function() return options[idx] end,
			Set = function(_, v)
				local i = table.find(options, v)
				if i then idx = i; val.Text = tostring(options[idx]) end
			end,
		}
	end

	local function trajSubSlider(label, min, max, default, callback, opts)
		opts = opts or {}
		local step = opts.Step or 0.1
		local row = trajSubRow(22)
		local value = math.clamp(default or min, min, max)
		local pad = H.Frame(row, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
		H.Pad(pad, 0, 0, 0, 20)
		H.Text(pad, label, {Position = H.U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
		local valLabel = H.Text(pad, string.format("%.2f", value), {
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
			valLabel.Text = string.format("%.2f", value)
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
		Hub:_track(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local size = bar.AbsoluteSize.X
				local cw = size / (BAR + 2)
				local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X - cw) / (size - 2 * cw), 0, 1)
				set(min + (max - min) * ratio)
			end
		end))
		Hub:_track(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
		return { Get = function() return value end, Set = function(_, v) set(v) end }
	end

	local function trajSubToggle(label, default, callback)
		local row = trajSubRow(22)
		local sState = default == true
		local pad = H.Frame(row, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
		H.Pad(pad, 0, 0, 0, 20)
		local hit = H.Button(pad, "", {Size = UDim2.fromScale(1, 1)})
		hit.MouseEnter:Connect(function() H.tween(hit, {BackgroundTransparency = 0.35}) end)
		hit.MouseLeave:Connect(function() H.tween(hit, {BackgroundTransparency = 1}) end)
		local box = H.Text(hit, "", {Position = H.U(8, 0), Size = H.U(28, 22), TextColor3 = T.white})
		H.Text(hit, label, {Position = H.U(36, 0), Size = UDim2.new(1, -80, 1, 0), TextSize = 11})
		local val = H.Text(hit, "", {
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
		hit.MouseButton1Click:Connect(function()
			sState = not sState
			render()
			if callback then pcall(callback, sState) end
		end)
		return { Get = function() return sState end, Set = function(_, v) sState = v == true; render() end }
	end

	-- expand/collapse
	local trajExpanded = false
	trajHit.MouseButton1Click:Connect(function()
		local mouseX = UserInputService:GetMouseLocation().X
		local rowRight = trajRow.AbsolutePosition.X + trajRow.AbsoluteSize.X
		local bindStart = rowRight - 120
		local bindEnd = rowRight - 74
		if mouseX >= bindStart and mouseX <= bindEnd then return end
		local toggleStart = rowRight - 80
		if mouseX >= toggleStart then
			enhState.spearTrajectory = not enhState.spearTrajectory
			trajRenderToggle()
			applyTrajectory()
		else
			trajExpanded = not trajExpanded
			trajContent.Visible = trajExpanded
			trajCaret.Text = trajExpanded and "[-]" or "[+]"
		end
	end)

	-- sub-items
	local trajColorChoice = trajSubChoice("arc color", COLOR_NAMES, enhState.trajColor, function(v)
		enhState.trajColor = v
	end)

	local trajOnTargetChoice = trajSubChoice("on target color", COLOR_NAMES, enhState.trajOnTargetColor, function(v)
		enhState.trajOnTargetColor = v
	end)

	local trajTransSlider = trajSubSlider("transparency", 0, 0.95, enhState.trajTransparency, function(v)
		enhState.trajTransparency = v
	end, { Step = 0.05 })

	local trajNoclipToggle = trajSubToggle("noclip", enhState.trajNoclip, function(v)
		enhState.trajNoclip = v
	end)

	----------------------------------------------------------------
	-- Config
	----------------------------------------------------------------
	Hub:RegisterConfig("enhState", enhState, function()
		applySpeed()
		applyVaultSpeed()
		applyFastVault()
		applyTrajectory()
	end)

	Hub:OnConfigLoad(function()
		speedToggle:Set(enhState.speedEnabled)
		speedSlider:Set(enhState.speedMultiplier)
		methodChoice:Set(enhState.speedMethod)
		preset1Toggle:Set(false)
		preset2Toggle:Set(false)
		preset3Toggle:Set(false)
		activePreset = 0
		vaultSpeedToggle:Set(enhState.vaultSpeedEnabled)
		vaultSlider:Set(enhState.vaultSpeedMultiplier)
		fastVaultToggle:Set(enhState.alwaysFastVault)
		trajRenderToggle()
		trajColorChoice:Set(enhState.trajColor)
		trajOnTargetChoice:Set(enhState.trajOnTargetColor)
		trajTransSlider:Set(enhState.trajTransparency)
		trajNoclipToggle:Set(enhState.trajNoclip)
	end)

	----------------------------------------------------------------
	-- Cleanup
	----------------------------------------------------------------
	Hub:RegisterCleanup(function()
		if speedConn then speedConn:Disconnect(); speedConn = nil end
		if vaultSpeedConn then vaultSpeedConn:Disconnect(); vaultSpeedConn = nil end
		if trajConn then trajConn:Disconnect(); trajConn = nil end
		local char = getCharacter()
		if char then
			char:SetAttribute("speedboost", 1)
			char:SetAttribute("vaultspeed", 1)
		end
		if savedVaultEvaluate and vaultModule then
			vaultModule.evaluate = savedVaultEvaluate
			savedVaultEvaluate = nil
		end
		destroyTrajParts()
	end)
end

return { init = init }
