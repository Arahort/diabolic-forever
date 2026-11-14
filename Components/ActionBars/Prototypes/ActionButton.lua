local Addon, ns = ...
local ActionBars = ns:GetModule("ActionBars")
local ButtonMod = ActionBars:NewModule("Buttons", "LibMoreEvents-1.0")
local LAB = LibStub("LibActionButton-1.0")
local LAB_Version = LibStub.minors["LibActionButton-1.0"]

-- Lua API
local next = next

-- WoW API
-- WoW 12.1: IsSpellOverlayed lives in C_SpellActivationOverlay. It was never in C_Spell,
-- so the old lookup resolved to nil and the proc highlight errored out on every check.
local IsSpellOverlayed = C_SpellActivationOverlay.IsSpellOverlayed
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local SetObjectScale = ns.API.SetUnitFramesObjectScale
local RegisterCooldown = ns.Widgets.RegisterCooldown
local UIHider = ns.Hider
local noop = ns.Noop

-- Default button config
local buttonConfig = {
	outOfRangeColoring = "button",
	tooltip = "enabled",
	showGrid = true,
	colors = {
		range = { 1, 1, 1 },
		mana = { .25, .25, 1 },
		disabled = { .4, .36, .32 }
	},
	hideElements = {
		macro = true,
		hotkey = false,
		equipped = true,
		border = true,
		borderIfEmpty = true
	},
	keyBoundTarget = false,
	keyBoundClickButton = "LeftButton",
	clickOnDown = true,
	flyoutDirection = "UP"
}

local ActionButton = {}
ns.ActionButton = ActionButton
ns.ActionButtons = {}
ActionButton.ApplyCooldownAppearance = function(button)
	if not ns.IsForever or not button.overlay then return end
	local cooldown = button.cooldown
	if not cooldown then return end
	-- LAB refreshes its default anchors when the secure action page changes.
	for _, frame in pairs({ cooldown, button.chargeCooldown, button.lossOfControlCooldown }) do
		frame:ClearAllPoints()
		frame:SetAllPoints(button.icon)
	end
	local showNumbers = C_CVar.GetCVarBool("countdownForCooldowns")
	cooldown:SetHideCountdownNumbers(not showNumbers)
	local font = GetFont(20, true)
	if cooldown.SetCountdownFont then cooldown:SetCountdownFont(font:GetName()) end
	local text = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
	if text then
		text:SetFontObject(font)
		text:SetDrawLayer("OVERLAY", 7)
		text:ClearAllPoints()
		text:SetPoint("CENTER", cooldown, "CENTER", 1, 0)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
		text:SetTextColor(250/255, 250/255, 250/255)
	end
end
ButtonMod.QueueActionRefresh = function(self, event)
	if self.actionRefreshPending then return end
	if event then
		local form, page, bonus = GetShapeshiftForm(), GetActionBarPage(), GetBonusBarOffset()
		local secret = issecretvalue and (issecretvalue(form) or issecretvalue(page) or issecretvalue(bonus))
		if not secret then
			if event ~= "PLAYER_ENTERING_WORLD" and form == self.lastForm and page == self.lastPage and bonus == self.lastBonus then return end
			self.lastForm, self.lastPage, self.lastBonus = form, page, bonus
		end
	end
	self.actionRefreshPending = true
	C_Timer.After(0, function()
		self.actionRefreshPending = nil
		-- Bonus-page contents settle after the form event and secure ChildUpdate.
		-- UpdateAction only refreshes LAB/native UI registration, not secure states.
		for button in next, ns.ActionButtons do
			if button.header and button.header.id == 1 then button:UpdateAction(true) end
		end
	end)
end

-- Tooltip wrapper functions to preserve LibActionButton tooltips
local onEnter = function(self)
	if (self.OnEnter) then
		self:OnEnter()
	end
end

local onLeave = function(self)
	if (self.OnLeave) then
		self:OnLeave()
	end
end

-- Constructor
ActionButton.Create = function(self, id, name, header, config)

	local button = LAB:CreateButton(id, name, header, config or buttonConfig)

	-- Preserve original tooltip handlers from LibActionButton
	button.OnEnter = button:GetScript("OnEnter")
	button.OnLeave = button:GetScript("OnLeave")

	-- Set wrapper functions that call original handlers
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)

	ns.ActionButtons[button] = true

	return button
end

---------------------------------------------
-- LAB Overrides & MaxDps Integration
---------------------------------------------
local ShowMaxDps = function(self)
	if (self.SpellHighlight) then
		if (self.maxDpsGlowColor) then
			local r, g, b, a = unpack(self.maxDpsGlowColor)
			self.SpellHighlight:SetVertexColor(r, g, b, a or .75)
		else
			self.SpellHighlight:SetVertexColor(249/255, 188/255, 65/255, .75)
		end
		self.SpellHighlight:Show()
		LAB.callbacks:Fire("OnButtonShowOverlayGlow", self)
	end
end

local HideMaxDps = function(self)
	if (self.SpellHighlight) then
		if (not self.maxDpsGlowShown) then
			self.SpellHighlight:Hide()
			LAB.callbacks:Fire("OnButtonHideOverlayGlow", self)
		end
	end
end

local UpdateMaxDps = function(self)
	if (self.maxDpsGlowShown) then
		ShowMaxDps(self)
	else
		if (WoWWrath) then
			HideMaxDps(self)
		else
			local spellId = self:GetSpellId()
			if (spellId and IsSpellOverlayed(spellId)) then
				ShowMaxDps(self)
			else
				HideMaxDps(self)
			end
		end
	end
