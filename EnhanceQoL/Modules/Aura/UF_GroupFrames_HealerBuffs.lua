local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.UF = addon.Aura.UF or {}
local UF = addon.Aura.UF
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")

UF.GroupFramesHealerBuffs = UF.GroupFramesHealerBuffs or {}
local HB = UF.GroupFramesHealerBuffs

local GFH = UF.GroupFramesHelper
local AuraUtil = UF.AuraUtil

local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local next = next
local tinsert = table.insert
local sort = table.sort
local format = string.format
local wipe = _G.wipe or (table and table.wipe)
local issecretvalue = _G.issecretvalue
local UnitIsUnit = _G.UnitIsUnit

local EMPTY = {}

local STYLE_ICON = "ICON"
local STYLE_SQUARE = "SQUARE"
local STYLE_BAR = "BAR"
local STYLE_BORDER = "BORDER"
local STYLE_TINT = "TINT"

local STYLE_SET = {
	[STYLE_ICON] = true,
	[STYLE_SQUARE] = true,
	[STYLE_BAR] = true,
	[STYLE_BORDER] = true,
	[STYLE_TINT] = true,
}

local ORIENT_HORIZONTAL = "HORIZONTAL"
local ORIENT_VERTICAL = "VERTICAL"

local RULE_MATCH_ANY = "ANY"
local RULE_MATCH_ALL = "ALL"
local ICON_MODE_ALL = "ALL"
local ICON_MODE_PRIORITY = "PRIORITY"
local KIND_PARTY = "party"
local KIND_RAID = "raid"

local ORIENTATION_SET = {
	[ORIENT_HORIZONTAL] = true,
	[ORIENT_VERTICAL] = true,
}

local RULE_MATCH_SET = {
	[RULE_MATCH_ANY] = true,
	[RULE_MATCH_ALL] = true,
}

local ICON_MODE_SET = {
	[ICON_MODE_ALL] = true,
	[ICON_MODE_PRIORITY] = true,
}

local KIND_SET = {
	[KIND_PARTY] = true,
	[KIND_RAID] = true,
}

local ANCHOR_SET = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local GROWTH_DIRS = {
	UPRIGHT = true,
	UPLEFT = true,
	RIGHTUP = true,
	RIGHTDOWN = true,
	LEFTUP = true,
	LEFTDOWN = true,
	DOWNLEFT = true,
	DOWNRIGHT = true,
}

local GROWTH_AXES = {
	UPRIGHT = { "UP", "RIGHT" },
	UPLEFT = { "UP", "LEFT" },
	RIGHTUP = { "RIGHT", "UP" },
	RIGHTDOWN = { "RIGHT", "DOWN" },
	LEFTUP = { "LEFT", "UP" },
	LEFTDOWN = { "LEFT", "DOWN" },
	DOWNLEFT = { "DOWN", "LEFT" },
	DOWNRIGHT = { "DOWN", "RIGHT" },
}

local function tr(key, fallback)
	local value = L and L[key]
	if value == nil or value == "" then return fallback or key end
	return value
end

HB.STYLE_OPTIONS = {
	{ value = STYLE_ICON, label = tr("UFGroupHealerBuffStyleIcon", "Icon") },
	{ value = STYLE_SQUARE, label = tr("UFGroupHealerBuffStyleSquare", "Square") },
	{ value = STYLE_BAR, label = tr("UFGroupHealerBuffStyleBar", "Bar") },
	{ value = STYLE_BORDER, label = tr("UFGroupHealerBuffStyleBorder", "Border") },
	{ value = STYLE_TINT, label = tr("UFGroupHealerBuffStyleTint", "Tint") },
}

HB.ORIENTATION_OPTIONS = {
	{ value = ORIENT_HORIZONTAL, label = tr("UFGroupHealerBuffOrientationHorizontal", "Horizontal") },
	{ value = ORIENT_VERTICAL, label = tr("UFGroupHealerBuffOrientationVertical", "Vertical") },
}

HB.RULE_MATCH_OPTIONS = {
	{ value = RULE_MATCH_ANY, label = tr("UFGroupHealerBuffRuleMatchAny", "Require Any Spell") },
	{ value = RULE_MATCH_ALL, label = tr("UFGroupHealerBuffRuleMatchAll", "Require All Spells") },
}

HB.ICON_MODE_OPTIONS = {
	{ value = ICON_MODE_ALL, label = tr("UFGroupHealerBuffIconModeAll", "Show All Active Spells") },
	{ value = ICON_MODE_PRIORITY, label = tr("UFGroupHealerBuffIconModePriority", "Show Highest Priority Only") },
}

HB.ANCHOR_OPTIONS = GFH and GFH.anchorOptions9
	or {
		{ value = "TOPLEFT", label = tr("UFGroupHealerBuffAnchorTopLeft", "Top Left") },
		{ value = "TOP", label = tr("UFGroupHealerBuffAnchorTop", "Top") },
		{ value = "TOPRIGHT", label = tr("UFGroupHealerBuffAnchorTopRight", "Top Right") },
		{ value = "LEFT", label = tr("UFGroupHealerBuffAnchorLeft", "Left") },
		{ value = "CENTER", label = tr("UFGroupHealerBuffAnchorCenter", "Center") },
		{ value = "RIGHT", label = tr("UFGroupHealerBuffAnchorRight", "Right") },
		{ value = "BOTTOMLEFT", label = tr("UFGroupHealerBuffAnchorBottomLeft", "Bottom Left") },
		{ value = "BOTTOM", label = tr("UFGroupHealerBuffAnchorBottom", "Bottom") },
		{ value = "BOTTOMRIGHT", label = tr("UFGroupHealerBuffAnchorBottomRight", "Bottom Right") },
	}

HB.GROWTH_OPTIONS = GFH and GFH.auraGrowthOptions
	or {
		{ value = "UPRIGHT", label = tr("UFGroupHealerBuffGrowthUpRight", "Up Right") },
		{ value = "UPLEFT", label = tr("UFGroupHealerBuffGrowthUpLeft", "Up Left") },
		{ value = "RIGHTUP", label = tr("UFGroupHealerBuffGrowthRightUp", "Right Up") },
		{ value = "RIGHTDOWN", label = tr("UFGroupHealerBuffGrowthRightDown", "Right Down") },
		{ value = "LEFTUP", label = tr("UFGroupHealerBuffGrowthLeftUp", "Left Up") },
		{ value = "LEFTDOWN", label = tr("UFGroupHealerBuffGrowthLeftDown", "Left Down") },
		{ value = "DOWNLEFT", label = tr("UFGroupHealerBuffGrowthDownLeft", "Down Left") },
		{ value = "DOWNRIGHT", label = tr("UFGroupHealerBuffGrowthDownRight", "Down Right") },
	}

