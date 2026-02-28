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
local LSM = LibStub("LibSharedMedia-3.0", true)
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

local PROVIDER_BY_CLASS = {
	DRUID = {
		spellIds = { 1126 },
		fallbackName = "Mark of the Wild",
	},
	MAGE = {
		spellIds = { 1459 },
		fallbackName = "Arcane Intellect",
	},
	PRIEST = {
		spellIds = { 21562 },
		fallbackName = "Power Word: Fortitude",
	},
	WARRIOR = {
		spellIds = { 6673 },
		fallbackName = "Battle Shout",
	},
	EVOKER = {
		spellIds = {
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
		fallbackName = "Blessing of the Bronze",
	},
	SHAMAN = {
		spellIds = { 462854 },
		fallbackName = "Skyfury",
	},
}

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

local function isAIFollowerUnit(unit)
	if type(unit) ~= "string" or unit == "player" then return false end
	if not UnitInPartyIsAI then return false end
	local ok, isAI = pcall(UnitInPartyIsAI, unit)
	if not ok then return false end
	return isAI == true
end

local function safeGetSpellName(spellId)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellId)
		if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
	end
	if C_Spell and C_Spell.GetSpellName then
		local name = C_Spell.GetSpellName(spellId)
		if type(name) == "string" and name ~= "" then return name end
	end
	if GetSpellInfo then
		local name = GetSpellInfo(spellId)
		if type(name) == "string" and name ~= "" then return name end
	end
	return nil
end

local function requestSpellDataLoad(spellId)
	spellId = tonumber(spellId)
	if not spellId then return end
	if spellId <= 0 then return end
	if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, spellId) end
end

local function getSpellIconRaw(spellId)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellId)
		if type(info) == "table" and info.iconID then return info.iconID end
	end
	if GetSpellTexture then
		local icon = GetSpellTexture(spellId)
		if icon and icon ~= "" then return icon end
	end
	return nil
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

local function resolveProviderPresentation(provider)
	if not provider then return end

	local resolvedId
	local resolvedName
	local resolvedIcon

	for i = 1, #provider.spellIds do
		local sid = normalizeSpellId(provider.spellIds[i])
		if sid then
			requestSpellDataLoad(sid)
			resolvedId = resolvedId or sid
			local name = safeGetSpellName(sid)
			local icon = getSpellIconRaw(sid)
			if name and not resolvedName then resolvedName = name end
			if icon and not resolvedIcon then resolvedIcon = icon end
			if name and icon then
				resolvedId = sid
				resolvedName = name
				resolvedIcon = icon
				break
			end
		end
	end

	provider.displaySpellId = resolvedId or normalizeSpellId(provider.spellIds[1]) or provider.displaySpellId or provider.spellIds[1]
	provider.cachedName = resolvedName or provider.fallbackName or "Buff"
	provider.cachedIcon = resolvedIcon or ICON_MISSING
	provider._presentationReady = true
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

function Reminder:GetProvider()
	local classToken = self:GetClassToken()
	local provider = classToken and PROVIDER_BY_CLASS[classToken] or nil
	if not provider then return nil end

	if not provider.spellSet then
		provider.spellSet = {}
		for i = 1, #provider.spellIds do
			local sid = normalizeSpellId(provider.spellIds[i])
			if sid then provider.spellSet[sid] = true end
		end
	end
	if provider.spellNameSet == nil or provider.spellNameSetReady ~= true then refreshProviderSpellNameSet(provider) end
	if not provider.displaySpellId then provider.displaySpellId = normalizeSpellId(provider.spellIds[1]) or provider.spellIds[1] end
	if not provider._presentationReady or provider.cachedIcon == ICON_MISSING or not provider.cachedName or provider.cachedName == provider.fallbackName then resolveProviderPresentation(provider) end

	return provider
end

function Reminder:GetProviderName(provider)
	if not provider then return L["Class Buff Reminder"] or "Class Buff Reminder" end
	resolveProviderPresentation(provider)
	if provider.cachedName and provider.cachedName ~= "" then return provider.cachedName end
	local name = safeGetSpellName(provider.displaySpellId) or provider.fallbackName or (L["Class Buff Reminder"] or "Class Buff Reminder")
	provider.cachedName = name
	return name
end

function Reminder:GetProviderIcon(provider)
	if not provider then return ICON_MISSING end
	resolveProviderPresentation(provider)
	if provider.cachedIcon and provider.cachedIcon ~= "" and provider.cachedIcon ~= ICON_MISSING then return provider.cachedIcon end
	self:RequestProviderPresentationRefresh(provider)
	if provider.cachedIcon and provider.cachedIcon ~= "" then return provider.cachedIcon end
	local icon = safeGetSpellIcon(provider.displaySpellId)
	provider.cachedIcon = icon
	if icon == ICON_MISSING then self:RequestProviderPresentationRefresh(provider) end
	return icon
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
		resolveProviderPresentation(provider)
		if provider.cachedIcon and provider.cachedIcon ~= "" and provider.cachedIcon ~= ICON_MISSING then provider.presentationRetryCount = 0 end
		Reminder:RequestUpdate(true)
	end)
