local Addon, ns = ...

-- Addon version
------------------------------------------------------
-- Keyword substitution requires the packager,
-- and does not affect direct GitHub repo pulls.
local version = "3.0.0"
if (version:find("project%-version")) then
	version = "Development"
end
ns.Private.Version = version
ns.Private.IsDevelopment = version == "Development"
ns.Private.IsAlpha = string.find(version, "%-Alpha$")
ns.Private.IsBeta = string.find(version, "%-Beta$")
ns.Private.IsRC = string.find(version, "%-RC$")
ns.Private.IsRelease = string.find(version, "%-Release$")

-- WoW client version
------------------------------------------------------
local patch, build, date, version = GetBuildInfo()
local major, minor = string.split(".", patch)

ns.Private.ClientVersion = version
ns.Private.ClientDate = date
ns.Private.ClientPatch = patch
ns.Private.ClientMajor = tonumber(major)
ns.Private.ClientMinor = tonumber(minor)
ns.Private.ClientBuild = tonumber(build)

-- Forever identity is separate from the historical Retail switches below.
local isForever = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18) and tonumber(major) == 1 and tonumber(minor) >= 60
ns.Private.IsForever = isForever
rawset(ns, "IsForever", isForever)
ns.Client = {
	IsForever = isForever,
	ProjectID = WOW_PROJECT_ID,
	Interface = version,
	ModernUI = isForever and type(Settings) == "table" and type(EditModeManagerFrame) == "table",
	HasSettings = Settings and type(Settings.RegisterProxySetting) == "function" or false,
	HasEditMode = EditModeManagerFrame ~= nil,
	HasAuraContainer = C_UnitAuras and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" or false,
	HasDurationObjects = type(UnitCastingDuration) == "function" and type(UnitChannelDuration) == "function"
}
-- Simple flags for client version checks
-- All flags disabled - unified codebase
ns.IsRetail = false
ns.Private.IsRetail = false
ns.Private.IsClassic = false
ns.Private.IsTBC = false
ns.Private.IsWrath = false
ns.Private.WoW10 = false

-- Prefix for frame names
------------------------------------------------------
ns.Private.Prefix = string.gsub(Addon, "UI(%d*)", "")

-- Player constants
------------------------------------------------------
local _,playerClass = UnitClass("player")
ns.Private.PlayerClass = playerClass
ns.Private.PlayerRealm = GetRealmName()
ns.Private.PlayerName = UnitNameUnmodified("player")

-- Scaling Constants
------------------------------------------------------
ns.UIScale = 0.6
ns.Private.UIDefaultScale = 0.6

-- Create aliases for backward compatibility
------------------------------------------------------
-- Use rawset to bypass metatable protection
rawset(ns, "IsRetail", false)
rawset(ns, "IsClassic", false)
rawset(ns, "IsTBC", false)
rawset(ns, "IsWrath", false)
rawset(ns, "WoW10", false)
rawset(ns, "Prefix", ns.Private.Prefix)
rawset(ns, "PlayerClass", ns.Private.PlayerClass)
rawset(ns, "PlayerRealm", ns.Private.PlayerRealm)
rawset(ns, "PlayerName", ns.Private.PlayerName)
