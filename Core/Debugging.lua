local Addon, ns = ...
local Debugging = ns:NewModule("Debugging", "AceConsole-3.0")

-- Lua API
local ipairs = ipairs
local print = print
local select = select
local string_format = string.format

-- WoW API
local EnableAddOn = C_AddOns.EnableAddOn
local GetAddOnInfo = C_AddOns.GetAddOnInfo

local ADDONS = (ns.IsRetail) and {

	"Blizzard_AchievementUI",
	"Blizzard_AdventureMap",
	"Blizzard_AlliedRacesUI",
	"Blizzard_AnimaDiversionUI",
	"Blizzard_APIDocumentation",
	"Blizzard_ArchaeologyUI",
	"Blizzard_ArdenwealdGardening",
	"Blizzard_ArenaUI",
	"Blizzard_ArtifactUI",
	"Blizzard_AuctionHouseUI",
	"Blizzard_AuthChallengeUI",
	"Blizzard_AzeriteEssenceUI",
	"Blizzard_AzeriteRespecUI",
	"Blizzard_AzeriteUI",
	"Blizzard_BarbershopUI",
	"Blizzard_BattlefieldMap",
	"Blizzard_BehavioralMessaging",
	"Blizzard_BlackMarketUI",
	"Blizzard_BoostTutorial",
	"Blizzard_Calendar",
	"Blizzard_ChallengesUI",
	"Blizzard_Channels",
	"Blizzard_CharacterCreate",
	"Blizzard_CharacterCustomize",
	"Blizzard_ChromieTimeUI",
	"Blizzard_ClassTalentUI",
	"Blizzard_ClassTrial",
	"Blizzard_ClickBindingUI",
	"Blizzard_ClientSavedVariables",
	"Blizzard_Collections",
	"Blizzard_CombatLog",
	"Blizzard_CombatText",
	"Blizzard_Commentator",
	"Blizzard_Communities",
	"Blizzard_CompactRaidFrames",
	"Blizzard_Console",
	"Blizzard_Contribution",
	"Blizzard_CovenantCallings",
	"Blizzard_CovenantPreviewUI",
	"Blizzard_CovenantRenown",
	"Blizzard_CovenantSanctum",
	"Blizzard_CovenantToasts",
	"Blizzard_CUFProfiles",
	"Blizzard_DeathRecap",
	"Blizzard_DebugTools",
	"Blizzard_Deprecated",
	"Blizzard_EncounterJournal",
	"Blizzard_EventTrace",
	"Blizzard_ExpansionLandingPage",
	"Blizzard_FlightMap",
	"Blizzard_FrameEffects",
	"Blizzard_GarrisonTemplates",
	"Blizzard_GarrisonUI",
	"Blizzard_GenericTraitUI",
	"Blizzard_GMChatUI",
	"Blizzard_GuildBankUI",
	"Blizzard_GuildControlUI",
	"Blizzard_GuildUI",
	"Blizzard_HybridMinimap",
	"Blizzard_InspectUI",
	"Blizzard_IslandsPartyPoseUI",
	"Blizzard_IslandsQueueUI",
	"Blizzard_ItemInteractionUI",
	"Blizzard_ItemSocketingUI",
	"Blizzard_ItemUpgradeUI",
	"Blizzard_Kiosk",
	"Blizzard_LandingSoulbinds",
	"Blizzard_MacroUI",
	"Blizzard_MainlineSettings",
	"Blizzard_MajorFactions",
	"Blizzard_MapCanvas",
	"Blizzard_MawBuffs",
	"Blizzard_MoneyReceipt",
	"Blizzard_MovePad",
	"Blizzard_NamePlates",
	"Blizzard_NewPlayerExperience",
	"Blizzard_NewPlayerExperienceGuide",
	"Blizzard_ObjectiveTracker",
	"Blizzard_ObliterumUI",
	"Blizzard_OrderHallUI",
	"Blizzard_PartyPoseUI",
	"Blizzard_PetBattleUI",
	"Blizzard_PlayerChoice",
	"Blizzard_Professions",
	"Blizzard_ProfessionsCrafterOrders",
	"Blizzard_ProfessionsCustomerOrders",
	"Blizzard_PTRFeedback",
	"Blizzard_PTRFeedbackGlue",
	"Blizzard_PVPMatch",
	"Blizzard_PVPUI",
	"Blizzard_QuestNavigation",
	"Blizzard_RaidUI",
	"Blizzard_RuneforgeUI",
	"Blizzard_ScrappingMachineUI",
	"Blizzard_SecureTransferUI",
	"Blizzard_SelectorUI",
	"Blizzard_Settings",
	"Blizzard_SharedMapDataProviders",
	"Blizzard_SharedTalentUI",
	"Blizzard_SocialUI",
	"Blizzard_Soulbinds",
	"Blizzard_StoreUI",
	"Blizzard_SubscriptionInterstitialUI",
	"Blizzard_TalentUI",
	"Blizzard_TalkingHeadUI",
	"Blizzard_TimeManager",
	"Blizzard_TokenUI",
	"Blizzard_TorghastLevelPicker",
	"Blizzard_TrainerUI",
	"Blizzard_Tutorial",
	"Blizzard_TutorialTemplates",
	"Blizzard_UIFrameManager",
	"Blizzard_UIWidgets",
	"Blizzard_VoidStorageUI",
	"Blizzard_WarfrontsPartyPoseUI",
	"Blizzard_WeeklyRewards",
	"Blizzard_WorldMap",
	"Blizzard_WowTokenUI"

}

