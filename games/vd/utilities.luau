--[[ Photon VD — Utilities Tab ]]--

local HttpService = game:GetService("HttpService")

local CONFIG_DIR = "Photon/vd"

local function ensureDir(path)
	if makefolder and isfolder and not isfolder(path) then
		makefolder(path)
	end
end

local function listConfigs()
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

	tab:Section("configs")

	local configInput = tab:Input("config name", "my_config", nil)

	tab:Button("save config", function()
		local name = configInput.Get()
		if not name or name == "" then
			Hub:Log("enter a config name", "err")
			return
		end
		name = name:gsub("[^%w_%-]", "_")
		if saveConfig(Hub, name) then
			Hub:Log("saved config: " .. name)
			Hub:Notify("config", "saved " .. name, 2)
		end
	end)

	tab:Button("load config", function()
		local name = configInput.Get()
		if not name or name == "" then
			Hub:Log("enter a config name to load", "err")
			return
		end
		name = name:gsub("[^%w_%-]", "_")
		if loadConfig(Hub, name) then
			Hub:Log("loaded config: " .. name)
			Hub:Notify("config", "loaded " .. name .. " — toggle features to sync ui", 3)
		end
	end)

	tab:Button("delete config", function()
		local name = configInput.Get()
		if not name or name == "" then
			Hub:Log("enter a config name to delete", "err")
			return
		end
		name = name:gsub("[^%w_%-]", "_")
		if deleteConfig(Hub, name) then
			Hub:Log("deleted config: " .. name)
			Hub:Notify("config", "deleted " .. name, 2)
		end
	end)

	tab:Button("list configs", function()
		local configs = listConfigs()
		if #configs == 0 then
			Hub:Log("no saved configs")
		else
			Hub:Log("configs: " .. table.concat(configs, ", "))
		end
	end)

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