local FAMILY_DATA = {
	-- Preservation Evoker
	{ id = "evoker_pres_dream_breath", classToken = "EVOKER", spec = "Preservation", spellIds = { 355941 }, fallbackName = "Dream Breath" },
	{ id = "evoker_pres_dream_flight", classToken = "EVOKER", spec = "Preservation", spellIds = { 363502 }, fallbackName = "Dream Flight" },
	{ id = "evoker_pres_echo", classToken = "EVOKER", spec = "Preservation", spellIds = { 364343 }, fallbackName = "Echo" },
	{ id = "evoker_pres_reversion", classToken = "EVOKER", spec = "Preservation", spellIds = { 366155 }, fallbackName = "Reversion" },
	{ id = "evoker_pres_echo_reversion", classToken = "EVOKER", spec = "Preservation", spellIds = { 367364 }, fallbackName = "Echo Reversion" },
	{ id = "evoker_pres_lifebind", classToken = "EVOKER", spec = "Preservation", spellIds = { 373267 }, fallbackName = "Lifebind" },
	{ id = "evoker_pres_echo_dream_breath", classToken = "EVOKER", spec = "Preservation", spellIds = { 376788 }, fallbackName = "Echo Dream Breath" },
	-- Augmentation Evoker
	{ id = "evoker_aug_blistering_scales", classToken = "EVOKER", spec = "Augmentation", spellIds = { 360827 }, fallbackName = "Blistering Scales" },
	{ id = "evoker_aug_ebon_might", classToken = "EVOKER", spec = "Augmentation", spellIds = { 395152 }, fallbackName = "Ebon Might" },
	{ id = "evoker_aug_prescience", classToken = "EVOKER", spec = "Augmentation", spellIds = { 410089 }, fallbackName = "Prescience" },
	{ id = "evoker_aug_infernos_blessing", classToken = "EVOKER", spec = "Augmentation", spellIds = { 410263 }, fallbackName = "Inferno's Blessing" },
	{ id = "evoker_aug_symbiotic_bloom", classToken = "EVOKER", spec = "Augmentation", spellIds = { 410686 }, fallbackName = "Symbiotic Bloom" },
	{ id = "evoker_aug_shifting_sands", classToken = "EVOKER", spec = "Augmentation", spellIds = { 413984 }, fallbackName = "Shifting Sands" },
	-- Restoration Druid
	{ id = "druid_rejuvenation", classToken = "DRUID", spec = "Restoration", spellIds = { 774 }, fallbackName = "Rejuvenation" },
	{ id = "druid_regrowth", classToken = "DRUID", spec = "Restoration", spellIds = { 8936 }, fallbackName = "Regrowth" },
	{ id = "druid_lifebloom", classToken = "DRUID", spec = "Restoration", spellIds = { 33763 }, fallbackName = "Lifebloom" },
	{ id = "druid_wild_growth", classToken = "DRUID", spec = "Restoration", spellIds = { 48438 }, fallbackName = "Wild Growth" },
	{ id = "druid_germination", classToken = "DRUID", spec = "Restoration", spellIds = { 155777 }, fallbackName = "Germination" },
	-- Discipline Priest
	{ id = "priest_pw_shield", classToken = "PRIEST", spec = "Discipline", spellIds = { 17 }, fallbackName = "Power Word: Shield" },
	{ id = "priest_atonement", classToken = "PRIEST", spec = "Discipline", spellIds = { 194384 }, fallbackName = "Atonement" },
	{ id = "priest_void_shield", classToken = "PRIEST", spec = "Discipline", spellIds = { 1253593 }, fallbackName = "Void Shield" },
	-- Holy Priest
	{ id = "priest_renew", classToken = "PRIEST", spec = "Holy", spellIds = { 139 }, fallbackName = "Renew" },
	{ id = "priest_prayer_of_mending", classToken = "PRIEST", spec = "Holy", spellIds = { 41635 }, fallbackName = "Prayer of Mending" },
	{ id = "priest_echo_of_light", classToken = "PRIEST", spec = "Holy", spellIds = { 77489 }, fallbackName = "Echo of Light" },
	-- Mistweaver Monk
	{ id = "monk_soothing_mist", classToken = "MONK", spec = "Mistweaver", spellIds = { 115175 }, fallbackName = "Soothing Mist" },
	{ id = "monk_renewing_mist", classToken = "MONK", spec = "Mistweaver", spellIds = { 119611 }, fallbackName = "Renewing Mist" },
	{ id = "monk_enveloping_mist", classToken = "MONK", spec = "Mistweaver", spellIds = { 124682 }, fallbackName = "Enveloping Mist" },
	{ id = "monk_aspect_of_harmony", classToken = "MONK", spec = "Mistweaver", spellIds = { 450769 }, fallbackName = "Aspect of Harmony" },
	-- Restoration Shaman
	{ id = "shaman_earth_shield", classToken = "SHAMAN", spec = "Restoration", spellIds = { 974, 383648 }, fallbackName = "Earth Shield" },
	{ id = "shaman_riptide", classToken = "SHAMAN", spec = "Restoration", spellIds = { 61295 }, fallbackName = "Riptide" },
	-- Holy Paladin
	{ id = "paladin_beacon_of_light", classToken = "PALADIN", spec = "Holy", spellIds = { 53563 }, fallbackName = "Beacon of Light" },
	{ id = "paladin_eternal_flame", classToken = "PALADIN", spec = "Holy", spellIds = { 156322 }, fallbackName = "Eternal Flame" },
	{ id = "paladin_beacon_of_faith", classToken = "PALADIN", spec = "Holy", spellIds = { 156910 }, fallbackName = "Beacon of Faith" },
	{ id = "paladin_beacon_of_the_savior", classToken = "PALADIN", spec = "Holy", spellIds = { 1244893 }, fallbackName = "Beacon of the Savior" },
	{ id = "paladin_beacon_of_virtue", classToken = "PALADIN", spec = "Holy", spellIds = { 200025 }, fallbackName = "Beacon of Virtue" },
}

local FAMILY_BY_ID = {}
local FAMILY_ORDER = {}
local SPELL_TO_FAMILY = {}

