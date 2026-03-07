local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.MythicPlus = addon.MythicPlus or {}
addon.MythicPlus.functions = addon.MythicPlus.functions or {}
addon.MythicPlus.variables = addon.MythicPlus.variables or {}

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_MythicPlus")
local LCore = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local LSM = LibStub("LibSharedMedia-3.0")
local issecretvalue = _G.issecretvalue
local wipe = _G.wipe or (table and table.wipe)

local frameLoad = CreateFrame("Frame")

local brButton
local brAnchor
local bloodlustButton
local bloodlustAnchor
local defaultButtonSize = 60
local defaultFontSize = 16

local EditMode = addon.EditMode
local BR_EDITMODE_ID = "mythicPlusBRTracker"
local brEditModeRegistered = false
local BR_MIN_SIZE = 20
local BR_MAX_SIZE = 100

local BLOODLUST_EDITMODE_ID = "mythicPlusBloodlustTracker"
local bloodlustEditModeRegistered = false
local BLOODLUST_MIN_SIZE = 20
local BLOODLUST_MAX_SIZE = 100
local BLOODLUST_DEFAULT_ICON_IDS = {
	136090,
	458224,
}
local BLOODLUST_DEFAULT_ICON_SET = {}
for i = 1, #BLOODLUST_DEFAULT_ICON_IDS do
	BLOODLUST_DEFAULT_ICON_SET[BLOODLUST_DEFAULT_ICON_IDS[i]] = true
end
local BLOODLUST_BORDER_SIZE_MIN = 1
local BLOODLUST_BORDER_SIZE_MAX = 24
local BLOODLUST_BORDER_OFFSET_MIN = -20
local BLOODLUST_BORDER_OFFSET_MAX = 20
local BLOODLUST_PREVIEW_COOLDOWN_TEXT = "12.3"
local BLOODLUST_COOLDOWN_TEXT_SIZE_MIN = 8
local BLOODLUST_COOLDOWN_TEXT_SIZE_MAX = 64
local BLOODLUST_COOLDOWN_TEXT_OFFSET_MIN = -40
local BLOODLUST_COOLDOWN_TEXT_OFFSET_MAX = 40
local BLOODLUST_COOLDOWN_OUTLINE_OPTIONS = {
	"NONE",
	"OUTLINE",
	"THICKOUTLINE",
	"MONOCHROMEOUTLINE",
}
local BLOODLUST_COOLDOWN_OUTLINE_SET = {}
for i = 1, #BLOODLUST_COOLDOWN_OUTLINE_OPTIONS do
	BLOODLUST_COOLDOWN_OUTLINE_SET[BLOODLUST_COOLDOWN_OUTLINE_OPTIONS[i]] = true
end
local BLOODLUST_LOCKOUT_IDS = {
	57723, -- Exhaustion
	57724, -- Sated
	80354, -- Temporal Displacement
	95809, -- Hunter Pet Insanity
	160455, -- Hunter Pet Fatigued
	264689, -- Hunter Pet Fatigued
	390435, -- Exhaustion (declassified)
}
local BLOODLUST_LOCKOUT_SET = {}
for i = 1, #BLOODLUST_LOCKOUT_IDS do
	BLOODLUST_LOCKOUT_SET[BLOODLUST_LOCKOUT_IDS[i]] = true
end
local BLOODLUST_READY_SPELL_ID = 2825
local BLOODLUST_FALLBACK_ICON = BLOODLUST_DEFAULT_ICON_IDS[1]
local BLOODLUST_LOCKOUT_DURATION_SECONDS = 600
local BLOODLUST_ACTIVE_SOUND_GRACE_SECONDS = 10
local BLOODLUST_ACTIVE_SOUND_MIN_REMAINING = BLOODLUST_LOCKOUT_DURATION_SECONDS - BLOODLUST_ACTIVE_SOUND_GRACE_SECONDS
local BLOODLUST_READY_CLASSES = {
	SHAMAN = true,
	HUNTER = true,
	MAGE = true,
	EVOKER = true,
}
local BLOODLUST_GLOBAL_FONT_KEY = addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__"
local BLOODLUST_GLOBAL_FONT_LABEL = addon.functions and addon.functions.GetGlobalFontConfigLabel and addon.functions.GetGlobalFontConfigLabel() or "Use global font config"
local bloodlustTrackedAuraInstanceIDs = {}
local bloodlustStateActive = false
local bloodlustStateInitialized = false
local bloodlustCooldownDeferredApplyPending = false
local bloodlustUnitAuraRegistered = false

local function normalizeBRSize(value)
	local size = tonumber(value) or defaultButtonSize
	size = math.floor(size + 0.5)
	if size < BR_MIN_SIZE then size = BR_MIN_SIZE end
	if size > BR_MAX_SIZE then size = BR_MAX_SIZE end
	return size
end

local function removeBRFrame()
	if brButton then
		brButton:Hide()
		brButton:SetParent(nil)
		brButton:SetScript("OnClick", nil)
		brButton:SetScript("OnEnter", nil)
		brButton:SetScript("OnLeave", nil)
		brButton:SetScript("OnUpdate", nil)
		brButton:SetScript("OnEvent", nil)
		brButton:SetScript("OnDragStart", nil)
		brButton:SetScript("OnDragStop", nil)
		brButton:UnregisterAllEvents()
		brButton:ClearAllPoints()
		brButton = nil
	end
end

local function isRaidDifficulty(d) return d == 14 or d == 15 or d == 16 or d == 17 end

local function safeRegisterUnitEvent(frame, event, ...)
	if not frame or not frame.RegisterUnitEvent or type(event) ~= "string" then return false end
	local ok = pcall(frame.RegisterUnitEvent, frame, event, ...)
	return ok
end

local function setFrameClickThrough(frame)
	if not frame then return end
	frame:EnableMouse(false)
	if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
	if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
end

local function syncBloodlustUnitAuraRegistration()
	local enabled = addon and addon.db and addon.db["mythicPlusBloodlustTrackerEnabled"] == true

	if enabled then
		if bloodlustUnitAuraRegistered then return end
		bloodlustUnitAuraRegistered = safeRegisterUnitEvent(frameLoad, "UNIT_AURA", "player") == true
		return
	end

	if not bloodlustUnitAuraRegistered then return end
	frameLoad:UnregisterEvent("UNIT_AURA")
	bloodlustUnitAuraRegistered = false
end

local function buildBRLayoutSnapshot()
	return {
		point = addon.db["mythicPlusBRTrackerPoint"] or "CENTER",
		relativePoint = addon.db["mythicPlusBRTrackerPoint"] or "CENTER",
		x = addon.db["mythicPlusBRTrackerX"] or 0,
		y = addon.db["mythicPlusBRTrackerY"] or 0,
		size = normalizeBRSize(addon.db["mythicPlusBRButtonSize"] or defaultButtonSize),
	}
end

local function seedBREditModeRecordFromProfile(record)
	if type(record) ~= "table" then return end
	local snapshot = buildBRLayoutSnapshot()
	record.point = snapshot.point or "CENTER"
	record.relativePoint = snapshot.relativePoint or record.point
	record.x = snapshot.x or 0
	record.y = snapshot.y or 0
	record.size = snapshot.size or defaultButtonSize
end

local function applyBRLayoutData(data)
	local config = data or buildBRLayoutSnapshot()

	local point = config.point or addon.db["mythicPlusBRTrackerPoint"] or "CENTER"
	local relativePoint = config.relativePoint or point
	local x = config.x
	if x == nil then x = addon.db["mythicPlusBRTrackerX"] or 0 end
	local y = config.y
	if y == nil then y = addon.db["mythicPlusBRTrackerY"] or 0 end
	-- Size is addon-profile-owned and must not be overwritten by EditMode apply payload.
	local size = normalizeBRSize(addon.db["mythicPlusBRButtonSize"] or config.size or defaultButtonSize)

	if addon.db then
		addon.db["mythicPlusBRTrackerPoint"] = point
		addon.db["mythicPlusBRTrackerX"] = x
		addon.db["mythicPlusBRTrackerY"] = y
		addon.db["mythicPlusBRButtonSize"] = size
	end

	if brAnchor then
		brAnchor:SetSize(size, size)
		brAnchor:ClearAllPoints()
		brAnchor:SetPoint(point, UIParent, relativePoint, x, y)
	end

	if brButton then
		brButton:SetSize(size, size)
		brButton:ClearAllPoints()
		brButton:SetPoint(point, UIParent, relativePoint, x, y)

		local scaleFactor = size / defaultButtonSize
		local newFontSize = math.floor(defaultFontSize * scaleFactor + 0.5)

		if brButton.cooldownFrame then brButton.cooldownFrame:SetScale(scaleFactor) end
		if brButton.charges then brButton.charges:SetFont(addon.variables.defaultFont, newFontSize, "OUTLINE") end
	end
end

