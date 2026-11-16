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
local function layoutConstraints(object)
	if not object then return { exists = false } end
	local ok, protected, explicit = pcall(object.IsProtected, object)
	if not ok then protected, explicit = "<unavailable>", "<unavailable>" end
	return {
		exists = true, protected = value(protected), explicit = value(explicit),
		anchoringRestricted = read(object, "IsAnchoringRestricted"), forbidden = read(object, "HasAnyForbiddenAspects"), accessConstraints = read(object, "HasAccessConstraints")
	}
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
local function variableSecurity(owner, key)
	if not owner or type(issecurevariable) ~= "function" then return { available = false } end
	local ok, secure, source = pcall(issecurevariable, owner, key)
	return { available = ok, secure = value(secure), source = value(source) }
end
local function security(owner, key)
	if not owner or type(owner[key]) ~= "function" then return { available = false } end
	return variableSecurity(owner, key)
end
local function tableField(owner, key)
	if type(owner) ~= "table" then return end
	local field = rawget(owner, key)
	if issecretvalue and issecretvalue(field) then return end
	if type(field) == "table" and (not canaccesstable or canaccesstable(field)) then return field end
end
local function fieldSecurity(owner, keys)
	local state = { exists = owner ~= nil }
	if not owner then return state end
	for _, key in ipairs(keys) do state[key] = variableSecurity(owner, key) end
	return state
