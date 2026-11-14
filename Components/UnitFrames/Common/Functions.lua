local Addon, ns = ...
local oUF = ns.oUF
local API = ns.API

-- WoW API
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitGUID = UnitGUID
local UnitIsConnected = UnitIsConnected
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

-- WoW 12.0.0: issecretvalue may not exist in older versions
local issecretvalue = issecretvalue or function() return false end

-- Tints the preview bar sitting behind a health bar with a darker shade of the health
-- color. oUF hands us a ColorMixin these days, and in WoW 12.1 the class color of a unit
-- whose identity is restricted comes back as secret numbers, which cannot be multiplied
-- in addon code. Those units get the plain color instead of a darkened one.
API.SetPreviewColor = function(preview, r, g, b)
	if (not preview) then return end
	if (type(r) == "table" and r.GetRGB) then
		r, g, b = r:GetRGB()
	end
	if (not r or not g or not b) then return end
	if (issecretvalue(r)) then
		preview:SetStatusBarColor(r, g, b)
	else
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

-- Anchor to the native fill edge so the engine handles secret health and healing.
API.CreateHorizontalHealthPrediction = function(health, splitHealing)
	local overlay = CreateFrame("Frame", nil, health)
	overlay:SetAllPoints(health)
	overlay:SetFrameLevel(health:GetFrameLevel() + 2)
	overlay:SetClipsChildren(true)
	local fill = health:GetNativeStatusBar():GetStatusBarTexture()
	local function CreatePredictionBar(anchor, reverse, r, g, b, alpha)
		local bar = CreateFrame("StatusBar", nil, overlay)
		bar:SetFrameLevel(overlay:GetFrameLevel())
		bar:SetPoint("TOP", overlay)
		bar:SetPoint("BOTTOM", overlay)
		bar:SetPoint(reverse and "RIGHT" or "LEFT", anchor, "RIGHT")
		bar:SetWidth(health:GetWidth())
		bar:SetReverseFill(reverse)
		bar:SetRenderMode(Enum.StatusBarRenderMode.Linear)
		bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
		bar:SetStatusBarColor(r, g, b, alpha)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		return bar
	end
	local prediction = {
		incomingHealClampMode = Enum.UnitIncomingHealClampMode.MissingHealth,
		incomingHealOverflow = 1,
		healAbsorbMode = Enum.UnitHealAbsorbMode.ReducedByIncomingHeals,
		healAbsorbClampMode = Enum.UnitHealAbsorbClampMode.CurrentHealth,
		damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MissingHealth,
	}
	local incoming = CreatePredictionBar(fill, false, .15, .85, .3, .35)
	if splitHealing then
		prediction.healingPlayer = incoming
		prediction.healingOther = CreatePredictionBar(incoming:GetStatusBarTexture(), false, 0, .63, .56, .35)
		prediction.damageAbsorb = CreatePredictionBar(prediction.healingOther:GetStatusBarTexture(), false, .25, .65, 1, .5)
	else
		prediction.healingAll = incoming
	end
	prediction.healAbsorb = CreatePredictionBar(fill, true, .5, 0, 0, .5)
	return prediction
end
-- Simple UpdateHealth - direct API for all units
API.UpdateHealth = function(self, event, unit)
	if (not unit or self.__unit ~= unit) then return end
	local element = self.Health
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end
	-- Direct API - let's see real error
	local cur = UnitHealth(unit)
	local max = UnitHealthMax(unit)
	local connected = UnitIsConnected(unit)
	-- Different GUID means a different player or NPC,
	-- so we want updates to be instant, not smoothed.
	local forced = (event == "ForceUpdate") or (event == "RefreshUnit") or (event == "GROUP_ROSTER_UPDATE")
	if (not forced) then
		local guid = UnitGUID(unit)
		-- WoW 12.0: Use pcall for guid comparison to handle secret/tainted values
		local guidChanged = false
		if guid then
			local success, result = pcall(function() return guid ~= element.guid end)
			guidChanged = success and result
		end
		if guidChanged or (guid and not element.guid) then
			forced = true
			element.guid = guid
		end
	end
	element:SetMinMaxValues(0, max, forced)
	if (connected) then
		element:SetValue(cur, forced)
	else
		element:SetValue(max, true)
	end
	element.cur = cur
	element.max = max
	local preview = element.Preview
	if (preview) then
		preview:SetMinMaxValues(0, max, true)
		if connected then
			preview:SetValue(cur, true)
		else
			preview:SetValue(max, true)
		end
	end
	if (element.PostUpdate) then
		element:PostUpdate(unit, cur, max)
	end
end

-- WoW 12.0.1: Power update - native StatusBar handles secret values
API.UpdatePower = function(self, event, unit)
	if(not unit or self.__unit ~= unit) then return end
	local element = self.Power
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end
	local guid = UnitGUID(unit)
	-- WoW 12.0: Use pcall for guid comparison to handle secret/tainted values
	local guidChanged = false
	if guid then
		local success, result = pcall(function() return guid ~= element.guid end)
		guidChanged = success and result
	end
	local forced = guidChanged or (guid and not element.guid) or (UnitIsDeadOrGhost(unit))
	element.guid = guid
	local displayType, min = nil, 0
	local cur, max = UnitPower(unit), UnitPowerMax(unit)
	element:SetMinMaxValues(0, max)
	if (UnitIsConnected(unit)) then
		element:SetValue(cur, forced)
	else
		element:SetValue(max, forced)
	end
	element.cur = cur
	element.min = min
	element.max = max
	element.displayType = displayType
	if (element.PostUpdate) then
		element:PostUpdate(unit, cur, min, max)
	end
end
