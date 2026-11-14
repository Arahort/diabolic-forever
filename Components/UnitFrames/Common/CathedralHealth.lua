local Addon, ns = ...
if not ns.IsForever then return end
local Health = {}
ns.CathedralHealth = Health
local SyncColor = function(state, color)
	local red, green, blue
	if type(color) == "table" and color.GetRGB then
		red, green, blue = color:GetRGB()
	else
		red, green, blue = state.element:GetStatusBarColor()
	end
	state.bar:SetStatusBarColor(red, green, blue, 1)
end
local SyncValue = function(state, maximum)
	state.bar:SetMinMaxValues(0, maximum)
	state.bar:SetValue(state.element:GetValue(), Enum.StatusBarInterpolation.ExponentialEaseOut)
end
Health.Install = function(frame, fillTexturePath, maskTexturePath)
	local element = frame.Health
	local state = { frame = frame, element = element, texture = element:GetStatusBarTexture() }
	state.textureAlpha = state.texture:GetAlpha()
	if element.Preview then
		state.preview = element.Preview:GetStatusBarTexture()
		state.previewAlpha = state.preview:GetAlpha()
	end
	local bar = CreateFrame("StatusBar", nil, element)
	bar:SetAllPoints(element)
	bar:SetFrameLevel(element:GetFrameLevel() + 1)
	bar:SetStatusBarTexture(fillTexturePath)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0, Enum.StatusBarInterpolation.Immediate)
	local mask = bar:CreateMaskTexture(nil, "ARTWORK")
	mask:SetTexture(maskTexturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(bar)
	bar:GetStatusBarTexture():AddMaskTexture(mask)
	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(bar)
	background:SetColorTexture(.035, .02, .02, 1)
	background:AddMaskTexture(mask)
	state.bar, state.mask, state.background = bar, mask, background
	bar:Hide()
	local postUpdate = element.PostUpdate
	element.PostUpdate = function(self, unit, current, maximum, ...)
		if postUpdate then postUpdate(self, unit, current, maximum, ...) end
		if state.active then SyncValue(state, maximum) end
	end
	local postUpdateColor = element.PostUpdateColor
	element.PostUpdateColor = function(self, unit, color, ...)
		if postUpdateColor then postUpdateColor(self, unit, color, ...) end
		if state.active then SyncColor(state, color) end
	end
	return state
end
Health.SetActive = function(state, active)
	state.active = active and true or false
	state.texture:SetAlpha(state.active and 0 or state.textureAlpha)
	if state.preview then state.preview:SetAlpha(state.active and 0 or state.previewAlpha) end
	if state.active then
		state.bar:SetAlpha(1)
		SyncColor(state)
		SyncValue(state, UnitHealthMax(state.frame.__unit or state.frame.unit))
		state.bar:Show()
	else
		state.bar:Hide()
	end
	ns.ForeverNativeFallbacks = ns.ForeverNativeFallbacks or {}
	ns.ForeverNativeFallbacks["CathedralHealth:"..(state.frame.__unit or state.frame.unit or "unknown")] = state.active and "native StatusBar" or "LibSmoothBar"
end
