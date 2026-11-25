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
	radius = 14,
	delay = 80,
	showRadius = false,
	faceCheck = true,
	faceCone = 70,
	ignoreHiddenMark = false,
	ignoreDarkSeverance = false,
	ignoreFrenzy = false,
}

local frenzyActive = false

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
	["rbxassetid://84926129581106"]  = true, -- veil m1
	["rbxassetid://138720291317243"] = true, -- jacket tony attack
	["rbxassetid://115244153053858"] = true, -- jacket cobra lunge windup
	["rbxassetid://130593238885843"] = true, -- jacket cobra post-lunge
	["rbxassetid://117070354890871"] = true, -- jacket swan chainsaw rev
	["rbxassetid://106871536134254"] = true, -- jacket swan post-rev sprint
}

local ANIM_BLACKLIST = {
	["rbxassetid://134450878841800"] = true, -- butcher chain throw
	["rbxassetid://129669521834246"] = true, -- veil equip spear
	["rbxassetid://84404617799721"]  = true, -- veil spear idle
	["rbxassetid://77303734522729"]  = true, -- veil spear charge start
	["rbxassetid://87436543050891"]  = true, -- veil spear charge loop
	["rbxassetid://79809716042968"]  = true, -- veil through the veil start
	["rbxassetid://122765810542358"] = true, -- veil through the veil loop
	["rbxassetid://101443662521580"] = true, -- veil spear throw
	["rbxassetid://127622545856523"] = true, -- veil spear throw
	["rbxassetid://71001061734896"]  = true, -- veil put away spear
	["rbxassetid://75613723058031"]  = true, -- abysswalker corrupt
	["rbxassetid://77477445889320"]  = true, -- stalker evil within grab
	["rbxassetid://76744850905644"]  = true, -- stalker evil within slam
}

local OPTIONAL_IGNORE = {
	hidden_mark = {
		["rbxassetid://98163597193511"]  = true,
	},
	dark_severance = {
		["rbxassetid://100014992013740"] = true,
	},
}

local FRENZY_START  = "rbxassetid://106776288044176"
local FRENZY_CANCEL = "rbxassetid://140115024869914"
local M1_ANIM_NAMES = { lungehold = true, attack = true }

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

local function getMyRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getKillerRoot(killerChar)
	return killerChar and killerChar:FindFirstChild("HumanoidRootPart")
end

local function inParryRange(killerChar)
	local myRoot = getMyRoot()
	local kRoot = getKillerRoot(killerChar)
	if not myRoot or not kRoot then return false end
	return (myRoot.Position - kRoot.Position).Magnitude <= autoParry.radius
end

local function killerFacingMe(killerChar)
	if not autoParry.faceCheck then return true end
	local myRoot = getMyRoot()
	local kRoot = getKillerRoot(killerChar)
	if not myRoot or not kRoot then return false end
	local toMe = (myRoot.Position - kRoot.Position) * Vector3.new(1, 0, 1)
	if toMe.Magnitude < 0.5 then return true end
	local threshold = math.cos(math.rad(autoParry.faceCone))
	local toMeDir = toMe.Unit

	local look = kRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 and toMeDir:Dot(look.Unit) > threshold then
		return true
	end

	local vel = kRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if vel.Magnitude > 2 and toMeDir:Dot(vel.Unit) > threshold then
		return true
	end

	return false
end

---------------------------------------------------------------------------
-- Radius visualization — world-space cylinder Part
---------------------------------------------------------------------------
local radiusPart = nil
local radiusRenderConn = nil

local function createRadiusPart()
	if radiusPart then return end
	radiusPart = Instance.new("Part")
	radiusPart.Name = "PhotonRadius"
	radiusPart.Shape = Enum.PartType.Cylinder
	radiusPart.Anchored = true
	radiusPart.CanCollide = false
	radiusPart.CanQuery = false
	radiusPart.CastShadow = false
	radiusPart.Material = Enum.Material.Neon
	radiusPart.Color = Color3.fromRGB(255, 150, 30)
	radiusPart.Transparency = 0.65
	radiusPart.Parent = workspace
end

local function destroyRadiusPart()
	if radiusPart then
		radiusPart:Destroy()
		radiusPart = nil
	end
end

local function startRadiusRender()
	if radiusRenderConn then return end
	createRadiusPart()
	radiusRenderConn = RunService.RenderStepped:Connect(function()
		if not autoParry.showRadius or not autoParry.enabled then
			if radiusPart then radiusPart.Transparency = 1 end
			return
		end
		local myRoot = getMyRoot()
		if not myRoot then
			if radiusPart then radiusPart.Transparency = 1 end
			return
		end
		local d = autoParry.radius * 2
		radiusPart.Size = Vector3.new(0.05, d, d)
		radiusPart.CFrame = CFrame.new(myRoot.Position) * CFrame.Angles(0, 0, math.rad(90))
		radiusPart.Transparency = 0.65
	end)
end

local function stopRadiusRender()
	if radiusRenderConn then
		radiusRenderConn:Disconnect()
		radiusRenderConn = nil
	end
	destroyRadiusPart()
end

