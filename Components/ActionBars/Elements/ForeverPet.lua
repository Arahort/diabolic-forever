local Addon, ns = ...
if not ns.IsForever then return end
local Pets = ns:GetModule("ActionBars"):NewModule("ForeverPet", "LibMoreEvents-1.0")
ns.ForeverPets = Pets
local GetMedia = ns.API.GetMedia
local L = ns.L
local isSecret = issecretvalue or function() return false end
local icons = {
	HUNTER = { "Ability_GhoulFrenzy", "Ability_Tracking", "Spell_Nature_TimeStop", "Ability_Hunter_Pet_Bear", "Ability_Druid_Dash", "Ability_Physical_Taunt", "Ability_Hunter_Pet_Wolf", "Ability_Defend", "Ability_Hunter_Pet_Assist", "Ability_Seal" },
	WARLOCK = { "Ability_GhoulFrenzy", "Ability_Tracking", "Spell_Nature_TimeStop", "Spell_Fire_FireBolt", "Spell_Shadow_BloodBoil", "Spell_Shadow_SummonVoidWalker", "Spell_Shadow_Seduction", "Ability_Defend", "Ability_Hunter_Pet_Assist", "Ability_Seal" },
	DEFAULT = { "Ability_GhoulFrenzy", "Ability_Tracking", "Spell_Nature_TimeStop", "Spell_Frost_FrostBolt02", "Spell_Frost_FrostNova", "Spell_Shadow_AnimateDead", "Ability_Physical_Taunt", "Ability_Defend", "Ability_Hunter_Pet_Assist", "Ability_Seal" }
}
local function ClassKey(value)
	value = value and value:upper() or UnitClassBase("player")
	return icons[value] and value or "DEFAULT"
end
local function ClassName(key)
	return key == "DEFAULT" and L["PetPreviewDefault"] or LOCALIZED_CLASS_NAMES_MALE[key]
end
local function SetPoint(frame, ...)
	local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
	local set = frame.SetPointBase or frame.SetPoint
	clear(frame)
	set(frame, ...)
end
local function SetScale(frame, scale)
	local set = frame.SetScaleBase or frame.SetScale
	set(frame, scale)
end
-- Coordinates in the neutral 2172x724 trophy atlas. Slots and endcaps scale separately.
local artRows = {
	HUNTER = { cell = { 670, 56, 808, 202 }, cap = { 174, 5, 440, 239 }, join = 391, top = { 670, 40, 1200, 56 }, bottom = { 670, 202, 1200, 222 } },
	WARLOCK = { cell = { 670, 294, 808, 438 }, cap = { 208, 248, 430, 482 }, join = 378, top = { 670, 278, 1200, 294 }, bottom = { 670, 438, 1200, 463 } },
	DEFAULT = { cell = { 670, 532, 808, 676 }, cap = { 195, 500, 410, 704 }, join = 386, top = { 670, 516, 1200, 532 }, bottom = { 670, 676, 1200, 700 } }
}
local function Artwork(parent)
	local art = {}
	art.backing = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
	art.backing:SetColorTexture(.025, .022, .018, 1)
	for _, key in ipairs({ "top", "bottom", "left", "right" }) do art[key] = parent:CreateTexture(nil, "BACKGROUND", nil, 1) end
	return art
end
local function Sprite(texture, rect, mirror)
	texture:SetTexture(GetMedia("pets/trophy-atlas", "png"))
	texture:SetTexCoord((mirror and rect[3] or rect[1]) / 2172, (mirror and rect[1] or rect[3]) / 2172, rect[2] / 724, rect[4] / 724)
	texture:SetVertexColor(ns.API.GetPetMetalColor())
end
local function SkinCell(button, texture, row)
	Sprite(texture, row.cell)
	texture:SetAllPoints(button)
	local icon = button.icon or button.Icon
	if icon then
		local width, height = button:GetSize()
		if not isSecret(width) and not isSecret(height) then
			local inset = math.min(width, height) * .055
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
			icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
		end
	end
