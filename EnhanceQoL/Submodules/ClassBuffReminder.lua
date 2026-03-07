local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.ClassBuffReminder = addon.ClassBuffReminder or {}
local Reminder = addon.ClassBuffReminder

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType
local LBG = LibStub("LibButtonGlow-1.0", true)
local issecretvalue = _G.issecretvalue
local UnitInPartyIsAI = _G.UnitInPartyIsAI
local GetTimePreciseSec = _G.GetTimePreciseSec

local EDITMODE_ID = "classBuffReminder"
local ICON_MISSING = "Interface\\Icons\\INV_Misc_QuestionMark"
local DISPLAY_MODE_FULL = "FULL"
local DISPLAY_MODE_ICON_ONLY = "ICON_ONLY"
local GROWTH_RIGHT = "RIGHT"
local GROWTH_LEFT = "LEFT"
local GROWTH_UP = "UP"
local GROWTH_DOWN = "DOWN"
local TEXT_OUTLINE_NONE = "NONE"
local TEXT_OUTLINE_OUTLINE = "OUTLINE"
local TEXT_OUTLINE_THICK = "THICKOUTLINE"
local TEXT_OUTLINE_MONO = "MONOCHROME_OUTLINE"
local SAMPLE_SPELL_IDS = { 1126, 1459, 21562, 6673, 381748 }
local SAMPLE_ICON_COUNT = 5
local AURA_FILTER_HELPFUL = "HELPFUL"
local AURA_SLOT_BATCH_SIZE = 32
local AURA_SLOT_SCAN_GUARD = 16

local DB_ENABLED = "classBuffReminderEnabled"
local DB_SHOW_PARTY = "classBuffReminderShowParty"
local DB_SHOW_RAID = "classBuffReminderShowRaid"
local DB_SHOW_SOLO = "classBuffReminderShowSolo"
local DB_GLOW = "classBuffReminderGlow"
local DB_SOUND_ON_MISSING = "classBuffReminderSoundOnMissing"
local DB_MISSING_SOUND = "classBuffReminderMissingSound"
local DB_DISPLAY_MODE = "classBuffReminderDisplayMode"
local DB_GROWTH_DIRECTION = "classBuffReminderGrowthDirection"
local DB_GROWTH_FROM_CENTER = "classBuffReminderGrowthFromCenter"
local DB_TRACK_FLASKS = "classBuffReminderTrackFlasks"
local DB_TRACK_FLASKS_INSTANCE_ONLY = "classBuffReminderTrackFlasksInstanceOnly"
local DB_SCALE = "classBuffReminderScale"
local DB_ICON_SIZE = "classBuffReminderIconSize"
local DB_FONT_SIZE = "classBuffReminderFontSize"
local DB_ICON_GAP = "classBuffReminderIconGap"
local DB_XY_TEXT_SIZE = "classBuffReminderXYTextSize"
local DB_XY_TEXT_OUTLINE = "classBuffReminderXYTextOutline"
local DB_XY_TEXT_COLOR = "classBuffReminderXYTextColor"
local DB_XY_TEXT_OFFSET_X = "classBuffReminderXYTextOffsetX"
local DB_XY_TEXT_OFFSET_Y = "classBuffReminderXYTextOffsetY"
local DB_SOUND_DEBUG_TRACE = "classBuffReminderSoundDebugTrace"
local SOUND_DEBUG_TRACE_MAX = 200

Reminder.defaults = Reminder.defaults
	or {
		enabled = false,
		showParty = true,
		showRaid = true,
		showSolo = false,
		glow = true,
		soundOnMissing = false,
		missingSound = "",
		displayMode = DISPLAY_MODE_ICON_ONLY,
		growthDirection = GROWTH_RIGHT,
		growthFromCenter = false,
		trackFlasks = false,
		trackFlasksInstanceOnly = false,
		scale = 1,
		iconSize = 64,
		fontSize = 13,
		iconGap = 6,
		xyTextSize = 13,
		xyTextOutline = TEXT_OUTLINE_OUTLINE,
		xyTextColor = { r = 1, g = 1, b = 1, a = 1 },
		xyTextOffsetX = 0,
		xyTextOffsetY = 0,
	}

local defaults = Reminder.defaults

local PROVIDER_SCOPE_GROUP = "GROUP"
local PROVIDER_SCOPE_SELF = "SELF"
local GROUP_UNIT_STATUS_INELIGIBLE = -1
local GROUP_UNIT_STATUS_PRESENT = 0
local GROUP_UNIT_STATUS_MISSING = 1

local EVOKER_BLESSING_OF_BRONZE_IDS = {
	381732,
	381741,
	381746,
	381748,
	381749,
	381750,
	381751,
	381752,
	381753,
	381754,
	381756,
	381757,
	381758,
}

local EVOKER_SOURCE_OF_MAGIC_IDS = {
	369459, -- Source of Magic
}

-- Shared flask auras (TWW + Midnight). Used for reminder presence checks.
local SHARED_FLASK_AURA_IDS = {
	432021,
	431971,
	431972,
	431973,
	431974,
	1235057,
	1235108,
	1235110,
	1235111,
}

local PROVIDER_BY_CLASS = {
	DRUID = {
		scope = PROVIDER_SCOPE_GROUP,
		spellIds = { 1126 },
		fallbackName = "Mark of the Wild",
	},
	MAGE = {
		scope = PROVIDER_SCOPE_GROUP,
		spellIds = { 1459 },
		fallbackName = "Arcane Intellect",
	},
	PRIEST = {
		scope = PROVIDER_SCOPE_GROUP,
		spellIds = { 21562 },
		fallbackName = "Power Word: Fortitude",
	},
	WARRIOR = {
		scope = PROVIDER_SCOPE_GROUP,
		spellIds = { 6673 },
		fallbackName = "Battle Shout",
	},
	EVOKER = {
		scope = PROVIDER_SCOPE_GROUP,
		spellIds = EVOKER_BLESSING_OF_BRONZE_IDS,
		fallbackName = "Blessing of the Bronze",
	},
	SHAMAN = {
		scope = PROVIDER_SCOPE_GROUP,
		spellIds = { 462854 },
		fallbackName = "Skyfury",
	},
}

local PALADIN_RITES = {
	adjuration = {
		spellId = 433583,
		buffIds = { 433583 },
		fallbackName = "Rite of Adjuration",
		enchantId = 7144,
	},
	sanctification = {
		spellId = 433568,
		buffIds = { 433568 },
		fallbackName = "Rite of Sanctification",
		enchantId = 7143,
	},
}

local ROGUE_POISON_LETHAL_IDS = {
	315584, -- Instant Poison
	2823, -- Deadly Poison
	8679, -- Wound Poison
	381664, -- Amplifying Poison
}

local ROGUE_POISON_UTILITY_IDS = {
	3408, -- Crippling Poison
	5761, -- Numbing Poison
	381637, -- Atrophic Poison
}

local SHAMAN_SPEC_ENHANCEMENT = 263
local SHAMAN_SPEC_RESTORATION = 264

local SHAMAN_ENHANCEMENT_WINDFURY_IDS = {
	319773, -- Windfury Weapon (modern aura id)
	33757, -- Windfury Weapon (legacy aura id)
}

local SHAMAN_ENHANCEMENT_FLAMETONGUE_IDS = {
	319778, -- Flametongue Weapon (modern aura id)
	318038, -- Flametongue Weapon (legacy aura id)
}

local SHAMAN_RESTORATION_EARTHLIVING_IDS = {
	382021,
	382022,
	382024, -- Earthliving Weapon (aura variant)
}

local SHAMAN_RESTORATION_TIDECALLER_IDS = {
	457481, -- Tidecaller's Guard
	457496, -- Tidecaller's Guard
}

local SHAMAN_RESTORATION_EARTHLIVING_AURA_NAMES = {
	"Earthliving Weapon",
}

local SHAMAN_RESTORATION_TIDECALLER_AURA_NAMES = {
	"Tidecaller's Guard",
}

local spellPresentationCache = {}
local spellDataLoadRequested = {}
local auraSlotResultBuffer = {}
local auraSlotResultCount = 0

local function normalizeCachedSpellId(value)
	local spellId = tonumber(value)
	if not spellId or spellId <= 0 then return nil end
	return spellId
end

local function getCachedSpellPresentation(spellId)
	spellId = normalizeCachedSpellId(spellId)
	if not spellId then return nil, nil end

	local cached = spellPresentationCache[spellId]
	if cached and cached.name and cached.icon then return cached.name, cached.icon end

	local name
	local icon

	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellId)
		if type(info) == "table" then
			if type(info.name) == "string" and info.name ~= "" then name = info.name end
			if info.iconID and info.iconID ~= "" then icon = info.iconID end
		end
	end

	if not name and C_Spell and C_Spell.GetSpellName then
		local directName = C_Spell.GetSpellName(spellId)
		if type(directName) == "string" and directName ~= "" then name = directName end
	end

	if not icon and C_Spell.GetSpellTexture then
		local fallbackIcon = C_Spell.GetSpellTexture(spellId)
		if fallbackIcon and fallbackIcon ~= "" then icon = fallbackIcon end
	end

	if not cached then
		cached = {}
		spellPresentationCache[spellId] = cached
	end
	if name and name ~= "" then cached.name = name end
	if icon and icon ~= "" then cached.icon = icon end

	return cached.name, cached.icon
end

local function captureAuraSlotResults(...)
	local count = select("#", ...)
	for i = 1, count do
		auraSlotResultBuffer[i] = select(i, ...)
	end
	if auraSlotResultCount > count then
		for i = count + 1, auraSlotResultCount do
			auraSlotResultBuffer[i] = nil
		end
	end
	auraSlotResultCount = count

	local nextToken = auraSlotResultBuffer[1]
	if issecretvalue and issecretvalue(nextToken) then nextToken = nil end
	return auraSlotResultBuffer, count, nextToken
end

local function getHelpfulAuraSlotBuffer(unit, continuationToken)
	if continuationToken ~= nil then return captureAuraSlotResults(C_UnitAuras.GetAuraSlots(unit, AURA_FILTER_HELPFUL, AURA_SLOT_BATCH_SIZE, continuationToken)) end
	return captureAuraSlotResults(C_UnitAuras.GetAuraSlots(unit, AURA_FILTER_HELPFUL, AURA_SLOT_BATCH_SIZE))
end

local function clamp(value, minValue, maxValue, fallback)
	local n = tonumber(value)
	if n == nil then return fallback end
	if minValue ~= nil and n < minValue then n = minValue end
	if maxValue ~= nil and n > maxValue then n = maxValue end
	return n
end

local function clamp01(value)
	local n = tonumber(value) or 1
	if n < 0 then return 0 end
	if n > 1 then return 1 end
	return n
end

local function normalizeColor(value, fallback)
	local fb = fallback or { r = 1, g = 1, b = 1, a = 1 }
	if type(value) == "table" then
		return clamp01(value.r or value[1] or fb.r), clamp01(value.g or value[2] or fb.g), clamp01(value.b or value[3] or fb.b), clamp01(value.a or value[4] or fb.a or 1)
	end
	return clamp01(fb.r), clamp01(fb.g), clamp01(fb.b), clamp01(fb.a or 1)
end

local function getValue(key, fallback)
	if not addon.db then return fallback end
	local value = addon.db[key]
	if value == nil then return fallback end
	return value
end

local function isTrackedUnit(unit)
	if type(unit) ~= "string" then return false end
	if unit == "player" then return true end
	if unit:find("^party%d+$") then return true end
	if unit:find("^raid%d+$") then return true end
	return false
end

local function canEvaluateUnit(unit)
	if type(unit) ~= "string" or unit == "" then return false end
	if not (UnitExists and UnitExists(unit)) then return false end
	if not (UnitIsConnected and UnitIsConnected(unit)) then return false end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
	return true
end

local function isAIFollowerUnit(unit)
	if type(unit) ~= "string" or unit == "player" then return false end
	if not UnitInPartyIsAI then return false end
	local isAI = UnitInPartyIsAI(unit)
	return isAI == true
end

local function isUnitHealerRole(unit)
	if type(unit) ~= "string" or unit == "" then return false end
	if not UnitGroupRolesAssigned then return false end
	local role = UnitGroupRolesAssigned(unit)
	if issecretvalue and issecretvalue(role) then return false end
	return role == "HEALER"
end

local function isPlayerOffhandShield()
	if not GetItemInfoInstant then return false end

	local offhandSlot = INVSLOT_OFFHAND or 17
	if GetInventoryItemID then
		local offhandItemId = GetInventoryItemID("player", offhandSlot)
		if offhandItemId then
			local equipLocById = select(4, GetItemInfoInstant(offhandItemId))
			if equipLocById == "INVTYPE_SHIELD" then return true end
		end
	end

	if not GetInventoryItemLink then return false end
	local offhandLink = GetInventoryItemLink("player", offhandSlot)
	if type(offhandLink) ~= "string" or offhandLink == "" then return false end
	local equipLoc = select(4, GetItemInfoInstant(offhandLink))
	return equipLoc == "INVTYPE_SHIELD"
end

local function safeGetSpellName(spellId)
	local name = getCachedSpellPresentation(spellId)
	return name
end

local function requestSpellDataLoad(spellId)
	spellId = normalizeCachedSpellId(spellId)
	if not spellId then return end
	if spellDataLoadRequested[spellId] == true then return end
	spellDataLoadRequested[spellId] = true
	if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellId) end
end

local function getSpellIconRaw(spellId)
	local _, icon = getCachedSpellPresentation(spellId)
	return icon
end

local function safeGetSpellIcon(spellId) return getSpellIconRaw(spellId) or ICON_MISSING end

local function normalizeSpellId(value)
	if value == nil then return nil end
	if issecretvalue and issecretvalue(value) then return nil end
	local spellId = tonumber(value)
	if not spellId or spellId <= 0 then return nil end
	return spellId
end

local function normalizeAuraInstanceId(value)
	if value == nil then return nil end
	if issecretvalue and issecretvalue(value) then return nil end
	local auraId = tonumber(value)
	if not auraId or auraId <= 0 then return nil end
	return auraId
end

local function wipeTable(target)
	if type(target) ~= "table" then return end
	if wipe then
		wipe(target)
		return
	end
	for key in pairs(target) do
		target[key] = nil
	end
end

local function normalizeDisplayMode(value)
	if value == DISPLAY_MODE_ICON_ONLY then return DISPLAY_MODE_ICON_ONLY end
	return DISPLAY_MODE_FULL
end

local function normalizeGrowthDirection(value)
	if value == GROWTH_LEFT then return GROWTH_LEFT end
	if value == GROWTH_UP then return GROWTH_UP end
	if value == GROWTH_DOWN then return GROWTH_DOWN end
	return GROWTH_RIGHT
end

local function normalizeTextOutline(value)
	if value == TEXT_OUTLINE_NONE then return TEXT_OUTLINE_NONE end
	if value == TEXT_OUTLINE_THICK then return TEXT_OUTLINE_THICK end
	if value == TEXT_OUTLINE_MONO then return TEXT_OUTLINE_MONO end
	return TEXT_OUTLINE_OUTLINE
end

local function textOutlineFlags(value)
	local outline = normalizeTextOutline(value)
	if outline == TEXT_OUTLINE_NONE then return "" end
	if outline == TEXT_OUTLINE_THICK then return "THICKOUTLINE" end
	if outline == TEXT_OUTLINE_MONO then return "OUTLINE,MONOCHROME" end
	return "OUTLINE"
end

local function centeredAxisOffset(index, count, step)
	local idx = tonumber(index)
	local total = tonumber(count)
	local spacing = tonumber(step)
	if not idx or not total or not spacing then return 0 end
	return ((idx - 1) - ((total - 1) / 2)) * spacing
end

local function safeIsPlayerSpell(spellId)
	spellId = normalizeSpellId(spellId)
	if not spellId then return false end

	if C_SpellBook and C_SpellBook.IsSpellKnown then
		if C_SpellBook.IsSpellKnown(spellId) then return true end
	end

	if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellId) then return true end

	if IsPlayerSpell and IsPlayerSpell(spellId) then return true end

	return false
end

local function hasKnownSpellInList(spellIds)
	if type(spellIds) ~= "table" then return false end
	for i = 1, #spellIds do
		if safeIsPlayerSpell(spellIds[i]) then return true end
	end
	return false
end

