local Addon, ns = ...
if not ns.IsForever then return end
local Cathedral = {}
ns.CathedralTarget = Cathedral
ns.ForeverNativeFallbacks = ns.ForeverNativeFallbacks or {}
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local HEALTH_FILL = [[Interface\TargetingFrame\UI-StatusBar]]
local IsSecret = issecretvalue or function() return false end
local WIDTH = 330
local RATIO = WIDTH / 1352
local BODY_EDGE = 25.5
local EDGE_INSET = 10
local FACTION_ALLIANCE = [[Interface\TargetingFrame\UI-PVP-Alliance]]
local FACTION_HORDE = [[Interface\TargetingFrame\UI-PVP-Horde]]
-- Reserve side slots for level and faction while keeping the name centred.
local NAME_INSET = math.ceil(247 * RATIO) + 6
local HEALTH_MASK = "-crypt-health-mask"
local MANA_MASK = "-crypt-mana-mask"
local TOT_MASK = "-crypt-skull-tot-mask"
local BANDS = { { 0, 314, 314 * RATIO }, { 314, 374, 20 }, { 374, 425, 25 }, { 425, 474, 14 } }
local HEIGHT = 314 * RATIO + 59
local FOOTER_WIDTH, FOOTER_HEIGHT = 190, 40
local FOOTER_OVERLAP = 5
local FOOTER_DEPTH = FOOTER_HEIGHT - FOOTER_OVERLAP
local FOOTER_X, FOOTER_Y = FOOTER_WIDTH / 789, FOOTER_HEIGHT / 105
local AURA_GAP, CAST_GAP = 14, 12
local CAST_DEPTH = 20 * .88
local MainY = function(pixel)
	local offset = 0
	for _, band in ipairs(BANDS) do
		if pixel <= band[2] then return HEIGHT - offset - (pixel - band[1]) * band[3] / (band[2] - band[1]) end
		offset = offset + band[3]
	end
	return 0
end
local levelTag = ns.Prefix..":CathedralLevel"
ns.oUF.Tags.Events[levelTag] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"
local function DisplayedLevel(unit)
	local level = (UnitEffectiveLevel or UnitLevel)(unit)
	local wild, companion = UnitIsWildBattlePet(unit), UnitIsBattlePetCompanion(unit)
	if (not IsSecret(wild) and wild) or (not IsSecret(companion) and companion) then level = UnitBattlePetLevel(unit) end
	return level
end
ns.oUF.Tags.Methods[levelTag] = function(unit)
	local level = DisplayedLevel(unit)
	if IsSecret(level) then return C_StringUtil.RoundToNearestString(level) end
	return level and level > 0 and level or "??"
end
local IsActive = function()
	return ns.API.IsStoneStyle()
end
local Asset = function(name)
	return GetMedia("arahort-stone/target-cathedral"..name, "png")
end
local Capture = function(object)
	local state = { points = {}, width = object:GetWidth(), height = object:GetHeight(), alpha = object:GetAlpha() }
	for i = 1, object:GetNumPoints() do state.points[i] = { object:GetPoint(i) } end
	if object.GetFontObject then
		state.font = object:GetFontObject()
		state.justify = object:GetJustifyH()
		state.wrap = object:CanWordWrap()
	end
	if object.GetTexture then state.texture = object:GetTexture(); state.coords = { object:GetTexCoord() } end
	if object.GetStatusBarTexture then
		state.texture = object:GetStatusBarTexture():GetTexture()
		state.coords = { object:GetStatusBarTexture():GetTexCoord() }
	end
	return state
end
local Restore = function(object, state)
	object:ClearAllPoints()
	object:SetSize(state.width, state.height)
	for _, point in ipairs(state.points) do object:SetPoint(unpack(point)) end
	object:SetAlpha(state.alpha)
	if state.font then object:SetFontObject(state.font); object:SetJustifyH(state.justify); object:SetWordWrap(state.wrap) end
	if state.texture then
		if object.SetStatusBarTexture then object:SetStatusBarTexture(state.texture); object:GetStatusBarTexture():SetTexCoord(unpack(state.coords))
		else object:SetTexture(state.texture); object:SetTexCoord(unpack(state.coords)) end
	end
end
local Place = function(object, relative, width, height, x, y)
	object:ClearAllPoints()
	object:SetSize(width, height)
	object:SetPoint("BOTTOMLEFT", relative, "BOTTOMLEFT", x, y)
