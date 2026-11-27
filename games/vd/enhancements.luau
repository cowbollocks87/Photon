--[[ Photon VD — Enhancements Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local SPEED_METHODS = { "cframe", "attribute" }

local function init(Hub, UI)
	local tab = Hub:Tab("enhancements")

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
	-- Veil — spear trajectory
	----------------------------------------------------------------
	tab:Section("veil")

	local SPEAR = {
		Speed = 165,
		Gravity = Vector3.new(0, -98.1, 0),
		MaxLife = 4,
		SpawnOffset = 3,
	}
	local TRAJ_SEGMENTS = 40
	local TRAJ_ENEMY_COLOR = Color3.fromRGB(255, 60, 60)
	local TRAJ_SELF_COLOR = Color3.fromRGB(100, 200, 255)

	local trajLines = {}
	local trajImpact = Drawing.new("Circle")
	trajImpact.Visible = false
	trajImpact.Radius = 4
	trajImpact.Thickness = 2
	trajImpact.Filled = false

	for i = 1, TRAJ_SEGMENTS do
		local line = Drawing.new("Line")
		line.Visible = false
		line.Thickness = 2
		line.Transparency = 0.3
		trajLines[i] = line
	end

	local trajConn = nil
	local chargeStart = {}

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

	local function hideTrajectory()
		for _, line in ipairs(trajLines) do
			line.Visible = false
		end
		trajImpact.Visible = false
	end

	local trajRayParams = RaycastParams.new()
	trajRayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function updateTrajectory()
		local cam = workspace.CurrentCamera
		if not cam then hideTrajectory() return end

		local localChar = getCharacter()
		if not localChar then hideTrajectory() return end

		for player, _ in pairs(chargeStart) do
			local char = player.Character
			if not char or char:GetAttribute("spearmode") ~= true then
				chargeStart[player] = nil
			end
		end

		local origin, direction, power, color

		if localChar:GetAttribute("spearmode") == true then
			origin = cam.CFrame.Position
			direction = cam.CFrame.LookVector
			color = TRAJ_SELF_COLOR
			if not chargeStart[LocalPlayer] then
				chargeStart[LocalPlayer] = tick()
			end
			local elapsed = tick() - chargeStart[LocalPlayer]
			power = math.clamp(elapsed * SPEAR.Speed, 1, SPEAR.Speed)
		else
			local veilPlayer, veilChar = findChargingVeil()
			if not veilPlayer then hideTrajectory() return end

			local head = veilChar:FindFirstChild("Head")
			if not head then hideTrajectory() return end

			origin = head.Position
			direction = head.CFrame.LookVector
			color = TRAJ_ENEMY_COLOR
			if not chargeStart[veilPlayer] then
				chargeStart[veilPlayer] = tick()
			end
			local elapsed = tick() - chargeStart[veilPlayer]
			power = math.clamp(elapsed * SPEAR.Speed, 1, SPEAR.Speed)
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

			if i > 0 and not hitGround then
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

		for i = 1, TRAJ_SEGMENTS do
			local line = trajLines[i]
			if i < #points then
				local p1 = points[i]
				local p2 = points[i + 1]
				local sp1, on1 = cam:WorldToViewportPoint(p1)
				local sp2, on2 = cam:WorldToViewportPoint(p2)

				if (on1 or on2) and sp1.Z > 0 and sp2.Z > 0 then
					line.From = Vector2.new(sp1.X, sp1.Y)
					line.To = Vector2.new(sp2.X, sp2.Y)
					line.Color = color
					line.Visible = true
				else
					line.Visible = false
				end
			else
				line.Visible = false
			end
		end

		if hitGround and #points > 0 then
			local sp, on = cam:WorldToViewportPoint(points[#points])
			if on and sp.Z > 0 then
				trajImpact.Position = Vector2.new(sp.X, sp.Y)
				trajImpact.Color = color
				trajImpact.Visible = true
			else
				trajImpact.Visible = false
			end
		else
			trajImpact.Visible = false
		end
	end

	local function applyTrajectory()
		if trajConn then trajConn:Disconnect(); trajConn = nil end
		if enhState.spearTrajectory then
			trajConn = RunService.RenderStepped:Connect(updateTrajectory)
		else
			hideTrajectory()
			chargeStart = {}
		end
	end

	local trajToggle = tab:Toggle("spear trajectory", false, function(on)
		enhState.spearTrajectory = on
		applyTrajectory()
	end, "spearTraj")

	tab:Label("shows predicted spear arc when the veil is charging. cyan = yours, red = enemy.")

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
		trajToggle:Set(enhState.spearTrajectory)
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
		for _, line in ipairs(trajLines) do
			pcall(line.Remove, line)
		end
		pcall(trajImpact.Remove, trajImpact)
	end)
end

return { init = init }