local function unitHasAuraBySpellId(unit, spellId)
	spellId = normalizeSpellId(spellId)
	if not spellId then return false end
	if type(unit) ~= "string" or unit == "" then return false end

	if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
		if C_UnitAuras.GetUnitAuraBySpellID(unit, spellId) ~= nil then return true end
	end

	if C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
		local continuationToken
		for _ = 1, AURA_SLOT_SCAN_GUARD do
			local slots, slotCount, nextToken = getHelpfulAuraSlotBuffer(unit, continuationToken)
			for i = 2, slotCount do
				local slot = slots[i]
				if not (issecretvalue and issecretvalue(slot)) then
					local aura = C_UnitAuras.GetAuraDataBySlot(unit, slot)
					if aura and not (issecretvalue and issecretvalue(aura)) then
						local isHelpful = aura.isHelpful
						if issecretvalue and issecretvalue(isHelpful) then isHelpful = nil end
						if isHelpful ~= false then
							local auraSpellId = normalizeSpellId(aura.spellId)
							if auraSpellId and auraSpellId == spellId then return true end
						end
					end
				end
			end

			if nextToken == nil then break end
			continuationToken = nextToken
		end
	end

	-- Some weapon-imbue auras can surface with an alternate spellID but keep the same aura name.
	local spellName = safeGetSpellName(spellId)
	if type(spellName) == "string" and spellName ~= "" and Reminder and Reminder.UnitHasAnyAuraName then
		if Reminder:UnitHasAnyAuraName(unit, { spellName }) then return true end
	end

	return false
end

local function playerHasEnchantId(enchantId)
	enchantId = tonumber(enchantId)
	if not enchantId or enchantId <= 0 then return false end
	if not GetWeaponEnchantInfo then return false end

	local hasMain, _, _, mainEnchantId, hasOff, _, _, offEnchantId = GetWeaponEnchantInfo()
	if hasMain and tonumber(mainEnchantId) == enchantId then return true end
	if hasOff and tonumber(offEnchantId) == enchantId then return true end
	return false
end

local function playerHasAnyEnchantId(enchantIds)
	if type(enchantIds) == "table" then
		for i = 1, #enchantIds do
			if playerHasEnchantId(enchantIds[i]) then return true end
		end
		return false
	end
	return playerHasEnchantId(enchantIds)
end

local function resetProviderRuntimeCache(provider)
	if type(provider) ~= "table" then return end
	provider.stateVersion = (tonumber(provider.stateVersion) or 0) + 1
	provider.spellSet = nil
	provider.spellNameSet = nil
	provider.spellNameSetReady = nil
	provider.spellNameRefreshAttempts = nil
	provider.displaySpellId = nil
	provider.cachedName = nil
	provider.cachedIcon = nil
	provider._presentationReady = nil
	provider._presentationAttempted = nil
	provider.presentationRetryPending = nil
	provider.presentationRetryCount = nil
end

local function getProviderStateVersion(provider)
	if type(provider) ~= "table" then return 0 end
	local version = tonumber(provider.stateVersion)
	if not version or version <= 0 then
		provider.stateVersion = 1
		return 1
	end
	return version
end

local function setProviderDisplaySpellId(provider, spellId)
	if type(provider) ~= "table" then return end
	local sid = normalizeSpellId(spellId)
	if not sid then return end
	if provider.displaySpellId == sid and provider.cachedIcon and provider.cachedIcon ~= "" then return end
	provider.displaySpellId = sid
	provider.cachedName = nil
	provider.cachedIcon = nil
	provider._presentationReady = nil
	provider._presentationAttempted = nil
end

local function makeSelfMissingEntry(spellId, label, countMissing, countTotal)
	return {
		spellId = normalizeSpellId(spellId),
		label = label,
		countMissing = tonumber(countMissing),
		countTotal = tonumber(countTotal),
	}
end

