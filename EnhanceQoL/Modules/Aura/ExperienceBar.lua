local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.ExperienceBar = addon.Aura.ExperienceBar or {}
local ExperienceBar = addon.Aura.ExperienceBar

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType
local LSM = LibStub("LibSharedMedia-3.0", true)

local EDITMODE_ID = "xpBar"
local ANCHOR_TARGET_UI = "UIParent"
local ANCHOR_TARGET_PLAYER_CASTBAR = "PLAYER_CASTBAR"
local EQOL_PLAYER_CASTBAR = "EQOLUFPlayerHealthCast"
local ANCHOR_POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local VALID_ANCHOR_POINTS = {}
for _, point in ipairs(ANCHOR_POINTS) do
	VALID_ANCHOR_POINTS[point] = true
end

ExperienceBar.defaults = ExperienceBar.defaults
	or {
		width = 260,
		height = 16,
		texture = "DEFAULT",
		color = { r = 0.20, g = 0.65, b = 0.95, a = 1 }, -- no rested bonus active
		restedColor = { r = 0.20, g = 0.85, b = 1.00, a = 1 }, -- rested bonus active
		restedOverlayEnabled = true,
		bgEnabled = true,
		bgTexture = "SOLID",
		bgColor = { r = 0, g = 0, b = 0, a = 0.45 },
		borderEnabled = false,
		borderTexture = "DEFAULT",
		borderColor = { r = 0, g = 0, b = 0, a = 0.85 },
		borderSize = 1,
		borderOffset = 0,
		fillDirection = "LEFT",
		anchorRelativeFrame = ANCHOR_TARGET_UI,
		anchorMatchRelativeWidth = false,
		anchorPoint = "CENTER",
		anchorRelativePoint = "CENTER",
		anchorOffsetX = 0,
		anchorOffsetY = -170,
		textEnabled = true,
		textMode = "CURMAXPERCENT", -- legacy fallback for center
		textLeftMode = "LEVEL",
		textCenterMode = "CURMAXPERCENT",
		textRightMode = "PERCENT_RESTED",
		textSize = 11,
		textFont = "DEFAULT",
		textOutline = "OUTLINE",
		textColor = { r = 1, g = 1, b = 1, a = 1 },
		hideInPetBattle = false,
		hideBlizzardTracking = true,
	}

local defaults = ExperienceBar.defaults

local DB_ENABLED = "xpBarEnabled"
local DB_WIDTH = "xpBarWidth"
local DB_HEIGHT = "xpBarHeight"
local DB_TEXTURE = "xpBarTexture"
local DB_COLOR = "xpBarColor"
local DB_RESTED_COLOR = "xpBarRestedColor"
local DB_RESTED_OVERLAY_ENABLED = "xpBarRestedOverlay"
local DB_BG_ENABLED = "xpBarBackgroundEnabled"
local DB_BG_TEXTURE = "xpBarBackgroundTexture"
local DB_BG_COLOR = "xpBarBackgroundColor"
local DB_BORDER_ENABLED = "xpBarBorderEnabled"
local DB_BORDER_TEXTURE = "xpBarBorderTexture"
local DB_BORDER_COLOR = "xpBarBorderColor"
local DB_BORDER_SIZE = "xpBarBorderSize"
local DB_BORDER_OFFSET = "xpBarBorderOffset"
local DB_FILL_DIRECTION = "xpBarFillDirection"
local DB_ANCHOR_RELATIVE_FRAME = "xpBarAnchorTarget"
local DB_ANCHOR_MATCH_WIDTH = "xpBarAnchorMatchWidth"
local DB_ANCHOR_POINT = "xpBarAnchorPoint"
local DB_ANCHOR_RELATIVE_POINT = "xpBarAnchorRelativePoint"
local DB_ANCHOR_OFFSET_X = "xpBarAnchorOffsetX"
local DB_ANCHOR_OFFSET_Y = "xpBarAnchorOffsetY"
local DB_TEXT_ENABLED = "xpBarShowText"
local DB_TEXT_MODE = "xpBarTextMode" -- legacy fallback
local DB_TEXT_LEFT_MODE = "xpBarTextLeftMode"
local DB_TEXT_CENTER_MODE = "xpBarTextCenterMode"
local DB_TEXT_RIGHT_MODE = "xpBarTextRightMode"
local DB_TEXT_SIZE = "xpBarTextSize"
local DB_TEXT_FONT = "xpBarTextFont"
local DB_TEXT_OUTLINE = "xpBarTextOutline"
local DB_TEXT_COLOR = "xpBarTextColor"
local DB_HIDE_IN_PET_BATTLE = "xpBarHideInPetBattle"
local DB_HIDE_BLIZZARD_TRACKING = "xpBarHideBlizzardTracking"

local DEFAULT_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local BAR_SIZE_MIN = 6
local BAR_SIZE_MAX = 2000
local BAR_WIDTH_MAX = 5000
local TEXT_SIZE_MIN = 8
local TEXT_SIZE_MAX = 30

local BLIZZARD_TRACKING_FRAMES = {
	"MainStatusTrackingBarContainer",
	"SecondaryStatusTrackingBarContainer",
	"StatusTrackingBarManager",
}

local function getValue(key, fallback)
	if not addon.db then return fallback end
	local value = addon.db[key]
	if value == nil then return fallback end
	return value
end

local function shouldHideInPetBattleForXP() return getValue(DB_HIDE_IN_PET_BATTLE, defaults.hideInPetBattle) == true end

local function isPetBattleActive() return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() == true end

local function clamp(value, minValue, maxValue)
	value = tonumber(value) or minValue
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function normalizeColor(value, fallback)
	if type(value) == "table" then
		local r = value.r or value[1] or 1
		local g = value.g or value[2] or 1
		local b = value.b or value[3] or 1
		local a = value.a or value[4]
		return r, g, b, a
	elseif type(value) == "number" then
		return value, value, value
	end
	local d = fallback or defaults.color or {}
	return d.r or 1, d.g or 1, d.b or 1, d.a
end

local function isLikelyFilePath(value)
	if type(value) ~= "string" or value == "" then return false end
	return string.find(value, "[/\\]") ~= nil
end

local function resolveTexture(key)
	if key == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if not key or key == "" or key == "DEFAULT" then return DEFAULT_TEX end
	if LSM and LSM.Fetch then
		local tex = LSM:Fetch("statusbar", key, true)
		if tex then return tex end
	end
	if isLikelyFilePath(key) then return key end
	return DEFAULT_TEX
end

local function resolveBorderTexture(key)
	if key == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if not key or key == "" or key == "DEFAULT" then return "Interface\\Buttons\\WHITE8x8" end
	if LSM and LSM.Fetch then
		local tex = LSM:Fetch("border", key, true)
		if tex then return tex end
	end
	if isLikelyFilePath(key) then return key end
	return "Interface\\Buttons\\WHITE8x8"
end

