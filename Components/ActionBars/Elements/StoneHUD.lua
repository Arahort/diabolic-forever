local Addon, ns = ...
if not ns.IsForever then return end
local HUD = {}
ns.StoneHUD = HUD
local GetMedia = ns.API.GetMedia
local SOCKET_TEXTURE = "arahort-stone/utility-frame-double-gap"
local events = CreateFrame("Frame")
local function LeftDockOffset()
	return ns.db and ns.db.global.orbs.style == "succubus" and -70 or 0
end
local function RightDockOffset()
	if ns.db and ns.db.global.orbs.style == "stone-and-bronze" then return -35 end
	return ns.db and ns.db.global.orbs.style == "succubus" and (70 + (ns.db.char.orbs.succubusButtonsX or -65)) or 0
end
local function RightDockY()
	return ns.db and ns.db.global.orbs.style == "succubus" and (ns.db.char.orbs.succubusButtonsY or 0) or 0
end
HUD.IsActive = function()
	return ns.API.IsStoneStyle()
end
local function ClearPoints(frame)
	(frame.ClearAllPointsBase or frame.ClearAllPoints)(frame)
end
local function SetPoint(frame, ...)
	(frame.SetPointBase or frame.SetPoint)(frame, ...)
end
local function SetScale(frame, value)
	(frame.SetScaleBase or frame.SetScale)(frame, value)
end
local function LockSelection(frame, locked)
	local custom = ns.LibEditMode and ns.LibEditMode.frameSelections[frame]
	local selection = custom or frame.Selection
	if not selection then return end
	frame.__stoneSelectionLocked = locked or nil
	if not frame.__stoneSelectionHook then
		frame.__stoneSelectionHook = true
		selection:HookScript("OnShow", function(self)
			if frame.__stoneSelectionLocked then self:Hide() end
		end)
	end
	if locked then
		if custom then selection.isSelected = false end
		selection:Hide()
		frame:SetMovable(false)
	elseif custom and ns.LibEditMode.isEditing then
		local shown = pcall(selection.ShowHighlighted, selection)
		if not shown then selection:Show() end
	elseif not custom and EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
		selection:Show()
	end
end
HUD.UpdateSocketPositions = function(self)
	local player = self.player
	if not player then return end
	for index, orb in ipairs({ player.Health, player.Power }) do
		local socket = orb.StoneSocket
		socket:SetTexture(GetMedia(SOCKET_TEXTURE, "png"))
		socket:ClearAllPoints()
		if index == 1 then
			socket:SetPoint("TOPLEFT", orb, "TOP", -381 + LeftDockOffset(), 105)
		else
			socket:SetPoint("TOPLEFT", orb, "TOP", 83 + RightDockOffset(), 105 + RightDockY())
		end
		socket:SetShown(self:IsActive())
	end
	local front = player.Health.StoneSocketFront
	if front then
		local active = ns.db.global.orbs.style == "stone-and-bronze"
		if active then front:SetTexture(GetMedia("arahort-stone/utility-frame-front", "png")) end
		front:SetShown(active)
	end
end
HUD.PreparePlayer = function(self, player)
	self.player = player
	if not player.Health.StoneSocket then
		for index, orb in ipairs({ player.Health, player.Power }) do
			local socket = player.Artwork.Overlay:CreateTexture(nil, "OVERLAY", nil, 0)
			socket:SetTexture(GetMedia(SOCKET_TEXTURE, "png"))
			socket:SetSize(330, 330)
			if index == 2 then socket:SetTexCoord(1, 0, 0, 1) end
			orb.StoneSocket = socket
			if index == 1 then
				local front = player.Artwork.Overlay:CreateTexture(nil, "OVERLAY", nil, 2)
				front:SetAllPoints(socket)
				front:Hide()
				orb.StoneSocketFront = front
			end
		end
	end
	self:UpdateSocketPositions()
	self:RequestRefresh()
