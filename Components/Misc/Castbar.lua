local Addon, ns = ...
local Castbar = ns:NewModule("Castbar", "AceEvent-3.0")

-- Addon API
local GetMedia = ns.API.GetMedia
local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end
Castbar.UpdateForeverAnchorGeometry = function(self, frame)
	local anchor = self.positionAnchor
	if not anchor then return end
	local width, height = frame:GetSize()
	local scale = frame:GetScale()
	if not IsSecret(width) and not IsSecret(height) and width > 0 and height > 0 then
		local borderWidth, borderHeight = width * 602/558, height * 86/45
		anchor:SetSize(borderWidth, math.max(borderHeight, 32))
		self.positionPreview:SetSize(width, height)
		self.previewBorder:SetSize(borderWidth, borderHeight)
	end
	if not IsSecret(scale) and scale > 0 then anchor:SetScale(scale) end
end
Castbar.ApplyForeverPosition = function(self)
	local anchor = self.positionAnchor
	if not anchor then return end
	local db = ns.db.global.castbar
	anchor:ClearAllPoints()
	anchor:SetPoint(db.positionPoint or "CENTER", UIParent, db.positionPoint or "CENTER", db.positionX or 0, db.positionY or -150)
end
Castbar.SetupForeverEditMode = function(self, frame)
	if self.positionAnchor then return end
	local LibEditMode = ns.LibEditMode
	if not LibEditMode or not LibEditMode.AddFrame then return end
	ns.db.global.castbar = ns.db.global.castbar or {}
	-- A plain positioning frame keeps LibEditMode geometry independent of secret cast text.
	local anchor = CreateFrame("Frame", Addon.."PlayerCastbarAnchor", UIParent)
	anchor:SetSize(208 * 602/558, 32)
	anchor:SetFrameStrata(frame:GetFrameStrata())
	anchor:SetFrameLevel(frame:GetFrameLevel() + 10)
	anchor.editModeName = "Diabolic: Cast Bar"
	self.positionAnchor = anchor
	local preview = CreateFrame("StatusBar", nil, anchor)
	preview:SetSize(208, 11)
	preview:SetPoint("CENTER", anchor, "CENTER")
	preview:SetFrameLevel(anchor:GetFrameLevel() + 1)
	preview:SetStatusBarTexture(GetMedia("statusbar/Heath-Bar"))
	preview:SetStatusBarColor(.2, .5, 1)
	preview:SetMinMaxValues(0, 1)
	preview:SetValue(.65)
	local background = preview:CreateTexture(nil, "BACKGROUND", nil, -3)
	background:SetAllPoints(preview)
	background:SetTexture(GetMedia("statusbar/Heath-Bar-Back"))
	background:SetVertexColor(.15, .15, .15, .85)
	local border = preview:CreateTexture(nil, "OVERLAY")
	border:SetTexture(GetMedia("statusbar/Health-Bar-Border2"))
	border:SetVertexColor(.8, .8, .8)
	border:SetPoint("CENTER", preview, "CENTER")
	border:SetSize(208 * 602/558, 11 * 86/45)
	self.previewBorder = border
	preview:Hide()
	self.positionPreview = preview
	self:ApplyForeverPosition()
	self:UpdateForeverAnchorGeometry(frame)
	LibEditMode:AddFrame(anchor, function(_, _, point, x, y)
		if type(x) ~= "number" or type(y) ~= "number" or IsSecret(x) or IsSecret(y) then return end
		local db = ns.db.global.castbar
		db.positionPoint, db.positionX, db.positionY = point, x, y
	end, { point = "CENTER", x = 0, y = -290 })
	local selection = LibEditMode.frameSelections[anchor]
	-- The shared template forces MEDIUM, while the native player castbar is HIGH.
	selection:SetFrameStrata(anchor:GetFrameStrata())
	selection:SetFrameLevel(math.max(selection:GetFrameLevel(), preview:GetFrameLevel() + 1))
	local function HideNativeSelection()
		if self.editing and frame.Selection then frame.Selection:Hide() end
	end
	if frame.Selection then frame.Selection:HookScript("OnShow", HideNativeSelection) end
	local function EnterEditMode()
		self.editing = true
		self:RestoreForeverParent()
		preview:Show()
		HideNativeSelection()
	end
	LibEditMode:RegisterCallback("enter", EnterEditMode)
	LibEditMode:RegisterCallback("exit", function()
		self.editing = nil
		preview:Hide()
		self:RestoreForeverParent()
	end)
	LibEditMode:RegisterCallback("layout", function()
		self:ApplyForeverPosition()
		self:RestoreForeverParent()
	end)
	if LibEditMode.isEditing then EnterEditMode() end