local function textureOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local lv = tostring(value or ""):lower()
		if lv == "" or seen[lv] then return end
		seen[lv] = true
		list[#list + 1] = { value = value, label = label }
	end

	add("DEFAULT", _G.DEFAULT)
	add("SOLID", "Solid")

	if LSM and LSM.HashTable then
		for name, path in pairs(LSM:HashTable("statusbar") or {}) do
			if type(path) == "string" and path ~= "" then add(name, tostring(name)) end
		end
	end

	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return list
end

local function borderOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local lv = tostring(value or ""):lower()
		if lv == "" or seen[lv] then return end
		seen[lv] = true
		list[#list + 1] = { value = value, label = label }
	end

	add("DEFAULT", _G.DEFAULT)
	add("SOLID", "Solid")

	if LSM and LSM.HashTable then
		for name, path in pairs(LSM:HashTable("border") or {}) do
			if type(path) == "string" and path ~= "" then add(name, tostring(name)) end
		end
	end

	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return list
end

local function fontOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local lv = tostring(value or ""):lower()
		if lv == "" or seen[lv] then return end
		seen[lv] = true
		list[#list + 1] = { value = value, label = label }
	end

	add("DEFAULT", _G.DEFAULT)
	if LSM and LSM.HashTable then
		for name, path in pairs(LSM:HashTable("font") or {}) do
			if type(path) == "string" and path ~= "" then add(name, tostring(name)) end
		end
	end

	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return list
end

local function resolveFontPath(key)
	local defaultFont = (addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT
	if not key or key == "" or key == "DEFAULT" then return defaultFont end
	if LSM and LSM.Fetch then
		local font = LSM:Fetch("font", key, true)
		if font then return font end
	end
	if isLikelyFilePath(key) then return key end
	return defaultFont
end

local function normalizeTextOutline(value)
	if value == "OUTLINE" then return "OUTLINE" end
	if value == "THICKOUTLINE" then return "THICKOUTLINE" end
	if value == "MONOCHROME" then return "MONOCHROME" end
	return "NONE"
end

local function normalizeFillDirection(value)
	if type(value) == "string" then value = string.upper(value) end
	if value == "RIGHT" then return "RIGHT" end
	if value == "UP" or value == "BOTTOM" then return "UP" end
	if value == "DOWN" or value == "TOP" then return "DOWN" end
	return "LEFT"
end

local function isVerticalFillDirection(value) return value == "UP" or value == "DOWN" end

local function isReverseFillDirection(value) return value == "RIGHT" or value == "DOWN" end

local function normalizeAnchorPoint(value, fallback)
	if value and VALID_ANCHOR_POINTS[value] then return value end
	if fallback and VALID_ANCHOR_POINTS[fallback] then return fallback end
	return "CENTER"
end

local function normalizeAnchorRelativeFrame(value)
	if value == ANCHOR_TARGET_PLAYER_CASTBAR or value == "PlayerCastingBarFrame" or value == EQOL_PLAYER_CASTBAR then return ANCHOR_TARGET_PLAYER_CASTBAR end
	if type(value) == "string" and value ~= "" then return value end
	return ANCHOR_TARGET_UI
end

local function normalizeAnchorOffset(value, fallback)
	local num = tonumber(value)
	if num == nil then num = fallback end
	if num == nil then num = 0 end
	return clamp(num, -1000, 1000)
end

local function normalizeLegacyTextMode(value)
	if value == "CURMAX" then return "CURMAX" end
	if value == "CURMAXPERCENT" then return "CURMAXPERCENT" end
	return "PERCENT"
end

local function normalizeTextContentMode(value)
	if value == "NONE" then return "NONE" end
	if value == "LEVEL" then return "LEVEL" end
	if value == "CURMAX" then return "CURMAX" end
	if value == "PERCENT" then return "PERCENT" end
	if value == "CURMAXPERCENT" then return "CURMAXPERCENT" end
	if value == "RESTED" then return "RESTED" end
	if value == "RESTEDPERCENT" then return "RESTEDPERCENT" end
	if value == "PERCENT_RESTED" then return "PERCENT_RESTED" end
	if value == "CURMAX_RESTED" then return "CURMAX_RESTED" end
	return "NONE"
end

local function textModeOptions()
	return {
		{ value = "NONE", label = L["xpBarTextTypeNone"] or "None" },
		{ value = "LEVEL", label = L["xpBarTextTypeLevel"] or "Level" },
		{ value = "CURMAX", label = L["xpBarTextTypeCurMax"] or "Current / Max" },
		{ value = "PERCENT", label = L["xpBarTextTypePercent"] or "Percent" },
		{ value = "CURMAXPERCENT", label = L["xpBarTextTypeCurMaxPercent"] or "Current / Max (percent)" },
		{ value = "RESTED", label = L["xpBarTextTypeRested"] or "Rested XP" },
		{ value = "RESTEDPERCENT", label = L["xpBarTextTypeRestedPercent"] or "Rested %" },
		{ value = "PERCENT_RESTED", label = L["xpBarTextTypePercentRested"] or "Percent (+rested)" },
		{ value = "CURMAX_RESTED", label = L["xpBarTextTypeCurMaxRested"] or "Current / Max (+rested)" },
	}
end

local function refreshSettingsUI()
	local lib = addon.EditModeLib
	if not (lib and lib.internal) then return end
	if lib.internal.RefreshSettings then lib.internal:RefreshSettings() end
	if lib.internal.RefreshSettingValues then lib.internal:RefreshSettingValues() end
end

local function isCustomPlayerCastbarEnabled()
	local cfg = addon.db and addon.db.ufFrames and addon.db.ufFrames.player
	if not (cfg and cfg.enabled == true) then return false end
	local castCfg = cfg.cast
	if not castCfg then
		local uf = addon.Aura and addon.Aura.UF
		local ufDefaults = uf and uf.defaults and uf.defaults.player
		castCfg = ufDefaults and ufDefaults.cast
	end
	if not castCfg then return false end
	return castCfg.enabled ~= false
end

local function resolvePlayerCastbarFrame()
	local wantsCustom = isCustomPlayerCastbarEnabled()
	if wantsCustom then
		local custom = _G and _G[EQOL_PLAYER_CASTBAR]
		if custom then return custom, true, true end
	end
	local blizz = _G and _G.PlayerCastingBarFrame
	if blizz then return blizz, false, wantsCustom end
	return UIParent, false, wantsCustom
end

local function normalizeXPValue(value)
	local n = tonumber(value) or 0
	if n < 0 then return 0 end
	return n
end

local function getPlayerLevel()
	local level = UnitLevel and UnitLevel("player") or 0
	if issecretvalue and issecretvalue(level) then return 0 end
	return math.max(0, tonumber(level) or 0)
end

local function getXPValues()
	local current = UnitXP and UnitXP("player") or 0
	local maximum = UnitXPMax and UnitXPMax("player") or 0
	if issecretvalue and (issecretvalue(current) or issecretvalue(maximum)) then return 0, 0 end
	return normalizeXPValue(current), normalizeXPValue(maximum)
end

local function getRestedXP()
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	if rested == nil then rested = 0 end
	if issecretvalue and issecretvalue(rested) then rested = 0 end
	return normalizeXPValue(rested)
end

local function formatNumber(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
	return tostring(value)
end

local function buildXPContext(level, current, maximum, rested)
	local maxXP = normalizeXPValue(maximum)
	local curXP = normalizeXPValue(current)
	if maxXP > 0 and curXP > maxXP then curXP = maxXP end
	local remaining = maxXP > curXP and (maxXP - curXP) or 0
	local restedEffective = math.min(normalizeXPValue(rested), remaining)
	local currentPercent = 0
	local withRestPercent = 0
	local restedPercent = 0
	if maxXP > 0 then
		currentPercent = (curXP / maxXP) * 100
		withRestPercent = (math.min(maxXP, curXP + restedEffective) / maxXP) * 100
		restedPercent = withRestPercent - currentPercent
		if restedPercent < 0 then restedPercent = 0 end
	end
	return {
		level = math.max(0, tonumber(level) or 0),
		current = curXP,
		max = maxXP,
		rested = restedEffective,
		remaining = remaining,
		currentPercent = currentPercent,
		restedPercent = restedPercent,
		withRestPercent = withRestPercent,
	}
end

local function formatXPText(mode, ctx)
	if not ctx then return nil end
	if mode == "NONE" then return nil end
	if mode == "LEVEL" then return (L["xpBarTextLevelFmt"] or "Level %d"):format(ctx.level or 0) end
	if mode == "CURMAX" then return formatNumber(ctx.current) .. " / " .. formatNumber(ctx.max) end
	if mode == "PERCENT" then return string.format("%.1f%%", ctx.currentPercent or 0) end
	if mode == "CURMAXPERCENT" then return string.format("%s / %s (%.1f%%)", formatNumber(ctx.current), formatNumber(ctx.max), ctx.currentPercent or 0) end
	if mode == "RESTED" then return string.format("+%s", formatNumber(ctx.rested or 0)) end
	if mode == "RESTEDPERCENT" then return string.format("%.1f%%", ctx.restedPercent or 0) end
	if mode == "PERCENT_RESTED" then return string.format("%.1f%% (+%.1f%%)", ctx.currentPercent or 0, ctx.restedPercent or 0) end
	if mode == "CURMAX_RESTED" then return string.format("%s / %s (+%s)", formatNumber(ctx.current), formatNumber(ctx.max), formatNumber(ctx.rested or 0)) end
	return nil
end

function ExperienceBar:IsEnabled() return addon.db and addon.db[DB_ENABLED] == true end

function ExperienceBar:GetWidth() return clamp(getValue(DB_WIDTH, defaults.width), BAR_SIZE_MIN, BAR_WIDTH_MAX) end

function ExperienceBar:GetHeight() return clamp(getValue(DB_HEIGHT, defaults.height), BAR_SIZE_MIN, BAR_SIZE_MAX) end

function ExperienceBar:GetTextureKey()
	local key = getValue(DB_TEXTURE, defaults.texture)
	if not key or key == "" then key = defaults.texture end
	return key
end

function ExperienceBar:GetColor() return normalizeColor(getValue(DB_COLOR, defaults.color), defaults.color) end

function ExperienceBar:GetRestedColor() return normalizeColor(getValue(DB_RESTED_COLOR, defaults.restedColor), defaults.restedColor) end

function ExperienceBar:GetRestedOverlayEnabled() return getValue(DB_RESTED_OVERLAY_ENABLED, defaults.restedOverlayEnabled ~= false) == true end

function ExperienceBar:GetBackgroundEnabled() return getValue(DB_BG_ENABLED, defaults.bgEnabled) == true end

function ExperienceBar:GetBackgroundTextureKey()
	local key = getValue(DB_BG_TEXTURE, defaults.bgTexture)
	if not key or key == "" then key = defaults.bgTexture end
	return key
end

function ExperienceBar:GetBackgroundColor() return normalizeColor(getValue(DB_BG_COLOR, defaults.bgColor), defaults.bgColor) end

function ExperienceBar:GetBorderEnabled() return getValue(DB_BORDER_ENABLED, defaults.borderEnabled) == true end

function ExperienceBar:GetBorderTextureKey()
	local key = getValue(DB_BORDER_TEXTURE, defaults.borderTexture)
	if not key or key == "" then key = defaults.borderTexture end
	return key
end

function ExperienceBar:GetBorderColor() return normalizeColor(getValue(DB_BORDER_COLOR, defaults.borderColor), defaults.borderColor) end

function ExperienceBar:GetBorderSize() return clamp(getValue(DB_BORDER_SIZE, defaults.borderSize), 1, 20) end

function ExperienceBar:GetBorderOffset() return clamp(getValue(DB_BORDER_OFFSET, defaults.borderOffset), -20, 20) end

function ExperienceBar:GetFillDirection() return normalizeFillDirection(getValue(DB_FILL_DIRECTION, defaults.fillDirection)) end

function ExperienceBar:GetAnchorRelativeFrame()
	local target = getValue(DB_ANCHOR_RELATIVE_FRAME, defaults.anchorRelativeFrame or ANCHOR_TARGET_UI)
	return normalizeAnchorRelativeFrame(target)
end

function ExperienceBar:GetAnchorMatchWidth() return getValue(DB_ANCHOR_MATCH_WIDTH, defaults.anchorMatchRelativeWidth == true) == true end

function ExperienceBar:GetAnchorPoint() return normalizeAnchorPoint(getValue(DB_ANCHOR_POINT, defaults.anchorPoint), defaults.anchorPoint) end

function ExperienceBar:GetAnchorRelativePoint()
	local point = normalizeAnchorPoint(getValue(DB_ANCHOR_RELATIVE_POINT, defaults.anchorRelativePoint), self:GetAnchorPoint())
	return point
end

function ExperienceBar:GetAnchorOffsetX() return normalizeAnchorOffset(getValue(DB_ANCHOR_OFFSET_X, defaults.anchorOffsetX), defaults.anchorOffsetX) end

function ExperienceBar:GetAnchorOffsetY() return normalizeAnchorOffset(getValue(DB_ANCHOR_OFFSET_Y, defaults.anchorOffsetY), defaults.anchorOffsetY) end

function ExperienceBar:GetTextEnabled() return getValue(DB_TEXT_ENABLED, defaults.textEnabled) == true end

function ExperienceBar:GetTextSize() return clamp(getValue(DB_TEXT_SIZE, defaults.textSize), TEXT_SIZE_MIN, TEXT_SIZE_MAX) end

function ExperienceBar:GetTextFont()
	local key = getValue(DB_TEXT_FONT, defaults.textFont)
	if not key or key == "" then key = defaults.textFont or "DEFAULT" end
	return key
end

function ExperienceBar:GetTextOutline() return normalizeTextOutline(getValue(DB_TEXT_OUTLINE, defaults.textOutline)) end

function ExperienceBar:GetTextColor() return normalizeColor(getValue(DB_TEXT_COLOR, defaults.textColor), defaults.textColor) end

function ExperienceBar:GetTextLeftMode() return normalizeTextContentMode(getValue(DB_TEXT_LEFT_MODE, defaults.textLeftMode or "LEVEL")) end

function ExperienceBar:GetTextCenterMode()
	local value = getValue(DB_TEXT_CENTER_MODE, nil)
	if value == nil then value = getValue(DB_TEXT_MODE, defaults.textCenterMode or defaults.textMode or "CURMAXPERCENT") end
	return normalizeTextContentMode(value)
end

function ExperienceBar:GetTextRightMode() return normalizeTextContentMode(getValue(DB_TEXT_RIGHT_MODE, defaults.textRightMode or "PERCENT_RESTED")) end

function ExperienceBar:GetHideInPetBattle() return shouldHideInPetBattleForXP() end

function ExperienceBar:GetHideBlizzardTracking() return getValue(DB_HIDE_BLIZZARD_TRACKING, defaults.hideBlizzardTracking) == true end

function ExperienceBar:AnchorUsesUIParent() return self:GetAnchorRelativeFrame() == ANCHOR_TARGET_UI end

function ExperienceBar:AnchorUsesMatchedWidth() return self:GetAnchorMatchWidth() and not self:AnchorUsesUIParent() end

local function anchorDefaultsFor(target)
	if target == ANCHOR_TARGET_UI then
		local point = defaults.anchorPoint or "CENTER"
		local relPoint = defaults.anchorRelativePoint or point
		return point, relPoint, defaults.anchorOffsetX or 0, defaults.anchorOffsetY or 0
	end
	return "TOPLEFT", "BOTTOMLEFT", 0, -2
end

function ExperienceBar:ResolveAnchorFrame()
	local target = self:GetAnchorRelativeFrame()
	self._anchorUsingCustom = nil
	self._anchorWantsCustom = nil

	if target == ANCHOR_TARGET_UI then return UIParent end

	if target == ANCHOR_TARGET_PLAYER_CASTBAR then
		local frame, usingCustom, wantsCustom = resolvePlayerCastbarFrame()
		self._anchorUsingCustom = usingCustom
		self._anchorWantsCustom = wantsCustom
		if wantsCustom and not usingCustom then self:ScheduleAnchorRefresh(target) end
		return frame or UIParent
	end

	local frame = _G and _G[target]
	if frame then return frame end
	self:ScheduleAnchorRefresh(target)
	return UIParent
end

function ExperienceBar:ScheduleAnchorRefresh(target)
	if not (C_Timer and C_Timer.NewTicker) then return end
	local desired = normalizeAnchorRelativeFrame(target or self:GetAnchorRelativeFrame())
	if desired == ANCHOR_TARGET_UI then return end

	if self._anchorRefreshTicker then
		if self._anchorRefreshTarget == desired then return end
		self._anchorRefreshTicker:Cancel()
		self._anchorRefreshTicker = nil
	end

	self._anchorRefreshTarget = desired
	local tries = 0
	self._anchorRefreshTicker = C_Timer.NewTicker(0.2, function()
		tries = tries + 1
		if self:GetAnchorRelativeFrame() ~= desired then
			if self._anchorRefreshTicker then self._anchorRefreshTicker:Cancel() end
			self._anchorRefreshTicker = nil
			self._anchorRefreshTarget = nil
			return
		end

		if desired == ANCHOR_TARGET_PLAYER_CASTBAR then
			local frame, usingCustom, wantsCustom = resolvePlayerCastbarFrame()
			if frame and (not wantsCustom or usingCustom) then
				if self._anchorRefreshTicker then self._anchorRefreshTicker:Cancel() end
				self._anchorRefreshTicker = nil
				self._anchorRefreshTarget = nil
				self:RefreshAnchor()
				return
			end
		elseif _G and _G[desired] then
			if self._anchorRefreshTicker then self._anchorRefreshTicker:Cancel() end
			self._anchorRefreshTicker = nil
			self._anchorRefreshTarget = nil
			self:RefreshAnchor()
			return
		end

		if tries >= 25 then
			if self._anchorRefreshTicker then self._anchorRefreshTicker:Cancel() end
			self._anchorRefreshTicker = nil
			self._anchorRefreshTarget = nil
		end
	end)
end

function ExperienceBar:RefreshAnchor()
	if self._refreshingAnchor then return end
	local target = self:GetAnchorRelativeFrame()
	if self._anchorRefreshTicker and (target == ANCHOR_TARGET_UI or self._anchorRefreshTarget ~= target) then
		self._anchorRefreshTicker:Cancel()
		self._anchorRefreshTicker = nil
		self._anchorRefreshTarget = nil
	end
	self._refreshingAnchor = true
	if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
	self._refreshingAnchor = nil
	if target == ANCHOR_TARGET_PLAYER_CASTBAR then
		if isCustomPlayerCastbarEnabled() and not (_G and _G[EQOL_PLAYER_CASTBAR]) then self:ScheduleAnchorRefresh(target) end
	elseif target ~= ANCHOR_TARGET_UI then
		if not (_G and _G[target]) then self:ScheduleAnchorRefresh(target) end
	end
end

function ExperienceBar:MaybeUpdateAnchor()
	local target = self:GetAnchorRelativeFrame()
	if target == ANCHOR_TARGET_PLAYER_CASTBAR then
		if isCustomPlayerCastbarEnabled() then
			if _G and _G[EQOL_PLAYER_CASTBAR] and not self._anchorUsingCustom then
				self:RefreshAnchor()
			elseif not (_G and _G[EQOL_PLAYER_CASTBAR]) then
				self:ScheduleAnchorRefresh(target)
			end
		elseif self._anchorUsingCustom then
			self:RefreshAnchor()
		end
	elseif target ~= ANCHOR_TARGET_UI then
		if not (_G and _G[target]) then self:ScheduleAnchorRefresh(target) end
	end
end

local widthMatchHookedFrames = {}
local pendingWidthHookRetries = {}
local widthSyncQueued = false

function ExperienceBar:ScheduleMatchedWidthSync()
	if widthSyncQueued then return end
	if not (C_Timer and C_Timer.After) then
		self:ApplySize()
		return
	end
	widthSyncQueued = true
	C_Timer.After(0, function()
		widthSyncQueued = false
		if not (addon and addon.db and addon.db[DB_ENABLED] == true) then return end
		ExperienceBar:ApplySize()
		if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
	end)
end

function ExperienceBar:EnsureWidthSyncHook(frameName)
	if not frameName or frameName == "" or frameName == ANCHOR_TARGET_UI or frameName == "EQOL_XPBar" then return end
	if widthMatchHookedFrames[frameName] then return end
	local frame = _G and _G[frameName]
	if not frame then
		if C_Timer and C_Timer.After and not pendingWidthHookRetries[frameName] then
			pendingWidthHookRetries[frameName] = true
			C_Timer.After(1, function()
				pendingWidthHookRetries[frameName] = nil
				if ExperienceBar and ExperienceBar.EnsureWidthSyncHook then ExperienceBar:EnsureWidthSyncHook(frameName) end
			end)
		end
		return
	end

	if frame.HookScript then
		local function onGeometryChanged()
			if ExperienceBar and ExperienceBar.AnchorUsesMatchedWidth and ExperienceBar:AnchorUsesMatchedWidth() then ExperienceBar:ScheduleMatchedWidthSync() end
		end
		local okSize = pcall(frame.HookScript, frame, "OnSizeChanged", onGeometryChanged)
		local okShow = pcall(frame.HookScript, frame, "OnShow", onGeometryChanged)
		local okHide = pcall(frame.HookScript, frame, "OnHide", onGeometryChanged)
		if okSize or okShow or okHide then widthMatchHookedFrames[frameName] = true end
	end
end

function ExperienceBar:EnsureWidthSyncHooks()
	if not self:AnchorUsesMatchedWidth() then return end
	local target = self:GetAnchorRelativeFrame()
	if target == ANCHOR_TARGET_PLAYER_CASTBAR then
		self:EnsureWidthSyncHook("PlayerCastingBarFrame")
		self:EnsureWidthSyncHook(EQOL_PLAYER_CASTBAR)
	elseif target ~= ANCHOR_TARGET_UI then
		self:EnsureWidthSyncHook(target)
	end
end

function ExperienceBar:GetResolvedWidth()
	local width = self:GetWidth()
	if not self:AnchorUsesMatchedWidth() then return width end
	local relativeFrame = self:ResolveAnchorFrame()
	if not (relativeFrame and relativeFrame.GetWidth) then return width end
	local relativeWidth = tonumber(relativeFrame:GetWidth()) or 0
	if relativeWidth <= 0 then return width end
	return math.max(BAR_SIZE_MIN, relativeWidth)
end

function ExperienceBar:ApplyCurrentFillColor(hasRested)
	if not self.frame then return end
	local r, g, b, a
	if self:GetRestedOverlayEnabled() then
		r, g, b, a = self:GetColor()
	elseif hasRested then
		r, g, b, a = self:GetRestedColor()
	else
		r, g, b, a = self:GetColor()
	end
	self.frame:SetStatusBarColor(r, g, b, a or 1)
	local tex = self.frame.GetStatusBarTexture and self.frame:GetStatusBarTexture()
	if tex and tex.Show then tex:Show() end
end

function ExperienceBar:UpdateRestedOverlay(ctx)
	if not (self.frame and self.frame.restedOverlay) then return end
	local overlay = self.frame.restedOverlay
	overlay:Hide()
	overlay:ClearAllPoints()

	if not self:GetRestedOverlayEnabled() then return end
	if not ctx or (ctx.max or 0) <= 0 then return end

	local startFraction = clamp((ctx.current or 0) / (ctx.max or 1), 0, 1)
	local endFraction = clamp(((ctx.current or 0) + (ctx.rested or 0)) / (ctx.max or 1), 0, 1)
	if endFraction <= startFraction then return end

	local fillDirection = self:GetFillDirection()
	local vertical = isVerticalFillDirection(fillDirection)
	local barSize = vertical and (self.frame:GetHeight() or 0) or (self.frame:GetWidth() or 0)
	if barSize <= 0 then return end

	local startPx = startFraction * barSize
	local endPx = endFraction * barSize
	if endPx <= startPx then return end

	local rr, rg, rb, ra = self:GetRestedColor()
	overlay:SetVertexColor(rr or 1, rg or 1, rb or 1, ra or 1)

	if fillDirection == "LEFT" then
		overlay:SetPoint("TOPLEFT", self.frame, "TOPLEFT", startPx, 0)
		overlay:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", endPx, 0)
	elseif fillDirection == "RIGHT" then
		overlay:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -startPx, 0)
		overlay:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -endPx, 0)
	elseif fillDirection == "UP" then
		overlay:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, startPx)
		overlay:SetPoint("TOPRIGHT", self.frame, "BOTTOMRIGHT", 0, endPx)
	else -- DOWN
		overlay:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -startPx)
		overlay:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", 0, -endPx)
	end

	overlay:Show()
end

function ExperienceBar:ApplyAppearance()
	if not self.frame then return end
	local texture = resolveTexture(self:GetTextureKey())
	self.frame:SetStatusBarTexture(texture)
	self:ApplyCurrentFillColor(self._hasRested == true)
	if self.frame.restedOverlay then self.frame.restedOverlay:SetTexture(texture) end

	local fillDirection = self:GetFillDirection()
	if self.frame.SetOrientation then self.frame:SetOrientation(isVerticalFillDirection(fillDirection) and "VERTICAL" or "HORIZONTAL") end
	if self.frame.SetReverseFill then self.frame:SetReverseFill(isReverseFillDirection(fillDirection)) end

	if self.frame.bg then
		if self:GetBackgroundEnabled() then
			local bgTex = resolveTexture(self:GetBackgroundTextureKey())
			self.frame.bg:SetTexture(bgTex)
			local br, bg, bb, ba = self:GetBackgroundColor()
			local alpha = (ba == nil) and 1 or ba
			self.frame.bg:SetVertexColor(br or 0, bg or 0, bb or 0, alpha)
			self.frame.bg:Hide()
			if alpha > 0 then self.frame.bg:Show() end
		else
			self.frame.bg:Hide()
		end
	end

	if self.frame.border then
		if not self:GetBorderEnabled() then
			self.frame.border:SetBackdrop(nil)
			self.frame.border:Hide()
		else
			local size = self:GetBorderSize()
			local offset = self:GetBorderOffset()
			local borderTex = resolveBorderTexture(self:GetBorderTextureKey())
			self.frame.border:SetBackdrop({
				edgeFile = borderTex,
				edgeSize = size,
				insets = { left = 0, right = 0, top = 0, bottom = 0 },
			})
			local br, bg, bb, ba = self:GetBorderColor()
			self.frame.border:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
			self.frame.border:SetBackdropColor(0, 0, 0, 0)
			self.frame.border:ClearAllPoints()
			self.frame.border:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -offset, offset)
			self.frame.border:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", offset, -offset)
			self.frame.border:Show()
		end
	end

	local font = resolveFontPath(self:GetTextFont())
	local outline = self:GetTextOutline()
	if outline == "NONE" then outline = "" end
	local size = self:GetTextSize()
	local tr, tg, tb, ta = self:GetTextColor()
	for _, key in ipairs({ "textLeft", "textCenter", "textRight" }) do
		local fs = self.frame[key]
		if fs then
			fs:SetFont(font, size, outline)
			fs:SetTextColor(tr or 1, tg or 1, tb or 1, ta or 1)
		end
	end
	if self.frame.editLabel then
		self.frame.editLabel:SetFont(font, math.max(size, 11), outline)
		self.frame.editLabel:SetTextColor(1, 0.9, 0.2, 1)
	end

	self:UpdateRestedOverlay(self._lastXPContext)
