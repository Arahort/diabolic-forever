local Addon, ns = ...
local version, build, buildDate, interface = GetBuildInfo()
local major, minor = string.match(version, "^(%d+)%.(%d+)")
local isForever = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18) and tonumber(major) == 1 and tonumber(minor) >= 60
if not isForever then return end
local diagnostics = {}
ns.ForeverDiagnostics = diagnostics
ns.ForeverNativeFallbacks = ns.ForeverNativeFallbacks or {}
local frame = CreateFrame("Frame")
local active, pending, taintOriginal
local function value(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	local kind = type(v)
	if kind == "nil" then return "<nil>" end
	if kind == "number" or kind == "string" or kind == "boolean" then return v end
	if (kind == "table" or kind == "userdata") and v.GetName then
		local ok, name = pcall(v.GetName, v)
		if ok and not (issecretvalue and issecretvalue(name)) then return name or "<unnamed>" end
	end
	return "<"..kind..">"
end
local function read(object, method, ...)
	if not object or type(object[method]) ~= "function" then return "<unavailable>" end
	local ok, result = pcall(object[method], object, ...)
	if ok then return value(result) end
	return "<unreadable>"
end
local function inspect(object)
	if not object then return { exists = false } end
	local state = {
		exists = true, name = value(object), parent = read(object, "GetParent"),
		shown = read(object, "IsShown"), visible = read(object, "IsVisible"),
		scale = read(object, "GetScale"), effectiveScale = read(object, "GetEffectiveScale"),
		width = read(object, "GetWidth"), height = read(object, "GetHeight")
	}
	if object.GetPoint then
		local ok, point, relative, relativePoint, x, y = pcall(object.GetPoint, object, 1)
		if ok then state.anchor = { value(point), value(relative), value(relativePoint), value(x), value(y) } end
	end
	if object.GetAttribute then
		state.page = read(object, "GetAttribute", "state-page")
		state.visibilityDriver = read(object, "GetAttribute", "visibility-driver")
	end
	if object == _G.DiabolicMicroMenuToggle then
		state.mouseEnabled = read(object, "IsMouseEnabled")
		state.clickEnabled = read(object, "IsMouseClickEnabled")
		state.enabled = read(object, "IsEnabled")
		state.secureVisibility = read(object, "GetAttribute", "state-vis")
		state.selectionShown = read(object.Selection, "IsShown")
	end
	if object.__DiabolicForeverStyled then
		state.diabolicCastbar = true
		state.fillTexture = read(object:GetStatusBarTexture(), "GetTexture")
		state.nativeBorderAlpha = read(object.Border, "GetAlpha")
		state.borderWidth = read(object.__DiabolicBorder, "GetWidth")
		state.borderHeight = read(object.__DiabolicBorder, "GetHeight")
		state.castTimeShown = read(object.CastTimeText, "IsShown")
		state.castTimeText = read(object.CastTimeText, "GetText")
	end
	return state
end
local function libraryVersions()
	local versions = {}
	if LibStub then
		for _, name in ipairs({ "AceAddon-3.0", "AceDB-3.0", "AceConsole-3.0", "LibActionButton-1.0", "LibButtonGlow-1.0", "LibButtonGlow-1.0-DiabolicForever", "LibMoreEvents-1.0", "LibOrb-1.0", "LibSmoothBar-1.0" }) do
			local library, revision = LibStub(name, true)
			if library then versions[name] = value(revision) end
		end
	end
	if ns.oUF then versions.oUF = value(ns.oUF._VERSION) end
	if ns.LibEditMode then versions.LibEditMode = value(ns.LibEditMode.hookVersion) end
	return versions
end
local function capabilities()
	return {
		settings = Settings and type(Settings.RegisterProxySetting) == "function" or false,
		editMode = EditModeManagerFrame ~= nil,
		auraContainer = C_UnitAuras and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" or false,
		healthPercent = type(UnitHealthPercent) == "function",
		powerPercent = type(UnitPowerPercent) == "function",
		castDuration = type(UnitCastingDuration) == "function",
		channelDuration = type(UnitChannelDuration) == "function",
		prediction = type(CreateUnitHealPredictionCalculator) == "function",
		nativeRole = UnitFrameUtil and type(UnitFrameUtil.UpdateUnitFrameRoleIcon) == "function" or false,
		stringUtil = C_StringUtil and type(C_StringUtil.TruncateWhenZero) == "function" or false
	}
end
local function security(owner, key)
	if not owner or type(owner[key]) ~= "function" or type(issecurevariable) ~= "function" then return { available = false } end
	local ok, secure, source = pcall(issecurevariable, owner, key)
	return { available = ok, secure = value(secure), source = value(source) }
end
local function snapshot(reason)
	local state = {
		time = time(), reason = reason, combat = InCombatLockdown(),
		libraries = libraryVersions(), capabilities = capabilities(), frames = {}, fallbacks = {}
	}
	state.actionBarsSettingsIcon = value(ns.ForeverActionBarsSettingsIcon)
	state.taintSources = {
		auraWarning = security(AuraContainerMixin, "GetAuraWarningAlphaForDuration"),
		auraFrameWarning = security(BuffFrame and BuffFrame.AuraContainer, "GetAuraWarningAlphaForDuration"),
		damageIcon = security(DamageMeterSourceEntryMixin, "GetIconAtlasElement"),
		damageTexture = security(DamageMeterEntryMixin, "GetIconTexture"),
		damageTimer = security(DamageMeterSessionWindowMixin, "SetSessionDuration"),
		fontScaling = security(ShrinkUntilTruncateFontStringMixin, "ApplyFontObjects"),
		addonLoader = security(C_AddOns, "LoadAddOn")
	}
	for _, name in ipairs({ "MainActionBar", "ActionButton1", "DiabolicPrimaryActionBar", "PetActionBar", "PetActionButton1", "PetFrame", "PlayerBottomManagedFrameContainer", "StanceBar", "MultiCastActionBarFrame", "TotemFrame", "StatusTrackingBarManager", "PlayerCastingBarFrame", "RuneFrame", "DruidComboPointBarFrame", "RogueComboPointBarFrame", "ComboPointPlayerFrame", "BuffFrame", "Minimap", "QueueStatusButton", "CompactRaidFrameManager", "BagsBar", "MainMenuBarBackpackButton", "KeyRingButton" }) do
		state.frames[name] = inspect(_G[name])
	end
	local cluster = MinimapCluster
	state.frames.MicroMenuToggle = inspect(_G.DiabolicMicroMenuToggle)
	state.frames.MicroMenuNative = inspect(_G.MicroMenu)
	state.frames.MicroMenuPopup = inspect(_G.DiabolicMicroMenu)
	local actions = ns.GetModule and ns:GetModule("ActionBars", true)
	local micro = actions and actions:GetModule("MicroMenu", true)
	if micro then state.microMenu = { initializationPending = value(micro.needsInitialization), secureReady = read(micro.toggle, "GetAttribute", "diabolic-menu-ready"), editModePending = value(micro.hasPendingEditModeState), menuEditing = value(micro.bar and micro.bar.inEditMode), libraryEditing = value(ns.LibEditMode and ns.LibEditMode.isEditing) } end
	if micro and micro.bar and (reason == "micro-click" or reason == "manual") then
		state.microButtons = {}
		for _, button in ipairs(micro.bar.buttons or {}) do
			state.microButtons[#state.microButtons + 1] = { name = value(button), enabled = read(button, "IsEnabled"), mouseEnabled = read(button, "IsMouseEnabled"), shown = read(button, "IsShown") }
		end
	end
	local header = ns.PartyHeader
	if header then
		state.partyScaling = { header = inspect(header), members = {} }
		for _, member in ipairs({ header:GetChildren() }) do
			if member.__isDiabolicGroupFrame then
				state.partyScaling.members[#state.partyScaling.members + 1] = inspect(member)
			end
		end
	end
	local backpack = _G.MainMenuBarBackpackButton
	if backpack then state.bagAppearance = { highlightAlpha = read(backpack:GetHighlightTexture(), "GetAlpha"), iconAlpha = read(backpack.__DiabolicIcon, "GetAlpha"), openAlpha = read(backpack.SlotHighlightTexture, "GetAlpha") } end
	state.frames.MinimapExperience = inspect(_G.DiabolicMinimapExperience)
	state.frames.InstanceDifficulty = inspect(cluster and cluster.InstanceDifficulty)
	state.frames.NativeCoords = inspect(cluster and cluster.MinimapContainer and cluster.MinimapContainer.PlayerCoords)
	local player = _G.DiabolicUnitFramePlayer
	local prediction = player and player.HealthPrediction
	if prediction then
		state.healPrediction = {
			native = value(prediction.nativePrediction),
			incomingHeal = read(prediction.IncomingHeal, "GetValue"),
			damageAbsorb = read(prediction.DamageAbsorb, "GetValue"),
			healAbsorb = read(prediction.HealAbsorb, "GetValue")
		}
	end
	local xp = ns.GetModule and ns:GetModule("MinimapExperience", true)
	if xp then
		state.minimapExperience = { active = value(xp.active), current = value(xp.currentXP), maximum = value(xp.maximumXP), fraction = value(xp.fraction), rested = value(xp.rested), radius = value(xp.radius), atlas = value(xp.atlas), thickness = value(xp.thickness), transparency = value(xp.transparency) }
	end
	state.frames.PlayerUnitFrame = inspect(player)
	state.frames.TargetUnitFrame = inspect(_G.DiabolicUnitFrameTarget)
	state.frames.QuestControl = inspect(_G.OverrideActionBar)
	for key, fallback in pairs(ns.ForeverNativeFallbacks) do state.fallbacks[value(key)] = value(fallback) end
	if ns.db then
		state.databaseInitialized = true
		state.savedChar = type(ns.db.char) == "table"
	end
	if C_Map and C_Map.GetBestMapForUnit then state.mapID = value(C_Map.GetBestMapForUnit("player")) end
	if BugGrabberDB and type(BugGrabberDB.errors) == "table" then
		local count = 0
		for _ in pairs(BugGrabberDB.errors) do count = count + 1 end
		state.bugGrabberCount = count
	end
	return state
end
function diagnostics:Record(reason)
	if not active then return end
	local log = DiabolicUI3_ForeverLog
	if not log.enabled then return end
	local ok, record = pcall(snapshot, reason)
	if not ok then record = { time = time(), reason = reason, diagnosticError = value(record) } end
	log.records[#log.records + 1] = record
	while #log.records > 150 do table.remove(log.records, 1) end
end
local function schedule(reason)
	if pending then return end
	pending = true
	C_Timer.After(1, function()
		pending = nil
		diagnostics:Record(reason)
	end)
end
frame:SetScript("OnEvent", function(_, event, addon)
	if event == "ADDON_LOADED" and addon == Addon then
		if type(DiabolicUI3_ForeverLog) ~= "table" then DiabolicUI3_ForeverLog = {} end
		local log = DiabolicUI3_ForeverLog
		log.schema = 1
		log.client = { version = version, build = build, buildDate = buildDate, interface = interface, projectID = WOW_PROJECT_ID }
		log.addonVersion = C_AddOns.GetAddOnMetadata(Addon, "Version")
		log.records = log.records or {}
		if log.enabled == nil then log.enabled = true end
		active = true
		diagnostics:Record("ADDON_LOADED")
	elseif active then
		if event == "PLAYER_LOGOUT" then
			if taintOriginal then C_CVar.SetCVar("taintLog", taintOriginal); taintOriginal = nil end
			diagnostics:Record(event)
		elseif event ~= "ADDON_LOADED" or addon == "Blizzard_Settings" or addon == "Blizzard_QueueStatusFrame" then
			schedule(event)
		end
	end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_REGEN_ENABLED", "UNIT_PET", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS" }) do frame:RegisterEvent(event) end
SLASH_DIABOLICFOREVER1 = "/diabolicforever"
SlashCmdList.DIABOLICFOREVER = function(command)
	if not active then return end
	command = string.lower(command or "")
	if command == "taint" then
		if not taintOriginal then taintOriginal = C_CVar.GetCVar("taintLog") or "0" end
		C_CVar.SetCVar("taintLog", "2")
		print("DiabolicUI Forever: reproduce the issue, then /diabolicforever taintstop and /reload. Native details are saved in Logs/taint.log.")
		return
	elseif command == "taintstop" then
		if taintOriginal then C_CVar.SetCVar("taintLog", taintOriginal); taintOriginal = nil end
		diagnostics:Record("taint-capture-ended")
		return
	elseif command == "stop" then
		DiabolicUI3_ForeverLog.enabled = false
	elseif command == "clear" then
		DiabolicUI3_ForeverLog.records = {}
	else
		DiabolicUI3_ForeverLog.enabled = true
		diagnostics:Record("manual")
	end
	print("DiabolicUI Forever: /reload saves diagnostics to WTF SavedVariables. /diabolicforever snapshot | stop | clear")
end
