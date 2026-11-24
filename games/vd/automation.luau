--[[ Photon VD — Automation Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
-- State
---------------------------------------------------------------------------
local autoSC = {
	enabled = false,
	mode = "great",
	rate = 100,
}

local renderConn = nil

---------------------------------------------------------------------------
-- Core — zone detection & auto-fire
---------------------------------------------------------------------------
-- Zone geometry (from decompiled Skillcheck-gen):
--   Great  goalRot+102 .. goalRot+116   (14°)
--   Good   goalRot+116 .. goalRot+159   (43°)
--
-- Strategy: fire the result remote, then cancel the original tween with
-- a zero-duration override.  The original script's tween-completion
-- handler sees PlaybackState.Cancelled and returns early, so it never
-- fires fail or sets isRepairing=false.  The repair continues and the
-- player can leave the generator normally.

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
		local char = LocalPlayer.Character
		if not char then return end

		local result = target == "great" and "success" or "neutral"
		local pts = target == "great" and 1 or 0
		resultEvent:FireServer(result, pts, genId, generator, sessionId, char)

		-- Cancel the original tween so its completion handler never runs
		pcall(function()
			TweenService:Create(Line, TweenInfo.new(0), {Rotation = lr}):Play()
		end)

		-- Keep check UI visible briefly to show the hit, then clean up
		task.delay(0.15, function()
			pcall(function()
				Check.Visible = false
				Line.Rotation = 0
				Goal.Rotation = 0
			end)
		end)

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