end

function Reminder:GetGrowthDirection() return normalizeGrowthDirection(getValue(DB_GROWTH_DIRECTION, defaults.growthDirection)) end

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
		local ok, stamp = pcall(date, "%H:%M:%S")
		if ok and type(stamp) == "string" and stamp ~= "" then return stamp end
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
	local keys = {}
	local map = {}
	local pathToKey = {}
	if LSM and LSM.HashTable then
		local hash = LSM:HashTable("sound") or {}
		for name, path in pairs(hash) do
			if type(name) == "string" and name ~= "" and type(path) == "string" and path ~= "" then
				keys[#keys + 1] = name
				map[name] = path
			end
		end
	end
	table.sort(keys, function(a, b)
		local al, bl = tostring(a):lower(), tostring(b):lower()
		if al == bl then return tostring(a) < tostring(b) end
		return al < bl
	end)
	for i = 1, #keys do
		local name = keys[i]
		local path = map[name]
		if type(path) == "string" and path ~= "" and pathToKey[path] == nil then pathToKey[path] = name end
	end
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

function Reminder:InvalidateAuraStates() self.unitAuraStates = {} end

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
	local state = self:GetUnitAuraState(unit)
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
		local slots
		if continuationToken ~= nil then
			slots = { C_UnitAuras.GetAuraSlots(unit, AURA_FILTER_HELPFUL, AURA_SLOT_BATCH_SIZE, continuationToken) }
		else
			slots = { C_UnitAuras.GetAuraSlots(unit, AURA_FILTER_HELPFUL, AURA_SLOT_BATCH_SIZE) }
		end

		local nextToken = slots and slots[1] or nil
		if issecretvalue and issecretvalue(nextToken) then nextToken = nil end

		for i = 2, (slots and #slots or 0) do
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
	local state = self:GetUnitAuraState(unit)
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

function Reminder:HasProvider() return self:GetProvider() ~= nil end

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

function Reminder:SetGlowShown(show)
	if not LBG then return end
	local target = self.frame and self.frame.iconHolder
	if not target then return end

	if show and not self.glowShown then
		LBG.ShowOverlayGlow(target)
		self.glowShown = true
	elseif not show and self.glowShown then
		LBG.HideOverlayGlow(target)
		self.glowShown = false
	end
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

		if i == 1 then
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

function Reminder:CollectUnits(target)
	if not target then target = {} end
	for i = #target, 1, -1 do
		target[i] = nil
	end

	if IsInRaid and IsInRaid() then
		local total = (GetNumGroupMembers and GetNumGroupMembers()) or 0
		for i = 1, total do
			target[#target + 1] = "raid" .. i
		end
	elseif IsInGroup and IsInGroup() then
		target[#target + 1] = "player"
		local total = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or math.max(0, ((GetNumGroupMembers and GetNumGroupMembers()) or 1) - 1)
		for i = 1, total do
			target[#target + 1] = "party" .. i
		end
	else
		target[#target + 1] = "player"
	end

	return target
end

function Reminder:UnitHasProviderBuff(unit, provider)
	if not (unit and provider and provider.spellSet) then return false end
	local state = self:GetUnitAuraState(unit)
	if not state then return false end
	if not state.initialized then state = self:FullRefreshUnitAuraState(unit, provider) end
	return state and state.hasBuff == true
end

function Reminder:ComputeMissing(provider)
	self.runtimeUnits = self.runtimeUnits or {}
	local units = self:CollectUnits(self.runtimeUnits)

	local total = 0
	local missing = 0
	for i = 1, #units do
		local unit = units[i]
		if isAIFollowerUnit(unit) then
			local state = self:GetUnitAuraState(unit)
			if state then self:ResetUnitAuraState(state) end
		elseif UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
			total = total + 1
			if not self:UnitHasProviderBuff(unit, provider) then missing = missing + 1 end
		end
	end

	return missing, total
end

function Reminder:IsGroupModeAllowed()
	if IsInRaid and IsInRaid() then return getValue(DB_SHOW_RAID, defaults.showRaid) == true end
	if IsInGroup and IsInGroup() then return getValue(DB_SHOW_PARTY, defaults.showParty) == true end
	return getValue(DB_SHOW_SOLO, defaults.showSolo) == true
end

function Reminder:ShouldRegisterRuntimeEvents()
	if getValue(DB_ENABLED, defaults.enabled) ~= true then return false end
	if not self:HasProvider() then return false end
	return true
end

function Reminder:Render(provider, missing, total)
	local frame = self:EnsureFrame()
	if not frame then return end

	local displayMode = normalizeDisplayMode(getValue(DB_DISPLAY_MODE, defaults.displayMode))
	local title = self:GetProviderName(provider)
	if displayMode == DISPLAY_MODE_ICON_ONLY then
		local shortFmt = L["ClassBuffReminderCountOnlyFmt"] or "%d/%d"
		if frame.iconCountText then frame.iconCountText:SetText(string.format(shortFmt, missing, total)) end
	else
		local missingText = L["ClassBuffReminderMissingFmt"] or "%d/%d missing"
		frame.nameText:SetText(title)
		frame.countText:SetText(string.format(missingText, missing, total))
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
	if displayMode ~= DISPLAY_MODE_ICON_ONLY then
		if missing > 0 then
			if frame.countText then frame.countText:SetTextColor(1, 0.25, 0.25, 1) end
		else
			if frame.countText then frame.countText:SetTextColor(0.35, 1, 0.35, 1) end
		end
	end
	frame:Show()

	local showGlow = getValue(DB_GLOW, defaults.glow) == true and missing > 0
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

	if getValue(DB_ENABLED, defaults.enabled) ~= true then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	local provider = self:GetProvider()
	if not provider then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	if not self:IsGroupModeAllowed() then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	local missing, total = self:ComputeMissing(provider)
	if total <= 0 then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	if self.suppressNextMissingSound == true and missing <= 0 then
		self.suppressNextMissingSound = false
		self:WriteSoundDebug("play-suppress-cleared", {
			reason = "no-missing-on-initial-check",
			total = tonumber(total) or 0,
		})
	end

	if missing <= 0 then
		self:SetGlowShown(false)
		self.missingActive = false
		frame:Hide()
		return
	end

	self:UpdateMissingStateAndSound(missing)

	self:Render(provider, missing, total)
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

	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then self:ScheduleInitialSoundSync(event) end

	if event == "UNIT_AURA" then
		if not isTrackedUnit(unit) then return end
		if isAIFollowerUnit(unit) then
			local state = self:GetUnitAuraState(unit)
			if state then self:ResetUnitAuraState(state) end
			return
		end
		local provider = self:GetProvider()
		if provider then
			self:ApplyDeltaToUnitAuraState(unit, updateInfo, provider)
		else
			local state = self:GetUnitAuraState(unit)
			if state then self:ResetUnitAuraState(state) end
		end
		self:RequestUpdate(false)
		return
	end

	self:InvalidateAuraStates()
	self:RequestUpdate(true)
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
	self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
	self.eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	self.eventFrame:RegisterEvent("UNIT_AURA")
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
				name = L["ClassBuffReminderShowParty"] or "Track in party",
				kind = SettingType.Checkbox,
				default = defaults.showParty,
				get = function() return getValue(DB_SHOW_PARTY, defaults.showParty) == true end,
				set = function(_, value) setBool(DB_SHOW_PARTY, value) end,
			},
			{
				name = L["ClassBuffReminderShowRaid"] or "Track in raid",
				kind = SettingType.Checkbox,
				default = defaults.showRaid,
				get = function() return getValue(DB_SHOW_RAID, defaults.showRaid) == true end,
				set = function(_, value) setBool(DB_SHOW_RAID, value) end,
			},
			{
				name = L["ClassBuffReminderShowSolo"] or "Show while solo",
				kind = SettingType.Checkbox,
				default = defaults.showSolo,
				get = function() return getValue(DB_SHOW_SOLO, defaults.showSolo) == true end,
				set = function(_, value) setBool(DB_SHOW_SOLO, value) end,
			},
			{
				name = L["ClassBuffReminderGlow"] or "Glow when missing",
				kind = SettingType.Checkbox,
				default = defaults.glow,
				get = function() return getValue(DB_GLOW, defaults.glow) == true end,
				set = function(_, value) setBool(DB_GLOW, value) end,
			},
			{
				name = L["ClassBuffReminderSoundOnMissing"] or "Play sound when missing",
				kind = SettingType.Checkbox,
				default = defaults.soundOnMissing,
				get = function() return getValue(DB_SOUND_ON_MISSING, defaults.soundOnMissing) == true end,
				set = function(_, value) setBool(DB_SOUND_ON_MISSING, value) end,
			},
			{
				name = L["ClassBuffReminderMissingSound"] or "Missing sound",
				kind = SettingType.Dropdown,
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
				name = L["ClassBuffReminderDisplayMode"] or "Display mode",
				kind = SettingType.Dropdown,
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
				name = L["ClassBuffReminderScale"] or "Scale",
				kind = SettingType.Slider,
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
	self:InvalidateAuraStates()

	if runtimeActive then
		self:RegisterEvents()
	else
		self:UnregisterEvents()
		self.initialSoundSyncDone = false
	end

	self:RequestUpdate(true)

	if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
end
