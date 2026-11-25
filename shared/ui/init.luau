--[[
	Photon UI Library
	Monochrome · monospace · floating window

	API
	  local Hub = UI.new({ Title = "hub", Version = "1.0.0", Keybind = Enum.KeyCode.RightShift })
	  local tab = Hub:Tab("scripts")

	  tab:Section("library")
	  tab:Script(name, description, callback)
	  tab:Button(label, callback)
	  tab:Toggle(label, default, callback(bool), bindId?)
	  tab:Slider(label, min, max, default, callback(n), {Step=1, Suffix=""})
	  tab:Choice(label, {"a","b"}, default, callback(str))
	  tab:Input(label, placeholder, callback(text), {Live=false, Default=""})
	  tab:Search(placeholder)
	  tab:KeyValue(key, value)
	  tab:Label(text)
	  tab:Console(height)

	  Hub:Log(message, level?)
	  Hub:Notify(title, body, seconds)
	  Hub:SelectTab(tab)  Hub:SetVisible(bool)  Hub:Clear()  Hub:Destroy()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------------
-- THEME
---------------------------------------------------------------------------
local function grey(v) return Color3.fromRGB(v, v, v) end
local T = {
	bg     = grey(10),
	side   = grey(7),
	field  = grey(5),
	raised = grey(24),
	line   = grey(32),
	lineHi = grey(64),
	dim    = grey(96),
	mid    = grey(158),
	text   = grey(226),
	white  = grey(255),
	black  = grey(0),
}
local HEX = {dim = "#606060", faint = "#3A3A3A", text = "#E2E2E2"}

local ACCENTS = {
	white      = {color = grey(255),                        hex = "#FFFFFF"},
	["baby blue"]  = {color = Color3.fromRGB(137, 207, 240), hex = "#89CFF0"},
	turquoise  = {color = Color3.fromRGB(72, 209, 204),    hex = "#48D1CC"},
	["sage green"] = {color = Color3.fromRGB(152, 190, 140), hex = "#98BE8C"},
	maroon     = {color = Color3.fromRGB(178, 70, 70),     hex = "#B24646"},
}
local ACCENT_LIST = {"white", "baby blue", "turquoise", "sage green", "maroon"}
T.accent = ACCENTS.white.color
HEX.accent = ACCENTS.white.hex

local accentCallbacks = {}
local function onAccentChange(fn) table.insert(accentCallbacks, fn) end
local function fireAccentChange()
	for _, fn in ipairs(accentCallbacks) do pcall(fn) end
end

local FAMILY = "rbxasset://fonts/families/RobotoMono.json"
local FONT   = Font.new(FAMILY, Enum.FontWeight.Regular)
local FONT_M = Font.new(FAMILY, Enum.FontWeight.Medium)
local FONT_B = Font.new(FAMILY, Enum.FontWeight.Bold)

local WIN_W, WIN_H = 580, 368
local SIDE_W, TITLE_H, STATUS_H, ROW_H = 150, 30, 22, 28
local BAR_CHARS = 20
local MAX_LOG = 150

local LEFT, RIGHT, CENTER = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center
local AUTO_X, AUTO_Y = Enum.AutomaticSize.X, Enum.AutomaticSize.Y

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------
local function merge(a, b)
	local t = {}
	for k, v in pairs(a) do t[k] = v end
	if b then for k, v in pairs(b) do t[k] = v end end
	return t
end

local function new(class, props)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end

local function U(x, y) return UDim2.fromOffset(x, y) end

local function Frame(parent, p)
	return new("Frame", merge({BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = parent}, p))
end

local function Text(parent, s, p)
	return new("TextLabel", merge({
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = s, FontFace = FONT, TextSize = 12,
		TextColor3 = T.text, TextXAlignment = LEFT, Size = UDim2.fromScale(1, 1), Parent = parent,
	}, p))
end

local function Button(parent, s, p)
	return new("TextButton", merge({
		AutoButtonColor = false, BackgroundTransparency = 1, BackgroundColor3 = T.raised, BorderSizePixel = 0,
		Text = s or "", FontFace = FONT, TextSize = 12, TextColor3 = T.text, Parent = parent,
	}, p))
end

local function Stroke(parent, color)
	return new("UIStroke", {Color = color or T.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter, Parent = parent})
end

local function Rule(parent, pos, size, color)
	return Frame(parent, {Name = "Rule", Position = pos, Size = size, BackgroundColor3 = color or T.line})
end

local function Pad(parent, t, r, b, l)
	return new("UIPadding", {PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l), Parent = parent})
end

local function List(parent, padding, horizontal)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 0), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(o, props, info) TweenService:Create(o, info or FAST, props):Play() end

local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

