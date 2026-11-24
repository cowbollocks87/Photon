--[[ Photon VD — Automation Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------------
-- Remote references
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
-- Keybind + hook
---------------------------------------------------------------------------
local scKey = Enum.KeyCode.Space
local kcHooked = false

pcall(function()
	local KC = require(ReplicatedStorage.Modules.Survivors.KeybindsConfig)
	local k = KC.binds and KC.binds.skillcheck
		or KC.defaults and KC.defaults.skillcheck
		or KC.keys and KC.keys.skillcheck
	if typeof(k) == "EnumItem" then scKey = k end

	if KC.matches then
		local orig = KC.matches
		KC.matches = function(action, input)
			if action == "skillcheck" and type(input) == "table" and rawget(input, "_auto") then
				return true
			end
			return orig(action, input)
		end
		kcHooked = true
	end
end)

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
-- Input simulation — three methods, tried in order
---------------------------------------------------------------------------

-- Pseudo-gaussian: sum of 3 uniforms / 3 → clusters near center
local function bellRand()
	return (math.random() + math.random() + math.random()) / 3
end

local function tryKeypress()
	local ok = pcall(function()
		keypress(scKey.Value)
		task.defer(function() pcall(keyrelease, scKey.Value) end)
	end)
	return ok
end

local function tryFiresignal()
	if not kcHooked then return false end
	local ok = pcall(function()
		firesignal(UserInputService.InputBegan, {
			KeyCode = scKey,
			UserInputType = Enum.UserInputType.Keyboard,
			UserInputState = Enum.UserInputState.Begin,
			_auto = true,
		}, false)
	end)
	return ok
end

local function directFire(resultEvent, genId, generator, sessionId, target)
	local char = LocalPlayer.Character
	if not char then return end
	local result = target == "great" and "success" or "neutral"
	local pts = target == "great" and 1 or 0
	resultEvent:FireServer(result, pts, genId, generator, sessionId, char)
	pcall(function()
		TweenService:Create(Line, TweenInfo.new(0), {Rotation = Line.Rotation}):Play()
	end)
	task.delay(0.15, function()
		pcall(function()
			Check.Visible = false
			Line.Rotation = 0
			Goal.Rotation = 0
		end)
	end)
end

---------------------------------------------------------------------------
-- Core — zone detection & auto-fire
---------------------------------------------------------------------------
-- Zone geometry (from decompiled Skillcheck-gen):
--   Great  goalRot+102 .. goalRot+116   (14°)
--   Good   goalRot+116 .. goalRot+159   (43°)
--
-- Strategy: pick a random landing point within the target zone so the
-- needle stops at a different rotation every check.  Try keypress first
-- (real OS input → original handler runs → sounds + visuals), then
-- firesignal with a KeybindsConfig.matches hook, then direct remote
-- fire + tween cancel as the guaranteed fallback.

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
	local targetRot = nil

	renderConn = RunService.RenderStepped:Connect(function()
		if not autoSC.enabled or fired then
			if renderConn then renderConn:Disconnect(); renderConn = nil end
			return
		end
		if not Check.Visible then return end

		-- First visible frame: pick random landing point in the zone
		if not targetRot then
			local gr = Goal.Rotation
			if target == "great" then
				targetRot = gr + 104 + bellRand() * 8
			else
				targetRot = gr + 120 + math.random() * 30
			end
		end

		if Line.Rotation < targetRot then return end

		fired = true

		-- Try native keypress → firesignal with hook → direct fire
		local inputSent = tryKeypress() or tryFiresignal()

		if inputSent then
			-- Safety net: if the original handler didn't process within 0.2s
			-- (Check still visible), fire the direct fallback before the
			-- tween completes and the game fires fail
			local re, gid, gen, sid, tgt = resultEvent, genId, generator, sessionId, target
			task.delay(0.2, function()
				if Check.Visible and autoSC.enabled then
					directFire(re, gid, gen, sid, tgt)
				end
			end)
		else
			directFire(resultEvent, genId, generator, sessionId, target)
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
