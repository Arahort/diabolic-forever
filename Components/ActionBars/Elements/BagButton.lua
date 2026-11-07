--[[
	DiabolicUI3 BagButton
	Styles the bag button with a circular border like ExtraActionButton
	and hides unnecessary elements (arrow, bag slots)
--]]
local Addon, ns = ...
local ActionBars = ns:GetModule("ActionBars")
local BagButton = ActionBars:NewModule("BagButton", "LibMoreEvents-1.0", "AceHook-3.0", "AceEvent-3.0")
-- Lua API
local pairs = pairs
local ipairs = ipairs
-- WoW API
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
-- Addon API
local Colors = ns.Colors
local GetMedia = ns.API.GetMedia
local SetObjectScale = ns.API.SetUnitFramesObjectScale
local IsAddOnEnabled = ns.API.IsAddOnEnabled
-- Local references
local styledButton = false
BagButton.UpdateForeverStateArt = function(self, button)
	if not button.__DiabolicIcon or button.__DiabolicStateArtUpdating then return end
	button.__DiabolicStateArtUpdating = true
	local normal = button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	if button.NormalTexture then button.NormalTexture:SetAlpha(0) end
	if button.icon then button.icon:SetAlpha(0) end
	if button.Icon then button.Icon:SetAlpha(0) end
	if button.Count then button.Count:SetAlpha(0) end
	button.__DiabolicIcon:SetVertexColor(1, 1, 1, 1)
	button.__DiabolicIcon:SetAlpha(.85)
	local function RestoreCircularTexture(texture, alpha)
		texture:SetTexture(GetMedia("actionbutton-mask-circular"))
		texture:SetTexCoord(0, 1, 0, 1)
		texture:ClearAllPoints()
		texture:SetAllPoints(button.__DiabolicIcon)
		texture:SetBlendMode("ADD")
		texture:SetVertexColor(1, 1, 1)
		texture:SetAlpha(alpha)
	end
	local highlight = button:GetHighlightTexture()
	if highlight ~= button.__DiabolicHighlight then
		if highlight then highlight:SetAlpha(0) end
		button:SetHighlightTexture(button.__DiabolicHighlight)
	end
	-- SetHighlightAtlas/UpdateTextures can overwrite our existing texture in place.
	-- Restoring the object reference alone leaves the square atlas and native tint.
	RestoreCircularTexture(button.__DiabolicHighlight, .12)
	local pushed = button:GetPushedTexture()
	if pushed ~= button.__DiabolicPushed then
		if pushed then pushed:SetAlpha(0) end
		button:SetPushedTexture(button.__DiabolicPushed)
	end
	RestoreCircularTexture(button.__DiabolicPushed, .08)
	-- OpenBag/CloseBag own this texture's visibility; only replace its square artwork.
	local slotHighlight = button.SlotHighlightTexture
	if slotHighlight then
		RestoreCircularTexture(slotHighlight, .08)
	end
	local checked = button.GetCheckedTexture and button:GetCheckedTexture()
	if checked then
		RestoreCircularTexture(checked, .08)
	end
	button.__DiabolicStateArtUpdating = nil
