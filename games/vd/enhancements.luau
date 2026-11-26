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
	-- Config
	----------------------------------------------------------------
	Hub:RegisterConfig("enhState", enhState, function()
		applySpeed()
		applyVaultSpeed()
		applyFastVault()
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
	end)

	----------------------------------------------------------------
	-- Cleanup
	----------------------------------------------------------------
	Hub:RegisterCleanup(function()
		if speedConn then speedConn:Disconnect(); speedConn = nil end
		if vaultSpeedConn then vaultSpeedConn:Disconnect(); vaultSpeedConn = nil end
		local char = getCharacter()
		if char then
			char:SetAttribute("speedboost", 1)
			char:SetAttribute("vaultspeed", 1)
		end
		if savedVaultEvaluate and vaultModule then
			vaultModule.evaluate = savedVaultEvaluate
			savedVaultEvaluate = nil
		end
	end)
end

return { init = init }