end

function ExperienceBar:ApplySize()
	if not self.frame then return end
	self:EnsureWidthSyncHooks()
	local width = self:GetResolvedWidth()
	local height = self:GetHeight()
	self.frame:SetSize(width, height)
	if self.frame.bg then self.frame.bg:SetAllPoints(self.frame) end
	if self.frame.editBg then self.frame.editBg:SetAllPoints(self.frame) end
	if self.frame.border then self.frame.border:SetAllPoints(self.frame) end
	self:UpdateRestedOverlay(self._lastXPContext)
end

function ExperienceBar:EnsureFrame()
	if self.frame then return self.frame end

	local bar = CreateFrame("StatusBar", "EQOL_XPBar", UIParent)
	bar:SetMinMaxValues(0, 1)
	bar:SetClampedToScreen(true)
	bar:Hide()

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bar.bg = bg

	local restedOverlay = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	restedOverlay:SetAllPoints(bar)
	restedOverlay:Hide()
	bar.restedOverlay = restedOverlay

	local editBg = bar:CreateTexture(nil, "BORDER")
	editBg:SetAllPoints(bar)
	editBg:SetColorTexture(0.1, 0.6, 0.6, 0.2)
	editBg:Hide()
	bar.editBg = editBg

	local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
	border:SetAllPoints(bar)
	border:SetFrameLevel((bar:GetFrameLevel() or 0) + 2)
	border:Hide()
	bar.border = border

	local textLeft = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	textLeft:SetPoint("LEFT", bar, "LEFT", 4, 0)
	textLeft:SetJustifyH("LEFT")
	textLeft:Hide()
	bar.textLeft = textLeft

	local textCenter = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	textCenter:SetPoint("CENTER", bar, "CENTER", 0, 0)
	textCenter:SetJustifyH("CENTER")
	textCenter:Hide()
	bar.textCenter = textCenter

	local textRight = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	textRight:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	textRight:SetJustifyH("RIGHT")
	textRight:Hide()
	bar.textRight = textRight

	local editLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	editLabel:SetPoint("BOTTOM", bar, "TOP", 0, 4)
	editLabel:SetText(L["ExperienceBar"] or "Experience Bar")
	editLabel:Hide()
	bar.editLabel = editLabel

	bar:HookScript("OnShow", function()
		if ExperienceBar and ExperienceBar.previewing then return end
		if ExperienceBar and ExperienceBar.UpdateSoon then ExperienceBar:UpdateSoon() end
	end)

	self.frame = bar
	self:ApplyAppearance()
	self:ApplySize()

	return bar
