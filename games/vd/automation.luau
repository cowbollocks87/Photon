--[[ Photon VD — Automation Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------------
-- Skill check keybind (resolved from game config, fallback Space)
---------------------------------------------------------------------------
local scKey = Enum.KeyCode.Space
pcall(function()
	local KC = require(ReplicatedStorage.Modules.Survivors.KeybindsConfig)
	local k = KC.binds and KC.binds.skillcheck
		or KC.defaults and KC.defaults.skillcheck
		or KC.keys and KC.keys.skillcheck
	if typeof(k) == "EnumItem" then scKey = k end
end)

---------------------------------------------------------------------------
-- Remote references (needed for event hooks + fallback fire)
---------------------------------------------------------------------------
local genRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Generator")
local genSCEvent = genRemotes:WaitForChild("SkillCheckEvent")
local genSCResult = genRemotes:WaitForChild("SkillCheckResultEvent")

local healSCEvent, healSCResult
pcall(function()
	local h = ReplicatedStorage.Remotes.Healing
	healSCEvent = h:FindFirstChild("SkillCheckEvent")
	healSCResult = h:FindFirstChild("SkillCheckResultEvent")
end)

---------------------------------------------------------------------------
-- Skill check UI references
---------------------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local SCGui = PlayerGui:WaitForChild("SkillCheckPromptGui")
local Check = SCGui:WaitForChild("Check")
local Line = Check:WaitForChild("Line")
local Goal = Check:WaitForChild("Goal")

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local autoSC = {
	enabled = false,
	mode = "great",
	rate = 100,
}

local renderConn = nil

---------------------------------------------------------------------------
-- Input simulation — firesignal lets the original Skillcheck-gen
-- script handle zone checking, result firing, cleanup and UI.
-- Fallback fires the remote directly when firesignal is unavailable.
---------------------------------------------------------------------------
local function pressSkillCheck()
	local ok = pcall(function()
		firesignal(UserInputService.InputBegan, {
			KeyCode = scKey,
			UserInputType = Enum.UserInputType.Keyboard,
			UserInputState = Enum.UserInputState.Begin,
		}, false)
	end)
	return ok
end

---------------------------------------------------------------------------
-- Core — zone detection & auto-fire
---------------------------------------------------------------------------
-- Zone geometry (from decompiled Skillcheck-gen):
--   Great  goalRot+102 .. goalRot+116   (14°)
--   Good   goalRot+116 .. goalRot+159   (43°)

local function startWatching(resultEvent, genId, generator, sessionId)
	if renderConn then renderConn:Disconnect() end

	local roll = math.random(1, 100)
	local target
	if autoSC.mode == "great" then
		target = roll <= autoSC.rate and "great" or "good"
	else
		target = roll <= autoSC.rate and "good" or "skip"
	end

	if target == "skip" then return end

	local fired = false

	renderConn = RunService.RenderStepped:Connect(function()
		if not autoSC.enabled or fired then
			if renderConn then renderConn:Disconnect(); renderConn = nil end
			return
		end
		if not Check.Visible then return end

		local lr = Line.Rotation
		local gr = Goal.Rotation
		local inZone
		if target == "great" then
			inZone = lr >= gr + 102 and lr <= gr + 116
		else
			inZone = lr > gr + 116 and lr <= gr + 159
		end

		if not inZone then return end

		fired = true

		local pressed = pressSkillCheck()
		if not pressed then
			local char = LocalPlayer.Character
			if char then
				local result = target == "great" and "success" or "neutral"
				local pts = target == "great" and 1 or 0
				resultEvent:FireServer(result, pts, genId, generator, sessionId, char)
				task.delay(0.15, function()
					pcall(function() Check.Visible = false end)
				end)
			end
		end

		renderConn:Disconnect()
		renderConn = nil
	end)
end

local function onSkillCheck(resultEvent, p1, p2, p3, p4)
	if not autoSC.enabled then return end
	if p4 ~= LocalPlayer.Character then return end
	startWatching(resultEvent, p1, p2, p3)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function init(Hub, UI)
	local tab = Hub:Tab("automation")

	tab:Section("skill check")
	tab:Toggle("auto skill check", false, function(on)
		autoSC.enabled = on
		Hub:Log(on and "auto skill check on" or "auto skill check off")
		if not on and renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
	end)

	local modes = {"great", "good"}
	local modeIdx = 1
	local modeUI = {}
	modeUI.kv = tab:KeyValue("mode", modes[modeIdx], function()
		modeIdx = (modeIdx % #modes) + 1
		autoSC.mode = modes[modeIdx]
		modeUI.kv:Set(modes[modeIdx])
	end)

	tab:Slider("rate", 0, 100, autoSC.rate, function(v)
		autoSC.rate = v
	end, { Step = 5, Suffix = "%" })

	Hub:_track(genSCEvent.OnClientEvent:Connect(function(p1, p2, p3, p4, p5)
		onSkillCheck(genSCResult, p1, p2, p3, p4)
	end))

	if healSCEvent and healSCResult then
		Hub:_track(healSCEvent.OnClientEvent:Connect(function(p1, p2, p3, p4, p5)
			onSkillCheck(healSCResult, p1, p2, p3, p4)
		end))
	end
end

return { init = init }