---------------------------------------------------------------------------
-- HUB
---------------------------------------------------------------------------
local UI = {}
UI.__index = UI
UI.Theme = T
UI.Fonts = { Regular = FONT, Medium = FONT_M, Bold = FONT_B }
UI.Helpers = { Frame = Frame, Text = Text, Button = Button, Stroke = Stroke, Rule = Rule, Pad = Pad, List = List, U = U, new = new, merge = merge, tween = tween, escape = escape }
UI.Constants = { WIN_W = WIN_W, WIN_H = WIN_H, SIDE_W = SIDE_W, TITLE_H = TITLE_H, STATUS_H = STATUS_H, ROW_H = ROW_H }

local Tab = {}
Tab.__index = Tab

function UI.new(opts)
	opts = opts or {}
	local self = setmetatable({}, UI)
	self.Title = opts.Title or "hub"
	self.Version = opts.Version or "1.0.0"
	self.Keybind = opts.Keybind or Enum.KeyCode.RightShift
	self.User = string.lower(LocalPlayer.Name)
	self.Tabs, self.Connections, self.Consoles, self.History = {}, {}, {}, {}
	self._configRegistry, self._cleanups = {}, {}
	self._appearance = { accent = "white" }
	self._keybinds = {}
	self._keybindToggles = {}
	self._keybindRenders = {}
	self._keybindListening = nil
	self.NotificationsEnabled = true
	self.Minimized = false
	self.LineCount, self.ToastCount = 0, 0

	local keyName = string.lower(self.Keybind.Name)

	local gui = new("ScreenGui", {Name = "Photon_" .. self.Title, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50})

	pcall(function()
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = game:GetService("CoreGui")
		else
			gui.Parent = game:GetService("CoreGui")
		end
	end)
	if not gui.Parent then
		gui.Parent = opts.Parent or LocalPlayer:WaitForChild("PlayerGui")
	end

	self.Gui = gui

	local win = Frame(gui, {Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = U(WIN_W, TITLE_H), BackgroundColor3 = T.bg, ClipsDescendants = true, Active = true})
	Stroke(win, T.line)
	self.Window = win
	self.Scale = new("UIScale", {Scale = opts.Scale or 1, Parent = win})

	local bar = Frame(win, {Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundColor3 = T.side, Active = true, ZIndex = 5})
	Rule(bar, UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))
	local promptRow = Frame(bar, {Position = U(12, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1})
	List(promptRow, 4, true)
	self.Prompt = Text(promptRow, "", {Name = "Prompt", RichText = true, LayoutOrder = 1, AutomaticSize = AUTO_X,
		Size = UDim2.new(0, 0, 1, 0), FontFace = FONT_M})
	self.Cursor = Frame(promptRow, {Name = "Cursor", LayoutOrder = 2, Size = U(7, 13), BackgroundColor3 = T.text})

	local function control(label, x)
		local b = Button(bar, label, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = U(30, 20), TextColor3 = T.dim})
		b.MouseEnter:Connect(function() b.TextColor3 = T.white end)
		b.MouseLeave:Connect(function() b.TextColor3 = T.dim end)
		return b
	end
	local closeBtn = control("[x]", -8)
	local minBtn = control("[_]", -40)

	local body = Frame(win, {Name = "Body", Position = U(0, TITLE_H), Size = UDim2.new(1, 0, 1, -(TITLE_H + STATUS_H)), BackgroundTransparency = 1})

	local side = Frame(body, {Name = "Sidebar", Size = UDim2.new(0, SIDE_W, 1, 0), BackgroundColor3 = T.side})
	Rule(side, UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0))
	Text(side, "// nav", {Position = U(16, 10), Size = U(100, 14), TextSize = 10, TextColor3 = T.dim})
	self.TabList = Frame(side, {Name = "Tabs", Position = U(8, 30), Size = UDim2.new(1, -16, 1, -84), BackgroundTransparency = 1})
	List(self.TabList, 2)
	Rule(side, UDim2.new(0, 16, 1, -46), UDim2.new(1, -32, 0, 1))
	Text(side, keyName .. "  hide", {Position = UDim2.new(0, 16, 1, -40), Size = U(SIDE_W - 32, 14), TextSize = 10, TextColor3 = T.dim})
	Text(side, "v" .. self.Version, {Position = UDim2.new(0, 16, 1, -24), Size = U(SIDE_W - 32, 14), TextSize = 10, TextColor3 = T.dim})

	self.Content = Frame(body, {Name = "Content", Position = U(SIDE_W, 0), Size = UDim2.new(1, -SIDE_W, 1, 0), BackgroundTransparency = 1})

	local status = Frame(win, {Name = "StatusBar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, STATUS_H), BackgroundColor3 = T.side})
	Rule(status, U(0, 0), UDim2.new(1, 0, 0, 1))
	local mode = Frame(status, {Name = "Mode", Position = U(0, 1), Size = UDim2.new(0, 0, 1, -1), AutomaticSize = AUTO_X, BackgroundColor3 = T.text})
	Pad(mode, 0, 10, 0, 10)
	self.ModeLabel = Text(mode, "", {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AUTO_X, FontFace = FONT_B, TextSize = 10, TextColor3 = T.black})
	self.StatusLabel = Text(status, "ready", {Position = U(88, 0), Size = UDim2.new(1, -230, 1, 0), TextSize = 10,
		TextColor3 = T.mid, TextTruncate = Enum.TextTruncate.AtEnd})
	local info = Text(status, "-- fps", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = U(140, STATUS_H),
		TextSize = 10, TextColor3 = T.dim, TextXAlignment = RIGHT})

	self.Toasts = Frame(gui, {Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1})
	self.ToastLayout = List(self.Toasts, 4)
	self.ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self._appearance.toastPos = self._appearance.toastPos or "top-center"
	self._appearance.toastOffsetX = self._appearance.toastOffsetX or 0
	self._appearance.toastOffsetY = self._appearance.toastOffsetY or 0
	self:SetToastPosition(self._appearance.toastPos)

	minBtn.MouseButton1Click:Connect(function()
		self.Minimized = not self.Minimized
		minBtn.Text = self.Minimized and "[+]" or "[_]"
		tween(win, {Size = U(WIN_W, self.Minimized and TITLE_H or WIN_H)}, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:SetVisible(false)
		self:Notify("hidden", "press " .. keyName .. " to reopen", 3)
	end)

	self:_track(UserInputService.InputBegan:Connect(function(input, processed)
		if self._keybindListening then
			if input.KeyCode == Enum.KeyCode.Unknown then return end
			local id = self._keybindListening
			if input.KeyCode == Enum.KeyCode.Escape then
				self._keybindListening = nil
				local renderFn = self._keybindRenders[id]
				if renderFn then renderFn() end
				return
			end
			if input.KeyCode == self.Keybind then return end
			self._keybindListening = nil
			self:SetKeybind(id, input.KeyCode)
			return
		end
		if processed then return end
		if input.KeyCode == self.Keybind then self:SetVisible(not win.Visible); return end
		local kn = input.KeyCode.Name
		for bindId, boundKey in pairs(self._keybinds) do
			if boundKey == kn then
				local toggle = self._keybindToggles[bindId]
				if toggle then toggle:Set(not toggle.Get()) end
			end
		end
	end))

	local dragging, dragStart, startPos = false, nil, nil
	bar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, dragStart, startPos = true, input.Position, win.Position
		end
	end)
	self:_track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	self:_track(UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end))

	local frames, acc = 0, 0
	self:_track(RunService.RenderStepped:Connect(function(dt)
		frames = frames + 1
		acc = acc + dt
		if acc >= 1 then
			info.Text = math.floor(frames / acc + 0.5) .. " fps  ·  " .. os.date("%H:%M:%S")
			frames, acc = 0, 0
		end
	end))

	task.spawn(function()
		while not self.Destroyed do
			self.Cursor.Visible = not self.Cursor.Visible
			task.wait(0.53)
		end
	end)

	task.defer(function()
		tween(win, {Size = U(WIN_W, WIN_H)}, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
	end)

	return self
end

function UI:_track(conn)
	table.insert(self.Connections, conn)
	return conn
end

function UI:_setPath(name)
	self.Prompt.Text = '<font color="' .. HEX.dim .. '">' .. escape(self.User) .. '@</font>' .. escape(self.Title)
		.. '<font color="' .. HEX.dim .. '">:</font>~/' .. escape(name) .. ' <font color="' .. HEX.dim .. '">$</font>'
end

function UI:SetVisible(v)
	if v and not self.Window.Visible then
		self._savedMouseBehavior = UserInputService.MouseBehavior
		self._savedMouseIcon = UserInputService.MouseIconEnabled
		if not self._cursorOverride then
			self._cursorOverride = RunService.RenderStepped:Connect(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end)
		end
	elseif not v and self.Window.Visible then
		if self._cursorOverride then
			self._cursorOverride:Disconnect()
			self._cursorOverride = nil
		end
		if self._savedMouseBehavior ~= nil then
			UserInputService.MouseBehavior = self._savedMouseBehavior
		end
		if self._savedMouseIcon ~= nil then
			UserInputService.MouseIconEnabled = self._savedMouseIcon
		end
	end
	self.Window.Visible = v
end

local TOAST_ANCHORS = {
	["top-left"]      = { anchor = Vector2.new(0, 0), scale = Vector2.new(0, 0),     base = Vector2.new(16, 16),   hAlign = Enum.HorizontalAlignment.Left },
	["top-center"]    = { anchor = Vector2.new(0.5, 0), scale = Vector2.new(0.5, 0), base = Vector2.new(0, 16),    hAlign = Enum.HorizontalAlignment.Center },
	["top-right"]     = { anchor = Vector2.new(1, 0), scale = Vector2.new(1, 0),     base = Vector2.new(-16, 16),  hAlign = Enum.HorizontalAlignment.Right },
	["bottom-left"]   = { anchor = Vector2.new(0, 1), scale = Vector2.new(0, 1),     base = Vector2.new(16, -16),  hAlign = Enum.HorizontalAlignment.Left },
	["bottom-center"] = { anchor = Vector2.new(0.5, 1), scale = Vector2.new(0.5, 1), base = Vector2.new(0, -16),   hAlign = Enum.HorizontalAlignment.Center },
	["bottom-right"]  = { anchor = Vector2.new(1, 1), scale = Vector2.new(1, 1),     base = Vector2.new(-16, -16), hAlign = Enum.HorizontalAlignment.Right },
}
UI.ToastPositions = {"top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"}

function UI:SetToastPosition(where)
	local cfg = TOAST_ANCHORS[where]
	if not cfg then return end
	self._appearance.toastPos = where
	local ox = self._appearance.toastOffsetX or 0
	local oy = self._appearance.toastOffsetY or 0
	self.Toasts.AnchorPoint = cfg.anchor
	self.Toasts.Position = UDim2.new(cfg.scale.X, cfg.base.X + ox, cfg.scale.Y, cfg.base.Y + oy)
	self.ToastLayout.HorizontalAlignment = cfg.hAlign
	local top = where:find("top") ~= nil
	self.ToastLayout.VerticalAlignment = top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
end

function UI:SetToastOffset(ox, oy)
	self._appearance.toastOffsetX = ox or self._appearance.toastOffsetX
	self._appearance.toastOffsetY = oy or self._appearance.toastOffsetY
	self:SetToastPosition(self._appearance.toastPos)
end

function UI:RegisterKeybind(id, toggle)
	self._keybindToggles[id] = toggle
end

function UI:SetKeybind(id, keyCode)
	self._keybinds[id] = keyCode and keyCode.Name or nil
	local renderFn = self._keybindRenders and self._keybindRenders[id]
	if renderFn then renderFn() end
end

function UI:ClearKeybind(id)
	self._keybinds[id] = nil
	local renderFn = self._keybindRenders and self._keybindRenders[id]
	if renderFn then renderFn() end
end

function UI:ClearAllKeybinds()
	for id in pairs(self._keybinds) do
		self._keybinds[id] = nil
	end
	if self._keybindRenders then
		for _, renderFn in pairs(self._keybindRenders) do renderFn() end
	end
end

function UI:StartListening(id)
	self._keybindListening = id
	local renderFn = self._keybindRenders and self._keybindRenders[id]
	if renderFn then renderFn() end
end

function UI:Tab(name)
	local index = #self.Tabs + 1
	local btn = Button(self.TabList, "", {Name = "Tab_" .. name, LayoutOrder = index, Size = UDim2.new(1, 0, 0, 24)})
	local caret = Text(btn, ">", {Name = "Caret", Position = U(8, 0), Size = UDim2.new(0, 12, 1, 0), TextColor3 = T.accent, Visible = false})
	local label = Text(btn, name, {Name = "Label", Position = U(22, 0), Size = UDim2.new(1, -52, 1, 0), TextColor3 = T.mid})
	Text(btn, string.format("%02d", index), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = U(20, 24),
		TextSize = 10, TextColor3 = T.dim, TextXAlignment = RIGHT})

	local page = new("ScrollingFrame", {
		Name = "Page_" .. name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = T.lineHi, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = AUTO_Y, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, Parent = self.Content,
	})
	Pad(page, 8, 14, 12, 12)
	List(page, 2)

	local tab = setmetatable({Hub = self, Name = name, _btn = btn, Page = page, Caret = caret, _label = label, Order = 0}, Tab)
	btn.MouseEnter:Connect(function() if self.Active ~= tab then label.TextColor3 = T.text end end)
	btn.MouseLeave:Connect(function() if self.Active ~= tab then label.TextColor3 = T.mid end end)
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

	table.insert(self.Tabs, tab)
	if index == 1 then self:SelectTab(tab) end
	return tab
