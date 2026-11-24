--[[ Photon VD — Automation Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
}

local renderConn = nil
local pendingCheck = nil

---------------------------------------------------------------------------
-- Core — zone detection & auto-fire
---------------------------------------------------------------------------
-- Zone geometry (from decompiled Skillcheck-gen):
--   Great  goalRot+102 .. goalRot+116   (14°)
--   Good   goalRot+116 .. goalRot+159   (43°)
-- Line tweens 0→360 linearly; RenderStepped fires the result the
-- first frame the needle enters the target zone.

local function startWatching(resultEvent, genId, generator, sessionId)
	if renderConn then renderConn:Disconnect() end

	pendingCheck = {
		event = resultEvent,
		genId = genId,
		gen = generator,
		session = sessionId,
	}

	renderConn = RunService.RenderStepped:Connect(function()
		if not autoSC.enabled or not pendingCheck then
			if renderConn then renderConn:Disconnect(); renderConn = nil end
			return
		end
		if not Check.Visible then return end

		local lr = Line.Rotation
		local gr = Goal.Rotation
		local inZone
		if autoSC.mode == "great" then
			inZone = lr >= gr + 102 and lr <= gr + 116
		else
			inZone = lr >= gr + 102 and lr <= gr + 159
		end

		if not inZone then return end

		local char = LocalPlayer.Character
		if not char then return end

		local p = pendingCheck
		p.event:FireServer("success", 1, p.genId, p.gen, p.session, char)
		Check.Visible = false

		-- The original script's tween will finish and fire "fail" +
		-- set isRepairing=false. The server deduplicates by session
		-- so the fail is a no-op, but isRepairing going false would
		-- stop the repair on the client. Restore it once.
		local ci = char:FindFirstChild("CheckInterractable")
		if ci then
			local guard
			guard = ci:GetAttributeChangedSignal("isRepairing"):Connect(function()
				if not ci:GetAttribute("isRepairing") then
					task.defer(function()
						pcall(function() ci:SetAttribute("isRepairing", true) end)
					end)
					if guard then guard:Disconnect(); guard = nil end
				end
			end)
			task.delay(5, function()
				if guard then guard:Disconnect(); guard = nil end
			end)
		end

		pendingCheck = nil
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
			pendingCheck = nil
		end
	end)

	local modes = {"great", "good"}
	local modeIdx = 1
	local modeKV = tab:KeyValue("mode", modes[modeIdx], function()
		modeIdx = (modeIdx % #modes) + 1
		autoSC.mode = modes[modeIdx]
		modeKV:Set(modes[modeIdx])
	end)

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