end
BagButton.StyleButton = function(self, button)
	if not button then return end
	if styledButton then
		if ns.IsForever then self:UpdateForeverStateArt(button) end
		return
	end
	styledButton = true
	button:SetSize(46, 46)
	if button.NormalTexture then
		button.NormalTexture:SetAlpha(0)
	end
	if button:GetNormalTexture() then
		button:GetNormalTexture():SetTexture(nil)
	end
	if button.Count then
		button.Count:SetAlpha(0)
	end
	if not button.__DiabolicIcon then
		local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
		icon:SetPoint("TOPLEFT", button, 4, -4)
		icon:SetPoint("BOTTOMRIGHT", button, -4, 4)
		icon:SetMask(GetMedia("actionbutton-mask-circular"))
		icon:SetTexture([[Interface\Buttons\Button-Backpack-Up]])
		icon:SetAlpha(.85)
		button.__DiabolicIcon = icon
		if button.icon then
			button.icon:SetAlpha(0)
		elseif button.Icon then
			button.Icon:SetAlpha(0)
		end
	end
	if not button.__DiabolicBorder then
		local border = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		border:SetTexture(GetMedia("button-big-circular"))
		border:SetVertexColor(.8, .76, .72)
		border:SetPoint("TOPLEFT", -8, 8)
		border:SetPoint("BOTTOMRIGHT", 8, -8)
		button.__DiabolicBorder = border
	end
	if not button.__DiabolicHighlight then
		local highlightTexture = button:CreateTexture(nil, "HIGHLIGHT", nil, 1)
		highlightTexture:SetTexture(GetMedia("actionbutton-mask-circular"))
		highlightTexture:SetAllPoints(button.__DiabolicIcon)
		highlightTexture:SetVertexColor(1, 1, 1, .15)
		button.__DiabolicHighlight = highlightTexture
		if button:GetHighlightTexture() then
			button:GetHighlightTexture():SetTexture(nil)
		end
		button:SetHighlightTexture(button.__DiabolicHighlight)
	end
	if not button.__DiabolicPushed then
		local pushedTexture = button:CreateTexture(nil, "ARTWORK", nil, 2)
		pushedTexture:SetTexture(GetMedia("actionbutton-mask-circular"))
		pushedTexture:SetAllPoints(button.__DiabolicIcon)
		pushedTexture:SetVertexColor(1, .8, 0, .25)
		button.__DiabolicPushed = pushedTexture
		if button:GetPushedTexture() then
			button:GetPushedTexture():SetTexture(nil)
		end
		button:SetPushedTexture(button.__DiabolicPushed)
	end
	if ns.IsForever then
		local function RestoreStateArt(frame) self:UpdateForeverStateArt(frame) end
		for _, method in ipairs({ "UpdateTextures", "SetNormalTexture", "SetNormalAtlas", "SetHighlightTexture", "SetHighlightAtlas", "SetPushedTexture", "SetPushedAtlas", "SetCheckedTexture", "SetCheckedAtlas" }) do
			if button[method] then hooksecurefunc(button, method, RestoreStateArt) end
		end
		button:HookScript("OnShow", RestoreStateArt)
		self:UpdateForeverStateArt(button)
	end
end
BagButton.HideBagSlots = function(self)
	local slots = {
		"CharacterBag0Slot",
		"CharacterBag1Slot",
		"CharacterBag2Slot",
		"CharacterBag3Slot",
		"CharacterReagentBag0Slot"
	}
	for _, slotName in ipairs(slots) do
		local slot = _G[slotName]
		if slot then
			slot:SetParent(ns.Hider)
			slot:Hide()
		end
	end
	if BagBarExpandToggle then
		BagBarExpandToggle:SetParent(ns.Hider)
		BagBarExpandToggle:Hide()
	end
end
BagButton.LayoutForeverBags = function(self)
	local bar, backpack = BagsBar, MainMenuBarBackpackButton
	if not bar or not backpack then return end
	-- Native Layout counts hidden bag slots; only the replacement backpack needs space.
	if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
	for _, name in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = bar[name]
		if pool then pool:ReleaseAll() end
	end
	bar.useDividers = false
	bar:SetSize(46, 46)
	local keyring = KeyRingButton
	if keyring then
		-- Only the backpack icon belongs in this layout; keep native key storage intact.
		keyring:SetParent(ns.Hider)
		keyring:Hide()
	end
	if not self.__foreverLayoutHooked and bar.Layout then
		self.__foreverLayoutHooked = true
		hooksecurefunc(bar, "Layout", function() self:SetupBagsBar() end)
	end
end
BagButton.SetupBagsBar = function(self)
	if self.__settingUpForever then return end
	local db = ns.db
	if not db then return end
	local settings = db.global.bagbutton
	if not settings then return end
	-- WoW 12.0: BagsBar is a secure frame — SetParent/Hide on it taints in combat.
	-- Defer the change until combat ends if we're locked down right now.
	if (InCombatLockdown()) then
		self.__pendingSetup = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
		return
	end
	self.__pendingSetup = nil
	if ns.IsForever then
		self.__settingUpForever = true
		self:LayoutForeverBags()
	end
	if settings.hideBagButton then
		if BagsBar then
			BagsBar:SetParent(ns.Hider)
			BagsBar:Hide()
		end
		self.__settingUpForever = nil
		return
	end
	if BagsBar then
		BagsBar:SetParent(UIParent)
		BagsBar:Show()
		BagsBar:SetAlpha(1)
	end
	self:HideBagSlots()
	local bagButton = MainMenuBarBackpackButton
	if bagButton then
		self:StyleButton(bagButton)
	end
	self.__settingUpForever = nil
end
BagButton.OnRegenEnabled = function(self)
	if (self.__pendingSetup) then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:SetupBagsBar()
	end
end
BagButton.OnInitialize = function(self)
	local bagAddons = { "AdiBags", "ArkInventory", "Bagnon", "Combuctor", "ElvUI" }
	for _, addon in ipairs(bagAddons) do
		if IsAddOnEnabled(addon) then
			return self:Disable()
		end
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
end
BagButton.OnPlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	C_Timer.After(0.2, function()
		self:SetupBagsBar()
	end)
end
BagButton.OnEnable = function(self)
end