end
local function callbackSecurity(owner)
	local state = {}
	local tables = tableField(owner, "callbackTables")
	for kind = 1, 2 do
		local events = tableField(tables, kind)
		state[kind] = {}
		for event in pairs(events or {}) do
			if not (issecretvalue and issecretvalue(event)) and type(event) == "string" then
				local callbacks = tableField(events, event)
				local info = { field = variableSecurity(events, event), callbacks = {} }
				for callbackOwner in pairs(callbacks or {}) do
					-- issecurevariable accepts string keys; numeric keys are coerced to strings.
					if not (issecretvalue and issecretvalue(callbackOwner)) then
						info.callbacks[#info.callbacks + 1] = type(callbackOwner) == "string" and variableSecurity(callbacks, callbackOwner) or { available = false, keyType = type(callbackOwner) }
					end
				end
				state[kind][event] = info
			end
		end
	end
	return state
end
local function nativeTaintState()
	-- Inspect provenance only: never invoke refresh/layout callbacks or copy combat values.
	local state = {
		manager = fieldSecurity(EditModeManagerFrame, { "editModeActive", "editModeSystemAnchorDirty", "registeredSystemFrames", "OnShow", "OnHide", "EnterEditMode", "ExitEditMode", "onCloseCallback" }),
		meter = fieldSecurity(DamageMeter, { "isEditing", "visibility", "windowDataList", "OnEvent", "OnEditModeExit", "UpdateShownState" }),
		castingBar = fieldSecurity(PlayerCastingBarFrame, { "showCastTimeSetting", "isManagedFrame", "isBottomManagedFrame", "isInEditMode", "casting", "channeling", "attachedToPlayerFrame" }),
		player = fieldSecurity(PlayerFrame, { "unit" }), auras = {}, windows = {}
	}
	local systems = tableField(EditModeManagerFrame, "registeredSystemFrames")
	state.systemEntries = {}
	for index = 1, systems and #systems or 0 do
		state.systemEntries[index] = fieldSecurity(tableField(systems, index), { "OnEditModeExit", "isSelected", "isHighlighted", "isInEditMode", "snappedFrames", "systemInfo" })
	end
	for _, name in ipairs({ "BuffFrame", "DebuffFrame", "ExternalDefensivesFrame" }) do
		local owner = tableField(_G, name)
		local aura = fieldSecurity(owner, { "isInEditMode", "auraFrames", "AuraContainer", "OnShow", "OnHide", "OnEditModeExit", "SetIsEditing", "Update" })
		aura.container = fieldSecurity(tableField(owner, "AuraContainer"), { "GetAuraWarningAlphaForDuration", "auraWarningMaxAlpha", "WarningFader" })
		aura.buttons = {}
		local buttons = tableField(owner, "auraFrames")
		for index = 1, buttons and #buttons or 0 do
			local button = tableField(buttons, index)
			local fields = fieldSecurity(button, { "isExample", "auraType", "buttonInfo", "timeLeft", "OnUpdate", "Update", "CalculateTimeLeft" })
			fields.info = fieldSecurity(tableField(button, "buttonInfo"), { "count", "expirationTime", "timeMod" })
			aura.buttons[index] = fields
		end
		state.auras[name] = aura
	end
	local function inspectWindow(window)
		local info = fieldSecurity(window, { "isEditing", "sessionType", "sessionID", "OnShow", "OnHide", "OnEvent", "Refresh", "SetSessionDuration", "SetupEntry" })
		local container = tableField(window, "MinimizeContainer") or window
		local scrollBox = tableField(container, "ScrollBox")
		local view = tableField(scrollBox, "view")
		info.scrollBox = fieldSecurity(scrollBox, { "view", "updateLock", "Update", "FullUpdate", "OnViewDataChanged", "callbackTables", "executingEvents" })
		info.view = fieldSecurity(view, { "dataProvider", "frames", "initializers", "elementFactory", "factory", "InvokeInitializers", "callbackTables", "executingEvents" })
		info.scrollBox.callbacks = callbackSecurity(scrollBox)
		info.view.callbacks = callbackSecurity(view)
		info.entries = {}
		local rows = tableField(view, "frames")
		local function inspectEntry(entry)
			return fieldSecurity(entry, { "isClassColorDesired", "style", "numberDisplayType", "sourceName", "nameText", "specIconID", "sessionTotalValue", "GetIconAtlasElement", "UpdateValue" })
		end
		for index = 1, rows and #rows or 0 do info.entries[index] = inspectEntry(tableField(rows, index)) end
		info.localPlayerEntry = inspectEntry(tableField(container, "LocalPlayerEntry"))
		return info, tableField(container, "SourceWindow")
	end
	local windows = tableField(DamageMeter, "windowDataList")
	for index = 1, 3 do
		local window = tableField(tableField(windows, index), "sessionWindow")
		if window then
			local info, source = inspectWindow(window)
			if source then info.source = inspectWindow(source) end
			state.windows[index] = info
		end
	end
	return state
end
local function snapshot(reason)
	local state = {
		time = time(), reason = reason, combat = InCombatLockdown(),
		libraries = libraryVersions(), capabilities = capabilities(), frames = {}, fallbacks = {}
	}
	state.taintLog = value(C_CVar.GetCVar("taintLog"))
	state.actionBarsSettingsIcon = value(ns.ForeverActionBarsSettingsIcon)
	if reason == "manual" or reason == "taint-capture-started" or reason == "taint-capture-ended" then state.nativeTaint = nativeTaintState() end
	state.taintSources = {
		auraWarning = security(AuraContainerMixin, "GetAuraWarningAlphaForDuration"),
		auraFrameWarning = security(BuffFrame and BuffFrame.AuraContainer, "GetAuraWarningAlphaForDuration"),
		damageIcon = security(DamageMeterSourceEntryMixin, "GetIconAtlasElement"),
		damageTexture = security(DamageMeterEntryMixin, "GetIconTexture"),
		damageTimer = security(DamageMeterSessionWindowMixin, "SetSessionDuration"),
		damageName = security(DamageMeterEntryMixin, "UpdateName"),
		editModeAnchorDirty = variableSecurity(EditModeManagerFrame, "editModeSystemAnchorDirty"),
		editModeSystems = variableSecurity(EditModeManagerFrame, "registeredSystemFrames"),
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
	state.frames.PetUnitFrame = inspect(_G.DiabolicUnitFramePet)
	state.frames.PetBarAnchor = inspect(_G.DiabolicUI3PetBarAnchor)
	state.frames.TargetUnitFrame = inspect(_G.DiabolicUnitFrameTarget)
	local combo = ns.ForeverComboPoints
	if combo then
		local row = combo.orbRow
		local parent = row and row:GetParent()
		state.comboPoints = {
			style = value(ns.db and ns.db.global.orbs.style), initialized = combo.player ~= nil,
			class = value(combo.class), maximum = value(combo.maximum), supported = value(combo.supported),
			orbEnabled = value(combo.orbEnabled), targetEnabled = value(combo.targetEnabled),
			resourceOrb = value(ns.db and ns.db.char.unitframes.comboOnResourceOrb),
			orbRow = inspect(row), parent = inspect(parent),
			alpha = read(row, "GetAlpha"), effectiveAlpha = read(row, "GetEffectiveAlpha"),
			strata = read(row, "GetFrameStrata"), level = read(row, "GetFrameLevel")
		}
	end
	local target = _G.DiabolicUnitFrameTarget
	local layout = target and target.Cathedral and target.Cathedral.layout
	if layout then
		state.targetAuraLayout = {
			anchor = layoutConstraints(layout.anchor), castDock = layoutConstraints(layout.castDock), auraDock = layoutConstraints(layout.auraDock), auras = layoutConstraints(target.Auras),
			presentation = ns.ForeverNativeFallbacks.targetAuraLayout,
			unitExistsState = read(layout.anchor, "GetAttribute", "state-unitexists"), combatState = read(layout.anchor, "GetAttribute", "state-combat"), preview = read(layout.anchor, "GetAttribute", "layout-preview")
		}
	end
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
	command = string.lower(string.match(command or "", "^%s*(.-)%s*$"))
	if command == "taint" then
		if not taintOriginal then taintOriginal = C_CVar.GetCVar("taintLog") or "0" end
		C_CVar.SetCVar("taintLog", "2")
		diagnostics:Record("taint-capture-started")
		print("DiabolicUI Forever: taintLog="..tostring(C_CVar.GetCVar("taintLog"))..". Reproduce the issue now, then /diabolicforever taintstop and /reload. Native details are saved in Logs/taint.log.")
		return
	elseif command == "taintstop" then
		C_CVar.SetCVar("taintLog", "0")
		taintOriginal = nil
		diagnostics:Record("taint-capture-ended")
		local current = C_CVar.GetCVar("taintLog") or "<unavailable>"
		print("DiabolicUI Forever: "..(current == "0" and "taint capture stopped" or "could not stop taint capture").."; taintLog="..current..". /reload saves diagnostics.")
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
