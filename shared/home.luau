--[[ Photon — Shared Home Tab ]]--

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local function build(Hub, gameConfig)
	gameConfig = gameConfig or {}
	local gameName = gameConfig.name or "Unknown"
	local home = Hub:Tab("home")

	-- greeting
	home:Section("welcome")
	local hour = tonumber(os.date("%H"))
	local greeting = hour < 12 and "good morning" or hour < 18 and "good afternoon" or "good evening"
	home:Label(greeting .. ", " .. LocalPlayer.DisplayName .. ".")

	-- session info
	home:Section("session")
	home:KeyValue("game", gameName)
	home:KeyValue("place id", tostring(game.PlaceId))
	local serverKv = home:KeyValue("server", game.JobId ~= "" and string.sub(game.JobId, 1, 12) or "studio")
	local playersKv = home:KeyValue("players", #Players:GetPlayers() .. " / " .. Players.MaxPlayers)
	local pingKv = home:KeyValue("ping", "--")
	local uptimeKv = home:KeyValue("uptime", "00:00:00")

	local function refreshPlayers()
		playersKv:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
	end
	Hub:_track(Players.PlayerAdded:Connect(refreshPlayers))
	Hub:_track(Players.PlayerRemoving:Connect(function() task.defer(refreshPlayers) end))

	local started = os.clock()
	task.spawn(function()
		while not Hub.Destroyed do
			local s = math.floor(os.clock() - started)
			uptimeKv:Set(string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60))
			local pingMs = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
			pingKv:Set(tostring(pingMs) .. " ms")
			task.wait(1)
		end
	end)

	-- environment
	home:Section("environment")
	local executorName, executorVersion = "unknown", "?"
	pcall(function()
		if identifyexecutor then
			executorName, executorVersion = identifyexecutor()
			executorName = string.lower(executorName)
		end
	end)
	home:KeyValue("executor", executorName)
	home:KeyValue("build", "v" .. tostring(executorVersion))

	local hwid = "n/a"
	pcall(function()
		if gethwid then hwid = string.sub(gethwid(), 1, 12) .. "..."
		elseif getHWID then hwid = string.sub(getHWID(), 1, 12) .. "..." end
	end)
	home:KeyValue("hwid", hwid)

	-- player list
	home:Section("players")
	local playerRows = {}

	local function addPlayerRow(player)
		local display = string.lower(player.DisplayName)
		local username = "@" .. string.lower(player.Name)
		local suffix = player == LocalPlayer and "  (you)" or ""
		playerRows[player] = home:KeyValue(display .. suffix, username, function()
			if setclipboard then
				setclipboard(player.Name)
				Hub:Log("copied " .. player.Name)
				Hub:Notify("copied", username .. " to clipboard", 2)
			end
		end)
	end

	local function removePlayerRow(player)
		playerRows[player] = nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		addPlayerRow(player)
	end

	Hub:_track(Players.PlayerAdded:Connect(addPlayerRow))
	Hub:_track(Players.PlayerRemoving:Connect(removePlayerRow))

	-- appearance
	home:Section("appearance")
	local accentList = Hub.AccentList or {"white"}
	home:Choice("accent color", accentList, "white", function(name)
		Hub:SetAccent(name)
	end)

	Hub:RegisterConfig("appearance", Hub._appearance, function()
		Hub:SetAccent(Hub._appearance.accent)
	end)

	-- quick actions
	home:Section("quick")
	home:Button("copy server id", function()
		if setclipboard then
			setclipboard(game.JobId)
			Hub:Log("server id copied")
			Hub:Notify("copied", "job id in clipboard", 2)
		else
			Hub:Log("clipboard not available", "err")
		end
	end)

	home:Button("rejoin server", function()
		Hub:Log("rejoining...")
		Hub:Notify("rejoin", "teleporting back to this server", 2)
		task.delay(0.5, function()
			local TeleportService = game:GetService("TeleportService")
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end)
	end)

	home:Button("server hop", function()
		Hub:Log("finding new server...")
		Hub:Notify("hop", "looking for a different server", 2)
		task.spawn(function()
			local TeleportService = game:GetService("TeleportService")
			local ok, result = pcall(function()
				return game:GetService("HttpService"):JSONDecode(
					game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=10")
				)
			end)
			if ok and result and result.data then
				for _, srv in ipairs(result.data) do
					if srv.id ~= game.JobId and srv.playing and srv.playing < srv.maxPlayers then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id)
						return
					end
				end
			end
			Hub:Log("no available servers found", "err")
		end)
	end)

	return home
end

return { build = build }