Debugging.EnableBlizzardAddOns = function(self)
	if (not ADDONS) then
		return
	end
	local disabled = {}
	for _,addon in next,ADDONS do
		local reason = select(5, GetAddOnInfo(addon))
		if (reason == "DISABLED") then
			EnableAddOn(addon)
			disabled[#disabled + 1] = addon
		end
	end
	local num = #disabled
	if (num == 0) then
		print("|cff33ff99", "No Blizzard addons were disabled.")
	else
		if (num > 1) then
			print("|cff33ff99", string_format("The following %d Blizzard addons were enabled:", #disabled))
		else
			print("|cff33ff99", "The following Blizzard addon was enabled:")
		end
		for _,addon in next,ADDONS do
			print(string_format("|cfff0f0f0%s|r", addon))
		end
	end
end

local DiagnosticValue = function(value)
	if (issecretvalue and issecretvalue(value)) then return "<secret>" end
	local kind = type(value)
	if (kind == "nil") then return "<nil>" end
	if (kind == "string" or kind == "number" or kind == "boolean") then return value end
	if ((kind == "table" or kind == "userdata") and value.GetName) then
		local ok, name = pcall(value.GetName, value)
		if (ok and not (issecretvalue and issecretvalue(name))) then return name or "<unnamed>" end
	end
	return "<"..kind..">"
end
local DiagnosticRead = function(object, method)
	if (not object or not object[method]) then return "<unavailable>" end
	local ok, value = pcall(object[method], object)
	if (ok) then return DiagnosticValue(value) end
	return "<unreadable>"
end
local DiagnosticFrame = function(frame)
	if (not frame) then return { exists = false } end
	local data = {
		exists = true, name = DiagnosticValue(frame),
		parent = DiagnosticRead(frame, "GetParent"),
		shown = DiagnosticRead(frame, "IsShown"), visible = DiagnosticRead(frame, "IsVisible"),
		scale = DiagnosticRead(frame, "GetScale"), effectiveScale = DiagnosticRead(frame, "GetEffectiveScale"),
		width = DiagnosticRead(frame, "GetWidth"), height = DiagnosticRead(frame, "GetHeight")
	}
	if (frame.GetPoint) then
		local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
		if (ok) then data.point = { DiagnosticValue(point), DiagnosticValue(relative), DiagnosticValue(relativePoint), DiagnosticValue(x), DiagnosticValue(y) } end
	end
	if (frame.GetText) then data.text = DiagnosticRead(frame, "GetText") end
	if (frame.GetFont) then
		local ok, path, size, flags = pcall(frame.GetFont, frame)
		if (ok) then data.font = { DiagnosticValue(path), DiagnosticValue(size), DiagnosticValue(flags) } end
	end
	return data
end
Debugging.GetDiagnosticLog = function(self)
	if (not ns.db) then return end
	local global = ns.db.global
	if (not global.diagnostics) then global.diagnostics = { enabled = false, records = {} } end
	return global.diagnostics
end
Debugging.CaptureDiagnostics = function(self, reason)
	local log = self:GetDiagnosticLog()
	if (not log or not log.enabled) then return end
	local version, build, buildDate, interface = GetBuildInfo()
	local cluster = MinimapCluster
	local container = cluster and cluster.MinimapContainer
	local minimap = ns:GetModule("Minimap", true)
	local coords = ns:GetModule("MapCoords", true)
	local mapID = C_Map.GetBestMapForUnit("player")
	local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	local x, y
	if (position) then x, y = position:GetXY() end
	local libraries = {}
	for _, name in ipairs({ "AceAddon-3.0", "AceDB-3.0", "AceConsole-3.0", "CallbackHandler-1.0", "LibActionButton-1.0", "LibButtonGlow-1.0", "LibMoreEvents-1.0", "LibOrb-1.0", "LibSmoothBar-1.0" }) do
		local lib, minor = LibStub(name, true)
		if (lib) then libraries[name] = DiagnosticValue(minor) end
	end
	libraries.oUF = ns.oUF and DiagnosticValue(ns.oUF._VERSION)
	libraries.LibEditMode = ns.LibEditMode and DiagnosticValue(ns.LibEditMode.hookVersion)
	local record = {
		time = time(), reason = reason, version = version, build = build, buildDate = buildDate, interface = interface,
		combat = InCombatLockdown(), libraries = libraries,
		map = { id = DiagnosticValue(mapID), x = DiagnosticValue(x), y = DiagnosticValue(y) },
		frames = {
			minimap = DiagnosticFrame(Minimap), cluster = DiagnosticFrame(cluster),
			queue = DiagnosticFrame(QueueStatusButton), queueHolder = DiagnosticFrame(minimap and minimap.queueHolder),
			difficulty = DiagnosticFrame(cluster and cluster.InstanceDifficulty),
			nativeCoords = DiagnosticFrame(container and container.PlayerCoords),
			customCoords = DiagnosticFrame(coords and coords.minimapText),
			legacyCoords = DiagnosticFrame(minimap and minimap.coordinates)
		},
		coordsEnabled = ns.db.char.mapcoords and ns.db.char.mapcoords.minimap,
		nativeCoordsCVar = C_CVar.GetCVar("minimapShowPlayerCoords"),
		taintLessPatch = DiagnosticValue(_G.UIDD_REFRESH_OVERREAD_PATCH_VERSION)
	}
	log.records = log.records or {}
	log.records[#log.records + 1] = record
	while (#log.records > 80) do table.remove(log.records, 1) end
end
Debugging.DiagnosticCommand = function(self, input)
	local command = string.lower(input or "")
	local log = self:GetDiagnosticLog()
	if (not log) then return end
	if (command == "stop") then
		log.enabled = false
		print("DiabolicUI: diagnostics stopped. /reload saves the log to disk.")
	elseif (command == "clear") then
		log.records = {}
		print("DiabolicUI: diagnostic records cleared.")
	elseif (command == "start" or command == "") then
		log.enabled = true
		self:CaptureDiagnostics("manual")
		print("DiabolicUI: diagnostics enabled. /diaboliclog snapshot captures state; /reload saves it to disk.")
	elseif (command == "snapshot") then
		self:CaptureDiagnostics("manual")
		print("DiabolicUI: snapshot captured. /reload saves it to disk.")
	else
		print("DiabolicUI: /diaboliclog start | snapshot | stop | clear")
	end
end
Debugging.OnEnable = function(self)
	self.diagnosticFrame = self.diagnosticFrame or CreateFrame("Frame")
	local frame = self.diagnosticFrame
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "EDIT_MODE_LAYOUTS_UPDATED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "LFG_UPDATE", "PLAYER_LOGOUT" }) do
		frame:RegisterEvent(event)
	end
	frame:SetScript("OnEvent", function(_, event)
		local log = self:GetDiagnosticLog()
		if (not log or not log.enabled) then return end
		if (event == "PLAYER_LOGOUT") then
			self:CaptureDiagnostics(event)
		elseif (not self.diagnosticPending) then
			self.diagnosticPending = true
			C_Timer.After(1, function()
				self.diagnosticPending = nil
				self:CaptureDiagnostics(event)
			end)
		end
	end)
end
Debugging.OnDisable = function(self)
	if (self.diagnosticFrame) then self.diagnosticFrame:UnregisterAllEvents() end
end
Debugging.OnInitialize = function(self)
	self:RegisterChatCommand("diaboliclog", "DiagnosticCommand")
	for _,cmd in next, { "enableblizz", "enableblizzard", "fixblizz", "fixblizzard" } do
		self:RegisterChatCommand(cmd, "EnableBlizzardAddOns")
	end
end