end
local function SkinArtwork(art, first, last, key)
	if not first or not last then return end
	local row = artRows[key]
	local _, height = first:GetSize()
	if isSecret(height) or height <= 0 then return end
	local factor = height / (row.cell[4] - row.cell[2])
	art.backing:ClearAllPoints()
	art.backing:SetPoint("TOPLEFT", first, "TOPLEFT")
	art.backing:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
	for _, name in ipairs({ "top", "bottom" }) do
		local rect, texture = row[name], art[name]
		Sprite(texture, rect)
		texture:ClearAllPoints()
		texture:SetPoint(name == "top" and "BOTTOMLEFT" or "TOPLEFT", first, name == "top" and "TOPLEFT" or "BOTTOMLEFT")
		texture:SetPoint(name == "top" and "BOTTOMRIGHT" or "TOPRIGHT", last, name == "top" and "TOPRIGHT" or "BOTTOMRIGHT")
		texture:SetHeight((rect[4] - rect[2]) * factor)
	end
	for _, name in ipairs({ "left", "right" }) do
		local texture, right = art[name], name == "right"
		local overlap = (row.cap[3] - row.join) * factor + .5
		Sprite(texture, row.cap, right)
		texture:ClearAllPoints()
		texture:SetSize((row.cap[3] - row.cap[1]) * factor, (row.cap[4] - row.cap[2]) * factor)
		texture:SetPoint(right and "TOPLEFT" or "TOPRIGHT", right and last or first, right and "TOPRIGHT" or "TOPLEFT", right and -overlap or overlap, (row.cell[2] - row.cap[2]) * factor)
	end
end
function Pets:CreateHost()
	local native = PetActionBar
	if not native then return end
	local host = CreateFrame("Frame", Addon.."PetBarAnchor", UIParent, "SecureHandlerStateTemplate")
	host:SetFrameStrata("MEDIUM")
	host:SetSize(509, 43)
	host.editModeName = "Diabolic: Pet Bar"
	self.host, self.native = host, native
	self.cells = {}
	self.background = CreateFrame("Frame", nil, native, ns.BackdropTemplate)
	self.background:SetPoint("TOPLEFT", -6, 6)
	self.background:SetPoint("BOTTOMRIGHT", 6, -6)
	self.background:SetFrameLevel(math.max(0, native:GetFrameLevel() - 1))
	self.artwork = Artwork(self.background)
	local edit = ns.LibEditMode
	if edit and edit.AddFrame then
		local db = ns.db.char.petbar
		edit:AddFrame(host, function(_, _, point, x, y)
			if InCombatLockdown() then return end
			db.positionPoint, db.positionX, db.positionY = point, x, y
		end, { point = db.positionPoint or "BOTTOM", x = db.positionX or 4, y = db.positionY or 163 })
		edit:AddFrameSettings(host, {
			{ kind = edit.SettingType.Slider, name = L["PetBarScale"], desc = L["PetBarScaleDesc"], default = .8, minValue = .4, maxValue = 1.5, valueStep = .05,
				get = function() return db.scale or .8 end,
				set = function(_, value) db.scale = value; self:Refresh() end,
				formatter = function(value) return string.format("%.2f", value) end }
		})
		self.selection = edit.frameSelections[host]
		self.selection:SetFrameStrata("HIGH")
		self.selection:SetFrameLevel(100)
		self.editing = edit.isEditing or nil
		edit:RegisterCallback("enter", function()
			self.editing = true
			self:Refresh()
			self:UpdatePreview()
		end)
		edit:RegisterCallback("exit", function()
			self.editing = nil
			self:Refresh()
			self:UpdatePreview()
		end)
	end
	-- Only hide the native selection artwork, without writing native EditMode state.
	if native.Selection then
		native.Selection:HookScript("OnShow", function(frame) if self.editing then frame:Hide() end end)
	end