end
HUD.EnsureDocks = function(self)
	if not self.leftDock then
		-- Independent UIParent anchors keep secret unit-frame geometry out of menu hit tests.
		self.panelDocks = {}
		for index = 1, 2 do
			local dock = ns.API.SetUnitFramesObjectScale(CreateFrame("Frame", nil, UIParent))
			dock:SetSize(46, 46)
			if index == 1 then self.leftDock = dock else self.rightDock = dock end
			local panelDock = ns.API.SetUnitFramesObjectScale(CreateFrame("Frame", nil, UIParent))
			panelDock:SetSize(38, 38)
			self.panelDocks[index] = panelDock
		end
	end
	local scale = 330/512
	for index, origin in ipairs({ -821, 855 }) do
		local direction = index == 1 and 1 or -1
		local offset = index == 1 and LeftDockOffset() or RightDockOffset()
		local offsetY = index == 2 and RightDockY() or 0
		local dock = index == 1 and self.leftDock or self.rightDock
		dock:ClearAllPoints()
		dock:SetPoint("CENTER", UIParent, "BOTTOM", origin + offset + direction*52.4473*scale, -19+(512-441.404)*scale + offsetY)
		local panelDock = self.panelDocks[index]
		panelDock:ClearAllPoints()
		panelDock:SetPoint("CENTER", UIParent, "BOTTOM", origin + offset + direction*127.561*scale, -19+(512-441.404)*scale + offsetY)
	end
end
HUD.ApplyPanelToggles = function(self, bars)
	if not bars or not bars.ToggleButtons then return end
	local active = self:IsActive()
	self.panelOriginal = self.panelOriginal or {}
	for index, toggle in ipairs(bars.ToggleButtons) do
		if active then
			self:EnsureDocks()
			if not self.panelOriginal[toggle] then
				local original = { points = {}, width = toggle:GetWidth(), height = toggle:GetHeight(), textureWidth = toggle.texture:GetWidth(), textureHeight = toggle.texture:GetHeight() }
				for i = 1, toggle:GetNumPoints() do original.points[i] = { toggle:GetPoint(i) } end
				self.panelOriginal[toggle] = original
			end
			toggle:ClearAllPoints()
			toggle:SetPoint("CENTER", self.panelDocks[index], "CENTER", 0, 0)
			toggle:SetSize(38, 38)
			toggle.texture:SetSize(38, 38)
			toggle.texture:SetTexture(GetMedia("arahort-stone/panel-cross", "png"))
			toggle.texture:SetVertexColor(1, 1, 1, 1)
			toggle.texture:SetAlpha(1)
			toggle:SetAlpha(1)
			if not toggle.stoneCrossHighlight then
				local highlight = toggle:CreateTexture(nil, "OVERLAY", nil, 1)
				highlight:SetTexture(GetMedia("actionbutton-mask-circular"))
				highlight:SetAllPoints(toggle.texture)
				highlight:SetBlendMode("ADD")
				highlight:SetVertexColor(1, .88, .65)
				highlight:SetAlpha(.2)
				highlight:Hide()
				toggle.stoneCrossHighlight = highlight
				toggle:HookScript("OnEnter", function(button)
					button.stoneCrossHighlight:SetShown(self:IsActive())
				end)
				toggle:HookScript("OnLeave", function(button) button.stoneCrossHighlight:Hide() end)
				toggle:HookScript("OnHide", function(button) button.stoneCrossHighlight:Hide() end)
			end
		elseif self.panelOriginal[toggle] then
			local original = self.panelOriginal[toggle]
			self.panelOriginal[toggle] = nil
			toggle:ClearAllPoints()
			for _, point in ipairs(original.points) do toggle:SetPoint(unpack(point)) end
			toggle:SetSize(original.width, original.height)
			toggle.texture:SetSize(original.textureWidth, original.textureHeight)
			toggle.texture:SetTexture(GetMedia("button-toggle-plus"))
		end
		if toggle.stoneCrossHighlight then toggle.stoneCrossHighlight:SetShown(active and toggle.mouseOver or false) end
		if toggle.UpdateAlpha then toggle:UpdateAlpha() end
	end
