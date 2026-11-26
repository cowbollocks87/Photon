--[[ Photon VD — Automation Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------------
-- Live-lookup helpers (instances may be recreated between matches)
---------------------------------------------------------------------------
local function getRemotes()
	local ok, r = pcall(function()
		return ReplicatedStorage:FindFirstChild("Remotes")
	end)
	return ok and r or nil
end

local function getGenSCEvent()
	local r = getRemotes()
	local g = r and r:FindFirstChild("Generator")
	return g and g:FindFirstChild("SkillCheckEvent")
end

local function getGenSCResult()
	local r = getRemotes()
	local g = r and r:FindFirstChild("Generator")
	return g and g:FindFirstChild("SkillCheckResultEvent")
end

local function getHealSCEvent()
	local r = getRemotes()
	local h = r and r:FindFirstChild("Healing")
	return h and h:FindFirstChild("SkillCheckEvent")
end

local function getHealSCResult()
	local r = getRemotes()
	local h = r and r:FindFirstChild("Healing")
	return h and h:FindFirstChild("SkillCheckResultEvent")
end

local function getParryRemotes()
	local r = getRemotes()
	local items = r and r:FindFirstChild("Items")
	local pd = items and items:FindFirstChild("Parrying Dagger")
	if not pd then return nil, nil end
	return pd:FindFirstChild("parry"), pd:FindFirstChild("parryResult")
end

local function getSlowEvent()
	local r = getRemotes()
	local m = r and r:FindFirstChild("Mechanics")
	return m and m:FindFirstChild("Slow")
end

local function getKSHitRemote()
	local r = getRemotes()
	local kp = r and r:FindFirstChild("KillerPerks")
	local ks = kp and kp:FindFirstChild("kingscourge")
	return ks and ks:FindFirstChild("KingScourgeHit")
end

local function getKSStartEvent()
	local r = getRemotes()
	local kp = r and r:FindFirstChild("KillerPerks")
	local ks = kp and kp:FindFirstChild("kingscourge")
	return ks and ks:FindFirstChild("KingScourgeStart")
end

local function getKSEndEvent()
	local r = getRemotes()
	local kp = r and r:FindFirstChild("KillerPerks")
	local ks = kp and kp:FindFirstChild("kingscourge")
	return ks and ks:FindFirstChild("KingScourgeEnd")
end

---------------------------------------------------------------------------
-- Skill check UI references (live lookup)
---------------------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function getSCGui()
	return PlayerGui:FindFirstChild("SkillCheckPromptGui")
end

local function getCheck()
	local sg = getSCGui()
	return sg and sg:FindFirstChild("Check")
end

local function getLine()
	local c = getCheck()
	return c and c:FindFirstChild("Line")
end

local function getGoal()
	local c = getCheck()
	return c and c:FindFirstChild("Goal")
end

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
	ksEnabled = false,
	ksRate = 100,
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

local function directFire(resultEvent, passArgs, target)
	local char = LocalPlayer.Character
	if not char then return end
	local result = target == "great" and "success" or "neutral"
	local pts = target == "great" and 1 or 0
	local fire = {result, pts}
	for _, v in ipairs(passArgs) do table.insert(fire, v) end
	table.insert(fire, char)
	resultEvent:FireServer(unpack(fire))
	pcall(function()
		local line = getLine()
		if line then TweenService:Create(line, TweenInfo.new(0), {Rotation = line.Rotation}):Play() end
	end)
	task.delay(0.15, function()
		pcall(function()
			local check = getCheck()
			local line = getLine()
			local goal = getGoal()
			if check then check.Visible = false end
			if line then line.Rotation = 0 end
			if goal then goal.Rotation = 0 end
		end)
	end)
end

---------------------------------------------------------------------------
-- Skill check core
---------------------------------------------------------------------------
local function startWatching(resultEvent, passArgs)
	if renderConn then renderConn:Disconnect() end

	local mode = autoSC.mode
	local rate = autoSC.rate

	local roll = math.random(1, 100)
	local target
	if mode == "great" then
		target = roll <= rate and "great" or "good"
	else
		target = roll <= rate and "good" or "skip"
	end

	if target == "skip" then return end

	local fired = false
	local targetRot = nil

	renderConn = RunService.RenderStepped:Connect(function()
		if not autoSC.enabled or fired then
			if renderConn then renderConn:Disconnect(); renderConn = nil end
			return
		end
		local check = getCheck()
		if not check or not check.Visible then return end

		if not targetRot then
			local goal = getGoal()
			local gr = goal and goal.Rotation or 0
			if target == "great" then
				targetRot = gr + 104 + bellRand() * 8
			else
				targetRot = gr + 120 + math.random() * 30
			end
		end

		local line = getLine()
		if not line or line.Rotation < targetRot then return end

		fired = true

		local inputSent = tryKeypress()
			or tryGetConnections(fakeInput)
			or tryFiresignal(fakeInput)

		if inputSent then
			local re, pa, tgt = resultEvent, passArgs, target
			task.delay(0.2, function()
				local c2 = getCheck()
				if c2 and c2.Visible and autoSC.enabled then
					directFire(re, pa, tgt)
				end
			end)
		else
			directFire(resultEvent, passArgs, target)
		end

		renderConn:Disconnect()
		renderConn = nil
	end)
end

local function onGenSkillCheck(p1, p2, p3, p4)
	if not autoSC.enabled then return end
	if p4 ~= LocalPlayer.Character then return end
	local re = getGenSCResult()
	if not re then return end
	startWatching(re, {p1, p2, p3})
end

local function onHealSkillCheck(p1, p2, p3)
	if not autoSC.enabled then return end
	if p3 ~= LocalPlayer.Character then return end
	local re = getHealSCResult()
	if not re then return end
	startWatching(re, {p1, p2})
end

---------------------------------------------------------------------------
-- King's Scourge — separate event chain, not routed through SkillCheckEvent
---------------------------------------------------------------------------
local ksState = nil
local ksRenderConn = nil

local function stopKSWatcher()
	if ksRenderConn then ksRenderConn:Disconnect(); ksRenderConn = nil end
	if ksState and ksState.endConn then pcall(ksState.endConn.Disconnect, ksState.endConn) end
	ksState = nil
end

local function onKSStart(genModel, genPart, count, guid, character, guid2)
	if not autoSC.enabled then return end
	if character ~= LocalPlayer.Character then return end

	stopKSWatcher()

	local ksHit = getKSHitRemote()
	if not ksHit then return end

	local rate = autoSC.ksEnabled and autoSC.ksRate or autoSC.rate

	ksState = { genPart = genPart, guid = guid, ksHit = ksHit, rate = rate }

	local endEv = getKSEndEvent()
	if endEv then
		ksState.endConn = endEv.OnClientEvent:Connect(function()
			stopKSWatcher()
		end)
	end

	local targetRot = nil
	local fired = false
	local prevLineRot = 0

	ksRenderConn = RunService.RenderStepped:Connect(function()
		if not autoSC.enabled or not ksState then
			stopKSWatcher()
			return
		end

		local check = getCheck()
		if not check or not check.Visible then
			targetRot = nil
			fired = false
			prevLineRot = 0
			return
		end

		local line = getLine()
		if not line then return end

		local curRot = line.Rotation

		if fired and curRot < prevLineRot - 20 then
			pcall(keyrelease, scKey.Value)
			targetRot = nil
			fired = false
		end

		prevLineRot = curRot

		if fired then return end

		if not targetRot then
			local goal = getGoal()
			local gr = goal and goal.Rotation or 0
			local roll = math.random(1, 100)
			if roll > ksState.rate then
				fired = true
				return
			end
			targetRot = gr + 104 + bellRand() * 8
		end

		if curRot < targetRot then return end

		fired = true
		prevLineRot = curRot

		pcall(keyrelease, scKey.Value)
		local inputSent = tryKeypress()
			or tryGetConnections(fakeInput)
			or tryFiresignal(fakeInput)

		if not inputSent then
			local char = LocalPlayer.Character
			if char and ksState then
				ksState.ksHit:FireServer(ksState.genPart, "success", ksState.guid, char)
			end
		end
	end)
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
	["rbxassetid://99210996402874"]  = true, -- cure flask throw
	["rbxassetid://79390410596403"]  = true, -- cure flask idle
	["rbxassetid://121108316060822"] = true, -- cure flask charge
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
		pcall(mouse2release)
	end)
end

local function directParry()
	local char = LocalPlayer.Character
	if not char then return end
	local pe = select(1, getParryRemotes())
	if not pe then return end
	pe:FireServer(char)
	pcall(function()
		local se = getSlowEvent()
		if se then se:Fire(0, 1, 0) end
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

local cachedMyRoot = nil
local cachedKillerRoot = nil

local function refreshMyRoot()
	local char = LocalPlayer.Character
	cachedMyRoot = char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function cacheKillerRoot(killerChar)
	cachedKillerRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart") or nil
end

local function inParryRange()
	local myRoot = cachedMyRoot
	local kRoot = cachedKillerRoot
	if not myRoot or not myRoot.Parent then refreshMyRoot(); myRoot = cachedMyRoot end
	if not kRoot or not kRoot.Parent then return false end
	return (myRoot.Position - kRoot.Position).Magnitude <= autoParry.radius
end

local function killerFacingMe()
	if not autoParry.faceCheck then return true end
	local myRoot = cachedMyRoot
	local kRoot = cachedKillerRoot
	if not myRoot or not myRoot.Parent then refreshMyRoot(); myRoot = cachedMyRoot end
	if not myRoot or not kRoot or not kRoot.Parent then return false end
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
		local myRoot = cachedMyRoot
		if not myRoot or not myRoot.Parent then
			refreshMyRoot()
			myRoot = cachedMyRoot
		end
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
	cachedKillerRoot = nil
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
	cacheKillerRoot(char)
	refreshMyRoot()

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

			if inParryRange() and killerFacingMe() then
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
				if not inParryRange() then return end
				if not killerFacingMe() then return end
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
	local scToggle = tab:Toggle("auto skill check", false, function(on)
		autoSC.enabled = on
		Hub:Log(on and "auto skill check on" or "auto skill check off")
		if not on then
			if renderConn then renderConn:Disconnect(); renderConn = nil end
			stopKSWatcher()
		end
	end, "autoSC")

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

	tab:Section("king's scourge")

	local ksToggle = tab:Toggle("custom king's scourge rate", false, function(on)
		autoSC.ksEnabled = on
	end)

	tab:Slider("king's scourge rate", 0, 100, autoSC.ksRate, function(v)
		autoSC.ksRate = v
	end, { Step = 5, Suffix = "%" })

	local scConns = {}
	local lastGenSC, lastHealSC, lastKSStart = nil, nil, nil

	local function hookSCEvents()
		local genEv = getGenSCEvent()
		if genEv and genEv ~= lastGenSC then
			if scConns.gen then pcall(scConns.gen.Disconnect, scConns.gen) end
			lastGenSC = genEv
			scConns.gen = genEv.OnClientEvent:Connect(onGenSkillCheck)
		end
		local healEv = getHealSCEvent()
		if healEv and healEv ~= lastHealSC then
			if scConns.heal then pcall(scConns.heal.Disconnect, scConns.heal) end
			lastHealSC = healEv
			scConns.heal = healEv.OnClientEvent:Connect(onHealSkillCheck)
		end
		local ksEv = getKSStartEvent()
		if ksEv and ksEv ~= lastKSStart then
			if scConns.ks then pcall(scConns.ks.Disconnect, scConns.ks) end
			lastKSStart = ksEv
			scConns.ks = ksEv.OnClientEvent:Connect(onKSStart)
		end
	end

	hookSCEvents()
	Hub:_track(RunService.Heartbeat:Connect(function()
		if not autoSC.enabled then return end
		local genEv = getGenSCEvent()
		local healEv = getHealSCEvent()
		local ksEv = getKSStartEvent()
		if genEv ~= lastGenSC or healEv ~= lastHealSC or ksEv ~= lastKSStart then
			hookSCEvents()
		end
	end))

	----------------------------------------------------------------
	-- Parry section
	----------------------------------------------------------------
	tab:Section("parry")
	local parryToggle = tab:Toggle("auto parry", false, function(on)
		autoParry.enabled = on
		Hub:Log(on and "auto parry on" or "auto parry off")
		if on then
			setupParryWatcher()
			if autoParry.showRadius then startRadiusRender() end
		else
			teardownParryWatcher()
			stopRadiusRender()
		end
	end, "autoParry")

	tab:Slider("radius", 8, 24, autoParry.radius, function(v)
		autoParry.radius = v
	end, { Step = 1, Suffix = " studs" })

	tab:Slider("delay", 0, 300, autoParry.delay, function(v)
		autoParry.delay = v
	end, { Step = 10, Suffix = " ms" })

	local radiusToggle = tab:Toggle("show radius", false, function(on)
		autoParry.showRadius = on
		if on and autoParry.enabled then
			startRadiusRender()
		else
			stopRadiusRender()
		end
	end)

	local faceToggle = tab:Toggle("facing check", true, function(on)
		autoParry.faceCheck = on
	end, "faceCheck")

	tab:Slider("facing cone", 30, 120, autoParry.faceCone, function(v)
		autoParry.faceCone = v
	end, { Step = 10, Suffix = "\194\176" })

	tab:Section("ignore list")

	local hmToggle = tab:Toggle("ignore hidden mark", false, function(on)
		autoParry.ignoreHiddenMark = on
	end)

	local dsToggle = tab:Toggle("ignore dark severance", false, function(on)
		autoParry.ignoreDarkSeverance = on
	end)

	local frenzyToggle = tab:Toggle("ignore frenzy", false, function(on)
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

	refreshMyRoot()
	Hub:_track(LocalPlayer.CharacterAdded:Connect(function(char)
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if root then cachedMyRoot = root end
	end))

	Hub:RegisterConfig("autoSC", autoSC)
	Hub:RegisterConfig("autoParry", autoParry)
	Hub:OnConfigLoad(function()
		scToggle:Set(autoSC.enabled)
		ksToggle:Set(autoSC.ksEnabled)
		parryToggle:Set(autoParry.enabled)
		radiusToggle:Set(autoParry.showRadius)
		faceToggle:Set(autoParry.faceCheck)
		hmToggle:Set(autoParry.ignoreHiddenMark)
		dsToggle:Set(autoParry.ignoreDarkSeverance)
		frenzyToggle:Set(autoParry.ignoreFrenzy)
	end)
	Hub:RegisterCleanup(function()
		teardownParryWatcher()
		stopRadiusRender()
		destroyRadiusPart()
		stopKSWatcher()
		for _, c in pairs(scConns) do pcall(c.Disconnect, c) end
		table.clear(scConns)
	end)
end

return { init = init }
