--[[ Photon VD — Performance Tab ]]--

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local function init(Hub, UI)
	local tab = Hub:Tab("performance")

	----------------------------------------------------------------
	-- State
	----------------------------------------------------------------
	local perfState = {
		noShadows = false,
		fullbright = false,
		fpsCapEnabled = false,
		fpsCap = 60,
		espRange = false,
		espRangeMax = 200,
		espDistOpacity = false,
	}

	local savedShadows = Lighting.GlobalShadows
	local savedAmbient = Lighting.Ambient
	local savedBrightness = Lighting.Brightness
	local savedOutdoorAmbient = Lighting.OutdoorAmbient

	----------------------------------------------------------------
	-- Shadows
	----------------------------------------------------------------
	tab:Section("lighting")

	local shadowToggle = tab:Toggle("remove global shadows", false, function(on)
		perfState.noShadows = on
		if on then
			savedShadows = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
		else
			Lighting.GlobalShadows = savedShadows
		end
	end)

	----------------------------------------------------------------
	-- Fullbright
	----------------------------------------------------------------
	local fullbrightConn = nil

	local function applyFullbright()
		savedAmbient = Lighting.Ambient
		savedBrightness = Lighting.Brightness
		savedOutdoorAmbient = Lighting.OutdoorAmbient
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.Brightness = 2
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	end

	local function revertFullbright()
		Lighting.Ambient = savedAmbient
		Lighting.Brightness = savedBrightness
		Lighting.OutdoorAmbient = savedOutdoorAmbient
	end

	local fullbrightToggle = tab:Toggle("fullbright", false, function(on)
		perfState.fullbright = on
		if on then
			applyFullbright()
			if not fullbrightConn then
				fullbrightConn = Lighting.Changed:Connect(function(prop)
					if not perfState.fullbright then return end
					if prop == "Ambient" and Lighting.Ambient ~= Color3.new(1, 1, 1) then
						Lighting.Ambient = Color3.new(1, 1, 1)
					elseif prop == "Brightness" and Lighting.Brightness ~= 2 then
						Lighting.Brightness = 2
					elseif prop == "OutdoorAmbient" and Lighting.OutdoorAmbient ~= Color3.new(1, 1, 1) then
						Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
					end
				end)
			end
		else
			if fullbrightConn then
				fullbrightConn:Disconnect()
				fullbrightConn = nil
			end
			revertFullbright()
		end
	end)

	----------------------------------------------------------------
	-- FPS cap
	----------------------------------------------------------------
	tab:Section("framerate")

	local fpsSlider

	local fpsCapToggle = tab:Toggle("custom frame rate cap", false, function(on)
		perfState.fpsCapEnabled = on
		if on then
			if setfpscap then
				setfpscap(perfState.fpsCap)
			end
		else
			if setfpscap then
				setfpscap(1e6)
			end
		end
	end)

	fpsSlider = tab:Slider("fps cap", 30, 200, perfState.fpsCap, function(v)
		perfState.fpsCap = v
		if perfState.fpsCapEnabled and setfpscap then
			setfpscap(v)
		end
	end, { Step = 5, Suffix = " fps" })

	----------------------------------------------------------------
	-- ESP range limit
	----------------------------------------------------------------
	tab:Section("esp range")

	local rangeToggle = tab:Toggle("highlight range limit", false, function(on)
		perfState.espRange = on
	end)

	local rangeSlider = tab:Slider("max range", 10, 500, perfState.espRangeMax, function(v)
		perfState.espRangeMax = v
	end, { Step = 10, Suffix = " studs" })

	local distOpacityToggle = tab:Toggle("distance based opacity", false, function(on)
		perfState.espDistOpacity = on
	end)

	----------------------------------------------------------------
	-- Expose to Hub for visuals consumption
	----------------------------------------------------------------
	Hub._perfESP = perfState

	Hub:RegisterConfig("perfState", perfState, function()
		if perfState.noShadows then
			Lighting.GlobalShadows = false
		end
		if perfState.fullbright then
			applyFullbright()
		end
		if perfState.fpsCapEnabled and setfpscap then
			setfpscap(perfState.fpsCap)
		end
	end)

	Hub:OnConfigLoad(function()
		shadowToggle:Set(perfState.noShadows)
		fullbrightToggle:Set(perfState.fullbright)
		fpsCapToggle:Set(perfState.fpsCapEnabled)
		fpsSlider:Set(perfState.fpsCap)
		rangeToggle:Set(perfState.espRange)
		rangeSlider:Set(perfState.espRangeMax)
		distOpacityToggle:Set(perfState.espDistOpacity)
	end)

	Hub:RegisterCleanup(function()
		if fullbrightConn then
			fullbrightConn:Disconnect()
			fullbrightConn = nil
		end
		if perfState.noShadows then
			Lighting.GlobalShadows = savedShadows
		end
		if perfState.fullbright then
			revertFullbright()
		end
		if perfState.fpsCapEnabled and setfpscap then
			setfpscap(1e6)
		end
	end)
end

return { init = init }
