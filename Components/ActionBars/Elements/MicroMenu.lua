local Addon, ns = ...
local ActionBars = ns:GetModule("ActionBars")
local MicroMenu = ActionBars:NewModule("MicroMenu", "LibMoreEvents-1.0", "AceHook-3.0")

-- Lua API
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local math_max = math.max
local math_floor = math.floor

-- WoW API
local C_PetBattles = C_PetBattles
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver

-- Addon API
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetUnitFramesObjectScale
local IsAddOnEnabled = ns.API.IsAddOnEnabled

-- Constants
local TOGGLE_SIZE = 80
local BUTTON_SPACING = 2
local PADDING_H = 8
local PADDING_V = 14
local FOREVER_VISIBILITY = "[petbattle][possessbar][overridebar][vehicleui][@vehicle,exists]hide;show"

MicroMenu.GetButtonSize = function(self)
	local db = ns.db
	return (db and db.global.micromenu.buttonSize) or 34
end

MicroMenu.GetPosition = function(self)
	local db = ns.db
	local point = (db and db.char.micromenu.positionPoint) or "BOTTOMRIGHT"
	local posX = (db and db.char.micromenu.positionX) or -11
	local posY = (db and db.char.micromenu.positionY) or 11
	return point, posX, posY
end

MicroMenu.GetToggleAlpha = function(self)
	local db = ns.db
	return (db and db.global.micromenu.toggleAlpha) or 0.3
end
MicroMenu.ApplyEditModeState = function(self, editing)
	self.pendingEditModeState, self.hasPendingEditModeState = editing, true
	if self.bar then self.bar.inEditMode = editing or nil end
	if InCombatLockdown() or not self.toggle or not self.bar then return end
	if editing then self.bar:Show() else self.bar:Hide() end
	self.hasPendingEditModeState = nil
end

MicroMenu.ResizeButton = function(self, btn, targetSize)
	local nw, nh = btn.nativeWidth, btn.nativeHeight
	if (not nw or nw == 0) then
		nw, nh = 32, 40
	end
	local ratio = nw / nh
	local ew = math_floor(targetSize * ratio + 0.5)
	local eh = targetSize
	btn:SetScale(1)
	btn:SetSize(ew, eh)
	return ew, eh
end