local function ensureBRAnchor()
	if not brAnchor then
		brAnchor = CreateFrame("Frame", "EnhanceQoLMythicPlusBRAnchor", UIParent)
		brAnchor:SetClampedToScreen(true)
		brAnchor:SetMovable(true)
		brAnchor:EnableMouse(true)

		local bg = brAnchor:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.1, 0.6, 0.6, 0.35)
		brAnchor.bg = bg

		local border = brAnchor:CreateTexture(nil, "OVERLAY")
		border:SetAllPoints()
		border:SetTexture("Interface\\BUTTONS\\UI-Quickslot2")
		border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
		border:SetVertexColor(0.1, 0.6, 0.6, 0.7)
		brAnchor.border = border

		brAnchor.label = brAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		brAnchor.label:SetPoint("CENTER")
		brAnchor.label:SetText(L["mythicPlusBRTrackerAnchor"])
	end

	if EditMode and not brEditModeRegistered then
		local settingType = EditMode.lib and EditMode.lib.SettingType
		local settings
		if settingType then
			settings = {
				{
					field = "size",
					name = L["mythicPlusBRButtonSizeHeadline"],
					kind = settingType.Slider,
					minValue = BR_MIN_SIZE,
					maxValue = BR_MAX_SIZE,
					valueStep = 1,
					default = normalizeBRSize(addon.db["mythicPlusBRButtonSize"] or defaultButtonSize),
					get = function() return normalizeBRSize(addon.db["mythicPlusBRButtonSize"] or defaultButtonSize) end,
					set = function(_, value)
						local size = normalizeBRSize(value)
						addon.db["mythicPlusBRButtonSize"] = size
						if EditMode and EditMode.SetValue then EditMode:SetValue(BR_EDITMODE_ID, "size", size, nil, true) end
						applyBRLayoutData()
					end,
				},
			}
		end

		EditMode:RegisterFrame(BR_EDITMODE_ID, {
			frame = brAnchor,
			title = L["mythicPlusBRTrackerAnchor"],
			layoutDefaults = {
				point = addon.db["mythicPlusBRTrackerPoint"] or "CENTER",
				relativePoint = addon.db["mythicPlusBRTrackerPoint"] or "CENTER",
				x = addon.db["mythicPlusBRTrackerX"] or 0,
				y = addon.db["mythicPlusBRTrackerY"] or 0,
				size = addon.db["mythicPlusBRButtonSize"] or defaultButtonSize,
			},
			legacyKeys = {
				point = "mythicPlusBRTrackerPoint",
				relativePoint = "mythicPlusBRTrackerPoint",
				x = "mythicPlusBRTrackerX",
				y = "mythicPlusBRTrackerY",
				size = "mythicPlusBRButtonSize",
			},
			isEnabled = function() return addon.db["mythicPlusBRTrackerEnabled"] end,
			onApply = function(_, layoutName, data)
				if not brAnchor._eqolEditModeHydrated then
					brAnchor._eqolEditModeHydrated = true
					local record = data or {}
					seedBREditModeRecordFromProfile(record)
					if EditMode and EditMode.SetFramePosition then
						EditMode:SetFramePosition(BR_EDITMODE_ID, record.point or "CENTER", record.x or 0, record.y or 0, layoutName)
						return
					end
				end
				applyBRLayoutData(data)
			end,
			settings = settings,
		})
		brEditModeRegistered = true
	else
		applyBRLayoutData()
	end

	return brAnchor
end

local function shouldShowBRTracker()
	if not addon.db["mythicPlusBRTrackerEnabled"] then return false end
	if not IsInInstance() then return false end
	local _, _, diff = GetInstanceInfo()
	if diff == 8 then return true end
	if isRaidDifficulty(diff) then return IsEncounterInProgress() end
	return false
end

local function createBRFrame()
	removeBRFrame()
	if not addon.db["mythicPlusBRTrackerEnabled"] then
		if brAnchor then brAnchor:Hide() end
		if EditMode then EditMode:RefreshFrame(BR_EDITMODE_ID) end
		return
	end
	local layout = buildBRLayoutSnapshot()
	ensureBRAnchor()
	if IsInGroup() and shouldShowBRTracker() then
		local point = layout.point or "CENTER"
		local relativePoint = layout.relativePoint or point
		local xOfs = layout.x or 0
		local yOfs = layout.y or 0
		local size = layout.size or defaultButtonSize

		brButton = CreateFrame("Button", nil, UIParent)
		brButton:SetSize(size, size)
		brButton:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
		setFrameClickThrough(brButton)

		local bg = brButton:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(brButton)
		bg:SetColorTexture(0, 0, 0, 0.8)

		local icon = brButton:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints(brButton)
		icon:SetTexture(136080)
		brButton.icon = icon

		local scaleFactor = size / defaultButtonSize
		local newFontSize = math.floor(defaultFontSize * scaleFactor + 0.5)

		brButton.cooldownFrame = CreateFrame("Cooldown", nil, brButton, "CooldownFrameTemplate")
		brButton.cooldownFrame:SetAllPoints(brButton)
		brButton.cooldownFrame.cooldownSet = false
		brButton.cooldownFrame:SetSwipeColor(0, 0, 0, 0.3)
		brButton.cooldownFrame:SetCountdownAbbrevThreshold(600)
		brButton.cooldownFrame:SetScale(scaleFactor)
		brButton.cooldownFrame:SetDrawEdge(false)

		brButton.charges = brButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		brButton.charges:SetPoint("BOTTOMRIGHT", brButton, "BOTTOMRIGHT", -3, 3)
		brButton.charges:SetFont(addon.variables.defaultFont, newFontSize, "OUTLINE")
	end
	applyBRLayoutData(layout)
	if EditMode then EditMode:RefreshFrame(BR_EDITMODE_ID) end
end

addon.MythicPlus.functions.createBRFrame = createBRFrame

local function normalizeBloodlustSize(value)
	local size = tonumber(value) or defaultButtonSize
	size = math.floor(size + 0.5)
	if size < BLOODLUST_MIN_SIZE then size = BLOODLUST_MIN_SIZE end
	if size > BLOODLUST_MAX_SIZE then size = BLOODLUST_MAX_SIZE end
	return size
end

local function normalizeBloodlustIcon(value)
	local iconId = tonumber(value)
	if iconId and BLOODLUST_DEFAULT_ICON_SET[iconId] then return iconId end
	return BLOODLUST_DEFAULT_ICON_IDS[1]
end

local function getBloodlustConfiguredIcon() return normalizeBloodlustIcon(addon.db and addon.db["mythicPlusBloodlustTrackerIcon"]) end

local function isLikelyFilePath(value)
	if type(value) ~= "string" or value == "" then return false end
	return value:find("/", 1, true) ~= nil or value:find("\\", 1, true) ~= nil
end

local function getCachedMediaHash(mediaType)
	if addon.functions and addon.functions.GetLSMMediaHash then
		local hash = addon.functions.GetLSMMediaHash(mediaType)
		if type(hash) == "table" then return hash end
	end
	return {}
end