end
HUD.ApplyMenu = function(self, menu)
	local toggle = menu and menu.toggle
	if not toggle or not toggle.texture then return end
	local active = self:IsActive()
	if active then
		self:EnsureDocks()
		toggle:ClearAllPoints()
		toggle:SetPoint("CENTER", self.leftDock, "CENTER", 0, 0)
		toggle:SetSize(46, 46)
		toggle.texture:SetSize(38, 38)
		toggle.texture:SetTexture(GetMedia("arahort-stone/menu-icon", "png"))
		toggle.texture:SetAlpha(.85)
		if not toggle.stoneHighlight then
			local highlight = toggle:CreateTexture(nil, "OVERLAY", nil, 1)
			highlight:SetTexture(GetMedia("actionbutton-mask-circular"))
			highlight:SetAllPoints(toggle.texture)
			highlight:SetBlendMode("ADD")
			highlight:SetAlpha(.12)
			highlight:Hide()
			toggle.stoneHighlight = highlight
		end
		LockSelection(toggle, true)
		menu.__stoneDocked = true
	elseif menu.__stoneDocked then
		menu.__stoneDocked = nil
		LockSelection(toggle, false)
		local point, x, y = menu:GetPosition()
		toggle:ClearAllPoints()
		toggle:SetPoint(point, UIParent, point, x, y)
		local factor = menu:GetButtonSize() / 34
		toggle:SetSize(80 * factor, 80 * factor)
		toggle.texture:SetSize(60 * factor, 60 * factor)
		toggle.texture:SetAlpha(1)
		toggle.texture:SetTexture(GetMedia("micromenu-toggle"))
	end
	if toggle.UpdateAlpha then toggle:UpdateAlpha() end
end
HUD.ApplyBag = function(self)
	local bar, button = BagsBar, MainMenuBarBackpackButton
	if not bar or not button or not button.__DiabolicIcon then return end
	local active = self:IsActive()
	if active then
		self:EnsureDocks()
		if not self.bagOriginal then
			self.bagOriginal = { points = {}, scale = bar:GetScale(), ignore = bar:IsIgnoringParentScale(), strata = bar:GetFrameStrata() }
			for i = 1, bar:GetNumPoints() do self.bagOriginal.points[i] = { bar:GetPoint(i) } end
		end
		bar:SetFrameStrata("MEDIUM")
		if bar.isSelected and EditModeManagerFrame then EditModeManagerFrame:ClearSelectedSystem() end
		LockSelection(bar, true)
		bar:SetIgnoreParentScale(false)
		SetScale(bar, ns.API.GetUnitFramesEffectiveScale())
		ClearPoints(bar)
		SetPoint(bar, "CENTER", self.rightDock, "CENTER", 0, 0)
		button.__DiabolicIcon:SetTexture(GetMedia("arahort-stone/bag-icon", "png"))
		button.__DiabolicBorder:Hide()
	elseif self.bagOriginal then
		local original = self.bagOriginal
		self.bagOriginal = nil
		bar:SetFrameStrata(original.strata)
		LockSelection(bar, false)
		bar:SetIgnoreParentScale(original.ignore)
		SetScale(bar, original.scale)
		ClearPoints(bar)
		local systemInfo = bar.systemInfo
		local anchor = systemInfo and systemInfo.anchorInfo
		if bar.IsInitialized and bar:IsInitialized() and anchor then
			-- Restore the current layout without changing Blizzard snapping or manager state.
			local scale = bar:GetScale()
			SetPoint(bar, anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX / scale, anchor.offsetY / scale)
			local anchor2 = systemInfo.anchorInfo2
			if anchor2 then
				SetPoint(bar, anchor2.point, anchor2.relativeTo, anchor2.relativePoint, anchor2.offsetX / scale, anchor2.offsetY / scale)
			end
		else
			for _, point in ipairs(original.points) do SetPoint(bar, unpack(point)) end
		end
		button.__DiabolicIcon:SetTexture([[Interface\Buttons\Button-Backpack-Up]])
		button.__DiabolicBorder:Show()
	end
	if not self.bagHooks then
		self.bagHooks = true
		for _, method in ipairs({ "SetPoint", "SetScale", "HighlightSystem", "SelectSystem" }) do
			if bar[method] then hooksecurefunc(bar, method, function()
				if self:IsActive() then self:RequestRefresh() end
			end) end
		end
	end
