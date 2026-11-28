--[[ Photon VD — Banner Tab ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------------
-- Perk Lookup — normalized key → display name (44 total)
---------------------------------------------------------------------------
local KILLER_PERKS = {
	-- stalker
	["predator"] = "Predator",
	["eternaltorment"] = "Eternal Torment",
	["playwithyourfood"] = "Play With Your Food",
	-- slasher
	["excitement"] = "Excitement",
	["brutalstrength"] = "Brutal Strength",
	["offscreenscare"] = "Offscreen Scare",
	-- killer (jeff)
	["terrorspread"] = "Terror Spread",
	["sloppymess"] = "Sloppy Mess",
	["resentmentclinger"] = "Resentment Clinger",
	-- hidden
	["echolocation"] = "Echo Location",
	["enhancedsenses"] = "Enhanced Senses",
	["nextinline"] = "Next in Line",
	-- abysswalker
	["corruptedpath"] = "Corrupted Path",
	["abyssalcovenant"] = "Abyssal Covenant",
	["shadowtrace"] = "Shadow Trace",
	-- veil
	["piercingreverie"] = "Piercing Reverie",
	["bloodbetweenworlds"] = "Blood Between Worlds",
	["echoofthevoid"] = "Echo Of The Void",
	-- masked
	["hardswing"] = "Hard Swing",
	["combostreak"] = "Combo Streak",
	["crackdown"] = "Crackdown",
	-- cure
	["foundationstaff"] = "Foundation Staff",
	["sustenance"] = "Sustenance",
	["desirefortheliving"] = "Desire For The Living",
	-- butcher
	["splitthepain"] = "Split The Pain",
	["bloodhound"] = "Bloodhound",
	["rottenstench"] = "Rotten Stench",
	-- universal shop perks
	["coldblooded"] = "Cold Blooded",
	["murderousacrobatics"] = "Murderous Acrobatics",
	["surgeofpower"] = "Surge of Power",
	["diminishingreturns"] = "Diminishing Returns",
	["veiledcorruption"] = "Veiled Corruption",
	["visceraldrive"] = "Visceral Drive",
	["kingsscourge"] = "King's Scourge",
	["dreadharvest"] = "Dread Harvest",
	["allseeingeye"] = "All Seeing Eye",
	["eyesofhell"] = "Eyes of Hell",
	["stagefright"] = "Stage Fright",
	["exposuretherapy"] = "Exposure Therapy",
	["silentshadow"] = "Silent Shadow",
	["touchofdeath"] = "Touch of Death",
	["deepwound"] = "Deep Wound",
	["tradeoff"] = "Trade Off",
	["containment"] = "Containment",
}

local function normalize(name)
	return string.lower(string.gsub(name, "[^%a]", ""))
end

---------------------------------------------------------------------------
-- Detection
---------------------------------------------------------------------------
local function findKiller()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Team and p.Team.Name == "Killer" then
			return p
		end
	end
	return nil
end

local function getKillerName(killer)
	if not killer then return nil end
	local char = killer.Character
	if not char then return nil end
	local morphed = char:GetAttribute("MorphedKiller")
	if morphed then return tostring(morphed) end
	return killer.DisplayName
end

local function detectPerks(char)
	local found = {}
	if not char then return found end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("BaseScript") or child:IsA("ModuleScript") then
			local key = normalize(child.Name)
			local perk = KILLER_PERKS[key]
			if perk then
				table.insert(found, perk)
			end
		end
	end
	return found
end

local MAP_NAMES = {
	["farm"]             = "Ashwood Farm",
	["club"]             = "BLOODBATH! Club",
	["firelinkshrine"]   = "Firelink Shrine",
	["rooftophospital"]  = "Mercy Hospital Rooftop",
	["asylum"]           = "Mount Massive Asylum",
	["scp"]              = "Site 68",
	["harbor"]           = "Bay Harbor",
	["re4"]              = "Valdelobos Village",
	["forest"]           = "Woodview Cabin",
}

local function detectMap()
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return nil, nil, nil end
	local stream = mapFolder:GetAttribute("StreamMapName")
	if not stream or stream == "" then return nil, nil, nil end
	local key = string.lower(stream)
	local display = MAP_NAMES[key] or stream
	local variant = mapFolder:GetAttribute("StreamVariantName")
	local varStr = variant and ("V" .. tostring(variant)) or nil
	return display, varStr, key
end

local function getPing()
	local ok, val = pcall(function()
		return math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
	end)
	return ok and val or 0
end

---------------------------------------------------------------------------
-- Clock overlay — per-map zone detection
---------------------------------------------------------------------------
local CLOCK_DATA = {
	["harbor"] = {
		centerX = -1649.7, centerZ = -1398.4,
		halfW = 430.1, halfH = 466.9,
		midRadius = 0.35,
		labels = {
			[10] = "10 — Warehouse",
		},
	},
}

local function getClockZone(mapKey, posX, posZ)
	local data = CLOCK_DATA[string.lower(mapKey)]
	if not data then return nil end

	local dx = (data.centerX - posX) / data.halfW
	local dz = (posZ - data.centerZ) / data.halfH
	local dist = math.sqrt(dx * dx + dz * dz)

	local angle = math.deg(math.atan2(dx, dz))
	if angle < 0 then angle += 360 end

	if dist < data.midRadius then
		if angle < 45 or angle >= 315 then return "Top Mid"
		elseif angle < 135 then return "Mid Right"
		elseif angle < 225 then return "Bottom Mid"
		else return "Mid Left" end
	end

	local clock = math.floor((angle + 15) / 30) % 12
	if clock == 0 then clock = 12 end
	return data.labels[clock] or tostring(clock)
end

local function getPlayerPosition()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end
	return root.Position.X, root.Position.Z
end

---------------------------------------------------------------------------
-- Banner positions
---------------------------------------------------------------------------
local BANNER_ANCHORS = {
	["top-left"]      = { anchor = Vector2.new(0, 0),     pos = UDim2.new(0, 12, 0, 12) },
	["top-center"]    = { anchor = Vector2.new(0.5, 0),   pos = UDim2.new(0.5, 0, 0, 12) },
	["top-right"]     = { anchor = Vector2.new(1, 0),     pos = UDim2.new(1, -12, 0, 12) },
	["bottom-left"]   = { anchor = Vector2.new(0, 1),     pos = UDim2.new(0, 12, 1, -12) },
	["bottom-center"] = { anchor = Vector2.new(0.5, 1),   pos = UDim2.new(0.5, 0, 1, -12) },
	["bottom-right"]  = { anchor = Vector2.new(1, 1),     pos = UDim2.new(1, -12, 1, -12) },
}
local POSITION_LIST = { "top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right" }

local DIM_HEX = "#606060"

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function init(Hub, UI)
	local T = UI.Theme
	local H = UI.Helpers
	local F = UI.Fonts
	local esc = H.escape

	local tab = Hub:Tab("banner")

	local bannerState = {
		enabled = false,
		position = "top-left",
		showPerformance = true,
		showMap = true,
		showKiller = true,
		showPerks = true,
		showClock = true,
	}

	-----------------------------------------------------------------
	-- HUD overlay (lives on Hub.Gui, independent of window visibility)
	-----------------------------------------------------------------
	local banner = H.Frame(Hub.Gui, {
		Name = "Banner",
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.25,
		Visible = false,
		Active = false,
	})
	H.Stroke(banner, T.line)
	H.Pad(banner, 6, 10, 6, 10)
	H.List(banner, 2)

	local function positionBanner(where)
		local cfg = BANNER_ANCHORS[where]
		if not cfg then return end
		bannerState.position = where
		banner.AnchorPoint = cfg.anchor
		banner.Position = cfg.pos
	end
	positionBanner(bannerState.position)

	local function infoLine(name, order)
		return H.Text(banner, "", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(0, 0, 0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = F.Regular,
			TextSize = 11,
			TextColor3 = T.text,
			RichText = true,
			Visible = false,
		})
	end

	local perfLabel   = infoLine("Perf", 1)
	local mapLabel    = infoLine("Map", 2)
	local clockLabel  = infoLine("Clock", 3)
	local killerLabel = infoLine("Killer", 4)
	local perkLabel   = infoLine("Perks", 5)

	-----------------------------------------------------------------
	-- Update loop
	-----------------------------------------------------------------
	local frameCount, frameAcc = 0, 0
	local currentFPS = 0
	local displayAcc = 0
	local slowAcc = 0
	local cachedMap, cachedVariant, cachedMapKey = nil, nil, nil
	local cachedKillerName = nil
	local cachedPerks = {}
	local cachedClockZone = nil

	Hub:_track(RunService.RenderStepped:Connect(function(dt)
		if not bannerState.enabled then return end

		frameCount += 1
		frameAcc += dt
		if frameAcc >= 1 then
			currentFPS = math.floor(frameCount / frameAcc + 0.5)
			frameCount, frameAcc = 0, 0
		end

		slowAcc += dt
		if slowAcc >= 2 then
			slowAcc = 0
			cachedMap, cachedVariant, cachedMapKey = detectMap()
			local killer = findKiller()
			cachedKillerName = getKillerName(killer)
			cachedPerks = killer and detectPerks(killer.Character) or {}
		end

		if bannerState.showClock and cachedMapKey then
			local px, pz = getPlayerPosition()
			if px then
				cachedClockZone = getClockZone(cachedMapKey, px, pz)
			else
				cachedClockZone = nil
			end
		else
			cachedClockZone = nil
		end

		displayAcc += dt
		if displayAcc < 0.5 then return end
		displayAcc = 0

		if bannerState.showPerformance then
			local ping = getPing()
			perfLabel.Text = '<font color="' .. DIM_HEX .. '">fps</font> '
				.. currentFPS .. '  <font color="' .. DIM_HEX .. '">ping</font> ' .. ping .. "ms"
			perfLabel.Visible = true
		else
			perfLabel.Visible = false
		end

		if bannerState.showMap and cachedMap then
			local text = esc(cachedMap)
			if cachedVariant then
				text = text .. ' <font color="' .. DIM_HEX .. '">(' .. esc(cachedVariant) .. ")</font>"
			end
			mapLabel.Text = '<font color="' .. DIM_HEX .. '">map</font> ' .. text
			mapLabel.Visible = true
		else
			mapLabel.Visible = false
		end

		if bannerState.showClock and cachedClockZone then
			clockLabel.Text = '<font color="' .. DIM_HEX .. '">clock</font> ' .. esc(cachedClockZone)
			clockLabel.Visible = true
		else
			clockLabel.Visible = false
		end

		if bannerState.showKiller and cachedKillerName then
			killerLabel.Text = '<font color="' .. DIM_HEX .. '">killer</font> ' .. esc(cachedKillerName)
			killerLabel.Visible = true
		else
			killerLabel.Visible = false
		end

		if bannerState.showPerks and cachedKillerName then
			if #cachedPerks > 0 then
				local names = {}
				for _, p in ipairs(cachedPerks) do table.insert(names, esc(p)) end
				perkLabel.Text = '<font color="' .. DIM_HEX .. '">perks</font> ' .. table.concat(names, ", ")
			else
				perkLabel.Text = '<font color="' .. DIM_HEX .. '">perks</font> Perkless'
			end
			perkLabel.Visible = true
		else
			perkLabel.Visible = false
		end
	end))

	-----------------------------------------------------------------
	-- Tab UI
	-----------------------------------------------------------------
	tab:Section("banner overlay")

	local masterToggle = tab:Toggle("enabled", false, function(on)
		bannerState.enabled = on
		banner.Visible = on
		if on then slowAcc = 2 end
		Hub:Log(on and "banner on" or "banner off")
	end, "banner")

	local posChoice = tab:Choice("position", POSITION_LIST, bannerState.position, function(pos)
		positionBanner(pos)
	end)

	tab:Section("display")

	local perfToggle = tab:Toggle("performance (fps, ping)", true, function(on)
		bannerState.showPerformance = on
	end)

	local mapToggle = tab:Toggle("map info", true, function(on)
		bannerState.showMap = on
	end)

	local clockToggle = tab:Toggle("clock position", true, function(on)
		bannerState.showClock = on
	end)

	local killerToggle = tab:Toggle("killer info", true, function(on)
		bannerState.showKiller = on
	end)

	local perkToggle = tab:Toggle("killer perks", true, function(on)
		bannerState.showPerks = on
	end)

	-----------------------------------------------------------------
	-- Config persistence
	-----------------------------------------------------------------
	Hub:RegisterConfig("bannerState", bannerState)

	Hub:OnConfigLoad(function()
		masterToggle:Set(bannerState.enabled)
		posChoice:Set(bannerState.position)
		perfToggle:Set(bannerState.showPerformance)
		mapToggle:Set(bannerState.showMap)
		clockToggle:Set(bannerState.showClock)
		killerToggle:Set(bannerState.showKiller)
		perkToggle:Set(bannerState.showPerks)
		positionBanner(bannerState.position)
		banner.Visible = bannerState.enabled
	end)

	Hub:RegisterCleanup(function()
		banner:Destroy()
	end)
end

return { init = init }
