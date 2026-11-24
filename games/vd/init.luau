--[[ Photon — Violence District ]]--

local UI = require(script.Parent.Parent.shared.ui)
local Visuals = require(script.visuals)

return function(Hub)
	Visuals.init(Hub, UI)
end
