local Addon, ns = ...
if not ns.IsForever then return end
local Combo = {}
ns.ForeverComboPoints = Combo
local events = CreateFrame("Frame")
local POINT_SIZE, TARGET_DEPTH = 32, 34
local ORB_POINT_SIZE, ORB_ROW_BUDGET = 41.8, 264
local TARGET_LIFT = 3
local MOUNT_WIDTH, MOUNT_HEIGHT = 24, 15
local MOUNT_JOIN_X, MOUNT_JOIN_Y = .952703, .691489
local MAX_POINTS = 8
local ORB_CHAIN_RADIUS = 89.5
local IsSecret = issecretvalue or function() return false end
local function Asset(name)
	local style = ns.db.global.orbs.style
	local folder = style == "legacy" and "legacy-combo/" or style == "diablo2" and "diablo2-combo/" or "arahort-stone/"
	local version = (name == "end-left" or name == "end-right") and "-v5" or "-v2"
	return ns.API.GetMedia(folder.."combo-fang-"..name..version, "png")
end
local function CreateRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(164, TARGET_DEPTH)
	row:EnableMouse(false)
	row.points = {}
	row.links = {}
	for i = 1, MAX_POINTS * 2 do
		row.links[i] = row:CreateTexture(nil, "BACKGROUND")
	end
	row.mounts = { row:CreateTexture(nil, "ARTWORK"), row:CreateTexture(nil, "ARTWORK") }
	for i = 1, MAX_POINTS do
		local point = CreateFrame("StatusBar", nil, row)
		point:SetSize(POINT_SIZE, POINT_SIZE)
		point:SetMinMaxValues(i - 1, i)
		point:SetValue(0, Enum.StatusBarInterpolation.Immediate)
		point:SetStatusBarTexture(Asset("red"))
		local empty = point:CreateTexture(nil, "BACKGROUND")
		empty:SetAllPoints(point)
		empty:SetTexture(Asset("empty"))
		point.Empty = empty
		row.points[i] = point
	end
	row:Hide()
	return row
end
Combo.GetTargetDepth = function(self, footerDepth)
	local settings = ns.db.char.unitframes
	return footerDepth + (self.supported and settings.comboOnTarget and ns.API.IsStoneStyle() and TARGET_DEPTH or 0)
end
Combo.UpdatePlacement = function(self)
	local hasToT = self.tot:IsShown()
	if IsSecret(hasToT) then self.pending = true; self.placementDeferred = true; return end
	local cathedral = ns.CathedralTarget
	if cathedral and cathedral.active and cathedral.totSuppressed then hasToT = false end
	if InCombatLockdown() then
		local protected = self.targetRow:IsProtected()
		if IsSecret(protected) or protected then
			self.pending = true
			self.placementDeferred = true
			ns.ForeverNativeFallbacks.comboPlacement = "deferred:protected"
			return
		end
	end
	local depth = hasToT and 35 or 0
	local attachmentX = (self.maximum - 1) * 27.5 / 2 + 8 + MOUNT_WIDTH * MOUNT_JOIN_X - 2.5
	local scale = hasToT and math.min(1, 69 / attachmentX) or 1
	self.targetRow:SetScale(scale)
	self.targetRow:ClearAllPoints()
	self.targetRow:SetPoint("TOP", self.target, "BOTTOM", 0, (TARGET_LIFT - depth) / scale)
	self.placementDeferred = nil
end
Combo.Update = function(self)
	local formAllowed = self.class == "ROGUE" or GetShapeshiftFormID() == (CAT_FORM or 1)
	local visible = self.editing or (formAllowed and UnitExists("target"))
	self.orbRow:SetShown(visible and self.orbEnabled)
	self.targetRow:SetShown(visible and self.targetEnabled and (self.editing or UnitCanAttack("player", "target")))
	-- The same target-bound value goes directly to both native bars. It can be secret.
	local points = self.editing and 3 or GetComboPoints("player", "target")
	for _, row in ipairs({ self.orbRow, self.targetRow }) do
		for i = 1, self.maximum do
			row.points[i]:SetValue(points, Enum.StatusBarInterpolation.Immediate)
		end
	end