local function getCachedMediaNames(mediaType)
	if addon.functions and addon.functions.GetLSMMediaNames then
		local names = addon.functions.GetLSMMediaNames(mediaType)
		if type(names) == "table" then return names end
	end

	local names = {}
	for name in pairs(getCachedMediaHash(mediaType)) do
		if type(name) == "string" and name ~= "" then names[#names + 1] = name end
	end
	table.sort(names, function(a, b)
		local al = string.lower(a)
		local bl = string.lower(b)
		if al == bl then return a < b end
		return al < bl
	end)
	return names
end

local function normalizeBloodlustBorderTexture(value)
	if type(value) ~= "string" or value == "" then return "DEFAULT" end
	if value == "DEFAULT" or value == "SOLID" then return value end
	return value
end

local function resolveBloodlustBorderTexture(value)
	local key = normalizeBloodlustBorderTexture(value)
	if key == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if key == "DEFAULT" then return "Interface\\Buttons\\WHITE8x8" end
	if isLikelyFilePath(key) then return key end
	if LSM and LSM.Fetch then
		local tex = LSM:Fetch("border", key, true)
		if tex then return tex end
	end
	return "Interface\\Buttons\\WHITE8x8"
end

local function normalizeBloodlustBorderSize(value)
	local size = tonumber(value) or 1
	size = math.floor(size + 0.5)
	if size < BLOODLUST_BORDER_SIZE_MIN then size = BLOODLUST_BORDER_SIZE_MIN end
	if size > BLOODLUST_BORDER_SIZE_MAX then size = BLOODLUST_BORDER_SIZE_MAX end
	return size
end

local function normalizeBloodlustBorderOffset(value)
	local offset = tonumber(value) or 0
	offset = math.floor(offset + 0.5)
	if offset < BLOODLUST_BORDER_OFFSET_MIN then offset = BLOODLUST_BORDER_OFFSET_MIN end
	if offset > BLOODLUST_BORDER_OFFSET_MAX then offset = BLOODLUST_BORDER_OFFSET_MAX end
	return offset
end

local function normalizeBloodlustBorderColor(value)
	local color = value
	if type(color) ~= "table" then color = { 1, 1, 1, 1 } end
	local r = tonumber(color.r or color[1]) or 1
	local g = tonumber(color.g or color[2]) or 1
	local b = tonumber(color.b or color[3]) or 1
	local a = tonumber(color.a or color[4]) or 1
	if r < 0 then r = 0 end
	if r > 1 then r = 1 end
	if g < 0 then g = 0 end
	if g > 1 then g = 1 end
	if b < 0 then b = 0 end
	if b > 1 then b = 1 end
	if a < 0 then a = 0 end
	if a > 1 then a = 1 end
	return { r, g, b, a }
end

local function normalizeBloodlustCooldownTextSize(value)
	local size = tonumber(value) or 16
	size = math.floor(size + 0.5)
	if size < BLOODLUST_COOLDOWN_TEXT_SIZE_MIN then size = BLOODLUST_COOLDOWN_TEXT_SIZE_MIN end
	if size > BLOODLUST_COOLDOWN_TEXT_SIZE_MAX then size = BLOODLUST_COOLDOWN_TEXT_SIZE_MAX end
	return size
end

local function normalizeBloodlustCooldownTextOffset(value)
	local offset = tonumber(value) or 0
	offset = math.floor(offset + 0.5)
	if offset < BLOODLUST_COOLDOWN_TEXT_OFFSET_MIN then offset = BLOODLUST_COOLDOWN_TEXT_OFFSET_MIN end
	if offset > BLOODLUST_COOLDOWN_TEXT_OFFSET_MAX then offset = BLOODLUST_COOLDOWN_TEXT_OFFSET_MAX end
	return offset
end

local function normalizeBloodlustCooldownOutline(value)
	if type(value) == "string" and BLOODLUST_COOLDOWN_OUTLINE_SET[value] then return value end
	return "OUTLINE"
end

local function normalizeBloodlustCooldownColor(value)
	local color = value
	if type(color) ~= "table" then color = { 1, 1, 1, 1 } end
	local r = tonumber(color.r or color[1]) or 1
	local g = tonumber(color.g or color[2]) or 1
	local b = tonumber(color.b or color[3]) or 1
	local a = tonumber(color.a or color[4]) or 1
	if r < 0 then r = 0 end
	if r > 1 then r = 1 end
	if g < 0 then g = 0 end
	if g > 1 then g = 1 end
	if b < 0 then b = 0 end
	if b > 1 then b = 1 end
	if a < 0 then a = 0 end
	if a > 1 then a = 1 end
	return { r, g, b, a }
end

local function normalizeBloodlustCooldownFontFace(value)
	if type(value) ~= "string" or value == "" then return BLOODLUST_GLOBAL_FONT_KEY end
	if value == BLOODLUST_GLOBAL_FONT_KEY then return value end
	return value
end

local function resolveBloodlustCooldownFontFace()
	local configured = normalizeBloodlustCooldownFontFace(addon.db and addon.db["mythicPlusBloodlustTrackerCooldownFontFace"])
	local localeFallback = addon.functions and addon.functions.GetLocaleDefaultFontFace and addon.functions.GetLocaleDefaultFontFace()
	local fallback = localeFallback or addon.variables.defaultFont or STANDARD_TEXT_FONT
	if addon.functions and addon.functions.ResolveFontFace then return addon.functions.ResolveFontFace(configured, fallback) end
	if configured == BLOODLUST_GLOBAL_FONT_KEY then return fallback end
	return configured
end

local function applyBloodlustAnchorPreviewIcon()
	if not (bloodlustAnchor and bloodlustAnchor.previewIcon) then return end
	bloodlustAnchor.previewIcon:SetTexture(getBloodlustConfiguredIcon())
end

local function applyBloodlustBorderFrame(frame, target, enabled, textureKey, borderSize, borderOffset, borderColor)
	if not frame or not target or not frame.SetBackdrop then return end
	if not enabled then
		frame:SetBackdrop(nil)
		frame:Hide()
		return
	end

	frame:SetBackdrop({
		edgeFile = resolveBloodlustBorderTexture(textureKey),
		edgeSize = borderSize,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	frame:SetBackdropColor(0, 0, 0, 0)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", target, "TOPLEFT", -borderOffset, borderOffset)
	frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", borderOffset, -borderOffset)
	frame:Show()
end

local function applyBloodlustBorderVisualSettings()
	local db = addon.db or {}
	local enabled = db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false
	local textureKey = normalizeBloodlustBorderTexture(db["mythicPlusBloodlustTrackerBorderTexture"])
	local borderSize = normalizeBloodlustBorderSize(db["mythicPlusBloodlustTrackerBorderSize"])
	local borderOffset = normalizeBloodlustBorderOffset(db["mythicPlusBloodlustTrackerBorderOffset"])
	local borderColor = normalizeBloodlustBorderColor(db["mythicPlusBloodlustTrackerBorderColor"])

	if bloodlustAnchor and bloodlustAnchor.previewBorder and bloodlustAnchor.previewIcon then
		applyBloodlustBorderFrame(bloodlustAnchor.previewBorder, bloodlustAnchor.previewIcon, enabled, textureKey, borderSize, borderOffset, borderColor)
	end
	if bloodlustButton and bloodlustButton.border then applyBloodlustBorderFrame(bloodlustButton.border, bloodlustButton, enabled, textureKey, borderSize, borderOffset, borderColor) end
end

local function applyBloodlustCooldownTextStyle(fontString, anchorFrame, db)
	if not fontString or not anchorFrame then return end
	local fontFace = resolveBloodlustCooldownFontFace()
	local fontSize = normalizeBloodlustCooldownTextSize(db["mythicPlusBloodlustTrackerCooldownTextSize"])
	local outlineValue = normalizeBloodlustCooldownOutline(db["mythicPlusBloodlustTrackerCooldownTextOutline"])
	local outlineFlags = outlineValue == "NONE" and "" or outlineValue
	local ok = fontString:SetFont(fontFace, fontSize, outlineFlags)
	if ok == false then
		local fallback = addon.variables.defaultFont or STANDARD_TEXT_FONT
		fontString:SetFont(fallback, fontSize, outlineFlags)
	end
	local color = normalizeBloodlustCooldownColor(db["mythicPlusBloodlustTrackerCooldownTextColor"])
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
	fontString:ClearAllPoints()
	fontString:SetPoint(
		"CENTER",
		anchorFrame,
		"CENTER",
		normalizeBloodlustCooldownTextOffset(db["mythicPlusBloodlustTrackerCooldownTextOffsetX"]),
		normalizeBloodlustCooldownTextOffset(db["mythicPlusBloodlustTrackerCooldownTextOffsetY"])
	)
end

local function applyBloodlustLiveCooldownTextStyle(deferIfMissing)
	if not (bloodlustButton and bloodlustButton.cooldownFrame) then return false end
	local cooldown = bloodlustButton.cooldownFrame
	local fontString = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
	if fontString then
		applyBloodlustCooldownTextStyle(fontString, cooldown, addon.db or {})
		return true
	end

	if deferIfMissing and not bloodlustCooldownDeferredApplyPending and C_Timer and C_Timer.After then
		bloodlustCooldownDeferredApplyPending = true
		C_Timer.After(0, function()
			bloodlustCooldownDeferredApplyPending = false
			if not (bloodlustButton and bloodlustButton.cooldownFrame) then return end
			local deferredCooldown = bloodlustButton.cooldownFrame
			local deferredFontString = deferredCooldown.GetCountdownFontString and deferredCooldown:GetCountdownFontString()
			if deferredFontString then applyBloodlustCooldownTextStyle(deferredFontString, deferredCooldown, addon.db or {}) end
		end)
	end

	return false
end

local function applyBloodlustCooldownVisualSettings()
	local db = addon.db or {}
	if bloodlustButton and bloodlustButton.cooldownFrame then
		local cooldown = bloodlustButton.cooldownFrame
		if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(db["mythicPlusBloodlustTrackerCooldownDrawSwipe"] ~= false) end
		if cooldown.SetDrawEdge then cooldown:SetDrawEdge(db["mythicPlusBloodlustTrackerCooldownDrawEdge"] == true) end
		if cooldown.SetDrawBling then cooldown:SetDrawBling(db["mythicPlusBloodlustTrackerCooldownDrawBling"] == true) end
		applyBloodlustLiveCooldownTextStyle(true)
	end
	if bloodlustAnchor and bloodlustAnchor.previewCooldownText and bloodlustAnchor.previewIcon then
		applyBloodlustCooldownTextStyle(bloodlustAnchor.previewCooldownText, bloodlustAnchor.previewIcon, db)
		bloodlustAnchor.previewCooldownText:SetText(BLOODLUST_PREVIEW_COOLDOWN_TEXT)
		bloodlustAnchor.previewCooldownText:Show()
	end
end

local function refreshBloodlustMedia(mediaType)
	if mediaType == "border" then
		applyBloodlustBorderVisualSettings()
	elseif mediaType == "font" then
		applyBloodlustCooldownVisualSettings()
	end
end

addon.MythicPlus.functions.refreshBloodlustMedia = refreshBloodlustMedia

local function removeBloodlustFrame()
	if bloodlustButton then
		bloodlustCooldownDeferredApplyPending = false
		bloodlustButton:Hide()
		bloodlustButton:SetParent(nil)
		bloodlustButton:SetScript("OnClick", nil)
		bloodlustButton:SetScript("OnEnter", nil)
		bloodlustButton:SetScript("OnLeave", nil)
		bloodlustButton:SetScript("OnUpdate", nil)
		bloodlustButton:SetScript("OnEvent", nil)
		bloodlustButton:SetScript("OnDragStart", nil)
		bloodlustButton:SetScript("OnDragStop", nil)
		bloodlustButton:UnregisterAllEvents()
		bloodlustButton:ClearAllPoints()
		bloodlustButton = nil
	end
end

local function buildBloodlustLayoutSnapshot()
	return {
		point = addon.db["mythicPlusBloodlustTrackerPoint"] or "CENTER",
		relativePoint = addon.db["mythicPlusBloodlustTrackerPoint"] or "CENTER",
		x = addon.db["mythicPlusBloodlustTrackerX"] or 0,
		y = addon.db["mythicPlusBloodlustTrackerY"] or 0,
		size = normalizeBloodlustSize(addon.db["mythicPlusBloodlustButtonSize"] or defaultButtonSize),
	}
end

local function seedBloodlustEditModeRecordFromProfile(record)
	if type(record) ~= "table" then return end
	local snapshot = buildBloodlustLayoutSnapshot()
	record.point = snapshot.point or "CENTER"
	record.relativePoint = snapshot.relativePoint or record.point
	record.x = snapshot.x or 0
	record.y = snapshot.y or 0
	record.size = snapshot.size or defaultButtonSize
end

local function applyBloodlustLayoutData(data)
	local config = data or buildBloodlustLayoutSnapshot()
	local point = config.point or addon.db["mythicPlusBloodlustTrackerPoint"] or "CENTER"
	local relativePoint = config.relativePoint or point
	local x = config.x
	if x == nil then x = addon.db["mythicPlusBloodlustTrackerX"] or 0 end
	local y = config.y
	if y == nil then y = addon.db["mythicPlusBloodlustTrackerY"] or 0 end
	local size = normalizeBloodlustSize(addon.db["mythicPlusBloodlustButtonSize"] or config.size or defaultButtonSize)
	local iconId = normalizeBloodlustIcon(addon.db["mythicPlusBloodlustTrackerIcon"])
	local cooldownTextSize = normalizeBloodlustCooldownTextSize(addon.db["mythicPlusBloodlustTrackerCooldownTextSize"])
	local cooldownTextOutline = normalizeBloodlustCooldownOutline(addon.db["mythicPlusBloodlustTrackerCooldownTextOutline"])
	local cooldownTextColor = normalizeBloodlustCooldownColor(addon.db["mythicPlusBloodlustTrackerCooldownTextColor"])
	local cooldownTextOffsetX = normalizeBloodlustCooldownTextOffset(addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetX"])
	local cooldownTextOffsetY = normalizeBloodlustCooldownTextOffset(addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetY"])
	local cooldownFontFace = normalizeBloodlustCooldownFontFace(addon.db["mythicPlusBloodlustTrackerCooldownFontFace"])
	local borderEnabled = addon.db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false
	local borderTexture = normalizeBloodlustBorderTexture(addon.db["mythicPlusBloodlustTrackerBorderTexture"])
	local borderSize = normalizeBloodlustBorderSize(addon.db["mythicPlusBloodlustTrackerBorderSize"])
	local borderOffset = normalizeBloodlustBorderOffset(addon.db["mythicPlusBloodlustTrackerBorderOffset"])
	local borderColor = normalizeBloodlustBorderColor(addon.db["mythicPlusBloodlustTrackerBorderColor"])

	if addon.db then
		addon.db["mythicPlusBloodlustTrackerPoint"] = point
		addon.db["mythicPlusBloodlustTrackerX"] = x
		addon.db["mythicPlusBloodlustTrackerY"] = y
		addon.db["mythicPlusBloodlustButtonSize"] = size
		addon.db["mythicPlusBloodlustTrackerIcon"] = iconId
		addon.db["mythicPlusBloodlustTrackerCooldownTextSize"] = cooldownTextSize
		addon.db["mythicPlusBloodlustTrackerCooldownTextOutline"] = cooldownTextOutline
		addon.db["mythicPlusBloodlustTrackerCooldownTextColor"] = cooldownTextColor
		addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetX"] = cooldownTextOffsetX
		addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetY"] = cooldownTextOffsetY
		addon.db["mythicPlusBloodlustTrackerCooldownFontFace"] = cooldownFontFace
		addon.db["mythicPlusBloodlustTrackerBorderEnabled"] = borderEnabled
		addon.db["mythicPlusBloodlustTrackerBorderTexture"] = borderTexture
		addon.db["mythicPlusBloodlustTrackerBorderSize"] = borderSize
		addon.db["mythicPlusBloodlustTrackerBorderOffset"] = borderOffset
		addon.db["mythicPlusBloodlustTrackerBorderColor"] = borderColor
	end

	if bloodlustAnchor then
		bloodlustAnchor:SetSize(size, size)
		bloodlustAnchor:ClearAllPoints()
		bloodlustAnchor:SetPoint(point, UIParent, relativePoint, x, y)
		if bloodlustAnchor.previewIcon then bloodlustAnchor.previewIcon:SetAllPoints(bloodlustAnchor) end
		applyBloodlustAnchorPreviewIcon()
	end

	if bloodlustButton then
		bloodlustButton:SetSize(size, size)
		bloodlustButton:ClearAllPoints()
		bloodlustButton:SetPoint(point, UIParent, relativePoint, x, y)
		local scaleFactor = size / defaultButtonSize
		local timerFontSize = math.floor(defaultFontSize * 0.75 * scaleFactor + 0.5)
		if timerFontSize < 10 then timerFontSize = 10 end
		bloodlustButton.defaultIcon = iconId
		if bloodlustButton.status then bloodlustButton.status:SetFont(addon.variables.defaultFont, timerFontSize, "OUTLINE") end
		if bloodlustButton.cooldownFrame then bloodlustButton.cooldownFrame:SetScale(1) end
	end
	-- Always apply text styling so Edit Mode preview updates even without a live tracker button.
	applyBloodlustCooldownVisualSettings()
	applyBloodlustBorderVisualSettings()
end

local function ensureBloodlustAnchor()
	if not bloodlustAnchor then
		bloodlustAnchor = CreateFrame("Frame", "EnhanceQoLMythicPlusBloodlustAnchor", UIParent)
		bloodlustAnchor:SetClampedToScreen(true)
		bloodlustAnchor:SetMovable(true)
		bloodlustAnchor:EnableMouse(true)

		local bg = bloodlustAnchor:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.5)
		bloodlustAnchor.bg = bg

		bloodlustAnchor.previewIcon = bloodlustAnchor:CreateTexture(nil, "ARTWORK")
		bloodlustAnchor.previewIcon:SetAllPoints(bloodlustAnchor)
		bloodlustAnchor.previewIcon:SetTexture(getBloodlustConfiguredIcon())
		bloodlustAnchor.previewIcon:SetTexCoord(0, 1, 0, 1)

		bloodlustAnchor.previewBorder = CreateFrame("Frame", nil, bloodlustAnchor, "BackdropTemplate")
		bloodlustAnchor.previewBorder:SetFrameLevel((bloodlustAnchor:GetFrameLevel() or 0) + 4)
		bloodlustAnchor.previewBorder:SetFrameStrata(bloodlustAnchor:GetFrameStrata())

		bloodlustAnchor.previewCooldownText = bloodlustAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bloodlustAnchor.previewCooldownText:SetPoint("CENTER", bloodlustAnchor, "CENTER", 0, 0)
		bloodlustAnchor.previewCooldownText:SetText(BLOODLUST_PREVIEW_COOLDOWN_TEXT)
		bloodlustAnchor.previewCooldownText:Show()

		bloodlustAnchor.label = bloodlustAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		bloodlustAnchor.label:SetPoint("CENTER")
		bloodlustAnchor.label:SetText(L["mythicPlusBloodlustTrackerAnchor"] or "Bloodlust Tracker Anchor")
		bloodlustAnchor.label:SetAlpha(0)
	end

	if EditMode and not bloodlustEditModeRegistered then
		local settingType = EditMode.lib and EditMode.lib.SettingType
		local settings
		if settingType then
			local function buildSoundEntries()
				local entries = getCachedMediaNames("sound")
				local soundTable = getCachedMediaHash("sound")
				return entries, soundTable
			end

			local function getStoredSoundKey(dbKey)
				local entries, soundTable = buildSoundEntries()
				local current = addon.db and addon.db[dbKey]
				if type(current) == "string" and current ~= "" and soundTable[current] then return current, entries, soundTable end
				return "", entries, soundTable
			end

			local function setStoredSoundKey(dbKey, value, preview)
				local current, _, soundTable = getStoredSoundKey(dbKey)
				local selected = type(value) == "string" and value or ""
				if selected ~= "" and not soundTable[selected] then selected = "" end
				if addon.db then addon.db[dbKey] = selected end
				if preview and selected ~= "" and soundTable[selected] then PlaySoundFile(soundTable[selected], "Master") end
				return current
			end

			local function buildFontEntries()
				local entries = getCachedMediaNames("font")
				local fontTable = getCachedMediaHash("font")
				return entries, fontTable
			end

			local function buildBorderEntries()
				local entries = {
					{ value = "DEFAULT", label = _G.DEFAULT or "Default" },
					{ value = "SOLID", label = "Solid" },
				}
				local names = getCachedMediaNames("border")
				for i = 1, #names do
					local name = names[i]
					entries[#entries + 1] = { value = name, label = name }
				end
				return entries
			end

			local function getStoredFontKey()
				local entries, fontTable = buildFontEntries()
				local current = normalizeBloodlustCooldownFontFace(addon.db and addon.db["mythicPlusBloodlustTrackerCooldownFontFace"])
				if current ~= BLOODLUST_GLOBAL_FONT_KEY and not (fontTable and fontTable[current]) and not (current:find("\\", 1, true) or current:find("/", 1, true)) then
					current = BLOODLUST_GLOBAL_FONT_KEY
				end
				return current, entries, fontTable
			end

			local function setStoredFontKey(value)
				local selected = normalizeBloodlustCooldownFontFace(value)
				if addon.db then addon.db["mythicPlusBloodlustTrackerCooldownFontFace"] = selected end
				applyBloodlustCooldownVisualSettings()
			end

			local function outlineOptionLabel(value)
				if value == "NONE" then return (LCore and LCore["fontOutlineNone"]) or NONE end
				if value == "OUTLINE" then return (LCore and LCore["fontOutlineThin"]) or "Outline" end
				if value == "THICKOUTLINE" then return (LCore and LCore["fontOutlineThick"]) or "Thick Outline" end
				if value == "MONOCHROMEOUTLINE" then return (LCore and LCore["fontOutlineMono"]) or "Monochrome Outline" end
				return value
			end

			settings = {
				{
					field = "size",
					name = L["mythicPlusBloodlustButtonSizeHeadline"] or (L["mythicPlusBRButtonSizeHeadline"] or "Button Size"),
					kind = settingType.Slider,
					minValue = BLOODLUST_MIN_SIZE,
					maxValue = BLOODLUST_MAX_SIZE,
					valueStep = 1,
					default = normalizeBloodlustSize(addon.db["mythicPlusBloodlustButtonSize"] or defaultButtonSize),
					get = function() return normalizeBloodlustSize(addon.db["mythicPlusBloodlustButtonSize"] or defaultButtonSize) end,
					set = function(_, value)
						local size = normalizeBloodlustSize(value)
						addon.db["mythicPlusBloodlustButtonSize"] = size
						if EditMode and EditMode.SetValue then EditMode:SetValue(BLOODLUST_EDITMODE_ID, "size", size, nil, true) end
						applyBloodlustLayoutData()
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerIcon"] or "Tracker icon",
					kind = settingType.Dropdown,
					get = function() return normalizeBloodlustIcon(addon.db and addon.db["mythicPlusBloodlustTrackerIcon"]) end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerIcon"] = normalizeBloodlustIcon(value) end
						applyBloodlustLayoutData()
						if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.refreshBloodlustTracker then addon.MythicPlus.functions.refreshBloodlustTracker(false) end
					end,
					generator = function(_, root)
						for i = 1, #BLOODLUST_DEFAULT_ICON_IDS do
							local iconId = BLOODLUST_DEFAULT_ICON_IDS[i]
							local label = string.format("|T%d:22:22:0:0|t", iconId)
							root:CreateRadio(label, function() return normalizeBloodlustIcon(addon.db and addon.db["mythicPlusBloodlustTrackerIcon"]) == iconId end, function()
								if addon.db then addon.db["mythicPlusBloodlustTrackerIcon"] = iconId end
								applyBloodlustLayoutData()
								if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.refreshBloodlustTracker then
									addon.MythicPlus.functions.refreshBloodlustTracker(false)
								end
							end)
						end
					end,
				},
				{
					name = "",
					kind = settingType.Divider,
				},
				{
					name = L["mythicPlusBloodlustTrackerBorderEnabled"] or "Use border",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerBorderEnabled"] = value == true end
						applyBloodlustBorderVisualSettings()
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerBorderTexture"] or "Border texture",
					kind = settingType.Dropdown,
					height = 220,
					get = function() return normalizeBloodlustBorderTexture(addon.db and addon.db["mythicPlusBloodlustTrackerBorderTexture"]) end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerBorderTexture"] = normalizeBloodlustBorderTexture(value) end
						applyBloodlustBorderVisualSettings()
					end,
					generator = function(_, root)
						local options = buildBorderEntries()
						for i = 1, #options do
							local option = options[i]
							root:CreateRadio(
								option.label,
								function() return normalizeBloodlustBorderTexture(addon.db and addon.db["mythicPlusBloodlustTrackerBorderTexture"]) == option.value end,
								function()
									if addon.db then addon.db["mythicPlusBloodlustTrackerBorderTexture"] = option.value end
									applyBloodlustBorderVisualSettings()
								end
							)
						end
					end,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false end,
				},
				{
					name = L["mythicPlusBloodlustTrackerBorderSize"] or "Border size",
					kind = settingType.Slider,
					minValue = BLOODLUST_BORDER_SIZE_MIN,
					maxValue = BLOODLUST_BORDER_SIZE_MAX,
					valueStep = 1,
					default = normalizeBloodlustBorderSize(addon.db and addon.db["mythicPlusBloodlustTrackerBorderSize"]),
					get = function() return normalizeBloodlustBorderSize(addon.db and addon.db["mythicPlusBloodlustTrackerBorderSize"]) end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerBorderSize"] = normalizeBloodlustBorderSize(value) end
						applyBloodlustBorderVisualSettings()
					end,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false end,
				},
				{
					name = L["mythicPlusBloodlustTrackerBorderOffset"] or "Border offset",
					kind = settingType.Slider,
					minValue = BLOODLUST_BORDER_OFFSET_MIN,
					maxValue = BLOODLUST_BORDER_OFFSET_MAX,
					valueStep = 1,
					default = normalizeBloodlustBorderOffset(addon.db and addon.db["mythicPlusBloodlustTrackerBorderOffset"]),
					get = function() return normalizeBloodlustBorderOffset(addon.db and addon.db["mythicPlusBloodlustTrackerBorderOffset"]) end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerBorderOffset"] = normalizeBloodlustBorderOffset(value) end
						applyBloodlustBorderVisualSettings()
					end,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false end,
				},
				{
					name = L["mythicPlusBloodlustTrackerBorderColor"] or "Border color",
					kind = settingType.Color,
					get = function()
						local c = normalizeBloodlustBorderColor(addon.db and addon.db["mythicPlusBloodlustTrackerBorderColor"])
						return { r = c[1], g = c[2], b = c[3], a = c[4] }
					end,
					set = function(_, color)
						if addon.db then addon.db["mythicPlusBloodlustTrackerBorderColor"] = normalizeBloodlustBorderColor(color) end
						applyBloodlustBorderVisualSettings()
					end,
					colorGet = function()
						local c = normalizeBloodlustBorderColor(addon.db and addon.db["mythicPlusBloodlustTrackerBorderColor"])
						return { r = c[1], g = c[2], b = c[3], a = c[4] }
					end,
					colorSet = function(_, color)
						if addon.db then addon.db["mythicPlusBloodlustTrackerBorderColor"] = normalizeBloodlustBorderColor(color) end
						applyBloodlustBorderVisualSettings()
					end,
					colorDefault = { r = 1, g = 1, b = 1, a = 1 },
					hasOpacity = true,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerBorderEnabled"] ~= false end,
				},
				{
					name = "",
					kind = settingType.Divider,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownDrawSwipe"] or "Draw cooldown swipe",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerCooldownDrawSwipe"] ~= false end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerCooldownDrawSwipe"] = value == true end
						applyBloodlustCooldownVisualSettings()
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownDrawEdge"] or "Draw cooldown edge",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerCooldownDrawEdge"] == true end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerCooldownDrawEdge"] = value == true end
						applyBloodlustCooldownVisualSettings()
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownDrawBling"] or "Draw cooldown bling",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerCooldownDrawBling"] == true end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerCooldownDrawBling"] = value == true end
						applyBloodlustCooldownVisualSettings()
					end,
				},
				{
					name = "",
					kind = settingType.Divider,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownFont"] or "Cooldown font",
					kind = settingType.Dropdown,
					height = 280,
					get = function()
						local current = getStoredFontKey()
						return current
					end,
					set = function(_, value) setStoredFontKey(value) end,
					generator = function(_, root)
						local _, entries = getStoredFontKey()
						root:CreateRadio(BLOODLUST_GLOBAL_FONT_LABEL, function() return getStoredFontKey() == BLOODLUST_GLOBAL_FONT_KEY end, function() setStoredFontKey(BLOODLUST_GLOBAL_FONT_KEY) end)
						for i = 1, #entries do
							local fontName = entries[i]
							root:CreateRadio(fontName, function() return getStoredFontKey() == fontName end, function() setStoredFontKey(fontName) end)
						end
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownTextSize"] or "Cooldown text size",
					kind = settingType.Slider,
					minValue = BLOODLUST_COOLDOWN_TEXT_SIZE_MIN,
					maxValue = BLOODLUST_COOLDOWN_TEXT_SIZE_MAX,
					valueStep = 1,
					default = normalizeBloodlustCooldownTextSize(addon.db["mythicPlusBloodlustTrackerCooldownTextSize"]),
					get = function() return normalizeBloodlustCooldownTextSize(addon.db["mythicPlusBloodlustTrackerCooldownTextSize"]) end,
					set = function(_, value)
						addon.db["mythicPlusBloodlustTrackerCooldownTextSize"] = normalizeBloodlustCooldownTextSize(value)
						applyBloodlustCooldownVisualSettings()
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownTextOutline"] or "Cooldown text outline",
					kind = settingType.Dropdown,
					get = function() return normalizeBloodlustCooldownOutline(addon.db and addon.db["mythicPlusBloodlustTrackerCooldownTextOutline"]) end,
					set = function(_, value)
						addon.db["mythicPlusBloodlustTrackerCooldownTextOutline"] = normalizeBloodlustCooldownOutline(value)
						applyBloodlustCooldownVisualSettings()
					end,
					generator = function(_, root)
						for i = 1, #BLOODLUST_COOLDOWN_OUTLINE_OPTIONS do
							local value = BLOODLUST_COOLDOWN_OUTLINE_OPTIONS[i]
							root:CreateRadio(
								outlineOptionLabel(value),
								function() return normalizeBloodlustCooldownOutline(addon.db and addon.db["mythicPlusBloodlustTrackerCooldownTextOutline"]) == value end,
								function()
									addon.db["mythicPlusBloodlustTrackerCooldownTextOutline"] = value
									applyBloodlustCooldownVisualSettings()
								end
							)
						end
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownTextColor"] or "Cooldown text color",
					kind = settingType.Color,
					get = function()
						local c = normalizeBloodlustCooldownColor(addon.db and addon.db["mythicPlusBloodlustTrackerCooldownTextColor"])
						return { r = c[1], g = c[2], b = c[3], a = c[4] }
					end,
					set = function(_, color)
						addon.db["mythicPlusBloodlustTrackerCooldownTextColor"] = normalizeBloodlustCooldownColor(color)
						applyBloodlustCooldownVisualSettings()
					end,
					colorGet = function()
						local c = normalizeBloodlustCooldownColor(addon.db and addon.db["mythicPlusBloodlustTrackerCooldownTextColor"])
						return { r = c[1], g = c[2], b = c[3], a = c[4] }
					end,
					colorSet = function(_, color)
						addon.db["mythicPlusBloodlustTrackerCooldownTextColor"] = normalizeBloodlustCooldownColor(color)
						applyBloodlustCooldownVisualSettings()
					end,
					colorDefault = { r = 1, g = 1, b = 1, a = 1 },
					hasOpacity = true,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownTextOffsetX"] or "Cooldown text X offset",
					kind = settingType.Slider,
					minValue = BLOODLUST_COOLDOWN_TEXT_OFFSET_MIN,
					maxValue = BLOODLUST_COOLDOWN_TEXT_OFFSET_MAX,
					valueStep = 1,
					default = normalizeBloodlustCooldownTextOffset(addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetX"]),
					get = function() return normalizeBloodlustCooldownTextOffset(addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetX"]) end,
					set = function(_, value)
						addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetX"] = normalizeBloodlustCooldownTextOffset(value)
						applyBloodlustCooldownVisualSettings()
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerCooldownTextOffsetY"] or "Cooldown text Y offset",
					kind = settingType.Slider,
					minValue = BLOODLUST_COOLDOWN_TEXT_OFFSET_MIN,
					maxValue = BLOODLUST_COOLDOWN_TEXT_OFFSET_MAX,
					valueStep = 1,
					default = normalizeBloodlustCooldownTextOffset(addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetY"]),
					get = function() return normalizeBloodlustCooldownTextOffset(addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetY"]) end,
					set = function(_, value)
						addon.db["mythicPlusBloodlustTrackerCooldownTextOffsetY"] = normalizeBloodlustCooldownTextOffset(value)
						applyBloodlustCooldownVisualSettings()
					end,
				},
				{
					name = "",
					kind = settingType.Divider,
				},
				{
					name = L["mythicPlusBloodlustTrackerSoundOnDebuffActive"] or "Play sound when Bloodlust lockout becomes active",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerSoundOnDebuffActive"] == true end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerSoundOnDebuffActive"] = value == true end
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerUseCustomDebuffSound"] or "Use custom sound for active lockout",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerUseCustomDebuffSound"] == true end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerUseCustomDebuffSound"] = value == true end
					end,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerSoundOnDebuffActive"] == true end,
				},
				{
					name = L["mythicPlusBloodlustTrackerDebuffSound"] or "Active lockout sound",
					kind = settingType.Dropdown,
					height = 280,
					get = function()
						local value = getStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile")
						return value
					end,
					set = function(_, value) setStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile", value, true) end,
					generator = function(_, root)
						local _, entries = getStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile")
						root:CreateRadio(
							NONE,
							function() return getStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile") == "" end,
							function() setStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile", "", false) end
						)
						for i = 1, #entries do
							local soundName = entries[i]
							root:CreateRadio(
								soundName,
								function() return getStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile") == soundName end,
								function() setStoredSoundKey("mythicPlusBloodlustTrackerDebuffSoundFile", soundName, true) end
							)
						end
					end,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerSoundOnDebuffActive"] == true and addon.db["mythicPlusBloodlustTrackerUseCustomDebuffSound"] == true end,
				},
				{
					name = "",
					kind = settingType.Divider,
				},
				{
					name = L["mythicPlusBloodlustTrackerReadySoundOnEncounterStart"] or "Play sound on ENCOUNTER_START when Bloodlust is ready",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerReadySoundOnEncounterStart"] == true end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerReadySoundOnEncounterStart"] = value == true end
					end,
				},
				{
					name = L["mythicPlusBloodlustTrackerUseCustomReadySound"] or "Use custom sound for ready reminder",
					kind = settingType.Checkbox,
					get = function() return addon.db and addon.db["mythicPlusBloodlustTrackerUseCustomReadySound"] == true end,
					set = function(_, value)
						if addon.db then addon.db["mythicPlusBloodlustTrackerUseCustomReadySound"] = value == true end
					end,
					isEnabled = function() return addon.db and addon.db["mythicPlusBloodlustTrackerReadySoundOnEncounterStart"] == true end,
				},
				{
					name = L["mythicPlusBloodlustTrackerReadySound"] or "Ready reminder sound",
					kind = settingType.Dropdown,
					height = 280,
					get = function()
						local value = getStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile")
						return value
					end,
					set = function(_, value) setStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile", value, true) end,
					generator = function(_, root)
						local _, entries = getStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile")
						root:CreateRadio(
							NONE,
							function() return getStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile") == "" end,
							function() setStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile", "", false) end
						)
						for i = 1, #entries do
							local soundName = entries[i]
							root:CreateRadio(
								soundName,
								function() return getStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile") == soundName end,
								function() setStoredSoundKey("mythicPlusBloodlustTrackerReadySoundFile", soundName, true) end
							)
						end
					end,
					isEnabled = function()
						return addon.db and addon.db["mythicPlusBloodlustTrackerReadySoundOnEncounterStart"] == true and addon.db["mythicPlusBloodlustTrackerUseCustomReadySound"] == true
					end,
				},
			}
		end

		EditMode:RegisterFrame(BLOODLUST_EDITMODE_ID, {
			frame = bloodlustAnchor,
			title = L["mythicPlusBloodlustTrackerAnchor"] or "Bloodlust Tracker Anchor",
			layoutDefaults = {
				point = addon.db["mythicPlusBloodlustTrackerPoint"] or "CENTER",
				relativePoint = addon.db["mythicPlusBloodlustTrackerPoint"] or "CENTER",
				x = addon.db["mythicPlusBloodlustTrackerX"] or 0,
				y = addon.db["mythicPlusBloodlustTrackerY"] or 0,
				size = addon.db["mythicPlusBloodlustButtonSize"] or defaultButtonSize,
			},
			legacyKeys = {
				point = "mythicPlusBloodlustTrackerPoint",
				relativePoint = "mythicPlusBloodlustTrackerPoint",
				x = "mythicPlusBloodlustTrackerX",
				y = "mythicPlusBloodlustTrackerY",
				size = "mythicPlusBloodlustButtonSize",
			},
			isEnabled = function() return addon.db["mythicPlusBloodlustTrackerEnabled"] end,
			onApply = function(_, layoutName, data)
				if not bloodlustAnchor._eqolEditModeHydrated then
					bloodlustAnchor._eqolEditModeHydrated = true
					local record = data or {}
					seedBloodlustEditModeRecordFromProfile(record)
					-- Apply visual settings immediately on first Edit Mode open.
					applyBloodlustLayoutData(record)
					if EditMode and EditMode.SetFramePosition then
						EditMode:SetFramePosition(BLOODLUST_EDITMODE_ID, record.point or "CENTER", record.x or 0, record.y or 0, layoutName)
						return
					end
				end
				applyBloodlustLayoutData(data)
			end,
			settings = settings,
		})
		bloodlustEditModeRegistered = true
	end
	applyBloodlustLayoutData()

	return bloodlustAnchor
end

local function shouldShowBloodlustTracker()
	if not addon.db["mythicPlusBloodlustTrackerEnabled"] then return false end
	if not IsInGroup() then return false end
	if not IsInInstance() then return false end
	local _, _, diff = GetInstanceInfo()
	if diff == 8 then return true end
	if isRaidDifficulty(diff) then return IsEncounterInProgress() end
	return false
end

local function getBloodlustDefaultIcon()
	local configured = getBloodlustConfiguredIcon()
	if configured then return configured end
	if issecretvalue and issecretvalue(BLOODLUST_READY_SPELL_ID) then return BLOODLUST_FALLBACK_ICON end
	if C_Spell and C_Spell.GetSpellTexture then
		local texture = C_Spell.GetSpellTexture(BLOODLUST_READY_SPELL_ID)
		if texture and not (issecretvalue and issecretvalue(texture)) then return texture end
	end
	return BLOODLUST_FALLBACK_ICON
end

local function createBloodlustFrame()
	removeBloodlustFrame()
	if not addon.db["mythicPlusBloodlustTrackerEnabled"] then
		if bloodlustAnchor then bloodlustAnchor:Hide() end
		if EditMode then EditMode:RefreshFrame(BLOODLUST_EDITMODE_ID) end
		return
	end

	local layout = buildBloodlustLayoutSnapshot()
	ensureBloodlustAnchor()
	if shouldShowBloodlustTracker() or bloodlustStateActive then
		local point = layout.point or "CENTER"
		local relativePoint = layout.relativePoint or point
		local xOfs = layout.x or 0
		local yOfs = layout.y or 0
		local size = layout.size or defaultButtonSize
		local defaultIcon = getBloodlustDefaultIcon()

		bloodlustButton = CreateFrame("Button", nil, UIParent)
		bloodlustButton:SetSize(size, size)
		bloodlustButton:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
		setFrameClickThrough(bloodlustButton)

		local bg = bloodlustButton:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(bloodlustButton)
		bg:SetColorTexture(0, 0, 0, 0.8)

		local icon = bloodlustButton:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints(bloodlustButton)
		icon:SetTexture(defaultIcon)
		icon:SetTexCoord(0, 1, 0, 1)
		bloodlustButton.icon = icon
		bloodlustButton.defaultIcon = defaultIcon

		bloodlustButton.border = CreateFrame("Frame", nil, bloodlustButton, "BackdropTemplate")
		bloodlustButton.border:SetFrameLevel((bloodlustButton:GetFrameLevel() or 0) + 5)
		bloodlustButton.border:SetFrameStrata(bloodlustButton:GetFrameStrata())

		local scaleFactor = size / defaultButtonSize
		local timerFontSize = math.floor(defaultFontSize * 0.75 * scaleFactor + 0.5)
		if timerFontSize < 10 then timerFontSize = 10 end

		bloodlustButton.cooldownFrame = CreateFrame("Cooldown", nil, bloodlustButton, "CooldownFrameTemplate")
		bloodlustButton.cooldownFrame:SetAllPoints(bloodlustButton)
		bloodlustButton.cooldownFrame:SetSwipeColor(0, 0, 0, 0.45)
		bloodlustButton.cooldownFrame:SetCountdownAbbrevThreshold(600)
		bloodlustButton.cooldownFrame:SetScale(1)
		if bloodlustButton.cooldownFrame.SetDrawSwipe then bloodlustButton.cooldownFrame:SetDrawSwipe(addon.db["mythicPlusBloodlustTrackerCooldownDrawSwipe"] ~= false) end
		if bloodlustButton.cooldownFrame.SetDrawEdge then bloodlustButton.cooldownFrame:SetDrawEdge(addon.db["mythicPlusBloodlustTrackerCooldownDrawEdge"] == true) end
		if bloodlustButton.cooldownFrame.SetDrawBling then bloodlustButton.cooldownFrame:SetDrawBling(addon.db["mythicPlusBloodlustTrackerCooldownDrawBling"] == true) end
		if bloodlustButton.cooldownFrame.SetHideCountdownNumbers then bloodlustButton.cooldownFrame:SetHideCountdownNumbers(false) end

		bloodlustButton.status = bloodlustButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bloodlustButton.status:SetPoint("BOTTOM", bloodlustButton, "BOTTOM", 0, 4)
		bloodlustButton.status:SetFont(addon.variables.defaultFont, timerFontSize, "OUTLINE")
		bloodlustButton.status:SetText(L["mythicPlusBloodlustTrackerReadyLabel"] or "READY")
		bloodlustButton.status:SetTextColor(0.2, 1, 0.2)
		bloodlustButton.cooldownFrame:Clear()
		applyBloodlustCooldownVisualSettings()
		applyBloodlustBorderVisualSettings()
	end

	applyBloodlustLayoutData(layout)
	if EditMode then EditMode:RefreshFrame(BLOODLUST_EDITMODE_ID) end
end

addon.MythicPlus.functions.createBloodlustFrame = createBloodlustFrame

local function clearBloodlustTrackedAuraInstances()
	if wipe then
		wipe(bloodlustTrackedAuraInstanceIDs)
	else
		for key in pairs(bloodlustTrackedAuraInstanceIDs) do
			bloodlustTrackedAuraInstanceIDs[key] = nil
		end
	end
end

local function isTrackedBloodlustSpell(spellId)
	if spellId == nil then return false end
	if issecretvalue and issecretvalue(spellId) then return false end
	spellId = tonumber(spellId)
	if not spellId then return false end
	return BLOODLUST_LOCKOUT_SET[spellId] == true
end

local function getActiveBloodlustAura()
	local unitGetter = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	local playerGetter = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not unitGetter and not playerGetter then return nil, false end

	for i = 1, #BLOODLUST_LOCKOUT_IDS do
		local spellId = BLOODLUST_LOCKOUT_IDS[i]
		if not (issecretvalue and issecretvalue(spellId)) then
			local aura = nil
			if unitGetter then aura = unitGetter("player", spellId) end
			if not aura and playerGetter then aura = playerGetter(spellId) end
			-- Query-by-ID on a whitelisted lockout spell is authoritative enough here.
			if aura then return aura, true end
		end
	end

	return nil, true
end

local function shouldRefreshBloodlustFromUpdateInfo(updateInfo)
	-- Active lockout fast path: only refresh if tracked aura got removed (or full/secret update).
	if bloodlustStateActive then
		if type(updateInfo) ~= "table" then return false end
		if issecretvalue and issecretvalue(updateInfo) then return true end
		if updateInfo.isFullUpdate == true then return true end

		local removedIDs = updateInfo.removedAuraInstanceIDs
		if type(removedIDs) ~= "table" then return false end
		for i = 1, #removedIDs do
			local auraInstanceID = removedIDs[i]
			if issecretvalue and issecretvalue(auraInstanceID) then return true end
			if auraInstanceID and bloodlustTrackedAuraInstanceIDs[auraInstanceID] then return true end
		end
		return false
	end

	if type(updateInfo) ~= "table" then return true end
	if issecretvalue and issecretvalue(updateInfo) then return true end
	if updateInfo.isFullUpdate == true then return true end

	local addedAuras = updateInfo.addedAuras
	if type(addedAuras) == "table" then
		for i = 1, #addedAuras do
			local aura = addedAuras[i]
			if type(aura) == "table" then
				local spellId = aura.spellId
				if issecretvalue and issecretvalue(spellId) then return true end
				if isTrackedBloodlustSpell(spellId) then return true end
			end
		end
	end

	local removedIDs = updateInfo.removedAuraInstanceIDs
	if type(removedIDs) == "table" then
		for i = 1, #removedIDs do
			local auraInstanceID = removedIDs[i]
			if issecretvalue and issecretvalue(auraInstanceID) then return true end
			if auraInstanceID and bloodlustTrackedAuraInstanceIDs[auraInstanceID] then return true end
		end
	end

	local updatedIDs = updateInfo.updatedAuraInstanceIDs
	if type(updatedIDs) == "table" then
		local getByInstanceID = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
		for i = 1, #updatedIDs do
			local auraInstanceID = updatedIDs[i]
			if issecretvalue and issecretvalue(auraInstanceID) then return true end
			if auraInstanceID and bloodlustTrackedAuraInstanceIDs[auraInstanceID] then return true end
			if getByInstanceID and auraInstanceID then
				local aura = getByInstanceID("player", auraInstanceID)
				if aura then
					local spellId = aura.spellId
					if issecretvalue and issecretvalue(spellId) then return true end
					if isTrackedBloodlustSpell(spellId) then return true end
				end
			end
		end
	end

	-- Some clients emit UNIT_AURA with sparse/empty updateInfo payloads.
	-- In that case, do a safe full refresh to avoid missing lockout transitions.
	local addedCount = type(addedAuras) == "table" and #addedAuras or 0
	local removedCount = type(removedIDs) == "table" and #removedIDs or 0
	local updatedCount = type(updatedIDs) == "table" and #updatedIDs or 0
	if addedCount == 0 and removedCount == 0 and updatedCount == 0 then return true end

	return false
end

local function getCustomSoundFile(settingKey)
	if not addon.db then return nil end
	local soundName = addon.db[settingKey]
	if type(soundName) ~= "string" or soundName == "" then return nil end
	local soundTable = getCachedMediaHash("sound")
	return soundTable and soundTable[soundName] or nil
end

local function getBloodlustFallbackSoundKit(soundSettingKey)
	if not SOUNDKIT then return nil end
	if soundSettingKey == "mythicPlusBloodlustTrackerReadySoundFile" then return SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING end
	return SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK
end

local function playBloodlustSound(useCustomKey, soundSettingKey, fallbackSoundKit)
	if not addon.db then return end
	local file = nil
	if addon.db[useCustomKey] == true then file = getCustomSoundFile(soundSettingKey) end
	if file then
		PlaySoundFile(file, "Master")
	elseif PlaySound then
		local kit = fallbackSoundKit or getBloodlustFallbackSoundKit(soundSettingKey)
		if kit then PlaySound(kit, "Master") end
	end
end

local function applyBloodlustAuraToFrame(aura)
	if not bloodlustButton then return end
	local icon = bloodlustButton.defaultIcon or getBloodlustDefaultIcon()

	if aura then
		bloodlustButton.icon:SetTexture(icon)
		bloodlustButton.icon:SetDesaturated(true)

		local duration = aura.duration
		local expiration = aura.expirationTime
		if issecretvalue and (issecretvalue(duration) or issecretvalue(expiration)) then
			duration = nil
			expiration = nil
		end
		duration = duration and tonumber(duration) or nil
		expiration = expiration and tonumber(expiration) or nil
		if duration and duration > 0 and expiration and expiration > 0 then
			bloodlustButton.cooldownFrame:SetCooldown(expiration - duration, duration)
		else
			bloodlustButton.cooldownFrame:Clear()
		end
		if bloodlustButton.status then
			bloodlustButton.status:SetText("")
			bloodlustButton.status:SetTextColor(1, 0.2, 0.2)
		end
	else
		bloodlustButton.icon:SetTexture(icon)
		bloodlustButton.icon:SetDesaturated(false)
		bloodlustButton.cooldownFrame:Clear()
		if bloodlustButton.status then
			bloodlustButton.status:SetText(L["mythicPlusBloodlustTrackerReadyLabel"] or "READY")
			bloodlustButton.status:SetTextColor(0.2, 1, 0.2)
		end
	end

	-- Cooldown timer text is created lazily by Blizzard code; re-apply style after state updates.
	applyBloodlustLiveCooldownTextStyle(true)
end

local function refreshBloodlustTracker(playReadySound)
	local aura, known = getActiveBloodlustAura()
	if not known then return false end

	clearBloodlustTrackedAuraInstances()
	local auraInstanceID = aura and aura.auraInstanceID
	if auraInstanceID and not (issecretvalue and issecretvalue(auraInstanceID)) then bloodlustTrackedAuraInstanceIDs[auraInstanceID] = true end

	local isActive = aura ~= nil
	local shouldPlayDebuffActiveSound = false
	if bloodlustStateInitialized and not bloodlustStateActive and isActive and addon.db["mythicPlusBloodlustTrackerSoundOnDebuffActive"] then
		local expiration = aura and aura.expirationTime
		if expiration and not (issecretvalue and issecretvalue(expiration)) then
			expiration = tonumber(expiration)
			if expiration and expiration > 0 then
				local remaining = expiration - GetTime()
				shouldPlayDebuffActiveSound = remaining > BLOODLUST_ACTIVE_SOUND_MIN_REMAINING
			end
		end
	end
	if shouldPlayDebuffActiveSound then playBloodlustSound("mythicPlusBloodlustTrackerUseCustomDebuffSound", "mythicPlusBloodlustTrackerDebuffSoundFile") end
	local classToken = addon.variables.unitClass
	if playReadySound and not isActive and addon.db["mythicPlusBloodlustTrackerReadySoundOnEncounterStart"] and BLOODLUST_READY_CLASSES[classToken] then
		playBloodlustSound("mythicPlusBloodlustTrackerUseCustomReadySound", "mythicPlusBloodlustTrackerReadySoundFile")
	end

	bloodlustStateActive = isActive
	bloodlustStateInitialized = true
	applyBloodlustAuraToFrame(aura)
	return true
end

addon.MythicPlus.functions.refreshBloodlustTracker = refreshBloodlustTracker
addon.MythicPlus.functions.syncBloodlustUnitAuraRegistration = syncBloodlustUnitAuraRegistration

local function setBRInfo(info)
	if brButton and brButton.cooldownFrame and info then
		local current = info.currentCharges
		local max = info.maxCharges

		if issecretvalue and issecretvalue(current) then
			brButton.cooldownFrame:SetCooldown(info.cooldownStartTime, info.cooldownDuration, info.chargeModRate)
			brButton.cooldownFrame.startTime = info.cooldownStartTime
			brButton.cooldownFrame.charges = C_StringUtil.TruncateWhenZero(current)

			brButton.charges:SetTextColor(0, 1, 0)
			brButton.icon:SetDesaturated(false)
			brButton.cooldownFrame:SetSwipeColor(0, 0, 0, 0.3)
			brButton.charges:Show()
		elseif current < max then
			if brButton.cooldownFrame.charges ~= current or brButton.cooldownFrame.startTime ~= info.cooldownStartTime then
				brButton.cooldownFrame:SetCooldown(info.cooldownStartTime, info.cooldownDuration, info.chargeModRate)
				brButton.cooldownFrame.startTime = info.cooldownStartTime
				brButton.cooldownFrame.charges = current

				if current > 0 then
					brButton.charges:SetTextColor(0, 1, 0)
					brButton.icon:SetDesaturated(false)
					brButton.cooldownFrame:SetSwipeColor(0, 0, 0, 0.3)
					brButton.charges:Show()
				else
					brButton.cooldownFrame:SetSwipeColor(0, 0, 0, 1)
					brButton.icon:SetDesaturated(true)
					brButton.charges:SetTextColor(1, 0, 0)
					brButton.charges:Hide()
				end
			end
		else
			brButton.cooldownFrame:Clear()
			brButton.charges:SetTextColor(0, 1, 0)
		end
		brButton.charges:SetText(current)
	end
end

hooksecurefunc(ScenarioObjectiveTracker.ChallengeModeBlock, "UpdateTime", function(self, elapsedTime)
	if addon.db["mythicPlusBRTrackerEnabled"] then
		if not brButton or not brButton.cooldownFrame or not brButton.cooldownFrame.cooldownSet then
			createBRFrame()
			if brButton and brButton.cooldownFrame then
				brButton.cooldownFrame.cooldownSet = true
				local info = C_Spell.GetSpellCharges(20484)
				setBRInfo(info)
			end
		end
	end

	if addon.db["mythicPlusBloodlustTrackerEnabled"] then
		if shouldShowBloodlustTracker() then
			if not bloodlustButton or not bloodlustButton.cooldownFrame then
				createBloodlustFrame()
				refreshBloodlustTracker(false)
			end
		else
			removeBloodlustFrame()
		end
	end

	if not addon.db["enableKeystoneHelper"] or not addon.db["mythicPlusShowChestTimers"] then return end

	-- Always show chest timers in challenge mode
	local timeLeft = math.max(0, self.timeLimit - elapsedTime)
	local chest3Time = self.timeLimit * 0.4
	local chest2Time = self.timeLimit * 0.2

	if not self.CustomTextAdded then
		self.ChestTimeText2 = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.ChestTimeText2:SetPoint("TOPLEFT", self.TimeLeft, "TOPRIGHT", 3, 2)
		self.ChestTimeText3 = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.ChestTimeText3:SetPoint("BOTTOMLEFT", self.TimeLeft, "BOTTOMRIGHT", 3, 0)
		self.CustomTextAdded = true
	end

	if timeLeft > 0 then
		local chestText3 = ""
		local chestText2 = ""

		if timeLeft >= chest3Time then chestText3 = string.format("+3: %s", SecondsToClock(timeLeft - chest3Time)) end
		if timeLeft >= chest2Time then chestText2 = string.format("+2: %s", SecondsToClock(timeLeft - chest2Time)) end

		self.ChestTimeText2:SetText(chestText2)
		self.ChestTimeText3:SetText(chestText3)
	else
		self.ChestTimeText2:SetText("")
		self.ChestTimeText3:SetText("")
	end
end)

local function GetScenarioPercent(criteriaIndex)
	local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
	if criteriaInfo and criteriaInfo.isWeightedProgress then
		local sValue = criteriaInfo.quantity
		if criteriaInfo.quantityString then
			sValue = tonumber(string.sub(criteriaInfo.quantityString, 1, string.len(criteriaInfo.quantityString) - 1)) / criteriaInfo.totalQuantity * 100
			sValue = math.floor(sValue * 100 + 0.5) / 100
		end
		return sValue
	end
	return nil
end

hooksecurefunc(ScenarioTrackerProgressBarMixin, "SetValue", function(self, percentage)
	-- Always show decimal progress for enemy forces in M+
	if not IsInInstance() or not self:IsVisible() then return end
	local _, _, diff = GetInstanceInfo()
	if diff ~= 8 then return end -- only in mythic challenge mode
	local sData = C_ScenarioInfo.GetScenarioStepInfo()
	if nil == sData then return end

	local truePercent
	if self.criteriaIndex then self.criteriaIndex = nil end
	for criteriaIndex = 1, sData.numCriteria do
		if nil == truePercent then
			truePercent = GetScenarioPercent(criteriaIndex)
			if truePercent then
				self.Bar.Label:SetFormattedText(truePercent .. "%%")
				self.percentage = percentage
			end
		end
	end
end)

local function createButtons()
	-- Always use improved Keystone Helper UI
	addon.MythicPlus.functions.addRCButton()
	addon.MythicPlus.functions.addPullButton()
end

local function checkKeyStone()
	addon.MythicPlus.variables.handled = false -- reset handle on Keystoneframe open
	addon.MythicPlus.functions.removeExistingButton()
	if not addon.db["enableKeystoneHelper"] then return end
	local GetContainerNumSlots = C_Container.GetContainerNumSlots
	local GetContainerItemID = C_Container.GetContainerItemID
	local UseContainerItem = C_Container.UseContainerItem
	local GetContainerItemInfo = C_Container.GetContainerItemInfo

	local kId = C_MythicPlus.GetOwnedKeystoneMapID()
	local mapId = select(8, GetInstanceInfo())
	if nil ~= kId and mapId == kId then
		for container = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
			for slot = 1, GetContainerNumSlots(container) do
				local id = GetContainerItemID(container, slot)
				if id == 180653 or id == 151086 then
					-- Button for ReadyCheck and Pulltimer
					if UnitInParty("player") and UnitIsGroupLeader("player") then createButtons() end

					if addon.db["autoInsertKeystone"] and addon.db["autoInsertKeystone"] == true then
						UseContainerItem(container, slot)
						if addon.db["closeBagsOnKeyInsert"] and addon.db["closeBagsOnKeyInsert"] == true then CloseAllBags() end
					end
					break
				end
			end
		end
	end
end

-- Funktion zum Umgang mit Events
local function eventHandler(self, event, arg1, arg2, arg3, arg4)
	if event == "ADDON_LOADED" and arg1 == addonName then
		-- loadMain()
	elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
		if InCombatLockdown() then return end
		if addon.db["enableKeystoneHelper"] then checkKeyStone() end
	elseif event == "READY_CHECK_FINISHED" and ChallengesKeystoneFrame and addon.MythicPlus.Buttons["ReadyCheck"] then
		addon.MythicPlus.Buttons["ReadyCheck"]:SetText(L["ReadyCheck"])
	elseif event == "SPELL_UPDATE_CHARGES" then
		if shouldShowBRTracker() then
			if not brButton or not brButton.cooldownFrame then createBRFrame() end
			local info = C_Spell.GetSpellCharges(20484)
			setBRInfo(info)
		else
			removeBRFrame()
		end
	elseif event == "UNIT_AURA" then
		if arg1 ~= "player" then return end
		if not addon.db["mythicPlusBloodlustTrackerEnabled"] then return end
		if bloodlustStateInitialized and not shouldRefreshBloodlustFromUpdateInfo(arg2) then return end

		-- Refresh state first so visibility logic can react to newly applied/removed lockout auras.
		refreshBloodlustTracker(false)
		if not shouldShowBloodlustTracker() and not bloodlustStateActive then
			removeBloodlustFrame()
			return
		end
		if not bloodlustButton or not bloodlustButton.cooldownFrame then createBloodlustFrame() end
		refreshBloodlustTracker(false)
	elseif event == "ENCOUNTER_START" then
		local _, _, diff = GetInstanceInfo()
		if isRaidDifficulty(diff) and shouldShowBRTracker() then
			if not brButton or not brButton.cooldownFrame then createBRFrame() end
			local info = C_Spell.GetSpellCharges(20484)
			setBRInfo(info)
		end
		if addon.db["mythicPlusBloodlustTrackerEnabled"] then
			-- Ready reminder sound should run on encounter start even when the frame is currently hidden.
			refreshBloodlustTracker(true)
			if shouldShowBloodlustTracker() or bloodlustStateActive then
				if not bloodlustButton or not bloodlustButton.cooldownFrame then createBloodlustFrame() end
				refreshBloodlustTracker(false)
			else
				removeBloodlustFrame()
			end
		end
	elseif event == "ENCOUNTER_END" then
		-- In raids we hide after encounter; in M+ we keep showing
		if not shouldShowBRTracker() then removeBRFrame() end
		if not shouldShowBloodlustTracker() and not bloodlustStateActive then removeBloodlustFrame() end
	end
end

function addon.MythicPlus.functions.InitMain()
	if addon.MythicPlus.variables.mainInitialized then return end
	if not addon.db then return end
	addon.MythicPlus.variables.mainInitialized = true

	-- Registriere das Event
	frameLoad:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
	frameLoad:RegisterEvent("READY_CHECK_FINISHED")
	frameLoad:RegisterEvent("LFG_ROLE_CHECK_SHOW")
	frameLoad:RegisterEvent("SPELL_UPDATE_CHARGES")
	frameLoad:RegisterEvent("ENCOUNTER_END")
	frameLoad:RegisterEvent("ENCOUNTER_START")

	-- Setze den Event-Handler
	frameLoad:SetScript("OnEvent", eventHandler)
	syncBloodlustUnitAuraRegistration()

	if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.createBRFrame then addon.MythicPlus.functions.createBRFrame() end
	if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.createBloodlustFrame then addon.MythicPlus.functions.createBloodlustFrame() end
	refreshBloodlustTracker(false)
	if bloodlustStateActive and (not bloodlustButton or not bloodlustButton.cooldownFrame) then
		createBloodlustFrame()
		refreshBloodlustTracker(false)
	end

	if addon.db["mythicPlusEnableDungeonFilter"] then addon.MythicPlus.functions.addDungeonFilter() end
end
