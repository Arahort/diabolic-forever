local Addon, ns = ...
if not ns.IsForever then return end
local Experience = ns:NewModule("MinimapExperience", "LibMoreEvents-1.0")
local SEGMENTS = 180
local DEFAULT_THICKNESS = 5.8
local FULL_CIRCLE = math.pi * 2
local NORMAL_ATLAS = "UI-HUD-ExperienceBar-Fill-Experience"
local RESTED_ATLAS = "UI-HUD-ExperienceBar-Fill-Rested"
-- Centre of the original 512px border's opaque annulus, displayed at 340/280.
local BORDER_RADIUS_RATIO = 214.5 / 512 * 340 / 280
local BORDER_WIDTH_RATIO = 26 / 512 * 340 / 280
local DIVIDER_PIXELS = 4.5
local EDGE_PIXELS = 2
local HOVER_INTERVAL = .075
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
	local honorIndex = info.BarsEnum.Honor
	for _, container in ipairs(manager.barContainers or {}) do
		local xp = container.bars and container.bars[xpIndex]
		self:SetNativePresentationHidden(xp, self.active)
		local honor = container.bars and container.bars[honorIndex]
		-- The native manager automatically selects Honor on entering a battleground.
		self:SetNativePresentationHidden(honor, not self.stopped)
		if honor and not self.nativeHooks[honor] then
			self.nativeHooks[honor] = true
			honor:HookScript("OnShow", function() self:SyncNativeBars() end)
		end
		local selected = (self.active and container.shownBarIndex == xpIndex) or (not self.stopped and container.shownBarIndex == honorIndex)
		local emptyPrimary = container == manager.MainStatusTrackingBarContainer and container.shownBarIndex == info.BarsEnum.None
		local hideSelection = selected or (self.active and emptyPrimary)
		if hideSelection and container.Selection then
			self.hiddenXPSelections[container] = true
			-- Suppress the mover without writing native highlight/selection metadata.
			if not InCombatLockdown() and (container.isInEditMode or container.Selection:IsShown() or container.isHighlighted or container.isSelected) then
				container.Selection:Hide()
				container:SetMovable(false)
			end
		elseif self.hiddenXPSelections[container] then
			self.hiddenXPSelections[container] = nil
			if not InCombatLockdown() and container.isInEditMode and container.Selection then container.Selection:Show() end
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
	ns.ForeverNativeFallbacks.nativeHonorBar = self.stopped and "Blizzard HonorStatusBar" or "Presentation hidden; native honor system retained"
end
Experience.DrawArc = function(self, textures, first, last, thickness, radius)
	local half = (thickness or self.fillThickness) / 2
	radius = radius or self.radius
	local outer, inner = radius + half, radius - half
	for i = 1, SEGMENTS do
		local a = math.max(first, (i - 1) / SEGMENTS)
		local b = math.min(last, i / SEGMENTS)
		local texture = textures[i]
		if b > a then
			if textures == self.rail then texture:SetTexCoord(a, b, 0, 1) end
			local x1, y1 = position(a, outer)
			local x2, y2 = position(a, inner)
			local x3, y3 = position(b, outer)
			local x4, y4 = position(b, inner)
			-- Texture is 1x1 at the centre; the four vertices form an annular sector.
			-- Outer/inner material edges always share the exact neighbouring vertices.
			texture:SetVertexOffset(UPPER_LEFT_VERTEX or 1, x1 + .5, y1 - .5)
			texture:SetVertexOffset(LOWER_LEFT_VERTEX or 2, x2 + .5, y2 + .5)
			texture:SetVertexOffset(UPPER_RIGHT_VERTEX or 3, x3 - .5, y3 - .5)
			texture:SetVertexOffset(LOWER_RIGHT_VERTEX or 4, x4 - .5, y4 + .5)
			texture:Show()
		else
			texture:Hide()
		end
	end
end
Experience.SetMaterial = function(self, atlas)
	local style = ns.db.global.orbs.style
	if self.atlas == atlas and self.materialStyle == style and self.appliedTransparency == self.transparency then return end
	local fill = ns.API.GetMedia(atlas == RESTED_ATLAS and "minimap-xp-rested" or "minimap-xp-fill", "png")
	local bonus = ns.API.GetMedia("minimap-xp-rested", "png")
	local stone = ns.API.IsStoneStyle()
	local channel = ns.API.GetMedia(stone and "arahort-stone/minimap-xp-channel" or "minimap-xp-channel", "png")
	for i = 1, SEGMENTS do
		self.fill[i]:SetTexture(fill, "CLAMP", "CLAMP")
		self.fill[i]:SetAlpha(1)
		self.bonus[i]:SetTexture(bonus, "CLAMP", "CLAMP")
		self.bonus[i]:SetAlpha(.35)
		self.rail[i]:SetTexture(channel, "CLAMP", "CLAMP")
		self.rail[i]:SetVertexColor(1, 1, 1)
		self.rail[i]:SetAlpha(1)
	end
	self.atlas, self.materialStyle, self.appliedTransparency = atlas, style, self.transparency
