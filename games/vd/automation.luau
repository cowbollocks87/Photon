--[[ Photon VD — Automation Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------------
-- Remote references — skill check
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
-- Remote references — parry
---------------------------------------------------------------------------
local parryEvent, parryResult
pcall(function()
	local pd = ReplicatedStorage.Remotes.Items["Parrying Dagger"]
	parryEvent = pd.parry
	parryResult = pd.parryResult
end)

local slowEvent
pcall(function()
	slowEvent = ReplicatedStorage.Remotes.Mechanics.Slow
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
-- Keybind + hook (shared — action-aware tagging)
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
		local origFn = KC.matches
		local hooked = false

		pcall(function()
			origFn = hookfunction(KC.matches, function(action, input)
				if type(input) == "table" and rawget(input, "_auto") == action then
					return true
				end
				return origFn(action, input)
			end)
			hooked = true
		end)

		if not hooked then
			KC.matches = function(action, input)
				if type(input) == "table" and rawget(input, "_auto") == action then
					return true
				end
				return origFn(action, input)
			end
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

local autoParry = {
	enabled = false,
}

local renderConn = nil

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------
local function bellRand()
	return (math.random() + math.random() + math.random()) / 3
end

---------------------------------------------------------------------------
-- Skill check input simulation
---------------------------------------------------------------------------
local fakeInput = {
	KeyCode = scKey,
	UserInputType = Enum.UserInputType.Keyboard,
	UserInputState = Enum.UserInputState.Begin,
	_auto = "skillcheck",
}

local function tryKeypress()
	return pcall(function()
		keypress(scKey.Value)
		task.defer(function() pcall(keyrelease, scKey.Value) end)
	end)
end

local function tryGetConnections(fake)
	if not kcHooked then return false end
	return pcall(function()
		for _, conn in ipairs(getconnections(UserInputService.InputBegan)) do
			conn:Fire(fake, false)
		end
	end)
end

local function tryFiresignal(fake)
	if not kcHooked then return false end
	return pcall(function()
		firesignal(UserInputService.InputBegan, fake, false)
	end)
end

local function directFire(resultEvent, gen, genPoint, sessionId, target)
	local char = LocalPlayer.Character
	if not char then return end
	local result = target == "great" and "success" or "neutral"
	local pts = target == "great" and 1 or 0
	resultEvent:FireServer(result, pts, gen, genPoint, sessionId, char)
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
-- Skill check core
---------------------------------------------------------------------------
local function startWatching(resultEvent, gen, genPoint, sessionId)
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

		local inputSent = tryKeypress()
			or tryGetConnections(fakeInput)
			or tryFiresignal(fakeInput)

		if inputSent then
			local re, g, gp, sid, tgt = resultEvent, gen, genPoint, sessionId, target
			task.delay(0.2, function()
				if Check.Visible and autoSC.enabled then
					directFire(re, g, gp, sid, tgt)
				end
			end)
		else
			directFire(resultEvent, gen, genPoint, sessionId, target)
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
-- Auto parry — killer detection + animation watching
---------------------------------------------------------------------------
local M1_ANIMS = {
	["rbxassetid://84926129581106"] = true,
}

local M1_RANGE = 16

local fakeParryInput = {
	KeyCode = Enum.KeyCode.Unknown,
	UserInputType = Enum.UserInputType.MouseButton2,
	UserInputState = Enum.UserInputState.Begin,
	_auto = "item",
}

local function tryParryKeypress()
	return pcall(function()
		mouse2press()
		task.defer(function() pcall(mouse2release) end)
	end)
end

local function directParry()
	local char = LocalPlayer.Character
	if not char or not parryEvent then return end
	parryEvent:FireServer(char)
	pcall(function()
		if slowEvent then slowEvent:Fire(0, 1, 0) end
	end)
end

local function fireParry()
	local sent = tryParryKeypress()
		or tryGetConnections(fakeParryInput)
		or tryFiresignal(fakeParryInput)
	if not sent then
		directParry()
	end
end

local function inM1Range(killerChar)
	local myRoot = LocalPlayer.Character
		and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local kRoot = killerChar
		and killerChar:FindFirstChild("HumanoidRootPart")
	if not myRoot or not kRoot then return false end
	return (myRoot.Position - kRoot.Position).Magnitude <= M1_RANGE
end

local parryConns = {}
local watchingKiller = nil

local function teardownParryWatcher()
	for _, c in ipairs(parryConns) do
		pcall(c.Disconnect, c)
	end
	table.clear(parryConns)
	watchingKiller = nil
end

local function findKiller()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Team and p.Team.Name == "Killer" then
			return p
		end
	end
	return nil
end

local function setupParryWatcher()
	teardownParryWatcher()
	if not autoParry.enabled then return end

	local killer = findKiller()
	if not killer then return end
	watchingKiller = killer

	table.insert(parryConns, killer.CharacterAdded:Connect(function()
		task.wait(0.5)
		if autoParry.enabled then setupParryWatcher() end
	end))

	local char = killer.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	table.insert(parryConns, animator.AnimationPlayed:Connect(function(track)
		if not autoParry.enabled then return end

		local id = track.Animation and track.Animation.AnimationId or ""
		local isKnown = M1_ANIMS[id]
		local isHeuristic = not isKnown
			and track.Priority == Enum.AnimationPriority.Action
			and track.Length >= 1 and track.Length <= 1.8
			and track.Speed >= 0.9 and track.Speed <= 1.1

		if not (isKnown or isHeuristic) then return end
		if not inM1Range(char) then return end

		fireParry()
	end))
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function init(Hub, UI)
	local tab = Hub:Tab("automation")

	----------------------------------------------------------------
	-- Skill check section
	----------------------------------------------------------------
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

	----------------------------------------------------------------
	-- Parry section
	----------------------------------------------------------------
	tab:Section("parry")
	tab:Toggle("auto parry", false, function(on)
		autoParry.enabled = on
		Hub:Log(on and "auto parry on" or "auto parry off")
		if on then
			setupParryWatcher()
		else
			teardownParryWatcher()
		end
	end)

	local lastParryCheck = 0
	Hub:_track(RunService.Heartbeat:Connect(function()
		if not autoParry.enabled then return end
		local now = os.clock()
		if now - lastParryCheck < 2 then return end
		lastParryCheck = now
		local killer = findKiller()
		if killer ~= watchingKiller then
			setupParryWatcher()
		end
	end))
end

return { init = init }
