local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local ActionBarLabels = addon.ActionBarLabels
local constants = addon.constants or {}

local NormalizeActionBarVisibilityConfig = addon.functions.NormalizeActionBarVisibilityConfig or function() end
local NormalizeUnitFrameVisibilityConfig = addon.functions.NormalizeUnitFrameVisibilityConfig or function() end
local UpdateActionBarMouseover = addon.functions.UpdateActionBarMouseover or function() end
local UpdateUnitFrameMouseover = addon.functions.UpdateUnitFrameMouseover or function() end
local RefreshAllActionBarAnchors = addon.functions.RefreshAllActionBarAnchors or function() end
local RefreshAllActionBarVisibilityAlpha = addon.functions.RefreshAllActionBarVisibilityAlpha or function() end
local GetActionBarFadeStrength = addon.functions.GetActionBarFadeStrength or function() return 1 end
local GetFrameFadeStrength = addon.functions.GetFrameFadeStrength or function() return 1 end
local GetCooldownViewerFadeStrength = addon.functions.GetCooldownViewerFadeStrength or function() return 1 end
local RefreshAllFrameVisibilityAlpha = addon.functions.RefreshAllFrameVisibilityAlpha or function() end
local GetVisibilityRuleMetadata = addon.functions.GetVisibilityRuleMetadata or function() return {} end
local HasFrameVisibilityOverride = addon.functions.HasFrameVisibilityOverride or function() return false end
local SetCooldownViewerVisibility = addon.functions.SetCooldownViewerVisibility or function() end
local GetCooldownViewerVisibility = addon.functions.GetCooldownViewerVisibility or function() return nil end
local SetSpellActivationOverlayVisibility = addon.functions.SetSpellActivationOverlayVisibility or function() end
local GetSpellActivationOverlayVisibility = addon.functions.GetSpellActivationOverlayVisibility or function() return nil end
local getCVarOptionState = addon.functions.GetCVarOptionState or function() return false end
local setCVarOptionState = addon.functions.SetCVarOptionState or function() end

local ACTION_BAR_FRAME_NAMES = constants.ACTION_BAR_FRAME_NAMES or {}
local ACTION_BAR_ANCHOR_ORDER = constants.ACTION_BAR_ANCHOR_ORDER or {}
local ACTION_BAR_ANCHOR_CONFIG = constants.ACTION_BAR_ANCHOR_CONFIG or {}
local COOLDOWN_VIEWER_FRAMES = constants.COOLDOWN_VIEWER_FRAMES or {}
local COOLDOWN_VIEWER_VISIBILITY_MODES = constants.COOLDOWN_VIEWER_VISIBILITY_MODES
	or {
		IN_COMBAT = "IN_COMBAT",
		WHILE_MOUNTED = "WHILE_MOUNTED",
		WHILE_NOT_MOUNTED = "WHILE_NOT_MOUNTED",
		SKYRIDING_ACTIVE = "SKYRIDING_ACTIVE",
		SKYRIDING_INACTIVE = "SKYRIDING_INACTIVE",
		FLYING_ACTIVE = "FLYING_ACTIVE",
		FLYING_INACTIVE = "FLYING_INACTIVE",
		MOUSEOVER = "MOUSEOVER",
		PLAYER_HAS_TARGET = "PLAYER_HAS_TARGET",
		PLAYER_CASTING = "PLAYER_CASTING",
		PLAYER_IN_GROUP = "PLAYER_IN_GROUP",
		NONE = "NONE",
		HIDE_WHILE_MOUNTED = "HIDE_WHILE_MOUNTED",
	}
local wipe = wipe
local fontOrder = {}
local borderOrder = {}
local QUICK_SLOT_BORDER = "Interface\\Buttons\\UI-Quickslot2"

local function getCachedLSMMedia(mediaType)
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames(mediaType)
	local hash = addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash(mediaType)
	if type(names) == "table" and type(hash) == "table" then return names, hash end
	return {}, {}
end

local function getGlobalFontConfigKey()
	if addon.functions and addon.functions.GetGlobalFontConfigKey then return addon.functions.GetGlobalFontConfigKey() end
	return "__EQOL_GLOBAL_FONT__"
end

local function getGlobalFontConfigLabel()
	if addon.functions and addon.functions.GetGlobalFontConfigLabel then return addon.functions.GetGlobalFontConfigLabel() end
	return "Use global font config"
end

addon.db = addon.db or {}
addon.db.actionBarHiddenHotkeys = type(addon.db.actionBarHiddenHotkeys) == "table" and addon.db.actionBarHiddenHotkeys or {}

local function collectRuleOptions(kind)
	local options = {}
	for key, data in pairs(GetVisibilityRuleMetadata() or {}) do
		if data.appliesTo and data.appliesTo[kind] then table.insert(options, {
			value = key,
			text = data.label or key,
			order = data.order or 999,
		}) end
	end
	table.sort(options, function(a, b)
		if a.order == b.order then return a.text < b.text end
		return a.order < b.order
	end)
	return options
end

local function isEQoLUnitEnabled(unit)
	if not addon.Aura then return false end
	local db = addon.db and addon.db.ufFrames
	if not db then return false end
	if unit == "boss" then
		local bossCfg = db.boss
		if bossCfg and bossCfg.enabled then return true end
		for i = 1, 5 do
			local cfg = db["boss" .. i]
			if cfg and cfg.enabled then return true end
		end
		return false
	end
	local cfg = db[unit]
	return cfg and cfg.enabled == true
end

local function shouldShowBlizzardFrameVisibility(info)
	if not addon.Aura then return true end
	if not info or not info.name then return true end
	if info.name == "PlayerFrame" then return not isEQoLUnitEnabled("player") end
	if info.name == "TargetFrame" then return not isEQoLUnitEnabled("target") end
	if info.name == "FocusFrame" then return not isEQoLUnitEnabled("focus") end
	if info.name == "PetFrame" then return not isEQoLUnitEnabled("pet") end
	if info.name == "BossTargetFrameContainer" then return not isEQoLUnitEnabled("boss") end
	return true
end

local ACTIONBAR_RULE_OPTIONS = collectRuleOptions("actionbar")
local function notifyFrameRuleLocked(label)
	local base = L["visibilityRule_lockedByUF"] or "Visibility is controlled by Enhanced Unit Frames. Disable them to change this setting."
	if label and label ~= "" then base = base .. " (" .. tostring(label) .. ")" end
	print("|cff00ff98Enhance QoL|r: " .. base)
end