end
local function DrawDividerPart(cap, radius, height, fraction, left, right)
	local nx, ny = position(fraction, 1)
	local tx, ty = ny, -nx
	local x1, y1 = nx * (radius + height) + tx * left, ny * (radius + height) + ty * left
	local x2, y2 = nx * (radius - height) + tx * left, ny * (radius - height) + ty * left
	local x3, y3 = nx * (radius + height) + tx * right, ny * (radius + height) + ty * right
	local x4, y4 = nx * (radius - height) + tx * right, ny * (radius - height) + ty * right
	cap:SetVertexOffset(UPPER_LEFT_VERTEX or 1, x1 + .5, y1 - .5)
	cap:SetVertexOffset(LOWER_LEFT_VERTEX or 2, x2 + .5, y2 + .5)
	cap:SetVertexOffset(UPPER_RIGHT_VERTEX or 3, x3 - .5, y3 - .5)
	cap:SetVertexOffset(LOWER_RIGHT_VERTEX or 4, x4 - .5, y4 + .5)
	cap:Show()
end
Experience.DrawCap = function(self, cap, fraction, shown)
	if not shown then
		cap:Hide()
		cap.face:Hide()
		cap.highlight:Hide()
		return
	end
	local height = self.channelThickness / 2
	local half = DIVIDER_PIXELS * self.pixelSize / 2
	local edge = .55 * self.pixelSize
	DrawDividerPart(cap, self.radius, height, fraction, -half, half)
	DrawDividerPart(cap.face, self.radius, height - edge, fraction, -half + edge, half - edge)
	DrawDividerPart(cap.highlight, self.radius, height - edge, fraction, -half + edge, -half + edge + .6 * self.pixelSize)
end
Experience.UpdateVisibility = function(self)
	if self.active and not self.stopped then
		-- Geometric hit testing also covers clocks and icons without taking mouse input.
		self.frame:SetShown(self.hoverWatcher:IsMouseOver())
	else
		self.frame:Hide()
	end
end
Experience.Update = function(self)
	if not self.frame or self.stopped then return end
	local settings = ns.db.global.minimap
	local thickness = math.max(.5, math.min(12, tonumber(settings.xpRingThickness) or DEFAULT_THICKNESS))
	local transparency = math.max(0, math.min(100, tonumber(settings.xpRingTransparency) or 50))
	-- One group opacity covers the liquid, brass edging and dividers equally.
	self.frame:SetAlpha(1 - transparency / 100)
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
		self.hoverWatcher:Hide()
		self.frame:Hide()
		self:SyncNativeBars()
		return
	end
	-- Fill is in the existing rim, rather than over the terrain. No unfilled track.
	self.radius = math.min(width, height) * BORDER_RADIUS_RATIO
	self.borderSize = math.min(width, height) * 340 / 280
	self.pixelSize = 1 / self.frame:GetEffectiveScale()
	local hoverSize = self.borderSize * 458 / 512
	self.hoverWatcher:SetSize(hoverSize, hoverSize)
	-- The socket occupies the existing rim, independently of the liquid-width slider.
	self.channelThickness = math.min(width, height) * BORDER_WIDTH_RATIO
	self.fillThickness = math.min(self.channelThickness * .8, thickness * 1.3)
	local fraction = clamp(xp / maximum)
	local rested = GetRestState() == 1
	local bonus = GetXPExhaustion() or 0
	self:SetMaterial(rested and RESTED_ATLAS or NORMAL_ATLAS)
	local last = clamp((xp + bonus) / maximum)
	self:DrawArc(self.rail, 0, last, self.channelThickness)
	self:DrawArc(self.fill, 0, fraction)
	self:DrawArc(self.bonus, fraction, last)
	local edgeWidth = EDGE_PIXELS * self.pixelSize
	local edgeOffset = (self.channelThickness - edgeWidth) / 2
	self:DrawArc(self.outerRail, 0, last, edgeWidth, self.radius + edgeOffset)
	self:DrawArc(self.innerRail, 0, last, edgeWidth, self.radius - edgeOffset)
	self:DrawCap(self.caps[1], 0, last > 0)
	self:DrawCap(self.caps[2], fraction, fraction > 0 and fraction < 1)
	self:DrawCap(self.caps[3], last, last > fraction and last < 1)
	self.hoverWatcher:Show()
	self:UpdateVisibility()
	self.currentXP, self.maximumXP, self.rested, self.fraction = xp, maximum, rested, fraction
	self:SyncNativeBars()
	ns.ForeverNativeFallbacks.statusBars = "XP inset in minimap rim; native honor bar hidden; reputation and other bars retained"