end

function UI:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		local on = t == tab
		t.Page.Visible = on
		t.Caret.Visible = on
		t._label.TextColor3 = on and T.accent or T.mid
		t._label.FontFace = on and FONT_M or FONT
		t._btn.BackgroundTransparency = on and 0 or 1
	end
	self.Active = tab
	self:_setPath(tab.Name)
	self.ModeLabel.Text = string.upper(tab.Name)
end

function UI:SetAccent(name)
	local preset = ACCENTS[name]
	if not preset then return end
	self._appearance.accent = name
	T.accent = preset.color
	HEX.accent = preset.hex
	fireAccentChange()
	for _, t in ipairs(self.Tabs) do
		t.Caret.TextColor3 = T.accent
	end
	if self.Active then self:SelectTab(self.Active) end
end

function UI:_writeLine(box, entry)
	self.LineCount = self.LineCount + 1
	local err = entry.level == "err"
	Text(box, '<font color="' .. HEX.dim .. '">' .. entry.time .. '  ' .. (err and "!" or ">") .. '</font>  ' .. escape(entry.text), {
		Name = "Line", LayoutOrder = self.LineCount, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y,
		TextWrapped = true, TextSize = 11, TextColor3 = err and T.white or T.text, TextYAlignment = Enum.TextYAlignment.Top,
	})
	local lines = {}
	for _, c in ipairs(box:GetChildren()) do
		if c.Name == "Line" then table.insert(lines, c) end
	end
	if #lines > MAX_LOG then
		table.sort(lines, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for i = 1, #lines - MAX_LOG do lines[i]:Destroy() end
	end
	task.defer(function()
		box.CanvasPosition = Vector2.new(0, math.max(0, box.AbsoluteCanvasSize.Y - box.AbsoluteWindowSize.Y))
	end)
end

function UI:Log(message, level)
	if self.Destroyed then return end
	local entry = {time = os.date("%H:%M:%S"), text = tostring(message), level = level or "info"}
	table.insert(self.History, entry)
	if #self.History > MAX_LOG then table.remove(self.History, 1) end
	for _, box in ipairs(self.Consoles) do self:_writeLine(box, entry) end
	self.StatusLabel.Text = entry.text
	self.StatusLabel.TextColor3 = entry.level == "err" and T.white or T.mid
end

function UI:Clear()
	self.History = {}
	for _, box in ipairs(self.Consoles) do
		for _, c in ipairs(box:GetChildren()) do
			if c.Name == "Line" then c:Destroy() end
		end
	end
	self.StatusLabel.Text = "cleared"
end

function UI:Notify(title, body, duration)
	if self.Destroyed or not self.NotificationsEnabled then return end
	duration = duration or 3
	self.ToastCount = self.ToastCount + 1

	local msg = body and body ~= "" and (title .. " — " .. body) or title

	local toast = Frame(self.Toasts, {Name = "Toast", LayoutOrder = self.ToastCount,
		Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.bg, BackgroundTransparency = 1, ClipsDescendants = true})
	local toastStroke = Stroke(toast, T.line)
	toastStroke.Transparency = 0.6
	Pad(toast, 0, 10, 0, 10)

	local accent = Frame(toast, {Name = "Accent", Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = T.accent})

	Text(toast, escape(msg), {Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		Position = U(8, 0), TextSize = 11, FontFace = FONT, TextColor3 = T.text, RichText = true})

	local bar = Frame(toast, {Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.accent, BackgroundTransparency = 0.5})
	tween(bar, {Size = UDim2.new(0, 0, 0, 1)}, TweenInfo.new(duration, Enum.EasingStyle.Linear))

	tween(toast, {BackgroundTransparency = 0.15}, TweenInfo.new(0.2, Enum.EasingStyle.Quart))

	task.delay(duration - 0.3, function()
		if not toast.Parent then return end
		tween(toast, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Quart))
		for _, child in ipairs(toast:GetDescendants()) do
			if child:IsA("TextLabel") then
				tween(child, {TextTransparency = 1}, TweenInfo.new(0.3))
			elseif child:IsA("Frame") then
				tween(child, {BackgroundTransparency = 1}, TweenInfo.new(0.3))
			elseif child:IsA("UIStroke") then
				tween(child, {Transparency = 1}, TweenInfo.new(0.3))
			end
		end
	end)
	task.delay(duration, function() if toast.Parent then toast:Destroy() end end)
