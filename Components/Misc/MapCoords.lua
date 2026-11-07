--[[
	The MIT License (MIT)
	Copyright (c) 2024 Lars Norberg
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
--]]
local Addon, ns = ...
local MapCoords = ns:NewModule("MapCoords", "LibMoreEvents-1.0")
-- Lua API
local floor = math.floor
local format = string.format
-- WoW API
local C_Map = C_Map
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local L = ns.L
-- Utility Functions
local function round(float)
	return floor(float + 0.5)
end
local function formatCoord(num, useDecimals)
	if num == nil then
		return 0
	elseif useDecimals then
		return format("%1.1f", round(num * 1000) / 10)
	else
		return round(num * 100)
	end
end
local function getPlayerCoords()
	local mapID = C_Map.GetBestMapForUnit("player")
	if mapID then
		local mapPos = C_Map.GetPlayerMapPosition(mapID, "player")
		if mapPos then
			return mapPos:GetXY()
		end
	end
	return 0, 0
end
-- 12.1.5 adds a second coordinate display; keep its CVar preference untouched.
MapCoords.UpdateNativeMinimapCoords = function(self, restore)
	local native = MinimapCluster and MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords
	if not native then return end
	local customMinimap = not restore and ns.db and not ns.db.global.minimap.disabled
	if customMinimap then
		if not self.nativeMinimapCoordsParent then
			self.nativeMinimapCoordsParent = native:GetParent()
		end
		if native:GetParent() ~= ns.Hider then
			native:SetParent(ns.Hider)
		end
	elseif self.nativeMinimapCoordsParent then
		native:SetParent(self.nativeMinimapCoordsParent)
		self.nativeMinimapCoordsParent = nil
	end
end
MapCoords.UpdateMinimapPosition = function(self)
	if not self.minimapText then return end
	local minimapModule = ns:GetModule("Minimap", true)
	local anchor = minimapModule and minimapModule.performance or Minimap
	if self.minimapAnchor ~= anchor then
		self.minimapText:ClearAllPoints()
		self.minimapText:SetPoint("TOP", anchor, "BOTTOM", 0, anchor == Minimap and -56 or -4)
		self.minimapAnchor = anchor
	end
end
-- Minimap Coordinates Update
MapCoords.UpdateMinimapCoords = function(self)
	self:UpdateNativeMinimapCoords()
	if not self.minimapText then
		return
	end
	if not ns.db or not ns.db.char or not ns.db.char.mapcoords then
		self.minimapText:SetText("")
		return
	end
	self:UpdateMinimapPosition()
	if ns.db.char.mapcoords.minimap and not ns.db.global.minimap.disabled then
		local x, y = getPlayerCoords()
		if x == 0 and y == 0 then
			self.minimapText:SetText("n/a")
		else
			local useDecimals = ns.db.char.mapcoords.decimals or false
			self.minimapText:SetFormattedText("%s / %s", formatCoord(x, useDecimals), formatCoord(y, useDecimals))
		end
	else
		self.minimapText:SetText("")
	end
end
-- WorldMap Coordinates Update
MapCoords.UpdateWorldMapCoords = function(self)
	if not self.worldMapFrame then
		return
	end
	if not ns.db or not ns.db.char or not ns.db.char.mapcoords then
		self.worldMapText:SetText("")
		return
	end
	local output = ""
	local useDecimals = ns.db.char.mapcoords.decimals or false
	-- Cursor coordinates
	if ns.db.char.mapcoords.worldmapCursor then
		local adjustedX, adjustedY = WorldMapFrame:GetNormalizedCursorPosition()
		if adjustedX > 0 and adjustedY > 0 and adjustedX < 1 and adjustedY < 1 then
			output = format("%s: %s / %s", L["CursorCoords"], formatCoord(adjustedX, useDecimals), formatCoord(adjustedY, useDecimals))
		end
	end
	-- Separator
	if ns.db.char.mapcoords.worldmapCursor and ns.db.char.mapcoords.worldmapPlayer then
		if output ~= "" then
			output = output .. " - "
		end
	end
	-- Player coordinates
	if ns.db.char.mapcoords.worldmapPlayer then
		local x, y = getPlayerCoords()
		if x == 0 and y == 0 then
			output = output .. L["PlayerCoords"] .. ": n/a"
		else
			output = output .. format("%s: %s / %s", L["PlayerCoords"], formatCoord(x, useDecimals), formatCoord(y, useDecimals))
		end
	end
	-- Dynamic positioning based on map state
	if WorldMapFrame:IsMaximized() then
		self.worldMapText:SetPoint("CENTER", WorldMapFrame.BorderFrame, "BOTTOM", 0, 10)
		self.worldMapText:SetTextColor(GameFontNormal:GetTextColor())
	else
		if QuestMapFrame and QuestMapFrame:IsVisible() then
			self.worldMapText:SetPoint("CENTER", WorldMapFrame.BorderFrame, "BOTTOM", -145, 10)
		else
			self.worldMapText:SetPoint("CENTER", WorldMapFrame.BorderFrame, "BOTTOM", 0, 10)
		end
		self.worldMapText:SetTextColor(1, 1, 1, 1)
	end
	self.worldMapFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	self.worldMapText:SetText(output)