end

local function shouldShowCustomXPBar()
	local _, maxXP = getXPValues()
	if maxXP <= 0 then return false end
	return true
end

function ExperienceBar:StopBootstrapRefresh()
	if self._bootstrapTicker then
		self._bootstrapTicker:Cancel()
		self._bootstrapTicker = nil
	end
	self._bootstrapTries = nil
end

function ExperienceBar:StartBootstrapRefresh()
	if not self:IsEnabled() then return end
	if not (C_Timer and C_Timer.NewTicker) then
		self:UpdateXP()
		return
	end
	if self._bootstrapTicker then return end
	self._bootstrapTries = 0
	self._bootstrapTicker = C_Timer.NewTicker(0.25, function()
		if not (ExperienceBar and ExperienceBar.IsEnabled and ExperienceBar:IsEnabled()) then
			if ExperienceBar and ExperienceBar.StopBootstrapRefresh then ExperienceBar:StopBootstrapRefresh() end
			return
		end
		ExperienceBar._bootstrapTries = (ExperienceBar._bootstrapTries or 0) + 1
		ExperienceBar:UpdateXP()
		local _, maxXP = getXPValues()
		if maxXP > 0 or (ExperienceBar._bootstrapTries or 0) >= 32 then ExperienceBar:StopBootstrapRefresh() end
	end)
end

function ExperienceBar:WantsBlizzardTrackingHidden()
	if not self:IsEnabled() then return false end
	if self.previewing then return false end
	if not self:GetHideBlizzardTracking() then return false end
	if shouldHideInPetBattleForXP() and isPetBattleActive() then return false end
	return shouldShowCustomXPBar()
end

function ExperienceBar:ApplyBlizzardTrackingVisibility()
	self._blizzardTrackingHooks = self._blizzardTrackingHooks or {}
	local hide = self:WantsBlizzardTrackingHidden()
	for _, frameName in ipairs(BLIZZARD_TRACKING_FRAMES) do
		local frame = _G and _G[frameName]
		if frame then
			if frame.HookScript and not self._blizzardTrackingHooks[frameName] then
				self._blizzardTrackingHooks[frameName] = true
				frame:HookScript("OnShow", function(shownFrame)
					if ExperienceBar and ExperienceBar.WantsBlizzardTrackingHidden and ExperienceBar:WantsBlizzardTrackingHidden() then
						shownFrame._eqolXPBarHidden = true
						shownFrame:SetAlpha(0)
						if shownFrame.EnableMouse then shownFrame:EnableMouse(false) end
					end
				end)
			end
			if hide then
				frame._eqolXPBarHidden = true
				frame:SetAlpha(0)
				if frame.EnableMouse then frame:EnableMouse(false) end
			elseif frame._eqolXPBarHidden then
				frame._eqolXPBarHidden = nil
				frame:SetAlpha(1)
				if frame.EnableMouse then frame:EnableMouse(true) end
			end
		end
	end
end

function ExperienceBar:UpdateTextFromContext(ctx)
	if not self.frame then return end

	if self.frame.editLabel then
		if self.previewing then
			self.frame.editLabel:SetText(L["ExperienceBar"] or "Experience Bar")
			self.frame.editLabel:Show()
		else
			self.frame.editLabel:Hide()
		end
	end

	if not self:GetTextEnabled() then
		if self.frame.textLeft then self.frame.textLeft:Hide() end
		if self.frame.textCenter then self.frame.textCenter:Hide() end
		if self.frame.textRight then self.frame.textRight:Hide() end
		return
	end

	local leftText = formatXPText(self:GetTextLeftMode(), ctx)
	local centerText = formatXPText(self:GetTextCenterMode(), ctx)
	local rightText = formatXPText(self:GetTextRightMode(), ctx)

	local function setText(fs, text)
		if not fs then return end
		if text and text ~= "" then
			fs:SetText(text)
			fs:Show()
		else
			fs:Hide()
		end
	end

	setText(self.frame.textLeft, leftText)
	setText(self.frame.textCenter, centerText)
	setText(self.frame.textRight, rightText)
end

function ExperienceBar:UpdateXP()
	if self.previewing then return end
	if not self.frame then return end

	if shouldHideInPetBattleForXP() and isPetBattleActive() then
		self.frame:Hide()
		self:ApplyBlizzardTrackingVisibility()
		return
	end

	self:MaybeUpdateAnchor()
	local currentXP, maxXP = getXPValues()
	if maxXP <= 0 then
		self.frame:Hide()
		self:ApplyBlizzardTrackingVisibility()
		self:StartBootstrapRefresh()
		return
	end

	self:StopBootstrapRefresh()

	local restedXP = getRestedXP()
	local ctx = buildXPContext(getPlayerLevel(), currentXP, maxXP, restedXP)
	self._lastXPContext = ctx
	self._hasRested = (ctx.rested or 0) > 0
	local fraction = 0
	if ctx.max > 0 then
		fraction = ctx.current / ctx.max
		if fraction < 0 then
			fraction = 0
		elseif fraction > 1 then
			fraction = 1
		end
	end
	self._lastFraction = fraction

	self.frame:SetMinMaxValues(0, 1)
	self.frame:SetValue(fraction)
	self:ApplyCurrentFillColor(self._hasRested)
	self:UpdateRestedOverlay(ctx)
	self:UpdateTextFromContext(ctx)
	self.frame:Show()
	self:ApplyBlizzardTrackingVisibility()