end
Castbar.RestoreForeverParent = function(self)
	local frame = PlayerCastingBarFrame
	if not frame or self.restoringPosition then return end
	if not self.positionAnchor and frame:GetParent() ~= PlayerFrame then return end
	if InCombatLockdown() then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end
	self.restoringPosition = true
	-- Native attachment can be reapplied after the unit-frame module initialized.
	if frame:GetParent() == PlayerFrame then PlayerFrame_DetachCastBar() end
	if frame:GetParent() ~= UIParent then frame:SetParent(UIParent) end
	-- Use the native base setters without writing Blizzard's snapping/layout metadata.
	local clearPoints = frame.ClearAllPointsBase or frame.ClearAllPoints
	local setPoint = frame.SetPointBase or frame.SetPoint
	clearPoints(frame)
	if self.positionAnchor then
		frame.isManagedFrame, frame.isBottomManagedFrame = false, false
		setPoint(frame, "CENTER", self.positionAnchor, "CENTER", 0, 0)
		self:UpdateForeverAnchorGeometry(frame)
	else
		local db = ns.db and ns.db.global.castbar
		local point = db and db.positionPoint or "CENTER"
		setPoint(frame, point, UIParent, point, db and db.positionX or 0, db and db.positionY or -150)
	end
	self.restoringPosition = nil
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end
Castbar.ApplyForeverAppearance = function(self, frame)
	if frame.__DiabolicRefreshing then return end
	frame.__DiabolicRefreshing = true
	-- Native StatusBar owns progress and secret durations; no overlay arithmetic.
	frame:SetStatusBarTexture(GetMedia("statusbar/Heath-Bar"))
	frame:SetStatusBarColor(.2, .5, 1)
	local fill = frame:GetStatusBarTexture()
	if fill then fill:SetAlpha(1) end
	for _, key in ipairs({ "Border", "TextBorder", "Background", "DropShadow" }) do
		if frame[key] then frame[key]:SetAlpha(0) end
	end
	local border = frame.__DiabolicBorder
	local width, height = frame:GetSize()
	border:ClearAllPoints()
	if not IsSecret(width) and not IsSecret(height) and width > 0 and height > 0 then
		-- Assets: outer frame 602x86, inner fill 558x45.
		border:SetSize(width * 602/558, height * 86/45)
		border:SetPoint("CENTER", frame, "CENTER")
	else
		border:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 9)
		border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, -9)
	end
	if frame.Text then
		frame.Text:SetFontObject(ns.API.GetFont(13, true))
		frame.Text:ClearAllPoints()
		frame.Text:SetPoint("LEFT", frame, "LEFT", 6, 0)
		frame.Text:SetPoint("RIGHT", frame, "RIGHT", frame.CastTimeText and -38 or -6, 0)
		frame.Text:SetJustifyH("CENTER")
	end
	if frame.CastTimeText then
		-- The native timer is opt-in independently of its font and placement.
		frame:SetCastTimeTextShown(true)
		frame.CastTimeText:SetFontObject(ns.API.GetFont(13, true))
		frame.CastTimeText:ClearAllPoints()
		frame.CastTimeText:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
	end
	if frame.BorderShield then
		-- Keep the native non-interruptible indicator and its visibility controller.
		frame.BorderShield:SetTexture(GetMedia("target-castbar-shield", "png"))
		frame.BorderShield:SetTexCoord(0, 1, 0, 1)
		frame.BorderShield:ClearAllPoints()
		frame.BorderShield:SetSize(22, 27)
		frame.BorderShield:SetPoint("RIGHT", frame.Icon or frame, "LEFT", -5, 0)
	end
	frame.__DiabolicRefreshing = nil
end
Castbar.StyleForeverCastbar = function(self, frame)
	if frame.__DiabolicForeverStyled then return end
	frame.__DiabolicForeverStyled = true
	local background = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
	background:SetAllPoints(frame)
	background:SetTexture(GetMedia("statusbar/Heath-Bar-Back"))
	background:SetVertexColor(.15, .15, .15, .85)
	frame.__DiabolicBackground = background
	local border = frame:CreateTexture(nil, "OVERLAY", nil, 0)
	border:SetTexture(GetMedia("statusbar/Health-Bar-Border2"))
	border:SetVertexColor(.8, .8, .8)
	frame.__DiabolicBorder = border
	if frame.Flash then
		local function RestyleFlash(texture)
			texture:SetTexture(GetMedia("statusbar/Heath-Bar"))
			texture:ClearAllPoints()
			texture:SetAllPoints(frame)
		end
		hooksecurefunc(frame.Flash, "SetAtlas", RestyleFlash)
		RestyleFlash(frame.Flash)
	end
	local function Refresh()
		self:ApplyForeverAppearance(frame)
		if frame == PlayerCastingBarFrame then self:RestoreForeverParent() end
	end
	hooksecurefunc(frame, "UpdateBarFillTexture", Refresh)
	hooksecurefunc(frame, "SetLook", Refresh)
	frame:HookScript("OnShow", Refresh)
	frame:HookScript("OnSizeChanged", Refresh)
	self:ApplyForeverAppearance(frame)
	if frame == PlayerCastingBarFrame then
		self:SetupForeverEditMode(frame)
		hooksecurefunc(frame, "ApplySystemAnchor", function() self:RestoreForeverParent() end)
		hooksecurefunc(frame, "SetPoint", function() self:RestoreForeverParent() end)
		hooksecurefunc(frame, "SetScale", function() self:RestoreForeverParent() end)
		self:RestoreForeverParent()
	end