local function buildFontDropdown(targetOrder, includeGlobalOption)
	local map = {
		[addon.variables.defaultFont] = L["actionBarFontDefault"] or "Blizzard Font",
	}
	local globalKey = getGlobalFontConfigKey()
	if includeGlobalOption ~= false then map[globalKey] = getGlobalFontConfigLabel() end
	local names, hash = getCachedLSMMedia("font")
	for i = 1, #names do
		local name = names[i]
		local path = hash[name]
		if type(path) == "string" and path ~= "" then map[path] = tostring(name) end
	end
	local list, order = addon.functions.prepareListForDropdown(map)
	wipe(targetOrder)
	if includeGlobalOption ~= false and list[globalKey] then targetOrder[#targetOrder + 1] = globalKey end
	for _, key in ipairs(order) do
		if key ~= globalKey then targetOrder[#targetOrder + 1] = key end
	end
	return list
end

local function buildOverrideFontDropdown() return buildFontDropdown(fontOrder, true) end

local function buildBorderDropdown()
	local map = {}
	local order = {}
	local function add(key, label)
		if not key or key == "" or map[key] then return end
		map[key] = label
		order[#order + 1] = key
	end

	add("DEFAULT", L["actionBarBorderDefault"] or "Default (Blizzard)")
	add(QUICK_SLOT_BORDER, L["actionBarBorderQuickslot"] or "Quickslot (Bartender-style)")

	local names, hash = getCachedLSMMedia("border")
	for i = 1, #names do
		local name = names[i]
		local path = hash[name]
		if type(path) == "string" and path ~= "" then add(path, tostring(name)) end
	end

	wipe(borderOrder)
	for i, key in ipairs(order) do
		borderOrder[i] = key
	end
	return map
end

local function createActionBarVisibility(category, expandable)
	if #ACTIONBAR_RULE_OPTIONS == 0 then return end

	addon.functions.SettingsCreateHeadline(category, L["visibilityScenarioGroupTitle"] or ACTIONBARS_LABEL, { parentSection = expandable })

	local explain = L["ActionbarVisibilityExplain2"]
	if explain and _G["HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_ALWAYS"] and _G["HUD_EDIT_MODE_MENU"] then
		addon.functions.SettingsCreateText(category, explain:format(_G["HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_ALWAYS"], _G["HUD_EDIT_MODE_MENU"]), { parentSection = expandable })
	end

	local bars, seenVars = {}, {}
	for _, info in ipairs(addon.variables.actionBarNames or {}) do
		if info.var and not seenVars[info.var] then
			table.insert(bars, info)
			seenVars[info.var] = true
		end
	end

	table.sort(bars, function(a, b) return (a.text or a.name or "") < (b.text or b.name or "") end)

	for _, info in ipairs(bars) do
		if info.var and info.name then
			local exp = expandable
			local ABRule = collectRuleOptions("actionbar")

			addon.functions.SettingsCreateMultiDropdown(category, {
				var = info.var .. "_visibility",
				text = info.text or info.name or info.var,
				options = ABRule,
				isSelectedFunc = function(key)
					local cfg = NormalizeActionBarVisibilityConfig(info.var)
					return cfg and cfg[key] == true
				end,
				setSelectedFunc = function(key, shouldSelect)
					local working = addon.db[info.var]
					if type(working) ~= "table" then working = {} end
					if shouldSelect then
						working[key] = true
					else
						working[key] = nil
					end
					local normalized = NormalizeActionBarVisibilityConfig(info.var, working)
					UpdateActionBarMouseover(info.name, normalized, info.var)
				end,
				parentSection = exp,
			})
		end
	end

	addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarMouseoverShowAll",
		text = L["actionBarMouseoverShowAll"] or "Show all action bars on mouseover",
		desc = L["actionBarMouseoverShowAllDesc"] or "When any action bar is hovered, show every action bar that uses the Mouseover rule.",
		func = function(value)
			addon.db.actionBarMouseoverShowAll = value and true or false
			for _, info in ipairs(addon.variables.actionBarNames or {}) do
				if info.var and info.name then
					local normalized = NormalizeActionBarVisibilityConfig(info.var)
					UpdateActionBarMouseover(info.name, normalized, info.var)
				end
			end
			RefreshAllActionBarVisibilityAlpha()
		end,
		parentSection = expandable,
	})

	local function getFadePercent()
		local value = GetActionBarFadeStrength()
		if value < 0 then value = 0 end
		if value > 1 then value = 1 end
		return math.floor((value * 100) + 0.5)
	end

	addon.functions.SettingsCreateSlider(category, {
		var = "actionBarFadeStrength",
		text = L["actionBarFadeStrength"] or "Fade amount",
		desc = L["actionBarFadeStrengthDesc"],
		min = 0,
		max = 100,
		step = 1,
		default = 100,
		get = getFadePercent,
		set = function(val)
			local pct = tonumber(val) or 0
			if pct < 0 then pct = 0 end
			if pct > 100 then pct = 100 end
			addon.db.actionBarFadeStrength = pct / 100
			RefreshAllActionBarVisibilityAlpha(true)
		end,
		parentSection = expandable,
	})
end

local function createAnchorControls(category, expandable)
	if #ACTION_BAR_FRAME_NAMES == 0 then return end

	addon.functions.SettingsCreateHeadline(category, L["actionBarAnchorSectionTitle"] or "Button growth", { parentSection = expandable })

	local anchorToggle = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarAnchorEnabled",
		text = L["actionBarAnchorEnable"] or "Modify Action Bar anchor",
		desc = L["actionBarAnchorEnableDesc"],
		func = function(value)
			addon.db["actionBarAnchorEnabled"] = value and true or false
			if value then
				RefreshAllActionBarAnchors()
			else
				addon.variables.requireReload = true
				addon.functions.checkReloadFrame()
			end
		end,
		parentSection = expandable,
	})
	local warning = L["actionBarAnchorWarning"] or "Warning: Enabling this can cause protected action errors when switching specs or opening Edit Mode."
	addon.functions.SettingsCreateText(category, "|cffff0000" .. warning .. "|r", { parentSection = expandable })

	local anchorOptions = {
		TOPLEFT = L["topLeft"] or "Top Left",
		TOPRIGHT = L["topRight"] or "Top Right",
		BOTTOMLEFT = L["bottomLeft"] or "Bottom Left",
		BOTTOMRIGHT = L["bottomRight"] or "Bottom Right",
	}
	local anchorOrder = ACTION_BAR_ANCHOR_ORDER

	for index = 1, #ACTION_BAR_FRAME_NAMES do
		local label
		if L["actionBarAnchorDropdown"] then
			label = L["actionBarAnchorDropdown"]:format(index)
		else
			label = string.format("Action Bar %d button anchor", index)
		end

		local dbKey = "actionBarAnchor" .. index
		local defaultKey = "actionBarAnchorDefault" .. index

		addon.functions.SettingsCreateDropdown(category, {
			var = dbKey,
			text = label,
			list = anchorOptions,
			order = anchorOrder,
			default = addon.db[defaultKey] or ACTION_BAR_ANCHOR_ORDER[1],
			get = function()
				local current = addon.db[dbKey]
				if not current or not ACTION_BAR_ANCHOR_CONFIG[current] then current = addon.db[defaultKey] end
				if not current or not ACTION_BAR_ANCHOR_CONFIG[current] then current = ACTION_BAR_ANCHOR_ORDER[1] end
				return current
			end,
			set = function(key)
				if not ACTION_BAR_ANCHOR_CONFIG[key] then return end
				addon.db[dbKey] = key
				RefreshAllActionBarAnchors()
			end,
			parent = true,
			element = anchorToggle.element,
			parentCheck = function() return anchorToggle.setting and anchorToggle.setting:GetValue() == true end,
			parentSection = expandable,
		})
	end
end

local function createButtonAppearanceControls(category, expandable)
	addon.functions.SettingsCreateHeadline(category, L["actionBarAppearanceHeader"] or "Button appearance", { parentSection = expandable })

	local hideBorders
	local function getBorderStyle()
		local current = addon.db.actionBarBorderStyle or "DEFAULT"
		local list = buildBorderDropdown()
		if not list[current] then current = "DEFAULT" end
		return current
	end
	local function isDefaultBorderStyle() return getBorderStyle() == "DEFAULT" end

	addon.functions.SettingsCreateScrollDropdown(category, {
		var = "actionBarBorderStyle",
		text = L["actionBarBorderStyle"] or "Action button border",
		desc = L["actionBarBorderStyleDesc"] or "Pick a custom border for action buttons. Selecting a custom border hides the Blizzard border.",
		listFunc = buildBorderDropdown,
		order = borderOrder,
		default = "DEFAULT",
		get = getBorderStyle,
		set = function(key)
			local list = buildBorderDropdown()
			if not list[key] then key = "DEFAULT" end
			addon.db.actionBarBorderStyle = key
			if key ~= "DEFAULT" then
				if not addon.db.actionBarHideBorders then
					addon.db.actionBarHideBorders = true
					addon.db.actionBarHideBordersAuto = true
					if hideBorders and hideBorders.setting then hideBorders.setting:SetValue(true) end
				end
			elseif addon.db.actionBarHideBordersAuto then
				addon.db.actionBarHideBordersAuto = nil
				addon.db.actionBarHideBorders = false
				if hideBorders and hideBorders.setting then hideBorders.setting:SetValue(false) end
			end
			if ActionBarLabels and ActionBarLabels.RefreshActionButtonBorders then ActionBarLabels.RefreshActionButtonBorders() end
		end,
		parentSection = expandable,
	})

	hideBorders = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarHideBorders",
		text = L["actionBarHideBorders"] or "Hide button borders",
		desc = L["actionBarHideBordersDesc"] or "Remove the default border texture around action buttons.",
		func = function(value)
			addon.db.actionBarHideBorders = value and true or false
			addon.db.actionBarHideBordersAuto = nil
			if ActionBarLabels and ActionBarLabels.RefreshActionButtonBorders then ActionBarLabels.RefreshActionButtonBorders() end
		end,
		parentCheck = isDefaultBorderStyle,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "actionBarBorderEdgeSize",
		text = L["actionBarBorderEdgeSize"] or "Border size",
		desc = L["actionBarBorderEdgeSizeDesc"] or "Edge size for SharedMedia borders (e.g., Blizzard Tooltip).",
		min = 1,
		max = 32,
		step = 1,
		default = 16,
		get = function()
			local value = tonumber(addon.db.actionBarBorderEdgeSize) or 16
			if value < 1 then value = 1 end
			if value > 32 then value = 32 end
			return value
		end,
		set = function(val)
			val = math.floor(val + 0.5)
			if val < 1 then val = 1 end
			if val > 32 then val = 32 end
			addon.db.actionBarBorderEdgeSize = val
			if ActionBarLabels and ActionBarLabels.RefreshActionButtonBorders then ActionBarLabels.RefreshActionButtonBorders() end
		end,
		parentCheck = function() return not isDefaultBorderStyle() end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "actionBarBorderPadding",
		text = L["actionBarBorderPadding"] or "Border padding",
		desc = L["actionBarBorderPaddingDesc"] or "Adjust border padding (positive grows, negative shrinks).",
		min = -8,
		max = 12,
		step = 1,
		default = 0,
		get = function()
			local value = tonumber(addon.db.actionBarBorderPadding) or 0
			if value < -8 then value = -8 end
			if value > 12 then value = 12 end
			return value
		end,
		set = function(val)
			val = math.floor(val + 0.5)
			if val < -8 then val = -8 end
			if val > 12 then val = 12 end
			addon.db.actionBarBorderPadding = val
			if ActionBarLabels and ActionBarLabels.RefreshActionButtonBorders then ActionBarLabels.RefreshActionButtonBorders() end
		end,
		parentCheck = function() return not isDefaultBorderStyle() end,
		parentSection = expandable,
	})

	local borderColorToggle = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarBorderColoring",
		text = L["actionBarBorderColoring"] or "Custom border color",
		desc = L["actionBarBorderColoringDesc"] or "Use a custom color for action button borders.",
		func = function(value)
			addon.db.actionBarBorderColoring = value and true or false
			if ActionBarLabels and ActionBarLabels.RefreshActionButtonBorders then ActionBarLabels.RefreshActionButtonBorders() end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateColorPicker(category, {
		var = "actionBarBorderColor",
		text = L["actionBarBorderColor"] or "Border color",
		callback = function()
			if ActionBarLabels and ActionBarLabels.RefreshActionButtonBorders then ActionBarLabels.RefreshActionButtonBorders() end
		end,
		parent = true,
		element = borderColorToggle.element,
		parentCheck = function() return borderColorToggle.setting and borderColorToggle.setting:GetValue() == true end,
		colorizeLabel = false,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarHideAssistedRotation",
		text = L["actionBarHideAssistedRotation"] or "Hide assisted rotation overlay",
		desc = L["actionBarHideAssistedRotationDesc"] or "Hide the Assisted Combat Rotation glow/overlay that Blizzard adds to the action button.",
		func = function(value)
			addon.db.actionBarHideAssistedRotation = value and true or false
			if addon.functions.UpdateAssistedCombatFrameHiding then addon.functions.UpdateAssistedCombatFrameHiding() end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "hideExtraActionArtwork",
		text = L["hideExtraActionArtwork"] or "Hide Extra Action/Zone Ability artwork",
		desc = L["hideExtraActionArtworkDesc"] or "Hide the decorative frame on the Extra Action Button and Zone Ability and disable mouse input on the Extra Action bar.",
		func = function(value)
			addon.db.hideExtraActionArtwork = value and true or false
			if addon.functions.ApplyExtraActionArtworkSetting then addon.functions.ApplyExtraActionArtworkSetting() end
		end,
		parentSection = expandable,
	})