end

function UI:RegisterConfig(key, state, refresh)
	self._configRegistry[key] = { state = state, refresh = refresh }
end

function UI:RegisterCleanup(fn)
	table.insert(self._cleanups, fn)
end

function UI:GetConfigSnapshot()
	local snap = {}
	for key, entry in pairs(self._configRegistry) do
		local copy = {}
		for k, v in pairs(entry.state) do
			if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "table" then
				copy[k] = v
			elseif type(v) == "table" then
				local inner = {}
				for ik, iv in pairs(v) do
					if type(iv) ~= "function" and type(iv) ~= "userdata" and type(iv) ~= "table" then
						inner[ik] = iv
					elseif type(iv) == "table" then
						local deep = {}
						for dk, dv in pairs(iv) do
							if type(dv) ~= "function" and type(dv) ~= "userdata" then
								deep[dk] = dv
							end
						end
						inner[ik] = deep
					end
				end
				copy[k] = inner
			end
		end
		snap[key] = copy
	end
	snap["_keybinds"] = {}
	for id, keyName in pairs(self._keybinds) do
		snap["_keybinds"][id] = keyName
	end
	return snap
end

function UI:ApplyConfig(snap)
	if snap["_keybinds"] then
		for id in pairs(self._keybinds) do
			self._keybinds[id] = nil
		end
		for id, kn in pairs(snap["_keybinds"]) do
			local ok, kc = pcall(function() return Enum.KeyCode[kn] end)
			if ok and kc then
				self._keybinds[id] = kn
			end
		end
		if self._keybindRenders then
			for _, renderFn in pairs(self._keybindRenders) do renderFn() end
		end
	end
	for key, saved in pairs(snap) do
		if key == "_keybinds" then continue end
		local entry = self._configRegistry[key]
		if entry then
			for k, v in pairs(saved) do
				if type(v) == "table" and type(entry.state[k]) == "table" then
					for ik, iv in pairs(v) do
						if type(iv) == "table" and type(entry.state[k][ik]) == "table" then
							for dk, dv in pairs(iv) do
								entry.state[k][ik][dk] = dv
							end
						else
							entry.state[k][ik] = iv
						end
					end
				else
					entry.state[k] = v
				end
			end
			if entry.refresh then pcall(entry.refresh) end
		end
	end