end
-- Throttled update system to reduce CPU usage
MapCoords.ThrottledUpdate = function(self, elapsed)
	self.updateTimer = (self.updateTimer or 0) + elapsed
	if self.updateTimer >= 0.1 then -- Update 10 times per second
		self:UpdateMinimapCoords()
		if WorldMapFrame and WorldMapFrame:IsShown() then
			self:UpdateWorldMapCoords()
		end
		self.updateTimer = 0
	end
end
MapCoords.SetupMinimapCoords = function(self)
	if self.minimapText then
		self:UpdateMinimapPosition()
		return
	end
	if not Minimap then return end
	-- Create Minimap coordinates frame
	local minimapFrame = CreateFrame("Frame", "DiabolicUI3MinimapCoords", Minimap)
	minimapFrame:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	minimapFrame:SetAllPoints(Minimap)
	self.minimapFrame = minimapFrame
	local minimapText = minimapFrame:CreateFontString(nil, "OVERLAY")
	minimapText:SetDrawLayer("OVERLAY", 1)
	minimapText:SetFontObject(GetFont(13, true))
	minimapText:SetTextColor(.53, .53, .53, .85)
	minimapText:SetJustifyH("CENTER")
	minimapText:SetJustifyV("BOTTOM")
	self.minimapText = minimapText
	-- The Minimap module can initialize after MapCoords.
	self:UpdateMinimapPosition()
	-- Immediate update
	self:UpdateMinimapCoords()
end
MapCoords.OnInitialize = function(self)
	-- Create WorldMap coordinates frame
	local worldMapFrame = CreateFrame("Frame", "DiabolicUI3WorldMapCoords", WorldMapFrame)
	worldMapFrame:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
	self.worldMapFrame = worldMapFrame
	local worldMapText = worldMapFrame:CreateFontString(nil, "OVERLAY")
	worldMapText:SetFontObject(GameFontNormal)
	worldMapText:SetJustifyH("CENTER")
	worldMapText:SetJustifyV("BOTTOM")
	self.worldMapText = worldMapText
	-- Setup update frame with throttling
	self.updateFrame = CreateFrame("Frame")
	self.updateFrame:SetScript("OnUpdate", function(frame, elapsed)
		self:ThrottledUpdate(elapsed)
	end)
	self.updateTimer = 0
	-- Register events for proper initialization
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ADDON_LOADED")
end
MapCoords.OnEvent = function(self, event, ...)
	if not self:IsEnabled() then return end
	if event == "PLAYER_ENTERING_WORLD" then
		-- Setup minimap coords after entering world
		C_Timer.After(0.5, function()
			if self:IsEnabled() then self:SetupMinimapCoords() end
		end)
	elseif event == "ADDON_LOADED" then
		local addon = ...
		if addon == "DiabolicUI3" then
			-- Try setup immediately
			self:SetupMinimapCoords()
		end
	end
end
MapCoords.OnEnable = function(self)
	if self.updateFrame then self.updateFrame:Show() end
	-- Try to setup minimap coords immediately
	self:SetupMinimapCoords()
	-- Initial update
	self:UpdateMinimapCoords()
end
MapCoords.OnDisable = function(self)
	if self.minimapText then self.minimapText:SetText("") end
	self:UpdateNativeMinimapCoords(true)
	if self.updateFrame then self.updateFrame:Hide() end
end