---------------------------------------------------------------------------
-- Parry watcher
---------------------------------------------------------------------------
local parryConns = {}
local watchingKiller = nil
local watchedAnimator = nil
local PARRY_WATCH_WINDOW = 0.65
local parryWatchConn = nil

local function teardownParryWatcher()
	for _, c in ipairs(parryConns) do
		pcall(c.Disconnect, c)
	end
	table.clear(parryConns)
	if parryWatchConn then
		parryWatchConn:Disconnect()
		parryWatchConn = nil
	end
	watchingKiller = nil
	watchedAnimator = nil
	frenzyActive = false
end

local function findKiller()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Team and p.Team.Name == "Killer" then
			return p
		end
	end
	return nil
end

local function connectAnimator(animator, char)
	watchedAnimator = animator

	table.insert(parryConns, animator.AnimationPlayed:Connect(function(track)
		if not autoParry.enabled then return end

		local id = track.Animation and track.Animation.AnimationId or ""
		local animName = track.Animation and track.Animation.Name or ""

		if id == FRENZY_START then frenzyActive = true; return end
		if id == FRENZY_CANCEL then frenzyActive = false; return end

		if ANIM_BLACKLIST[id] then return end
		if autoParry.ignoreHiddenMark and OPTIONAL_IGNORE.hidden_mark[id] then return end
		if autoParry.ignoreDarkSeverance and OPTIONAL_IGNORE.dark_severance[id] then return end
		if autoParry.ignoreFrenzy and frenzyActive then return end

		local isKnown = M1_ANIMS[id] or M1_ANIM_NAMES[animName]

		if not isKnown then
			local len = track.Length
			local isHeuristic = track.Priority.Value >= Enum.AnimationPriority.Action.Value
				and track.Speed >= 0.5 and track.Speed <= 2.0
				and (len == 0 or (len >= 0.3 and len <= 2.5))
			if not isHeuristic then return end
		end

		local function startWatch()
			if not autoParry.enabled then return end

			if inParryRange(char) and killerFacingMe(char) then
				fireParry()
				return
			end

			if parryWatchConn then parryWatchConn:Disconnect() end
			local watchStart = os.clock()
			parryWatchConn = RunService.RenderStepped:Connect(function()
				if not autoParry.enabled or os.clock() - watchStart > PARRY_WATCH_WINDOW then
					parryWatchConn:Disconnect()
					parryWatchConn = nil
					return
				end
				if not inParryRange(char) then return end
				if not killerFacingMe(char) then return end
				parryWatchConn:Disconnect()
				parryWatchConn = nil
				fireParry()
			end)
		end

		local delayMs = autoParry.delay
		if delayMs > 0 then
			task.delay(delayMs / 1000, startWatch)
		else
			startWatch()
		end
	end))
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
	if animator then
		connectAnimator(animator, char)
	else
		table.insert(parryConns, hum.ChildAdded:Connect(function(child)
			if child:IsA("Animator") and not watchedAnimator then
				connectAnimator(child, char)
			end
		end))
	end
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
			if autoParry.showRadius then startRadiusRender() end
		else
			teardownParryWatcher()
			stopRadiusRender()
		end
	end)

	tab:Slider("radius", 8, 24, autoParry.radius, function(v)
		autoParry.radius = v
	end, { Step = 1, Suffix = " studs" })

	tab:Slider("delay", 0, 300, autoParry.delay, function(v)
		autoParry.delay = v
	end, { Step = 10, Suffix = " ms" })

	tab:Toggle("show radius", false, function(on)
		autoParry.showRadius = on
		if on and autoParry.enabled then
			startRadiusRender()
		else
			stopRadiusRender()
		end
	end)

	tab:Toggle("facing check", true, function(on)
		autoParry.faceCheck = on
	end)

	tab:Slider("facing cone", 30, 120, autoParry.faceCone, function(v)
		autoParry.faceCone = v
	end, { Step = 10, Suffix = "\194\176" })

	tab:Section("ignore list")

	tab:Toggle("ignore hidden mark", false, function(on)
		autoParry.ignoreHiddenMark = on
	end)

	tab:Toggle("ignore dark severance", false, function(on)
		autoParry.ignoreDarkSeverance = on
	end)

	tab:Toggle("ignore frenzy", false, function(on)
		autoParry.ignoreFrenzy = on
	end)

	local lastParryCheck = 0
	Hub:_track(RunService.Heartbeat:Connect(function()
		if not autoParry.enabled then return end
		local now = os.clock()
		if now - lastParryCheck < 1 then return end
		lastParryCheck = now

		local killer = findKiller()
		if killer ~= watchingKiller then
			setupParryWatcher()
			return
		end

		if not killer then return end
		local char = killer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local anim = hum and hum:FindFirstChildOfClass("Animator")
		if anim ~= watchedAnimator then
			setupParryWatcher()
		end
	end))

	Hub:RegisterConfig("autoSC", autoSC)
	Hub:RegisterConfig("autoParry", autoParry)
	Hub:RegisterCleanup(function()
		teardownParryWatcher()
		stopRadiusRender()
		destroyRadiusPart()
	end)
end

return { init = init }