end

function UI:Unload()
	for _, fn in ipairs(self._cleanups) do pcall(fn) end
	self:Destroy()
end

function UI:Destroy()
	self.Destroyed = true
	for _, c in ipairs(self.Connections) do c:Disconnect() end
	self.Gui:Destroy()
end

---------------------------------------------------------------------------
-- WIDGETS
---------------------------------------------------------------------------
function Tab:_row(h)
	self.Order = self.Order + 1
	return Frame(self.Page, {Name = "Row", LayoutOrder = self.Order, Size = UDim2.new(1, 0, 0, h or ROW_H), BackgroundTransparency = 1})
end

function Tab:_hit(row)
	local b = Button(row, "", {Name = "Hit", Size = UDim2.fromScale(1, 1)})
	b.MouseEnter:Connect(function() tween(b, {BackgroundTransparency = 0.35}) end)
	b.MouseLeave:Connect(function() tween(b, {BackgroundTransparency = 1}) end)
	return b
end

function Tab:_safe(label, fn, ...)
	if not fn then return true end
	local ok, err = pcall(fn, ...)
	if not ok then self.Hub:Log(label .. ": " .. tostring(err), "err") end
	return ok
end

function Tab:_runnable(hit, label, callback)
	local tag = Text(hit, "[ run ]", {Name = "Tag", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = U(70, 16), TextXAlignment = RIGHT, TextColor3 = T.mid})
	hit.MouseEnter:Connect(function() tag.TextColor3 = T.white end)
	hit.MouseLeave:Connect(function() tag.TextColor3 = T.mid end)
	local busy = false
	hit.MouseButton1Click:Connect(function()
		if busy then return end
		busy = true
		tag.Text = "[ ... ]"
		local ok = self:_safe(label, callback)
		tag.Text = ok and "[ ok ]" or "[ err ]"
		if ok then self.Hub:Log("ran " .. label) end
		task.delay(1.1, function()
			if tag.Parent then tag.Text = "[ run ]" end
			busy = false
		end)
	end)
