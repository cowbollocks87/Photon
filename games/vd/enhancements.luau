--[[ Photon VD — Enhancements Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local function init(Hub, UI)
	local tab = Hub:Tab("enhancements")

	----------------------------------------------------------------
	-- State
	----------------------------------------------------------------
	local enhState = {
		speedEnabled = false,
		speedMultiplier = 1.0,
		vaultSpeedEnabled = false,
		vaultSpeedMultiplier = 1.0,
		alwaysFastVault = false,
	}

	local speedConn = nil
	local vaultSpeedConn = nil
	local savedVaultEvaluate = nil
	local vaultModule = nil

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
	-- Apply functions
	----------------------------------------------------------------
	local function applySpeed()
		if speedConn then speedConn:Disconnect(); speedConn = nil end
		if enhState.speedEnabled then
			speedConn = RunService.Heartbeat:Connect(function()
				local c = getCharacter()
				if c then c:SetAttribute("speedboost", enhState.speedMultiplier) end
			end)
		else
			local c = getCharacter()
			if c then c:SetAttribute("speedboost", 1) end
		end
	end

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
	-- Speed
	----------------------------------------------------------------
	tab:Section("speed")

	local speedToggle = tab:Toggle("speed modifier", false, function(on)
		enhState.speedEnabled = on
		applySpeed()
	end)

	local speedSlider = tab:Slider("speed multiplier", 1.0, 3.0, enhState.speedMultiplier, function(v)
		enhState.speedMultiplier = v
	end, { Step = 0.1, Suffix = "x" })

	----------------------------------------------------------------
	-- Vault
	----------------------------------------------------------------
	tab:Section("vault")

	local vaultSpeedToggle = tab:Toggle("vault speed modifier", false, function(on)
		enhState.vaultSpeedEnabled = on
		applyVaultSpeed()
	end)

	local vaultSlider = tab:Slider("vault speed multiplier", 1.0, 3.0, enhState.vaultSpeedMultiplier, function(v)
		enhState.vaultSpeedMultiplier = v
	end, { Step = 0.1, Suffix = "x" })

	local fastVaultToggle = tab:Toggle("always fast vault", false, function(on)
		enhState.alwaysFastVault = on
		applyFastVault()
		if on and not vaultModule then
			Hub:Log("vault module not loaded — may not take effect until next vault", "warn")
		end
	end)

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