end

function ExperienceBar:UpdateSoon()
	if not self:IsEnabled() then return end
	self:StartBootstrapRefresh()
	if not (C_Timer and C_Timer.After) then
		self:UpdateXP()
		return
	end
	C_Timer.After(0, function()
		if ExperienceBar and ExperienceBar.IsEnabled and ExperienceBar:IsEnabled() then ExperienceBar:UpdateXP() end
	end)
	C_Timer.After(0.2, function()
		if ExperienceBar and ExperienceBar.IsEnabled and ExperienceBar:IsEnabled() then ExperienceBar:UpdateXP() end
	end)
	C_Timer.After(1.0, function()
		if ExperienceBar and ExperienceBar.IsEnabled and ExperienceBar:IsEnabled() then ExperienceBar:UpdateXP() end
	end)
end

function ExperienceBar:ShowEditModeHint(show)
	if not self.frame then return end
	if show then
		if self.frame.editBg then self.frame.editBg:Show() end
		self.previewing = true
		self._hasRested = true
		self:ApplyCurrentFillColor(true)
		self.frame:SetMinMaxValues(0, 403725)
		self.frame:SetValue(320192)
		local sampleLevel = getPlayerLevel()
		if sampleLevel <= 0 then sampleLevel = 80 end
		local sample = buildXPContext(sampleLevel, 320192, 403725, 83533)
		self._lastXPContext = sample
		self:UpdateRestedOverlay(sample)
		self:UpdateTextFromContext(sample)
		self.frame:Show()
	else
		if self.frame.editBg then self.frame.editBg:Hide() end
		self.previewing = nil
		self:UpdateXP()
		self:UpdateSoon()
	end
end

function ExperienceBar:RegisterEvents()
	if self.eventsRegistered then return end
	local frame = self:EnsureFrame()
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_ALIVE")
	frame:RegisterEvent("PLAYER_XP_UPDATE")
	frame:RegisterEvent("PLAYER_LEVEL_UP")
	frame:RegisterEvent("UPDATE_EXHAUSTION")
	frame:RegisterEvent("PLAYER_UPDATE_RESTING")
	frame:RegisterEvent("ENABLE_XP_GAIN")
	frame:RegisterEvent("DISABLE_XP_GAIN")
	frame:RegisterEvent("PET_BATTLE_OPENING_START")
	frame:RegisterEvent("PET_BATTLE_CLOSE")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "PLAYER_XP_UPDATE" then
			local unit = ...
			if unit and unit ~= "player" then return end
		elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_ALIVE" then
			ExperienceBar:UpdateSoon()
		end
		ExperienceBar:UpdateXP()
	end)
	self.eventsRegistered = true
end

function ExperienceBar:UnregisterEvents()
	if not self.eventsRegistered or not self.frame then return end
	self.frame:UnregisterEvent("PLAYER_LOGIN")
	self.frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self.frame:UnregisterEvent("PLAYER_ALIVE")
	self.frame:UnregisterEvent("PLAYER_XP_UPDATE")
	self.frame:UnregisterEvent("PLAYER_LEVEL_UP")
	self.frame:UnregisterEvent("UPDATE_EXHAUSTION")
	self.frame:UnregisterEvent("PLAYER_UPDATE_RESTING")
	self.frame:UnregisterEvent("ENABLE_XP_GAIN")
	self.frame:UnregisterEvent("DISABLE_XP_GAIN")
	self.frame:UnregisterEvent("PET_BATTLE_OPENING_START")
	self.frame:UnregisterEvent("PET_BATTLE_CLOSE")
	self.frame:SetScript("OnEvent", nil)
	self.eventsRegistered = false
end

local editModeRegistered = false
local editModeCallbacksRegistered = false

function ExperienceBar:BuildLayoutRecordFromProfile()
	local record = {}
	record.point = self:GetAnchorPoint()
	record.relativePoint = self:GetAnchorRelativePoint()
	record.x = self:GetAnchorOffsetX()
	record.y = self:GetAnchorOffsetY()
	record.width = self:GetWidth()
	record.height = self:GetHeight()
	record.texture = self:GetTextureKey()
	record.bgEnabled = self:GetBackgroundEnabled()
	record.bgTexture = self:GetBackgroundTextureKey()
	do
		local r, g, b, a = self:GetBackgroundColor()
		record.bgColor = { r = r, g = g, b = b, a = a }
	end
	record.borderEnabled = self:GetBorderEnabled()
	record.borderTexture = self:GetBorderTextureKey()
	do
		local r, g, b, a = self:GetBorderColor()
		record.borderColor = { r = r, g = g, b = b, a = a }
	end
	record.borderSize = self:GetBorderSize()
	record.borderOffset = self:GetBorderOffset()
	record.fillDirection = self:GetFillDirection()
	record.anchorRelativeFrame = self:GetAnchorRelativeFrame()
	record.anchorMatchWidth = self:GetAnchorMatchWidth()
	record.textEnabled = self:GetTextEnabled()
	record.textLeftMode = self:GetTextLeftMode()
	record.textCenterMode = self:GetTextCenterMode()
	record.textRightMode = self:GetTextRightMode()
	record.textMode = normalizeLegacyTextMode(record.textCenterMode)
	record.textSize = self:GetTextSize()
	record.textFont = self:GetTextFont()
	record.textOutline = self:GetTextOutline()
	record.hideInPetBattle = self:GetHideInPetBattle()
	record.hideBlizzardTracking = self:GetHideBlizzardTracking()
	record.restedOverlayEnabled = self:GetRestedOverlayEnabled()
	do
		local r, g, b, a = self:GetColor()
		record.color = { r = r, g = g, b = b, a = a }
	end
	do
		local r, g, b, a = self:GetRestedColor()
		record.restedColor = { r = r, g = g, b = b, a = a }
	end
	do
		local r, g, b, a = self:GetTextColor()
		record.textColor = { r = r, g = g, b = b, a = a }
	end
	return record
end

local function registerEditModeCallbacks()
	if editModeCallbacksRegistered then return end
	local lib = addon.EditModeLib
	if not (lib and lib.RegisterCallback) then return end

	lib:RegisterCallback("exit", function()
		if not (ExperienceBar and ExperienceBar.IsEnabled and ExperienceBar:IsEnabled()) then return end
		ExperienceBar.previewing = nil
		if ExperienceBar.frame then
			if ExperienceBar.frame.editBg then ExperienceBar.frame.editBg:Hide() end
			if ExperienceBar.frame.editLabel then ExperienceBar.frame.editLabel:Hide() end
		end
		ExperienceBar:ApplySize()
		ExperienceBar:ApplyAppearance()
		ExperienceBar:UpdateSoon()
	end)

	editModeCallbacksRegistered = true
end

function ExperienceBar:ApplyLayoutData(data)
	if not data or not addon.db then return end

	local width = clamp(data.width or defaults.width, BAR_SIZE_MIN, BAR_WIDTH_MAX)
	local height = clamp(data.height or defaults.height, BAR_SIZE_MIN, BAR_SIZE_MAX)
	local texture = data.texture or defaults.texture
	local r, g, b, a = normalizeColor(data.color or defaults.color, defaults.color)
	local rr, rg, rb, ra = normalizeColor(data.restedColor or defaults.restedColor, defaults.restedColor)
	local bgEnabled = data.bgEnabled == true
	local bgTexture = data.bgTexture or defaults.bgTexture
	local bgr, bgg, bgb, bga = normalizeColor(data.bgColor or defaults.bgColor, defaults.bgColor)
	local borderEnabled = data.borderEnabled == true
	local borderTexture = data.borderTexture or defaults.borderTexture
	local bdr, bdg, bdb, bda = normalizeColor(data.borderColor or defaults.borderColor, defaults.borderColor)
	local borderSize = clamp(data.borderSize or defaults.borderSize, 1, 20)
	local borderOffset = clamp(data.borderOffset or defaults.borderOffset, -20, 20)
	local fillDirection = normalizeFillDirection(data.fillDirection or defaults.fillDirection)
	local anchorRelativeFrame = normalizeAnchorRelativeFrame(data.anchorRelativeFrame or data.anchorTarget or addon.db[DB_ANCHOR_RELATIVE_FRAME] or defaults.anchorRelativeFrame)
	local anchorMatchWidth = addon.db[DB_ANCHOR_MATCH_WIDTH] == true
	if data.anchorMatchWidth ~= nil then
		anchorMatchWidth = data.anchorMatchWidth == true
	elseif data.anchorMatchRelativeWidth ~= nil then
		anchorMatchWidth = data.anchorMatchRelativeWidth == true
	end
	local anchorPoint = normalizeAnchorPoint(data.point or addon.db[DB_ANCHOR_POINT], defaults.anchorPoint)
	local anchorRelativePoint = normalizeAnchorPoint(data.relativePoint or addon.db[DB_ANCHOR_RELATIVE_POINT], anchorPoint)
	local anchorOffsetX = normalizeAnchorOffset(data.x ~= nil and data.x or addon.db[DB_ANCHOR_OFFSET_X], defaults.anchorOffsetX)
	local anchorOffsetY = normalizeAnchorOffset(data.y ~= nil and data.y or addon.db[DB_ANCHOR_OFFSET_Y], defaults.anchorOffsetY)
	local textEnabled = addon.db[DB_TEXT_ENABLED] ~= false
	if data.textEnabled ~= nil then textEnabled = data.textEnabled == true end
	local textLeftMode = normalizeTextContentMode(data.textLeftMode or addon.db[DB_TEXT_LEFT_MODE] or defaults.textLeftMode)
	local textCenterMode = normalizeTextContentMode(data.textCenterMode or data.textMode or addon.db[DB_TEXT_CENTER_MODE] or addon.db[DB_TEXT_MODE] or defaults.textCenterMode or defaults.textMode)
	local textRightMode = normalizeTextContentMode(data.textRightMode or addon.db[DB_TEXT_RIGHT_MODE] or defaults.textRightMode)
	local textSize = clamp(data.textSize or addon.db[DB_TEXT_SIZE] or defaults.textSize, TEXT_SIZE_MIN, TEXT_SIZE_MAX)
	local textFont = data.textFont or addon.db[DB_TEXT_FONT] or defaults.textFont or "DEFAULT"
	local textOutline = normalizeTextOutline(data.textOutline or addon.db[DB_TEXT_OUTLINE] or defaults.textOutline)
	local textR, textG, textB, textA = normalizeColor(data.textColor or addon.db[DB_TEXT_COLOR] or defaults.textColor, defaults.textColor)
	local hideInPetBattle = addon.db[DB_HIDE_IN_PET_BATTLE] == true
	if data.hideInPetBattle ~= nil then hideInPetBattle = data.hideInPetBattle == true end
	local hideBlizzardTracking = addon.db[DB_HIDE_BLIZZARD_TRACKING] == true
	if data.hideBlizzardTracking ~= nil then hideBlizzardTracking = data.hideBlizzardTracking == true end
	local restedOverlayEnabled = addon.db[DB_RESTED_OVERLAY_ENABLED] ~= false
	if data.restedOverlayEnabled ~= nil then restedOverlayEnabled = data.restedOverlayEnabled == true end

	addon.db[DB_WIDTH] = width
	addon.db[DB_HEIGHT] = height
	addon.db[DB_TEXTURE] = texture
	addon.db[DB_COLOR] = { r = r, g = g, b = b, a = a }
	addon.db[DB_RESTED_COLOR] = { r = rr, g = rg, b = rb, a = ra }
	addon.db[DB_BG_ENABLED] = bgEnabled
	addon.db[DB_BG_TEXTURE] = bgTexture
	addon.db[DB_BG_COLOR] = { r = bgr, g = bgg, b = bgb, a = bga }
	addon.db[DB_BORDER_ENABLED] = borderEnabled
	addon.db[DB_BORDER_TEXTURE] = borderTexture
	addon.db[DB_BORDER_COLOR] = { r = bdr, g = bdg, b = bdb, a = bda }
	addon.db[DB_BORDER_SIZE] = borderSize
	addon.db[DB_BORDER_OFFSET] = borderOffset
	addon.db[DB_FILL_DIRECTION] = fillDirection
	local prevAnchorRelativeFrame = addon.db[DB_ANCHOR_RELATIVE_FRAME]
	addon.db[DB_ANCHOR_RELATIVE_FRAME] = anchorRelativeFrame
	addon.db[DB_ANCHOR_MATCH_WIDTH] = anchorMatchWidth and true or false
	addon.db[DB_ANCHOR_POINT] = anchorPoint
	addon.db[DB_ANCHOR_RELATIVE_POINT] = anchorRelativePoint
	addon.db[DB_ANCHOR_OFFSET_X] = anchorOffsetX
	addon.db[DB_ANCHOR_OFFSET_Y] = anchorOffsetY
	addon.db[DB_TEXT_ENABLED] = textEnabled and true or false
	addon.db[DB_TEXT_LEFT_MODE] = textLeftMode
	addon.db[DB_TEXT_CENTER_MODE] = textCenterMode
	addon.db[DB_TEXT_RIGHT_MODE] = textRightMode
	addon.db[DB_TEXT_MODE] = normalizeLegacyTextMode(textCenterMode)
	addon.db[DB_TEXT_SIZE] = textSize
	addon.db[DB_TEXT_FONT] = textFont
	addon.db[DB_TEXT_OUTLINE] = textOutline
	addon.db[DB_TEXT_COLOR] = { r = textR, g = textG, b = textB, a = textA }
	addon.db[DB_HIDE_IN_PET_BATTLE] = hideInPetBattle and true or false
	addon.db[DB_HIDE_BLIZZARD_TRACKING] = hideBlizzardTracking and true or false
	addon.db[DB_RESTED_OVERLAY_ENABLED] = restedOverlayEnabled and true or false

	self:ApplySize()
	self:ApplyAppearance()
	if prevAnchorRelativeFrame ~= anchorRelativeFrame then self:RefreshAnchor() end
	self:UpdateSoon()