end

Castbar.StyleCastbar = function(self, frame)
	if not frame then return end
	if ns.IsForever then return self:StyleForeverCastbar(frame) end
	if frame.__GP_Styled then return end
	-- Get castbar dimensions
	local width, height = frame:GetSize()
	if width == 0 or height == 0 then
		width, height = 195, 20 -- default size fallback
	end
	-- Border size multipliers
	local borderWidth = width * 1.1
	local borderHeight = height * 2.55
	-- Create a separate frame BEHIND the castbar with lower strata
	local borderFrame = CreateFrame("Frame", nil, UIParent)
	borderFrame:SetFrameStrata("LOW")
	borderFrame:SetSize(borderWidth, borderHeight)
	-- Create border texture
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	border:SetTexture(GetMedia("statusbar/Health-Bar-Border2"))
	border:SetVertexColor(.8, .8, .8)
	-- Position and show/hide with castbar
	local function UpdatePosition()
		if frame:IsShown() then
			borderFrame:ClearAllPoints()
			borderFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
			borderFrame:Show()
		else
			borderFrame:Hide()
		end
	end
	frame:HookScript("OnShow", UpdatePosition)
	frame:HookScript("OnHide", function() borderFrame:Hide() end)
	-- Initial state
	borderFrame:Hide()
	frame.__GP_BorderFrame = borderFrame
	frame.__GP_Border = border
	-- Hide spell name background (hook OnShow because Blizzard resets it each cast)
	if frame.TextBorder then
		frame.TextBorder:SetAlpha(0)
		frame:HookScript("OnShow", function() frame.TextBorder:SetAlpha(0) end)
	end
	-- Move spell name text inside the bar and keep it there on each cast
	if frame.Text then
		local function RepositionText()
			frame.Text:ClearAllPoints()
			frame.Text:SetPoint("CENTER", frame, "CENTER", 0, 0)
		end
		RepositionText()
		frame:HookScript("OnShow", RepositionText)
	end
	-- Move timer text inside the bar, right-aligned, same font size as spell name
	if frame.CastTimeText then
		if frame.Text then
			local fontPath, fontSize, fontFlags = frame.Text:GetFont()
			if fontPath then
				frame.CastTimeText:SetFont(fontPath, fontSize, fontFlags)
			end
		end
		local function RepositionTimer()
			frame.CastTimeText:ClearAllPoints()
			frame.CastTimeText:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
		end
		RepositionTimer()
		frame:HookScript("OnShow", RepositionTimer)
	end
	frame.__GP_Styled = true
	-- WoW 12.0: SetStatusBarTexture on protected frames is ignored
	-- Alternative: hide original texture and overlay our own with proper texcoord
	local origTexture = frame:GetStatusBarTexture()
	if origTexture then
		origTexture:SetAlpha(0) -- Hide original
		-- Create overlay texture at full width, use texcoord to show progress
		local overlay = frame:CreateTexture(nil, "ARTWORK", nil, 1)
		overlay:SetTexture(GetMedia("statusbar/Heath-Bar"))
		overlay:SetPoint("TOPLEFT", frame, "TOPLEFT")
		overlay:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
		overlay:SetVertexColor(0.2, 0.5, 1.0) -- Blue color
		overlay:SetWidth(0.01)
		frame.__GP_BarOverlay = overlay
		-- Update overlay width and texcoord based on progress
		frame:HookScript("OnUpdate", function(self)
			local min, max = self:GetMinMaxValues()
			local value = self:GetValue()
			if max > min then
				local progress = (value - min) / (max - min)
				local fullWidth = self:GetWidth()
				overlay:SetWidth(fullWidth * progress)
				overlay:SetTexCoord(0, progress, 0, 1)
			else
				overlay:SetWidth(0.01)
			end
		end)
	end
end

Castbar.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	if ns.IsForever then
		hooksecurefunc("PlayerFrame_AttachCastBar", function() self:RestoreForeverParent() end)
		self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnEvent")
	end
end

Castbar.OnEvent = function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(0.5, function()
			if ns.IsForever then self:RestoreForeverParent() end
			if PlayerCastingBarFrame then
				self:StyleCastbar(PlayerCastingBarFrame)
			end
			if PetCastingBarFrame then
				self:StyleCastbar(PetCastingBarFrame)
			end
		end)
		if not ns.IsForever then self:UnregisterEvent("PLAYER_ENTERING_WORLD") end
	elseif ns.IsForever and (event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED") then
		self:RestoreForeverParent()
		if PlayerCastingBarFrame and PlayerCastingBarFrame.__DiabolicForeverStyled then self:ApplyForeverAppearance(PlayerCastingBarFrame) end
	end
end
