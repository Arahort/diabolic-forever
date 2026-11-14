local Addon, ns = ...
if not ns.IsForever then return end
local Castbar = {}
ns.CathedralCastbar = Castbar
local Asset = function(name)
	return ns.API.GetMedia("arahort-stone/castbar-"..name, "png")
end
local CaptureTexture = function(texture)
	local state = { texture = texture:GetTexture(), coords = { texture:GetTexCoord() }, color = { texture:GetVertexColor() }, alpha = texture:GetAlpha(), width = texture:GetWidth(), height = texture:GetHeight(), layer = { texture:GetDrawLayer() }, points = {} }
	for i = 1, texture:GetNumPoints() do state.points[i] = { texture:GetPoint(i) } end
	return state
end
local RestoreTexture = function(texture, state)
	texture:SetTexture(state.texture)
	texture:SetTexCoord(unpack(state.coords))
	texture:SetVertexColor(unpack(state.color))
	texture:SetAlpha(state.alpha)
	texture:SetDrawLayer(unpack(state.layer))
	texture:ClearAllPoints()
	texture:SetSize(state.width, state.height)
	for _, point in ipairs(state.points) do texture:SetPoint(unpack(point)) end
end
local ApplyTint = function(state)
	if not state.active or state.coloring then return end
	local bar = state.bar
	local protected = bar.notInterruptible
	if protected == nil then protected = false end
	if state.target.castbarPreviewActive then protected = false end
	state.coloring = true
	bar:SetStatusBarColor(1, 1, 1, 1)
	-- Native alpha selection accepts the secret flag without a Lua boolean test.
	bar:GetStatusBarTexture():SetAlphaFromBoolean(protected, 0, 1)
	state.protectedFill:SetAlphaFromBoolean(protected, 1, 0)
	state.coloring = nil
end
Castbar.Install = function(target)
	local bar = target.Castbar
	if not bar or not bar.DiabolicBackground or not bar.DiabolicBorder or not bar.DiabolicIconBorder then return end
	local state = { target = target, bar = bar, background = bar.DiabolicBackground, border = bar.DiabolicBorder, iconBorder = bar.DiabolicIconBorder }
	state.original = { fill = CaptureTexture(bar:GetStatusBarTexture()), background = CaptureTexture(state.background), border = CaptureTexture(state.border), iconBorder = CaptureTexture(state.iconBorder), color = { bar:GetStatusBarColor() } }
	local protectedFill = bar:CreateTexture(nil, "ARTWORK")
	protectedFill:SetTexture(ns.API.GetMedia("statusbar/Heath-Bar"))
	protectedFill:SetVertexColor(.51, .75, .76, 1)
	protectedFill:SetAllPoints(bar:GetStatusBarTexture())
	protectedFill:Hide()
	state.protectedFill = protectedFill
	hooksecurefunc(bar, "SetStatusBarColor", function() ApplyTint(state) end)
	return state
end
Castbar.SetActive = function(state, active)
	if not state then return end
	active = active and true or false
	local style = ns.db and ns.db.global.orbs.style
	if state.active == active and (not active or state.style == style) then return end
	state.active = active
	state.style = style
	local bar = state.bar
	if active then
		bar:SetStatusBarTexture(Asset("fill"))
		bar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
		bar:GetStatusBarTexture():SetAlpha(1)
		state.background:SetTexture(Asset("background"))
		state.background:SetTexCoord(0, 1, 0, 1)
		state.background:SetVertexColor(1, 1, 1, 1)
		state.background:ClearAllPoints()
		state.background:SetAllPoints(bar)
		state.border:SetTexture(Asset("border"))
		state.border:SetTexCoord(0, 1, 0, 1)
		state.border:SetVertexColor(1, 1, 1, 1)
		state.border:ClearAllPoints()
		state.border:SetSize(240 * 602 / 558, 20 * 86 / 64)
		state.border:SetPoint("CENTER", bar, "CENTER")
		state.iconBorder:SetTexture(Asset("icon-border"))
		state.iconBorder:SetTexCoord(0, 1, 0, 1)
		state.iconBorder:SetVertexColor(1, 1, 1, 1)
		state.iconBorder:SetDrawLayer("OVERLAY", 2)
		state.iconBorder:ClearAllPoints()
		state.iconBorder:SetSize(35, 35)
		state.iconBorder:SetPoint("CENTER", bar.Icon, "CENTER")
		state.protectedFill:Show()
		ApplyTint(state)
	else
		state.protectedFill:Hide()
		bar:SetStatusBarTexture(state.original.fill.texture)
		bar:GetStatusBarTexture():SetTexCoord(unpack(state.original.fill.coords))
		bar:GetStatusBarTexture():SetAlpha(state.original.fill.alpha)
		RestoreTexture(state.background, state.original.background)
		RestoreTexture(state.border, state.original.border)
		RestoreTexture(state.iconBorder, state.original.iconBorder)
		bar:SetStatusBarColor(unpack(state.original.color))
		if bar.PostCastInterruptible then bar:PostCastInterruptible(state.target.__unit) end
	end
end