end
function Pets:Refresh()
	if InCombatLockdown() then self.pending = true; return end
	self.pending = nil
	if not self.host then self:CreateHost() end
	local host, native = self.host, self.native
	if not host then return end
	local db = ns.db.char.petbar
	-- C base setters avoid native EditMode overrides that taint the shared manager.
	if native:GetParent() ~= host then native:SetParent(host) end
	SetScale(native, 1)
	SetPoint(native, "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
	native:SetAlpha(1)
	local width, height = native:GetSize()
	if not isSecret(width) and not isSecret(height) and width > 0 and height > 0 then host:SetSize(width, height) end
	ns.API.SetEditModeUFObjectScale(host, db.scale or .8)
	SetPoint(host, db.positionPoint or "BOTTOM", UIParent, db.positionPoint or "BOTTOM", db.positionX or 4, db.positionY or 163)
	RegisterStateDriver(host, "visibility", (self.editing or ns.db.char.actionbars.showPetBar) and "[petbattle] hide; show" or "hide")
	local key = ClassKey()
	for i = 1, 10 do
		local button = _G["PetActionButton"..i]
		if button then
			local texture = self.cells[i]
			if not texture then texture = button:CreateTexture(nil, "BACKGROUND", nil, 1); self.cells[i] = texture end
			SkinCell(button, texture, artRows[key])
			local normal = button:GetNormalTexture()
			if normal then normal:SetAlpha(0) end
		end
	end
	SkinArtwork(self.artwork, _G.PetActionButton1, _G.PetActionButton10, key)
	ns.ForeverNativeFallbacks.petBar = "Blizzard pet buttons, secure clicks/autocast/events; Diabolic position and skin"
	local pet = ns.UnitFramesByName and ns.UnitFramesByName.Pet
	ns.API.UpdatePetOrbPosition(pet)
	ns.API.UpdatePetOrbArtwork(pet)
	self:UpdatePreview()
end
function Pets:CreatePreview()
	local preview = CreateFrame("Frame", Addon.."PetBarPreview", UIParent, ns.BackdropTemplate)
	preview:SetFrameStrata("HIGH")
	preview:EnableMouse(false)
	preview.artwork = Artwork(preview)
	preview.buttons = {}
	for i = 1, 10 do
		local slot = CreateFrame("Frame", nil, preview)
		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetAllPoints()
		slot.cell = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
		preview.buttons[i] = slot
	end
	preview.label = preview:CreateFontString(nil, "OVERLAY")
	preview.label:SetFontObject(ns.API.GetFont(12, true))
	preview.label:SetPoint("BOTTOM", preview, "TOP", 0, 8)
	preview:Hide()
	self.previewBar = preview
	local orb = CreateFrame("Frame", Addon.."PetOrbPreview", UIParent)
	-- Match the live Retail pet orb behind the player's orb, including overlay children.
	orb:SetFrameStrata("BACKGROUND")
	orb:EnableMouse(false)
	-- oUF's CreateOrb wrapper supplies the owner as parent; use the same wrapper here.
	-- LibOrb:Embed alone defaults an omitted parent to UIParent and breaks scale/position.
	orb.CreateOrb = function(frame, name, parent, ...)
		return LibStub("LibOrb-1.0"):CreateOrb(name, parent or frame, ...)
	end
	ns.API.StylePetOrb(orb, "pet")
	orb.label = orb:CreateFontString(nil, "OVERLAY")
	orb.label:SetFontObject(ns.API.GetFont(12, true))
	orb.label:SetPoint("BOTTOM", orb, "TOP", 0, 12)
	orb:Hide()
	self.previewOrb = orb
end
function Pets:UpdatePreview()
	local showBar = self.previewBarEnabled or self.editing
	local showOrb = self.previewOrbEnabled
	if InCombatLockdown() then
		if self.previewBar then self.previewBar:Hide(); self.previewOrb:Hide() end
		return
	end
	if not self.previewBar and not showBar and not showOrb then return end
	if not self.previewBar then self:CreatePreview() end
	local preview, orb = self.previewBar, self.previewOrb
	local key = self.previewClass or ClassKey()
	preview:SetShown(showBar and self.native ~= nil)
	if showBar and self.native then
		preview:SetScale(self.host:GetScale())
		preview:SetAllPoints(self.host)
		local width, height = self.host:GetSize()
		local button = _G.PetActionButton1
		local slotWidth, slotHeight = 30, 30
		if button then slotWidth, slotHeight = button:GetSize() end
		if isSecret(slotWidth) or isSecret(slotHeight) or slotWidth <= 0 or slotHeight <= 0 then slotWidth, slotHeight = 30, 30 end
		local step = math.max(slotWidth, (width - slotWidth) / 9)
		for i, slot in ipairs(preview.buttons) do
			slot:ClearAllPoints()
			slot:SetSize(slotWidth, slotHeight)
			slot:SetPoint("LEFT", preview, "LEFT", (i - 1) * step, 0)
			slot.icon:SetTexture("Interface\\Icons\\"..icons[key][i])
			SkinCell(slot, slot.cell, artRows[key])
		end
		SkinArtwork(preview.artwork, preview.buttons[1], preview.buttons[10], key)
		preview.label:SetText(string.format(L["PetPreviewLabel"], ClassName(key)))
	end
	orb:SetShown(showOrb)
	if showOrb then
		local frame = ns.UnitFramesByName and ns.UnitFramesByName.Pet
		orb:ClearAllPoints()
		if frame then
			orb:SetScale(frame:GetScale())
			orb:SetFrameLevel(frame:GetFrameLevel())
			orb:SetPoint("CENTER", frame, "CENTER")
		else
			orb:SetPoint("CENTER", UIParent, "CENTER", -250, -150)
		end
		orb:UpdateOrbSize(ns.db.char.pet.orbSize or 100)
		ns.API.UpdatePetOrbArtwork(orb)
		orb.Health:SetMinMaxValues(0, 100, true)
		orb.Health:SetValue(self.previewHealth or 65, true)
		orb.label:SetText(string.format(L["PetPreviewHealth"], self.previewHealth or 65))
	end
end
function Pets:Command(input)
	local command, a, b = string.match(string.lower(input or ""), "^%s*(%S*)%s*(%S*)%s*(%S*)%s*$")
	if not command then print(L["PetPreviewUsage"]); return end
	if command == "status" then
		local db = ns.db.char.petbar
		print(string.format(L["PetPreviewStatus"], ClassName(self.previewClass or ClassKey()), db.positionX or 4, db.positionY or 163, ns.db.char.pet.orbSize or 100))
		return
	end
	if command == "hide" or command == "off" then
		self.previewBarEnabled, self.previewOrbEnabled = nil, nil
		self:UpdatePreview()
		print(L["PetPreviewHidden"])
		return
	end
	if InCombatLockdown() then print(L["PetPreviewCombat"]); return end
	if command == "show" or command == "bar" then
		if a ~= "" and not icons[a:upper()] then print(L["PetPreviewUsage"]); return end
		self.previewClass = ClassKey(a ~= "" and a or nil)
		self.previewBarEnabled = true
		if command == "show" then self.previewOrbEnabled = true end
	elseif command == "orb" then
		local health = a == "" and 65 or tonumber(a)
		if not health or health < 0 or health > 100 then print(L["PetPreviewUsage"]); return end
		self.previewHealth, self.previewOrbEnabled = health, true
	elseif command == "orbpos" and a == "reset" and b == "" then
		local db = ns.db.char.pet
		db.orbPoint, db.orbRelPoint, db.orbPositionX, db.orbPositionY = nil, nil, nil, nil
	elseif command == "barpos" or command == "orbpos" then
		local x, y = tonumber(a), tonumber(b)
		if not x or not y or math.abs(x) > 4000 or math.abs(y) > 4000 then print(L["PetPreviewUsage"]); return end
		if command == "barpos" then
			local db = ns.db.char.petbar
			db.positionPoint, db.positionX, db.positionY = "BOTTOM", x, y
		else
			local frame = ns.UnitFramesByName and ns.UnitFramesByName.Pet
			if not frame or not frame.isOrbStyle then print(L["PetPreviewUsage"]); return end
			local db = ns.db.char.pet
			db.orbPoint, db.orbRelPoint, db.orbPositionX, db.orbPositionY = "BOTTOM", "BOTTOM", x, y
			frame:ClearAllPoints()
			frame:SetPoint("BOTTOM", UIParent, "BOTTOM", x, y)
		end
	else
		print(L["PetPreviewUsage"])
		return
	end
	self:Refresh()
	print(L["PetPreviewNotice"])
end
function Pets:OnEvent(event)
	if event == "PLAYER_REGEN_DISABLED" then
		self.previewBarEnabled, self.previewOrbEnabled = nil, nil
		self:UpdatePreview()
	else
		self:Refresh()
	end
end
function Pets:OnEnable()
	ns:RegisterChatCommand("diabolicpet", function(input) self:Command(input) end)
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UNIT_PET", "PET_BAR_UPDATE" }) do self:RegisterEvent(event, "OnEvent") end
	ns.RegisterCallback(self, "PetBar_Position_Updated", "Refresh")
	ns.RegisterCallback(self, "ActionBar_Settings_Updated", "Refresh")
	ns.RegisterCallback(self, "ActionBars_SecondaryBar_Updated", "Refresh")
	ns.RegisterCallback(self, "ActionBars_ThirdBar_Updated", "Refresh")
	ns.RegisterCallback(self, "OrbStyle_Updated", "Refresh")
	self:Refresh()
end