end
HUD.Refresh = function(self)
	if InCombatLockdown() then self.pending = true; return end
	if self.refreshing or not self.worldReady or not ns.db then return end
	self.refreshing = true
	self.pending = nil
	local actionBars = ns:GetModule("ActionBars", true)
	local menu = actionBars and actionBars:GetModule("MicroMenu", true)
	local bars = actionBars and actionBars:GetModule("Bars", true)
	if bars and bars.UpdateSidePanelLayout then bars:UpdateSidePanelLayout() end
	if menu and self:IsActive() and not ns.API.IsAddOnEnabled("ConsolePort") then
		if not menu:IsEnabled() then menu:Enable(); self.forcedMenu = true end
		if not menu.bar then menu:InitializeMicroMenu() end
	elseif menu and self.forcedMenu then
		self.forcedMenu = nil
		if not ns.db.global.micromenu.enableMicroMenu then menu:Disable() end
	end
	if menu then self:ApplyMenu(menu) end
	self:ApplyPanelToggles(bars)
	self:ApplyBag()
	self.refreshing = nil
end
HUD.RequestRefresh = function(self)
	if self.scheduled then return end
	self.scheduled = true
	C_Timer.After(0, function()
		self.scheduled = nil
		self:Refresh()
	end)
end
HUD.OnStyleChanged = function(self)
	if EventRegistry then EventRegistry:TriggerEvent("EditModeExternal.hideDialog") end
	local bars = ns:GetModule("ActionBars", true)
	local bags = bars and bars:GetModule("BagButton", true)
	if bags and bags:IsEnabled() then bags:SetupBagsBar() end
	self:RequestRefresh()
end
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then HUD.worldReady = true end
	HUD:RequestRefresh()
end)
ns.RegisterCallback(HUD, "OrbStyle_Updated", "OnStyleChanged")
ns.RegisterCallback(HUD, "UnitFrames_Scale_Updated", "RequestRefresh")
ns:RegisterChatCommand("succubusbuttons", function(command)
	local L = ns.L
	if not ns.db or ns.db.global.orbs.style ~= "succubus" or not HUD.player then
		print(L["SuccubusButtonsUnavailable"])
		return
	end
	command = string.lower(string.match(command or "", "^%s*(.-)%s*$"))
	local db = ns.db.char.orbs
	if command == "" then
		print(string.format(L["SuccubusButtonsCurrent"], db.succubusButtonsX or -65, db.succubusButtonsY or 0))
		print(L["SuccubusButtonsUsage"])
		return
	end
	local x, y
	if command == "reset" then
		x, y = -65, 0
	else
		local first, second = string.match(command, "^(%S+)%s+(%S+)$")
		x = first and tonumber((string.gsub(first, ",", ".")))
		y = second and tonumber((string.gsub(second, ",", ".")))
		if not x or not y or x ~= x or y ~= y or math.abs(x) > 200 or math.abs(y) > 200 then
			print(L["SuccubusButtonsUsage"])
			return
		end
	end
	if InCombatLockdown() then
		print(L["SuccubusButtonsCombat"])
		return
	end
	db.succubusButtonsX, db.succubusButtonsY = x, y
	HUD:UpdateSocketPositions()
	HUD:EnsureDocks()
	print(string.format(L["SuccubusButtonsCurrent"], x, y))
end)
