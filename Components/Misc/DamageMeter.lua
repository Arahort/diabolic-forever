local Addon, ns = ...
if not ns.IsForever then return end
local Skin = ns:NewModule("DamageMeterSkin", "AceEvent-3.0")
local windows, entries = {}, setmetatable({}, { __mode = "k" })
local FONT_SIZE, TEXT_PADDING = 12, 1.75
local function Palette()
	local style = ns.db.global.orbs.style
	if style == "legacy" then return "arahort-stone/", .68, .70, .73 end
	if style == "diablo2" then return "arahort-stone-dark/", 1, .91, .78 end
	return "arahort-stone/", 1, 1, 1
end
local function Asset(name)
	local folder = Palette()
	return ns.API.GetMedia(folder..name, "png")
end
local function SetTint(texture)
	local _, r, g, b = Palette()
	texture:SetVertexColor(r, g, b)
end
local function CreateChrome(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel(parent:GetFrameLevel())
	frame:EnableMouse(false)
	local size, width, height = 56, 1808, 716
	local background = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetColorTexture(.018, .016, .018, .88)
	local xs, ys = { 0, 180, width - 180, width }, { 0, 180, height - 180, height }
	local textures = {}
	for row = 1, 3 do
		for column = 1, 3 do
			if row ~= 2 or column ~= 2 then
				local texture = frame:CreateTexture(nil, "ARTWORK")
				local left, right = xs[column], xs[column + 1]
				-- The central crest is separate, so the plain top rail can stretch.
				if row == 1 and column == 2 then right = 500 end
				texture:SetTexCoord(left / width, right / width, ys[row] / height, ys[row + 1] / height)
				local vertical = row == 1 and "TOP" or "BOTTOM"
				local horizontal = column == 1 and "LEFT" or "RIGHT"
				if row == 2 then
					texture:SetWidth(size)
					texture:SetPoint("TOP"..horizontal, frame, "TOP"..horizontal, 0, -size)
					texture:SetPoint("BOTTOM"..horizontal, frame, "BOTTOM"..horizontal, 0, size)
				elseif column == 2 then
					texture:SetHeight(size)
					texture:SetPoint(vertical.."LEFT", frame, vertical.."LEFT", size, 0)
					texture:SetPoint(vertical.."RIGHT", frame, vertical.."RIGHT", -size, 0)
				else
					texture:SetSize(size, size)
					texture:SetPoint(vertical..horizontal, frame, vertical..horizontal)
				end
				textures[#textures + 1] = { texture = texture, coords = { left / width, right / width, ys[row] / height, ys[row + 1] / height } }
			end
		end
	end
	local crest = frame:CreateTexture(nil, "OVERLAY")
	crest:SetSize(size * 280 / 180, size * 134 / 180)
	crest:SetPoint("TOP", frame, "TOP", 0, 0)
	return { frame = frame, textures = textures, crest = crest, background = background }
end
local function UpdateChrome(chrome)
	for _, piece in ipairs(chrome.textures) do
		piece.texture:SetTexture(Asset("meter-window-v3"), "CLAMP", "CLAMP")
		piece.texture:SetTexCoord(unpack(piece.coords))
		SetTint(piece.texture)
	end
	chrome.crest:SetTexture(Asset("meter-crest-v3"))
	SetTint(chrome.crest)
end
local function CreateBorder(parent, anchor)
	local border = CreateFrame("Frame", nil, parent)
	border:SetFrameLevel(parent:GetFrameLevel() + 1)
	border:EnableMouse(false)
	local well = CreateFrame("Frame", nil, border)
	well:SetPoint("TOPLEFT", anchor, "TOPLEFT", 3, -2)
	well:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -3, 2)
	return ns.CryptGroup.CreateBarBorder(well, border, 3, 2)
end
local function UpdateBorder(pieces)
	for _, piece in ipairs(pieces) do
		piece.texture:SetTexture(Asset("meter-row-v4"), "CLAMP", "CLAMP")
		piece.texture:SetTexCoord(unpack(piece.coords))
		SetTint(piece.texture)
		piece.texture:Show()
	end
end
Skin.SkinEntry = function(self, entry, window)
	if not entry.StatusBar then return end
	local state = entries[entry]
	if not state then
		state = { window = window, border = CreateBorder(entry.StatusBar, entry.StatusBar) }
		if entry.Icon then state.iconBorder = CreateBorder(entry.Icon, entry.Icon) end
		entries[entry] = state
	end
	state.window = window
	local height = window:GetBarHeight()
	if entry.Icon then entry.Icon:SetSize(height, height) end
	local bar = entry.StatusBar
	bar:GetStatusBarTexture():SetTexture(Asset("meter-fill"))
	if bar.Background then
		bar.Background:SetTexture(ns.API.GetMedia("blank"))
		bar.Background:SetVertexColor(.025, .025, .028)
	end
	if bar.BackgroundEdge then bar.BackgroundEdge:SetAlpha(0) end
	UpdateBorder(state.border)
	if state.iconBorder then UpdateBorder(state.iconBorder) end
	local font = ns.API.GetFont(FONT_SIZE, true)
	for _, text in ipairs({ bar.Name, bar.Value }) do
		text:SetFontObject(font)
		text:SetTextScale(window:GetTextScale())
		text:SetJustifyV("MIDDLE")
		text:SetWordWrap(false)
		text:SetTextColor(.94, .91, .84)
	end
	-- Insets use only fixed geometry. Never measure secret names, numbers or bar fill.
	if entry:GetStyle() == Enum.DamageMeterStyle.Thin then
		bar.Name:SetPoint("TOP", entry, "TOP", 0, -TEXT_PADDING)
		bar.Value:SetPoint("TOP", entry, "TOP", 0, -TEXT_PADDING)
	else
		for _, text in ipairs({ bar.Name, bar.Value }) do
			text:SetPoint("TOP", entry, "TOP", 0, -TEXT_PADDING)
			text:SetPoint("BOTTOM", entry, "BOTTOM", 0, TEXT_PADDING)
		end
	end
end
Skin.SkinRows = function(self, state)
	state.scrollBox:ForEachFrame(function(entry) self:SkinEntry(entry, state.window) end)
	if state.window.GetLocalPlayerEntry then
		local entry = state.window:GetLocalPlayerEntry()
		if entry then self:SkinEntry(entry, state.window) end
	end
end
Skin.UpdateWindow = function(self, state)
	local window = state.window
	local chromeLevel = window:GetFrameLevel()
	state.chrome.frame:SetFrameLevel(chromeLevel)
	for _, button in ipairs({ window.DamageMeterTypeDropdown, window.SessionDropdown, window.SettingsDropdown, window.MinimizeButton }) do
		if button:GetFrameLevel() <= chromeLevel then button:SetFrameLevel(chromeLevel + 1) end
	end
	local anchor = state.source and window:GetBackground() or window
	local collapsed = not state.source and window:IsMinimized()
	state.chrome.frame:SetScale(collapsed and .5 or 1)
	state.chrome.frame:ClearAllPoints()
	state.chrome.frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", -18, collapsed and 34 or 24)
	state.chrome.frame:SetPoint("BOTTOMRIGHT", collapsed and window.Header or anchor, "BOTTOMRIGHT", 18, collapsed and -22 or -18)
	state.chrome.background:ClearAllPoints()
	state.chrome.background:SetPoint("TOPLEFT", window.Header or anchor, "TOPLEFT", -4, 4)
	state.chrome.background:SetPoint("BOTTOMRIGHT", collapsed and window.Header or anchor, "BOTTOMRIGHT", 4, -4)
	state.chrome.background:Show()
	UpdateChrome(state.chrome)
	local background = window:GetBackground()
	if background then
		background:SetTexture(ns.API.GetMedia("blank"))
		background:SetVertexColor(.025, .025, .028)
	end
	if window.Header then
		window.Header:SetTexture(Asset("meter-header"))
		SetTint(window.Header)
	end
	self:SkinRows(state)
end
Skin.SkinWindow = function(self, window, source)
	if not window or windows[window] then return end
	local scrollBox = window:GetScrollBox()
	if not scrollBox or not scrollBox:GetView() then return end
	local state = { window = window, source = source, scrollBox = scrollBox, chrome = CreateChrome(window) }
	windows[window] = state
	-- Native ScrollBox owns row geometry, caches and initializers, including in combat.
	-- Skin pooled rows only after its update; never call native layout/data setters.
	hooksecurefunc(scrollBox, "Update", function() self:SkinRows(state) end)
	for _, method in ipairs({ "OnTextScaleChanged", "OnBarHeightChanged", "OnShowBarIconsChanged", "OnBackgroundAlphaChanged" }) do
		if window[method] then hooksecurefunc(window, method, function() self:SkinRows(state) end) end
	end
	if window.ShowLocalPlayerEntry then
		hooksecurefunc(window, "ShowLocalPlayerEntry", function() self:SkinEntry(window:GetLocalPlayerEntry(), window) end)
	end
	hooksecurefunc(window, "OnStyleChanged", function() self:UpdateWindow(state) end)
	if window.SetMinimized then hooksecurefunc(window, "SetMinimized", function() self:UpdateWindow(state) end) end
	window:HookScript("OnShow", function() self:UpdateWindow(state) end)
	self:UpdateWindow(state)
	if not source and window.GetSourceWindow then self:SkinWindow(window:GetSourceWindow(), true) end
end
Skin.Refresh = function(self)
	for _, state in pairs(windows) do self:UpdateWindow(state) end
end
Skin.Install = function(self)
	if self.installed or not DamageMeter then return end
	self.installed = true
	hooksecurefunc(DamageMeter, "SetupSessionWindow", function()
		DamageMeter:ForEachSessionWindow(function(window) self:SkinWindow(window) end)
	end)
	DamageMeter:ForEachSessionWindow(function(window) self:SkinWindow(window) end)
end
Skin.OnInitialize = function(self)
	if not ns.db.global.damageMeter.useCustomStyle then return end
	ns.RegisterCallback(self, "OrbStyle_Updated", "Refresh")
	EventUtil.ContinueOnAddOnLoaded("Blizzard_DamageMeter", function() self:Install() end)
end