end

-- WoW 12.0.0: UpdateUsable function to handle spell availability visual feedback
local UpdateUsable = function(self)

	if (UnitIsDeadOrGhost("player")) then
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(unpack(buttonConfig.colors.disabled))

	elseif (self.outOfRange) then
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(unpack(buttonConfig.colors.range))
	else
		local isUsable, notEnoughMana = self:IsUsable()
		if (isUsable) then
			self.icon:SetDesaturated(false)
			self.icon:SetVertexColor(1, 1, 1)

		elseif (notEnoughMana) then
			self.icon:SetDesaturated(true)
			self.icon:SetVertexColor(unpack(buttonConfig.colors.mana))
		else
			self.icon:SetDesaturated(true)
			self.icon:SetVertexColor(unpack(buttonConfig.colors.disabled))
		end
	end

	if (ns.IsRetail and self._state_type == "action") then
		local isLevelLinkLocked = C_LevelLink.IsActionLocked(self._state_action)
		if (not self.icon:IsDesaturated()) then
			self.icon:SetDesaturated(isLevelLinkLocked)
			if isLevelLinkLocked then
				self.icon:SetVertexColor(unpack(buttonConfig.colors.disabled))
			end
		end
		if (self.LevelLinkLockIcon) then
			self.LevelLinkLockIcon:SetShown(isLevelLinkLocked)
		end
	end

end

ButtonMod.HandleMaxDps = function(self)

	MaxDps:RegisterLibActionButton(LAB_Version)

	lib.MaxDps_GetTexture = lib.MaxDps_GetTexture or MaxDps.GetTexture
	lib.MaxDps_Glow = lib.MaxDps_Glow or MaxDps.Glow
	lib.MaxDps_HideGlow = lib.MaxDps_HideGlow  or MaxDps.HideGlow

	MaxDps.GetTexture = function() end

	MaxDps.Glow = function(this, button, id, texture, type, color)
		if (not ButtonRegistry[button]) then
			return lib.MaxDps_Glow(this, button, id, texture, type, color)
		end
		local col = color and { color.r, color.g, color.b, color.a } or nil
		if (not color) and (type) then
			if (type == "normal") then
				local c = this.db.global.highlightColor
				col = { c.r, c.g, c.b, c.a }

			elseif (type == "cooldown") then
				local c = this.db.global.cooldownColor
				col = { c.r, c.g, c.b, c.a }
			end
		end
		button.maxDpsGlowColor = col
		button.maxDpsGlowShown = true
		UpdateMaxDps(button)
	end

	MaxDps.HideGlow = function(this, button, id)
		if (not ButtonRegistry[button]) then
			return lib.MaxDps_HideGlow(this, button, id)
		end
		button.maxDpsGlowColor = nil
		button.maxDpsGlowShown = nil
		UpdateMaxDps(button)
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "OnEvent")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnEvent")

	LAB.RegisterCallback(self, "OnButtonShowOverlayGlow", "OnEvent")
	LAB.RegisterCallback(self, "OnButtonHideOverlayGlow", "OnEvent")

	self.MaxDps = true
end

ButtonMod.OnEvent = function(self, event, ...)
	if ns.IsForever then
		if event == "CVAR_UPDATE" then
			local cvar = ...
			if cvar == "countdownForCooldowns" then
				for button in next, ns.ActionButtons do ActionButton.ApplyCooldownAppearance(button) end
			end
			return
		elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
			self:QueueActionRefresh(event)
		end
	end
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "MaxDps") then
			self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			self:HandleMaxDps()
		end

	elseif (event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_VEHICLE_ACTIONBAR" or event == "UPDATE_SHAPESHIFT_FORM") then

		if (self.MaxDps) then
			for button in next, LAB.activeButtons do
				if (ns.ActionButtons[button]) then
					if (button.maxDpsGlowShown) then
						button.maxDpsGlowColor = nil
						button.maxDpsGlowShown = nil
						UpdateMaxDps(button)
					end
				end
			end
		end

	elseif (event == "OnButtonUsable") then
		local button = ...
		if (ns.ActionButtons[button]) then
			UpdateUsable(button)
		end

	elseif (event == "OnButtonUpdate") then
		local button = ...
		if (ns.ActionButtons[button]) then
			ActionButton.ApplyCooldownAppearance(button)
			UpdateUsable(button)
			if (self.MaxDps) then
				if (not button:GetTexture()) then
					button.maxDpsGlowColor = nil
					button.maxDpsGlowShown = nil
				end
				UpdateMaxDps(button)
			end
		end

	elseif (event == "OnButtonHideOverlayGlow" or event == "OnButtonShowOverlayGlow") then
		local button = ...
		if (ns.ActionButtons[button]) then
			if (self.MaxDps) then
				UpdateMaxDps(button)
			end
		end
	end
end

ButtonMod.OnInitialize = function(self)
	if ns.IsForever then
		self:RegisterEvent("CVAR_UPDATE", "OnEvent")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnEvent")
		self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", "OnEvent")
		self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "OnEvent")
	end

	if (MaxDps) then
		self:HandleMaxDps()
	elseif (IsAddOnEnabled("MaxDps")) then
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end

	LAB.RegisterCallback(self, "OnButtonUsable", "OnEvent")
	LAB.RegisterCallback(self, "OnButtonUpdate", "OnEvent")
end