local function appendMissingEntries(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then return end
	for i = 1, #source do
		target[#target + 1] = source[i]
	end
end

local function buildSelfStatus(total, missingEntries)
	local entries = type(missingEntries) == "table" and missingEntries or {}
	local missing = #entries
	local normalizedTotal = tonumber(total) or 1
	if normalizedTotal < missing then normalizedTotal = missing end
	if normalizedTotal < 0 then normalizedTotal = 0 end
	return {
		total = normalizedTotal,
		missing = missing,
		missingEntries = entries,
	}
end

local function resolveProviderPresentation(provider, force)
	if not provider then return end
	if force ~= true then
		if provider._presentationReady == true then return end
		if provider._presentationAttempted == true then return end
		if provider.presentationRetryPending == true then return end
	end
	provider._presentationAttempted = true

	local resolvedId
	local resolvedName
	local resolvedIcon
	local preferredId = normalizeSpellId(provider.displaySpellId)
	if preferredId then resolvedId = preferredId end

	if preferredId then
		requestSpellDataLoad(preferredId)
		local preferredName = safeGetSpellName(preferredId)
		local preferredIcon = getSpellIconRaw(preferredId)
		if preferredName and preferredName ~= "" then
			resolvedName = preferredName
			resolvedId = preferredId
		end
		if preferredIcon and preferredIcon ~= "" then
			resolvedIcon = preferredIcon
			resolvedId = preferredId
		end
		if resolvedName and resolvedIcon then
			provider.displaySpellId = preferredId
			provider.cachedName = resolvedName
			provider.cachedIcon = resolvedIcon
			provider._presentationReady = true
			return
		end
	end

	for i = 1, #provider.spellIds do
		local sid = normalizeSpellId(provider.spellIds[i])
		if sid then
			if preferredId and sid == preferredId then
				if resolvedName and resolvedIcon then break end
				-- Continue with additional IDs only to fill missing name/icon fields.
			end
			requestSpellDataLoad(sid)
			if not resolvedId then resolvedId = sid end
			local name = safeGetSpellName(sid)
			local icon = getSpellIconRaw(sid)
			if name and not resolvedName then resolvedName = name end
			if icon and not resolvedIcon then resolvedIcon = icon end
			if name and icon then
				if not preferredId then resolvedId = sid end
				resolvedName = name
				resolvedIcon = icon
				break
			end
		end
	end

	provider.displaySpellId = resolvedId or preferredId or normalizeSpellId(provider.spellIds[1]) or provider.displaySpellId or provider.spellIds[1]
	provider.cachedName = resolvedName or provider.fallbackName or "Buff"
	provider.cachedIcon = resolvedIcon or ICON_MISSING
	provider._presentationReady = (resolvedName ~= nil and resolvedIcon ~= nil)
end

local function refreshProviderSpellNameSet(provider)
	if type(provider) ~= "table" then return end
	if type(provider.spellIds) ~= "table" then return end
	provider.spellNameSet = provider.spellNameSet or {}

	local resolvedAny = false
	for i = 1, #provider.spellIds do
		local sid = normalizeSpellId(provider.spellIds[i])
		if sid then
			requestSpellDataLoad(sid)
			local name = safeGetSpellName(sid)
			if type(name) == "string" and name ~= "" then
				provider.spellNameSet[name] = true
				resolvedAny = true
			end
		end
	end

	provider.spellNameRefreshAttempts = (tonumber(provider.spellNameRefreshAttempts) or 0) + 1
	if resolvedAny then
		provider.spellNameSetReady = true
		provider.spellNameRefreshAttempts = 0
	elseif provider.spellNameRefreshAttempts >= 8 then
		provider.spellNameSetReady = true
	end
end

function Reminder:GetClassToken() return (addon.variables and addon.variables.unitClass) or select(2, UnitClass("player")) end

function Reminder:GetCurrentSpecId()
	local sid = addon.variables and addon.variables.unitSpecId
	sid = tonumber(sid)
	if sid and sid > 0 then return sid end

	local specIndex = GetSpecialization and GetSpecialization() or nil
	if not specIndex or not GetSpecializationInfo then return nil end
	local specId = GetSpecializationInfo(specIndex)
	specId = tonumber(specId)
	if not specId or specId <= 0 then return nil end
	return specId
end

function Reminder:IsFlaskTrackingEnabled() return getValue(DB_TRACK_FLASKS, defaults.trackFlasks) == true end

function Reminder:IsFlaskInstanceOnlyEnabled() return getValue(DB_TRACK_FLASKS_INSTANCE_ONLY, defaults.trackFlasksInstanceOnly) == true end

function Reminder:IsDungeonOrRaidInstance()
	if not IsInInstance then return false end
	local inInstance, instanceType = IsInInstance()
	if inInstance ~= true then return false end
	return instanceType == "party" or instanceType == "raid"
end

function Reminder:CanCheckFlaskReminder()
	if not self:IsFlaskTrackingEnabled() then return false end
	if not self:IsFlaskInstanceOnlyEnabled() then return true end
	return self:IsDungeonOrRaidInstance()
end

function Reminder:CanEvaluateFlaskReminderNow()
	if not self:CanCheckFlaskReminder() then return false end
	-- Flask auras are not combat-whitelisted, so suppress flask reminder checks while in combat.
	if InCombatLockdown and InCombatLockdown() then return false end
	return true
end

function Reminder:InvalidateFlaskCache()
	self.flaskCandidateCache = nil
	self.flaskCandidateCacheSpecId = nil
	self.flaskCandidateCacheTime = 0
	self.flaskCandidateCacheReady = false
	self.flaskCacheDirty = true
end

local function nowSeconds()
	if GetTimePreciseSec then return tonumber(GetTimePreciseSec()) or 0 end
	if GetTime then return tonumber(GetTime()) or 0 end
	return 0
end

function Reminder:GetSharedFlaskCandidates(specId)
	if type(specId) ~= "number" then return nil, nil, false end
	if not addon.Flasks then return nil, nil, false end
	if addon.Flasks.lastSpecID ~= specId then return nil, nil, false end

	local selectedType = addon.Flasks.lastSelectedType
	if type(selectedType) ~= "string" then selectedType = nil end
	if selectedType == "none" then return nil, selectedType, true end

	local shared = addon.Flasks.filteredFlasks
	if type(shared) ~= "table" then return nil, selectedType, false end
	if #shared <= 0 then return nil, selectedType, true end
	return shared, selectedType, true
end

function Reminder:GetFlaskCandidatesForCurrentSpec()
	if not self:CanCheckFlaskReminder() then return nil, nil end
	if not (addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.getAvailableCandidatesForSpec) then return nil, nil end

	local specId = self:GetCurrentSpecId()
	if self.flaskCacheDirty ~= true and self.flaskCandidateCacheReady == true and self.flaskCandidateCacheSpecId == specId then return self.flaskCandidateCache, self.flaskSelectedType end

	local now = nowSeconds()
	local canUseShared = addon.db and addon.db.flaskMacroEnabled == true
	local sharedCandidates, sharedType, sharedReady = self:GetSharedFlaskCandidates(specId)
	if canUseShared and sharedReady then
		self.flaskCandidateCache = sharedCandidates
		self.flaskCandidateCacheSpecId = specId
		self.flaskSelectedType = sharedType
		self.flaskCandidateCacheTime = now
		self.flaskCandidateCacheReady = true
		self.flaskCacheDirty = false
		return sharedCandidates, sharedType
	end

	local candidates, selectedType = addon.Flasks.functions.getAvailableCandidatesForSpec(specId)
	if type(selectedType) ~= "string" then selectedType = nil end
	if selectedType == "none" then
		candidates = nil
	elseif type(candidates) ~= "table" or #candidates <= 0 then
		candidates = nil
	end

	self.flaskCandidateCache = candidates
	self.flaskCandidateCacheSpecId = specId
	self.flaskSelectedType = selectedType
	self.flaskCandidateCacheTime = now
	self.flaskCandidateCacheReady = true
	self.flaskCacheDirty = false

	return candidates, selectedType
end

function Reminder:GetFlaskMissingEntry()
	local candidates = self:GetFlaskCandidatesForCurrentSpec()
	if type(candidates) ~= "table" or #candidates <= 0 then return nil end

	local hasFlaskAura = self:UnitHasAnyAuraSpellId("player", SHARED_FLASK_AURA_IDS)
	local dynamicSpellIds = self.runtimeFlaskSpellIds or {}
	local dynamicAuraNames = self.runtimeFlaskAuraNames or {}
	self.runtimeFlaskSpellIds = dynamicSpellIds
	self.runtimeFlaskAuraNames = dynamicAuraNames
	wipeTable(dynamicSpellIds)
	wipeTable(dynamicAuraNames)

	local displaySpellId
	local displayLabel
	for i = 1, #candidates do
		local itemId = tonumber(candidates[i] and candidates[i].id)
		if itemId and itemId > 0 then
			local spellName, spellId
			if C_Item and C_Item.GetItemSpell then
				spellName, spellId = C_Item.GetItemSpell(itemId)
			elseif GetItemSpell then
				spellName, spellId = GetItemSpell(itemId)
			end

			spellId = normalizeSpellId(spellId)
			if not displaySpellId and spellId then displaySpellId = spellId end
			if spellId then dynamicSpellIds[#dynamicSpellIds + 1] = spellId end

			if type(spellName) == "string" and spellName ~= "" then
				dynamicAuraNames[#dynamicAuraNames + 1] = spellName
				if not displayLabel then displayLabel = spellName end
			end

			local itemName
			if C_Item and C_Item.GetItemNameByID then itemName = C_Item.GetItemNameByID(itemId) end
			if (not itemName or itemName == "") and GetItemInfo then itemName = GetItemInfo(itemId) end
			if type(itemName) == "string" and itemName ~= "" then
				dynamicAuraNames[#dynamicAuraNames + 1] = itemName
				if not displayLabel then displayLabel = itemName end
			end
		end
	end

	if not hasFlaskAura and #dynamicSpellIds > 0 and self:UnitHasAnyAuraSpellId("player", dynamicSpellIds) then hasFlaskAura = true end
	if not hasFlaskAura and #dynamicAuraNames > 0 and self:UnitHasAnyAuraName("player", dynamicAuraNames) then hasFlaskAura = true end
	if hasFlaskAura then return nil end

	if not displaySpellId then displaySpellId = normalizeSpellId(SHARED_FLASK_AURA_IDS[1]) end
	if type(displayLabel) ~= "string" or displayLabel == "" then displayLabel = "Flask" end
	return makeSelfMissingEntry(displaySpellId, displayLabel)
end

function Reminder:GetSupplementalMissingEntries()
	if not self:CanEvaluateFlaskReminderNow() then return nil end
	if not canEvaluateUnit("player") then return nil end
	local flaskEntry = self:GetFlaskMissingEntry()
	if not flaskEntry then return nil end
	return { flaskEntry }
end

function Reminder:UnitHasAnyAuraSpellId(unit, spellIds)
	if type(spellIds) ~= "table" then return false end
	for i = 1, #spellIds do
		local sid = normalizeSpellId(spellIds[i])
		if sid and unitHasAuraBySpellId(unit, sid) then return true end
	end
	return false
end

function Reminder:UnitHasAnyAuraName(unit, auraNames)
	if type(auraNames) ~= "table" then return false end
	if type(unit) ~= "string" or unit == "" then return false end
	if not (C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot) then return false end

	local targetNames = {}
	for i = 1, #auraNames do
		local auraName = auraNames[i]
		if type(auraName) == "string" and auraName ~= "" then targetNames[auraName] = true end
	end
	if not next(targetNames) then return false end

	local continuationToken
	for _ = 1, AURA_SLOT_SCAN_GUARD do
		local slots, slotCount, nextToken = getHelpfulAuraSlotBuffer(unit, continuationToken)
		for i = 2, slotCount do
			local slot = slots[i]
			if not (issecretvalue and issecretvalue(slot)) then
				local aura = C_UnitAuras.GetAuraDataBySlot(unit, slot)
				if aura and not (issecretvalue and issecretvalue(aura)) then
					local isHelpful = aura.isHelpful
					if issecretvalue and issecretvalue(isHelpful) then isHelpful = nil end
					if isHelpful ~= false then
						local activeName = aura.name
						if not (issecretvalue and issecretvalue(activeName)) and type(activeName) == "string" and targetNames[activeName] then return true end
					end
				end
			end
		end

		if nextToken == nil then break end
		continuationToken = nextToken
	end

	return false
end

function Reminder:GetGroupBuffMissingCountBySpellIds(spellIds)
	if type(spellIds) ~= "table" then return 0, 0 end
	local units = self:GetRosterUnits()

	local total = 0
	local missing = 0
	for i = 1, #units do
		local unit = units[i]
		if isAIFollowerUnit(unit) then
			-- Skip AI followers for group-buff requirements.
		elseif UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
			total = total + 1
			if not self:UnitHasAnyAuraSpellId(unit, spellIds) then missing = missing + 1 end
		end
	end

	return missing, total
end

local function paladinRitesHasUnitBuff(provider, unit, reminder)
	if unit ~= "player" then return false end
	if type(reminder) ~= "table" then return false end
	if reminder:UnitHasAnyAuraSpellId(unit, provider and provider.spellIds) then return true end
	if not provider then return false end
	if type(provider.enchantIds) == "table" and #provider.enchantIds > 0 then return playerHasAnyEnchantId(provider.enchantIds) end
	return playerHasEnchantId(provider.enchantId)
end

local function paladinRitesGetSelfStatus(provider, reminder)
	if type(provider) ~= "table" or type(reminder) ~= "table" then return buildSelfStatus(1, {}) end

	local activeSpellId = normalizeSpellId(provider.spellIds and provider.spellIds[1]) or normalizeSpellId(provider.displaySpellId)
	local hasRite = false
	if reminder:UnitHasAnyAuraSpellId("player", provider.spellIds) then
		hasRite = true
	elseif type(provider.enchantIds) == "table" and #provider.enchantIds > 0 and playerHasAnyEnchantId(provider.enchantIds) then
		hasRite = true
	elseif provider.enchantId and playerHasEnchantId(provider.enchantId) then
		hasRite = true
	end

	local missingEntries = {}
	if not hasRite then
		missingEntries[1] = makeSelfMissingEntry(activeSpellId, provider.fallbackName or "Rite")
		setProviderDisplaySpellId(provider, activeSpellId)
	else
		setProviderDisplaySpellId(provider, activeSpellId)
	end

	return buildSelfStatus(1, missingEntries)
end

local function getRoguePoisonPresence(provider, reminder)
	local hasLethal = reminder:UnitHasAnyAuraSpellId("player", provider.lethalSpellIds)
	local hasUtility = reminder:UnitHasAnyAuraSpellId("player", provider.utilitySpellIds)

	-- Fallback for clients where poisons are only exposed as temporary enchants.
	if not hasLethal and not hasUtility and GetWeaponEnchantInfo then
		local hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
		if hasMainHandEnchant and hasOffHandEnchant then
			hasLethal = true
			hasUtility = true
		end
	end

	return hasLethal, hasUtility
end

local function roguePoisonsGetSelfStatus(provider, reminder)
	if type(provider) ~= "table" or type(reminder) ~= "table" then return buildSelfStatus(2, {}) end

	local lethalDisplayId = normalizeSpellId(provider.lethalDisplaySpellId) or normalizeSpellId(provider.lethalSpellIds and provider.lethalSpellIds[1])
	local utilityDisplayId = normalizeSpellId(provider.utilityDisplaySpellId) or normalizeSpellId(provider.utilitySpellIds and provider.utilitySpellIds[1])
	local hasLethal, hasUtility = getRoguePoisonPresence(provider, reminder)

	local missingEntries = {}
	if not hasLethal then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(lethalDisplayId, "Lethal Poison") end
	if not hasUtility then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(utilityDisplayId, "Non-lethal Poison") end

	if #missingEntries > 0 then
		setProviderDisplaySpellId(provider, missingEntries[1].spellId)
	else
		setProviderDisplaySpellId(provider, lethalDisplayId or utilityDisplayId)
	end

	return buildSelfStatus(2, missingEntries)
end

local function roguePoisonsHasUnitBuff(provider, unit, reminder)
	if unit ~= "player" then return false end
	local status = roguePoisonsGetSelfStatus(provider, reminder)
	return status and status.missing <= 0
end

local function shamanEnhancementGetSelfStatus(provider, reminder)
	if type(provider) ~= "table" or type(reminder) ~= "table" then return buildSelfStatus(2, {}) end

	local totalRequirements = 2
	local missingEntries = {}

	local skyfuryDisplayId = normalizeSpellId(provider.skyfuryDisplaySpellId) or normalizeSpellId(provider.skyfurySpellIds and provider.skyfurySpellIds[1])
	local skyfuryMissingCount, skyfuryTotal = reminder:GetGroupBuffMissingCountBySpellIds(provider.skyfurySpellIds)
	if skyfuryTotal > 0 then
		totalRequirements = totalRequirements + 1
		if skyfuryMissingCount > 0 then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(skyfuryDisplayId, provider.skyfuryLabel or "Skyfury", skyfuryMissingCount, skyfuryTotal) end
	end

	local windfuryDisplayId = normalizeSpellId(provider.windfuryDisplaySpellId) or normalizeSpellId(provider.windfurySpellIds and provider.windfurySpellIds[1])
	local flametongueDisplayId = normalizeSpellId(provider.flametongueDisplaySpellId) or normalizeSpellId(provider.flametongueSpellIds and provider.flametongueSpellIds[1])
	local hasWindfury = reminder:UnitHasAnyAuraSpellId("player", provider.windfurySpellIds)
	local hasFlametongue = reminder:UnitHasAnyAuraSpellId("player", provider.flametongueSpellIds)

	if GetWeaponEnchantInfo then
		local hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
		if not hasWindfury and hasMainHandEnchant then hasWindfury = true end
		if not hasFlametongue and hasOffHandEnchant then hasFlametongue = true end
	end

	if not hasWindfury then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(windfuryDisplayId, "Windfury Weapon") end
	if not hasFlametongue then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(flametongueDisplayId, "Flametongue Weapon") end

	if #missingEntries > 0 then
		setProviderDisplaySpellId(provider, missingEntries[1].spellId)
	else
		setProviderDisplaySpellId(provider, skyfuryDisplayId or windfuryDisplayId or flametongueDisplayId)
	end

	return buildSelfStatus(totalRequirements, missingEntries)
end

local function shamanEnhancementImbuesHasUnitBuff(provider, unit, reminder)
	if unit ~= "player" then return false end
	local status = shamanEnhancementGetSelfStatus(provider, reminder)
	return status and status.missing <= 0
end

local function shamanRestorationGetSelfStatus(provider, reminder)
	if type(provider) ~= "table" or type(reminder) ~= "table" then return buildSelfStatus(1, {}) end

	local totalRequirements = 1
	local missingEntries = {}

	local skyfuryDisplayId = normalizeSpellId(provider.skyfuryDisplaySpellId) or normalizeSpellId(provider.skyfurySpellIds and provider.skyfurySpellIds[1])
	local skyfuryMissingCount, skyfuryTotal = reminder:GetGroupBuffMissingCountBySpellIds(provider.skyfurySpellIds)
	if skyfuryTotal > 0 then
		totalRequirements = totalRequirements + 1
		if skyfuryMissingCount > 0 then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(skyfuryDisplayId, provider.skyfuryLabel or "Skyfury", skyfuryMissingCount, skyfuryTotal) end
	end

	local earthlivingDisplaySpellId = normalizeSpellId(provider.earthlivingDisplaySpellId)
		or normalizeSpellId(provider.primaryDisplaySpellId)
		or normalizeSpellId(provider.earthlivingSpellIds and provider.earthlivingSpellIds[1])
		or normalizeSpellId(provider.displaySpellId)
	local hasEarthliving = reminder:UnitHasAnyAuraSpellId("player", provider.earthlivingSpellIds or provider.spellIds)
	if not hasEarthliving then hasEarthliving = reminder:UnitHasAnyAuraName("player", provider.earthlivingAuraNames) end
	if not hasEarthliving and GetWeaponEnchantInfo then
		local hasMainHandEnchant, _, _, mainHandEnchantId = GetWeaponEnchantInfo()
		local expectedEnchantId = tonumber(provider.enchantId)
		if expectedEnchantId and tonumber(mainHandEnchantId) == expectedEnchantId then
			hasEarthliving = true
		elseif expectedEnchantId and mainHandEnchantId == nil and hasMainHandEnchant then
			hasEarthliving = true
		end
	end

	if not hasEarthliving then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(earthlivingDisplaySpellId, provider.earthlivingLabel or provider.fallbackName or "Earthliving Weapon") end

	local shouldTrackTidecaller = hasKnownSpellInList(provider.tidecallerKnownSpellIds or provider.tidecallerSpellIds)
	if shouldTrackTidecaller and provider.requireShieldForTidecaller == true and not isPlayerOffhandShield() then shouldTrackTidecaller = false end
	if shouldTrackTidecaller then
		totalRequirements = totalRequirements + 1

		local tidecallerDisplaySpellId = normalizeSpellId(provider.tidecallerDisplaySpellId) or normalizeSpellId(provider.tidecallerSpellIds and provider.tidecallerSpellIds[1])
		local hasTidecaller = reminder:UnitHasAnyAuraSpellId("player", provider.tidecallerSpellIds)
		if not hasTidecaller then hasTidecaller = reminder:UnitHasAnyAuraName("player", provider.tidecallerAuraNames) end
		if not hasTidecaller and GetWeaponEnchantInfo then
			local _, _, _, _, hasOffHandEnchant, _, _, offHandEnchantId = GetWeaponEnchantInfo()
			local expectedTidecallerEnchantId = tonumber(provider.tidecallerEnchantId)
			if expectedTidecallerEnchantId and tonumber(offHandEnchantId) == expectedTidecallerEnchantId then
				hasTidecaller = true
			elseif provider.acceptAnyOffhandEnchantWhenKnown == true and hasOffHandEnchant then
				hasTidecaller = true
			end
		end

		if not hasTidecaller then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(tidecallerDisplaySpellId, provider.tidecallerLabel or "Tidecaller's Guard") end
	end

	setProviderDisplaySpellId(provider, missingEntries[1] and missingEntries[1].spellId or skyfuryDisplayId or earthlivingDisplaySpellId)
	return buildSelfStatus(totalRequirements, missingEntries)
end

local function shamanRestorationEarthlivingHasUnitBuff(provider, unit, reminder)
	if unit ~= "player" then return false end
	local status = shamanRestorationGetSelfStatus(provider, reminder)
	return status and status.missing <= 0
end

local function evokerSupportGetSelfStatus(provider, reminder)
	if type(provider) ~= "table" or type(reminder) ~= "table" then return buildSelfStatus(0, {}) end

	local totalRequirements = 0
	local missingEntries = {}

	local sourceDisplaySpellId = normalizeSpellId(provider.sourceDisplaySpellId) or normalizeSpellId(provider.sourceSpellIds and provider.sourceSpellIds[1])
	local shouldTrackSource = hasKnownSpellInList(provider.sourceKnownSpellIds or provider.sourceSpellIds)
	if shouldTrackSource then
		reminder.runtimeHealerUnits = reminder.runtimeHealerUnits or {}
		local healerUnits = reminder:CollectOtherHealerUnits(reminder.runtimeHealerUnits)
		if #healerUnits > 0 then
			totalRequirements = totalRequirements + 1
			local hasSourceOnTarget = false
			for i = 1, #healerUnits do
				local unit = healerUnits[i]
				if reminder:UnitHasAnyAuraSpellId(unit, provider.sourceSpellIds) then
					hasSourceOnTarget = true
					break
				end
				if reminder:UnitHasAnyAuraName(unit, provider.sourceAuraNames) then
					hasSourceOnTarget = true
					break
				end
			end

			if not hasSourceOnTarget then missingEntries[#missingEntries + 1] = makeSelfMissingEntry(sourceDisplaySpellId, provider.sourceLabel or "Source of Magic") end
		end
	end

	local bronzeDisplaySpellId = normalizeSpellId(provider.bronzeDisplaySpellId) or normalizeSpellId(provider.bronzeSpellIds and provider.bronzeSpellIds[1])
	local bronzeMissingCount, bronzeTotal = reminder:GetGroupBuffMissingCountBySpellIds(provider.bronzeSpellIds)
	if bronzeTotal > 0 then
		totalRequirements = totalRequirements + 1
		if bronzeMissingCount > 0 then
			missingEntries[#missingEntries + 1] = makeSelfMissingEntry(bronzeDisplaySpellId, provider.bronzeLabel or "Blessing of the Bronze", bronzeMissingCount, bronzeTotal)
		end
	end

	setProviderDisplaySpellId(provider, missingEntries[1] and missingEntries[1].spellId or sourceDisplaySpellId or bronzeDisplaySpellId)
	return buildSelfStatus(totalRequirements, missingEntries)
end

local function evokerSupportHasUnitBuff(provider, unit, reminder)
	if unit ~= "player" then return false end
	local status = evokerSupportGetSelfStatus(provider, reminder)
	return status and status.missing <= 0
end

function Reminder:GetEvokerSupportProvider()
	self.evokerSupportProvider = self.evokerSupportProvider
		or {
			scope = PROVIDER_SCOPE_SELF,
			spellIds = {
				369459,
				381732,
				381741,
				381746,
				381748,
				381749,
				381750,
				381751,
				381752,
				381753,
				381754,
				381756,
				381757,
				381758,
			},
			sourceSpellIds = EVOKER_SOURCE_OF_MAGIC_IDS,
			sourceKnownSpellIds = EVOKER_SOURCE_OF_MAGIC_IDS,
			sourceAuraNames = { "Source of Magic" },
			sourceLabel = "Source of Magic",
			sourceDisplaySpellId = 369459,
			bronzeSpellIds = EVOKER_BLESSING_OF_BRONZE_IDS,
			bronzeLabel = "Blessing of the Bronze",
			bronzeDisplaySpellId = 381748,
			fallbackName = "Source of Magic",
			tracksExternalUnitAuras = true,
			hasUnitBuffFunc = evokerSupportHasUnitBuff,
			getSelfStatusFunc = evokerSupportGetSelfStatus,
		}

	return self.evokerSupportProvider
end

function Reminder:GetPaladinRitesProvider()
	local adjurationKnown = safeIsPlayerSpell(PALADIN_RITES.adjuration.spellId)
	local sanctificationKnown = safeIsPlayerSpell(PALADIN_RITES.sanctification.spellId)
	if not adjurationKnown and not sanctificationKnown then return nil end

	local spellIds
	local enchantIds
	local fallbackName
	local nextKey
	local displaySpellId

	if adjurationKnown and not sanctificationKnown then
		spellIds = { PALADIN_RITES.adjuration.spellId }
		enchantIds = { PALADIN_RITES.adjuration.enchantId }
		fallbackName = PALADIN_RITES.adjuration.fallbackName
		nextKey = tostring(PALADIN_RITES.adjuration.spellId)
		displaySpellId = PALADIN_RITES.adjuration.spellId
	elseif sanctificationKnown and not adjurationKnown then
		spellIds = { PALADIN_RITES.sanctification.spellId }
		enchantIds = { PALADIN_RITES.sanctification.enchantId }
		fallbackName = PALADIN_RITES.sanctification.fallbackName
		nextKey = tostring(PALADIN_RITES.sanctification.spellId)
		displaySpellId = PALADIN_RITES.sanctification.spellId
	else
		spellIds = { PALADIN_RITES.adjuration.spellId, PALADIN_RITES.sanctification.spellId }
		enchantIds = { PALADIN_RITES.adjuration.enchantId, PALADIN_RITES.sanctification.enchantId }
		fallbackName = "Rite"
		nextKey = "both"
		displaySpellId = PALADIN_RITES.adjuration.spellId
		if self:UnitHasAnyAuraSpellId("player", { PALADIN_RITES.sanctification.spellId }) or playerHasEnchantId(PALADIN_RITES.sanctification.enchantId) then
			displaySpellId = PALADIN_RITES.sanctification.spellId
		elseif self:UnitHasAnyAuraSpellId("player", { PALADIN_RITES.adjuration.spellId }) or playerHasEnchantId(PALADIN_RITES.adjuration.enchantId) then
			displaySpellId = PALADIN_RITES.adjuration.spellId
		end
	end

	self.paladinRitesProvider = self.paladinRitesProvider
		or {
			scope = PROVIDER_SCOPE_SELF,
			spellIds = spellIds,
			fallbackName = fallbackName,
			enchantId = enchantIds[1],
			enchantIds = enchantIds,
			hasUnitBuffFunc = paladinRitesHasUnitBuff,
			getSelfStatusFunc = paladinRitesGetSelfStatus,
			activeKey = nil,
		}

	local provider = self.paladinRitesProvider
	provider.spellIds = spellIds
	provider.fallbackName = fallbackName
	provider.enchantIds = enchantIds
	provider.enchantId = (#enchantIds == 1) and enchantIds[1] or nil

	if provider.activeKey ~= nextKey then
		provider.activeKey = nextKey
		resetProviderRuntimeCache(provider)
	end

	setProviderDisplaySpellId(provider, displaySpellId)
	return provider
end

function Reminder:GetRoguePoisonsProvider()
	self.roguePoisonsProvider = self.roguePoisonsProvider
		or {
			scope = PROVIDER_SCOPE_SELF,
			spellIds = {
				315584,
				2823,
				8679,
				381664,
				3408,
				5761,
				381637,
			},
			lethalSpellIds = ROGUE_POISON_LETHAL_IDS,
			utilitySpellIds = ROGUE_POISON_UTILITY_IDS,
			lethalDisplaySpellId = 315584,
			utilityDisplaySpellId = 3408,
			fallbackName = "Poisons",
			hasUnitBuffFunc = roguePoisonsHasUnitBuff,
			getSelfStatusFunc = roguePoisonsGetSelfStatus,
		}
	return self.roguePoisonsProvider
end

function Reminder:GetShamanEnhancementProvider()
	self.shamanEnhancementProvider = self.shamanEnhancementProvider
		or {
			scope = PROVIDER_SCOPE_SELF,
			spellIds = {
				319773,
				33757,
				319778,
				318038,
			},
			windfurySpellIds = SHAMAN_ENHANCEMENT_WINDFURY_IDS,
			flametongueSpellIds = SHAMAN_ENHANCEMENT_FLAMETONGUE_IDS,
			windfuryDisplaySpellId = 319773,
			flametongueDisplaySpellId = 319778,
			skyfurySpellIds = PROVIDER_BY_CLASS.SHAMAN.spellIds,
			skyfuryDisplaySpellId = 462854,
			skyfuryLabel = PROVIDER_BY_CLASS.SHAMAN.fallbackName or "Skyfury",
			fallbackName = "Weapon Imbues",
			hasUnitBuffFunc = shamanEnhancementImbuesHasUnitBuff,
			getSelfStatusFunc = shamanEnhancementGetSelfStatus,
		}
	return self.shamanEnhancementProvider
end

function Reminder:GetShamanRestorationProvider()
	local earthlivingDisplaySpellId = 382021
	if safeIsPlayerSpell(382024) then
		earthlivingDisplaySpellId = 382024
	elseif safeIsPlayerSpell(382022) then
		earthlivingDisplaySpellId = 382022
	end

	local tidecallerDisplaySpellId = 457481
	if safeIsPlayerSpell(457496) then tidecallerDisplaySpellId = 457496 end

	self.shamanRestorationProvider = self.shamanRestorationProvider
		or {
			scope = PROVIDER_SCOPE_SELF,
			spellIds = {
				382021,
				382022,
				382024,
				457481,
				457496,
			},
			earthlivingSpellIds = SHAMAN_RESTORATION_EARTHLIVING_IDS,
			earthlivingAuraNames = SHAMAN_RESTORATION_EARTHLIVING_AURA_NAMES,
			earthlivingLabel = "Earthliving Weapon",
			enchantId = 6498,
			earthlivingDisplaySpellId = earthlivingDisplaySpellId,
			tidecallerSpellIds = SHAMAN_RESTORATION_TIDECALLER_IDS,
			tidecallerKnownSpellIds = SHAMAN_RESTORATION_TIDECALLER_IDS,
			tidecallerAuraNames = SHAMAN_RESTORATION_TIDECALLER_AURA_NAMES,
			tidecallerLabel = "Tidecaller's Guard",
			tidecallerDisplaySpellId = tidecallerDisplaySpellId,
			requireShieldForTidecaller = true,
			acceptAnyOffhandEnchantWhenKnown = true,
			skyfurySpellIds = PROVIDER_BY_CLASS.SHAMAN.spellIds,
			skyfuryDisplaySpellId = 462854,
			skyfuryLabel = PROVIDER_BY_CLASS.SHAMAN.fallbackName or "Skyfury",
			fallbackName = "Earthliving Weapon",
			hasUnitBuffFunc = shamanRestorationEarthlivingHasUnitBuff,
			getSelfStatusFunc = shamanRestorationGetSelfStatus,
		}

	if self.shamanRestorationProvider.earthlivingDisplaySpellId ~= earthlivingDisplaySpellId or self.shamanRestorationProvider.tidecallerDisplaySpellId ~= tidecallerDisplaySpellId then
		self.shamanRestorationProvider.earthlivingDisplaySpellId = earthlivingDisplaySpellId
		self.shamanRestorationProvider.tidecallerDisplaySpellId = tidecallerDisplaySpellId
		resetProviderRuntimeCache(self.shamanRestorationProvider)
	end

	return self.shamanRestorationProvider
end

function Reminder:GetShamanProvider()
	local specId = self:GetCurrentSpecId()
	if specId == SHAMAN_SPEC_ENHANCEMENT then return self:GetShamanEnhancementProvider() or PROVIDER_BY_CLASS.SHAMAN end
	if specId == SHAMAN_SPEC_RESTORATION then return self:GetShamanRestorationProvider() or PROVIDER_BY_CLASS.SHAMAN end
	return PROVIDER_BY_CLASS.SHAMAN
end

function Reminder:GetFlaskOnlyProvider()
	self.flaskOnlyProvider = self.flaskOnlyProvider
		or {
			scope = PROVIDER_SCOPE_SELF,
			spellIds = SHARED_FLASK_AURA_IDS,
			fallbackName = "Flask",
			displaySpellId = normalizeSpellId(SHARED_FLASK_AURA_IDS[1]),
		}
	return self.flaskOnlyProvider
end

local function finalizeResolvedProvider(provider)
	if not provider then return nil end
	if provider.scope == nil then provider.scope = PROVIDER_SCOPE_GROUP end
	if type(provider.spellIds) ~= "table" or #provider.spellIds <= 0 then return nil end
	if not tonumber(provider.stateVersion) or tonumber(provider.stateVersion) <= 0 then provider.stateVersion = 1 end

	if not provider.spellSet then
		provider.spellSet = {}
		for i = 1, #provider.spellIds do
			local sid = normalizeSpellId(provider.spellIds[i])
			if sid then provider.spellSet[sid] = true end
		end
	end
	if not provider.displaySpellId then provider.displaySpellId = normalizeSpellId(provider.spellIds[1]) or provider.spellIds[1] end

	return provider
end

function Reminder:RefreshProviderCache(force)
	if force ~= true and self.runtimeProviderValid == true then return self.activeProvider, self.hasProviderCached == true end

	local classToken = self:GetClassToken()
	local provider
	if classToken == "PALADIN" then
		provider = self:GetPaladinRitesProvider()
	elseif classToken == "ROGUE" then
		provider = self:GetRoguePoisonsProvider()
	elseif classToken == "EVOKER" then
		provider = self:GetEvokerSupportProvider()
	elseif classToken == "SHAMAN" then
		provider = self:GetShamanProvider()
	else
		provider = classToken and PROVIDER_BY_CLASS[classToken] or nil
	end

	provider = finalizeResolvedProvider(provider)
	self.activeProvider = provider
	self.hasProviderCached = provider ~= nil
	self.runtimeProviderValid = true
	return provider, self.hasProviderCached
end

function Reminder:GetProvider()
	local provider = self:RefreshProviderCache(false)
	return provider
end

function Reminder:GetProviderName(provider)
	if not provider then return L["Class Buff Reminder"] or "Class Buff Reminder" end
	if provider.cachedName and provider.cachedName ~= "" and provider.cachedName ~= provider.fallbackName then return provider.cachedName end
	if provider._presentationAttempted ~= true then resolveProviderPresentation(provider) end
	if provider.cachedName and provider.cachedName ~= "" then return provider.cachedName end
	local name = safeGetSpellName(provider.displaySpellId) or provider.fallbackName or (L["Class Buff Reminder"] or "Class Buff Reminder")
	provider.cachedName = name
	return name
end

function Reminder:GetProviderIcon(provider)
	if not provider then return ICON_MISSING end
	if provider.cachedIcon and provider.cachedIcon ~= "" and provider.cachedIcon ~= ICON_MISSING then return provider.cachedIcon end
	if provider._presentationAttempted ~= true then resolveProviderPresentation(provider) end
	if provider.cachedIcon and provider.cachedIcon ~= "" and provider.cachedIcon ~= ICON_MISSING then return provider.cachedIcon end
	self:RequestProviderPresentationRefresh(provider)
	return provider.cachedIcon or ICON_MISSING
end

function Reminder:RequestProviderPresentationRefresh(provider)
	if type(provider) ~= "table" then return end
	if provider.cachedIcon and provider.cachedIcon ~= "" and provider.cachedIcon ~= ICON_MISSING then
		provider.presentationRetryCount = 0
		return
	end
	if not (C_Timer and C_Timer.After) then return end
	if provider.presentationRetryPending then return end
	local retries = tonumber(provider.presentationRetryCount) or 0
	if retries >= 8 then return end

	provider.presentationRetryPending = true
	C_Timer.After(0.25, function()
		provider.presentationRetryPending = false
		provider.presentationRetryCount = (tonumber(provider.presentationRetryCount) or 0) + 1
		resolveProviderPresentation(provider, true)
		if provider.cachedIcon and provider.cachedIcon ~= "" and provider.cachedIcon ~= ICON_MISSING then provider.presentationRetryCount = 0 end
		Reminder:RequestUpdate(true)
	end)
end

function Reminder:InvalidateProviderAvailabilityCache()
	self.activeProvider = nil
	self.hasProviderCached = nil
	self.runtimeProviderValid = nil
	self:InvalidateGroupMissingState()
end

function Reminder:GetGrowthDirection() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) end
function Reminder:GetGrowthFromCenter() return getValue(DB_GROWTH_FROM_CENTER, defaults.growthFromCenter) == true end

function Reminder:GetIconCountTextStyle()
	local size = clamp(getValue(DB_XY_TEXT_SIZE, defaults.xyTextSize), 8, 64, defaults.xyTextSize)
	local outline = normalizeTextOutline(getValue(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline))
	local r, g, b, a = normalizeColor(getValue(DB_XY_TEXT_COLOR, defaults.xyTextColor), defaults.xyTextColor)
	local offsetX = clamp(getValue(DB_XY_TEXT_OFFSET_X, defaults.xyTextOffsetX), -60, 60, defaults.xyTextOffsetX)
	local offsetY = clamp(getValue(DB_XY_TEXT_OFFSET_Y, defaults.xyTextOffsetY), -60, 60, defaults.xyTextOffsetY)
	return size, outline, r, g, b, a, offsetX, offsetY
end

local function soundDebugTimestamp()
	if date then
		local stamp = date("%H:%M:%S")
		if type(stamp) == "string" and stamp ~= "" then return stamp end
	end
	local timeValue = 0
	if GetTimePreciseSec then
		timeValue = GetTimePreciseSec() or 0
	elseif GetTime then
		timeValue = GetTime() or 0
	end
	return string.format("%.3f", tonumber(timeValue) or 0)
end

function Reminder:WriteSoundDebug(eventName, payload)
	if not addon.db then return end
	local trace = addon.db[DB_SOUND_DEBUG_TRACE]
	if type(trace) ~= "table" then
		trace = {}
		addon.db[DB_SOUND_DEBUG_TRACE] = trace
	end

	local entry = {
		t = soundDebugTimestamp(),
		e = tostring(eventName or "unknown"),
	}
	if type(payload) == "table" then
		for key, value in pairs(payload) do
			local tv = type(value)
			if tv == "string" or tv == "number" or tv == "boolean" then
				entry[key] = value
			elseif value ~= nil then
				entry[key] = "<" .. tv .. ">"
			end
		end
	end

	trace[#trace + 1] = entry
	if #trace > SOUND_DEBUG_TRACE_MAX then
		local overflow = #trace - SOUND_DEBUG_TRACE_MAX
		for i = 1, overflow do
			table.remove(trace, 1)
		end
	end
end

function Reminder:BuildMissingSoundOptions()
	local version = (addon.functions and addon.functions.GetLSMMediaVersion and addon.functions.GetLSMMediaVersion("sound")) or 0
	if self.missingSoundCacheVersion == version and self.missingSoundKeys and self.missingSoundMap and self.missingSoundPathToKey then
		return self.missingSoundKeys, self.missingSoundMap, self.missingSoundPathToKey
	end

	local keys = {}
	local map = {}
	local pathToKey = {}

	local names = (addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("sound")) or nil
	local hash = (addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash("sound")) or nil
	if type(names) == "table" and type(hash) == "table" then
		for i = 1, #names do
			local name = names[i]
			local path = hash[name]
			if type(name) == "string" and name ~= "" and type(path) == "string" and path ~= "" then
				keys[#keys + 1] = name
				map[name] = path
			end
		end
	end
	for i = 1, #keys do
		local name = keys[i]
		local path = map[name]
		if type(path) == "string" and path ~= "" and pathToKey[path] == nil then pathToKey[path] = name end
	end
	self.missingSoundCacheVersion = version
	self.missingSoundKeys = keys
	self.missingSoundMap = map
	self.missingSoundPathToKey = pathToKey
	return keys, map, pathToKey
end

function Reminder:GetMissingSoundOptions() return self:BuildMissingSoundOptions() end

function Reminder:ResolveMissingSound()
	local rawKey = getValue(DB_MISSING_SOUND, defaults.missingSound)
	if type(rawKey) ~= "string" then rawKey = "" end

	local keys, map, pathToKey = self:GetMissingSoundOptions()
	local resolvedKey = rawKey
	if resolvedKey ~= "" and type(pathToKey) == "table" and pathToKey[resolvedKey] and map[pathToKey[resolvedKey]] then resolvedKey = pathToKey[resolvedKey] end

	local soundFile
	if resolvedKey ~= "" and type(map) == "table" then soundFile = map[resolvedKey] end

	return rawKey, resolvedKey, soundFile, #keys
end

function Reminder:NormalizeMissingSoundSelection(source)
	if not addon.db then return end

	local _, map, pathToKey = self:GetMissingSoundOptions()
	local current = addon.db[DB_MISSING_SOUND]
	if type(current) ~= "string" then current = "" end

	local normalized = current
	if normalized ~= "" and type(pathToKey) == "table" and pathToKey[normalized] and type(map) == "table" and map[pathToKey[normalized]] then normalized = pathToKey[normalized] end

	if normalized ~= current then addon.db[DB_MISSING_SOUND] = normalized end

	local _, resolvedKey, soundFile, optionCount = self:ResolveMissingSound()
	self:WriteSoundDebug("normalize", {
		source = source or "",
		current = current,
		normalized = normalized,
		resolved = resolvedKey or "",
		hasFile = soundFile and true or false,
		options = optionCount or 0,
	})
end

function Reminder:ScheduleInitialSoundSync(reason)
	if self.initialSoundSyncDone == true or self.initialSoundSyncPending == true then return end
	if not (C_Timer and C_Timer.After) then return end

	self.initialSoundSyncPending = true
	self:WriteSoundDebug("schedule-sync", {
		reason = reason or "unknown",
	})

	C_Timer.After(1, function()
		Reminder.initialSoundSyncPending = false
		if not Reminder:ShouldRegisterRuntimeEvents() then
			Reminder:WriteSoundDebug("run-sync-skipped", {
				reason = reason or "unknown",
				runtime = false,
			})
			return
		end

		Reminder.initialSoundSyncDone = true
		Reminder:NormalizeMissingSoundSelection("initial-sync")
		local rawKey, resolvedKey, soundFile, optionCount = Reminder:ResolveMissingSound()
		Reminder:WriteSoundDebug("run-sync", {
			reason = reason or "unknown",
			raw = rawKey or "",
			resolved = resolvedKey or "",
			hasFile = soundFile and true or false,
			options = optionCount or 0,
		})
	end)
end

function Reminder:GetMissingSoundValue()
	local _, resolvedKey = self:ResolveMissingSound()
	if type(resolvedKey) ~= "string" then return "" end
	return resolvedKey
end

function Reminder:GetMissingSoundFile()
	local _, _, soundFile = self:ResolveMissingSound()
	if type(soundFile) ~= "string" or soundFile == "" then return nil end
	return soundFile
end

function Reminder:PlayMissingSound(force)
	if not force and getValue(DB_SOUND_ON_MISSING, defaults.soundOnMissing) ~= true then
		self:WriteSoundDebug("play-skip-disabled", { force = force == true })
		return
	end

	local rawKey, resolvedKey, soundFile, optionCount = self:ResolveMissingSound()
	if soundFile and PlaySoundFile then
		PlaySoundFile(soundFile, "Master")
		self:WriteSoundDebug("play", {
			force = force == true,
			raw = rawKey or "",
			resolved = resolvedKey or "",
			options = optionCount or 0,
		})
		return
	end

	self:WriteSoundDebug("play-missing-file", {
		force = force == true,
		raw = rawKey or "",
		resolved = resolvedKey or "",
		options = optionCount or 0,
	})
end

function Reminder:UpdateMissingStateAndSound(missing)
	local isMissing = tonumber(missing) and tonumber(missing) > 0 or false
	local wasMissing = self.missingActive == true
	if isMissing and not wasMissing then
		if self.suppressNextMissingSound == true then
			self.suppressNextMissingSound = false
			self:WriteSoundDebug("play-suppressed", {
				reason = "initial-login",
				missing = tonumber(missing) or 0,
			})
		else
			self:PlayMissingSound()
		end
	end
	self.missingActive = isMissing
end

function Reminder:GetUnitAuraState(unit)
	if type(unit) ~= "string" or unit == "" then return nil end
	self.unitAuraStates = self.unitAuraStates or {}
	local state = self.unitAuraStates[unit]
	if not state then
		state = {
			trackedByInstance = {},
			trackedCount = 0,
			hasBuff = false,
			initialized = false,
			providerRef = nil,
			providerVersion = nil,
		}
		self.unitAuraStates[unit] = state
	end
	if type(state.trackedByInstance) ~= "table" then state.trackedByInstance = {} end
	if type(state.trackedCount) ~= "number" then state.trackedCount = 0 end
	return state
end

function Reminder:ResetUnitAuraState(state)
	if type(state) ~= "table" then return end
	if type(state.trackedByInstance) == "table" then wipeTable(state.trackedByInstance) end
	state.trackedCount = 0
	state.hasBuff = false
	state.initialized = false
end

function Reminder:PrepareUnitAuraState(unit, provider)
	local state = self:GetUnitAuraState(unit)
	if not state then return nil end
	if type(provider) ~= "table" then return state end

	local providerVersion = getProviderStateVersion(provider)
	if state.providerRef ~= provider or state.providerVersion ~= providerVersion then
		self:ResetUnitAuraState(state)
		state.providerRef = provider
		state.providerVersion = providerVersion
	end
	return state
end

function Reminder:InvalidateGroupMissingState() self.groupMissingState = nil end

function Reminder:MarkAuraStatesDirty()
	if type(self.unitAuraStates) == "table" then
		for _, state in pairs(self.unitAuraStates) do
			if type(state) == "table" then state.initialized = false end
		end
	end
	self:InvalidateGroupMissingState()
end

function Reminder:InvalidateAuraStates()
	self.unitAuraStates = {}
	self:InvalidateGroupMissingState()
end

function Reminder:GetTrackableProviderAuraData(aura, provider)
	if not aura or (issecretvalue and issecretvalue(aura)) then return nil end
	if not (provider and provider.spellSet) then return nil end

	local isHelpful = aura.isHelpful
	if issecretvalue and issecretvalue(isHelpful) then isHelpful = nil end
	if isHelpful == false then return nil end

	local auraId = normalizeAuraInstanceId(aura.auraInstanceID)
	if not auraId then return nil end

	local spellId = normalizeSpellId(aura.spellId)
	if spellId and provider.spellSet[spellId] then return auraId, spellId end

	if type(provider.spellNameSet) ~= "table" or provider.spellNameSetReady ~= true then refreshProviderSpellNameSet(provider) end
	local auraName = aura.name
	if issecretvalue and issecretvalue(auraName) then auraName = nil end
	if type(auraName) == "string" and auraName ~= "" and provider.spellNameSet and provider.spellNameSet[auraName] then return auraId, spellId end

	return nil
end

function Reminder:AddProviderAuraToState(state, aura, provider)
	if type(state) ~= "table" then return false end
	local auraId, spellId = self:GetTrackableProviderAuraData(aura, provider)
	if not auraId then return false end

	if state.trackedByInstance[auraId] == nil then
		state.trackedByInstance[auraId] = spellId
		state.trackedCount = (state.trackedCount or 0) + 1
	else
		state.trackedByInstance[auraId] = spellId
	end
	state.hasBuff = (state.trackedCount or 0) > 0
	return true
end

function Reminder:RemoveProviderAuraFromState(state, auraId)
	if type(state) ~= "table" then return false end
	auraId = normalizeAuraInstanceId(auraId)
	if not auraId or state.trackedByInstance[auraId] == nil then return false end

	state.trackedByInstance[auraId] = nil
	state.trackedCount = (state.trackedCount or 0) - 1
	if state.trackedCount < 0 then state.trackedCount = 0 end
	state.hasBuff = state.trackedCount > 0
	return true
end

function Reminder:FullRefreshUnitAuraState(unit, provider)
	local state = self:PrepareUnitAuraState(unit, provider)
	if not state then return nil end
	self:ResetUnitAuraState(state)
	if isAIFollowerUnit(unit) then
		state.initialized = true
		return state
	end

	if not (unit and UnitExists and UnitExists(unit) and provider and provider.spellSet) then
		state.initialized = true
		return state
	end
	if not (C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot) then
		state.initialized = true
		return state
	end

	local continuationToken
	for _ = 1, AURA_SLOT_SCAN_GUARD do
		local slots, slotCount, nextToken = getHelpfulAuraSlotBuffer(unit, continuationToken)
		for i = 2, slotCount do
			local slot = slots[i]
			if not (issecretvalue and issecretvalue(slot)) then
				local aura = C_UnitAuras.GetAuraDataBySlot(unit, slot)
				if aura then self:AddProviderAuraToState(state, aura, provider) end
			end
		end

		if nextToken == nil then break end
		continuationToken = nextToken
	end

	state.hasBuff = (state.trackedCount or 0) > 0
	state.initialized = true
	return state
end

function Reminder:ApplyDeltaToUnitAuraState(unit, updateInfo, provider)
	local state = self:PrepareUnitAuraState(unit, provider)
	if not state then return nil end
	if isAIFollowerUnit(unit) then
		self:ResetUnitAuraState(state)
		state.initialized = true
		return state
	end

	if not (provider and provider.spellSet) then
		self:ResetUnitAuraState(state)
		state.initialized = true
		return state
	end
	if not UnitExists or not UnitExists(unit) then
		self:ResetUnitAuraState(state)
		return state
	end

	if not updateInfo or (issecretvalue and issecretvalue(updateInfo)) then return self:FullRefreshUnitAuraState(unit, provider) end
	local isFullUpdate = updateInfo.isFullUpdate
	if issecretvalue and issecretvalue(isFullUpdate) then isFullUpdate = true end
	if isFullUpdate or not state.initialized then return self:FullRefreshUnitAuraState(unit, provider) end

	local removed = updateInfo.removedAuraInstanceIDs
	if type(removed) == "table" then
		for i = 1, #removed do
			local auraId = normalizeAuraInstanceId(removed[i])
			if auraId and state.trackedByInstance[auraId] ~= nil then self:RemoveProviderAuraFromState(state, auraId) end
		end
	end

	local added = updateInfo.addedAuras
	if type(added) == "table" then
		for i = 1, #added do
			self:AddProviderAuraToState(state, added[i], provider)
		end
	end

	local updated = updateInfo.updatedAuraInstanceIDs
	if type(updated) == "table" and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
		for i = 1, #updated do
			local auraId = normalizeAuraInstanceId(updated[i])
			if auraId and state.trackedByInstance[auraId] ~= nil then
				local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraId)
				if aura then
					local trackedAuraId = self:GetTrackableProviderAuraData(aura, provider)
					if trackedAuraId ~= auraId then self:RemoveProviderAuraFromState(state, auraId) end
				else
					self:RemoveProviderAuraFromState(state, auraId)
				end
			end
		end
	end

	state.hasBuff = (state.trackedCount or 0) > 0
	state.initialized = true
	return state
end

function Reminder:IsGroupMissingStateValid(provider, state)
	if type(provider) ~= "table" or provider.scope == PROVIDER_SCOPE_SELF then return false end
	if type(state) ~= "table" then return false end
	if state.providerRef ~= provider then return false end
	if state.providerVersion ~= getProviderStateVersion(provider) then return false end
	return state.rosterVersion == (tonumber(self.rosterUnitsVersion) or 0)
end

function Reminder:GetGroupUnitMissingStatus(provider, unit)
	if isAIFollowerUnit(unit) then return GROUP_UNIT_STATUS_INELIGIBLE end
	if not (UnitExists and UnitExists(unit) and UnitIsConnected and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)) then return GROUP_UNIT_STATUS_INELIGIBLE end
	if self:UnitHasProviderBuff(unit, provider) then return GROUP_UNIT_STATUS_PRESENT end
	return GROUP_UNIT_STATUS_MISSING
end

function Reminder:ApplyGroupUnitMissingStatus(state, unit, nextStatus)
	if type(state) ~= "table" or type(unit) ~= "string" or unit == "" then return end
	state.unitStatus = state.unitStatus or {}
	local previous = state.unitStatus[unit]
	if previous == nextStatus then return end

	if previous == GROUP_UNIT_STATUS_PRESENT or previous == GROUP_UNIT_STATUS_MISSING then state.total = math.max(0, (tonumber(state.total) or 0) - 1) end
	if previous == GROUP_UNIT_STATUS_MISSING then state.missing = math.max(0, (tonumber(state.missing) or 0) - 1) end

	if nextStatus == GROUP_UNIT_STATUS_PRESENT or nextStatus == GROUP_UNIT_STATUS_MISSING then state.total = (tonumber(state.total) or 0) + 1 end
	if nextStatus == GROUP_UNIT_STATUS_MISSING then state.missing = (tonumber(state.missing) or 0) + 1 end

	state.unitStatus[unit] = nextStatus
end

function Reminder:RebuildGroupMissingState(provider)
	if type(provider) ~= "table" or provider.scope == PROVIDER_SCOPE_SELF then
		self.groupMissingState = nil
		return nil
	end

	local state = self.groupMissingState or {}
	state.providerRef = provider
	state.providerVersion = getProviderStateVersion(provider)
	state.rosterVersion = tonumber(self.rosterUnitsVersion) or 0
	state.total = 0
	state.missing = 0
	state.unitStatus = state.unitStatus or {}
	wipeTable(state.unitStatus)

	local units = self:GetRosterUnits()
	for i = 1, #units do
		local unit = units[i]
		self:ApplyGroupUnitMissingStatus(state, unit, self:GetGroupUnitMissingStatus(provider, unit))
	end

	self.groupMissingState = state
	return state
end

function Reminder:GetGroupMissingState(provider)
	local state = self.groupMissingState
	if self:IsGroupMissingStateValid(provider, state) then return state end
	return self:RebuildGroupMissingState(provider)
end

function Reminder:RefreshGroupMissingStateUnit(provider, unit)
	local state = self.groupMissingState
	if not self:IsGroupMissingStateValid(provider, state) then return nil end
	if not self:IsRosterUnit(unit) then return state end
	self:ApplyGroupUnitMissingStatus(state, unit, self:GetGroupUnitMissingStatus(provider, unit))
	return state
end

function Reminder:HasProvider()
	local _, hasProvider = self:RefreshProviderCache(false)
	return hasProvider == true
end

function Reminder:EnsureFrame()
	if self.frame then return self.frame end

	local frame = CreateFrame("Frame", "EQOL_ClassBuffReminderFrame", UIParent, "BackdropTemplate")
	frame:SetClampedToScreen(true)
	frame:SetMovable(false)
	frame:SetSize(220, 34)
	frame:SetFrameStrata("MEDIUM")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0, 0, 0, 0.45)
	frame.bg = bg

	local iconHolder = CreateFrame("Button", nil, frame)
	iconHolder:SetSize(defaults.iconSize, defaults.iconSize)
	iconHolder:SetPoint("LEFT", frame, "LEFT", 6, 0)
	frame.iconHolder = iconHolder

	local icon = iconHolder:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(iconHolder)
	icon:SetTexture(ICON_MISSING)
	frame.icon = icon

	local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	nameText:SetJustifyH("LEFT")
	nameText:SetPoint("TOPLEFT", iconHolder, "TOPRIGHT", 6, -1)
	frame.nameText = nameText

	local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	countText:SetJustifyH("LEFT")
	countText:SetPoint("BOTTOMLEFT", iconHolder, "BOTTOMRIGHT", 6, 1)
	frame.countText = countText

	local iconCountText = iconHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	iconCountText:SetPoint("CENTER", iconHolder, "CENTER", 0, 0)
	iconCountText:SetJustifyH("CENTER")
	iconCountText:SetShadowOffset(1, -1)
	iconCountText:SetShadowColor(0, 0, 0, 1)
	iconCountText:Hide()
	frame.iconCountText = iconCountText

	local missingIconContainer = CreateFrame("Frame", nil, frame)
	missingIconContainer:SetPoint("CENTER", frame, "CENTER", 0, 0)
	missingIconContainer:SetSize(defaults.iconSize, defaults.iconSize)
	missingIconContainer:Hide()
	frame.missingIconContainer = missingIconContainer
	frame.missingIcons = {}

	local sampleContainer = CreateFrame("Frame", nil, frame)
	sampleContainer:SetAllPoints(frame)
	sampleContainer:Hide()
	frame.sampleContainer = sampleContainer

	frame.sampleIcons = {}
	for i = 1, SAMPLE_ICON_COUNT do
		local sample = CreateFrame("Frame", nil, sampleContainer)
		sample:SetSize(defaults.iconSize, defaults.iconSize)
		local sampleIcon = sample:CreateTexture(nil, "ARTWORK")
		sampleIcon:SetAllPoints(sample)
		sampleIcon:SetTexture(safeGetSpellIcon(SAMPLE_SPELL_IDS[i]))
		sample.icon = sampleIcon
		sample:Hide()
		frame.sampleIcons[i] = sample
	end

	frame:Hide()

	self.frame = frame
	self:ApplyVisualSettings()

	return frame
end

function Reminder:GetSelfProviderStatus(provider, forceRefresh)
	if type(provider) ~= "table" or provider.scope ~= PROVIDER_SCOPE_SELF then return nil end
	if not forceRefresh and self.selfProviderStatusProvider == provider and type(self.selfProviderStatus) == "table" then return self.selfProviderStatus end
	if type(provider.getSelfStatusFunc) ~= "function" then return nil end

	local status = provider.getSelfStatusFunc(provider, self)
	if type(status) ~= "table" then return nil end

	local entries = type(status.missingEntries) == "table" and status.missingEntries or {}
	local missing = tonumber(status.missing)
	if missing == nil then missing = #entries end
	if missing < 0 then missing = 0 end
	local total = tonumber(status.total)
	if total == nil then total = math.max(1, missing) end
	if total < missing then total = missing end
	if total < 0 then total = 0 end

	status.missingEntries = entries
	status.missing = missing
	status.total = total

	self.selfProviderStatusProvider = provider
	self.selfProviderStatus = status
	return status
end

function Reminder:GetSelfMissingEntries(provider)
	local status = self:GetSelfProviderStatus(provider, false)
	if not status then return nil end
	return status.missingEntries
end

function Reminder:GetSelfMissingSummaryText(entries)
	if type(entries) ~= "table" or #entries <= 0 then return "" end
	local parts = {}
	for i = 1, #entries do
		local entry = entries[i]
		local label = type(entry) == "table" and entry.label or nil
		if type(label) ~= "string" or label == "" then
			local sid = type(entry) == "table" and normalizeSpellId(entry.spellId) or nil
			label = sid and safeGetSpellName(sid) or nil
		end
		if type(label) ~= "string" or label == "" then label = L["ClassBuffReminderMissing"] or "Missing" end
		local cm = type(entry) == "table" and tonumber(entry.countMissing) or nil
		local ct = type(entry) == "table" and tonumber(entry.countTotal) or nil
		if cm and ct and ct > 0 then
			cm = math.max(0, math.floor(cm + 0.5))
			ct = math.max(0, math.floor(ct + 0.5))
			label = string.format("%s (%d/%d)", label, cm, ct)
		end
		parts[#parts + 1] = label
	end
	return table.concat(parts, ", ")
end

function Reminder:EnsureSelfMissingIconFrames(requiredCount)
	local frame = self:EnsureFrame()
	if not frame then return nil, nil end
	frame.missingIcons = frame.missingIcons or {}
	frame.missingIconContainer = frame.missingIconContainer or CreateFrame("Frame", nil, frame)
	local container = frame.missingIconContainer

	for i = 1, requiredCount do
		local iconFrame = frame.missingIcons[i]
		if not iconFrame then
			iconFrame = CreateFrame("Frame", nil, container)
			iconFrame:SetSize(defaults.iconSize, defaults.iconSize)
			local icon = iconFrame:CreateTexture(nil, "ARTWORK")
			icon:SetAllPoints(iconFrame)
			icon:SetTexture(ICON_MISSING)
			iconFrame.icon = icon

			local countText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			countText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
			countText:SetJustifyH("CENTER")
			countText:SetShadowOffset(1, -1)
			countText:SetShadowColor(0, 0, 0, 1)
			countText:SetText("")
			iconFrame.countText = countText

			frame.missingIcons[i] = iconFrame
		end
	end

	return container, frame.missingIcons
end

function Reminder:HideSelfMissingIcons()
	local frame = self.frame
	if not frame then return end
	if frame.missingIconContainer then frame.missingIconContainer:Hide() end
	if frame.missingIcons then
		for i = 1, #frame.missingIcons do
			local iconFrame = frame.missingIcons[i]
			if iconFrame then iconFrame:Hide() end
		end
	end
	if frame.iconHolder then frame.iconHolder:Show() end
end

function Reminder:RenderSelfMissingIcons(missingEntries)
	local frame = self.frame
	if not frame then return false end
	if type(missingEntries) ~= "table" or #missingEntries <= 0 then
		self:HideSelfMissingIcons()
		return false
	end

	local scale = clamp(getValue(DB_SCALE, defaults.scale), 0.5, 2, defaults.scale)
	local iconSize = clamp(getValue(DB_ICON_SIZE, defaults.iconSize), 14, 120, defaults.iconSize)
	local iconGap = clamp(getValue(DB_ICON_GAP, defaults.iconGap), 0, 40, defaults.iconGap)
	local xyTextSize, xyTextOutline, xyTextR, xyTextG, xyTextB, xyTextA, xyOffsetX, xyOffsetY = self:GetIconCountTextStyle()
	local scaledIconSize = math.max(14, math.floor((iconSize * scale) + 0.5))
	local scaledIconGap = math.max(0, math.floor((iconGap * scale) + 0.5))
	local scaledXYTextSize = math.max(8, math.floor((xyTextSize * scale) + 0.5))
	local scaledXYOffsetX = math.floor((xyOffsetX * scale) + 0.5)
	local scaledXYOffsetY = math.floor((xyOffsetY * scale) + 0.5)
	local step = scaledIconSize + scaledIconGap
	local direction = self:GetGrowthDirection()
	local growFromCenter = self:GetGrowthFromCenter()
	local count = #missingEntries
	local fontPath = (addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT

	local width, height
	if direction == GROWTH_UP or direction == GROWTH_DOWN then
		width = scaledIconSize
		height = scaledIconSize + ((count - 1) * step)
	else
		width = scaledIconSize + ((count - 1) * step)
		height = scaledIconSize
	end

	local container, icons = self:EnsureSelfMissingIconFrames(count)
	if not (container and icons) then return false end

	container:ClearAllPoints()
	container:SetPoint("CENTER", frame, "CENTER", 0, 0)
	container:SetSize(width, height)

	for i = 1, #icons do
		if icons[i] then icons[i]:Hide() end
	end

	for i = 1, count do
		local iconFrame = icons[i]
		local entry = missingEntries[i]
		local sid = type(entry) == "table" and normalizeSpellId(entry.spellId) or nil
		local texture = sid and safeGetSpellIcon(sid) or ICON_MISSING

		iconFrame:SetSize(scaledIconSize, scaledIconSize)
		iconFrame:ClearAllPoints()

		local x = 0
		local y = 0
		if growFromCenter then
			local centeredOffset = centeredAxisOffset(i, count, step)
			if direction == GROWTH_UP or direction == GROWTH_DOWN then
				y = centeredOffset
			else
				x = centeredOffset
			end
		elseif direction == GROWTH_LEFT then
			x = (width / 2) - (scaledIconSize / 2) - ((i - 1) * step)
		elseif direction == GROWTH_UP then
			y = -(height / 2) + (scaledIconSize / 2) + ((i - 1) * step)
		elseif direction == GROWTH_DOWN then
			y = (height / 2) - (scaledIconSize / 2) - ((i - 1) * step)
		else
			x = -(width / 2) + (scaledIconSize / 2) + ((i - 1) * step)
		end

		iconFrame:SetPoint("CENTER", container, "CENTER", x, y)
		if iconFrame.icon then iconFrame.icon:SetTexture(texture) end
		if iconFrame.countText then
			if iconFrame.countText.SetFont then iconFrame.countText:SetFont(fontPath, scaledXYTextSize, textOutlineFlags(xyTextOutline)) end
			iconFrame.countText:SetTextColor(xyTextR, xyTextG, xyTextB, xyTextA)
			iconFrame.countText:ClearAllPoints()
			iconFrame.countText:SetPoint("CENTER", iconFrame, "CENTER", scaledXYOffsetX, scaledXYOffsetY)
			local cm = type(entry) == "table" and tonumber(entry.countMissing) or nil
			local ct = type(entry) == "table" and tonumber(entry.countTotal) or nil
			if cm and ct and ct > 0 then
				cm = math.max(0, math.floor(cm + 0.5))
				ct = math.max(0, math.floor(ct + 0.5))
				iconFrame.countText:SetText(string.format("%d/%d", cm, ct))
			else
				iconFrame.countText:SetText("")
			end
		end
		iconFrame:Show()
	end

	if frame.iconHolder then frame.iconHolder:Hide() end
	container:Show()
	frame:SetSize(width + 2, height + 2)
	return true
end

function Reminder:GetGlowTargets()
	local frame = self.frame
	if not frame then return nil end

	if frame.missingIconContainer and frame.missingIconContainer:IsShown() and type(frame.missingIcons) == "table" then
		local targets = {}
		for i = 1, #frame.missingIcons do
			local iconFrame = frame.missingIcons[i]
			if iconFrame and iconFrame:IsShown() then targets[#targets + 1] = iconFrame end
		end
		if #targets > 0 then return targets end
	end

	if frame.iconHolder then return { frame.iconHolder } end
	return nil
end

function Reminder:SetGlowShown(show)
	if not LBG then return end

	self.glowTargets = self.glowTargets or {}
	if show ~= true then
		for target in pairs(self.glowTargets) do
			LBG.HideOverlayGlow(target)
			self.glowTargets[target] = nil
		end
		self.glowShown = false
		return
	end

	local targets = self:GetGlowTargets() or {}
	local nextTargets = {}
	for i = 1, #targets do
		local target = targets[i]
		if target then nextTargets[target] = true end
	end

	for target in pairs(self.glowTargets) do
		if not nextTargets[target] then
			LBG.HideOverlayGlow(target)
			self.glowTargets[target] = nil
		end
	end

	for target in pairs(nextTargets) do
		if not self.glowTargets[target] then
			LBG.ShowOverlayGlow(target)
			self.glowTargets[target] = true
		end
	end

	self.glowShown = next(self.glowTargets) ~= nil
end

function Reminder:HideSamplePreview()
	local frame = self.frame
	if not frame then return end
	if frame.sampleContainer then frame.sampleContainer:Hide() end
	if not frame.sampleIcons then return end
	for i = 1, #frame.sampleIcons do
		local sample = frame.sampleIcons[i]
		if sample then sample:Hide() end
	end
end

function Reminder:ApplySamplePreview(iconSize, scale, iconGap)
	local frame = self.frame
	if not frame or not frame.sampleIcons then return end
	if not self.editModeActive then
		self:HideSamplePreview()
		return
	end

	local direction = self:GetGrowthDirection()
	local growFromCenter = self:GetGrowthFromCenter()
	local spacing = iconGap
	if type(spacing) ~= "number" then spacing = math.floor((6 * (scale or 1)) + 0.5) end
	if spacing < 0 then spacing = 0 end
	local count = math.min(SAMPLE_ICON_COUNT, #frame.sampleIcons)

	for i = 1, count do
		local sample = frame.sampleIcons[i]
		local sid = SAMPLE_SPELL_IDS[((i - 1) % #SAMPLE_SPELL_IDS) + 1]
		sample:ClearAllPoints()
		sample:SetSize(iconSize, iconSize)
		if sample.icon then sample.icon:SetTexture(safeGetSpellIcon(sid)) end
		sample:SetAlpha(i == 1 and 1 or 0.85)
		sample:Show()

		if growFromCenter then
			local centeredOffset = centeredAxisOffset(i, count, spacing)
			if direction == GROWTH_UP or direction == GROWTH_DOWN then
				sample:SetPoint("CENTER", frame, "CENTER", 0, centeredOffset)
			else
				sample:SetPoint("CENTER", frame, "CENTER", centeredOffset, 0)
			end
		elseif i == 1 then
			if direction == GROWTH_LEFT then
				sample:SetPoint("RIGHT", frame, "LEFT", -spacing, 0)
			elseif direction == GROWTH_UP then
				sample:SetPoint("BOTTOM", frame, "TOP", 0, spacing)
			elseif direction == GROWTH_DOWN then
				sample:SetPoint("TOP", frame, "BOTTOM", 0, -spacing)
			else
				sample:SetPoint("LEFT", frame, "RIGHT", spacing, 0)
			end
		else
			local prev = frame.sampleIcons[i - 1]
			if direction == GROWTH_LEFT then
				sample:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
			elseif direction == GROWTH_UP then
				sample:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
			elseif direction == GROWTH_DOWN then
				sample:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
			else
				sample:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
			end
		end
	end

	if frame.sampleContainer then frame.sampleContainer:Show() end
end

function Reminder:ApplyVisualSettings()
	local frame = self:EnsureFrame()
	if not frame then return end

	local scale = clamp(getValue(DB_SCALE, defaults.scale), 0.5, 2, defaults.scale)
	local iconSize = clamp(getValue(DB_ICON_SIZE, defaults.iconSize), 14, 120, defaults.iconSize)
	local fontSize = clamp(getValue(DB_FONT_SIZE, defaults.fontSize), 9, 30, defaults.fontSize)
	local iconGap = clamp(getValue(DB_ICON_GAP, defaults.iconGap), 0, 40, defaults.iconGap)
	local displayMode = normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode))
	local growthDirection = normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection))
	local xyTextSize, xyTextOutline, xyTextR, xyTextG, xyTextB, xyTextA, xyOffsetX, xyOffsetY = self:GetIconCountTextStyle()
	local scaledIconSize = math.max(14, math.floor((iconSize * scale) + 0.5))
	local scaledFontSize = math.max(9, math.floor((fontSize * scale) + 0.5))
	local scaledIconGap = math.max(0, math.floor((iconGap * scale) + 0.5))
	local scaledXYTextSize = math.max(8, math.floor((xyTextSize * scale) + 0.5))
	local scaledXYOffsetX = math.floor((xyOffsetX * scale) + 0.5)
	local scaledXYOffsetY = math.floor((xyOffsetY * scale) + 0.5)
	local textGap = scaledIconGap
	local framePadding = math.max(4, math.floor((6 * scale) + 0.5))

	if addon.db then
		if addon.db[DB_DISPLAY_MODE] ~= displayMode then addon.db[DB_DISPLAY_MODE] = displayMode end
		if addon.db[DB_SCALE] ~= scale then addon.db[DB_SCALE] = scale end
		if addon.db[DB_ICON_SIZE] ~= iconSize then addon.db[DB_ICON_SIZE] = iconSize end
		if addon.db[DB_FONT_SIZE] ~= fontSize then addon.db[DB_FONT_SIZE] = fontSize end
		if addon.db[DB_ICON_GAP] ~= iconGap then addon.db[DB_ICON_GAP] = iconGap end
		if addon.db[DB_GROWTH_DIRECTION] ~= growthDirection then addon.db[DB_GROWTH_DIRECTION] = growthDirection end
		if addon.db[DB_XY_TEXT_SIZE] ~= xyTextSize then addon.db[DB_XY_TEXT_SIZE] = xyTextSize end
		if addon.db[DB_XY_TEXT_OUTLINE] ~= xyTextOutline then addon.db[DB_XY_TEXT_OUTLINE] = xyTextOutline end
		if addon.db[DB_XY_TEXT_OFFSET_X] ~= xyOffsetX then addon.db[DB_XY_TEXT_OFFSET_X] = xyOffsetX end
		if addon.db[DB_XY_TEXT_OFFSET_Y] ~= xyOffsetY then addon.db[DB_XY_TEXT_OFFSET_Y] = xyOffsetY end
		local currentColor = addon.db[DB_XY_TEXT_COLOR]
		if type(currentColor) ~= "table" or currentColor.r ~= xyTextR or currentColor.g ~= xyTextG or currentColor.b ~= xyTextB or currentColor.a ~= xyTextA then
			addon.db[DB_XY_TEXT_COLOR] = { r = xyTextR, g = xyTextG, b = xyTextB, a = xyTextA }
		end
	end

	frame:SetScale(1)
	frame.iconHolder:SetSize(scaledIconSize, scaledIconSize)
	frame.iconHolder:ClearAllPoints()
	frame.iconHolder:SetShown(true)

	local fontPath = (addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT
	if frame.nameText and frame.nameText.SetFont then frame.nameText:SetFont(fontPath, scaledFontSize, "OUTLINE") end
	if frame.countText and frame.countText.SetFont then frame.countText:SetFont(fontPath, scaledFontSize, "OUTLINE") end
	if frame.iconCountText and frame.iconCountText.SetFont then frame.iconCountText:SetFont(fontPath, scaledXYTextSize, textOutlineFlags(xyTextOutline)) end
	if frame.iconCountText then
		frame.iconCountText:SetTextColor(xyTextR, xyTextG, xyTextB, xyTextA)
		frame.iconCountText:ClearAllPoints()
		frame.iconCountText:SetPoint("CENTER", frame.iconHolder, "CENTER", scaledXYOffsetX, scaledXYOffsetY)
		if frame.iconCountText.SetWidth then frame.iconCountText:SetWidth(scaledIconSize + 2) end
	end

	frame.nameText:ClearAllPoints()
	frame.countText:ClearAllPoints()
	if displayMode == DISPLAY_MODE_ICON_ONLY then
		if frame.bg then frame.bg:Hide() end
		frame.nameText:Hide()
		frame.countText:Hide()
		if frame.iconCountText then frame.iconCountText:Show() end
		frame.iconHolder:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame:SetSize(scaledIconSize + 2, scaledIconSize + 2)
	else
		if frame.bg then frame.bg:Show() end
		frame.nameText:Show()
		frame.countText:Show()
		if frame.iconCountText then frame.iconCountText:Hide() end
		frame.iconHolder:SetPoint("LEFT", frame, "LEFT", framePadding, 0)
		frame.nameText:SetPoint("TOPLEFT", frame.iconHolder, "TOPRIGHT", textGap, -1)
		frame.countText:SetPoint("BOTTOMLEFT", frame.iconHolder, "BOTTOMRIGHT", textGap, 1)
		local textWidth = math.max(frame.nameText:GetStringWidth() or 0, frame.countText:GetStringWidth() or 0)
		local width = (scaledIconSize + (framePadding * 2) + textGap) + textWidth + framePadding
		local minWidth = math.floor((120 * scale) + 0.5)
		if width < minWidth then width = minWidth end
		local height = math.max(scaledIconSize + (framePadding * 2), (scaledFontSize * 2) + (framePadding * 2))
		local minHeight = math.floor((30 * scale) + 0.5)
		if height < minHeight then height = minHeight end
		frame:SetSize(width, height)
	end

	self:ApplySamplePreview(scaledIconSize, scale, scaledIconGap)
end

function Reminder:InvalidateRosterCache()
	self.rosterUnitsValid = nil
	self.rosterUnitsVersion = (tonumber(self.rosterUnitsVersion) or 0) + 1
	self:InvalidateGroupMissingState()
end

function Reminder:GetRosterUnits()
	if self.rosterUnitsValid == true and type(self.rosterUnits) == "table" then return self.rosterUnits end

	self.rosterUnits = self.rosterUnits or {}
	self.rosterUnitLookup = self.rosterUnitLookup or {}
	local units = self.rosterUnits
	local lookup = self.rosterUnitLookup
	for i = #units, 1, -1 do
		units[i] = nil
	end
	wipeTable(lookup)

	if IsInRaid and IsInRaid() then
		local total = (GetNumGroupMembers and GetNumGroupMembers()) or 0
		for i = 1, total do
			local unit = "raid" .. i
			units[#units + 1] = unit
			lookup[unit] = true
		end
	elseif IsInGroup and IsInGroup() then
		units[#units + 1] = "player"
		lookup.player = true
		local total = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or math.max(0, ((GetNumGroupMembers and GetNumGroupMembers()) or 1) - 1)
		for i = 1, total do
			local unit = "party" .. i
			units[#units + 1] = unit
			lookup[unit] = true
		end
	else
		units[#units + 1] = "player"
		lookup.player = true
	end

	self.rosterUnitsValid = true
	return units
end

function Reminder:IsRosterUnit(unit)
	if type(unit) ~= "string" or unit == "" then return false end
	self:GetRosterUnits()
	return self.rosterUnitLookup and self.rosterUnitLookup[unit] == true
end

function Reminder:CollectUnits(target)
	local units = self:GetRosterUnits()
	if not target or target == units then return units end
	for i = #target, 1, -1 do
		target[i] = nil
	end
	for i = 1, #units do
		target[i] = units[i]
	end
	return target
end

function Reminder:CollectOtherHealerUnits(target)
	if not target then target = {} end
	for i = #target, 1, -1 do
		target[i] = nil
	end

	local units = self:GetRosterUnits()
	for i = 1, #units do
		local unit = units[i]
		if unit ~= "player" and not isAIFollowerUnit(unit) and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and isUnitHealerRole(unit) then target[#target + 1] = unit end
	end

	return target
end

function Reminder:UnitHasProviderBuff(unit, provider)
	if not (unit and provider) then return false end
	if provider.scope == PROVIDER_SCOPE_SELF then
		local status = self:GetSelfProviderStatus(provider, false)
		if status then return status.missing <= 0 end
	end
	if type(provider.hasUnitBuffFunc) == "function" then return provider.hasUnitBuffFunc(provider, unit, self) == true end
	if not provider.spellSet then return false end
	local state = self:PrepareUnitAuraState(unit, provider)
	if not state then return false end
	if not state.initialized then state = self:FullRefreshUnitAuraState(unit, provider) end
	return state and state.hasBuff == true
end

function Reminder:ComputeMissing(provider)
	if provider and provider.scope == PROVIDER_SCOPE_SELF then
		self.selfProviderStatusProvider = nil
		self.selfProviderStatus = nil
		if not canEvaluateUnit("player") then return 0, 0 end

		local status = self:GetSelfProviderStatus(provider, true)
		if status then return status.missing, status.total end

		if self:UnitHasProviderBuff("player", provider) then return 0, 1 end
		return 1, 1
	end
	self.selfProviderStatusProvider = nil
	self.selfProviderStatus = nil

	local state = self:GetGroupMissingState(provider)
	if not state then return 0, 0 end
	return tonumber(state.missing) or 0, tonumber(state.total) or 0
end

function Reminder:IsGroupModeAllowed()
	if IsInRaid and IsInRaid() then return getValue(DB_SHOW_RAID, defaults.showRaid) == true end
	if IsInGroup and IsInGroup() then return getValue(DB_SHOW_PARTY, defaults.showParty) == true end
	return getValue(DB_SHOW_SOLO, defaults.showSolo) == true
end

function Reminder:ShouldRegisterRuntimeEvents()
	if getValue(DB_ENABLED, defaults.enabled) ~= true then return false end
	if self.runtimeProviderValid ~= true then self:RefreshProviderCache(false) end
	if self.hasProviderCached == true then return true end
	return self:IsFlaskTrackingEnabled()
end

function Reminder:Render(provider, missing, total, supplementalEntries, effectiveMissing)
	local frame = self:EnsureFrame()
	if not frame then return end

	local displayMode = normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode))
	local title = self:GetProviderName(provider)
	local selfMissingEntries = self:GetSelfMissingEntries(provider)
	local supplemental = type(supplementalEntries) == "table" and supplementalEntries or nil
	local iconEntries
	local summaryEntries

	if provider and provider.scope == PROVIDER_SCOPE_SELF then
		summaryEntries = {}
		if type(selfMissingEntries) == "table" and #selfMissingEntries > 0 then appendMissingEntries(summaryEntries, selfMissingEntries) end
		if supplemental and #supplemental > 0 then appendMissingEntries(summaryEntries, supplemental) end
		if #summaryEntries <= 0 then summaryEntries = nil end
		iconEntries = summaryEntries
	elseif supplemental and #supplemental > 0 then
		summaryEntries = supplemental
		iconEntries = {}
		if tonumber(missing) and missing > 0 then iconEntries[#iconEntries + 1] = makeSelfMissingEntry(provider and provider.displaySpellId, title, missing, total) end
		appendMissingEntries(iconEntries, supplemental)
	end

	self:HideSelfMissingIcons()
	if displayMode == DISPLAY_MODE_ICON_ONLY then
		if iconEntries and #iconEntries > 0 then
			if frame.iconCountText then frame.iconCountText:SetText("") end
		else
			local shortFmt = L["ClassBuffReminderCountOnlyFmt"] or "%d/%d"
			if frame.iconCountText then frame.iconCountText:SetText(string.format(shortFmt, missing, total)) end
		end
	else
		frame.nameText:SetText(title)
		if provider and provider.scope == PROVIDER_SCOPE_SELF then
			frame.countText:SetText(self:GetSelfMissingSummaryText(summaryEntries))
		elseif summaryEntries and #summaryEntries > 0 then
			if tonumber(missing) and missing > 0 then
				local missingText = L["ClassBuffReminderMissingFmt"] or "%d/%d missing"
				local buffMissingText = string.format(missingText, missing, total)
				local supplementalText = self:GetSelfMissingSummaryText(summaryEntries)
				if supplementalText and supplementalText ~= "" then
					frame.countText:SetText(buffMissingText .. ", " .. supplementalText)
				else
					frame.countText:SetText(buffMissingText)
				end
			else
				frame.countText:SetText(self:GetSelfMissingSummaryText(summaryEntries))
			end
		else
			local missingText = L["ClassBuffReminderMissingFmt"] or "%d/%d missing"
			frame.countText:SetText(string.format(missingText, missing, total))
		end
	end

	local providerIcon = self:GetProviderIcon(provider)
	if providerIcon == ICON_MISSING and self.editModeActive ~= true then
		self:SetGlowShown(false)
		frame:Hide()
		self:RequestProviderPresentationRefresh(provider)
		return
	end
	frame.icon:SetTexture(providerIcon)
	self:ApplyVisualSettings()
	if displayMode == DISPLAY_MODE_ICON_ONLY and iconEntries and #iconEntries > 0 and self.editModeActive ~= true then self:RenderSelfMissingIcons(iconEntries) end
	if displayMode ~= DISPLAY_MODE_ICON_ONLY then
		local hasVisibleMissing = (tonumber(effectiveMissing) or tonumber(missing) or 0) > 0
		if hasVisibleMissing then
			if frame.countText then frame.countText:SetTextColor(1, 0.25, 0.25, 1) end
		else
			if frame.countText then frame.countText:SetTextColor(0.35, 1, 0.35, 1) end
		end
	end
	frame:Show()

	local showGlow = getValue(DB_GLOW, defaults.glow) == true and ((tonumber(effectiveMissing) or tonumber(missing) or 0) > 0)
	self:SetGlowShown(showGlow)
end

function Reminder:RenderEditModePreview()
	local frame = self:EnsureFrame()
	if not frame then return end

	local displayMode = normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode))
	local provider = self:GetProvider()
	if provider then
		self:Render(provider, 2, 5)
		if displayMode ~= DISPLAY_MODE_ICON_ONLY then frame.countText:SetTextColor(1, 0.82, 0, 1) end
	else
		frame.icon:SetTexture(ICON_MISSING)
		if displayMode == DISPLAY_MODE_ICON_ONLY then
			if frame.iconCountText then frame.iconCountText:SetText("0/0") end
		else
			frame.nameText:SetText(L["Class Buff Reminder"] or "Class Buff Reminder")
			frame.countText:SetText(L["ClassBuffReminderNoProvider"] or "No class buff configured for this class")
			frame.countText:SetTextColor(1, 0.82, 0, 1)
		end
		self:ApplyVisualSettings()
		frame:Show()
		self:SetGlowShown(false)
	end
end

function Reminder:UpdateDisplay()
	local frame = self:EnsureFrame()
	if not frame then return end

	if self.editModeActive == true then
		self.missingActive = false
		self:RenderEditModePreview()
		return
	end

	if frame.iconCountText then frame.iconCountText:SetText("") end
	if frame.countText then frame.countText:SetText("") end
	self:HideSamplePreview()
	self:HideSelfMissingIcons()

	if getValue(DB_ENABLED, defaults.enabled) ~= true then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	local provider = self:GetProvider()
	local classProvider = provider
	if not provider then
		if self:IsFlaskTrackingEnabled() then
			provider = self:GetFlaskOnlyProvider()
		else
			self:SetGlowShown(false)
			self.missingActive = false
			frame:Hide()
			return
		end
	end

	if not self:IsGroupModeAllowed() then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	if not canEvaluateUnit("player") then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	local missing, total = 0, 0
	if classProvider then
		missing, total = self:ComputeMissing(provider)
	end
	local supplementalEntries = self:GetSupplementalMissingEntries()
	if not classProvider and type(supplementalEntries) == "table" and supplementalEntries[1] and supplementalEntries[1].spellId then
		provider.displaySpellId = normalizeSpellId(supplementalEntries[1].spellId) or provider.displaySpellId
		provider.cachedIcon = nil
		provider.cachedName = provider.fallbackName or "Flask"
		provider._presentationReady = false
	end
	local supplementalMissing = type(supplementalEntries) == "table" and #supplementalEntries or 0
	if total <= 0 and supplementalMissing <= 0 then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	local effectiveMissing = (tonumber(missing) or 0) + supplementalMissing

	if self.suppressNextMissingSound == true and effectiveMissing <= 0 then
		self.suppressNextMissingSound = false
		self:WriteSoundDebug("play-suppress-cleared", {
			reason = "no-missing-on-initial-check",
			total = tonumber(total) or 0,
		})
	end

	if effectiveMissing <= 0 then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	self:UpdateMissingStateAndSound(effectiveMissing)

	self:Render(provider, missing, total, supplementalEntries, effectiveMissing)
end

function Reminder:RequestUpdate(immediate)
	if immediate or not (C_Timer and C_Timer.After) then
		self:UpdateDisplay()
		return
	end

	if self.updatePending then return end
	self.updatePending = true
	C_Timer.After(0.08, function()
		Reminder.updatePending = false
		Reminder:UpdateDisplay()
	end)
end

function Reminder:HandleEvent(event, unit, updateInfo)
	if not self:ShouldRegisterRuntimeEvents() then return end

	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		self:ScheduleInitialSoundSync(event)
		self:InvalidateProviderAvailabilityCache()
		self:InvalidateRosterCache()
		self:MarkAuraStatesDirty()
		self:InvalidateFlaskCache()
		self:RequestUpdate(true)
		return
	end

	if event == "GROUP_ROSTER_UPDATE" then
		self:InvalidateRosterCache()
		self:MarkAuraStatesDirty()
		self:RequestUpdate(true)
		return
	end

	if event == "PLAYER_ROLES_ASSIGNED" or event == "ROLE_CHANGED_INFORM" then
		self:RequestUpdate(true)
		return
	end

	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self:RequestUpdate(true)
		return
	end

	if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "SPELLS_CHANGED" then
		self:InvalidateProviderAvailabilityCache()
		self:InvalidateFlaskCache()
		self:RequestUpdate(true)
		return
	end

	if event == "UNIT_INVENTORY_CHANGED" then
		if unit == "player" then
			self:InvalidateFlaskCache()
			self:RequestUpdate(false)
		end
		return
	end

	if event == "PLAYER_EQUIPMENT_CHANGED" then
		self:InvalidateFlaskCache()
		self:RequestUpdate(false)
		return
	end

	if event == "BAG_UPDATE_DELAYED" then
		self:InvalidateFlaskCache()
		self:RequestUpdate(false)
		return
	end

	if event == "PLAYER_LEVEL_UP" then
		self:InvalidateProviderAvailabilityCache()
		self:InvalidateFlaskCache()
		self:RequestUpdate(true)
		return
	end

	if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		self:MarkAuraStatesDirty()
		self:RequestUpdate(true)
		return
	end

	if event == "UNIT_AURA" then
		if not isTrackedUnit(unit) then return end
		local provider = self:GetProvider()
		if provider and provider.scope == PROVIDER_SCOPE_SELF then
			if unit == "player" or provider.tracksExternalUnitAuras == true then self:RequestUpdate(false) end
			return
		end
		if isAIFollowerUnit(unit) then
			local state = self:GetUnitAuraState(unit)
			if state then self:ResetUnitAuraState(state) end
			self:RefreshGroupMissingStateUnit(provider, unit)
			return
		end
		if provider then
			self:ApplyDeltaToUnitAuraState(unit, updateInfo, provider)
			self:RefreshGroupMissingStateUnit(provider, unit)
		else
			local state = self:GetUnitAuraState(unit)
			if state then self:ResetUnitAuraState(state) end
		end
		self:RequestUpdate(false)
		return
	end
end

function Reminder:RegisterEvents()
	if not self:ShouldRegisterRuntimeEvents() then
		self:UnregisterEvents()
		return
	end

	if self.eventsRegistered then return end

	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	self.eventFrame:RegisterEvent("ROLE_CHANGED_INFORM")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
	self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
	self.eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	self.eventFrame:RegisterEvent("SPELLS_CHANGED")
	self.eventFrame:RegisterEvent("UNIT_AURA")
	self.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
	self.eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
	self.eventFrame:RegisterEvent("PLAYER_DEAD")
	self.eventFrame:RegisterEvent("PLAYER_ALIVE")
	self.eventFrame:RegisterEvent("PLAYER_UNGHOST")
	self.eventFrame:SetScript("OnEvent", function(_, event, ...) Reminder:HandleEvent(event, ...) end)

	self.eventsRegistered = true
	self:ScheduleInitialSoundSync("RegisterEvents")
end

function Reminder:UnregisterEvents()
	if not self.eventFrame then return end
	self.eventFrame:UnregisterAllEvents()
	self.eventFrame:SetScript("OnEvent", nil)
	self.eventsRegistered = false
end

function Reminder:RegisterEditMode()
	if self.editModeRegistered then return end
	if not (EditMode and EditMode.RegisterFrame) then return end

	local function setBool(key, value)
		if addon.db then addon.db[key] = value == true end
		Reminder:RequestUpdate(true)
	end

	local function setNumber(key, value, minValue, maxValue, fallback)
		if not addon.db then return end
		addon.db[key] = clamp(value, minValue, maxValue, fallback)
		Reminder:ApplyVisualSettings()
		Reminder:RequestUpdate(true)
	end

	local function setColor(key, value, fallback)
		if not addon.db then return end
		local r, g, b, a = normalizeColor(value, fallback)
		addon.db[key] = { r = r, g = g, b = b, a = a }
		Reminder:ApplyVisualSettings()
		Reminder:RequestUpdate(true)
	end

	local function setDisplayMode(value)
		if addon.db then addon.db[DB_DISPLAY_MODE] = normalizeDisplayMode(value) end
		Reminder:ApplyVisualSettings()
		Reminder:RequestUpdate(true)
	end

	local function setGrowthDirection(value)
		if addon.db then addon.db[DB_GROWTH_DIRECTION] = normalizeGrowthDirection(value) end
		Reminder:ApplyVisualSettings()
		Reminder:RequestUpdate(true)
	end

	local function setGrowthFromCenter(value)
		if addon.db then addon.db[DB_GROWTH_FROM_CENTER] = value == true end
		Reminder:ApplyVisualSettings()
		Reminder:RequestUpdate(true)
	end

	local function setTrackFlasks(value)
		if addon.db then addon.db[DB_TRACK_FLASKS] = value == true end
		Reminder:InvalidateFlaskCache()
		Reminder:RequestUpdate(true)
	end

	local function setTrackFlasksInstanceOnly(value)
		if addon.db then addon.db[DB_TRACK_FLASKS_INSTANCE_ONLY] = value == true end
		Reminder:InvalidateFlaskCache()
		Reminder:RequestUpdate(true)
	end

	local function setTextOutline(value)
		if addon.db then addon.db[DB_XY_TEXT_OUTLINE] = normalizeTextOutline(value) end
		Reminder:ApplyVisualSettings()
		Reminder:RequestUpdate(true)
	end

	local function setMissingSound(value)
		if addon.db then
			local _, map, pathToKey = Reminder:GetMissingSoundOptions()
			local chosen = type(value) == "string" and value or ""
			if chosen ~= "" and map and map[chosen] then
				-- keep chosen key
			elseif chosen ~= "" and pathToKey and pathToKey[chosen] and map[pathToKey[chosen]] then
				chosen = pathToKey[chosen]
			else
				chosen = ""
			end
			addon.db[DB_MISSING_SOUND] = chosen or ""
			Reminder:WriteSoundDebug("set-sound", {
				input = type(value) == "string" and value or "",
				stored = addon.db[DB_MISSING_SOUND] or "",
			})
		end
		Reminder.initialSoundSyncDone = false
		Reminder:NormalizeMissingSoundSelection("set-missing-sound")
		Reminder:ScheduleInitialSoundSync("set-missing-sound")
		Reminder:RequestUpdate(true)
	end

	local function isIconOnlyModeActive() return normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode)) == DISPLAY_MODE_ICON_ONLY end

	local settings
	if SettingType then
		settings = {
			{
				name = L["ClassBuffReminderSectionClassBuffs"] or "Class Buffs",
				kind = SettingType.Collapsible,
				id = "classBuffs",
				defaultCollapsed = false,
			},
			{
				name = L["ClassBuffReminderShowParty"] or "Track in party",
				kind = SettingType.Checkbox,
				parentId = "classBuffs",
				default = defaults.showParty,
				get = function() return getValue(DB_SHOW_PARTY, defaults.showParty) == true end,
				set = function(_, value) setBool(DB_SHOW_PARTY, value) end,
			},
			{
				name = L["ClassBuffReminderShowRaid"] or "Track in raid",
				kind = SettingType.Checkbox,
				parentId = "classBuffs",
				default = defaults.showRaid,
				get = function() return getValue(DB_SHOW_RAID, defaults.showRaid) == true end,
				set = function(_, value) setBool(DB_SHOW_RAID, value) end,
			},
			{
				name = L["ClassBuffReminderShowSolo"] or "Show while solo",
				kind = SettingType.Checkbox,
				parentId = "classBuffs",
				default = defaults.showSolo,
				get = function() return getValue(DB_SHOW_SOLO, defaults.showSolo) == true end,
				set = function(_, value) setBool(DB_SHOW_SOLO, value) end,
			},
			{
				name = L["ClassBuffReminderGlow"] or "Glow when missing",
				kind = SettingType.Checkbox,
				parentId = "classBuffs",
				default = defaults.glow,
				get = function() return getValue(DB_GLOW, defaults.glow) == true end,
				set = function(_, value) setBool(DB_GLOW, value) end,
			},
			{
				name = L["ClassBuffReminderSectionFlasks"] or "Flasks",
				kind = SettingType.Collapsible,
				id = "flasks",
				defaultCollapsed = false,
			},
			{
				name = L["ClassBuffReminderTrackFlasks"] or "Track missing flask buff",
				kind = SettingType.Checkbox,
				parentId = "flasks",
				default = defaults.trackFlasks == true,
				get = function() return getValue(DB_TRACK_FLASKS, defaults.trackFlasks) == true end,
				set = function(_, value) setTrackFlasks(value) end,
			},
			{
				name = L["ClassBuffReminderTrackFlasksInstanceOnly"] or "Only in dungeons/raids",
				kind = SettingType.Checkbox,
				parentId = "flasks",
				default = defaults.trackFlasksInstanceOnly == true,
				get = function() return getValue(DB_TRACK_FLASKS_INSTANCE_ONLY, defaults.trackFlasksInstanceOnly) == true end,
				set = function(_, value) setTrackFlasksInstanceOnly(value) end,
				isShown = function() return getValue(DB_TRACK_FLASKS, defaults.trackFlasks) == true end,
			},
			{
				name = L["ClassBuffReminderSectionSound"] or "Sound",
				kind = SettingType.Collapsible,
				id = "sound",
				defaultCollapsed = true,
			},
			{
				name = L["ClassBuffReminderSoundOnMissing"] or "Play sound when missing",
				kind = SettingType.Checkbox,
				parentId = "sound",
				default = defaults.soundOnMissing,
				get = function() return getValue(DB_SOUND_ON_MISSING, defaults.soundOnMissing) == true end,
				set = function(_, value) setBool(DB_SOUND_ON_MISSING, value) end,
			},
			{
				name = L["ClassBuffReminderMissingSound"] or "Missing sound",
				kind = SettingType.Dropdown,
				parentId = "sound",
				height = 260,
				get = function()
					Reminder:BuildMissingSoundOptions()
					return Reminder:GetMissingSoundValue()
				end,
				set = function(_, value) setMissingSound(value) end,
				generator = function(_, root)
					local keys = Reminder:BuildMissingSoundOptions()
					for i = 1, #keys do
						local soundName = keys[i]
						root:CreateRadio(soundName, function() return Reminder:GetMissingSoundValue() == soundName end, function()
							setMissingSound(soundName)
							Reminder:PlayMissingSound(true)
						end)
					end
				end,
				isEnabled = function() return getValue(DB_SOUND_ON_MISSING, defaults.soundOnMissing) == true end,
			},
			{
				name = L["ClassBuffReminderSectionAnchorSize"] or "Anchor & Size",
				kind = SettingType.Collapsible,
				id = "anchorSize",
				defaultCollapsed = true,
			},
			{
				name = L["ClassBuffReminderDisplayMode"] or "Display mode",
				kind = SettingType.Dropdown,
				parentId = "anchorSize",
				height = 80,
				get = function() return normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode)) end,
				set = function(_, value) setDisplayMode(value) end,
				generator = function(_, root)
					root:CreateRadio(
						L["ClassBuffReminderDisplayModeFull"] or "Full",
						function() return normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode)) == DISPLAY_MODE_FULL end,
						function() setDisplayMode(DISPLAY_MODE_FULL) end
					)
					root:CreateRadio(
						L["ClassBuffReminderDisplayModeIconOnly"] or "Icon only (X/Y)",
						function() return normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode)) == DISPLAY_MODE_ICON_ONLY end,
						function() setDisplayMode(DISPLAY_MODE_ICON_ONLY) end
					)
				end,
			},
			{
				name = L["ClassBuffReminderGrowthDirection"] or "Growth direction",
				kind = SettingType.Dropdown,
				parentId = "anchorSize",
				height = 120,
				get = function() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) end,
				set = function(_, value) setGrowthDirection(value) end,
				generator = function(_, root)
					root:CreateRadio(
						L["ClassBuffReminderGrowthRight"] or "Right",
						function() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) == GROWTH_RIGHT end,
						function() setGrowthDirection(GROWTH_RIGHT) end
					)
					root:CreateRadio(
						L["ClassBuffReminderGrowthLeft"] or "Left",
						function() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) == GROWTH_LEFT end,
						function() setGrowthDirection(GROWTH_LEFT) end
					)
					root:CreateRadio(
						L["ClassBuffReminderGrowthUp"] or "Up",
						function() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) == GROWTH_UP end,
						function() setGrowthDirection(GROWTH_UP) end
					)
					root:CreateRadio(
						L["ClassBuffReminderGrowthDown"] or "Down",
						function() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) == GROWTH_DOWN end,
						function() setGrowthDirection(GROWTH_DOWN) end
					)
				end,
			},
			{
				name = L["ClassBuffReminderGrowthFromCenter"] or L["UFPowerDetachedGrowFromCenter"] or "Grow from center",
				kind = SettingType.Checkbox,
				parentId = "anchorSize",
				default = defaults.growthFromCenter == true,
				get = function() return getValue(DB_GROWTH_FROM_CENTER, defaults.growthFromCenter) == true end,
				set = function(_, value) setGrowthFromCenter(value) end,
			},
			{
				name = L["ClassBuffReminderScale"] or "Scale",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.scale,
				minValue = 0.5,
				maxValue = 2,
				valueStep = 0.05,
				get = function() return clamp(getValue(DB_SCALE, defaults.scale), 0.5, 2, defaults.scale) end,
				set = function(_, value) setNumber(DB_SCALE, value, 0.5, 2, defaults.scale) end,
				formatter = function(value) return string.format("%.2f", tonumber(value) or defaults.scale) end,
			},
			{
				name = L["ClassBuffReminderIconSize"] or "Icon size",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.iconSize,
				minValue = 14,
				maxValue = 120,
				valueStep = 1,
				get = function() return clamp(getValue(DB_ICON_SIZE, defaults.iconSize), 14, 120, defaults.iconSize) end,
				set = function(_, value) setNumber(DB_ICON_SIZE, value, 14, 120, defaults.iconSize) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.iconSize) + 0.5)) end,
			},
			{
				name = L["ClassBuffReminderIconGap"] or "Icon gap",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.iconGap,
				minValue = 0,
				maxValue = 40,
				valueStep = 1,
				get = function() return clamp(getValue(DB_ICON_GAP, defaults.iconGap), 0, 40, defaults.iconGap) end,
				set = function(_, value) setNumber(DB_ICON_GAP, value, 0, 40, defaults.iconGap) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.iconGap) + 0.5)) end,
			},
			{
				name = L["ClassBuffReminderFontSize"] or "Font size",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.fontSize,
				minValue = 9,
				maxValue = 30,
				valueStep = 1,
				get = function() return clamp(getValue(DB_FONT_SIZE, defaults.fontSize), 9, 30, defaults.fontSize) end,
				set = function(_, value) setNumber(DB_FONT_SIZE, value, 9, 30, defaults.fontSize) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.fontSize) + 0.5)) end,
				isShown = function() return not isIconOnlyModeActive() end,
			},
			{
				name = L["ClassBuffReminderXYTextSize"] or "X/Y text size",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.xyTextSize,
				minValue = 8,
				maxValue = 64,
				valueStep = 1,
				get = function() return clamp(getValue(DB_XY_TEXT_SIZE, defaults.xyTextSize), 8, 64, defaults.xyTextSize) end,
				set = function(_, value) setNumber(DB_XY_TEXT_SIZE, value, 8, 64, defaults.xyTextSize) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.xyTextSize) + 0.5)) end,
				isShown = function() return isIconOnlyModeActive() end,
			},
			{
				name = L["ClassBuffReminderXYTextOutline"] or "X/Y text outline",
				kind = SettingType.Dropdown,
				parentId = "anchorSize",
				height = 120,
				get = function() return normalizeTextOutline(getValue(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline)) end,
				set = function(_, value) setTextOutline(value) end,
				generator = function(_, root)
					root:CreateRadio(
						L["ClassBuffReminderTextOutlineNone"] or "None",
						function() return normalizeTextOutline(getValue(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline)) == TEXT_OUTLINE_NONE end,
						function() setTextOutline(TEXT_OUTLINE_NONE) end
					)
					root:CreateRadio(
						L["ClassBuffReminderTextOutlineNormal"] or "Outline",
						function() return normalizeTextOutline(getValue(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline)) == TEXT_OUTLINE_OUTLINE end,
						function() setTextOutline(TEXT_OUTLINE_OUTLINE) end
					)
					root:CreateRadio(
						L["ClassBuffReminderTextOutlineThick"] or "Thick outline",
						function() return normalizeTextOutline(getValue(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline)) == TEXT_OUTLINE_THICK end,
						function() setTextOutline(TEXT_OUTLINE_THICK) end
					)
					root:CreateRadio(
						L["ClassBuffReminderTextOutlineMono"] or "Monochrome outline",
						function() return normalizeTextOutline(getValue(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline)) == TEXT_OUTLINE_MONO end,
						function() setTextOutline(TEXT_OUTLINE_MONO) end
					)
				end,
				isShown = function() return isIconOnlyModeActive() end,
			},
			{
				name = L["ClassBuffReminderXYTextColor"] or "X/Y text color",
				kind = SettingType.Color,
				parentId = "anchorSize",
				default = defaults.xyTextColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = normalizeColor(getValue(DB_XY_TEXT_COLOR, defaults.xyTextColor), defaults.xyTextColor)
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) setColor(DB_XY_TEXT_COLOR, value, defaults.xyTextColor) end,
				isShown = function() return isIconOnlyModeActive() end,
			},
			{
				name = L["ClassBuffReminderXYTextOffsetX"] or "X/Y offset X",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.xyTextOffsetX,
				minValue = -60,
				maxValue = 60,
				valueStep = 1,
				get = function() return clamp(getValue(DB_XY_TEXT_OFFSET_X, defaults.xyTextOffsetX), -60, 60, defaults.xyTextOffsetX) end,
				set = function(_, value) setNumber(DB_XY_TEXT_OFFSET_X, value, -60, 60, defaults.xyTextOffsetX) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.xyTextOffsetX) + 0.5)) end,
				isShown = function() return isIconOnlyModeActive() end,
			},
			{
				name = L["ClassBuffReminderXYTextOffsetY"] or "X/Y offset Y",
				kind = SettingType.Slider,
				parentId = "anchorSize",
				default = defaults.xyTextOffsetY,
				minValue = -60,
				maxValue = 60,
				valueStep = 1,
				get = function() return clamp(getValue(DB_XY_TEXT_OFFSET_Y, defaults.xyTextOffsetY), -60, 60, defaults.xyTextOffsetY) end,
				set = function(_, value) setNumber(DB_XY_TEXT_OFFSET_Y, value, -60, 60, defaults.xyTextOffsetY) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.xyTextOffsetY) + 0.5)) end,
				isShown = function() return isIconOnlyModeActive() end,
			},
		}
	end

	EditMode:RegisterFrame(EDITMODE_ID, {
		frame = self:EnsureFrame(),
		title = L["Class Buff Reminder"] or "Class Buff Reminder",
		layoutDefaults = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = 240,
		},
		onApply = function()
			Reminder:ApplyVisualSettings()
			Reminder:UpdateDisplay()
		end,
		onEnter = function()
			Reminder.editModeActive = true
			Reminder:UpdateDisplay()
		end,
		onExit = function()
			Reminder.editModeActive = false
			Reminder.missingActive = false
			Reminder:HideSamplePreview()
			Reminder:SetGlowShown(false)
			if Reminder.frame then
				if Reminder.frame.iconCountText then Reminder.frame.iconCountText:SetText("") end
				if Reminder.frame.countText then Reminder.frame.countText:SetText("") end
				Reminder.frame:Hide()
			end
			Reminder:RequestUpdate(true)
			if C_Timer and C_Timer.After then C_Timer.After(0, function() Reminder:RequestUpdate(true) end) end
		end,
		isEnabled = function() return addon.db and addon.db[DB_ENABLED] == true end,
		settings = settings,
		-- Runtime visibility is controlled by UpdateDisplay/Render.
		-- Keep this false so EditMode doesn't force-show the frame on login.
		showOutsideEditMode = false,
	})

	self.editModeRegistered = true