end

local function applySetting(field, value)
	if not addon.db then return end
	local editField = field
	local skipEditValue

	if field == "width" then
		local width = clamp(value, BAR_SIZE_MIN, BAR_WIDTH_MAX)
		addon.db[DB_WIDTH] = width
		value = width
	elseif field == "height" then
		local height = clamp(value, BAR_SIZE_MIN, BAR_SIZE_MAX)
		addon.db[DB_HEIGHT] = height
		value = height
	elseif field == "texture" then
		local tex = value or defaults.texture
		addon.db[DB_TEXTURE] = tex
		value = tex
	elseif field == "color" then
		local r, g, b, a = normalizeColor(value, defaults.color)
		addon.db[DB_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_COLOR]
	elseif field == "restedColor" then
		local r, g, b, a = normalizeColor(value, defaults.restedColor)
		addon.db[DB_RESTED_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_RESTED_COLOR]
	elseif field == "restedOverlayEnabled" then
		local enabled = value == true
		addon.db[DB_RESTED_OVERLAY_ENABLED] = enabled and true or false
		value = enabled
	elseif field == "bgEnabled" then
		local enabled = value == true
		addon.db[DB_BG_ENABLED] = enabled
		value = enabled
	elseif field == "bgTexture" then
		local tex = value or defaults.bgTexture
		addon.db[DB_BG_TEXTURE] = tex
		value = tex
	elseif field == "bgColor" then
		local r, g, b, a = normalizeColor(value, defaults.bgColor)
		addon.db[DB_BG_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_BG_COLOR]
	elseif field == "borderEnabled" then
		local enabled = value == true
		addon.db[DB_BORDER_ENABLED] = enabled
		value = enabled
	elseif field == "borderTexture" then
		local tex = value or defaults.borderTexture
		addon.db[DB_BORDER_TEXTURE] = tex
		value = tex
	elseif field == "borderColor" then
		local r, g, b, a = normalizeColor(value, defaults.borderColor)
		addon.db[DB_BORDER_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_BORDER_COLOR]
	elseif field == "borderSize" then
		local size = clamp(value, 1, 20)
		addon.db[DB_BORDER_SIZE] = size
		value = size
	elseif field == "borderOffset" then
		local offset = clamp(value, -20, 20)
		addon.db[DB_BORDER_OFFSET] = offset
		value = offset
	elseif field == "fillDirection" then
		local dir = normalizeFillDirection(value)
		addon.db[DB_FILL_DIRECTION] = dir
		value = dir
	elseif field == "anchorRelativeFrame" then
		local target = normalizeAnchorRelativeFrame(value)
		local prev = addon.db[DB_ANCHOR_RELATIVE_FRAME]
		addon.db[DB_ANCHOR_RELATIVE_FRAME] = target
		editField = "anchorRelativeFrame"
		if EditMode and EditMode.SetValue then EditMode:SetValue(EDITMODE_ID, editField, target, nil, true) end
		if prev ~= target then
			local point, relPoint, x, y = anchorDefaultsFor(target)
			addon.db[DB_ANCHOR_POINT] = point
			addon.db[DB_ANCHOR_RELATIVE_POINT] = relPoint
			addon.db[DB_ANCHOR_OFFSET_X] = x
			addon.db[DB_ANCHOR_OFFSET_Y] = y
			if EditMode and EditMode.SetValue then
				EditMode:SetValue(EDITMODE_ID, "point", point, nil, true)
				EditMode:SetValue(EDITMODE_ID, "relativePoint", relPoint, nil, true)
				EditMode:SetValue(EDITMODE_ID, "x", x, nil, true)
				EditMode:SetValue(EDITMODE_ID, "y", y, nil, true)
			end
			refreshSettingsUI()
		end
		value = target
		skipEditValue = true
	elseif field == "anchorMatchWidth" then
		local enabled = value == true
		addon.db[DB_ANCHOR_MATCH_WIDTH] = enabled and true or false
		value = enabled
		refreshSettingsUI()
	elseif field == "anchorPoint" then
		local point = normalizeAnchorPoint(value, defaults.anchorPoint)
		addon.db[DB_ANCHOR_POINT] = point
		editField = "point"
		value = point
		local rel = normalizeAnchorPoint(addon.db[DB_ANCHOR_RELATIVE_POINT], point)
		if addon.db[DB_ANCHOR_RELATIVE_POINT] ~= rel then
			addon.db[DB_ANCHOR_RELATIVE_POINT] = rel
			if EditMode and EditMode.SetValue then EditMode:SetValue(EDITMODE_ID, "relativePoint", rel, nil, true) end
		end
	elseif field == "anchorRelativePoint" then
		local rel = normalizeAnchorPoint(value, defaults.anchorRelativePoint)
		addon.db[DB_ANCHOR_RELATIVE_POINT] = rel
		editField = "relativePoint"
		value = rel
	elseif field == "anchorOffsetX" then
		local offset = normalizeAnchorOffset(value, defaults.anchorOffsetX)
		addon.db[DB_ANCHOR_OFFSET_X] = offset
		editField = "x"
		value = offset
	elseif field == "anchorOffsetY" then
		local offset = normalizeAnchorOffset(value, defaults.anchorOffsetY)
		addon.db[DB_ANCHOR_OFFSET_Y] = offset
		editField = "y"
		value = offset
	elseif field == "textEnabled" then
		local enabled = value == true
		addon.db[DB_TEXT_ENABLED] = enabled and true or false
		value = enabled
	elseif field == "textLeftMode" then
		local mode = normalizeTextContentMode(value)
		addon.db[DB_TEXT_LEFT_MODE] = mode
		value = mode
	elseif field == "textCenterMode" then
		local mode = normalizeTextContentMode(value)
		addon.db[DB_TEXT_CENTER_MODE] = mode
		addon.db[DB_TEXT_MODE] = normalizeLegacyTextMode(mode)
		value = mode
	elseif field == "textRightMode" then
		local mode = normalizeTextContentMode(value)
		addon.db[DB_TEXT_RIGHT_MODE] = mode
		value = mode
	elseif field == "textSize" then
		local size = clamp(value, TEXT_SIZE_MIN, TEXT_SIZE_MAX)
		addon.db[DB_TEXT_SIZE] = size
		value = size
	elseif field == "textFont" then
		local key = value or defaults.textFont or "DEFAULT"
		addon.db[DB_TEXT_FONT] = key
		value = key
	elseif field == "textOutline" then
		local outline = normalizeTextOutline(value)
		addon.db[DB_TEXT_OUTLINE] = outline
		value = outline
	elseif field == "textColor" then
		local r, g, b, a = normalizeColor(value, defaults.textColor)
		addon.db[DB_TEXT_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_TEXT_COLOR]
	elseif field == "hideInPetBattle" then
		local enabled = value == true
		addon.db[DB_HIDE_IN_PET_BATTLE] = enabled and true or false
		value = enabled
	elseif field == "hideBlizzardTracking" then
		local enabled = value == true
		addon.db[DB_HIDE_BLIZZARD_TRACKING] = enabled and true or false
		value = enabled
	end

	if not skipEditValue and EditMode and EditMode.SetValue then EditMode:SetValue(EDITMODE_ID, editField, value, nil, true) end
	ExperienceBar:ApplySize()
	ExperienceBar:ApplyAppearance()
	ExperienceBar:RefreshAnchor()
	ExperienceBar:UpdateSoon()