end

function Tab:Section(title)
	local row = self:_row(28)
	local s = "// " .. string.lower(title)
	local w = TextService:GetTextSize(s, 10, Enum.Font.RobotoMono, Vector2.new(1000, 100)).X
	Text(row, s, {Position = U(0, 10), Size = U(w + 2, 14), TextSize = 10, TextColor3 = T.dim})
	Rule(row, U(w + 10, 17), UDim2.new(1, -(w + 10), 0, 1))
end

function Tab:Label(text)
	local row = self:_row(0)
	row.AutomaticSize = AUTO_Y
	Pad(row, 4, 8, 6, 8)
	local l = Text(row, text, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, TextWrapped = true, TextSize = 11,
		TextColor3 = T.mid, RichText = true, TextYAlignment = Enum.TextYAlignment.Top})
	return {Set = function(_, t) l.Text = t end}
end

function Tab:KeyValue(key, value, callback)
	local row = self:_row(22)
	if callback then
		local hit = self:_hit(row)
		Text(hit, key, {Position = U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
		local v = Text(hit, tostring(value), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0),
			TextSize = 11, TextColor3 = T.text, TextXAlignment = RIGHT})
		hit.MouseButton1Click:Connect(function() self:_safe(key, callback) end)
		return {Set = function(_, val) v.Text = tostring(val) end, Remove = function() row:Destroy() end}
	end
	Text(row, key, {Position = U(8, 0), Size = UDim2.new(0.5, -8, 1, 0), TextSize = 11, TextColor3 = T.dim})
	local v = Text(row, tostring(value), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0),
		TextSize = 11, TextColor3 = T.text, TextXAlignment = RIGHT})
	return {Set = function(_, val) v.Text = tostring(val) end, Remove = function() row:Destroy() end}
