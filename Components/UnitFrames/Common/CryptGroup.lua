local Addon, ns = ...
if not ns.IsForever then return end
local CryptGroup = {}
ns.CryptGroup = CryptGroup
local frames = setmetatable({}, { __mode = "k" })
local GetMedia = ns.API.GetMedia
local portraitWidth, portraitHeight = 953, 1207
local apertureX, apertureY = 474.5, 688.5
local apertureWidth, apertureHeight = 729, 749
local portraitDiameter = 76
local barWidth, barHeight = 917, 167
local wellLeft, wellTop, wellRight, wellBottom = 48, 46, 869, 120
local styleQueue = CreateFrame("Frame")
local function GetStyle()
	return ns.db and ns.db.global.orbs.style
end
local function SetPiecesShown(pieces, shown)
	for _, piece in ipairs(pieces) do
		piece.texture:SetShown(shown)
	end
end
local function MakeBezel(bar, backdrop, edgeWidth, edgeHeight)
	-- Keep the bevels and corners fixed while the existing bar sliders resize the wells.
	edgeWidth, edgeHeight = edgeWidth or 5, edgeHeight or 4
	local horizontal = {
		{ "LEFT", "LEFT", -edgeWidth, 0, 0, wellLeft / barWidth },
		{ "LEFT", "RIGHT", 0, 0, wellLeft / barWidth, wellRight / barWidth },
		{ "RIGHT", "RIGHT", 0, edgeWidth, wellRight / barWidth, 1 }
	}
	local vertical = {
		{ "TOP", "TOP", edgeHeight, 0, 0, wellTop / barHeight },
		{ "TOP", "BOTTOM", 0, 0, wellTop / barHeight, wellBottom / barHeight },
		{ "BOTTOM", "BOTTOM", 0, -edgeHeight, wellBottom / barHeight, 1 }
	}
	local pieces = {}
	for _, y in ipairs(vertical) do
		for _, x in ipairs(horizontal) do
			local piece = backdrop:CreateTexture(nil, "ARTWORK", nil, 2)
			piece:SetPoint("TOPLEFT", bar, y[1]..x[1], x[3], y[3])
			piece:SetPoint("BOTTOMRIGHT", bar, y[2]..x[2], x[4], y[4])
			piece:Hide()
			pieces[#pieces + 1] = { texture = piece, coords = { x[5], x[6], y[5], y[6] } }
		end
	end
	return pieces
end
CryptGroup.CreateBarBorder = MakeBezel
local function ApplyPalette(skin)
	local ready = skin.portrait:SetTexture(GetMedia("arahort-stone/group-crypt-portrait", "png")) ~= false
	local bar = GetMedia("arahort-stone/group-crypt-bar", "png")
	for _, pieces in ipairs({ skin.healthPieces, skin.powerPieces }) do
		for _, piece in ipairs(pieces) do
			if piece.texture:SetTexture(bar, "CLAMP", "CLAMP") == false then ready = false end
			piece.texture:SetTexCoord(unpack(piece.coords))
		end
	end
	return ready
end
local function Apply(frame, skin, style, initializing)
	local active = skin.baseReady and ns.API.IsStoneStyle(style)
	if active and skin.style ~= style then
		active = ApplyPalette(skin)
		skin.style = active and style or nil
	end
	if skin.active == active then return end
	skin.active = active
	frame.Portrait.Border:SetShown(not active)
	frame.Portrait.Bg:SetShown(not active)
	frame.Portrait.Shade:SetShown(not active)
	frame.GroupRoleIndicator.Backdrop:SetShown(not active)
	frame.HealthBackdrop:SetShown(not active)
	-- Power visibility is controlled by the existing Power.PostUpdate.
	frame.PowerBackdrop:SetAlpha(active and 0 or skin.powerBackdropAlpha)
	skin.portrait:SetShown(active)
	skin.backing:SetShown(active)
	skin.highlight:SetShown(active)
	SetPiecesShown(skin.healthPieces, active)
	SetPiecesShown(skin.powerPieces, active and frame.PowerBackdrop:IsShown())
	if not initializing then
		frame.Name:ClearAllPoints()
		frame.Auras:ClearAllPoints()
	end
	if active then
		frame.Name:SetPoint("TOP", frame, "BOTTOM", 0, 3)
	else
		frame.Name:SetPoint("BOTTOM", frame.Health, "TOP", 0, 3)
	end
	-- Leave room for the largest name font without anchoring to the unit's secret text.
	frame.Auras:SetPoint("TOP", frame, "BOTTOM", 0, active and -27 or -4)
end
CryptGroup.Install = function(frame, portraitFrame, portraitOverlay, backdrop)
	local skin = {}
	frames[frame] = skin
	local model = frame.Portrait
	local scaleX, scaleY = portraitDiameter / apertureWidth, portraitDiameter / apertureHeight
	local portrait = portraitOverlay:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(portraitWidth * scaleX, portraitHeight * scaleY)
	portrait:SetPoint("TOPLEFT", model, "CENTER", -apertureX * scaleX, apertureY * scaleY)
	skin.portrait = portrait
	-- The backing sprite's circle is centered at (129,126) on its 256-pixel canvas.
	local backing = portraitFrame:CreateTexture(nil, "BACKGROUND")
	local backingReady = backing:SetTexture(GetMedia("UnitFrames/Group/party_portrait_back")) ~= false
	backing:SetSize(136, 136)
	backing:SetPoint("CENTER", model, "CENTER", -136 / 256, -272 / 256)
	backing:SetVertexColor(.5, .5, .5)
	skin.backing = backing
	-- A separate rim pass keeps the statues neutral on selection.
	local highlight = portraitOverlay:CreateTexture(nil, "OVERLAY")
	local highlightReady = highlight:SetTexture(GetMedia("arahort-stone/group-crypt-ring-highlight", "png")) ~= false
	highlight:SetAllPoints(portrait)
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(.84, .54, .20)
	highlight:SetAlpha(0)
	skin.highlight = highlight
	local bezel = CreateFrame("Frame", nil, backdrop)
	bezel:SetFrameLevel(frame.Health:GetFrameLevel() + 1)
	bezel:SetAllPoints()
	skin.healthPieces = MakeBezel(frame.Health, bezel)
	skin.powerPieces = MakeBezel(frame.Power, bezel)
	skin.baseReady = backingReady and highlightReady
	skin.powerBackdropAlpha = frame.PowerBackdrop:GetAlpha()
	Apply(frame, skin, GetStyle(), true)
end
CryptGroup.SetPowerShown = function(frame, shown)
	local skin = frames[frame]
	if skin and skin.active then SetPiecesShown(skin.powerPieces, shown) end
end
CryptGroup.SetTarget = function(frame, selected)
	local skin = frames[frame]
	if skin then skin.highlight:SetAlphaFromBoolean(selected, .33, 0) end
end
CryptGroup.Refresh = function()
	if InCombatLockdown() then
		styleQueue:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	styleQueue:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local style = GetStyle()
	for frame, skin in pairs(frames) do
		Apply(frame, skin, style)
	end
end
styleQueue:SetScript("OnEvent", CryptGroup.Refresh)
ns.RegisterCallback(CryptGroup, "OrbStyle_Updated", "Refresh")