end
Experience.OnInitialize = function(self)
	local settings = ns.db.global.minimap
	if settings.xpRingConceptOpacity then
		if settings.xpRingTransparency == 0 then settings.xpRingTransparency = 66 end
		settings.xpRingConceptOpacity = nil
	end
	self.originalAlpha = setmetatable({}, { __mode = "k" })
	self.nativeHooks = setmetatable({}, { __mode = "k" })
	self.hiddenXPSelections = setmetatable({}, { __mode = "k" })
	self.fill, self.bonus = {}, {}
	self.rail, self.caps = {}, {}
	self.outerRail, self.innerRail = {}, {}
	local frame = CreateFrame("Frame", "DiabolicMinimapExperience", Minimap)
	frame:SetAllPoints(Minimap)
	frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	frame:SetAlpha(.5)
	frame:EnableMouse(false)
	frame:SetClipsChildren(false)
	self.frame = frame
	local watcher = CreateFrame("Frame", nil, Minimap)
	watcher:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	watcher:EnableMouse(false)
	watcher:SetScript("OnShow", function() self:UpdateVisibility() end)
	watcher:SetScript("OnUpdate", function(_, elapsed)
		self.hoverElapsed = (self.hoverElapsed or 0) + elapsed
		if self.hoverElapsed < HOVER_INTERVAL then return end
		self.hoverElapsed = 0
		self:UpdateVisibility()
	end)
	self.hoverWatcher = watcher
	watcher:Hide()
	local function CreateSector(layer, sublevel)
		local texture = frame:CreateTexture(nil, layer, nil, sublevel)
		texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
		texture:SetSize(1, 1)
		texture:SetTexCoord(0, 1, 0, 1)
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
		texture:Hide()
		return texture
	end
	-- Aged brass sampled from the supplied material: dark face, midtone and highlight.
	local brassShadow = CreateColor(99 / 255, 75 / 255, 26 / 255, 1)
	local brassMidtone = CreateColor(122 / 255, 93 / 255, 36 / 255, 1)
	local brassHighlight = CreateColor(156 / 255, 121 / 255, 56 / 255, 1)
	for i = 1, SEGMENTS do
		self.rail[i] = CreateSector("ARTWORK", 0)
		self.bonus[i] = CreateSector("OVERLAY", 0)
		self.fill[i] = CreateSector("OVERLAY", 1)
		self.outerRail[i] = CreateSector("OVERLAY", 2)
		self.outerRail[i]:SetColorTexture(1, 1, 1, 1)
		self.outerRail[i]:SetGradient("VERTICAL", brassShadow, brassHighlight)
		self.innerRail[i] = CreateSector("OVERLAY", 2)
		self.innerRail[i]:SetColorTexture(1, 1, 1, 1)
		self.innerRail[i]:SetGradient("VERTICAL", brassHighlight, brassShadow)
	end
	for i = 1, 3 do
		local cap = CreateSector("OVERLAY", 3)
		cap:SetColorTexture(50 / 255, 38 / 255, 13 / 255, 1)
		cap.face = CreateSector("OVERLAY", 4)
		cap.face:SetColorTexture(1, 1, 1, 1)
		cap.face:SetGradient("HORIZONTAL", brassHighlight, brassShadow)
		cap.highlight = CreateSector("OVERLAY", 5)
		cap.highlight:SetColorTexture(1, 1, 1, 1)
		cap.highlight:SetGradient("VERTICAL", brassMidtone, brassHighlight)
		self.caps[i] = cap
	end
	Minimap:HookScript("OnSizeChanged", function() self:Update() end)
	frame:Hide()
end
Experience.OnEnable = function(self)
	self.stopped = nil
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_FACTION", "HONOR_XP_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
		self:RegisterEvent(event, "Update")
	end
	if ns.RegisterCallback then ns.RegisterCallback(self, "Minimap_Settings_Updated", "Update") end
	if ns.RegisterCallback then ns.RegisterCallback(self, "Minimap_Experience_Updated", "Update") end
	if ns.RegisterCallback then ns.RegisterCallback(self, "Relative_Scale_Updated", "Update") end
	if ns.RegisterCallback then ns.RegisterCallback(self, "Minimap_Scale_Updated", "Update") end
	if ns.RegisterCallback then ns.RegisterCallback(self, "OrbStyle_Updated", "Update") end
	self:Update()
end
Experience.OnDisable = function(self)
	self.stopped = true
	self.active = false
	self:SyncNativeBars()
	if self.frame then self.frame:Hide() end
	if self.hoverWatcher then self.hoverWatcher:Hide() end
	for object, alpha in pairs(self.originalAlpha or {}) do object:SetAlpha(alpha) end
	self.originalAlpha = setmetatable({}, { __mode = "k" })
end