end

function ExperienceBar:RegisterEditMode()
	if editModeRegistered or not EditMode or not EditMode.RegisterFrame then return end

	local settings
	if SettingType then
		local function anchorFrameEntries()
			local entries = {}
			local seen = {}
			local function frameIsAvailable(key)
				if key == ANCHOR_TARGET_UI or key == ANCHOR_TARGET_PLAYER_CASTBAR then return true end
				return _G and _G[key] ~= nil
			end
			local function add(key, label, force)
				if not key or key == "" or seen[key] then return end
				if not force and not frameIsAvailable(key) then return end
				seen[key] = true
				entries[#entries + 1] = { key = key, label = label or key }
			end

			add(ANCHOR_TARGET_UI, L["xpBarAnchorScreen"] or "Screen (UIParent)", true)
			add(ANCHOR_TARGET_PLAYER_CASTBAR, L["xpBarAnchorPlayerCastbar"] or "Player Castbar", true)
			add("EQOL_GCDBar", L["GCDBar"] or "GCD Bar")

			add("PlayerFrame", _G.HUD_EDIT_MODE_PLAYER_FRAME_LABEL or PLAYER or "Player Frame")
			add("TargetFrame", _G.HUD_EDIT_MODE_TARGET_FRAME_LABEL or TARGET or "Target Frame")

			add("EssentialCooldownViewer", L["cooldownViewerEssential"] or "Essential Cooldown Viewer")
			add("UtilityCooldownViewer", L["cooldownViewerUtility"] or "Utility Cooldown Viewer")
			add("BuffBarCooldownViewer", L["cooldownViewerBuffBar"] or "Buff Bar Cooldowns")
			add("BuffIconCooldownViewer", L["cooldownViewerBuffIcon"] or "Buff Icon Cooldowns")

			local cooldownPanels = addon.Aura and addon.Aura.CooldownPanels
			if cooldownPanels and cooldownPanels.GetRoot then
				local root = cooldownPanels:GetRoot()
				if root and root.panels then
					local order = root.order or {}
					local function addPanelEntry(panelId, panel)
						if not panel or panel.enabled == false then return end
						local label = string.format("Panel %s: %s", tostring(panelId), panel.name or "Cooldown Panel")
						add("EQOL_CooldownPanel" .. tostring(panelId), label)
					end
					if #order > 0 then
						for _, panelId in ipairs(order) do
							addPanelEntry(panelId, root.panels[panelId])
						end
					else
						for panelId, panel in pairs(root.panels) do
							addPanelEntry(panelId, panel)
						end
					end
				end
			end

			local rb = addon.Aura and addon.Aura.ResourceBars
			add("EQOLHealthBar", HEALTH or "Health")
			if rb and rb.classPowerTypes then
				for _, pType in ipairs(rb.classPowerTypes) do
					local frameName = "EQOL" .. tostring(pType) .. "Bar"
					local label = (rb.PowerLabels and rb.PowerLabels[pType]) or _G["POWER_TYPE_" .. tostring(pType)] or tostring(pType)
					add(frameName, label)
				end
			end

			local current = ExperienceBar:GetAnchorRelativeFrame()
			if current and not seen[current] then add(current, current, true) end

			return entries
		end

		local function dropdownFromModes(getFn, setFn)
			return function(_, root)
				for _, option in ipairs(textModeOptions()) do
					root:CreateRadio(option.label, function() return getFn() == option.value end, function() setFn(option.value) end)
				end
			end
		end

		settings = {
			{
				name = L["xpBarAnchor"] or "Anchor to",
				kind = SettingType.Dropdown,
				field = "anchorRelativeFrame",
				height = 180,
				get = function() return ExperienceBar:GetAnchorRelativeFrame() end,
				set = function(_, value) applySetting("anchorRelativeFrame", value) end,
				generator = function(_, root)
					for _, option in ipairs(anchorFrameEntries()) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetAnchorRelativeFrame() == option.key end, function() applySetting("anchorRelativeFrame", option.key) end)
					end
				end,
			},
			{
				name = L["xpBarAnchorPoint"] or "Anchor point",
				kind = SettingType.Dropdown,
				field = "anchorPoint",
				height = 180,
				get = function() return ExperienceBar:GetAnchorPoint() end,
				set = function(_, value) applySetting("anchorPoint", value) end,
				generator = function(_, root)
					for _, point in ipairs(ANCHOR_POINTS) do
						root:CreateRadio(point, function() return ExperienceBar:GetAnchorPoint() == point end, function() applySetting("anchorPoint", point) end)
					end
				end,
			},
			{
				name = L["xpBarAnchorRelativePoint"] or "Relative point",
				kind = SettingType.Dropdown,
				field = "anchorRelativePoint",
				height = 180,
				get = function() return ExperienceBar:GetAnchorRelativePoint() end,
				set = function(_, value) applySetting("anchorRelativePoint", value) end,
				generator = function(_, root)
					for _, point in ipairs(ANCHOR_POINTS) do
						root:CreateRadio(point, function() return ExperienceBar:GetAnchorRelativePoint() == point end, function() applySetting("anchorRelativePoint", point) end)
					end
				end,
			},
			{
				name = L["xpBarAnchorOffsetX"] or "X Offset",
				kind = SettingType.Slider,
				field = "anchorOffsetX",
				minValue = -1000,
				maxValue = 1000,
				valueStep = 1,
				allowInput = true,
				get = function() return ExperienceBar:GetAnchorOffsetX() end,
				set = function(_, value) applySetting("anchorOffsetX", value) end,
			},
			{
				name = L["xpBarAnchorOffsetY"] or "Y Offset",
				kind = SettingType.Slider,
				field = "anchorOffsetY",
				minValue = -1000,
				maxValue = 1000,
				valueStep = 1,
				allowInput = true,
				get = function() return ExperienceBar:GetAnchorOffsetY() end,
				set = function(_, value) applySetting("anchorOffsetY", value) end,
			},
			{
				name = L["xpBarAnchorMatchWidth"] or "Match relative frame width",
				kind = SettingType.Checkbox,
				field = "anchorMatchWidth",
				default = defaults.anchorMatchRelativeWidth == true,
				get = function() return ExperienceBar:GetAnchorMatchWidth() end,
				set = function(_, value) applySetting("anchorMatchWidth", value) end,
				isEnabled = function() return not ExperienceBar:AnchorUsesUIParent() end,
			},
			{
				name = L["xpBarHideInPetBattle"] or "Hide in pet battles",
				kind = SettingType.Checkbox,
				field = "hideInPetBattle",
				default = defaults.hideInPetBattle == true,
				get = function() return ExperienceBar:GetHideInPetBattle() end,
				set = function(_, value) applySetting("hideInPetBattle", value) end,
			},
			{
				name = L["xpBarHideBlizzardTracking"] or "Hide Blizzard tracking bars while leveling",
				kind = SettingType.Checkbox,
				field = "hideBlizzardTracking",
				default = defaults.hideBlizzardTracking == true,
				get = function() return ExperienceBar:GetHideBlizzardTracking() end,
				set = function(_, value) applySetting("hideBlizzardTracking", value) end,
			},
			{
				name = L["xpBarWidth"] or "Bar width",
				kind = SettingType.Slider,
				field = "width",
				default = defaults.width,
				minValue = BAR_SIZE_MIN,
				maxValue = BAR_WIDTH_MAX,
				valueStep = 1,
				allowInput = true,
				get = function() return ExperienceBar:GetWidth() end,
				set = function(_, value) applySetting("width", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isEnabled = function() return not ExperienceBar:AnchorUsesMatchedWidth() end,
			},
			{
				name = L["xpBarHeight"] or "Bar height",
				kind = SettingType.Slider,
				field = "height",
				default = defaults.height,
				minValue = BAR_SIZE_MIN,
				maxValue = BAR_SIZE_MAX,
				valueStep = 1,
				allowInput = true,
				get = function() return ExperienceBar:GetHeight() end,
				set = function(_, value) applySetting("height", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["xpBarTexture"] or "Bar texture",
				kind = SettingType.Dropdown,
				field = "texture",
				height = 180,
				get = function() return ExperienceBar:GetTextureKey() end,
				set = function(_, value) applySetting("texture", value) end,
				generator = function(_, root)
					for _, option in ipairs(textureOptions()) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetTextureKey() == option.value end, function() applySetting("texture", option.value) end)
					end
				end,
			},
			{
				name = L["xpBarColor"] or "Bar color",
				kind = SettingType.Color,
				field = "color",
				default = defaults.color,
				hasOpacity = true,
				get = function()
					local r, g, b, a = ExperienceBar:GetColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("color", value) end,
			},
			{
				name = L["xpBarRestedColor"] or "Rested color",
				kind = SettingType.Color,
				field = "restedColor",
				default = defaults.restedColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = ExperienceBar:GetRestedColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("restedColor", value) end,
			},
			{
				name = L["xpBarRestedOverlayEnabled"] or "Show rested overlay segment",
				kind = SettingType.Checkbox,
				field = "restedOverlayEnabled",
				default = defaults.restedOverlayEnabled ~= false,
				get = function() return ExperienceBar:GetRestedOverlayEnabled() end,
				set = function(_, value) applySetting("restedOverlayEnabled", value) end,
			},
			{
				name = L["xpBarBackgroundEnabled"] or "Use background",
				kind = SettingType.Checkbox,
				field = "bgEnabled",
				default = defaults.bgEnabled == true,
				get = function() return ExperienceBar:GetBackgroundEnabled() end,
				set = function(_, value) applySetting("bgEnabled", value) end,
			},
			{
				name = L["xpBarBackgroundTexture"] or "Background texture",
				kind = SettingType.Dropdown,
				field = "bgTexture",
				height = 180,
				get = function() return ExperienceBar:GetBackgroundTextureKey() end,
				set = function(_, value) applySetting("bgTexture", value) end,
				generator = function(_, root)
					for _, option in ipairs(textureOptions()) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetBackgroundTextureKey() == option.value end, function() applySetting("bgTexture", option.value) end)
					end
				end,
				isEnabled = function() return ExperienceBar:GetBackgroundEnabled() end,
			},
			{
				name = L["xpBarBackgroundColor"] or "Background color",
				kind = SettingType.Color,
				field = "bgColor",
				default = defaults.bgColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = ExperienceBar:GetBackgroundColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("bgColor", value) end,
				isEnabled = function() return ExperienceBar:GetBackgroundEnabled() end,
			},
			{
				name = L["xpBarBorderEnabled"] or "Use border",
				kind = SettingType.Checkbox,
				field = "borderEnabled",
				default = defaults.borderEnabled == true,
				get = function() return ExperienceBar:GetBorderEnabled() end,
				set = function(_, value) applySetting("borderEnabled", value) end,
			},
			{
				name = L["xpBarBorderTexture"] or "Border texture",
				kind = SettingType.Dropdown,
				field = "borderTexture",
				height = 180,
				get = function() return ExperienceBar:GetBorderTextureKey() end,
				set = function(_, value) applySetting("borderTexture", value) end,
				generator = function(_, root)
					for _, option in ipairs(borderOptions()) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetBorderTextureKey() == option.value end, function() applySetting("borderTexture", option.value) end)
					end
				end,
				isEnabled = function() return ExperienceBar:GetBorderEnabled() end,
			},
			{
				name = L["xpBarBorderSize"] or "Border size",
				kind = SettingType.Slider,
				field = "borderSize",
				default = defaults.borderSize,
				minValue = 1,
				maxValue = 20,
				valueStep = 1,
				get = function() return ExperienceBar:GetBorderSize() end,
				set = function(_, value) applySetting("borderSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isEnabled = function() return ExperienceBar:GetBorderEnabled() end,
			},
			{
				name = L["xpBarBorderOffset"] or "Border offset",
				kind = SettingType.Slider,
				field = "borderOffset",
				default = defaults.borderOffset,
				minValue = -20,
				maxValue = 20,
				valueStep = 1,
				get = function() return ExperienceBar:GetBorderOffset() end,
				set = function(_, value) applySetting("borderOffset", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isEnabled = function() return ExperienceBar:GetBorderEnabled() end,
			},
			{
				name = L["xpBarBorderColor"] or "Border color",
				kind = SettingType.Color,
				field = "borderColor",
				default = defaults.borderColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = ExperienceBar:GetBorderColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("borderColor", value) end,
				isEnabled = function() return ExperienceBar:GetBorderEnabled() end,
			},
			{
				name = L["xpBarFillDirection"] or "Fill direction",
				kind = SettingType.Dropdown,
				field = "fillDirection",
				height = 140,
				get = function() return ExperienceBar:GetFillDirection() end,
				set = function(_, value) applySetting("fillDirection", value) end,
				generator = function(_, root)
					local opts = {
						{ value = "LEFT", label = L["xpBarFillLeft"] or "Left to right" },
						{ value = "RIGHT", label = L["xpBarFillRight"] or "Right to left" },
						{ value = "UP", label = L["xpBarFillUp"] or "Bottom to top" },
						{ value = "DOWN", label = L["xpBarFillDown"] or "Top to bottom" },
					}
					for _, option in ipairs(opts) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetFillDirection() == option.value end, function() applySetting("fillDirection", option.value) end)
					end
				end,
			},
			{
				name = L["xpBarTextEnabled"] or "Show text",
				kind = SettingType.Checkbox,
				field = "textEnabled",
				default = defaults.textEnabled == true,
				get = function() return ExperienceBar:GetTextEnabled() end,
				set = function(_, value) applySetting("textEnabled", value) end,
			},
			{
				name = L["xpBarTextLeft"] or "Left text",
				kind = SettingType.Dropdown,
				field = "textLeftMode",
				height = 200,
				get = function() return ExperienceBar:GetTextLeftMode() end,
				set = function(_, value) applySetting("textLeftMode", value) end,
				generator = dropdownFromModes(function() return ExperienceBar:GetTextLeftMode() end, function(value) applySetting("textLeftMode", value) end),
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
			{
				name = L["xpBarTextCenter"] or "Center text",
				kind = SettingType.Dropdown,
				field = "textCenterMode",
				height = 200,
				get = function() return ExperienceBar:GetTextCenterMode() end,
				set = function(_, value) applySetting("textCenterMode", value) end,
				generator = dropdownFromModes(function() return ExperienceBar:GetTextCenterMode() end, function(value) applySetting("textCenterMode", value) end),
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
			{
				name = L["xpBarTextRight"] or "Right text",
				kind = SettingType.Dropdown,
				field = "textRightMode",
				height = 200,
				get = function() return ExperienceBar:GetTextRightMode() end,
				set = function(_, value) applySetting("textRightMode", value) end,
				generator = dropdownFromModes(function() return ExperienceBar:GetTextRightMode() end, function(value) applySetting("textRightMode", value) end),
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
			{
				name = L["xpBarTextSize"] or "Text size",
				kind = SettingType.Slider,
				field = "textSize",
				default = defaults.textSize,
				minValue = TEXT_SIZE_MIN,
				maxValue = TEXT_SIZE_MAX,
				valueStep = 1,
				allowInput = true,
				get = function() return ExperienceBar:GetTextSize() end,
				set = function(_, value) applySetting("textSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
			{
				name = L["xpBarTextFont"] or "Text font",
				kind = SettingType.Dropdown,
				field = "textFont",
				height = 180,
				get = function() return ExperienceBar:GetTextFont() end,
				set = function(_, value) applySetting("textFont", value) end,
				generator = function(_, root)
					for _, option in ipairs(fontOptions()) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetTextFont() == option.value end, function() applySetting("textFont", option.value) end)
					end
				end,
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
			{
				name = L["xpBarTextOutline"] or "Text outline",
				kind = SettingType.Dropdown,
				field = "textOutline",
				height = 120,
				get = function() return ExperienceBar:GetTextOutline() end,
				set = function(_, value) applySetting("textOutline", value) end,
				generator = function(_, root)
					local options = {
						{ value = "NONE", label = L["xpBarTextOutlineNone"] or NONE or "None" },
						{ value = "OUTLINE", label = L["xpBarTextOutlineNormal"] or "Outline" },
						{ value = "THICKOUTLINE", label = L["xpBarTextOutlineThick"] or "Thick outline" },
						{ value = "MONOCHROME", label = L["xpBarTextOutlineMono"] or "Monochrome" },
					}
					for _, option in ipairs(options) do
						root:CreateRadio(option.label, function() return ExperienceBar:GetTextOutline() == option.value end, function() applySetting("textOutline", option.value) end)
					end
				end,
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
			{
				name = L["xpBarTextColor"] or "Text color",
				kind = SettingType.Color,
				field = "textColor",
				default = defaults.textColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = ExperienceBar:GetTextColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("textColor", value) end,
				isEnabled = function() return ExperienceBar:GetTextEnabled() end,
			},
		}
	end

	local function seedEditModeRecordFromProfile(record)
		if type(record) ~= "table" then return end
		local src = ExperienceBar:BuildLayoutRecordFromProfile()
		for k, v in pairs(src) do
			record[k] = v
		end
	end

	EditMode:RegisterFrame(EDITMODE_ID, {
		frame = self:EnsureFrame(),
		title = L["ExperienceBar"] or "Experience Bar",
		layoutDefaults = {
			point = self:GetAnchorPoint(),
			relativePoint = self:GetAnchorRelativePoint(),
			x = self:GetAnchorOffsetX(),
			y = self:GetAnchorOffsetY(),
			width = self:GetWidth(),
			height = self:GetHeight(),
			texture = self:GetTextureKey(),
			bgEnabled = self:GetBackgroundEnabled(),
			bgTexture = self:GetBackgroundTextureKey(),
			bgColor = (function()
				local r, g, b, a = self:GetBackgroundColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			borderEnabled = self:GetBorderEnabled(),
			borderTexture = self:GetBorderTextureKey(),
			borderColor = (function()
				local r, g, b, a = self:GetBorderColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			borderSize = self:GetBorderSize(),
			borderOffset = self:GetBorderOffset(),
			fillDirection = self:GetFillDirection(),
			anchorRelativeFrame = self:GetAnchorRelativeFrame(),
			anchorMatchWidth = self:GetAnchorMatchWidth(),
			textEnabled = self:GetTextEnabled(),
			textLeftMode = self:GetTextLeftMode(),
			textCenterMode = self:GetTextCenterMode(),
			textRightMode = self:GetTextRightMode(),
			textMode = normalizeLegacyTextMode(self:GetTextCenterMode()),
			textSize = self:GetTextSize(),
			textFont = self:GetTextFont(),
			textOutline = self:GetTextOutline(),
			textColor = (function()
				local r, g, b, a = self:GetTextColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			hideInPetBattle = self:GetHideInPetBattle(),
			hideBlizzardTracking = self:GetHideBlizzardTracking(),
			color = (function()
				local r, g, b, a = self:GetColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			restedColor = (function()
				local r, g, b, a = self:GetRestedColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			restedOverlayEnabled = self:GetRestedOverlayEnabled(),
		},
		onApply = function(_, _, data)
			if not self._eqolEditModeHydrated then
				self._eqolEditModeHydrated = true
				local record = data or {}
				seedEditModeRecordFromProfile(record)
				ExperienceBar:ApplyLayoutData(record)
				return
			end
			ExperienceBar:ApplyLayoutData(data)
		end,
		onEnter = function() ExperienceBar:ShowEditModeHint(true) end,
		onExit = function() ExperienceBar:ShowEditModeHint(false) end,
		isEnabled = function() return addon.db and addon.db[DB_ENABLED] end,
		settings = settings,
		relativeTo = function() return ExperienceBar:ResolveAnchorFrame() end,
		allowDrag = function() return ExperienceBar:AnchorUsesUIParent() end,
		showOutsideEditMode = false,
		showReset = false,
		showSettingsReset = false,
		enableOverlayToggle = true,
	})

	editModeRegistered = true
end

function ExperienceBar:OnSettingChanged(enabled)
	if enabled then
		self:EnsureFrame()
		self:RegisterEditMode()
		registerEditModeCallbacks()
		self:RegisterEvents()
		self:ApplyLayoutData(self:BuildLayoutRecordFromProfile())
		self:RefreshAnchor()
		self:ApplySize()
		self:ApplyAppearance()
		self:UpdateXP()
		self:UpdateSoon()
	else
		self:UnregisterEvents()
		self:StopBootstrapRefresh()
		if self.frame then self.frame:Hide() end
		if self._anchorRefreshTicker then
			self._anchorRefreshTicker:Cancel()
			self._anchorRefreshTicker = nil
		end
		self:ApplyBlizzardTrackingVisibility()
	end

	if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
end

return ExperienceBar