end

function Tab:Button(label, callback)
	local hit = self:_hit(self:_row())
	Text(hit, "$", {Position = U(8, 0), Size = U(12, ROW_H), TextColor3 = T.dim})
	Text(hit, label, {Position = U(24, 0), Size = UDim2.new(1, -110, 1, 0)})
	self:_runnable(hit, label, callback)
end

function Tab:Script(name, description, callback)
	local row = self:_row(44)
	row:SetAttribute("SearchKey", string.lower(name .. " " .. (description or "")))
	local hit = self:_hit(row)
	Text(hit, name, {Position = U(8, 6), Size = UDim2.new(1, -100, 0, 16), FontFace = FONT_M, TextSize = 13, TextColor3 = T.white})
	Text(hit, description or "", {Position = U(8, 24), Size = UDim2.new(1, -100, 0, 14), TextSize = 10, TextColor3 = T.dim,
		TextTruncate = Enum.TextTruncate.AtEnd})
	Rule(row, UDim2.new(0, 8, 1, -1), UDim2.new(1, -16, 0, 1))
	self:_runnable(hit, name, callback)
	return row
end

function Tab:Toggle(label, default, callback, bindId)
	local Hub = self.Hub
	local state = default == true
	local hit = self:_hit(self:_row())
	local box = Text(hit, "", {Position = U(8, 0), Size = U(28, ROW_H), TextColor3 = T.white})
	local labelEnd = bindId and -152 or -100
	Text(hit, label, {Position = U(40, 0), Size = UDim2.new(1, labelEnd, 1, 0)})
	local val = Text(hit, "", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = U(40, ROW_H), TextXAlignment = RIGHT, TextSize = 11})
	local function render()
		box.Text = state and "[x]" or "[ ]"
		box.TextColor3 = state and T.accent or T.dim
		val.Text = state and "on" or "off"
		val.TextColor3 = state and T.accent or T.dim
	end
	local function set(v)
		state = v
		render()
		self:_safe(label, callback, state)
	end
	render()
	onAccentChange(render)
	local bindEaten = false
	hit.MouseButton1Click:Connect(function()
		if bindEaten then bindEaten = false; return end
		set(not state)
	end)

	if bindId then
		local bindBox = Button(hit, "", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -54, 0.5, 0),
			Size = U(46, 16),
			TextSize = 10,
			FontFace = FONT_M,
			TextColor3 = T.mid,
			BackgroundColor3 = T.raised,
			BackgroundTransparency = 0,
		})
		Stroke(bindBox, T.line)
		Hub._keybindRenders = Hub._keybindRenders or {}
		local function renderBind()
			if Hub._keybindListening == bindId then
				bindBox.Text = "..."
				bindBox.TextColor3 = T.accent
			else
				local k = Hub._keybinds[bindId]
				bindBox.Text = k or "none"
				bindBox.TextColor3 = k and T.text or T.dim
			end
		end
		Hub._keybindRenders[bindId] = renderBind
		renderBind()
		bindBox.MouseButton1Click:Connect(function()
			bindEaten = true
			Hub:StartListening(bindId)
		end)
		bindBox.MouseButton2Click:Connect(function()
			bindEaten = true
			Hub:ClearKeybind(bindId)
		end)
		Hub:RegisterKeybind(bindId, {Set = function(_, v) set(v == true) end, Get = function() return state end})
	end

	return {Set = function(_, v) set(v == true) end, Get = function() return state end}
end

function Tab:Slider(label, min, max, default, callback, opts)
	opts = opts or {}
	local step = opts.Step or 1
	local suffix = opts.Suffix or ""
	local value = math.clamp(default or min, min, max)

	local row = self:_row()
	local bg = Frame(row, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.raised, BackgroundTransparency = 1})
	Text(row, label, {Position = U(8, 0), Size = UDim2.new(1, -236, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd})
	local valueLabel = Text(row, "", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = U(46, ROW_H),
		TextXAlignment = RIGHT, TextColor3 = T.white})
	local bar = Button(row, "", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -58, 0.5, 0), Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = AUTO_X, RichText = true, TextColor3 = T.dim})

	local function fmt(v)
		if step < 1 then return string.format("%.2f", v) end
		return tostring(math.floor(v + 0.5))
	end
	local function render()
		local filled = math.floor((value - min) / (max - min) * BAR_CHARS + 0.5)
		bar.Text = '[<font color="' .. HEX.accent .. '">' .. string.rep("#", filled) .. '</font><font color="' .. HEX.faint .. '">'
			.. string.rep("-", BAR_CHARS - filled) .. '</font>]'
		valueLabel.Text = fmt(value) .. suffix
	end
	local function set(v, fire)
		v = math.clamp(min + math.floor((v - min) / step + 0.5) * step, min, max)
		if v == value and fire then return end
		value = v
		render()
		if fire then self:_safe(label, callback, value) end
	end
	local function setFromX(x)
		local size = bar.AbsoluteSize.X
		local cw = size / (BAR_CHARS + 2)
		local ratio = math.clamp((x - bar.AbsolutePosition.X - cw) / (size - 2 * cw), 0, 1)
		set(min + (max - min) * ratio, true)
	end

	local dragging = false
	bar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	self.Hub:_track(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then setFromX(input.Position.X) end
	end))
	self.Hub:_track(UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end))
	row.MouseEnter:Connect(function() tween(bg, {BackgroundTransparency = 0.35}) end)
	row.MouseLeave:Connect(function() tween(bg, {BackgroundTransparency = 1}) end)

	render()
	onAccentChange(render)
	return {Set = function(_, v) set(v, true) end, Get = function() return value end}