for _, family in ipairs(FAMILY_DATA) do
	family.spellIds = family.spellIds or {}
	FAMILY_BY_ID[family.id] = family
	FAMILY_ORDER[#FAMILY_ORDER + 1] = family.id
	for i = 1, #family.spellIds do
		SPELL_TO_FAMILY[tonumber(family.spellIds[i])] = family.id
	end
end

HB.FAMILY_BY_ID = FAMILY_BY_ID
HB.FAMILY_ORDER = FAMILY_ORDER
HB.SPELL_TO_FAMILY = SPELL_TO_FAMILY

local function wipeTable(tbl)
	if not tbl then return end
	if wipe then
		wipe(tbl)
	else
		for key in pairs(tbl) do
			tbl[key] = nil
		end
	end
end

local function copyTable(src)
	if type(src) ~= "table" then return src end
	if addon.functions and addon.functions.copyTable then return addon.functions.copyTable(src) end
	if CopyTable then return CopyTable(src) end
	local out = {}
	for key, value in pairs(src) do
		if type(value) == "table" then
			out[key] = copyTable(value)
		else
			out[key] = value
		end
	end
	return out
end

local function clamp(value, minValue, maxValue, fallback)
	local n = tonumber(value)
	if n == nil then n = fallback end
	if n == nil then return nil end
	if minValue ~= nil and n < minValue then n = minValue end
	if maxValue ~= nil and n > maxValue then n = maxValue end
	return n
end

local function roundInt(value)
	local n = tonumber(value) or 0
	if n >= 0 then return floor(n + 0.5) end
	return -floor(abs(n) + 0.5)
end

local function normalizeStyle(value)
	local style = tostring(value or STYLE_ICON):upper()
	if STYLE_SET[style] then return style end
	return STYLE_ICON
end

local function normalizeOrientation(value)
	local orient = tostring(value or ORIENT_HORIZONTAL):upper()
	if ORIENTATION_SET[orient] then return orient end
	return ORIENT_HORIZONTAL
end

local function normalizeRuleMatch(value)
	local mode = tostring(value or RULE_MATCH_ANY):upper()
	if RULE_MATCH_SET[mode] then return mode end
	return RULE_MATCH_ANY
end

local function normalizeIconMode(value)
	local mode = tostring(value or ICON_MODE_ALL):upper()
	if ICON_MODE_SET[mode] then return mode end
	return ICON_MODE_ALL
end

local function normalizeAnchor(value)
	local anchor = tostring(value or "CENTER"):upper()
	if ANCHOR_SET[anchor] then return anchor end
	return "CENTER"
end

local function parseGrowth(growth)
	if not growth then return nil end
	local raw = tostring(growth):upper():gsub("[%s_]+", "")
	if GROWTH_DIRS[raw] then return raw end
	local first, second = tostring(growth):upper():match("^(%a+)[_%s]+(%a+)$")
	if first and second then
		local combo = first .. second
		if GROWTH_DIRS[combo] then return combo end
	end
	return nil
end

local function normalizeGrowth(value)
	local growth = parseGrowth(value)
	if growth then return growth end
	return "RIGHTDOWN"
end

local function normalizeColor(value, fallback)
	local ref = fallback or { 1, 1, 1, 1 }
	local r, g, b, a
	if type(value) == "table" then
		r = value.r or value[1]
		g = value.g or value[2]
		b = value.b or value[3]
		a = value.a
		if a == nil then a = value[4] end
	end
	if r == nil then r = ref[1] or 1 end
	if g == nil then g = ref[2] or 1 end
	if b == nil then b = ref[3] or 1 end
	if a == nil then a = ref[4] end
	if a == nil then a = 1 end
	r = clamp(r, 0, 1, 1)
	g = clamp(g, 0, 1, 1)
	b = clamp(b, 0, 1, 1)
	a = clamp(a, 0, 1, 1)
	return { r, g, b, a }
end

local function normalizeOptionalColor(value)
	if value == nil then return nil end
	if type(value) ~= "table" then return nil end
	return normalizeColor(value, { 1, 1, 1, 1 })
end

local function normalizeKind(kind)
	kind = tostring(kind or KIND_PARTY):lower()
	if kind == "mt" or kind == "ma" then return KIND_RAID end
	if KIND_SET[kind] then return kind end
	return kind
end

local function normalizeOrder(order, map)
	local result = {}
	local seen = {}
	if type(order) == "table" then
		for i = 1, #order do
			local id = order[i]
			if id ~= nil then
				id = tostring(id)
				if map[id] and not seen[id] then
					seen[id] = true
					result[#result + 1] = id
				end
			end
		end
	end
	local missing = {}
	for id in pairs(map) do
		if not seen[id] then missing[#missing + 1] = id end
	end
	sort(missing, function(a, b)
		local na = tonumber(a)
		local nb = tonumber(b)
		if na and nb then return na < nb end
		if na then return true end
		if nb then return false end
		return tostring(a) < tostring(b)
	end)
	for i = 1, #missing do
		result[#result + 1] = missing[i]
	end
	return result
end

local function getSpellName(spellId)
	if spellId == nil then return nil end
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

local function getSpellTexture(spellId)
	if spellId == nil then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		local texture = C_Spell.GetSpellTexture(spellId)
		if texture then return texture end
	end
	if GetSpellTexture then
		local texture = GetSpellTexture(spellId)
		if texture then return texture end
	end
	return nil
end

local function ensureFamilyPresentation(family)
	if not family then return nil, nil end
	if not family._resolvedName then family._resolvedName = getSpellName(family.spellIds and family.spellIds[1]) or family.fallbackName or family.id end
	if not family._resolvedIcon then family._resolvedIcon = getSpellTexture(family.spellIds and family.spellIds[1]) or 134400 end
	return family._resolvedName, family._resolvedIcon
end

local function buildFamilyLabel(family)
	if not family then return "" end
	local name = ensureFamilyPresentation(family)
	local classToken = family.classToken or ""
	local spec = family.spec
	if spec and spec ~= "" then return spec .. " " .. classToken .. " - " .. tostring(name) end
	if classToken ~= "" then return classToken .. " - " .. tostring(name) end
	return tostring(name)
end

function HB.GetFamilyOptions(classFilter)
	local list = {}
	for i = 1, #FAMILY_ORDER do
		local family = FAMILY_BY_ID[FAMILY_ORDER[i]]
		if family then
			if classFilter == nil or classFilter == "" or classFilter == family.classToken then
				local _, icon = ensureFamilyPresentation(family)
				list[#list + 1] = {
					value = family.id,
					label = buildFamilyLabel(family),
					icon = icon,
					classToken = family.classToken,
					spec = family.spec,
					spellIds = family.spellIds,
				}
			end
		end
	end
	return list
end

function HB.GetFamilyById(id)
	if id == nil then return nil end
	local family = FAMILY_BY_ID[tostring(id)]
	if family then ensureFamilyPresentation(family) end
	return family
end

function HB.GetFamilyFromSpell(spellId)
	if spellId == nil then return nil end
	if issecretvalue and issecretvalue(spellId) then return nil end
	return SPELL_TO_FAMILY[tonumber(spellId)]
end

local function newPlacementConfig()
	return {
		enabled = false,
		version = 1,
		groupsById = {},
		groupOrder = {},
		rulesById = {},
		ruleOrder = {},
	}
end

function HB.CreateDefaultPlacement() return newPlacementConfig() end

local function getDefaultGroupName(id) return format(tr("UFGroupHealerBuffEditorIndicatorNameFormat", "Indicator %s"), tostring(id or "")) end

HB.GetDefaultGroupName = getDefaultGroupName

function HB.CreateDefaultGroup(id)
	id = tostring(id or "1")
	return {
		id = id,
		name = getDefaultGroupName(id),
		style = STYLE_ICON,
		anchorPoint = "CENTER",
		x = 0,
		y = 0,
		growth = "RIGHTDOWN",
		perRow = 3,
		max = 3,
		spacing = 0,
		size = 16,
		barOrientation = ORIENT_HORIZONTAL,
		barThickness = 6,
		inset = 0,
		borderSize = 2,
		ruleMatch = RULE_MATCH_ANY,
		iconMode = ICON_MODE_ALL,
		showCooldownSwipe = true,
		showCooldownEdge = true,
		showCooldownBling = true,
		hideCooldownText = false,
		hideChargeText = false,
		color = { 1, 0.82, 0.1, 0.9 },
	}
end

function HB.CreateDefaultRule(id, familyId, groupId)
	id = tostring(id or "1")
	return {
		id = id,
		spellFamilyId = familyId,
		groupId = tostring(groupId or "1"),
		["not"] = false,
		enabled = true,
		appliesParty = true,
		appliesRaid = true,
	}
end

local function normalizeGroup(group, id)
	if type(group) ~= "table" then return nil end
	group.id = tostring(group.id or id)
	if group.name == nil or group.name == "" then group.name = getDefaultGroupName(group.id) end
	group.style = normalizeStyle(group.style)
	group.anchorPoint = normalizeAnchor(group.anchorPoint)
	group.x = roundInt(clamp(group.x, -300, 300, 0))
	group.y = roundInt(clamp(group.y, -300, 300, 0))
	group.growth = normalizeGrowth(group.growth)
	group.perRow = roundInt(clamp(group.perRow, 1, 20, 3))
	group.max = roundInt(clamp(group.max, 0, 40, 3))
	group.spacing = roundInt(clamp(group.spacing, 0, 40, 0))
	group.size = roundInt(clamp(group.size, 4, 96, 16))
	group.barOrientation = normalizeOrientation(group.barOrientation)
	group.barThickness = roundInt(clamp(group.barThickness, 1, 96, 6))
	group.inset = roundInt(clamp(group.inset, 0, 60, 0))
	group.borderSize = roundInt(clamp(group.borderSize, 1, 24, 2))
	group.ruleMatch = normalizeRuleMatch(group.ruleMatch or group.matchMode or group.ruleMode)
	group.iconMode = normalizeIconMode(group.iconMode or group.iconDisplayMode or group.iconRuleMode)
	local showCooldownSwipe = group.showCooldownSwipe
	if showCooldownSwipe == nil then showCooldownSwipe = group.cooldownSwipe end
	group.showCooldownSwipe = showCooldownSwipe ~= false
	local showCooldownEdge = group.showCooldownEdge
	if showCooldownEdge == nil then showCooldownEdge = group.cooldownEdge end
	if showCooldownEdge == nil then showCooldownEdge = group.drawEdge end
	group.showCooldownEdge = showCooldownEdge ~= false
	local showCooldownBling = group.showCooldownBling
	if showCooldownBling == nil then showCooldownBling = group.cooldownBling end
	if showCooldownBling == nil then showCooldownBling = group.drawBling end
	group.showCooldownBling = showCooldownBling ~= false
	group.hideCooldownText = group.hideCooldownText == true
	if group.hideChargeText == nil then group.hideChargeText = group.hideStacks end
	group.hideChargeText = group.hideChargeText == true
	local cooldownTextSize = clamp(group.cooldownTextSize or group.cooldownSize or group.cooldownFontSizeOverride, 6, 64, nil)
	if cooldownTextSize ~= nil then cooldownTextSize = roundInt(cooldownTextSize) end
	group.cooldownTextSize = cooldownTextSize
	local chargeTextSize = clamp(group.chargeTextSize or group.chargeSize or group.countFontSizeOverride, 6, 64, nil)
	if chargeTextSize ~= nil then chargeTextSize = roundInt(chargeTextSize) end
	group.chargeTextSize = chargeTextSize
	group.matchMode = nil
	group.ruleMode = nil
	group.iconDisplayMode = nil
	group.iconRuleMode = nil
	group.cooldownSwipe = nil
	group.cooldownEdge = nil
	group.cooldownBling = nil
	group.drawEdge = nil
	group.drawBling = nil
	group.hideStacks = nil
	group.cooldownSize = nil
	group.chargeSize = nil
	group.cooldownFontSizeOverride = nil
	group.countFontSizeOverride = nil
	group.color = normalizeColor(group.color, { 1, 0.82, 0.1, 0.9 })
	return group
end

local function normalizeRule(rule, id)
	if type(rule) ~= "table" then return nil end
	rule.id = tostring(rule.id or id)
	local familyId = rule.spellFamilyId or rule.familyId
	if familyId ~= nil then familyId = tostring(familyId) end
	rule.spellFamilyId = familyId
	rule.familyId = nil
	rule.groupId = tostring(rule.groupId or "")
	rule["not"] = rule["not"] == true
	if rule.enabled == nil then rule.enabled = true end
	rule.enabled = rule.enabled ~= false
	local appliesParty = rule.appliesParty
	if appliesParty == nil then appliesParty = rule.appliesToParty end
	if appliesParty == nil then appliesParty = rule.party end
	if appliesParty == nil then appliesParty = true end
	local appliesRaid = rule.appliesRaid
	if appliesRaid == nil then appliesRaid = rule.appliesToRaid end
	if appliesRaid == nil then appliesRaid = rule.raid end
	if appliesRaid == nil then appliesRaid = true end
	rule.appliesParty = appliesParty ~= false
	rule.appliesRaid = appliesRaid ~= false
	rule.appliesToParty = nil
	rule.appliesToRaid = nil
	rule.party = nil
	rule.raid = nil
	rule.color = normalizeOptionalColor(rule.color or rule.spellColor)
	rule.spellColor = nil
	return rule
end

function HB.EnsureConfig(cfg)
	if type(cfg) ~= "table" then return nil end
	local placement = cfg.healerBuffPlacement
	if type(placement) ~= "table" then
		placement = newPlacementConfig()
		cfg.healerBuffPlacement = placement
	end
	if placement.enabled == nil then placement.enabled = false end
	if placement.version == nil then placement.version = 1 end
	placement.groupsById = type(placement.groupsById) == "table" and placement.groupsById or {}
	placement.groupOrder = type(placement.groupOrder) == "table" and placement.groupOrder or {}
	placement.rulesById = type(placement.rulesById) == "table" and placement.rulesById or {}
	placement.ruleOrder = type(placement.ruleOrder) == "table" and placement.ruleOrder or {}

	local normalizedGroups = {}
	for key, group in pairs(placement.groupsById) do
		group = normalizeGroup(group, key)
		if group then normalizedGroups[group.id] = group end
	end
	placement.groupsById = normalizedGroups
	placement.groupOrder = normalizeOrder(placement.groupOrder, normalizedGroups)

	local normalizedRules = {}
	for key, rule in pairs(placement.rulesById) do
		rule = normalizeRule(rule, key)
		if rule and rule.spellFamilyId and FAMILY_BY_ID[rule.spellFamilyId] and normalizedGroups[rule.groupId] then normalizedRules[rule.id] = rule end
	end
	placement.rulesById = normalizedRules
	placement.ruleOrder = normalizeOrder(placement.ruleOrder, normalizedRules)

	return placement
end

function HB.GetNextGroupId(placement)
	placement = placement or {}
	local groups = placement.groupsById or {}
	local maxId = 0
	for id in pairs(groups) do
		local n = tonumber(id)
		if n and n > maxId then maxId = n end
	end
	return tostring(maxId + 1)
end

function HB.GetNextRuleId(placement)
	placement = placement or {}
	local rules = placement.rulesById or {}
	local maxId = 0
	for id in pairs(rules) do
		local n = tonumber(id)
		if n and n > maxId then maxId = n end
	end
	return tostring(maxId + 1)
end

HB._kindGeneration = HB._kindGeneration or {}
HB._compiledByConfig = HB._compiledByConfig or setmetatable({}, { __mode = "k" })

function HB.InvalidateKind(kind)
	kind = normalizeKind(kind)
	if not KIND_SET[kind] then return end
	HB._kindGeneration[kind] = (HB._kindGeneration[kind] or 0) + 1
end

function HB.IsEnabled(kind, cfg)
	cfg = cfg or {}
	kind = normalizeKind(kind)
	local placement = HB.EnsureConfig(cfg)
	if not placement or placement.enabled ~= true then return false end
	if not KIND_SET[kind] then return false end
	if not next(placement.groupsById or EMPTY) then return false end
	if not next(placement.rulesById or EMPTY) then return false end
	return true
end

local function buildRulePseudoAuraId(ruleId)
	local numeric = tonumber(ruleId)
	if numeric then return -700000 - numeric end
	local hash = 0
	ruleId = tostring(ruleId or "")
	for i = 1, #ruleId do
		hash = ((hash * 33) + ruleId:byte(i)) % 100000
	end
	return -800000 - hash
end

local function ruleAppliesToKind(rule, kind)
	if not rule then return false end
	if kind == KIND_PARTY then return rule.appliesParty ~= false end
	if kind == KIND_RAID then return rule.appliesRaid ~= false end
	return false
end

local function compile(kind, cfg)
	kind = normalizeKind(kind)
	local placement = HB.EnsureConfig(cfg)
	if not placement then return nil end
	local generation = HB._kindGeneration[kind] or 0
	local cachedByKind = HB._compiledByConfig[cfg]
	local cached = cachedByKind and cachedByKind[kind]
	if cached and cached.generation == generation then return cached end

	local compiled = {
		kind = kind,
		generation = generation,
		placement = placement,
		groupsById = placement.groupsById,
		groupOrder = placement.groupOrder,
		rulesById = placement.rulesById,
		ruleOrder = placement.ruleOrder,
		ruleById = {},
		groupToRuleIds = {},
		groupToEnabledRuleIds = {},
		familyToRuleIds = {},
		suppressedFamilies = {},
		groupOrderByStyle = {
			[STYLE_ICON] = {},
			[STYLE_SQUARE] = {},
			[STYLE_BAR] = {},
			[STYLE_BORDER] = {},
			[STYLE_TINT] = {},
		},
		spellToFamily = SPELL_TO_FAMILY,
		enabled = false,
	}

	for i = 1, #compiled.groupOrder do
		local groupId = compiled.groupOrder[i]
		local group = compiled.groupsById[groupId]
		if group then
			compiled.groupToRuleIds[groupId] = compiled.groupToRuleIds[groupId] or {}
			compiled.groupToEnabledRuleIds[groupId] = compiled.groupToEnabledRuleIds[groupId] or {}
			compiled.groupOrderByStyle[group.style][#compiled.groupOrderByStyle[group.style] + 1] = groupId
		end
	end

	for i = 1, #compiled.ruleOrder do
		local ruleId = compiled.ruleOrder[i]
		local rule = compiled.rulesById[ruleId]
		if rule and ruleAppliesToKind(rule, kind) then
			local familyId = rule.spellFamilyId
			local groupId = rule.groupId
			if familyId and FAMILY_BY_ID[familyId] and groupId and compiled.groupsById[groupId] then
				rule._pseudoAuraInstanceId = rule._pseudoAuraInstanceId or buildRulePseudoAuraId(rule.id)
				compiled.ruleById[ruleId] = rule
				local byFamily = compiled.familyToRuleIds[familyId]
				if not byFamily then
					byFamily = {}
					compiled.familyToRuleIds[familyId] = byFamily
				end
				byFamily[#byFamily + 1] = ruleId
				if rule.enabled ~= false then compiled.suppressedFamilies[familyId] = true end
				local byGroup = compiled.groupToRuleIds[groupId]
				if not byGroup then
					byGroup = {}
					compiled.groupToRuleIds[groupId] = byGroup
				end
				byGroup[#byGroup + 1] = ruleId
				if rule.enabled ~= false then
					local byGroupEnabled = compiled.groupToEnabledRuleIds[groupId]
					if not byGroupEnabled then
						byGroupEnabled = {}
						compiled.groupToEnabledRuleIds[groupId] = byGroupEnabled
					end
					byGroupEnabled[#byGroupEnabled + 1] = ruleId
				end
			end
		end
	end

	if placement.enabled == true and next(compiled.ruleById) and next(compiled.groupsById) and KIND_SET[kind] then compiled.enabled = true end
	cachedByKind = cachedByKind or {}
	cachedByKind[kind] = compiled
	HB._compiledByConfig[cfg] = cachedByKind
	return compiled
end

local function roundToPixel(value, scale)
	if GFH and GFH.RoundToPixel then return GFH.RoundToPixel(value, scale) end
	return roundInt(value)
end

local function getEffectiveScale(frame)
	if GFH and GFH.GetEffectiveScale then return GFH.GetEffectiveScale(frame) end
	if frame and frame.GetEffectiveScale then
		local scale = frame:GetEffectiveScale()
		if scale and scale > 0 then return scale end
	end
	return 1
end

local function getGrowthAxes(growth)
	local axes = GROWTH_AXES[normalizeGrowth(growth)]
	if axes then return axes[1], axes[2] end
	return "RIGHT", "DOWN"
end

local function clearHiddenAuraButton(btn)
	if not btn then return end
	btn._showTooltip = false
	if btn.SetMouseClickEnabled then btn:SetMouseClickEnabled(false) end
	if btn.SetMouseMotionEnabled then btn:SetMouseMotionEnabled(false) end
	if btn.EnableMouse then btn:EnableMouse(false) end
	if btn.Hide then btn:Hide() end
end

local function hideButtons(buttons, startIndex)
	if not buttons then return end
	for i = startIndex, #buttons do
		clearHiddenAuraButton(buttons[i])
	end
end

local function setAuraTooltipState(btn, show)
	if not btn then return end
	btn._showTooltip = show == true
	if btn.SetMouseClickEnabled then btn:SetMouseClickEnabled(show == true) end
	if btn.SetMouseMotionEnabled then btn:SetMouseMotionEnabled(show == true) end
	if btn.EnableMouse then btn:EnableMouse(show == true) end
	if show ~= true and GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

local function calcGridSize(shown, perRow, size, spacing, primary)
	if shown == nil or shown < 1 then return 0.001, 0.001 end
	perRow = max(1, tonumber(perRow) or 1)
	size = tonumber(size) or 16
	spacing = tonumber(spacing) or 0
	local primaryVertical = primary == "UP" or primary == "DOWN"
	local rows, cols
	if primaryVertical then
		rows = min(shown, perRow)
		cols = max(1, floor((shown + perRow - 1) / perRow))
	else
		rows = max(1, floor((shown + perRow - 1) / perRow))
		cols = min(shown, perRow)
	end
	local w = cols * size + spacing * max(0, cols - 1)
	local h = rows * size + spacing * max(0, rows - 1)
	if w <= 0 then w = 0.001 end
	if h <= 0 then h = 0.001 end
	return w, h
end

local function positionAuraButton(btn, container, primary, secondary, index, perRow, size, spacing)
	if not (btn and container) then return end
	perRow = max(1, perRow or 1)
	local primaryHorizontal = primary == "LEFT" or primary == "RIGHT"
	local row, col
	if primaryHorizontal then
		row = floor((index - 1) / perRow)
		col = (index - 1) % perRow
	else
		row = (index - 1) % perRow
		col = floor((index - 1) / perRow)
	end
	local horizontalDir = primaryHorizontal and primary or secondary
	local verticalDir = primaryHorizontal and secondary or primary
	local xSign = horizontalDir == "RIGHT" and 1 or -1
	local ySign = verticalDir == "UP" and 1 or -1
	local basePoint = (ySign == 1 and "BOTTOM" or "TOP") .. (xSign == 1 and "LEFT" or "RIGHT")
	local step = size + spacing
	local scale = getEffectiveScale(container)
	local x = roundToPixel(col * step * xSign, scale)
	local y = roundToPixel(row * step * ySign, scale)
	btn:ClearAllPoints()
	btn:SetPoint(basePoint, container, basePoint, x, y)
end

local function getState(btn)
	if not btn then return nil, nil end
	local st = btn._eqolUFState
	if not st then return nil, nil end
	local state = st._healerBuffPlacementState
	if state then return state, st end
	state = {
		auraFamilyByInstance = {},
		familyCounts = {},
		familyAura = {},
		familyAuraInstance = {},
		ruleActive = {},
		groupActive = {},
		renderHashByStyle = {},
		groupContainers = {},
		groupButtons = {},
		groupStyleCache = {},
		changedFamilies = {},
		changedRules = {},
		changedGroups = {},
		tempRuleList = {},
		tempSampleRuleActive = {},
		tempSampleGroupActive = {},
		tempSampleFamilyAura = {},
		tempSampleFamilyAuraInstance = {},
		tempSampleFamilyCounts = {},
		tempPlaceholderByRule = {},
	}
	st._healerBuffPlacementState = state
	return state, st
end

local function ensureVisualLayers(btn, st)
	if not (btn and st) then return nil end
	local parent = st.barGroup or btn
	if not parent then return nil end

	if not st.healerBuffRoot then
		st.healerBuffRoot = CreateFrame("Frame", nil, parent)
		st.healerBuffRoot:EnableMouse(false)
	end
	local root = st.healerBuffRoot
	if root.GetParent and root:GetParent() ~= parent then root:SetParent(parent) end
	root:ClearAllPoints()
	root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	if root.SetFrameStrata and parent.GetFrameStrata then root:SetFrameStrata(parent:GetFrameStrata()) end
	if root.SetFrameLevel and parent.GetFrameLevel then root:SetFrameLevel((parent:GetFrameLevel() or 0) + 12) end
	root:Show()

	if not st.healerBuffIconLayer then
		st.healerBuffIconLayer = CreateFrame("Frame", nil, root)
		st.healerBuffIconLayer:EnableMouse(false)
	end
	local iconLayer = st.healerBuffIconLayer
	if iconLayer.GetParent and iconLayer:GetParent() ~= root then iconLayer:SetParent(root) end
	iconLayer:ClearAllPoints()
	iconLayer:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	iconLayer:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
	if iconLayer.SetFrameStrata and root.GetFrameStrata then iconLayer:SetFrameStrata(root:GetFrameStrata()) end
	if iconLayer.SetFrameLevel and root.GetFrameLevel then iconLayer:SetFrameLevel((root:GetFrameLevel() or 0) + 30) end

	if not st.healerBuffTint then
		st.healerBuffTint = root:CreateTexture(nil, "ARTWORK", nil, 2)
		st.healerBuffTint:SetColorTexture(0, 0, 0, 0)
		st.healerBuffTint:Hide()
	end
	if st.healerBuffTint.GetParent and st.healerBuffTint:GetParent() ~= root then st.healerBuffTint:SetParent(root) end
	if st.healerBuffTint.SetDrawLayer then st.healerBuffTint:SetDrawLayer("ARTWORK", 2) end

	if not st.healerBuffBar then
		st.healerBuffBar = root:CreateTexture(nil, "ARTWORK", nil, 3)
		st.healerBuffBar:SetColorTexture(0, 0, 0, 0)
		st.healerBuffBar:Hide()
	end
	if st.healerBuffBar.GetParent and st.healerBuffBar:GetParent() ~= root then st.healerBuffBar:SetParent(root) end
	if st.healerBuffBar.SetDrawLayer then st.healerBuffBar:SetDrawLayer("ARTWORK", 3) end

	if not st.healerBuffBorder then
		st.healerBuffBorder = CreateFrame("Frame", nil, root, "BackdropTemplate")
		st.healerBuffBorder:EnableMouse(false)
		st.healerBuffBorder:Hide()
	end
	if st.healerBuffBorder.GetParent and st.healerBuffBorder:GetParent() ~= root then st.healerBuffBorder:SetParent(root) end
	if st.healerBuffBorder.SetFrameStrata and root.GetFrameStrata then st.healerBuffBorder:SetFrameStrata(root:GetFrameStrata()) end
	if st.healerBuffBorder.SetFrameLevel and root.GetFrameLevel then st.healerBuffBorder:SetFrameLevel((root:GetFrameLevel() or 0) + 4) end

	return root
end

local function clearHealthTint(st)
	if not st then return false end
	local changed = (st._hbHealthTintR ~= nil) or (st._hbHealthTintG ~= nil) or (st._hbHealthTintB ~= nil) or (st._hbHealthTintA ~= nil)
	st._hbHealthTintR = nil
	st._hbHealthTintG = nil
	st._hbHealthTintB = nil
	st._hbHealthTintA = nil
	return changed
end

local function hideAllVisuals(btn, st, state)
	if not st then return end
	if st.healerBuffTint then st.healerBuffTint:Hide() end
	if st.healerBuffBar then st.healerBuffBar:Hide() end
	if st.healerBuffBorder then st.healerBuffBorder:Hide() end
	local tintChanged = clearHealthTint(st)
	if state and state.groupContainers then
		for groupId, container in pairs(state.groupContainers) do
			if container then container:Hide() end
			hideButtons(state.groupButtons and state.groupButtons[groupId], 1)
		end
	end
	if tintChanged and btn and UF and UF.GroupFrames and UF.GroupFrames.UpdateHealthStyle then UF.GroupFrames:UpdateHealthStyle(btn) end
end

local function resetState(state)
	if not state then return end
	wipeTable(state.auraFamilyByInstance)
	wipeTable(state.familyCounts)
	wipeTable(state.familyAura)
	wipeTable(state.familyAuraInstance)
	wipeTable(state.ruleActive)
	wipeTable(state.groupActive)
	wipeTable(state.changedFamilies)
	wipeTable(state.changedRules)
	wipeTable(state.changedGroups)
	wipeTable(state.tempRuleList)
	wipeTable(state.renderHashByStyle)
end

local function getFamilyForAura(compiled, aura)
	if not (compiled and aura) then return nil end
	local spellId = aura.spellId
	if spellId == nil then return nil end
	if issecretvalue and issecretvalue(spellId) then return nil end
	local familyId = compiled.spellToFamily[tonumber(spellId)]
	if familyId == nil then return nil end

	local isFromPlayerOrPlayerPet = aura.isFromPlayerOrPlayerPet
	if issecretvalue and issecretvalue(isFromPlayerOrPlayerPet) then return nil end
	if isFromPlayerOrPlayerPet == true then return familyId end

	local sourceUnit = aura.sourceUnit
	if issecretvalue and issecretvalue(sourceUnit) then return nil end
	local fromPlayer = sourceUnit == "player" or sourceUnit == "pet" or sourceUnit == "vehicle"
	if not fromPlayer and UnitIsUnit and sourceUnit then
		fromPlayer = UnitIsUnit(sourceUnit, "player") or UnitIsUnit(sourceUnit, "pet") or UnitIsUnit(sourceUnit, "vehicle")
	end
	if not fromPlayer then return nil end
	return familyId
end

function HB.ShouldSuppressRegularBuffAura(kind, cfg, aura)
	if aura == nil or cfg == nil then return false end
	local compiled = compile(kind, cfg)
	if not (compiled and compiled.enabled) then return false end
	local familyId = getFamilyForAura(compiled, aura)
	if familyId == nil then return false end
	return compiled.suppressedFamilies and compiled.suppressedFamilies[familyId] == true
end

local function rebuildFamilyStateFromCache(state, compiled, cache)
	wipeTable(state.auraFamilyByInstance)
	wipeTable(state.familyCounts)
	wipeTable(state.familyAura)
	wipeTable(state.familyAuraInstance)
	if not (cache and cache.order and cache.auras) then return end
	local order = cache.order
	local auras = cache.auras
	for i = 1, #order do
		local auraId = order[i]
		local aura = auraId and auras[auraId]
		if aura and auraId then
			local familyId = getFamilyForAura(compiled, aura)
			if familyId then
				state.auraFamilyByInstance[auraId] = familyId
				state.familyCounts[familyId] = (state.familyCounts[familyId] or 0) + 1
				if not state.familyAura[familyId] then
					state.familyAura[familyId] = aura
					state.familyAuraInstance[familyId] = auraId
				end
			end
		end
	end
end

local function findRepresentativeAura(state, cache, familyId)
	if not (cache and cache.order and cache.auras and familyId) then
		state.familyAura[familyId] = nil
		state.familyAuraInstance[familyId] = nil
		return
	end
	local order = cache.order
	local auras = cache.auras
	for i = 1, #order do
		local auraId = order[i]
		if auraId and state.auraFamilyByInstance[auraId] == familyId then
			state.familyAura[familyId] = auras[auraId]
			state.familyAuraInstance[familyId] = auraId
			return
		end
	end
	state.familyAura[familyId] = nil
	state.familyAuraInstance[familyId] = nil
end

local function markFamilyChanged(changedFamilies, familyId)
	if familyId then changedFamilies[familyId] = true end
end

local function updateFamilyFromAura(state, compiled, auraId, aura, changedFamilies)
	local oldFamily = state.auraFamilyByInstance[auraId]
	local newFamily = aura and getFamilyForAura(compiled, aura) or nil
	if oldFamily == newFamily then
		if newFamily then
			state.familyAura[newFamily] = aura
			state.familyAuraInstance[newFamily] = auraId
			markFamilyChanged(changedFamilies, newFamily)
		end
		return
	end

	if oldFamily then
		local oldCount = (state.familyCounts[oldFamily] or 0) - 1
		if oldCount <= 0 then
			state.familyCounts[oldFamily] = nil
			state.familyAura[oldFamily] = nil
			state.familyAuraInstance[oldFamily] = nil
		else
			state.familyCounts[oldFamily] = oldCount
			if state.familyAuraInstance[oldFamily] == auraId then
				state.familyAura[oldFamily] = nil
				state.familyAuraInstance[oldFamily] = nil
			end
		end
		markFamilyChanged(changedFamilies, oldFamily)
	end

	if newFamily then
		state.auraFamilyByInstance[auraId] = newFamily
		state.familyCounts[newFamily] = (state.familyCounts[newFamily] or 0) + 1
		state.familyAura[newFamily] = aura
		state.familyAuraInstance[newFamily] = auraId
		markFamilyChanged(changedFamilies, newFamily)
	else
		state.auraFamilyByInstance[auraId] = nil
	end
end

local function applyDeltaToFamilyState(state, compiled, cache, updateInfo)
	local changedFamilies = state.changedFamilies
	wipeTable(changedFamilies)
	if not updateInfo then return changedFamilies end

	if updateInfo.removedAuraInstanceIDs then
		for i = 1, #updateInfo.removedAuraInstanceIDs do
			local auraId = updateInfo.removedAuraInstanceIDs[i]
			if auraId then updateFamilyFromAura(state, compiled, auraId, nil, changedFamilies) end
		end
	end

	if updateInfo.addedAuras then
		for i = 1, #updateInfo.addedAuras do
			local aura = updateInfo.addedAuras[i]
			local auraId = aura and aura.auraInstanceID
			if auraId then updateFamilyFromAura(state, compiled, auraId, aura, changedFamilies) end
		end
	end

	if updateInfo.updatedAuraInstanceIDs and cache and cache.auras then
		for i = 1, #updateInfo.updatedAuraInstanceIDs do
			local auraId = updateInfo.updatedAuraInstanceIDs[i]
			if auraId then
				local aura = cache.auras[auraId]
				updateFamilyFromAura(state, compiled, auraId, aura, changedFamilies)
			end
		end
	end

	for familyId in pairs(changedFamilies) do
		if state.familyCounts[familyId] and not state.familyAuraInstance[familyId] then findRepresentativeAura(state, cache, familyId) end
	end

	return changedFamilies
end

local function evaluateRuleActive(rule, familyCounts)
	if not rule or rule.enabled == false then return false end
	local active = (familyCounts[rule.spellFamilyId] or 0) > 0
	if rule["not"] then active = not active end
	return active
end

local function evaluateGroupActive(state, compiled, groupId)
	local active = false
	local group = compiled.groupsById and compiled.groupsById[groupId]
	local isTintAll = group and group.style == STYLE_TINT and group.ruleMatch == RULE_MATCH_ALL
	if isTintAll then
		local enabledRuleIds = compiled.groupToEnabledRuleIds[groupId]
		if enabledRuleIds and #enabledRuleIds > 0 then
			active = true
			for i = 1, #enabledRuleIds do
				if state.ruleActive[enabledRuleIds[i]] ~= true then
					active = false
					break
				end
			end
		end
	else
		local ruleIds = compiled.groupToRuleIds[groupId]
		if ruleIds then
			for i = 1, #ruleIds do
				if state.ruleActive[ruleIds[i]] then
					active = true
					break
				end
			end
		end
	end
	local changed = state.groupActive[groupId] ~= active
	state.groupActive[groupId] = active
	return changed
end

local function evaluateAllRulesAndGroups(state, compiled)
	wipeTable(state.ruleActive)
	wipeTable(state.groupActive)
	for i = 1, #compiled.ruleOrder do
		local ruleId = compiled.ruleOrder[i]
		local rule = compiled.ruleById[ruleId]
		if rule then state.ruleActive[ruleId] = evaluateRuleActive(rule, state.familyCounts) end
	end
	for i = 1, #compiled.groupOrder do
		evaluateGroupActive(state, compiled, compiled.groupOrder[i])
	end
end

local function evaluateDeltaRulesAndGroups(state, compiled, changedFamilies)
	local changedRules = state.changedRules
	local changedGroups = state.changedGroups
	wipeTable(changedRules)
	wipeTable(changedGroups)

	for familyId in pairs(changedFamilies or EMPTY) do
		local familyRules = compiled.familyToRuleIds[familyId]
		if familyRules then
			for i = 1, #familyRules do
				changedRules[familyRules[i]] = true
			end
		end
	end

	for ruleId in pairs(changedRules) do
		local rule = compiled.ruleById[ruleId]
		if rule then
			local newActive = evaluateRuleActive(rule, state.familyCounts)
			if state.ruleActive[ruleId] ~= newActive then
				state.ruleActive[ruleId] = newActive
				changedGroups[rule.groupId] = true
			end
		end
	end

	for groupId in pairs(changedGroups) do
		evaluateGroupActive(state, compiled, groupId)
	end
end

local function ensureGroupContainer(state, st, groupId)
	local container = state.groupContainers[groupId]
	if not container then
		container = CreateFrame("Frame", nil, st.healerBuffIconLayer)
		container:EnableMouse(false)
		state.groupContainers[groupId] = container
	end
	if container.GetParent and container:GetParent() ~= st.healerBuffIconLayer then container:SetParent(st.healerBuffIconLayer) end
	if container.SetFrameStrata and st.healerBuffIconLayer.GetFrameStrata then container:SetFrameStrata(st.healerBuffIconLayer:GetFrameStrata()) end
	if container.SetFrameLevel and st.healerBuffIconLayer.GetFrameLevel then container:SetFrameLevel((st.healerBuffIconLayer:GetFrameLevel() or 0) + 1) end
	return container
end

local function getAuraStyleForGroup(state, cfg, group)
	local styleCache = state.groupStyleCache[group.id]
	if not styleCache then
		styleCache = {}
		state.groupStyleCache[group.id] = styleCache
	end
	local ac = cfg and cfg.auras and cfg.auras.buff or EMPTY
	local key = table.concat({
		group.size,
		group.spacing,
		ac.showTooltip == false and 0 or 1,
		group.showCooldownSwipe == false and 0 or 1,
		group.showCooldownEdge == false and 0 or 1,
		group.showCooldownBling == false and 0 or 1,
		group.hideCooldownText == true and 1 or 0,
		group.hideChargeText == true and 1 or 0,
		tostring(group.cooldownTextSize),
		tostring(group.chargeTextSize),
		ac.showCooldown == false and 0 or 1,
		tostring(ac.showCooldownText),
		tostring(ac.cooldownAnchor),
		tostring(ac.cooldownFont),
		tostring(ac.cooldownFontSize),
		tostring(ac.cooldownFontOutline),
		tostring(ac.showStacks),
		tostring(ac.countAnchor),
		tostring(ac.countFont),
		tostring(ac.countFontSize),
		tostring(ac.countFontOutline),
	}, "|")
	if styleCache._key == key then return styleCache end

	styleCache._key = key
	styleCache.size = group.size
	styleCache.padding = group.spacing
	styleCache.showTooltip = ac.showTooltip ~= false
	styleCache.showCooldownSwipe = group.showCooldownSwipe ~= false
	styleCache.showCooldownEdge = group.showCooldownEdge ~= false
	styleCache.showCooldownBling = group.showCooldownBling ~= false
	styleCache.showCooldown = ac.showCooldown ~= false
	if group.hideCooldownText == true then
		styleCache.showCooldownText = false
	elseif ac.showCooldownText ~= nil then
		styleCache.showCooldownText = ac.showCooldownText
	else
		styleCache.showCooldownText = nil
	end
	if group.hideChargeText == true then
		styleCache.showStacks = false
	elseif ac.showStacks ~= nil then
		styleCache.showStacks = ac.showStacks
	else
		styleCache.showStacks = nil
	end
	styleCache.cooldownAnchor = ac.cooldownAnchor
	styleCache.cooldownOffset = ac.cooldownOffset
	styleCache.cooldownFont = ac.cooldownFont
	if group.cooldownTextSize ~= nil then
		styleCache.cooldownFontSize = group.cooldownTextSize
	else
		styleCache.cooldownFontSize = ac.cooldownFontSize
	end
	styleCache.cooldownFontOutline = ac.cooldownFontOutline
	styleCache.countAnchor = ac.countAnchor
	styleCache.countOffset = ac.countOffset
	styleCache.countFont = ac.countFont
	if group.chargeTextSize ~= nil then
		styleCache.countFontSize = group.chargeTextSize
	else
		styleCache.countFontSize = ac.countFontSize
	end
	styleCache.countFontOutline = ac.countFontOutline
	styleCache.showDR = false
	styleCache._eqolStyleHash = key
	return styleCache
end

local function updateGroupContainerLayout(container, group, shown)
	local growthPrimary, growthSecondary = getGrowthAxes(group.growth)
	local scale = getEffectiveScale(container)
	local ox = roundToPixel(group.x or 0, scale)
	local oy = roundToPixel(group.y or 0, scale)
	container:ClearAllPoints()
	container:SetPoint(group.anchorPoint, container:GetParent(), group.anchorPoint, ox, oy)
	local w, h = calcGridSize(shown, group.perRow, group.size, group.spacing, growthPrimary)
	container:SetSize(w, h)
	return growthPrimary, growthSecondary
end

local function resolveColor(color)
	if type(color) == "table" then return color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1, color[4] or color.a or 1 end
	return 1, 1, 1, 1
end

local function styleSquareButton(btn, color)
	if not btn then return end
	local r, g, b, a = resolveColor(color)
	if btn.icon then
		btn.icon:SetTexture("Interface\\Buttons\\WHITE8x8")
		btn.icon:SetTexCoord(0, 1, 0, 1)
		btn.icon:SetVertexColor(r, g, b, a)
	end
	if btn.border then btn.border:Hide() end
	if btn.dispelIcon then btn.dispelIcon:Hide() end
end

local function styleIconButton(btn)
	if not btn then return end
	if btn.icon then btn.icon:SetVertexColor(1, 1, 1, 1) end
end

local function getPlaceholderAura(state, ruleId, familyId)
	state.tempPlaceholderByRule = state.tempPlaceholderByRule or {}
	local aura = state.tempPlaceholderByRule[ruleId]
	if not aura then
		aura = {}
		state.tempPlaceholderByRule[ruleId] = aura
	end
	local family = FAMILY_BY_ID[familyId]
	local _, icon = ensureFamilyPresentation(family)
	aura.auraInstanceID = (FAMILY_BY_ID[familyId] and FAMILY_BY_ID[familyId]._pseudoAuraInstanceId) or buildRulePseudoAuraId(ruleId)
	aura.icon = icon or 134400
	aura.duration = 0
	aura.expirationTime = nil
	aura.applications = 1
	aura.isSample = true
	aura.spellId = family and family.spellIds and family.spellIds[1] or nil
	return aura
end

local function collectActiveRulesForGroup(state, compiled, groupId, outRules, changedFamilies, maxRules)
	wipeTable(outRules)
	local byGroup = compiled.groupToRuleIds[groupId]
	if not byGroup then return false end
	local force = false
	for i = 1, #byGroup do
		local ruleId = byGroup[i]
		if state.ruleActive[ruleId] then
			outRules[#outRules + 1] = ruleId
			local rule = compiled.ruleById[ruleId]
			if changedFamilies and rule and changedFamilies[rule.spellFamilyId] then force = true end
			if maxRules and #outRules >= maxRules then break end
		end
	end
	return force
end

local function buildRuleHash(compiled, ruleIds, familyAuraInstance, styleHash)
	local hash = tostring(styleHash or "") .. "#" .. tostring(#ruleIds)
	for i = 1, #ruleIds do
		local ruleId = ruleIds[i]
		local rule = compiled.ruleById[ruleId]
		local familyId = rule and rule.spellFamilyId
		local auraId = familyId and familyAuraInstance and familyAuraInstance[familyId] or 0
		hash = hash .. "|" .. tostring(ruleId) .. ":" .. tostring(auraId)
	end
	return hash
end

local function renderIconStyleForGroup(btn, st, state, compiled, cfg, group, changedFamilies, renderHashes)
	local container = ensureGroupContainer(state, st, group.id)
	local buttons = state.groupButtons[group.id]
	if not buttons then
		buttons = {}
		state.groupButtons[group.id] = buttons
	end

	local activeRules = state.tempRuleList
	local maxRules = (group.iconMode == ICON_MODE_PRIORITY) and 1 or nil
	local force = collectActiveRulesForGroup(state, compiled, group.id, activeRules, changedFamilies, maxRules)
	local style = getAuraStyleForGroup(state, cfg, group)
	local styleHash = tostring(style._eqolStyleHash or "") .. "|" .. tostring(group.style or STYLE_ICON)
	if group.style == STYLE_SQUARE then
		local cr, cg, cb, ca = resolveColor(group.color)
		styleHash = table.concat({ styleHash, cr, cg, cb, ca }, ":")
		for i = 1, #activeRules do
			local rule = compiled.ruleById[activeRules[i]]
			local rr, rg, rb, ra = resolveColor((rule and rule.color) or group.color)
			styleHash = styleHash .. "|" .. table.concat({ rr, rg, rb, ra }, ",")
		end
	end
	local hash = buildRuleHash(compiled, activeRules, state.familyAuraInstance, styleHash)
	if not force and renderHashes[group.id] == hash then return end
	renderHashes[group.id] = hash

	if #activeRules == 0 then
		container:Hide()
		hideButtons(buttons, 1)
		return
	end

	local primary, secondary = updateGroupContainerLayout(container, group, #activeRules)
	container:Show()
	local unitToken = btn.unit or "player"
	for index = 1, #activeRules do
		local ruleId = activeRules[index]
		local rule = compiled.ruleById[ruleId]
		local familyId = rule and rule.spellFamilyId
		local aura = familyId and state.familyAura[familyId] or nil
		if not aura then aura = getPlaceholderAura(state, ruleId, familyId) end
		local auraInstanceId = aura and aura.auraInstanceID
		local button = buttons[index]
		if not button then button = AuraUtil.ensureAuraButton(container, buttons, index, style) end
		if not button then break end
		local drawCooldownSwipe = style.showCooldownSwipe ~= false
		if button.cd and button._hbDrawCooldownSwipe ~= drawCooldownSwipe then
			button._hbDrawCooldownSwipe = drawCooldownSwipe
			if button.cd.SetDrawSwipe then button.cd:SetDrawSwipe(drawCooldownSwipe) end
		end
		local drawCooldownEdge = style.showCooldownEdge ~= false
		if button.cd and button._hbDrawCooldownEdge ~= drawCooldownEdge then
			button._hbDrawCooldownEdge = drawCooldownEdge
			if button.cd.SetDrawEdge then button.cd:SetDrawEdge(drawCooldownEdge) end
		end
		local drawCooldownBling = style.showCooldownBling ~= false
		if button.cd and button._hbDrawCooldownBling ~= drawCooldownBling then
			button._hbDrawCooldownBling = drawCooldownBling
			if button.cd.SetDrawBling then button.cd:SetDrawBling(drawCooldownBling) end
		end
		local familyChanged = changedFamilies and familyId and changedFamilies[familyId] == true
		if familyChanged or button._hbAuraInstance ~= auraInstanceId or button._hbStyleKey ~= styleHash then
			AuraUtil.applyAuraToButton(button, aura, style, false, unitToken)
			button._hbAuraInstance = auraInstanceId
			button._hbStyleKey = styleHash
		end
		if group.style == STYLE_SQUARE then
			styleSquareButton(button, (rule and rule.color) or group.color)
			setAuraTooltipState(button, false)
		else
			styleIconButton(button)
			setAuraTooltipState(button, style.showTooltip == true and (auraInstanceId and auraInstanceId > 0))
		end
		if button.SetSize then button:SetSize(group.size, group.size) end
		positionAuraButton(button, container, primary, secondary, index, group.perRow, group.size, group.spacing)
		button:Show()
	end
	hideButtons(buttons, #activeRules + 1)
end

local function hideUnusedGroupContainers(state, activeGroups)
	for groupId, container in pairs(state.groupContainers or EMPTY) do
		if not activeGroups[groupId] then
			if container then container:Hide() end
			hideButtons(state.groupButtons and state.groupButtons[groupId], 1)
		end
	end
end

local function winnerForStyle(compiled, groupActive, style)
	local order = compiled.groupOrderByStyle[style]
	if not order then return nil end
	for i = 1, #order do
		local groupId = order[i]
		if groupActive[groupId] then return compiled.groupsById[groupId], groupId end
	end
	return nil
end

local function getStyleAnchoredOffsets(root, group, inset)
	if not (root and group) then return 0, 0 end
	local rootW = root.GetWidth and root:GetWidth() or 0
	local rootH = root.GetHeight and root:GetHeight() or 0
	if rootW <= 0 or rootH <= 0 then return 0, 0 end
	local x, y = HB.ClampOffsets(group.anchorPoint, group.x, group.y, rootW, rootH, inset or 0)
	local scale = getEffectiveScale(root)
	return roundToPixel(x or 0, scale), roundToPixel(y or 0, scale)
end

local function renderBar(st, group)
	local bar = st.healerBuffBar
	if not bar then return end
	if not group then
		bar:Hide()
		return
	end
	local inset = group.inset or 0
	local thickness = max(1, group.barThickness or 6)
	local r, g, b, a = resolveColor(group.color)
	local ox, oy = getStyleAnchoredOffsets(st.healerBuffRoot, group, inset)
	bar:SetColorTexture(r, g, b, a)
	bar:ClearAllPoints()
	if group.barOrientation == ORIENT_VERTICAL then
		bar:SetPoint("TOP", st.healerBuffRoot, "TOP", ox, oy - inset)
		bar:SetPoint("BOTTOM", st.healerBuffRoot, "BOTTOM", ox, oy + inset)
		bar:SetWidth(thickness)
	else
		bar:SetPoint("LEFT", st.healerBuffRoot, "LEFT", ox + inset, oy)
		bar:SetPoint("RIGHT", st.healerBuffRoot, "RIGHT", ox - inset, oy)
		bar:SetHeight(thickness)
	end
	bar:Show()
end

local function renderBorder(st, group)
	local border = st.healerBuffBorder
	if not border then return end
	if not group then
		border:Hide()
		return
	end
	local inset = group.inset or 0
	local size = max(1, group.borderSize or 1)
	local r, g, b, a = resolveColor(group.color)
	local ox, oy = getStyleAnchoredOffsets(st.healerBuffRoot, group, inset)
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", st.healerBuffRoot, "TOPLEFT", ox + inset, oy - inset)
	border:SetPoint("BOTTOMRIGHT", st.healerBuffRoot, "BOTTOMRIGHT", ox - inset, oy + inset)
	local key = tostring(size)
	if border._hbBackdropKey ~= key then
		border._hbBackdropKey = key
		border:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = size,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
	end
	border:SetBackdropColor(0, 0, 0, 0)
	border:SetBackdropBorderColor(r, g, b, a)
	border:Show()
end

function HB.ApplyHealthTint(st, r, g, b, a)
	local strength = st and st._hbHealthTintA
	if not strength then return r, g, b, a end
	strength = clamp(strength, 0, 1, 0) or 0
	if strength <= 0 then return r, g, b, a end
	local tr = st._hbHealthTintR or r
	local tg = st._hbHealthTintG or g
	local tb = st._hbHealthTintB or b
	if strength >= 1 then return tr, tg, tb, a end
	local inv = 1 - strength
	return (r * inv) + (tr * strength), (g * inv) + (tg * strength), (b * inv) + (tb * strength), a
end

local function renderTint(btn, st, group)
	local tint = st and st.healerBuffTint
	local changed = false
	if tint then tint:Hide() end
	if not group then
		changed = clearHealthTint(st)
	else
		local r, g, b, a = resolveColor(group.color)
		a = clamp(a, 0, 1, 1) or 1
		if st._hbHealthTintR ~= r or st._hbHealthTintG ~= g or st._hbHealthTintB ~= b or st._hbHealthTintA ~= a then
			st._hbHealthTintR, st._hbHealthTintG, st._hbHealthTintB, st._hbHealthTintA = r, g, b, a
			changed = true
		end
	end
	if changed and btn and UF and UF.GroupFrames and UF.GroupFrames.UpdateHealthStyle then UF.GroupFrames:UpdateHealthStyle(btn) end
end

local function renderAll(btn, st, state, compiled, cfg, changedFamilies)
	local renderHash = state.renderHashByStyle
	renderHash[STYLE_ICON] = renderHash[STYLE_ICON] or {}
	renderHash[STYLE_SQUARE] = renderHash[STYLE_SQUARE] or {}

	local activeContainers = {}
	for i = 1, #compiled.groupOrder do
		local groupId = compiled.groupOrder[i]
		local group = compiled.groupsById[groupId]
		if group and (group.style == STYLE_ICON or group.style == STYLE_SQUARE) then
			if state.groupActive[groupId] then
				activeContainers[groupId] = true
				renderIconStyleForGroup(btn, st, state, compiled, cfg, group, changedFamilies, renderHash[group.style])
			else
				local container = state.groupContainers[groupId]
				if container then container:Hide() end
				hideButtons(state.groupButtons[groupId], 1)
				renderHash[group.style][groupId] = nil
			end
		end
	end
	hideUnusedGroupContainers(state, activeContainers)

	local barGroup, barGroupId = winnerForStyle(compiled, state.groupActive, STYLE_BAR)
	local borderGroup, borderGroupId = winnerForStyle(compiled, state.groupActive, STYLE_BORDER)
	local tintGroup, tintGroupId = winnerForStyle(compiled, state.groupActive, STYLE_TINT)

	local barHash = barGroupId
			and table.concat({
				barGroupId,
				tostring(barGroup.barOrientation),
				tostring(barGroup.barThickness),
				tostring(barGroup.inset),
				tostring(barGroup.anchorPoint),
				tostring(barGroup.x),
				tostring(barGroup.y),
				tostring(barGroup.color and barGroup.color[1]),
				tostring(barGroup.color and barGroup.color[2]),
				tostring(barGroup.color and barGroup.color[3]),
				tostring(barGroup.color and barGroup.color[4]),
			}, ":")
		or "none"
	if renderHash[STYLE_BAR] ~= barHash then
		renderHash[STYLE_BAR] = barHash
		renderBar(st, barGroup)
	end

	local borderHash = borderGroupId
			and table.concat({
				borderGroupId,
				tostring(borderGroup.borderSize),
				tostring(borderGroup.inset),
				tostring(borderGroup.anchorPoint),
				tostring(borderGroup.x),
				tostring(borderGroup.y),
				tostring(borderGroup.color and borderGroup.color[1]),
				tostring(borderGroup.color and borderGroup.color[2]),
				tostring(borderGroup.color and borderGroup.color[3]),
				tostring(borderGroup.color and borderGroup.color[4]),
			}, ":")
		or "none"
	if renderHash[STYLE_BORDER] ~= borderHash then
		renderHash[STYLE_BORDER] = borderHash
		renderBorder(st, borderGroup)
	end

	local tintHash = tintGroupId
			and table.concat({
				tintGroupId,
				tostring(tintGroup.color and tintGroup.color[1]),
				tostring(tintGroup.color and tintGroup.color[2]),
				tostring(tintGroup.color and tintGroup.color[3]),
				tostring(tintGroup.color and tintGroup.color[4]),
			}, ":")
		or "none"
	if renderHash[STYLE_TINT] ~= tintHash then
		renderHash[STYLE_TINT] = tintHash
		renderTint(btn, st, tintGroup)
	end
end

function HB.BuildButton(btn)
	local state, st = getState(btn)
	if not (state and st) then return end
	ensureVisualLayers(btn, st)
end

function HB.LayoutButton(btn)
	local state, st = getState(btn)
	if not (state and st) then return end
	ensureVisualLayers(btn, st)
end

function HB.ClearButton(btn)
	local state, st = getState(btn)
	if not (state and st) then return end
	resetState(state)
	hideAllVisuals(btn, st, state)
end

function HB.UpdateFromAuras(btn, updateInfo, cache, changed, isFullUpdate)
	local state, st = getState(btn)
	if not (state and st and btn) then return end
	local kind = normalizeKind(btn._eqolGroupKind or KIND_PARTY)
	local cfg = btn._eqolCfg
	if not cfg then return end
	local compiled = compile(kind, cfg)
	if not (compiled and compiled.enabled) then
		HB.ClearButton(btn)
		return
	end

	ensureVisualLayers(btn, st)

	if isFullUpdate or not updateInfo then
		rebuildFamilyStateFromCache(state, compiled, cache)
		evaluateAllRulesAndGroups(state, compiled)
		wipeTable(state.changedFamilies)
		for familyId in pairs(state.familyCounts) do
			state.changedFamilies[familyId] = true
		end
		renderAll(btn, st, state, compiled, cfg, state.changedFamilies)
		return
	end

	local changedFamilies = applyDeltaToFamilyState(state, compiled, cache, updateInfo)
	evaluateDeltaRulesAndGroups(state, compiled, changedFamilies)
	renderAll(btn, st, state, compiled, cfg, changedFamilies)
end

local function buildSampleState(state, compiled)
	local sampleRuleActive = state.tempSampleRuleActive
	local sampleGroupActive = state.tempSampleGroupActive
	local sampleFamilyAura = state.tempSampleFamilyAura
	local sampleFamilyAuraInstance = state.tempSampleFamilyAuraInstance
	local sampleFamilyCounts = state.tempSampleFamilyCounts

	wipeTable(sampleRuleActive)
	wipeTable(sampleGroupActive)
	wipeTable(sampleFamilyAura)
	wipeTable(sampleFamilyAuraInstance)
	wipeTable(sampleFamilyCounts)

	for i = 1, #compiled.groupOrder do
		local groupId = compiled.groupOrder[i]
		local group = compiled.groupsById and compiled.groupsById[groupId]
		local enabledRules = compiled.groupToEnabledRuleIds[groupId]
		if enabledRules and #enabledRules > 0 then
			local anyPicked = nil
			local isPriorityOnly = group and (group.style == STYLE_ICON or group.style == STYLE_SQUARE) and group.iconMode == ICON_MODE_PRIORITY
			for j = 1, #enabledRules do
				local ruleId = enabledRules[j]
				local rule = compiled.ruleById[ruleId]
				if rule then
					sampleRuleActive[ruleId] = true
					local familyId = rule.spellFamilyId
					if familyId then
						sampleFamilyCounts[familyId] = 1
						sampleFamilyAuraInstance[familyId] = rule._pseudoAuraInstanceId
						sampleFamilyAura[familyId] = getPlaceholderAura(state, ruleId, familyId)
					end
					if not anyPicked then anyPicked = ruleId end
					if isPriorityOnly then break end
				end
			end
			if anyPicked then sampleGroupActive[groupId] = true end
		end
	end

	return sampleRuleActive, sampleGroupActive, sampleFamilyAura, sampleFamilyAuraInstance, sampleFamilyCounts
end

function HB.UpdateSample(btn)
	local state, st = getState(btn)
	if not (state and st and btn) then return end
	local kind = normalizeKind(btn._eqolGroupKind or KIND_PARTY)
	local cfg = btn._eqolCfg
	if not cfg then return end
	local compiled = compile(kind, cfg)
	if not (compiled and compiled.enabled) then
		HB.ClearButton(btn)
		return
	end
	ensureVisualLayers(btn, st)

	local sampleRuleActive, sampleGroupActive, sampleFamilyAura, sampleFamilyAuraInstance = buildSampleState(state, compiled)
	state.ruleActive = sampleRuleActive
	state.groupActive = sampleGroupActive
	state.familyAura = sampleFamilyAura
	state.familyAuraInstance = sampleFamilyAuraInstance

	wipeTable(state.changedFamilies)
	for familyId in pairs(sampleFamilyAura) do
		state.changedFamilies[familyId] = true
	end
	renderAll(btn, st, state, compiled, cfg, state.changedFamilies)
end

local ANCHOR_COORDS = {
	TOPLEFT = { -0.5, 0.5 },
	TOP = { 0, 0.5 },
	TOPRIGHT = { 0.5, 0.5 },
	LEFT = { -0.5, 0 },
	CENTER = { 0, 0 },
	RIGHT = { 0.5, 0 },
	BOTTOMLEFT = { -0.5, -0.5 },
	BOTTOM = { 0, -0.5 },
	BOTTOMRIGHT = { 0.5, -0.5 },
}

function HB.ClampOffsets(anchorPoint, x, y, frameW, frameH, inset)
	anchorPoint = normalizeAnchor(anchorPoint)
	frameW = tonumber(frameW) or 0
	frameH = tonumber(frameH) or 0
	if frameW <= 0 then frameW = 200 end
	if frameH <= 0 then frameH = 100 end
	inset = clamp(inset, 0, min(frameW, frameH) * 0.5, 0) or 0

	local anchor = ANCHOR_COORDS[anchorPoint] or ANCHOR_COORDS.CENTER
	local anchorX = (anchor[1] or 0) * frameW
	local anchorY = (anchor[2] or 0) * frameH
	local minX = (-frameW * 0.5 + inset) - anchorX
	local maxX = (frameW * 0.5 - inset) - anchorX
	local minY = (-frameH * 0.5 + inset) - anchorY
	local maxY = (frameH * 0.5 - inset) - anchorY

	x = clamp(x, minX, maxX, 0) or 0
	y = clamp(y, minY, maxY, 0) or 0
	return roundInt(x), roundInt(y)
end

function HB.GetGrowthAxes(growth)
	local first, second = getGrowthAxes(growth)
	return first, second
end

function HB.GetCompiled(kind, cfg)
	if not cfg then return nil end
	return compile(kind, cfg)
end
