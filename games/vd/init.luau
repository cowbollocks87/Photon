--[[ Photon — Violence District ]]--

local UI = require(script.Parent.Parent.shared.ui)
local Visuals = require(script.visuals)
local Automation = require(script.automation)
local Enhancements = require(script.enhancements)
local Performance = require(script.performance)
local Utilities = require(script.utilities)

return function(Hub)
	Visuals.init(Hub, UI)
	Automation.init(Hub, UI)
	Enhancements.init(Hub, UI)
	Performance.init(Hub, UI)
	Utilities.init(Hub, UI)
end