end

function Tab:Choice(label, options, default, callback)
	local index = table.find(options, default) or 1
	local row = self:_row()
	Text(row, label, {Position = U(8, 0), Size = UDim2.new(1, -200, 1, 0)})
	local right = Frame(row, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = AUTO_X, BackgroundTransparency = 1})
	List(right, 8, true)
	local function arrow(s, order)
		local b = Button(right, s, {LayoutOrder = order, Size = U(12, ROW_H), TextColor3 = T.dim})
		b.MouseEnter:Connect(function() b.TextColor3 = T.white end)
		b.MouseLeave:Connect(function() b.TextColor3 = T.dim end)
		return b
	end
	local prev = arrow("<", 1)
	local val = Button(right, "", {LayoutOrder = 2, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AUTO_X, FontFace = FONT_M, TextColor3 = T.white})
	local nxt = arrow(">", 3)

	local function shift(d)
		index = ((index - 1 + d) % #options) + 1
		val.Text = tostring(options[index])
		self:_safe(label, callback, options[index])
	end
	val.Text = tostring(options[index])
	prev.MouseButton1Click:Connect(function() shift(-1) end)
	nxt.MouseButton1Click:Connect(function() shift(1) end)
	val.MouseButton1Click:Connect(function() shift(1) end)
	return {
		Get = function() return options[index] end,
		Set = function(_, v) index = table.find(options, v) or index; shift(0) end,
	}
end

function Tab:Input(label, placeholder, callback, opts)
	opts = opts or {}
	local row = self:_row()
	Text(row, label, {Position = U(8, 0), Size = UDim2.new(0.4, -8, 1, 0)})
	local field = Frame(row, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.6, -8, 0, 20), BackgroundColor3 = T.field})
	local stroke = Stroke(field, T.line)
	Text(field, ">", {Position = U(6, 0), Size = U(10, 20), TextSize = 11, TextColor3 = T.dim})
	local box = new("TextBox", {
		Position = U(18, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = opts.Default or "",
		PlaceholderText = placeholder or "", PlaceholderColor3 = T.dim, TextColor3 = T.white, FontFace = FONT, TextSize = 11,
		TextXAlignment = LEFT, ClearTextOnFocus = false, ClipsDescendants = true, Parent = field,
	})
	box.Focused:Connect(function() stroke.Color = T.mid end)
	box.FocusLost:Connect(function(enter)
		stroke.Color = T.line
		if enter and not opts.Live then self:_safe(label, callback, box.Text) end
	end)
	if opts.Live then
		box:GetPropertyChangedSignal("Text"):Connect(function() self:_safe(label, callback, box.Text) end)
	end
	return {Get = function() return box.Text end, Set = function(_, t) box.Text = t end, Box = box}
end

function Tab:Search(placeholder)
	return self:Input("filter", placeholder or "name or keyword", function(q)
		q = string.lower(q)
		for _, child in ipairs(self.Page:GetChildren()) do
			local key = child:GetAttribute("SearchKey")
			if key then child.Visible = q == "" or string.find(key, q, 1, true) ~= nil end
		end
	end, {Live = true})
end

function Tab:Console(height)
	local row = self:_row(height or 200)
	local box = new("ScrollingFrame", {
		Name = "Console", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.field, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = T.lineHi, CanvasSize = UDim2.new(), AutomaticCanvasSize = AUTO_Y, Parent = row,
	})
	Stroke(box, T.line)
	Pad(box, 8, 10, 8, 10)
	List(box, 2)
	table.insert(self.Hub.Consoles, box)
	for _, entry in ipairs(self.Hub.History) do self.Hub:_writeLine(box, entry) end
	return box
end

UI.AccentList = ACCENT_LIST
return UI