MicroMenu.LayoutForeverMicroMenu = function(self)
	if self.foreverMenuDisabled or self.__foreverLayoutUpdating or not self.bar or not self.nativeMenu then return end
	if InCombatLockdown() then self.needsLayout = true; return end
	self.__foreverLayoutUpdating = true
	local native = self.nativeMenu
	if native:GetParent() ~= self.bar then native:SetParent(self.bar) end
	native:SetFrameStrata("FULLSCREEN_DIALOG")
	native:SetFrameLevel(self.bar:GetFrameLevel() + 1)
	-- Native Edit Mode scale must not shrink icons inside an unscaled custom wrapper.
	native:SetScale(1)
	-- The secure toggle shows prepared geometry; native OnShow must not reanchor in combat.
	native.skipLayoutOnShow = true
	native:ClearAllPoints()
	native:SetPoint("BOTTOM", self.bar, "BOTTOM", 0, PADDING_V)
	native.isHorizontal = false
	native.isStacked = false
	-- Vertical grids count rows per column, unlike horizontal grids' columns per row.
	native.stride = math_max(#native:GetLayoutChildren(), 1)
	native.layoutFramesGoingRight = true
	native.layoutFramesGoingUp = true
	native.childXPadding = 0
	native.childYPadding = BUTTON_SPACING
	if native.BorderArt then native.BorderArt:SetAlpha(0) end
	if native.BackgroundArt then native.BackgroundArt:SetAlpha(0) end
	local size = self:GetButtonSize()
	for _, button in ipairs(self.bar.buttons) do self:ResizeButton(button, size) end
	-- Keep every child in the native grid, including native hidden/help buttons.
	native:Layout()
	self.bar:SetSize(size + PADDING_H * 2, native:GetHeight() + PADDING_V * 2)
	if self.toggle then
		local scale = size / 34
		self.toggle:SetSize(TOGGLE_SIZE * scale, TOGGLE_SIZE * scale)
		if self.toggle.texture then self.toggle.texture:SetSize(60 * scale, 60 * scale) end
	end
	self.__foreverLayoutUpdating = nil
end
MicroMenu.UpdateLayout = function(self)
	if ns.IsForever then return self:LayoutForeverMicroMenu() end
	if (InCombatLockdown()) then
		self.needsLayout = true
		return
	end
	if (not self.bar or not self.bar.buttons) then return end
	local btnSize = self:GetButtonSize()
	local totalHeight = PADDING_V
	local visibleCount = 0
	for i, btn in ipairs(self.bar.buttons) do
		if (btn:IsShown()) then
			local ew, eh = self:ResizeButton(btn, btnSize)
			btn:ClearAllPoints()
			btn:SetPoint("BOTTOM", self.bar, "BOTTOM", 0, totalHeight)
			totalHeight = totalHeight + eh + BUTTON_SPACING
			visibleCount = visibleCount + 1
		end
	end
	if (visibleCount > 0) then
		totalHeight = totalHeight - BUTTON_SPACING
	end
	totalHeight = totalHeight + PADDING_V
	local barWidth = btnSize + PADDING_H * 2
	self.bar:SetSize(barWidth, totalHeight)
	-- Resize toggle proportionally to button size
	if (self.toggle) then
		local toggleScale = btnSize / 34
		self.toggle:SetSize(TOGGLE_SIZE * toggleScale, TOGGLE_SIZE * toggleScale)
		if (self.toggle.texture) then
			self.toggle.texture:SetSize(60 * toggleScale, 60 * toggleScale)
		end
	end
end

MicroMenu.InitializeMicroMenu = function(self)
	if (self.bar) then return end
	if ns.IsForever and InCombatLockdown() then
		-- PEW's deferred callback can run after combat lockdown has already begun.
		-- Do not publish half-created controls with missing secure frame handles.
		self.needsInitialization = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
		return
	end
	self.needsInitialization = nil
	-- Discover micro buttons dynamically from Blizzard's MicroMenu frame
	local microButtons = {}
	if (_G.MicroMenu) then
		for _, child in pairs({ _G.MicroMenu:GetChildren() }) do
			if (child:IsObjectType("Button") and child:GetName()
				and child:GetName():find("MicroButton")) then
				table_insert(microButtons, child)
			end
		end
	end
	if ns.IsForever then
		-- Preserve Camelot's Spellbook/Talent/Legacy order without replacing clicks.
		table.sort(microButtons, function(a, b)
			local ai = a.layoutIndex or math.huge
			local bi = b.layoutIndex or math.huge
			if ai ~= bi then return ai < bi end
			return a:GetName() < b:GetName()
		end)
	end
	if (#microButtons == 0) then
		return
	end
	-- Menu container - FULLSCREEN_DIALOG so GameTooltip (TOOLTIP strata) renders on top
	local bar = CreateFrame("Frame", ns.Prefix.."MicroMenu", UIParent, "SecureHandlerStateTemplate")
	bar:SetFrameStrata("FULLSCREEN_DIALOG")
	bar:SetClampedToScreen(true)
	if ns.IsForever then
		-- Native microbutton hooks can query chained centers during each reparent.
		bar:SetSize(1, 1)
		bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	bar:Hide()
	self.bar = bar
	-- Dark backdrop with overshoot for border-tooltip edge art
	local backdrop = CreateFrame("Frame", nil, bar, ns.BackdropTemplate)
	backdrop:SetFrameLevel(bar:GetFrameLevel())
	backdrop:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeSize = 32, edgeFile = GetMedia("border-tooltip"),
		tile = true,
		insets = { left = 8, right = 8, top = 16, bottom = 16 }
	})
	backdrop:SetBackdropColor(.05, .05, .05, .85)
	backdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -6, 6)
	backdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
	bar.backdrop = backdrop
	-- Reparent and resize micro buttons vertically inside our container
	bar.buttons = {}
	local btnSize = self:GetButtonSize()
	local totalHeight = PADDING_V
	for i, btn in ipairs(microButtons) do
		-- Save native dimensions before any modifications
		btn.nativeWidth = btn:GetWidth()
		btn.nativeHeight = btn:GetHeight()
		-- Reparent to our bar
		if not ns.IsForever then btn:SetParent(bar) end
		btn:SetHitRectInsets(0, 0, 0, 0)
		btn:SetFrameLevel(bar:GetFrameLevel() + 2)
		-- Strip all decorations, keep only the icon
		for _, region in pairs({ btn:GetRegions() }) do
			if (region:IsObjectType("Texture")) then
				local layer = region:GetDrawLayer()
				if (layer == "BACKGROUND" or layer == "BORDER") then
					region:SetAlpha(0)
				end
			end
		end
		if (btn.FlashBorder) then btn.FlashBorder:SetAlpha(0) end
		if (btn.FlashContent) then btn.FlashContent:SetAlpha(0) end
		if (btn.FlashTexture) then btn.FlashTexture:SetAlpha(0) end
		if (btn.Background) then btn.Background:SetAlpha(0) end
		if (btn.Highlight) then btn.Highlight:SetAlpha(0) end
		btn:SetAlpha(1)
		if not ns.IsForever then btn:Show() end
		-- Resize to target size preserving aspect ratio
		local ew, eh = self:ResizeButton(btn, btnSize)
		if not ns.IsForever then
			btn:ClearAllPoints()
			btn:SetPoint("BOTTOM", bar, "BOTTOM", 0, totalHeight)
		end
		totalHeight = totalHeight + eh + BUTTON_SPACING
		bar.buttons[#bar.buttons + 1] = btn
	end
	totalHeight = totalHeight - BUTTON_SPACING + PADDING_V
	-- Size the bar
	local barWidth = btnSize + PADDING_H * 2
	bar:SetSize(barWidth, totalHeight)
	-- Toggle button
	local posPoint, posX, posY = self:GetPosition()
	local toggleTemplate = ns.IsForever and "SecureHandlerClickTemplate,SecureHandlerStateTemplate" or "SecureHandlerClickTemplate"
	local toggle = SetObjectScale(CreateFrame("CheckButton", ns.Prefix.."MicroMenuToggle", UIParent, toggleTemplate))
	toggle:SetFrameStrata("HIGH")
	toggle:RegisterForClicks("AnyUp")
	toggle:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
	toggle:SetPoint(posPoint, UIParent, posPoint, posX, posY)
	self.toggle = toggle
	-- Anchor menu above toggle
	if ns.IsForever then bar:ClearAllPoints() end
	bar:SetPoint("BOTTOM", toggle, "TOP", 0, -4)
	if ns.IsForever then
		self.nativeMenu = _G.MicroMenu
		local native = self.nativeMenu
		self.nativeMenuOriginal = {
			parent = native:GetParent(), points = {}, isHorizontal = native.isHorizontal,
			isStacked = native.isStacked, stride = native.stride,
			layoutFramesGoingRight = native.layoutFramesGoingRight, layoutFramesGoingUp = native.layoutFramesGoingUp,
			childXPadding = native.childXPadding, childYPadding = native.childYPadding,
			strata = native:GetFrameStrata(), level = native:GetFrameLevel(), scale = native:GetScale(), skipLayoutOnShow = native.skipLayoutOnShow,
			borderAlpha = native.BorderArt and native.BorderArt:GetAlpha(),
			backgroundAlpha = native.BackgroundArt and native.BackgroundArt:GetAlpha()
		}
		for index = 1, native:GetNumPoints() do
			self.nativeMenuOriginal.points[index] = { native:GetPoint(index) }
		end
		self:LayoutForeverMicroMenu()
		self:SecureHook(self.nativeMenu, "Layout", "UpdateLayout")
		if self.nativeMenu.UpdateScale then self:SecureHook(self.nativeMenu, "UpdateScale", "UpdateLayout") end
	end
	-- Frame references for secure handler
	toggle:SetFrameRef("Bar", bar)
	if ns.IsForever then
		toggle:Execute([[self:SetAttribute("diabolic-menu-ready", self:GetFrameRef("Bar") ~= nil)]])
	end
	-- Secure onclick - toggles menu visibility (works in combat)
	-- Note: UpdateTexture is called via HookScript on bar OnShow/OnHide
	toggle:SetAttribute("_onclick", [[
		local bar = self:GetFrameRef("Bar")
		if (bar:IsShown()) then
			bar:Hide()
		else
			bar:Show()
		end
	]])
	toggle:HookScript("OnClick", function()
		if ns.ForeverDiagnostics then ns.ForeverDiagnostics:Record("micro-click") end
	end)
	-- Toggle texture
	local texture = toggle:CreateTexture(nil, "ARTWORK", nil, 0)
	texture:SetSize(60, 60)
	texture:SetPoint("CENTER")
	texture:SetTexture(GetMedia("micromenu-toggle"))
	toggle.texture = texture
	-- Methods
	toggle.UpdateTexture = function(self)
		-- Icon stays the same, just update alpha
		self:UpdateAlpha()
	end
	toggle.UpdateAlpha = function(self)
		if (self.mouseOver) or (bar:IsShown()) then
			self:SetAlpha(1)
		else
			self:SetAlpha(MicroMenu:GetToggleAlpha())
		end
	end
	toggle.OnEnter = function(self)
		self.mouseOver = true
		self:UpdateAlpha()
	end
	toggle.OnLeave = function(self)
		self.mouseOver = nil
		self:UpdateAlpha()
	end
	toggle:SetScript("OnEnter", toggle.OnEnter)
	toggle:SetScript("OnLeave", toggle.OnLeave)
	-- Visibility driver - hide during pet battle / vehicle
	-- Note: UpdateTexture is called via HookScript on toggle OnShow
	toggle:SetAttribute("_onstate-vis", [[
		if (not newstate) then
			return
		end
		if (newstate == "hide") then
			self:Hide()
			self:GetFrameRef("Bar"):Hide()
		else
			self:Show()
		end
	]])
	RegisterStateDriver(toggle, ns.IsForever and "vis" or "state-vis", FOREVER_VISIBILITY)
	-- Key binding integration: map the Bindings.xml key directly to the toggle button via C-level
	local bindingOwner = CreateFrame("Frame")
	self.bindingOwner = bindingOwner
	local function UpdateMicroMenuBinding()
		if (InCombatLockdown()) then return end
		ClearOverrideBindings(bindingOwner)
		local key1, key2 = GetBindingKey("DIABOLICUI3_TOGGLE_MICRO_MENU")
		local name = toggle:GetName()
		if (key1) then SetOverrideBindingClick(bindingOwner, false, key1, name, "LeftButton") end
		if (key2) then SetOverrideBindingClick(bindingOwner, false, key2, name, "LeftButton") end
	end
	bindingOwner:RegisterEvent("UPDATE_BINDINGS")
	bindingOwner:RegisterEvent("PLAYER_ENTERING_WORLD")
	bindingOwner:SetScript("OnEvent", UpdateMicroMenuBinding)
	self.UpdateToggleBindings = UpdateMicroMenuBinding
	UpdateMicroMenuBinding()
	-- Auto-hide: close menu when mouse leaves for 3 seconds
	local AUTO_HIDE_DELAY = 3
	local hideTimer = 0
	local function IsMouseOverWidget(widget)
		if (not widget:IsVisible()) then return false end
		local left, bottom, width, height = widget:GetRect()
		if (not left) then return false end
		local scale = widget:GetEffectiveScale()
		local x, y = GetCursorPosition()
		x, y = x / scale, y / scale
		return (x >= left and x <= left + width and y >= bottom and y <= bottom + height)
	end
	bar:SetScript("OnUpdate", function(self, elapsed)
		if (not self:IsShown()) then return end
		if (self.inEditMode) then return end
		if (IsMouseOverWidget(self) or IsMouseOverWidget(toggle)) then
			hideTimer = 0
		else
			hideTimer = hideTimer + elapsed
			if (hideTimer >= AUTO_HIDE_DELAY) then
				hideTimer = 0
				if (not InCombatLockdown()) then
					self:Hide()
				end
			end
		end
	end)
	-- Sync texture when menu is hidden externally
	bar:HookScript("OnHide", function() toggle:UpdateTexture(); hideTimer = 0 end)
	bar:HookScript("OnShow", function() toggle:UpdateTexture(); hideTimer = 0 end)
	-- Initial state
	toggle:UpdateAlpha()
	-- Deferred relayout: Blizzard may hide some buttons after init (e.g. HelpMicroButton)
	C_Timer.After(0.5, function() self:UpdateLayout() end)
	-- Hook Blizzard's reparenting to reclaim buttons
	if (_G.MicroMenu) then
		self:SecureHook(_G.MicroMenu, "SetParent", "DeferReclaimButtons")
	end
	if (C_PetBattles) then
		self:RegisterEvent("PET_BATTLE_CLOSE", "DeferReclaimButtons")
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
	ns.RegisterCallback(self, "MicroMenu_Settings_Updated", "OnSettingsUpdated")
	-- EditMode integration
	local LibEditMode = ns.LibEditMode
	if (LibEditMode and LibEditMode.AddFrame) then
		local L = ns.L
		toggle.editModeName = "Diabolic: Micro Menu"
		LibEditMode:AddFrame(toggle, function(frame, layoutName, point, x, y)
			if (InCombatLockdown()) then return end
			local db = ns.db.char.micromenu
			db.positionPoint = point
			db.positionX = x
			db.positionY = y
		end, {point = "BOTTOMRIGHT", x = -11, y = 11})
		-- The shared template defaults to MEDIUM, but this toggle is HIGH.
		-- Put the selection above it instead of disabling a protected button's mouse.
		local selection = LibEditMode.frameSelections[toggle]
		selection:SetFrameStrata(toggle:GetFrameStrata())
		selection:SetFrameLevel(math_max(selection:GetFrameLevel(), toggle:GetFrameLevel() + 1))
		LibEditMode:RegisterCallback("enter", function()
			self:ApplyEditModeState(true)
		end)
		LibEditMode:RegisterCallback("exit", function()
			self:ApplyEditModeState(false)
		end)
		LibEditMode:AddFrameSettings(toggle, {
			{
				kind = LibEditMode.SettingType.Slider,
				name = L["MicroMenuButtonSize"],
				desc = L["MicroMenuButtonSizeDesc"],
				default = 34,
				minValue = 20,
				maxValue = 50,
				valueStep = 1,
				formatter = function(value) return tostring(math_floor(value)) end,
				get = function() return ns.db.global.micromenu.buttonSize or 34 end,
				set = function(layoutName, value)
					ns.db.global.micromenu.buttonSize = value
					MicroMenu:UpdateLayout()
				end,
			},
			{
				kind = LibEditMode.SettingType.Slider,
				name = L["MicroMenuToggleAlpha"],
				desc = L["MicroMenuToggleAlphaDesc"],
				default = 0.3,
				minValue = 0.1,
				maxValue = 1.0,
				valueStep = 0.1,
				formatter = function(value) return string.format("%.1f", value) end,
				get = function() return ns.db.global.micromenu.toggleAlpha or 0.3 end,
				set = function(layoutName, value)
					ns.db.global.micromenu.toggleAlpha = value
					MicroMenu:OnSettingsUpdated()
				end,
			}
		})
		if LibEditMode.isEditing then self:ApplyEditModeState(true) end
	end
	-- Handle Bartender4 deferred init: if OnEnable already ran, apply EditMode scaling now
	if (self:IsEnabled()) then
		ns.API.SetEditModeUFObjectScale(toggle)
		toggle:ClearAllPoints()
		toggle:SetPoint(posPoint, UIParent, posPoint, posX, posY)
	end
end

MicroMenu.OnSettingsUpdated = function(self)
	self:UpdateLayout()
	if self.toggle and self.toggle.UpdateAlpha then
		self.toggle:UpdateAlpha()
	end
end

MicroMenu.ReclaimButtons = function(self)
	if ns.IsForever then return self:LayoutForeverMicroMenu() end
	if (InCombatLockdown()) then
		self.needsReclaim = true
		return
	end
	if (not self.bar or not self.bar.buttons) then return end
	local btnSize = self:GetButtonSize()
	local totalHeight = PADDING_V
	local visibleCount = 0
	for i, btn in ipairs(self.bar.buttons) do
		if (btn:GetParent() ~= self.bar) then
			btn:SetParent(self.bar)
		end
		btn:SetHitRectInsets(0, 0, 0, 0)
		btn:SetFrameLevel(self.bar:GetFrameLevel() + 2)
		btn:SetAlpha(1)
		if (btn:IsShown()) then
			local ew, eh = self:ResizeButton(btn, btnSize)
			btn:ClearAllPoints()
			btn:SetPoint("BOTTOM", self.bar, "BOTTOM", 0, totalHeight)
			totalHeight = totalHeight + eh + BUTTON_SPACING
			visibleCount = visibleCount + 1
		end
	end
	if (visibleCount > 0) then
		totalHeight = totalHeight - BUTTON_SPACING
	end
	totalHeight = totalHeight + PADDING_V
	local barWidth = btnSize + PADDING_H * 2
	self.bar:SetSize(barWidth, totalHeight)
end

MicroMenu.DeferReclaimButtons = function(self)
	if (InCombatLockdown()) then
		self.needsReclaim = true
		return
	end
	self:ReclaimButtons()
end

MicroMenu.OnCombatEnd = function(self)
	if InCombatLockdown() then return end
	if ns.IsForever and not self:IsEnabled() then
		self.needsInitialization, self.__foreverEnablePending = nil, nil
		self:RestoreForeverMicroMenu()
		return
	end
	if self.__foreverEnablePending then
		self.__foreverEnablePending = nil
		self:OnEnable()
	end
	if self.needsInitialization then self:InitializeMicroMenu() end
	if self.hasPendingEditModeState then self:ApplyEditModeState(self.pendingEditModeState) end
	if (self.needsReclaim) then
		self.needsReclaim = nil
		self:ReclaimButtons()
	end
	if (self.needsLayout) then
		self.needsLayout = nil
		self:UpdateLayout()
	end
end

MicroMenu.RestoreForeverMicroMenu = function(self)
	local native, original = self.nativeMenu, self.nativeMenuOriginal
	if not native or not original then return end
	if InCombatLockdown() then
		self.restoreFrame = self.restoreFrame or CreateFrame("Frame")
		self.restoreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		self.restoreFrame:SetScript("OnEvent", function(frame)
			frame:UnregisterAllEvents()
			if self.foreverMenuDisabled then self:RestoreForeverMicroMenu() end
		end)
		return
	end
	if self.bindingOwner then
		ClearOverrideBindings(self.bindingOwner)
		self.bindingOwner:UnregisterAllEvents()
	end
	if self.toggle then UnregisterStateDriver(self.toggle, "vis") end
	native:SetParent(original.parent)
	native:ClearAllPoints()
	for _, point in ipairs(original.points) do native:SetPoint(unpack(point)) end
	for _, key in ipairs({ "isHorizontal", "isStacked", "stride", "layoutFramesGoingRight", "layoutFramesGoingUp", "childXPadding", "childYPadding", "skipLayoutOnShow" }) do
		native[key] = original[key]
	end
	native:SetFrameStrata(original.strata)
	native:SetFrameLevel(original.level)
	native:SetScale(original.scale)
	if native.BorderArt then native.BorderArt:SetAlpha(original.borderAlpha) end
	if native.BackgroundArt then native.BackgroundArt:SetAlpha(original.backgroundAlpha) end
	for _, button in ipairs(self.bar.buttons) do button:SetSize(button.nativeWidth, button.nativeHeight) end
	native:Layout()
	self.bar:Hide()
	if self.toggle then self.toggle:Hide() end
end
MicroMenu.OnDisable = function(self)
	if ns.IsForever then
		self.foreverMenuDisabled = true
		self:RestoreForeverMicroMenu()
	end
end
MicroMenu.OnEnable = function(self)
	if ns.IsForever then
		if InCombatLockdown() then
			self.__foreverEnablePending = true
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
			return
		end
		self.foreverMenuDisabled = nil
		if self.nativeMenu then
			if not self:IsHooked(self.nativeMenu, "Layout") then self:SecureHook(self.nativeMenu, "Layout", "UpdateLayout") end
			if not self:IsHooked(self.nativeMenu, "SetParent") then self:SecureHook(self.nativeMenu, "SetParent", "DeferReclaimButtons") end
			if self.nativeMenu.UpdateScale and not self:IsHooked(self.nativeMenu, "UpdateScale") then self:SecureHook(self.nativeMenu, "UpdateScale", "UpdateLayout") end
			self:LayoutForeverMicroMenu()
			if self.toggle then self.toggle:Show() end
			if self.toggle then RegisterStateDriver(self.toggle, "vis", FOREVER_VISIBILITY) end
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
			if self.bindingOwner then
				self.bindingOwner:RegisterEvent("UPDATE_BINDINGS")
				self.bindingOwner:RegisterEvent("PLAYER_ENTERING_WORLD")
				if self.UpdateToggleBindings then self.UpdateToggleBindings() end
			end
		end
	end
	-- Switch to EditMode-compatible scaling (UIParent:GetScale() is valid by PLAYER_LOGIN)
	if (self.toggle) then
		ns.API.SetEditModeUFObjectScale(self.toggle)
		-- Re-apply position after scale switch to prevent visual drift
		local posPoint, posX, posY = self:GetPosition()
		self.toggle:ClearAllPoints()
		self.toggle:SetPoint(posPoint, UIParent, posPoint, posX, posY)
	end
end
MicroMenu.InitializeForeverAfterWorld = function(self)
	C_Timer.After(0, function()
		if self:IsEnabled() then self:InitializeMicroMenu() end
	end)
end
MicroMenu.OnInitialize = function(self)
	local db = ns:GetSettings()
	if (not db.global.micromenu.enableMicroMenu) then
		return self:Disable()
	end
	if (IsAddOnEnabled("ConsolePort")) then
		return self:Disable()
	end
	if ns.IsForever then
		-- Native layout must finish its own login/LOD initialization first.
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "InitializeForeverAfterWorld")
		return
	end
	if (IsAddOnEnabled("Bartender4") and not ns.BartenderHandled) then
		ns.RegisterCallback(self, "Bartender_Handled", "InitializeMicroMenu")
	else
		self:InitializeMicroMenu()
	end
end