end

local function createLabelControls(category, expandable)
	addon.functions.SettingsCreateHeadline(category, L["actionBarLabelGroupTitle"] or "Button text", { parentSection = expandable })
	local globalFontKey = getGlobalFontConfigKey()

	local outlineOrder = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROMEOUTLINE" }
	local outlineOptions = {
		NONE = L["fontOutlineNone"] or NONE,
		OUTLINE = L["fontOutlineThin"] or "Outline",
		THICKOUTLINE = L["fontOutlineThick"] or "Thick Outline",
		MONOCHROMEOUTLINE = L["fontOutlineMono"] or "Monochrome Outline",
	}

	local macroOverride
	local hideMacro = addon.functions.SettingsCreateCheckbox(category, {
		var = "hideMacroNames",
		text = L["hideMacroNames"],
		desc = L["hideMacroNamesDesc"],
		func = function(value)
			addon.db["hideMacroNames"] = value and true or false
			if value then
				addon.db.actionBarMacroFontOverride = false
				if macroOverride and macroOverride.setting then macroOverride.setting:SetValue(false) end
			end
			if ActionBarLabels and ActionBarLabels.RefreshAllMacroNameVisibility then ActionBarLabels.RefreshAllMacroNameVisibility() end
		end,
		parentSection = expandable,
	})

	macroOverride = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarMacroFontOverride",
		text = L["actionBarMacroFontOverride"] or "Change macro font",
		func = function(value)
			if value then
				addon.db["hideMacroNames"] = false
				if hideMacro and hideMacro.setting then hideMacro.setting:SetValue(false) end
			end
			addon.db.actionBarMacroFontOverride = value and true or false
			if ActionBarLabels and ActionBarLabels.RefreshAllMacroNameVisibility then ActionBarLabels.RefreshAllMacroNameVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parentSection = expandable,
	})

	local function macroParentCheck() return macroOverride.setting and macroOverride.setting:GetValue() == true and hideMacro.setting and hideMacro.setting:GetValue() ~= true end

	addon.functions.SettingsCreateScrollDropdown(category, {
		var = "actionBarMacroFontFace",
		text = L["actionBarMacroFontLabel"] or "Macro name font",
		listFunc = buildOverrideFontDropdown,
		order = fontOrder,
		default = globalFontKey,
		get = function()
			local current = addon.db.actionBarMacroFontFace or globalFontKey
			local list = buildOverrideFontDropdown()
			if not list[current] then current = globalFontKey end
			return current
		end,
		set = function(key)
			addon.db.actionBarMacroFontFace = key
			if ActionBarLabels and ActionBarLabels.RefreshAllMacroNameVisibility then ActionBarLabels.RefreshAllMacroNameVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = macroOverride.element,
		parentCheck = macroParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateDropdown(category, {
		var = "actionBarMacroFontOutline",
		text = L["actionBarFontOutlineLabel"] or "Font outline",
		list = outlineOptions,
		order = outlineOrder,
		default = "OUTLINE",
		get = function() return addon.db.actionBarMacroFontOutline or "OUTLINE" end,
		set = function(key)
			addon.db.actionBarMacroFontOutline = key
			if ActionBarLabels and ActionBarLabels.RefreshAllMacroNameVisibility then ActionBarLabels.RefreshAllMacroNameVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = macroOverride.element,
		parentCheck = macroParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "actionBarMacroFontSize",
		text = L["actionBarMacroFontSize"] or "Macro font size",
		min = 8,
		max = 24,
		step = 1,
		default = 12,
		get = function()
			local value = tonumber(addon.db.actionBarMacroFontSize) or 12
			if value < 8 then value = 8 end
			if value > 24 then value = 24 end
			return value
		end,
		set = function(val)
			val = math.floor(val + 0.5)
			if val < 8 then val = 8 end
			if val > 24 then val = 24 end
			addon.db.actionBarMacroFontSize = val
			if ActionBarLabels and ActionBarLabels.RefreshAllMacroNameVisibility then ActionBarLabels.RefreshAllMacroNameVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = macroOverride.element,
		parentCheck = macroParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateColorPicker(category, {
		var = "actionBarMacroFontColor",
		text = L["actionBarMacroFontColor"] or "Macro text color",
		callback = function()
			if ActionBarLabels and ActionBarLabels.RefreshAllMacroNameVisibility then ActionBarLabels.RefreshAllMacroNameVisibility() end
		end,
		parent = true,
		element = macroOverride.element,
		parentCheck = macroParentCheck,
		colorizeLabel = false,
		parentSection = expandable,
	})

	local hotkeyOverride = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarHotkeyFontOverride",
		text = L["actionBarHotkeyFontOverride"] or "Change keybind font",
		func = function(value)
			addon.db.actionBarHotkeyFontOverride = value and true or false
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyVisibility then ActionBarLabels.RefreshAllHotkeyVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parentSection = expandable,
	})

	local function hotkeyParentCheck() return hotkeyOverride.setting and hotkeyOverride.setting:GetValue() == true end

	addon.functions.SettingsCreateScrollDropdown(category, {
		var = "actionBarHotkeyFontFace",
		text = L["actionBarHotkeyFontLabel"] or "Keybind font",
		listFunc = buildOverrideFontDropdown,
		order = fontOrder,
		default = globalFontKey,
		get = function()
			local current = addon.db.actionBarHotkeyFontFace or globalFontKey
			local list = buildOverrideFontDropdown()
			if not list[current] then current = globalFontKey end
			return current
		end,
		set = function(key)
			addon.db.actionBarHotkeyFontFace = key
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyVisibility then ActionBarLabels.RefreshAllHotkeyVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = hotkeyOverride.element,
		parentCheck = hotkeyParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateDropdown(category, {
		var = "actionBarHotkeyFontOutline",
		text = L["actionBarFontOutlineLabel"] or "Font outline",
		list = outlineOptions,
		order = outlineOrder,
		default = "OUTLINE",
		get = function() return addon.db.actionBarHotkeyFontOutline or "OUTLINE" end,
		set = function(key)
			addon.db.actionBarHotkeyFontOutline = key
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyVisibility then ActionBarLabels.RefreshAllHotkeyVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = hotkeyOverride.element,
		parentCheck = hotkeyParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "actionBarHotkeyFontSize",
		text = L["actionBarHotkeyFontSize"] or "Keybind font size",
		min = 8,
		max = 24,
		step = 1,
		default = 12,
		get = function()
			local value = tonumber(addon.db.actionBarHotkeyFontSize) or 12
			if value < 8 then value = 8 end
			if value > 24 then value = 24 end
			return value
		end,
		set = function(val)
			val = math.floor(val + 0.5)
			if val < 8 then val = 8 end
			if val > 24 then val = 24 end
			addon.db.actionBarHotkeyFontSize = val
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyVisibility then ActionBarLabels.RefreshAllHotkeyVisibility() end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = hotkeyOverride.element,
		parentCheck = hotkeyParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateColorPicker(category, {
		var = "actionBarHotkeyFontColor",
		text = L["actionBarHotkeyFontColor"] or "Keybind text color",
		callback = function()
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parent = true,
		element = hotkeyOverride.element,
		parentCheck = hotkeyParentCheck,
		colorizeLabel = false,
		parentSection = expandable,
	})

	local countOverride = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarCountFontOverride",
		text = L["actionBarCountFontOverride"] or "Change charge/stack font",
		func = function(value)
			addon.db.actionBarCountFontOverride = value and true or false
			if ActionBarLabels and ActionBarLabels.RefreshAllCountStyles then ActionBarLabels.RefreshAllCountStyles() end
		end,
		parentSection = expandable,
	})

	local function countParentCheck() return countOverride.setting and countOverride.setting:GetValue() == true end

	addon.functions.SettingsCreateScrollDropdown(category, {
		var = "actionBarCountFontFace",
		text = L["actionBarCountFontLabel"] or "Charge/stack font",
		listFunc = buildOverrideFontDropdown,
		order = fontOrder,
		default = globalFontKey,
		get = function()
			local current = addon.db.actionBarCountFontFace or globalFontKey
			local list = buildOverrideFontDropdown()
			if not list[current] then current = globalFontKey end
			return current
		end,
		set = function(key)
			addon.db.actionBarCountFontFace = key
			if ActionBarLabels and ActionBarLabels.RefreshAllCountStyles then ActionBarLabels.RefreshAllCountStyles() end
		end,
		parent = true,
		element = countOverride.element,
		parentCheck = countParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateDropdown(category, {
		var = "actionBarCountFontOutline",
		text = L["actionBarFontOutlineLabel"] or "Font outline",
		list = outlineOptions,
		order = outlineOrder,
		default = "OUTLINE",
		get = function() return addon.db.actionBarCountFontOutline or "OUTLINE" end,
		set = function(key)
			addon.db.actionBarCountFontOutline = key
			if ActionBarLabels and ActionBarLabels.RefreshAllCountStyles then ActionBarLabels.RefreshAllCountStyles() end
		end,
		parent = true,
		element = countOverride.element,
		parentCheck = countParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "actionBarCountFontSize",
		text = L["actionBarCountFontSize"] or "Charge/stack font size",
		min = 8,
		max = 24,
		step = 1,
		default = 12,
		get = function()
			local value = tonumber(addon.db.actionBarCountFontSize) or 12
			if value < 8 then value = 8 end
			if value > 24 then value = 24 end
			return value
		end,
		set = function(val)
			val = math.floor(val + 0.5)
			if val < 8 then val = 8 end
			if val > 24 then val = 24 end
			addon.db.actionBarCountFontSize = val
			if ActionBarLabels and ActionBarLabels.RefreshAllCountStyles then ActionBarLabels.RefreshAllCountStyles() end
		end,
		parent = true,
		element = countOverride.element,
		parentCheck = countParentCheck,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateColorPicker(category, {
		var = "actionBarCountFontColor",
		text = L["actionBarCountFontColor"] or "Charge/stack text color",
		callback = function()
			if ActionBarLabels and ActionBarLabels.RefreshAllCountStyles then ActionBarLabels.RefreshAllCountStyles() end
		end,
		parent = true,
		element = countOverride.element,
		parentCheck = countParentCheck,
		colorizeLabel = false,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateHeadline(category, L["actionBarKeybindVisibilityHeader"] or "Keybind label visibility", { parentSection = expandable })

	local barOptions = {}
	for _, info in ipairs(addon.variables.actionBarNames or {}) do
		if info.name then table.insert(barOptions, { value = info.name, text = info.text or info.name }) end
	end
	table.sort(barOptions, function(a, b) return tostring(a.text) < tostring(b.text) end)

	addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarShortHotkeys",
		text = L["actionBarShortHotkeys"] or "Shorten keybind text",
		desc = L["actionBarShortHotkeysDesc"],
		func = function(value)
			addon.db.actionBarShortHotkeys = value and true or false
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		parentSection = expandable,
	})

	local rangeToggle = addon.functions.SettingsCreateCheckbox(category, {
		var = "actionBarFullRangeColoring",
		text = L["fullButtonRangeColoring"],
		desc = L["fullButtonRangeColoringDesc"],
		func = function(value)
			addon.db["actionBarFullRangeColoring"] = value
			if ActionBarLabels and ActionBarLabels.UpdateRangeOverlayEvents then ActionBarLabels.UpdateRangeOverlayEvents() end
			if ActionBarLabels and ActionBarLabels.RefreshAllRangeOverlays then ActionBarLabels.RefreshAllRangeOverlays() end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateColorPicker(category, {
		var = "actionBarFullRangeColor",
		text = L["rangeOverlayColor"],
		callback = function()
			if ActionBarLabels and ActionBarLabels.RefreshAllRangeOverlays then ActionBarLabels.RefreshAllRangeOverlays() end
		end,
		parent = true,
		element = rangeToggle.element,
		parentCheck = function() return rangeToggle.setting and rangeToggle.setting:GetValue() == true end,
		colorizeLabel = true,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateMultiDropdown(category, {
		var = "actionBarHiddenHotkeys",
		text = L["actionBarHideHotkeysGroup"] or "Hide keybinds per bar",
		options = barOptions,
		isSelectedFunc = function(key) return addon.db.actionBarHiddenHotkeys and addon.db.actionBarHiddenHotkeys[key] == true end,
		setSelectedFunc = function(key, shouldSelect)
			if type(addon.db.actionBarHiddenHotkeys) ~= "table" then addon.db.actionBarHiddenHotkeys = {} end
			if shouldSelect then
				addon.db.actionBarHiddenHotkeys[key] = true
			else
				addon.db.actionBarHiddenHotkeys[key] = nil
			end
			if ActionBarLabels and ActionBarLabels.RefreshAllHotkeyStyles then ActionBarLabels.RefreshAllHotkeyStyles() end
		end,
		desc = L["actionBarHideHotkeysDesc"],
		parentSection = expandable,
	})
end

local function createActionBarCategory()
	--local category = addon.functions.SettingsCreateCategory(nil, L["visibilityKindActionBars"] or ACTIONBARS_LABEL, nil, "ActionBar")
	--addon.SettingsLayout.actionBarCategory = category
	local category = addon.SettingsLayout.rootUI

	local expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = L["ActionBarsAndButtons"] or "Action Bars & Buttons",
		expanded = false,
		colorizeTitle = false,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "AutoPushSpellToActionBar",
		text = L["AutoPushSpellToActionBar"],
		get = function() return getCVarOptionState("AutoPushSpellToActionBar") end,
		func = function(value) setCVarOptionState("AutoPushSpellToActionBar", value) end,
		default = false,
		parentSection = expandable,
	})

	createActionBarVisibility(category, expandable)
	createAnchorControls(category, expandable)
	createButtonAppearanceControls(category, expandable)
	createLabelControls(category, expandable)
end

local function setFrameRule(info, key, shouldSelect)
	if not info or not info.var then return end
	if HasFrameVisibilityOverride(info.var) then
		notifyFrameRuleLocked(info.text or info.name or info.var)
		return
	end
	local working = addon.db[info.var]
	if type(working) ~= "table" then working = {} end

	if key == "ALWAYS_HIDDEN" and shouldSelect then
		working = { ALWAYS_HIDDEN = true }
	elseif shouldSelect then
		working[key] = true
		working.ALWAYS_HIDDEN = nil
	else
		working[key] = nil
	end

	NormalizeUnitFrameVisibilityConfig(info.var, working)
	UpdateUnitFrameMouseover(info.name, info)
end

local function getFrameRuleOptions(info)
	local allowedRuleSet
	if info and type(info.visibilityRules) == "table" then
		for _, ruleKey in ipairs(info.visibilityRules) do
			if type(ruleKey) == "string" and ruleKey ~= "" then
				allowedRuleSet = allowedRuleSet or {}
				allowedRuleSet[ruleKey] = true
			end
		end
	end

	local options = {}
	for key, data in pairs(GetVisibilityRuleMetadata() or {}) do
		local allowed = data.appliesTo and data.appliesTo.frame
		if allowed and data.unitRequirement and data.unitRequirement ~= info.unitToken then allowed = false end
		if allowed and allowedRuleSet and not allowedRuleSet[key] then allowed = false end
		if allowed then table.insert(options, { value = key, text = data.label or key, order = data.order or 999 }) end
	end
	table.sort(options, function(a, b)
		if a.order == b.order then return a.text < b.text end
		return a.order < b.order
	end)
	return options
end

local function createCooldownViewerDropdowns(category, expandable)
	if not category or #COOLDOWN_VIEWER_FRAMES == 0 then return end

	addon.functions.SettingsCreateHeadline(category, L["cooldownManagerHeader"] or "Show when", { parentSection = expandable })

	local options = {
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.IN_COMBAT, text = L["cooldownManagerShowCombat"] or "In combat" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.WHILE_MOUNTED, text = L["cooldownManagerShowMounted"] or "Mounted" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.WHILE_NOT_MOUNTED, text = L["cooldownManagerShowNotMounted"] or "Not mounted" },
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.SKYRIDING_ACTIVE,
			text = L["cooldownManagerShowSkyriding"] or (L["visibilityRule_skyriding"] or "While skyriding"),
		},
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.SKYRIDING_INACTIVE,
			text = L["cooldownManagerHideSkyriding"] or (L["visibilityRule_hideSkyriding"] or "Hide while skyriding"),
		},
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.FLYING_ACTIVE,
			text = L["visibilityRule_flying"] or "While flying",
		},
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.FLYING_INACTIVE,
			text = L["visibilityRule_hideFlying"] or "Hide while flying",
		},
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.PLAYER_CASTING, text = L["cooldownManagerShowCasting"] or "Player is casting" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.PLAYER_IN_GROUP, text = L["cooldownManagerShowGrouped"] or "In party/raid" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.MOUSEOVER, text = L["cooldownManagerShowMouseover"] or "On mouseover" },
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.PLAYER_HAS_TARGET,
			text = L["cooldownManagerShowTarget"] or L["visibilityRule_playerHasTarget"] or "When I have a target",
		},
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.ALWAYS_HIDDEN,
			text = L["visibilityRule_alwaysHidden"] or "Always hidden",
		},
	}
	local labels = {
		EssentialCooldownViewer = L["cooldownViewerEssential"] or "Essential Cooldown Viewer",
		UtilityCooldownViewer = L["cooldownViewerUtility"] or "Utility Cooldown Viewer",
		BuffBarCooldownViewer = L["cooldownViewerBuffBar"] or "Buff Bar Cooldowns",
		BuffIconCooldownViewer = L["cooldownViewerBuffIcon"] or "Buff Icon Cooldowns",
	}

	local desc = L["cooldownManagerShowDesc"] or "Visible while any selected condition is true."

	for _, frameName in ipairs(COOLDOWN_VIEWER_FRAMES) do
		local exp = expandable
		local label = labels[frameName] or frameName
		addon.functions.SettingsCreateMultiDropdown(category, {
			var = "cooldownViewerVisibility_" .. tostring(frameName),
			text = label,
			options = options,
			hideSummary = true,
			isSelectedFunc = function(key)
				local cfg = GetCooldownViewerVisibility(frameName)
				return cfg and cfg[key] == true
			end,
			setSelectedFunc = function(key, shouldSelect) SetCooldownViewerVisibility(frameName, key, shouldSelect) end,
			getSelection = function() return GetCooldownViewerVisibility(frameName) or {} end,
			setSelection = function(map)
				for _, opt in ipairs(options) do
					local key = opt.value
					local desired = map and map[key] == true
					SetCooldownViewerVisibility(frameName, key, desired)
				end
			end,
			desc = desc,
			parentSection = exp,
		})
	end

	local function getCooldownViewerFadePercent()
		local value = GetCooldownViewerFadeStrength()
		if value < 0 then value = 0 end
		if value > 1 then value = 1 end
		return math.floor((value * 100) + 0.5)
	end

	addon.functions.SettingsCreateSlider(category, {
		var = "cooldownViewerFadeStrength",
		text = L["cooldownViewerFadeStrength"] or "Fade amount",
		desc = L["cooldownViewerFadeStrengthDesc"],
		min = 0,
		max = 100,
		step = 1,
		default = 100,
		get = getCooldownViewerFadePercent,
		set = function(val)
			local pct = tonumber(val) or 0
			if pct < 0 then pct = 0 end
			if pct > 100 then pct = 100 end
			addon.db.cooldownViewerFadeStrength = pct / 100
			if addon.functions.ApplyCooldownViewerVisibility then addon.functions.ApplyCooldownViewerVisibility() end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "cooldownViewerSharedHover",
		text = L["cooldownManagerSharedHover"],
		default = false,
		get = function() return addon.db and addon.db.cooldownViewerSharedHover end,
		set = function(value)
			addon.db.cooldownViewerSharedHover = value
			if addon.functions.ApplyCooldownViewerVisibility then addon.functions.ApplyCooldownViewerVisibility() end
		end,
		desc = L["cooldownManagerSharedHoverDesc"],
		parentSection = expandable,
	})
end

local function createSpellActivationOverlayDropdown(category, expandable)
	if not category then return end

	addon.functions.SettingsCreateHeadline(category, L["spellActivationOverlayHeader"] or "Spell activation overlay", { parentSection = expandable })

	local options = {
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.WHILE_MOUNTED, text = L["cooldownManagerShowMounted"] or "Mounted" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.WHILE_NOT_MOUNTED, text = L["cooldownManagerShowNotMounted"] or "Not mounted" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.SKYRIDING_ACTIVE, text = L["cooldownManagerShowSkyriding"] or "While skyriding" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.SKYRIDING_INACTIVE, text = L["VisibilityCondNotSkyriding"] or "Not skyriding" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.FLYING_ACTIVE, text = L["visibilityRule_flying"] or "While flying" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.FLYING_INACTIVE, text = L["VisibilityCondNotFlying"] or "Not flying" },
		{ value = COOLDOWN_VIEWER_VISIBILITY_MODES.PLAYER_CASTING, text = L["cooldownManagerShowCasting"] or "Player is casting" },
		{
			value = COOLDOWN_VIEWER_VISIBILITY_MODES.PLAYER_HAS_TARGET,
			text = L["cooldownManagerShowTarget"] or L["visibilityRule_playerHasTarget"] or "When I have a target",
		},
	}

	addon.functions.SettingsCreateMultiDropdown(category, {
		var = "spellActivationOverlayVisibility",
		text = L["spellActivationOverlayFrame"] or "Spell Activation Overlay",
		options = options,
		hideSummary = true,
		isSelectedFunc = function(key)
			local cfg = GetSpellActivationOverlayVisibility()
			return cfg and cfg[key] == true
		end,
		setSelectedFunc = function(key, shouldSelect) SetSpellActivationOverlayVisibility(key, shouldSelect) end,
		getSelection = function() return GetSpellActivationOverlayVisibility() or {} end,
		setSelection = function(map)
			for _, opt in ipairs(options) do
				local key = opt.value
				local desired = map and map[key] == true
				SetSpellActivationOverlayVisibility(key, desired)
			end
		end,
		desc = L["spellActivationOverlayDesc"] or "Visible while any selected condition is true.",
		parentSection = expandable,
	})

	local customAlphaToggle = addon.functions.SettingsCreateCheckbox(category, {
		var = "spellActivationOverlayUseCustomAlpha",
		text = L["spellActivationOverlayUseCustomAlpha"] or "Use custom alpha",
		default = false,
		get = function() return addon.db and addon.db.spellActivationOverlayUseCustomAlpha end,
		set = function(value)
			addon.db = addon.db or {}
			addon.db.spellActivationOverlayUseCustomAlpha = value and true or false
			if addon.functions.ApplySpellActivationOverlayVisibility then addon.functions.ApplySpellActivationOverlayVisibility() end
		end,
		parentSection = expandable,
	})
	local function customAlphaEnabled() return customAlphaToggle and customAlphaToggle.setting and customAlphaToggle.setting:GetValue() == true end

	local function getAlphaPercent(key, fallback)
		local value = addon.db and addon.db[key]
		if type(value) ~= "number" then value = fallback end
		if value < 0 then value = 0 end
		if value > 1 then value = 1 end
		return math.floor((value * 100) + 0.5)
	end

	local function setAlphaPercent(key, percent)
		addon.db = addon.db or {}
		local value = tonumber(percent) or 0
		if value < 0 then value = 0 end
		if value > 100 then value = 100 end
		addon.db[key] = value / 100
		if addon.functions.ApplySpellActivationOverlayVisibility then addon.functions.ApplySpellActivationOverlayVisibility() end
	end

	addon.functions.SettingsCreateSlider(category, {
		var = "spellActivationOverlayActiveAlpha",
		text = L["spellActivationOverlayActiveAlpha"] or "Active alpha",
		min = 0,
		max = 100,
		step = 1,
		default = 100,
		get = function() return getAlphaPercent("spellActivationOverlayActiveAlpha", 1) end,
		set = function(val) setAlphaPercent("spellActivationOverlayActiveAlpha", val) end,
		element = customAlphaToggle and customAlphaToggle.element,
		parentCheck = customAlphaEnabled,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "spellActivationOverlayHiddenAlpha",
		text = L["spellActivationOverlayHiddenAlpha"] or "Hidden alpha",
		min = 0,
		max = 100,
		step = 1,
		default = 0,
		get = function() return getAlphaPercent("spellActivationOverlayHiddenAlpha", 0) end,
		set = function(val) setAlphaPercent("spellActivationOverlayHiddenAlpha", val) end,
		element = customAlphaToggle and customAlphaToggle.element,
		parentCheck = customAlphaEnabled,
		parentSection = expandable,
	})
end

local function createFrameCategory()
	local category = addon.SettingsLayout.rootUI

	local expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = L["VisibilityAndFadingFrames"] or "Visibility & Fading (Frames)",
		newTagID = "VisibilityFrames",
		expanded = false,
		colorizeTitle = false,
	})
	addon.SettingsLayout.uiFramesExpandable = expandable

	addon.functions.SettingsCreateHeadline(category, L["visibilityScenarioGroupTitle"] or (L["ActionBarVisibilityLabel"] or "Visibility"), { parentSection = expandable })
	if L["visibilityFrameExplain2"] then addon.functions.SettingsCreateText(category, L["visibilityFrameExplain2"], { parentSection = expandable }) end

	local frames = {}
	for _, info in ipairs(addon.variables.unitFrameNames or {}) do
		table.insert(frames, info)
	end
	table.sort(frames, function(a, b) return (a.text or a.name or "") < (b.text or b.name or "") end)

	local function expandWith(predicate)
		return function()
			if expandable and expandable.IsExpanded and expandable:IsExpanded() == false then return false end
			return predicate()
		end
	end

	for _, info in ipairs(frames) do
		if info.var and info.name then
			local options = getFrameRuleOptions(info)
			if #options > 0 then
				local function shouldShow() return shouldShowBlizzardFrameVisibility(info) end
				local init = addon.functions.SettingsCreateMultiDropdown(category, {
					var = info.var .. "_visibility",
					text = info.text or info.name or info.var,
					options = options,
					isSelectedFunc = function(key)
						local cfg = NormalizeUnitFrameVisibilityConfig(info.var)
						return cfg and cfg[key] == true
					end,
					setSelectedFunc = function(key, shouldSelect) setFrameRule(info, key, shouldSelect) end,
					isEnabled = function() return shouldShow() end,
					parentSection = expandWith(shouldShow),
				})
			end
		end
	end

	local function getFrameFadePercent()
		local value = GetFrameFadeStrength()
		if value < 0 then value = 0 end
		if value > 1 then value = 1 end
		return math.floor((value * 100) + 0.5)
	end

	addon.functions.SettingsCreateSlider(category, {
		var = "frameVisibilityFadeStrength",
		text = L["frameFadeStrength"] or "Fade amount",
		desc = L["frameFadeStrengthDesc"],
		min = 0,
		max = 100,
		step = 1,
		default = 100,
		get = getFrameFadePercent,
		set = function(val)
			local pct = tonumber(val) or 0
			if pct < 0 then pct = 0 end
			if pct > 100 then pct = 100 end
			addon.db.frameVisibilityFadeStrength = pct / 100
			RefreshAllFrameVisibilityAlpha()
			if addon.functions.ApplyCooldownViewerVisibility then addon.functions.ApplyCooldownViewerVisibility() end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "unclampDamageMeter",
		text = L["unclampDamageMeter"] or "Unclamp Blizzard damage meter",
		desc = L["unclampDamageMeterDesc"] or "Allow Blizzard damage meter windows to be moved beyond the screen edges.",
		func = function(value)
			addon.db["unclampDamageMeter"] = value and true or false
			if addon.functions.applyDamageMeterClamp then addon.functions.applyDamageMeterClamp() end
		end,
		default = false,
		parentSection = expandable,
	})
