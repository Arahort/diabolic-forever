local Addon, ns = ...
if not ns.IsForever then return end
local Experience = ns:NewModule("MinimapExperience", "LibMoreEvents-1.0")
local SEGMENTS = 180
local DEFAULT_THICKNESS = 5.8
local FULL_CIRCLE = math.pi * 2
local NORMAL_ATLAS = "UI-HUD-ExperienceBar-Fill-Experience"
local RESTED_ATLAS = "UI-HUD-ExperienceBar-Fill-Rested"
local function clamp(value)
	return math.max(0, math.min(1, value))
end
local function position(fraction, radius)
	local angle = fraction * FULL_CIRCLE
	return math.sin(angle) * radius, math.cos(angle) * radius
end
Experience.SetNativePresentationHidden = function(self, object, hidden)
	if not object then return end
	if hidden then
		if self.originalAlpha[object] == nil then self.originalAlpha[object] = object:GetAlpha() end
		object:SetAlpha(0)
	elseif self.originalAlpha[object] ~= nil then
		object:SetAlpha(self.originalAlpha[object])
		self.originalAlpha[object] = nil
	end
end
Experience.SyncNativeBars = function(self)
	if self.syncingNativeBars then return end
	local manager = StatusTrackingBarManager
	local info = StatusTrackingBarInfo
	if not manager or not info then return end
	self.syncingNativeBars = true
	local xpIndex = info.BarsEnum.Experience
	for _, container in ipairs(manager.barContainers or {}) do
		local xp = container.bars and container.bars[xpIndex]
		self:SetNativePresentationHidden(xp, self.active)
		local selected = self.active and container.shownBarIndex == xpIndex
		local emptyPrimary = container == manager.MainStatusTrackingBarContainer and container.shownBarIndex == info.BarsEnum.None
		local hideSelection = self.active and (selected or emptyPrimary)
		if hideSelection and container.Selection then
			self.hiddenXPSelections[container] = true
			-- Clear the native selection and snap target, not the shared status system.
			if not InCombatLockdown() and (container.isInEditMode or container.Selection:IsShown() or container.isHighlighted or container.isSelected) then
				container:ClearHighlight()
				container:SetMovable(false)
			end
		elseif self.hiddenXPSelections[container] then
			self.hiddenXPSelections[container] = nil
			if not InCombatLockdown() and container.isInEditMode then container:HighlightSystem() end
		end
		self:SetNativePresentationHidden(container.BarFrameTexture, selected)
		local pool = container.HorizontalDividersPool
		if pool then
			for divider in pool:EnumerateActive() do self:SetNativePresentationHidden(divider, selected) end
		end
		if not self.nativeHooks[container] then
			self.nativeHooks[container] = true
			local function Refresh() self:SyncNativeBars() end
			hooksecurefunc(container, "ApplyPendingBarToShow", Refresh)
			hooksecurefunc(container, "UpdateDividers", Refresh)
			hooksecurefunc(container, "HighlightSystem", Refresh)
			hooksecurefunc(container, "SelectSystem", Refresh)
			hooksecurefunc(container, "UpdateShownState", Refresh)
		end
	end
	self.syncingNativeBars = nil
end
Experience.DrawArc = function(self, lines, first, last)
	for i = 1, SEGMENTS do
		local a = math.max(first, (i - 1) / SEGMENTS)
		local b = math.min(last, i / SEGMENTS)
		local line = lines[i]
		if b > a then
			local x1, y1 = position(a, self.radius)
			local x2, y2 = position(b, self.radius)
			line:SetStartPoint("CENTER", self.frame, x1, y1)
			line:SetEndPoint("CENTER", self.frame, x2, y2)
			line:Show()
		else
			line:Hide()
		end
	end
end
Experience.SetMaterial = function(self, atlas)
	if self.atlas == atlas then return end
	for i = 1, SEGMENTS do
		self.fill[i]:SetAtlas(atlas, false)
		self.bonus[i]:SetAtlas(RESTED_ATLAS, false)
		self.bonus[i]:SetAlpha(.35)
	end
	self.atlas = atlas