end
local Mask = function(texture, parent, name)
	local mask = parent:CreateMaskTexture(nil, "ARTWORK")
	mask:SetTexture(Asset(name), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(parent)
	texture:AddMaskTexture(mask)
	return mask
end
local ModelIsReady = function(model)
	local ok, fileID = pcall(model.GetModelFileID, model)
	return ok and not IsSecret(fileID) and type(fileID) == "number" and fileID > 0
end
local ShowModel = function(model)
	if not Cathedral.active then model:SetAlpha(0); ns.ForeverNativeFallbacks.CathedralPortrait = "disabled"; return end
	if model.cathedralAllowed and ModelIsReady(model) then
		model:SetPortraitZoom(1)
		model:SetCamDistanceScale(.85)
		model:SetPosition(0, 0, 0)
		model:SetAlpha(1)
		model.Fallback:SetAlpha(0)
		ns.ForeverNativeFallbacks.CathedralPortrait = "3d"
	else
		model:SetAlpha(model.cathedralAllowed and 1 or 0)
		model.Fallback:SetAlpha(1)
		ns.ForeverNativeFallbacks.CathedralPortrait = model.cathedralRestricted and "2d:identity" or "2d:loading"
	end
end
local PortraitUpdate = function(owner, event, unit)
	local model = owner.Portrait
	if not Cathedral.active then return end
	unit = Cathedral.editing and "player" or unit
	if not unit then return end
	local identitySecret = true
	if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret then
		local ok, restricted = pcall(C_Secrets.ShouldUnitIdentityBeSecret, unit)
		identitySecret = not ok or IsSecret(restricted) or restricted
	end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok or IsSecret(guid) then guid = nil end
	if not (C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret) then identitySecret = guid == nil end
	local changed = model.cathedralUnit ~= unit or model.cathedralGUID ~= guid or model.cathedralRestricted ~= identitySecret
	if not changed and event == "OnUpdate" then return end
	pcall(SetPortraitTexture, model.Fallback, unit)
	if not changed and event ~= "UNIT_MODEL_CHANGED" and event ~= "UNIT_PORTRAIT_UPDATE" and event ~= "PORTRAITS_UPDATED" then return end
	model.cathedralUnit, model.cathedralGUID, model.cathedralRestricted = unit, guid, identitySecret
	model.cathedralAllowed = false
	model:SetAlpha(0)
	model.Fallback:SetAlpha(1)
	model:ClearModel()
	if identitySecret or not UnitExists(unit) then ShowModel(model); return end
	model.cathedralAllowed = true
	model:SetAlpha(1)
	local loaded, success = pcall(model.SetUnit, model, unit)
	if not loaded or (not IsSecret(success) and success == false) then model.cathedralAllowed = false end
	ShowModel(model)
end
Cathedral.InstallTarget = function(self, frame)
	if frame.Cathedral then return end
	local state = {}
	frame.Cathedral = state
	state.original = { frame = Capture(frame), backdrop = Capture(frame.Backdrop), health = Capture(frame.Health), preview = Capture(frame.Health.Preview), value = Capture(frame.Health.Value), name = Capture(frame.Name) }
	local art = CreateFrame("Frame", nil, frame)
	art:SetAllPoints(frame)
	art:SetFrameLevel(frame.Health:GetFrameLevel() + 3)
	state.art = art
	state.textures = {}
	local function layer(suffix, x, width, top, height, coords, sublevel, parent)
		local texture = (parent or art):CreateTexture(nil, "ARTWORK", nil, sublevel)
		texture:SetTexture(Asset(suffix), "CLAMP", "CLAMP")
		texture:SetTexCoord(unpack(coords))
		texture:SetSize(width, height)
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -top)
		state.textures[#state.textures + 1] = { texture, suffix, coords }
		return texture
	end
	state.main = layer("-crypt-frame", 0, WIDTH, 0, HEIGHT, { 0, 1, 0, 1 }, 0)
	local factionArt = CreateFrame("Frame", nil, art)
	factionArt:SetAllPoints(frame)
	factionArt:SetFrameLevel(art:GetFrameLevel() + 1)
	factionArt:EnableMouse(false)
	state.factionArt = factionArt
	local factionIcon = factionArt:CreateTexture(nil, "OVERLAY")
	factionIcon:SetSize(22, 22)
	factionIcon:SetTexCoord(0, .65625, 0, .65625)
	-- Centre of the name-band interior in the actual 543px Crypt frame.
	factionIcon:SetPoint("RIGHT", frame, "BOTTOMLEFT", WIDTH - BODY_EDGE - EDGE_INSET, HEIGHT * (1 - 330 / 543))
	state.factionIcon = factionIcon
	factionArt:Hide()
	state.crest = art:CreateTexture(nil, "OVERLAY")
	state.crest:SetTexture(Asset("-elite"))
	state.crest:SetSize(40, 40 * 102 / 249)
	state.crest:SetPoint("TOP", state.main, "TOP", 0, -3.4)
	state.level = art:CreateFontString(nil, "OVERLAY")
	state.level:SetFont(STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]], 12, "OUTLINE")
	state.level:SetSize(25, 20)
	state.level:SetWordWrap(false)
	state.level:SetMaxLines(1)
	state.level:SetJustifyH("LEFT")
	state.level:SetJustifyV("MIDDLE")
	state.level:SetPoint("LEFT", frame, "BOTTOMLEFT", BODY_EDGE + EDGE_INSET, MainY(337) + 1.5)
	state.level:SetTextColor(.94, .88, .76)
	state.level:SetShadowColor(0, 0, 0, .8)
	state.level:SetShadowOffset(.5, -.5)
	frame:Tag(state.level, "["..levelTag.."]")
	state.name = art:CreateFontString(nil, "OVERLAY")
	state.name:SetFontObject(GetFont(16, true))
	state.name:SetSize(WIDTH - 2 * NAME_INSET, 20)
	state.name:SetJustifyH("CENTER")
	state.name:SetJustifyV("MIDDLE")
	state.name:SetPoint("CENTER", frame, "BOTTOM", 0, MainY(337))
	state.name:SetWordWrap(false)
	state.name:SetMaxLines(1)
	state.name:SetTextColor(unpack(ns.Colors.offwhite))
	frame:Tag(state.name, "[name]")
	state.value = art:CreateFontString(nil, "OVERLAY")
	state.value:SetFontObject(GetFont(16, true))
	state.value:SetSize(260, 22)
	state.value:SetJustifyH("CENTER")
	state.value:SetJustifyV("MIDDLE")
	-- The outlined glyphs sit below the font box's visual center.
	state.value:SetPoint("CENTER", frame, "BOTTOM", 0, MainY(399) + 1.5)
	state.value:SetWordWrap(false)
	state.value:SetTextColor(unpack(ns.Colors.offwhite))
	frame:Tag(state.value, "["..ns.Prefix..":Health]")
	local portraitHost = CreateFrame("Frame", nil, frame)
	portraitHost:SetFrameLevel(frame:GetFrameLevel() + 1)
	portraitHost:SetSize(238 * RATIO, 238 * RATIO)
	portraitHost:SetPoint("CENTER", frame, "BOTTOMLEFT", WIDTH / 2, MainY(210))
	state.portraitHost = portraitHost
	local black = portraitHost:CreateTexture(nil, "BACKGROUND")
	black:SetAllPoints()
	black:SetColorTexture(.025, .025, .025, 1)
	local circle = portraitHost:CreateMaskTexture(nil, "ARTWORK")
	circle:SetTexture([[Interface\CHARACTERFRAME\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	circle:SetAllPoints()
	black:AddMaskTexture(circle)
	local fallback = portraitHost:CreateTexture(nil, "ARTWORK")
	fallback:SetAllPoints()
	fallback:SetTexCoord(.08, .92, .08, .92)
	fallback:AddMaskTexture(circle)
	local portrait = CreateFrame("PlayerModel", nil, portraitHost)
	portrait:SetSize(40.5, 40.5)
	portrait:SetPoint("CENTER", 0, 1)
	portrait:SetFrameLevel(portraitHost:GetFrameLevel() + 1)
	portrait.Fallback = fallback
	portrait.Override = PortraitUpdate
	portrait:SetScript("OnModelLoaded", ShowModel)
	frame.Portrait = portrait
	local power = CreateFrame("StatusBar", nil, frame)
	power:SetFrameLevel(frame.Health:GetFrameLevel())
	power:SetStatusBarTexture(Asset("-fill"))
	power.colorPower = true
	power.frequentUpdates = true
	Place(power, frame, 1062 * RATIO, MainY(433) - MainY(447), 144 * RATIO, MainY(447))
	state.powerMask = Mask(power:GetStatusBarTexture(), power, MANA_MASK)
	local powerBack = power:CreateTexture(nil, "BACKGROUND")
	powerBack:SetAllPoints()
	powerBack:SetColorTexture(.025, .025, .025, 1)
	powerBack:AddMaskTexture(state.powerMask)
	frame.Power = power
	state.healthMask = Mask(frame.Health:GetStatusBarTexture(), frame.Health, HEALTH_MASK)
	frame.Health.Preview:GetStatusBarTexture():AddMaskTexture(state.healthMask)
	local healthBack = frame.Health:CreateTexture(nil, "BACKGROUND")
	healthBack:SetAllPoints()
	healthBack:SetColorTexture(.055, .015, .015, 1)
	healthBack:AddMaskTexture(state.healthMask)
	state.healthBack = healthBack
	state.nativeHealth = ns.CathedralHealth.Install(frame, HEALTH_FILL, Asset(HEALTH_MASK))
	state.castbar = ns.CathedralCastbar.Install(frame)
	art:Hide()
	portraitHost:Hide()
	healthBack:Hide()
	hooksecurefunc(frame, "SetScale", function() self:SyncScale() end)
end
Cathedral.InstallToT = function(self, frame)
	local state = { original = { frame = Capture(frame), bg = Capture(frame.Bg), health = Capture(frame.Health), preview = Capture(frame.Health.Preview), value = Capture(frame.Health.Value) } }
	frame.Cathedral = state
	state.predictionTexture = frame.HealthPrediction:GetTexture()
	local art = CreateFrame("Frame", nil, frame)
	art:SetAllPoints(frame)
	art:SetFrameLevel(frame.Health:GetFrameLevel() + 3)
	state.art = art
	state.textures = ns.API.CreateCathedralFooterTextures(art, frame, Asset("-crypt-skull-tot"), FOOTER_WIDTH, FOOTER_HEIGHT)
	state.name = art:CreateFontString(nil, "OVERLAY")
	state.name:SetFontObject(GetFont(13, true))
	state.name:SetSize(112, 17)
	state.name:SetJustifyH("CENTER")
	state.name:SetJustifyV("MIDDLE")
	state.name:SetPoint("CENTER", frame, "BOTTOM", 0, 68 * FOOTER_Y)
	state.name:SetWordWrap(false)
	state.name:SetMaxLines(1)
	state.name:SetTextColor(unpack(ns.Colors.offwhite))
	frame:Tag(state.name, "[name]")
	state.value = art:CreateFontString(nil, "OVERLAY")
	state.value:SetFontObject(GetFont(11, true))
	state.value:SetSize(106, 14)
	state.value:SetJustifyH("CENTER")
	state.value:SetJustifyV("MIDDLE")
	state.value:SetTextColor(unpack(ns.Colors.offwhite))
	state.value:SetPoint("CENTER", frame, "BOTTOM", 0, 34 * FOOTER_Y)
	frame:Tag(state.value, "["..ns.Prefix..":HealthPercent]")
	state.mask = Mask(frame.Health:GetStatusBarTexture(), frame.Health, TOT_MASK)
	frame.Health.Preview:GetStatusBarTexture():AddMaskTexture(state.mask)
	frame.HealthPrediction:AddMaskTexture(state.mask)
	local background = frame.Health:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(.015, .04, .01, 1)
	background:AddMaskTexture(state.mask)
	state.healthBack = background
	state.nativeHealth = ns.CathedralHealth.Install(frame, HEALTH_FILL, Asset(TOT_MASK))
	art:Hide()
	background:Hide()
	hooksecurefunc(frame, "SetScale", function() self:SyncScale() end)
end
Cathedral.UpdateLevelColor = function(self)
	local state = self.target and self.target.Cathedral
	if not self.active or not state then return end
	local color = HIGHLIGHT_FONT_COLOR
	local level = DisplayedLevel("target")
	local playerLevel = (UnitEffectiveLevel or UnitLevel)("player")
	if not IsSecret(level) and not IsSecret(playerLevel) and type(level) == "number" and type(playerLevel) == "number" and GetCreatureDifficultyColor then
		color = GetCreatureDifficultyColor(level > 0 and level or 999) or color
	end
	state.level:SetTextColor(color.r, color.g, color.b)
end
Cathedral.UpdateFaction = function(self)
	local state = self.target and self.target.Cathedral
	if not state or not state.factionArt then return end
	state.factionArt:Hide()
	if not self.active then return end
	local player = UnitIsPlayer("target")
	if IsSecret(player) or not player then return end
	local faction = UnitFactionGroup("target")
	if IsSecret(faction) then return end
	if faction == "Alliance" then
		state.factionIcon:SetTexture(FACTION_ALLIANCE)
	elseif faction == "Horde" then
		state.factionIcon:SetTexture(FACTION_HORDE)
	else
		return
	end
	state.factionArt:Show()
end
Cathedral.UpdateArtwork = function(self, frame)
	if not self.active or not frame.Cathedral then return false end
	local classification = UnitClassification(frame.__unit or "target")
	frame.Cathedral.crest:SetShown(classification == "elite" or classification == "rareelite" or classification == "worldboss" or classification == "rare")
	frame.Backdrop:SetAlpha(0)
	return true
end
Cathedral.SyncScale = function(self)
	if self.scaling or not self.active or not self.target or not self.tot then return end
	if InCombatLockdown() then self.pending = true; return end
	self.scaling = true
	local scale = self.target:GetEffectiveScale()
	if IsSecret(scale) then self.pending = true; self.scaling = nil; return end
	self.tot:SetScale(scale)
	local layout = self.target.Cathedral.layout
	if layout then
		layout.castDock:SetScale(scale)
		layout.auraDock:SetScale(scale)
	end
	self.scaling = nil
end
local LAYOUT_STATE = [[
local preview = self:GetAttribute("layout-preview") and self:GetAttribute("state-combat") ~= "combat"
local depth = (self:GetAttribute("state-unitexists") or preview) and self:GetAttribute("footer-depth") or 0
if preview or self:GetAttribute("state-combo") == "show" then
	depth = depth + (self:GetAttribute("combo-depth") or 0)
end
self:ClearAllPoints()
self:SetPoint("TOP", self:GetFrameRef("target"), "BOTTOM", 0, -depth)
]]
local function DockAccess(dock)
	local flags, reason = {}, nil
	for _, check in ipairs({ { "protected", "IsProtected" }, { "restricted", "IsAnchoringRestricted" }, { "constraints", "HasAccessConstraints" }, { "forbidden", "HasAnyForbiddenAspects" } }) do
		local ok, value, explicit = pcall(dock[check[2]], dock)
		if not ok or IsSecret(value) or type(value) ~= "boolean" then
			flags[check[1]] = "unavailable"
			reason = reason or check[1]..":unavailable"
		else
			flags[check[1]] = value
			if value then reason = reason or check[1] end
		end
		if check[1] == "protected" then flags.explicit = IsSecret(explicit) and "secret" or explicit end
	end
	return reason == nil, flags, reason
end
local function ComboDriver(depth)
	if depth == 0 then return "hide" end
	local combo = ns.ForeverComboPoints
	if combo and combo.class == "DRUID" then
		for index = 1, GetNumShapeshiftForms() do
			local _, _, _, spellID = GetShapeshiftFormInfo(index)
			if not IsSecret(spellID) and spellID == 768 then
				return "[@target,exists,harm,form:"..index.."]show;hide"
			end
		end
		return "hide"
	end
	return "[@target,exists,harm]show;hide"
end
Cathedral.UpdateLayoutPresentation = function(self, frame)
	frame = frame or self.target
	local layout = frame and frame.Cathedral and frame.Cathedral.layout
	if not self.active or not layout or not layout.ready or layout.configuring then return end
	local castAllowed, castFlags, castReason = DockAccess(layout.castDock)
	local auraAllowed, auraFlags, auraReason = DockAccess(layout.auraDock)
	local report = { mode = "reserved", castDock = castFlags, auraDock = auraFlags, totSuppressed = self.totSuppressed == true }
	ns.ForeverNativeFallbacks.targetAuraLayout = report
	if not castAllowed or not auraAllowed then
		report.reason = castReason and "cast:"..castReason or "auras:"..auraReason
		if layout.compact then report.mode = "blocked-pending" end
		if InCombatLockdown() then self.pending = true end
		return
	end
	local exists = layout.anchor:GetAttribute("state-unitexists")
	local combat = layout.anchor:GetAttribute("state-combat")
	local combo = layout.anchor:GetAttribute("state-combo")
	local preview = layout.anchor:GetAttribute("layout-preview")
	if IsSecret(exists) or IsSecret(combat) or IsSecret(combo) or IsSecret(preview) then
		report.reason = "state:secret"
		return
	end
	preview = preview and combat ~= "combat"
	local comboDepth = (preview or combo == "show") and layout.comboDepth or 0
	-- UnitWatch sees duplicate ToT units too; their existing presentation policy sets alpha to zero.
	local suppressedDepth = exists and self.totSuppressed and not preview and FOOTER_DEPTH or 0
	local comboBlocked = comboDepth > 0 and ns.ForeverComboPoints and ns.ForeverComboPoints.placementDeferred
	if comboBlocked then suppressedDepth = 0; report.reason = "combo-placement:deferred" end
	local base = -suppressedDepth
	local castOffset = base + CAST_GAP
	local auraOffset = base + AURA_GAP + (layout.below and CAST_GAP + CAST_DEPTH or 0)
	if layout.castOffset ~= castOffset then
		layout.castDock:ClearAllPoints()
		layout.castDock:SetPoint("TOP", layout.anchor, "TOP", 0, -castOffset)
		layout.castOffset = castOffset
	end
	if layout.auraOffset ~= auraOffset then
		layout.auraDock:ClearAllPoints()
		layout.auraDock:SetPoint("TOP", layout.anchor, "TOP", 0, -auraOffset)
		layout.auraOffset = auraOffset
	end
	layout.compact = suppressedDepth > 0
	report.mode, report.comboDepth, report.suppressedDepth = comboBlocked and "reserved-combo" or "dynamic", comboDepth, suppressedDepth
	report.totExists, report.comboState = exists, combo
end
local CreateLayout = function(frame)
	local anchor = CreateFrame("Frame", nil, frame, "SecureHandlerStateTemplate")
	anchor:SetSize(1, 1)
	anchor:EnableMouse(false)
	anchor:SetFrameRef("target", frame)
	anchor:SetAttribute("unit", "targettarget")
	anchor:SetAttribute("footer-depth", FOOTER_DEPTH)
	anchor:SetAttribute("combo-depth", 0)
	anchor:SetAttribute("_onstate-unitexists", LAYOUT_STATE)
	anchor:SetAttribute("_onstate-combat", LAYOUT_STATE)
	anchor:SetAttribute("_onstate-combo", LAYOUT_STATE)
	local castDock = CreateFrame("Frame", nil, UIParent)
	castDock:SetSize(1, 1)
	castDock:EnableMouse(false)
	castDock:SetIgnoreParentScale(true)
	local auraDock = CreateFrame("Frame", nil, UIParent)
	auraDock:SetSize(1, 1)
	auraDock:EnableMouse(false)
	auraDock:SetIgnoreParentScale(true)
	anchor:HookScript("OnAttributeChanged", function(_, name)
		if name == "state-unitexists" or name == "state-combat" or name == "state-combo" then
			Cathedral:UpdateLayoutPresentation(frame)
		end
	end)
	return { anchor = anchor, castDock = castDock, auraDock = auraDock }
end
Cathedral.LayoutTarget = function(self, frame, show, aboveName)
	local state = frame.Cathedral
	local layout = state and state.layout
	if not self.active then
		if layout and layout.bound then
			if InCombatLockdown() then self.pending = true; return true end
			UnregisterUnitWatch(layout.anchor)
			UnregisterStateDriver(layout.anchor, "combat")
			UnregisterStateDriver(layout.anchor, "combo")
			layout.watching, layout.bound = nil, nil
			layout.comboCondition = nil
		end
		return false
	end
	if InCombatLockdown() then self.pending = true; return true end
	if not layout then
		layout = CreateLayout(frame)
		state.layout = layout
	end
	local comboDepth = ns.ForeverComboPoints and ns.ForeverComboPoints:GetTargetDepth(0) or 0
	local below = show and not aboveName
	local auraDepth = AURA_GAP + (below and CAST_GAP + CAST_DEPTH or 0)
	local scale = frame:GetEffectiveScale()
	if IsSecret(scale) then self.pending = true; return true end
	layout.configuring = true
	layout.comboDepth, layout.below = comboDepth, below
	layout.anchor:SetAttribute("combo-depth", comboDepth)
	layout.castDock:SetScale(scale)
	layout.auraDock:SetScale(scale)
	-- Establish the conservative reserve before binding. A blocked dock must never start compact.
	layout.castDock:ClearAllPoints()
	layout.castDock:SetPoint("TOP", layout.anchor, "TOP", 0, -CAST_GAP)
	layout.auraDock:ClearAllPoints()
	layout.auraDock:SetPoint("TOP", layout.anchor, "TOP", 0, -auraDepth)
	layout.castOffset, layout.auraOffset, layout.compact = CAST_GAP, auraDepth, false
	local cast = frame.Castbar
	cast:ClearAllPoints()
	if show and aboveName then
		cast:SetPoint("BOTTOM", frame, "TOP", 0, 8)
	else
		cast:SetPoint("TOP", layout.castDock, "TOP", 0, 0)
	end
	if not layout.bound then
		-- Only an upstream anchor changes in combat, never aura geometry or its parent.
		frame.Auras:ClearAllPoints()
		frame.Auras:SetPoint("TOP", layout.auraDock, "TOP", 0, 0)
		layout.bound = true
	end
	layout.anchor:SetAttribute("layout-preview", self.editing and true or false)
	if not layout.watching then
		-- Combat always overrides a stale EditMode preview flag after an automatic exit.
		RegisterStateDriver(layout.anchor, "combat", "[combat]combat;peace")
		RegisterUnitWatch(layout.anchor, true)
		layout.watching = true
	end
	local comboCondition = ComboDriver(comboDepth)
	if layout.comboCondition ~= comboCondition then
		RegisterStateDriver(layout.anchor, "combo", comboCondition)
		layout.comboCondition = comboCondition
	end
	layout.anchor:Execute(LAYOUT_STATE)
	layout.ready, layout.configuring = true, nil
	self:UpdateLayoutPresentation(frame)
	return true
end
Cathedral.UpdateTextures = function(self)
	local target, tot = self.target, self.tot
	local state, footer = target.Cathedral, tot.Cathedral
	for _, textures in ipairs({ state.textures, footer.textures }) do
		for _, entry in ipairs(textures) do
			entry[1]:SetTexture(Asset(entry[2]), "CLAMP", "CLAMP")
			entry[1]:SetTexCoord(unpack(entry[3]))
		end
	end
	state.crest:SetTexture(Asset("-elite"))
	target.Power:SetStatusBarTexture(Asset("-fill"))
	tot.HealthPrediction:SetTexture(Asset("-fill"))
	for _, entry in ipairs({ { state.healthMask, HEALTH_MASK }, { state.nativeHealth.mask, HEALTH_MASK }, { state.powerMask, MANA_MASK }, { footer.mask, TOT_MASK }, { footer.nativeHealth.mask, TOT_MASK } }) do
		entry[1]:SetTexture(Asset(entry[2]), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	ns.CathedralCastbar.SetActive(state.castbar, true)
end
Cathedral.Apply = function(self)
	if InCombatLockdown() then self.pending = true; return end
	if not self.target or not self.tot then return end
	local active = IsActive() and true or false
	self.pending = nil
	if self.active == active then
		if active then self:UpdateTextures() end
		self:UpdateFaction()
		self:UpdateLevelColor()
		self:SyncScale()
		if self.target.UpdateTargetCastbar then self.target:UpdateTargetCastbar() end
		return
	end
	self.active = active
	local target, tot = self.target, self.tot
	local state, footer = target.Cathedral, tot.Cathedral
	if active then
		target:SetSize(WIDTH, HEIGHT)
		Place(target.Health, target, 1092 * RATIO, MainY(380) - MainY(418), 130 * RATIO, MainY(418))
		Place(target.Health.Preview, target.Health, 1092 * RATIO, MainY(380) - MainY(418), 0, 0)
		target.Health:SetStatusBarTexture(Asset("-fill"))
		target.Health:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
		target.Health.Preview:SetStatusBarTexture(Asset("-fill"))
		target.Health.Preview:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
		target.Name:SetAlpha(0)
		target.Health.Value:SetAlpha(0)
		state.art:Show()
		state.portraitHost:Show()
		state.healthBack:Show()
		target:EnableElement("Portrait")
		target:EnableElement("Power")
		tot:SetSize(FOOTER_WIDTH, FOOTER_HEIGHT)
		tot:ClearAllPoints()
		tot:SetPoint("TOP", target, "BOTTOM", 0, FOOTER_OVERLAP)
		tot.Bg:SetAlpha(0)
		Place(tot.Health, tot, 450 * FOOTER_X, 16 * FOOTER_Y, 170 * FOOTER_X, 26 * FOOTER_Y)
		Place(tot.Health.Preview, tot.Health, 450 * FOOTER_X, 16 * FOOTER_Y, 0, 0)
		tot.Health:SetStatusBarTexture(Asset("-fill"))
		tot.Health.Preview:SetStatusBarTexture(Asset("-fill"))
		tot.Health:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
		tot.Health.Preview:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
		tot.HealthPrediction:SetTexture(Asset("-fill"))
		tot.Health.Value:SetAlpha(0)
		footer.art:Show()
		footer.healthBack:Show()
		self:SyncScale()
		self:UpdateArtwork(target)
		PortraitUpdate(target, "ForceUpdate", target.__unit)
	else
		state.art:Hide()
		state.portraitHost:Hide()
		state.healthBack:Hide()
		footer.art:Hide()
		footer.healthBack:Hide()
		target:DisableElement("Power")
		target:DisableElement("Portrait")
		ns.ForeverNativeFallbacks.CathedralPortrait = "disabled"
		target:SetSize(state.original.frame.width, state.original.frame.height)
		Restore(target.Backdrop, state.original.backdrop)
		Restore(target.Health, state.original.health)
		Restore(target.Health.Preview, state.original.preview)
		target.Health.Value:SetAlpha(state.original.value.alpha)
		target.Name:SetAlpha(state.original.name.alpha)
		Restore(tot, footer.original.frame)
		Restore(tot.Bg, footer.original.bg)
		Restore(tot.Health, footer.original.health)
		Restore(tot.Health.Preview, footer.original.preview)
		tot.Health.Value:SetAlpha(footer.original.value.alpha)
		tot.HealthPrediction:SetTexture(footer.predictionTexture)
		ns.API.SetUnitFramesObjectScale(tot)
		target:PostUpdate()
	end
	if active then self:UpdateTextures() end
	ns.CathedralHealth.SetActive(state.nativeHealth, active)
	local fillBar = active and state.nativeHealth.bar or target.Health:GetNativeStatusBar()
	local fill = fillBar:GetStatusBarTexture()
	local prediction = target.HealthPrediction
	prediction.healingAll:SetPoint("LEFT", fill, "RIGHT")
	prediction.healAbsorb:SetPoint("RIGHT", fill, "RIGHT")
	for _, bar in ipairs({ prediction.healingAll, prediction.healAbsorb }) do
		local texture = bar:GetStatusBarTexture()
		if active then
			texture:AddMaskTexture(state.nativeHealth.mask)
		else
			texture:RemoveMaskTexture(state.nativeHealth.mask)
		end
	end
	ns.CathedralHealth.SetActive(footer.nativeHealth, active)
	ns.CathedralCastbar.SetActive(state.castbar, active)
	state.healthMask:SetAlpha(active and 1 or 0)
	footer.mask:SetAlpha(active and 1 or 0)
	if not active then
		target.Health:GetStatusBarTexture():RemoveMaskTexture(state.healthMask)
		target.Health.Preview:GetStatusBarTexture():RemoveMaskTexture(state.healthMask)
		tot.Health:GetStatusBarTexture():RemoveMaskTexture(footer.mask)
		tot.Health.Preview:GetStatusBarTexture():RemoveMaskTexture(footer.mask)
		tot.HealthPrediction:RemoveMaskTexture(footer.mask)
	else
		target.Health:GetStatusBarTexture():AddMaskTexture(state.healthMask)
		target.Health.Preview:GetStatusBarTexture():AddMaskTexture(state.healthMask)
		tot.Health:GetStatusBarTexture():AddMaskTexture(footer.mask)
		tot.Health.Preview:GetStatusBarTexture():AddMaskTexture(footer.mask)
		tot.HealthPrediction:AddMaskTexture(footer.mask)
	end
	if target.UpdateTargetCastbar then target:UpdateTargetCastbar() end
	self:UpdateFaction()
	self:UpdateLevelColor()
	target:UpdateAllElements("ForceUpdate")
	tot:UpdateAllElements("ForceUpdate")
end
Cathedral.Initialize = function(self, target, tot)
	self.target, self.tot = target, tot
	self.totSuppressed = nil
	if not InCombatLockdown() then
		local alpha = tot:GetAlpha()
		if not IsSecret(alpha) then self.totSuppressed = alpha == 0 end
	end
	hooksecurefunc(tot, "SetAlpha", function(_, alpha)
		if IsSecret(alpha) then self.totSuppressed = nil
		else self.totSuppressed = alpha == 0 end
		local combo = ns.ForeverComboPoints
		if combo and combo.targetRow then combo:UpdatePlacement() end
		self:UpdateLayoutPresentation()
	end)
	tot.Cathedral.original.frame = Capture(tot)
	self:Apply()
	if ns.LibEditMode and ns.LibEditMode.RegisterCallback then
		ns.LibEditMode:RegisterCallback("enter", function()
			self.editing = true
			if self.active then PortraitUpdate(target, "ForceUpdate", "player") end
			if self.active and target.UpdateTargetCastbar then target:UpdateTargetCastbar() end
		end)
		ns.LibEditMode:RegisterCallback("exit", function()
			self.editing = nil
			if self.active then PortraitUpdate(target, "ForceUpdate", target.__unit) end
			if self.active and target.UpdateTargetCastbar then target:UpdateTargetCastbar() end
		end)
	end
end
local OriginalToT = ns.UnitStyles.ToT
ns.UnitStyles.ToT = function(frame, ...)
	OriginalToT(frame, ...)
	Cathedral:InstallToT(frame)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterUnitEvent("UNIT_LEVEL", "target")
events:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", "target")
events:RegisterUnitEvent("UNIT_FACTION", "target")
events:RegisterUnitEvent("UNIT_FLAGS", "target")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and Cathedral.pending then Cathedral:Apply() end
	Cathedral:UpdateFaction()
	Cathedral:UpdateLevelColor()
end)
ns.RegisterCallback(Cathedral, "OrbStyle_Updated", "Apply")