end

function addon.functions.initUIOptions()
	local defaults = (addon.GCDBar and addon.GCDBar.defaults) or {}
	local xpDefaults = (addon.Aura and addon.Aura.ExperienceBar and addon.Aura.ExperienceBar.defaults) or {}
	addon.functions.InitDBValue("gcdBarEnabled", false)
	addon.functions.InitDBValue("gcdBarWidth", defaults.width or 200)
	addon.functions.InitDBValue("gcdBarHeight", defaults.height or 18)
	addon.functions.InitDBValue("gcdBarTexture", defaults.texture or "DEFAULT")
	addon.functions.InitDBValue("gcdBarColor", defaults.color or { r = 1, g = 0.82, b = 0.2, a = 1 })
	addon.functions.InitDBValue("gcdBarBackgroundEnabled", defaults.bgEnabled == true)
	addon.functions.InitDBValue("gcdBarBackgroundTexture", defaults.bgTexture or "SOLID")
	addon.functions.InitDBValue("gcdBarBackgroundColor", defaults.bgColor or { r = 0, g = 0, b = 0, a = 0 })
	addon.functions.InitDBValue("gcdBarBorderEnabled", defaults.borderEnabled == true)
	addon.functions.InitDBValue("gcdBarBorderTexture", defaults.borderTexture or "DEFAULT")
	addon.functions.InitDBValue("gcdBarBorderColor", defaults.borderColor or { r = 0, g = 0, b = 0, a = 0.8 })
	addon.functions.InitDBValue("gcdBarBorderSize", defaults.borderSize or 1)
	addon.functions.InitDBValue("gcdBarBorderOffset", defaults.borderOffset or 0)
	addon.functions.InitDBValue("gcdBarProgressMode", defaults.progressMode or "REMAINING")
	addon.functions.InitDBValue("gcdBarFillDirection", defaults.fillDirection or "LEFT")
	addon.functions.InitDBValue("gcdBarAnchorTarget", defaults.anchorRelativeFrame or defaults.anchorTarget or "UIParent")
	addon.functions.InitDBValue("gcdBarAnchorPoint", defaults.anchorPoint or "CENTER")
	addon.functions.InitDBValue("gcdBarAnchorRelativePoint", defaults.anchorRelativePoint or defaults.anchorPoint or "CENTER")
	addon.functions.InitDBValue("gcdBarAnchorOffsetX", defaults.anchorOffsetX or 0)
	addon.functions.InitDBValue("gcdBarAnchorOffsetY", defaults.anchorOffsetY or -120)
	addon.functions.InitDBValue("gcdBarAnchorMatchWidth", defaults.anchorMatchRelativeWidth == true)
	addon.functions.InitDBValue("gcdBarHideInPetBattle", defaults.hideInPetBattle == true)

	if addon.GCDBar and addon.GCDBar.OnSettingChanged then addon.GCDBar:OnSettingChanged(addon.db["gcdBarEnabled"]) end

	addon.functions.InitDBValue("xpBarEnabled", false)
	addon.functions.InitDBValue("xpBarWidth", xpDefaults.width or 260)
	addon.functions.InitDBValue("xpBarHeight", xpDefaults.height or 16)
	addon.functions.InitDBValue("xpBarTexture", xpDefaults.texture or "DEFAULT")
	addon.functions.InitDBValue("xpBarColor", xpDefaults.color or { r = 0.20, g = 0.65, b = 0.95, a = 1 })
	addon.functions.InitDBValue("xpBarRestedColor", xpDefaults.restedColor or { r = 0.20, g = 0.85, b = 1.00, a = 1 })
	addon.functions.InitDBValue("xpBarRestedOverlay", xpDefaults.restedOverlayEnabled ~= false)
	addon.functions.InitDBValue("xpBarBackgroundEnabled", xpDefaults.bgEnabled == true)
	addon.functions.InitDBValue("xpBarBackgroundTexture", xpDefaults.bgTexture or "SOLID")
	addon.functions.InitDBValue("xpBarBackgroundColor", xpDefaults.bgColor or { r = 0, g = 0, b = 0, a = 0.45 })
	addon.functions.InitDBValue("xpBarBorderEnabled", xpDefaults.borderEnabled == true)
	addon.functions.InitDBValue("xpBarBorderTexture", xpDefaults.borderTexture or "DEFAULT")
	addon.functions.InitDBValue("xpBarBorderColor", xpDefaults.borderColor or { r = 0, g = 0, b = 0, a = 0.85 })
	addon.functions.InitDBValue("xpBarBorderSize", xpDefaults.borderSize or 1)
	addon.functions.InitDBValue("xpBarBorderOffset", xpDefaults.borderOffset or 0)
	addon.functions.InitDBValue("xpBarFillDirection", xpDefaults.fillDirection or "LEFT")
	addon.functions.InitDBValue("xpBarAnchorTarget", xpDefaults.anchorRelativeFrame or xpDefaults.anchorTarget or "UIParent")
	addon.functions.InitDBValue("xpBarAnchorPoint", xpDefaults.anchorPoint or "CENTER")
	addon.functions.InitDBValue("xpBarAnchorRelativePoint", xpDefaults.anchorRelativePoint or xpDefaults.anchorPoint or "CENTER")
	addon.functions.InitDBValue("xpBarAnchorOffsetX", xpDefaults.anchorOffsetX or 0)
	addon.functions.InitDBValue("xpBarAnchorOffsetY", xpDefaults.anchorOffsetY or -170)
	addon.functions.InitDBValue("xpBarAnchorMatchWidth", xpDefaults.anchorMatchRelativeWidth == true)
	addon.functions.InitDBValue("xpBarShowText", xpDefaults.textEnabled ~= false)
	addon.functions.InitDBValue("xpBarTextMode", xpDefaults.textMode or xpDefaults.textCenterMode or "CURMAXPERCENT")
	addon.functions.InitDBValue("xpBarTextLeftMode", xpDefaults.textLeftMode or "LEVEL")
	addon.functions.InitDBValue("xpBarTextCenterMode", xpDefaults.textCenterMode or xpDefaults.textMode or "CURMAXPERCENT")
	addon.functions.InitDBValue("xpBarTextRightMode", xpDefaults.textRightMode or "PERCENT_RESTED")
	addon.functions.InitDBValue("xpBarTextSize", xpDefaults.textSize or 11)
	addon.functions.InitDBValue("xpBarTextFont", xpDefaults.textFont or (addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__"))
	addon.functions.InitDBValue("xpBarTextOutline", xpDefaults.textOutline or "OUTLINE")
	addon.functions.InitDBValue("xpBarTextColor", xpDefaults.textColor or { r = 1, g = 1, b = 1, a = 1 })
	addon.functions.InitDBValue("xpBarTextAbbreviateNumbers", xpDefaults.abbreviateNumbers == true)
	addon.functions.InitDBValue("xpBarHideInPetBattle", xpDefaults.hideInPetBattle == true)
	addon.functions.InitDBValue("xpBarHideBlizzardTracking", xpDefaults.hideBlizzardTracking ~= false)

	if addon.Aura and addon.Aura.ExperienceBar and addon.Aura.ExperienceBar.OnSettingChanged then addon.Aura.ExperienceBar:OnSettingChanged(addon.db["xpBarEnabled"]) end

	local combatDefaults = (addon.CombatText and addon.CombatText.defaults) or {}
	local combatAlwaysModeCombatOnly = addon.CombatText and addon.CombatText.ALWAYS_VISIBLE_MODE_COMBAT_ONLY or "COMBAT_ONLY"
	local combatAlwaysModeStatus = addon.CombatText and addon.CombatText.ALWAYS_VISIBLE_MODE_STATUS or "STATUS"
	local combatFont = combatDefaults.fontFace or (addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__")
	local function cloneColor(value, fallback)
		local source = type(value) == "table" and value or fallback
		source = type(source) == "table" and source or { r = 1, g = 1, b = 1, a = 1 }
		return {
			r = source.r or source[1] or 1,
			g = source.g or source[2] or 1,
			b = source.b or source[3] or 1,
			a = source.a or source[4],
		}
	end
	addon.functions.InitDBValue("combatTextEnabled", false)
	addon.functions.InitDBValue("combatTextDuration", combatDefaults.duration or 3)
	addon.functions.InitDBValue("combatTextAlwaysVisible", combatDefaults.alwaysVisible == true)
	local alwaysVisibleMode = combatDefaults.alwaysVisibleMode
	if alwaysVisibleMode ~= combatAlwaysModeCombatOnly and alwaysVisibleMode ~= combatAlwaysModeStatus then alwaysVisibleMode = combatAlwaysModeStatus end
	addon.functions.InitDBValue("combatTextAlwaysVisibleMode", alwaysVisibleMode)
	addon.functions.InitDBValue("combatTextFont", combatFont)
	addon.functions.InitDBValue("combatTextFontSize", combatDefaults.fontSize or 32)
	local defaultCombatColor = cloneColor(addon.db["combatTextColor"], combatDefaults.enterColor or combatDefaults.color or { r = 1, g = 1, b = 1, a = 1 })
	addon.functions.InitDBValue("combatTextColor", cloneColor(defaultCombatColor, defaultCombatColor))
	addon.functions.InitDBValue("combatTextEnterColor", cloneColor(defaultCombatColor, defaultCombatColor))
	addon.functions.InitDBValue("combatTextLeaveColor", cloneColor(defaultCombatColor, combatDefaults.leaveColor or defaultCombatColor))

	if addon.CombatText and addon.CombatText.OnSettingChanged then addon.CombatText:OnSettingChanged(addon.db["combatTextEnabled"]) end
end

local function createNameplatesCategory()
	local category = addon.SettingsLayout.rootUI
	local label = L["NameplatesAndNames"] or "Nameplates & Names"
	local classColorCVar = "ShowClassColorInNameplate"
	if GetBuildInfo then
		local build = select(4, GetBuildInfo())
		if build == 120001 then classColorCVar = "nameplateUseClassColorForFriendlyPlayerUnitNames" end
	end

	local expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = label,
		expanded = false,
		colorizeTitle = false,
	})
	addon.SettingsLayout.uiNameplatesExpandable = expandable

	local nameplateData = {
		{
			var = "ShowClassColorInNameplate",
			text = L["ShowClassColorInNameplate"],
			get = function() return getCVarOptionState(classColorCVar) end,
			func = function(value) setCVarOptionState(classColorCVar, value) end,
			default = false,
			parentSection = expandable,
		},
		{
			var = "UnitNamePlayerGuild",
			text = L["UnitNamePlayerGuild"],
			get = function() return getCVarOptionState("UnitNamePlayerGuild") end,
			func = function(value) setCVarOptionState("UnitNamePlayerGuild", value) end,
			default = false,
			parentSection = expandable,
		},
		{
			var = "UnitNamePlayerPVPTitle",
			text = L["UnitNamePlayerPVPTitle"],
			get = function() return getCVarOptionState("UnitNamePlayerPVPTitle") end,
			func = function(value) setCVarOptionState("UnitNamePlayerPVPTitle", value) end,
			default = false,
			parentSection = expandable,
		},
	}

	table.sort(nameplateData, function(a, b) return a.text < b.text end)
	addon.functions.SettingsCreateCheckboxes(category, nameplateData)
end

local function createCastbarCategory()
	local category = addon.SettingsLayout.rootUI
	local label = L["CastbarsAndCooldowns"] or "Castbars & Cooldowns"

	local expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = label,
		expanded = false,
		colorizeTitle = false,
		newTagID = "CastbarsAndCooldowns",
	})
	addon.SettingsLayout.uiCastbarsExpandable = expandable

	addon.functions.SettingsCreateHeadline(category, C_Spell.GetSpellName(61304) or "GCD", {
		parentSection = expandable,
	})
	addon.functions.SettingsCreateCheckbox(category, {
		var = "gcdBarEnabled",
		text = L["gcdBarEnabled"] or "Enable GCD bar",
		desc = L["gcdBarDesc"],
		func = function(value)
			addon.db["gcdBarEnabled"] = value and true or false
			if addon.GCDBar and addon.GCDBar.OnSettingChanged then addon.GCDBar:OnSettingChanged(addon.db["gcdBarEnabled"]) end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateText(category, "|cffffd700" .. (L["gcdBarEditModeHint"] or "Configure size, texture, and color in Edit Mode.") .. "|r", {
		parentSection = expandable,
	})

	addon.functions.SettingsCreateHeadline(category, L["ExperienceBar"] or "Experience Bar", {
		parentSection = expandable,
	})
	local xpBarEnabled = addon.functions.SettingsCreateCheckbox(category, {
		var = "xpBarEnabled",
		text = L["xpBarEnabled"] or "Enable Experience bar",
		desc = L["xpBarDesc"] or "Shows your experience as a customizable bar.",
		func = function(value)
			addon.db["xpBarEnabled"] = value and true or false
			if addon.Aura and addon.Aura.ExperienceBar and addon.Aura.ExperienceBar.OnSettingChanged then addon.Aura.ExperienceBar:OnSettingChanged(addon.db["xpBarEnabled"]) end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateText(category, "|cffffd700" .. (L["xpBarEditModeHint"] or "Configure anchor, style, and text in Edit Mode.") .. "|r", {
		parentSection = expandable,
	})

	addon.functions.SettingsCreateHeadline(category, L["CombatText"] or "Combat text", {
		parentSection = expandable,
	})
	addon.functions.SettingsCreateCheckbox(category, {
		var = "combatTextEnabled",
		text = L["combatTextEnabled"] or "Enable combat text",
		desc = L["combatTextDesc"],
		func = function(value)
			addon.db["combatTextEnabled"] = value and true or false
			if addon.CombatText and addon.CombatText.OnSettingChanged then addon.CombatText:OnSettingChanged(addon.db["combatTextEnabled"]) end
		end,
		parentSection = expandable,
	})
	local combatAlwaysVisible = addon.functions.SettingsCreateCheckbox(category, {
		var = "combatTextAlwaysVisible",
		text = L["combatTextAlwaysVisible"] or "Always show combat text",
		desc = L["combatTextAlwaysVisibleDesc"] or "Keeps the combat text visible until the next combat state change.",
		func = function(value)
			addon.db["combatTextAlwaysVisible"] = value and true or false
			if addon.CombatText then
				if addon.CombatText.RefreshDisplayMode then
					addon.CombatText:RefreshDisplayMode()
				elseif addon.CombatText.RefreshHideTimer then
					addon.CombatText:RefreshHideTimer()
				end
			end
		end,
		parentSection = expandable,
	})
	local combatAlwaysModeCombatOnly = addon.CombatText and addon.CombatText.ALWAYS_VISIBLE_MODE_COMBAT_ONLY or "COMBAT_ONLY"
	local combatAlwaysModeStatus = addon.CombatText and addon.CombatText.ALWAYS_VISIBLE_MODE_STATUS or "STATUS"
	local combatAlwaysModeOptions = {
		[combatAlwaysModeCombatOnly] = L["combatTextAlwaysVisibleModeCombatOnly"] or "Only while in combat (+Combat)",
		[combatAlwaysModeStatus] = L["combatTextAlwaysVisibleModeStatus"] or "Always show status (+/-Combat)",
	}
	addon.functions.SettingsCreateDropdown(category, {
		var = "combatTextAlwaysVisibleMode",
		text = L["combatTextAlwaysVisibleMode"] or "Always-show mode",
		desc = L["combatTextAlwaysVisibleModeDesc"] or "Choose whether always-show mode is only active in combat, or shows + and - permanently.",
		list = combatAlwaysModeOptions,
		order = { combatAlwaysModeCombatOnly, combatAlwaysModeStatus },
		default = combatAlwaysModeStatus,
		get = function()
			local mode = addon.db["combatTextAlwaysVisibleMode"]
			if mode ~= combatAlwaysModeCombatOnly and mode ~= combatAlwaysModeStatus then mode = combatAlwaysModeStatus end
			return mode
		end,
		set = function(mode)
			if mode ~= combatAlwaysModeCombatOnly and mode ~= combatAlwaysModeStatus then mode = combatAlwaysModeStatus end
			addon.db["combatTextAlwaysVisibleMode"] = mode
			if addon.CombatText and addon.CombatText.RefreshDisplayMode then addon.CombatText:RefreshDisplayMode() end
		end,
		parent = true,
		element = combatAlwaysVisible and combatAlwaysVisible.element,
		parentCheck = function() return combatAlwaysVisible and combatAlwaysVisible.setting and combatAlwaysVisible.setting:GetValue() == true end,
		parentSection = expandable,
	})
	addon.functions.SettingsCreateText(category, "|cffffd700" .. (L["combatTextEditModeHint"] or "Configure text size, font, color, and position in Edit Mode.") .. "|r", {
		parentSection = expandable,
	})

	local function getCastbarConfig()
		addon.db = addon.db or {}
		addon.db.castbar = type(addon.db.castbar) == "table" and addon.db.castbar or {}
		local castbar = addon.Aura and (addon.Aura.Castbar or addon.Aura.UFStandaloneCastbar)
		local hasStandaloneModule = type(castbar) == "table" and type(castbar.GetConfig) == "function"
		if not hasStandaloneModule then addon.db.castbar.enabled = false end
		local cfg, defaults
		if hasStandaloneModule then
			cfg, defaults = castbar.GetConfig()
		end
		cfg = type(cfg) == "table" and cfg or addon.db.castbar
		defaults = type(defaults) == "table" and defaults or {}
		if hasStandaloneModule then
			if cfg.enabled == nil then cfg.enabled = defaults.enabled == true end
		else
			cfg.enabled = false
		end
		return cfg
	end

	local function refreshCastbar()
		local castbar = addon.Aura and (addon.Aura.Castbar or addon.Aura.UFStandaloneCastbar)
		if castbar and castbar.Refresh then castbar.Refresh() end
		if addon.functions and addon.functions.ApplyCastBarVisibility then addon.functions.ApplyCastBarVisibility() end
	end

	local function isCustomCastbarEnabled() return getCastbarConfig().enabled == true end

	local function getCastbarOptions()
		local options = {}
		if not isCustomCastbarEnabled() then table.insert(options, { value = "PlayerCastingBarFrame", text = PLAYER }) end
		if not isEQoLUnitEnabled("target") then table.insert(options, { value = "TargetFrameSpellBar", text = TARGET }) end
		if not isEQoLUnitEnabled("focus") then table.insert(options, { value = "FocusFrameSpellBar", text = FOCUS }) end
		return options
	end
	local function shouldShowCastbarDropdown() return #getCastbarOptions() > 0 end
	local function expandWith(predicate)
		return function()
			if expandable and expandable.IsExpanded and expandable:IsExpanded() == false then return false end
			return predicate()
		end
	end
	addon.functions.SettingsCreateHeadline(category, L["CastBars2"], {
		parentSection = expandable,
	})
	addon.functions.SettingsCreateCheckbox(category, {
		var = "useCustomPlayerCastbar",
		text = L["useCustomPlayerCastbar"] or "Enable castbar",
		desc = L["useCustomPlayerCastbarDesc"] or "Enable the EQoL castbar.",
		get = function() return isCustomCastbarEnabled() end,
		func = function(value)
			local castCfg = getCastbarConfig()
			castCfg.enabled = value and true or false
			refreshCastbar()
		end,
		default = false,
		parentSection = expandable,
	})
	addon.functions.SettingsCreateCheckbox(category, {
		var = "ShowTargetCastbar",
		text = L["ShowTargetCastbar"],
		get = function() return getCVarOptionState("ShowTargetCastbar") end,
		func = function(value) setCVarOptionState("ShowTargetCastbar", value) end,
		default = false,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateMultiDropdown(category, {
		var = "hiddenCastBars",
		text = L["castBarsToHide2"],
		optionfunc = getCastbarOptions,
		isSelectedFunc = function(key)
			if not key then return false end
			if addon.db.hiddenCastBars and addon.db.hiddenCastBars[key] then return true end
			return false
		end,
		setSelectedFunc = function(key, shouldSelect)
			addon.db.hiddenCastBars = addon.db.hiddenCastBars or {}
			addon.db.hiddenCastBars[key] = shouldSelect and true or false
			addon.functions.ApplyCastBarVisibility()
		end,
		isEnabled = shouldShowCastbarDropdown,
		parentSection = expandWith(shouldShowCastbarDropdown),
	})

	createCooldownViewerDropdowns(category, expandable)
	createSpellActivationOverlayDropdown(category, expandable)
end

local function ensureBarsResourcesCategory()
	local category = addon.SettingsLayout.rootUI
	local expandable = addon.SettingsLayout.uiBarsResourcesExpandable
	if expandable then return end

	expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = L["BarsAndResources"] or "Bars & Resources",
		expanded = false,
		colorizeTitle = false,
		newTagID = "ResourceBars",
	})
	addon.SettingsLayout.uiBarsResourcesExpandable = expandable
end

createActionBarCategory()
createFrameCategory()
createNameplatesCategory()
createCastbarCategory()
ensureBarsResourcesCategory()