end
Experience.Update = function(self)
	if not self.frame or self.stopped then return end
	local settings = ns.db.global.minimap
	local thickness = math.max(.5, math.min(12, tonumber(settings.xpRingThickness) or DEFAULT_THICKNESS))
	local transparency = math.max(0, math.min(100, tonumber(settings.xpRingTransparency) or 50))
	self.frame:SetAlpha(1 - transparency / 100)
	if self.thickness ~= thickness then
		for i = 1, SEGMENTS do
			self.fill[i]:SetThickness(thickness)
			self.bonus[i]:SetThickness(thickness)
		end
	end
	self.thickness, self.transparency = thickness, transparency
	local enabled = not ns.db.global.minimap.disabled
	local visible = GameRulesUtil.CanShowExperienceBar() and not IsXPUserDisabled()
	local xp, maximum = UnitXP("player"), UnitXPMax("player")
	-- Reuse the client's banked/trial XP interpretation where it is available.
	local manager = StatusTrackingBarManager
	local info = StatusTrackingBarInfo
	if manager and info then
		for _, container in ipairs(manager.barContainers or {}) do
			local native = container.bars and container.bars[info.BarsEnum.Experience]
			if native then xp, maximum = native:GetLevelData(); break end
		end
	end
	local width, height = Minimap:GetSize()
	local hasMaterial = C_Texture.GetAtlasInfo(NORMAL_ATLAS) and C_Texture.GetAtlasInfo(RESTED_ATLAS)
	self.active = enabled and visible and maximum > 0 and width > 12 and height > 12 and not not hasMaterial
	if not self.active then
		self.frame:Hide()
		self:SyncNativeBars()
		return
	end
	-- No backing/shadow; keep the coloured outer edge inset at every thickness.
	self.radius = math.min(width, height) / 2 - thickness / 2 - 2.35
	local fraction = clamp(xp / maximum)
	local rested = GetRestState() == 1
	local bonus = GetXPExhaustion() or 0
	self:SetMaterial(rested and RESTED_ATLAS or NORMAL_ATLAS)
	self:DrawArc(self.fill, 0, fraction)
	self:DrawArc(self.bonus, fraction, clamp((xp + bonus) / maximum))
	self.frame:Show()
	self.currentXP, self.maximumXP, self.rested, self.fraction = xp, maximum, rested, fraction
	self:SyncNativeBars()
	ns.ForeverNativeFallbacks.statusBars = "XP ring inside minimap; native reputation and other bars retained"
end
Experience.OnInitialize = function(self)
	self.originalAlpha = setmetatable({}, { __mode = "k" })
	self.nativeHooks = setmetatable({}, { __mode = "k" })
	self.hiddenXPSelections = setmetatable({}, { __mode = "k" })
	self.fill, self.bonus = {}, {}
	local frame = CreateFrame("Frame", "DiabolicMinimapExperience", Minimap)
	frame:SetAllPoints(Minimap)
	frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	frame:SetAlpha(.5)
	frame:EnableMouse(false)
	frame:SetClipsChildren(true)
	self.frame = frame
	for i = 1, SEGMENTS do
		local bonus = frame:CreateLine(nil, "ARTWORK", nil, 0)
		bonus:SetThickness(DEFAULT_THICKNESS)
		self.bonus[i] = bonus
		local fill = frame:CreateLine(nil, "OVERLAY", nil, 0)
		fill:SetThickness(DEFAULT_THICKNESS)
		self.fill[i] = fill
	end
	Minimap:HookScript("OnSizeChanged", function() self:Update() end)
	frame:Hide()
end
Experience.OnEnable = function(self)
	self.stopped = nil
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_FACTION", "PLAYER_REGEN_ENABLED" }) do
		self:RegisterEvent(event, "Update")
	end
	if ns.RegisterCallback then ns.RegisterCallback(self, "Minimap_Settings_Updated", "Update") end
	if ns.RegisterCallback then ns.RegisterCallback(self, "Minimap_Experience_Updated", "Update") end
	self:Update()
end
Experience.OnDisable = function(self)
	self.stopped = true
	self.active = false
	self:SyncNativeBars()
	if self.frame then self.frame:Hide() end
	for object, alpha in pairs(self.originalAlpha or {}) do object:SetAlpha(alpha) end
	self.originalAlpha = setmetatable({}, { __mode = "k" })
end
