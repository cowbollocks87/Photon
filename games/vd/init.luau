--[[ Photon — Violence District ]]--

local UI = require(script.Parent.Parent.shared.ui)
local Visuals = require(script.visuals)
local Automation = require(script.automation)

return function(Hub)
	Visuals.init(Hub, UI)
	Automation.init(Hub, UI)
end