end

function Reminder:UnregisterEditMode()
	if not self.editModeRegistered then return end
	if not (EditMode and EditMode.UnregisterFrame) then return end
	EditMode:UnregisterFrame(EDITMODE_ID, false)
	self.editModeRegistered = false
end

function Reminder:OnSettingChanged()
	local enabled = getValue(DB_ENABLED, defaults.enabled) == true
	local runtimeActive = self:ShouldRegisterRuntimeEvents()
	if runtimeActive and not self.eventsRegistered then
		self.suppressNextMissingSound = true
		self:WriteSoundDebug("play-suppress-armed", {
			reason = "runtime-start",
		})
	end
	self:WriteSoundDebug("setting-changed", {
		enabled = enabled,
		runtime = runtimeActive,
	})
	if runtimeActive then
		self:NormalizeMissingSoundSelection("OnSettingChanged")
		self:ScheduleInitialSoundSync("OnSettingChanged")
	end

	if enabled then
		self:RegisterEditMode()
	else
		self:UnregisterEditMode()
	end
	self:ApplyVisualSettings()
	self:InvalidateProviderAvailabilityCache()
	self:InvalidateRosterCache()
	self:InvalidateFlaskCache()

	if runtimeActive then
		self:RegisterEvents()
	else
		self:UnregisterEvents()
		self.initialSoundSyncDone = false
	end

	self:RequestUpdate(true)

	if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
end
