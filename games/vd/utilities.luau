--[[ Photon VD — Utilities Tab ]]--

local HttpService = game:GetService("HttpService")

local CONFIG_DIR = "Photon/vd"

local function ensureDir(path)
	if makefolder and isfolder and not isfolder(path) then
		makefolder(path)
	end
end

local function scanConfigs()
	if not listfiles or not isfolder or not isfolder(CONFIG_DIR) then return {} end
	local names = {}
	for _, path in ipairs(listfiles(CONFIG_DIR)) do
		local name = path:match("([^/\\]+)%.json$")
		if name then table.insert(names, name) end
	end
	table.sort(names)
	return names
end

local function saveConfig(Hub, name)
	if not writefile then
		Hub:Log("writefile not available", "err")
		return false
	end
	ensureDir("Photon")
	ensureDir(CONFIG_DIR)
	local snap = Hub:GetConfigSnapshot()
	local ok, json = pcall(HttpService.JSONEncode, HttpService, snap)
	if not ok then
		Hub:Log("config encode failed", "err")
		return false
	end
	writefile(CONFIG_DIR .. "/" .. name .. ".json", json)
	return true
end

local function loadConfig(Hub, name)
	if not readfile then
		Hub:Log("readfile not available", "err")
		return false
	end
	local path = CONFIG_DIR .. "/" .. name .. ".json"
	if isfile and not isfile(path) then
		Hub:Log("config not found: " .. name, "err")
		return false
	end
	local raw = readfile(path)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(data) ~= "table" then
		Hub:Log("config parse failed", "err")
		return false
	end
	Hub:ApplyConfig(data)
	return true
end

local function deleteConfig(Hub, name)
	if not delfile then
		Hub:Log("delfile not available", "err")
		return false
	end
	local path = CONFIG_DIR .. "/" .. name .. ".json"
	if isfile and not isfile(path) then
		Hub:Log("config not found: " .. name, "err")
		return false
	end
	delfile(path)
	return true
end

local function init(Hub, UI)
	local tab = Hub:Tab("utilities")

	----------------------------------------------------------------
	-- Save
	----------------------------------------------------------------
	tab:Section("save config")

	local refreshDropdown
	local configInput = tab:Input("config name", "my_config", nil)

	tab:Button("save", function()
		local name = configInput.Get()
		if not name or name == "" then
			Hub:Log("enter a config name", "err")
			return
		end
		name = name:gsub("[^%w_%-]", "_")
		if saveConfig(Hub, name) then
			Hub:Log("saved: " .. name)
			Hub:Notify("config", "saved " .. name, 2)
			refreshDropdown()
		end
	end)

	----------------------------------------------------------------
	-- Load / Delete
	----------------------------------------------------------------
	tab:Section("manage configs")

	local configList = scanConfigs()
	if #configList == 0 then table.insert(configList, "(none)") end

	local dropdown = tab:Choice("config", configList, configList[1], function() end)

	refreshDropdown = function()
		local fresh = scanConfigs()
		for i = #configList, 1, -1 do table.remove(configList, i) end
		if #fresh == 0 then
			table.insert(configList, "(none)")
		else
			for _, n in ipairs(fresh) do table.insert(configList, n) end
		end
		local cur = dropdown.Get()
		if not table.find(configList, cur) then
			dropdown:Set(configList[1])
		end
	end

	tab:Button("load", function()
		local name = dropdown.Get()
		if not name or name == "" or name == "(none)" then
			Hub:Log("no config selected", "err")
			return
		end
		if loadConfig(Hub, name) then
			Hub:Log("loaded: " .. name)
			Hub:Notify("config", "loaded " .. name, 2)
		end
	end)

	tab:Button("delete", function()
		local name = dropdown.Get()
		if not name or name == "" or name == "(none)" then
			Hub:Log("no config selected", "err")
			return
		end
		if deleteConfig(Hub, name) then
			Hub:Log("deleted: " .. name)
			Hub:Notify("config", "deleted " .. name, 2)
			refreshDropdown()
		end
	end)

	tab:Button("refresh list", function()
		refreshDropdown()
		Hub:Log("config list refreshed")
	end)

	----------------------------------------------------------------
	-- System
	----------------------------------------------------------------
	tab:Section("system")

	tab:Button("unload photon", function()
		Hub:Log("unloading...")
		Hub:Notify("photon", "unloading — goodbye", 2)
		task.delay(0.5, function()
			Hub:Unload()
		end)
	end)
end

return { init = init }