end
Combo.Refresh = function(self)
	if not self.supported then return end
	if InCombatLockdown() then
		self.pending = true
		return
	end
	self.pending = nil
	local settings = ns.db.char.unitframes
	self.orbEnabled = settings.comboOnOrb
	self.targetEnabled = settings.comboOnTarget and ns.API.IsStoneStyle()
	self.orbRow:ClearAllPoints()
	self.orbRow:SetAllPoints(settings.comboOnResourceOrb and self.player.Power or self.player.Health)
	local maximum = UnitPowerMax("player", Enum.PowerType.ComboPoints)
	if IsSecret(maximum) or maximum <= 0 then
		-- Match the Forever talent fallback used by NugComboBar, without inspecting secret power.
		maximum = self.class == "ROGUE" and IsPlayerSpell(193531) and 6 or 5
	end
	self.maximum = math.max(1, math.min(MAX_POINTS, maximum))
	for _, row in ipairs({ self.orbRow, self.targetRow }) do
		local orb = row == self.orbRow
		local nodes = {}
		local pointSize = orb and math.min(ORB_POINT_SIZE, ORB_ROW_BUDGET / self.maximum) or POINT_SIZE
		local chainOffset = 7.5 * pointSize / POINT_SIZE
		local angleStep = math.min(.435, 1.74 / math.max(1, self.maximum - 1))
		for i, point in ipairs(row.points) do
			local fraction = self.maximum == 1 and .5 or (i - 1) / (self.maximum - 1)
			local angle = (i - (self.maximum + 1) / 2) * angleStep
			local x = orb and math.sin(angle) * (ORB_CHAIN_RADIUS - chainOffset) or (i - (self.maximum + 1) / 2) * 27.5
			local y = orb and math.cos(angle) * (ORB_CHAIN_RADIUS - chainOffset) or 4 * (2 * fraction - 1)^2
			point:ClearAllPoints()
			point:SetPoint(orb and "CENTER" or "TOP", row, orb and "CENTER" or "TOP", x, y)
			point:SetSize(pointSize, pointSize)
			point:SetStatusBarTexture(Asset(orb and "amber" or "red"))
			point.Empty:SetTexture(Asset("empty"))
			local rotation = orb and -angle or 0
			point.Empty:SetRotation(rotation)
			point:GetStatusBarTexture():SetRotation(rotation)
			point:SetShown(i <= self.maximum)
			point.chainX = x - math.sin(rotation) * chainOffset
			point.chainY = y + (orb and 0 or -pointSize / 2) + math.cos(rotation) * chainOffset
			if i <= self.maximum then
				if orb and i > 1 then
					local middleAngle = angle - angleStep / 2
					nodes[#nodes + 1] = { math.sin(middleAngle) * ORB_CHAIN_RADIUS, math.cos(middleAngle) * ORB_CHAIN_RADIUS }
				end
				nodes[#nodes + 1] = { point.chainX, point.chainY }
			end
		end
		if not orb then
			local first, last = nodes[1], nodes[#nodes]
			table.insert(nodes, 1, { first[1] - 8, first[2] })
			nodes[#nodes + 1] = { last[1] + 8, last[2] }
		end
		local phase = 0
		for i, link in ipairs(row.links) do
			local left, right = nodes[i], nodes[i + 1]
			if right then
				local dx, dy = right[1] - left[1], right[2] - left[2]
				local length = math.sqrt(dx * dx + dy * dy)
				local width = length + .8
				link:ClearAllPoints()
				link:SetPoint("CENTER", row, orb and "CENTER" or "TOP", (left[1] + right[1]) / 2, (left[2] + right[2]) / 2)
				link:SetSize(width, 4)
				link:SetTexture(Asset("chain"), "REPEAT", "CLAMP")
				link:SetTexCoord(phase - .4 / 27.5, phase + (length + .4) / 27.5, 0, 1)
				link:SetRotation(math.atan2(dy, dx))
				phase = phase + length / 27.5
			end
			link:SetShown(right ~= nil)
		end
		for i, mount in ipairs(row.mounts) do
			mount:SetShown(not orb)
			if not orb then
				local node = i == 1 and nodes[1] or nodes[#nodes]
				mount:ClearAllPoints()
				mount:SetSize(MOUNT_WIDTH, MOUNT_HEIGHT)
				mount:SetTexture(Asset(i == 1 and "end-left" or "end-right"), "CLAMP", "CLAMP")
				mount:SetTexCoord(0, 1, 0, 1)
				local inset = MOUNT_WIDTH * (1 - MOUNT_JOIN_X)
				mount:SetPoint(i == 1 and "TOPRIGHT" or "TOPLEFT", row, "TOP", node[1] + (i == 1 and inset or -inset), node[2] + MOUNT_HEIGHT * MOUNT_JOIN_Y)
			end
		end
	end
	self:Update()
	self:UpdatePlacement()
	self.target:UpdateTargetCastbar()
end
Combo.Initialize = function(self, player, target, tot)
	if self.player then return end
	self.class = select(2, UnitClass("player"))
	self.supported = self.class == "ROGUE" or self.class == "DRUID"
	if not self.supported then return end
	self.player, self.target, self.tot = player, target, tot
	self.maximum, self.orbEnabled, self.targetEnabled = 5, false, false
	self.orbRow = CreateRow(player.Artwork.Overlay)
	self.orbRow:SetFrameLevel(player.Artwork.Overlay:GetFrameLevel() + 1)
	self.orbRow:SetAllPoints(player.Health)
	self.targetRow = CreateRow(target)
	self.targetRow:SetFrameLevel(target.Health:GetFrameLevel() + 4)
	local function UpdatePlacement()
		self:UpdatePlacement()
		if ns.CathedralTarget then ns.CathedralTarget:UpdateLayoutPresentation() end
	end
	tot:HookScript("OnShow", UpdatePlacement)
	tot:HookScript("OnHide", UpdatePlacement)
	ns.RegisterCallback(self, "OrbStyle_Updated", "Refresh")
	ns.RegisterCallback(self, "UnitFrames_Settings_Updated", "Refresh")
	if ns.LibEditMode and ns.LibEditMode.RegisterCallback then
		ns.LibEditMode:RegisterCallback("enter", function() self.editing = true; self:Update() end)
		ns.LibEditMode:RegisterCallback("exit", function() self.editing = nil; self:Update() end)
	end
	events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	events:RegisterUnitEvent("UNIT_FACTION", "target")
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "COMBO_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "UNIT_MAXPOWER" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_REGEN_ENABLED" and self.pending) then
			self:Refresh()
		else
			self:Update()
		end
	end)
	self:Refresh()
end
