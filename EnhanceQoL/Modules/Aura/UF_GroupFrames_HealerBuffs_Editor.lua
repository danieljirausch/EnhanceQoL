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
local GF = UF.GroupFrames
local HB = UF.GroupFramesHealerBuffs
if not (GF and HB) then return end

UF.GroupFramesHealerBuffEditor = UF.GroupFramesHealerBuffEditor or {}
local Editor = UF.GroupFramesHealerBuffEditor

local max = math.max
local min = math.min
local floor = math.floor
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local sort = table.sort
local wipe = _G.wipe or (table and table.wipe)
local UIDropDownMenu_EnableDropDown = _G.UIDropDownMenu_EnableDropDown
local UIDropDownMenu_DisableDropDown = _G.UIDropDownMenu_DisableDropDown
local UIDropDownMenu_Enable = _G.UIDropDownMenu_Enable
local UIDropDownMenu_Disable = _G.UIDropDownMenu_Disable
local ToggleDropDownMenu = _G.ToggleDropDownMenu
local CloseDropDownMenus = _G.CloseDropDownMenus
local ColorPickerFrame = _G.ColorPickerFrame
local OpacitySliderFrame = _G.OpacitySliderFrame
local LOCALIZED_CLASS_NAMES_MALE = _G.LOCALIZED_CLASS_NAMES_MALE or {}
local LOCALIZED_CLASS_NAMES_FEMALE = _G.LOCALIZED_CLASS_NAMES_FEMALE or {}

local GROUP_ROW_HEIGHT = 22
local GROUP_ROW_GAP = 1
local RULE_ROW_HEIGHT = 24
local RULE_ROW_GAP = 2
local GROUP_VISIBLE_ROWS = 9
local RULE_VISIBLE_ROWS = 9
local EMPTY = {}

local ASSET_BG_DARK = "Interface\\AddOns\\EnhanceQoL\\Assets\\background_dark.tga"
local ASSET_BG_GRAY = "Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga"
local ASSET_BORDER_PANEL = "Interface\\AddOns\\EnhanceQoL\\Assets\\PanelBorder_"
local ASSET_BORDER_ROUND = "Interface\\AddOns\\EnhanceQoL\\Assets\\border_round_"

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

local function indexOf(list, value)
	if type(list) ~= "table" then return nil end
	for i = 1, #list do
		if list[i] == value then return i end
	end
	return nil
end

local function roundInt(value)
	local n = tonumber(value) or 0
	if n >= 0 then return floor(n + 0.5) end
	return -floor(math.abs(n) + 0.5)
end

local function applyPanelBorder(frame)
	if not frame then return end
	local borderLayer, borderSubLevel = "BORDER", 0
	local borderPath = ASSET_BORDER_PANEL
	local cornerSize = 70
	local edgeThickness = 70
	local cornerOffsets = 13

	local function makeTex(key, layer, subLevel)
		local tex = frame:CreateTexture(nil, layer or borderLayer, nil, subLevel or borderSubLevel)
		tex:SetTexture(borderPath .. key .. ".tga")
		tex:SetAlpha(0.9)
		return tex
	end

	local tl = makeTex("tl", borderLayer, borderSubLevel + 1)
	tl:SetSize(cornerSize, cornerSize)
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -cornerOffsets, cornerOffsets)

	local tr = makeTex("tr", borderLayer, borderSubLevel + 1)
	tr:SetSize(cornerSize, cornerSize)
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", cornerOffsets + 8, cornerOffsets)

	local bl = makeTex("bl", borderLayer, borderSubLevel + 1)
	bl:SetSize(cornerSize, cornerSize)
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -cornerOffsets, -cornerOffsets)

	local br = makeTex("br", borderLayer, borderSubLevel + 1)
	br:SetSize(cornerSize, cornerSize)
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", cornerOffsets + 8, -cornerOffsets)

	local top = makeTex("t", borderLayer, borderSubLevel)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
	top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
	top:SetHeight(edgeThickness)
	top:SetHorizTile(true)

	local bottom = makeTex("b", borderLayer, borderSubLevel)
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
	bottom:SetHeight(edgeThickness)
	bottom:SetHorizTile(true)

	local left = makeTex("l", borderLayer, borderSubLevel)
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
	left:SetWidth(edgeThickness)
	left:SetVertTile(true)

	local right = makeTex("r", borderLayer, borderSubLevel)
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
	right:SetWidth(edgeThickness)
	right:SetVertTile(true)
end

local function applyInsetBorder(frame, offset, alpha)
	if not frame then return end
	offset = offset or 8
	alpha = alpha or 0.72

	local layer, subLevel = "BORDER", 2
	local path = ASSET_BORDER_ROUND
	local cornerSize = 36
	local edgeSize = 36

	frame.eqolInsetParts = frame.eqolInsetParts or {}
	local parts = frame.eqolInsetParts

	local function tex(name)
		if not parts[name] then parts[name] = frame:CreateTexture(nil, layer, nil, subLevel) end
		local t = parts[name]
		t:SetAlpha(alpha)
		t:SetTexture(path .. name .. ".tga")
		t:SetDrawLayer(layer, subLevel)
		return t
	end

	local tl = tex("tl")
	tl:SetSize(cornerSize, cornerSize)
	tl:ClearAllPoints()
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -offset)

	local tr = tex("tr")
	tr:SetSize(cornerSize, cornerSize)
	tr:ClearAllPoints()
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -offset, -offset)

	local bl = tex("bl")
	bl:SetSize(cornerSize, cornerSize)
	bl:ClearAllPoints()
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", offset, offset)

	local br = tex("br")
	br:SetSize(cornerSize, cornerSize)
	br:ClearAllPoints()
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -offset, offset)

	local top = tex("t")
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
	top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
	top:SetHeight(edgeSize)
	top:SetHorizTile(true)

	local bottom = tex("b")
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
	bottom:SetHeight(edgeSize)
	bottom:SetHorizTile(true)

	local left = tex("l")
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
	left:SetWidth(edgeSize)
	left:SetVertTile(true)

	local right = tex("r")
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
	right:SetWidth(edgeSize)
	right:SetVertTile(true)
end

local function applyCardBackground(frame, dark)
	if not frame then return end
	frame._eqolCardBg = frame._eqolCardBg or frame:CreateTexture(nil, "BACKGROUND")
	frame._eqolCardBg:SetAllPoints(frame)
	frame._eqolCardBg:SetTexture(dark and ASSET_BG_DARK or ASSET_BG_GRAY)
	frame._eqolCardBg:SetAlpha(dark and 0.92 or 0.86)
	applyInsetBorder(frame, 6, dark and 0.55 or 0.68)
end

local function createLabel(parent, text, size, outline)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText(text or "")
	local font = (addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT
	label:SetFont(font, size or 12, outline or "OUTLINE")
	label:SetTextColor(0.96, 0.9, 0.72, 1)
	return label
end

local function createButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 120, height or 22)
	button:SetText(text or "")
	return button
end

local function createCheck(parent, text)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	if check.Text and text then
		check.Text:SetText(text)
		check.Text:SetTextColor(1, 1, 1, 1)
	end
	return check
end

local function createEditBox(parent, width)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetAutoFocus(false)
	box:SetSize(width or 180, 24)
	box:SetFontObject(GameFontHighlightSmall)
	return box
end

local function createSlider(parent, width, minValue, maxValue, step)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetWidth(width or 180)
	slider:SetMinMaxValues(minValue or 0, maxValue or 1)
	slider:SetValueStep(step or 1)
	slider:SetObeyStepOnDrag(true)
	if slider.Low then slider.Low:SetText(tostring(minValue or 0)) end
	if slider.High then slider.High:SetText(tostring(maxValue or 1)) end
	return slider
end

local function toggleDropdown(dropdown)
	if not dropdown then return end
	if dropdown.Button and dropdown.Button.IsEnabled and not dropdown.Button:IsEnabled() then return end
	if _G.UIDROPDOWNMENU_OPEN_MENU == dropdown then
		if CloseDropDownMenus then CloseDropDownMenus(1) end
		return
	end
	if ToggleDropDownMenu then
		ToggleDropDownMenu(1, nil, dropdown, dropdown, 0, 0)
		return
	end
	local button = dropdown.Button
	if not button and dropdown.GetName and dropdown:GetName() then button = _G[dropdown:GetName() .. "Button"] end
	if not button then return end
	if button.IsEnabled and not button:IsEnabled() then return end
	if button.Click then button:Click() end
end

local function makeDropdownFullyClickable(dropdown)
	if not dropdown or dropdown._eqolFullClick then return end
	dropdown._eqolFullClick = true
	local hit = CreateFrame("Button", nil, dropdown)
	hit:SetAllPoints(dropdown)
	local baseLevel = (dropdown.Button and dropdown.Button.GetFrameLevel and dropdown.Button:GetFrameLevel()) or (dropdown.GetFrameLevel and dropdown:GetFrameLevel()) or 1
	if hit.SetFrameLevel then hit:SetFrameLevel(baseLevel + 1) end
	hit:RegisterForClicks("LeftButtonUp")
	hit:SetScript("OnClick", function() toggleDropdown(dropdown) end)
	hit:EnableMouse(true)
	dropdown._eqolClicker = hit
end

local function createDropdown(parent, width)
	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dropdown, width or 160)
	UIDropDownMenu_SetText(dropdown, "")
	makeDropdownFullyClickable(dropdown)
	return dropdown
end

local function setControlEnabled(control, enabled)
	if not control then return end
	enabled = enabled == true
	if control.SetEnabled then
		control:SetEnabled(enabled)
	elseif enabled then
		if control.Enable then control:Enable() end
		if control.EnableMouse then control:EnableMouse(true) end
	else
		if control.Disable then control:Disable() end
		if control.EnableMouse then control:EnableMouse(false) end
	end

	-- UIDropDownMenuTemplate frames do not expose SetEnabled consistently.
	if control.Button and control.Text then
		if enabled then
			if UIDropDownMenu_EnableDropDown then
				UIDropDownMenu_EnableDropDown(control)
			elseif UIDropDownMenu_Enable then
				UIDropDownMenu_Enable(control)
			end
		else
			if UIDropDownMenu_DisableDropDown then
				UIDropDownMenu_DisableDropDown(control)
			elseif UIDropDownMenu_Disable then
				UIDropDownMenu_Disable(control)
			end
		end
	end
	if control._eqolClicker then
		control._eqolClicker:SetEnabled(enabled)
		control._eqolClicker:EnableMouse(enabled)
	end
end

local function setControlVisible(control, visible)
	if not control then return end
	if visible then
		control:Show()
	else
		control:Hide()
	end
end

local function iconMarkup(icon, size)
	if icon == nil then return "" end
	local s = tostring(size or 14)
	return "|T" .. tostring(icon) .. ":" .. s .. ":" .. s .. ":0:0|t "
end

local function getDropdownOptionText(option, withIcon)
	if not option then return "" end
	local label = option.label or option.text or tostring(option.value)
	if withIcon and option.icon then return iconMarkup(option.icon, 14) .. tostring(label) end
	return tostring(label)
end

local function setDropdown(dropdown, options, selectedValue, onSelect)
	dropdown._eqolOptions = options or {}
	dropdown._eqolSelectedValue = selectedValue
	dropdown._eqolOnSelect = onSelect

	UIDropDownMenu_Initialize(dropdown, function(self, level)
		local opts = dropdown._eqolOptions or {}
		for i = 1, #opts do
			local option = opts[i]
			local info = UIDropDownMenu_CreateInfo()
			info.text = getDropdownOptionText(option, true)
			info.value = option.value
			info.checked = option.value == dropdown._eqolSelectedValue
			info.func = function()
				dropdown._eqolSelectedValue = option.value
				UIDropDownMenu_SetText(dropdown, getDropdownOptionText(option, true))
				if dropdown._eqolOnSelect then dropdown._eqolOnSelect(option.value, option) end
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local selectedText = nil
	for i = 1, #(options or {}) do
		if options[i].value == selectedValue then
			selectedText = getDropdownOptionText(options[i], true)
			break
		end
	end
	if not selectedText then
		if selectedValue ~= nil then
			selectedText = tostring(selectedValue)
		else
			selectedText = "Select"
		end
	end
	UIDropDownMenu_SetText(dropdown, selectedText)
end

local function unpackRgba(color)
	if type(color) == "table" then return tonumber(color[1]) or 1, tonumber(color[2]) or 1, tonumber(color[3]) or 1, tonumber(color[4]) or 1 end
	return 1, 1, 1, 1
end

local function setColorPreview(button, color)
	local r, g, b, a = unpackRgba(color)
	if not button then return end
	local swatch = button.ColorSwatch or button._eqolColorSwatch or button.Swatch
	if swatch and swatch.SetColorTexture then swatch:SetColorTexture(r, g, b, a) end
end

local function showColorPicker(initialColor, onApply)
	if type(onApply) ~= "function" then return end
	local r, g, b, a = unpackRgba(initialColor)

	local function applyFromPicker(restore)
		local nr, ng, nb, na
		if type(restore) == "table" then
			nr = tonumber(restore.r) or tonumber(restore[1]) or r
			ng = tonumber(restore.g) or tonumber(restore[2]) or g
			nb = tonumber(restore.b) or tonumber(restore[3]) or b
			na = tonumber(restore.a) or tonumber(restore[4]) or a
		else
			if ColorPickerFrame and ColorPickerFrame.GetColorRGB then
				nr, ng, nb = ColorPickerFrame:GetColorRGB()
			else
				nr, ng, nb = r, g, b
			end
			if ColorPickerFrame and ColorPickerFrame.GetColorAlpha then
				na = ColorPickerFrame:GetColorAlpha()
			else
				local opacity = (OpacitySliderFrame and OpacitySliderFrame.GetValue and OpacitySliderFrame:GetValue()) or 0
				na = 1 - opacity
			end
		end
		nr = min(1, max(0, tonumber(nr) or 1))
		ng = min(1, max(0, tonumber(ng) or 1))
		nb = min(1, max(0, tonumber(nb) or 1))
		na = min(1, max(0, tonumber(na) or 1))
		onApply(nr, ng, nb, na)
	end

	if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r,
			g = g,
			b = b,
			opacity = 1 - a,
			hasOpacity = true,
			swatchFunc = function() applyFromPicker() end,
			opacityFunc = function() applyFromPicker() end,
			cancelFunc = function(restore) applyFromPicker(restore) end,
		})
		return
	end

	if not ColorPickerFrame then return end
	ColorPickerFrame.hasOpacity = true
	ColorPickerFrame.opacity = 1 - a
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
	ColorPickerFrame.func = function() applyFromPicker() end
	ColorPickerFrame.opacityFunc = function() applyFromPicker() end
	ColorPickerFrame.cancelFunc = function(restore)
		if type(restore) ~= "table" then restore = ColorPickerFrame.previousValues end
		applyFromPicker(restore)
	end
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end

local function createThinScrollFrameBar(scrollFrame, xOffset)
	if not scrollFrame then return nil end
	local parent = scrollFrame:GetParent() or scrollFrame
	local sb = CreateFrame("Slider", nil, parent)
	sb:SetOrientation("VERTICAL")
	sb:SetWidth(10)
	sb:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", xOffset or 4, 2)
	sb:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", xOffset or 4, -2)
	sb:SetValueStep(1)
	sb:SetObeyStepOnDrag(true)

	sb.track = sb:CreateTexture(nil, "BACKGROUND")
	sb.track:SetPoint("TOP", sb, "TOP", 0, -2)
	sb.track:SetPoint("BOTTOM", sb, "BOTTOM", 0, 2)
	sb.track:SetWidth(1)
	sb.track:SetColorTexture(1, 1, 1, 0.2)

	sb.channel = sb:CreateTexture(nil, "BACKGROUND", nil, -1)
	sb.channel:SetPoint("TOP", sb, "TOP", 0, 0)
	sb.channel:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	sb.channel:SetWidth(6)
	sb.channel:SetColorTexture(0, 0, 0, 0.3)

	local thumb = sb:CreateTexture(nil, "ARTWORK")
	thumb:SetSize(6, 24)
	thumb:SetColorTexture(0.85, 0.9, 1, 0.5)
	sb:SetThumbTexture(thumb)
	sb.thumb = thumb
	sb._suppress = false

	local function applyVisibility(range)
		local hasScroll = range and range > 0
		if sb.thumb then sb.thumb:SetAlpha(hasScroll and 0.5 or 0) end
		if sb.track then sb.track:SetAlpha(hasScroll and 0.22 or 0) end
		if sb.channel then sb.channel:SetAlpha(hasScroll and 0.32 or 0) end
	end

	local function updateRange(_, _, yRange)
		local vrange = yRange
		if vrange == nil and scrollFrame.GetVerticalScrollRange then vrange = scrollFrame:GetVerticalScrollRange() end
		local maxRange = max(0, vrange or 0)
		sb._suppress = true
		sb:SetMinMaxValues(0, maxRange)
		local cur = sb:GetValue() or 0
		if cur > maxRange then sb:SetValue(maxRange) end
		sb._suppress = false
		applyVisibility(maxRange)
	end

	scrollFrame:SetScript("OnScrollRangeChanged", updateRange)
	scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
		sb._suppress = true
		sb:SetValue(offset or 0)
		sb._suppress = false
	end)

	sb:SetScript("OnValueChanged", function(sl, value)
		if sl._suppress then return end
		local minVal, maxVal = sl:GetMinMaxValues()
		value = max(minVal or 0, min(maxVal or 0, roundInt(value or 0)))
		sl._suppress = true
		sl:SetValue(value)
		sl._suppress = false
		scrollFrame:SetVerticalScroll(value)
	end)

	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(_, delta)
		local minVal, maxVal = sb:GetMinMaxValues()
		local cur = sb:GetValue() or 0
		local step = 30
		local nextValue = cur - (delta * step)
		if minVal and nextValue < minVal then nextValue = minVal end
		if maxVal and nextValue > maxVal then nextValue = maxVal end
		sb:SetValue(nextValue)
	end)

	sb:SetScript("OnEnter", function()
		if sb.track then sb.track:SetColorTexture(1, 1, 1, 0.32) end
		if sb.thumb then sb.thumb:SetColorTexture(0.92, 0.95, 1, 0.72) end
	end)
	sb:SetScript("OnLeave", function()
		if sb.track then sb.track:SetColorTexture(1, 1, 1, 0.2) end
		if sb.thumb then sb.thumb:SetColorTexture(0.85, 0.9, 1, 0.5) end
	end)

	function sb:Sync()
		local range = scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange() or 0
		updateRange(nil, nil, range)
		sb._suppress = true
		sb:SetValue(scrollFrame:GetVerticalScroll() or 0)
		sb._suppress = false
	end

	updateRange(nil, nil, scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange() or 0)
	return sb
end

local function createThinListBar(parent, anchorFrame, xOffset, getMaxValue, getCurrentValue, setCurrentValue)
	if not anchorFrame then return nil end
	local sb = CreateFrame("Slider", nil, parent or anchorFrame:GetParent() or anchorFrame)
	sb:SetOrientation("VERTICAL")
	sb:SetWidth(10)
	sb:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", xOffset or 4, 2)
	sb:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMRIGHT", xOffset or 4, -2)
	sb:SetValueStep(1)
	sb:SetObeyStepOnDrag(true)
	sb:SetMinMaxValues(0, 0)
	sb:SetValue(0)
	sb._suppress = false

	sb.track = sb:CreateTexture(nil, "BACKGROUND")
	sb.track:SetPoint("TOP", sb, "TOP", 0, -2)
	sb.track:SetPoint("BOTTOM", sb, "BOTTOM", 0, 2)
	sb.track:SetWidth(1)
	sb.track:SetColorTexture(1, 1, 1, 0.2)

	sb.channel = sb:CreateTexture(nil, "BACKGROUND", nil, -1)
	sb.channel:SetPoint("TOP", sb, "TOP", 0, 0)
	sb.channel:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	sb.channel:SetWidth(6)
	sb.channel:SetColorTexture(0, 0, 0, 0.3)

	local thumb = sb:CreateTexture(nil, "ARTWORK")
	thumb:SetSize(6, 24)
	thumb:SetColorTexture(0.85, 0.9, 1, 0.5)
	sb:SetThumbTexture(thumb)
	sb.thumb = thumb

	local function applyVisibility(range)
		local hasScroll = range and range > 0
		if sb.thumb then sb.thumb:SetAlpha(hasScroll and 0.5 or 0) end
		if sb.track then sb.track:SetAlpha(hasScroll and 0.22 or 0) end
		if sb.channel then sb.channel:SetAlpha(hasScroll and 0.32 or 0) end
	end

	local function clampToRange(value)
		local minVal, maxVal = sb:GetMinMaxValues()
		value = roundInt(value or 0)
		if minVal and value < minVal then value = minVal end
		if maxVal and value > maxVal then value = maxVal end
		return value
	end

	sb:SetScript("OnValueChanged", function(self, value)
		if self._suppress then return end
		value = clampToRange(value)
		self._suppress = true
		self:SetValue(value)
		self._suppress = false
		if setCurrentValue then setCurrentValue(value) end
	end)

	sb:SetScript("OnEnter", function()
		if sb.track then sb.track:SetColorTexture(1, 1, 1, 0.32) end
		if sb.thumb then sb.thumb:SetColorTexture(0.92, 0.95, 1, 0.72) end
	end)
	sb:SetScript("OnLeave", function()
		if sb.track then sb.track:SetColorTexture(1, 1, 1, 0.2) end
		if sb.thumb then sb.thumb:SetColorTexture(0.85, 0.9, 1, 0.5) end
	end)

	function sb:Sync()
		local maxValue = max(0, roundInt(getMaxValue and getMaxValue() or 0))
		local currentValue = roundInt(getCurrentValue and getCurrentValue() or 0)
		if currentValue < 0 then currentValue = 0 end
		if currentValue > maxValue then currentValue = maxValue end
		self._suppress = true
		self:SetMinMaxValues(0, maxValue)
		self:SetValue(currentValue)
		self._suppress = false
		applyVisibility(maxValue)
	end

	function sb:Step(delta)
		local currentValue = roundInt(getCurrentValue and getCurrentValue() or self:GetValue() or 0)
		self:SetValue(currentValue - roundInt(delta or 0))
	end

	sb:Sync()
	return sb
end

local function getKindConfig(kind)
	local cfg
	if GF and GF.GetHealerBuffPlacementConfig then
		cfg = GF:GetHealerBuffPlacementConfig(kind)
	elseif GF and GF.GetConfig then
		cfg = GF:GetConfig(kind)
	end
	if cfg and HB and HB.EnsureConfig then HB.EnsureConfig(cfg) end
	return cfg
end

local function eachGroupRule(placement, groupId, callback)
	if not (placement and groupId and callback) then return end
	for i = 1, #(placement.ruleOrder or {}) do
		local ruleId = placement.ruleOrder[i]
		local rule = placement.rulesById and placement.rulesById[ruleId]
		if rule and rule.groupId == groupId then callback(ruleId, rule, i) end
	end
end

local function isRuleForClass(rule, classToken)
	if not (rule and classToken) then return false end
	local family = HB.GetFamilyById and HB.GetFamilyById(rule.spellFamilyId)
	return family and family.classToken and tostring(family.classToken) == tostring(classToken)
end

local function groupHasClassRule(placement, groupId, classToken)
	if not (placement and groupId and classToken) then return false end
	for i = 1, #(placement.ruleOrder or EMPTY) do
		local ruleId = placement.ruleOrder[i]
		local rule = placement.rulesById and placement.rulesById[ruleId]
		if rule and rule.groupId == groupId and isRuleForClass(rule, classToken) then return true end
	end
	return false
end

local function buildUsedFamilyMapForGroup(placement, groupId, out)
	out = out or {}
	wipeTable(out)
	if not (placement and groupId) then return out end
	for i = 1, #(placement.ruleOrder or EMPTY) do
		local ruleId = placement.ruleOrder[i]
		local rule = placement.rulesById and placement.rulesById[ruleId]
		local familyId = rule and rule.spellFamilyId
		if rule and rule.groupId == groupId and familyId ~= nil then out[tostring(familyId)] = ruleId end
	end
	return out
end

local function findExistingRuleForGroupFamily(placement, groupId, familyId)
	if not (placement and groupId and familyId ~= nil) then return nil end
	familyId = tostring(familyId)
	for i = 1, #(placement.ruleOrder or EMPTY) do
		local ruleId = placement.ruleOrder[i]
		local rule = placement.rulesById and placement.rulesById[ruleId]
		if rule and rule.groupId == groupId and tostring(rule.spellFamilyId or "") == familyId then return ruleId end
	end
	return nil
end

local function copyArray(src)
	local out = {}
	for i = 1, #(src or EMPTY) do
		out[#out + 1] = src[i]
	end
	return out
end

local function getFamilyPresentation(familyId)
	local family = HB.GetFamilyById and HB.GetFamilyById(familyId)
	if not family then return tostring(familyId or ""), nil, nil, nil end
	local name = family._resolvedName or family.fallbackName or family.id or tostring(familyId or "")
	local icon = family._resolvedIcon
	return tostring(name), icon, family.classToken, family.spec
end

local function getFamilyLabel(familyId, withIcon)
	local name, icon = getFamilyPresentation(familyId)
	if withIcon and icon then return iconMarkup(icon, 14) .. name end
	return name
end

local function buildFamilyOptionsForEditor(classTokenFilter)
	local raw = HB.GetFamilyOptions and HB.GetFamilyOptions() or {}
	local list = {}
	for i = 1, #raw do
		local option = raw[i]
		local name, icon, classToken, spec = getFamilyPresentation(option.value)
		if classTokenFilter == nil or (classToken and tostring(classToken) == tostring(classTokenFilter)) then
			list[#list + 1] = {
				value = option.value,
				label = name,
				icon = option.icon or icon,
				classToken = classToken or option.classToken,
				spec = spec or option.spec,
			}
		end
	end
	sort(list, function(a, b)
		local al = tostring(a.label or "")
		local bl = tostring(b.label or "")
		if al == bl then return tostring(a.value) < tostring(b.value) end
		return al < bl
	end)
	return list
end

local function getClassDisplayName(classToken)
	if classToken == nil then return "Other" end
	local token = tostring(classToken)
	return tostring(LOCALIZED_CLASS_NAMES_MALE[token] or LOCALIZED_CLASS_NAMES_FEMALE[token] or token)
end

local function buildFamilyOptionsByClass(classTokenFilter)
	local options = buildFamilyOptionsForEditor(classTokenFilter)
	local buckets, classOrder = {}, {}
	for i = 1, #options do
		local option = options[i]
		local classToken = option.classToken and tostring(option.classToken) or "_OTHER"
		local bucket = buckets[classToken]
		if bucket == nil then
			bucket = {
				token = classToken,
				label = getClassDisplayName(option.classToken),
				spells = {},
			}
			buckets[classToken] = bucket
			classOrder[#classOrder + 1] = classToken
		end
		bucket.spells[#bucket.spells + 1] = option
	end
	sort(classOrder, function(a, b)
		local left = buckets[a]
		local right = buckets[b]
		if left == nil or right == nil then return tostring(a) < tostring(b) end
		if left.label == right.label then return tostring(left.token) < tostring(right.token) end
		return tostring(left.label) < tostring(right.label)
	end)
	for i = 1, #classOrder do
		local bucket = buckets[classOrder[i]]
		if bucket and bucket.spells then
			sort(bucket.spells, function(a, b)
				local al = tostring(a and a.label or "")
				local bl = tostring(b and b.label or "")
				if al == bl then return tostring(a and a.value or "") < tostring(b and b.value or "") end
				return al < bl
			end)
		end
	end
	return buckets, classOrder
end

local function buildStyleOptionsForMenu()
	local raw = HB.STYLE_OPTIONS or EMPTY
	local list = {}
	for i = 1, #raw do
		list[#list + 1] = raw[i]
	end
	sort(list, function(a, b)
		local left = tostring((a and (a.label or a.text or a.value)) or "")
		local right = tostring((b and (b.label or b.text or b.value)) or "")
		if left == right then return tostring(a and a.value or "") < tostring(b and b.value or "") end
		return left < right
	end)
	return list
end

local function getGroupLabel(placement, groupId)
	if not placement or not groupId then return tostring(groupId or "") end
	local group = placement.groupsById and placement.groupsById[groupId]
	if not group then return tostring(groupId) end
	return tostring(group.name or ("Indicator " .. tostring(groupId)))
end

local function getVisibleGroupIds(placement, out, classToken)
	out = out or {}
	wipeTable(out)
	if not placement then return out end
	for i = 1, #(placement.groupOrder or EMPTY) do
		local groupId = placement.groupOrder[i]
		local group = groupId and placement.groupsById and placement.groupsById[groupId]
		if group then
			if classToken == nil or groupHasClassRule(placement, groupId, classToken) then out[#out + 1] = groupId end
		end
	end
	return out
end

local function getVisibleRuleIds(placement, groupId, out, classToken)
	out = out or {}
	wipeTable(out)
	if not placement then return out end
	for i = 1, #(placement.ruleOrder or EMPTY) do
		local ruleId = placement.ruleOrder[i]
		local rule = placement.rulesById and placement.rulesById[ruleId]
		if rule and (groupId == nil or rule.groupId == groupId) then
			if classToken == nil or isRuleForClass(rule, classToken) then out[#out + 1] = ruleId end
		end
	end
	return out
end

local function getFirstRuleIdForGroup(placement, groupId)
	if not (placement and groupId) then return nil end
	for i = 1, #(placement.ruleOrder or EMPTY) do
		local ruleId = placement.ruleOrder[i]
		local rule = placement.rulesById and placement.rulesById[ruleId]
		if rule and rule.groupId == groupId then return ruleId end
	end
	return nil
end

local function moveIdInOrder(order, fromId, targetId)
	if type(order) ~= "table" then return false end
	if fromId == nil or targetId == nil or fromId == targetId then return false end
	local fromIndex, toIndex
	for i = 1, #order do
		local id = order[i]
		if id == fromId then fromIndex = i end
		if id == targetId then toIndex = i end
	end
	if not fromIndex or not toIndex then return false end
	table.remove(order, fromIndex)
	if fromIndex < toIndex then toIndex = toIndex - 1 end
	table.insert(order, toIndex, fromId)
	return true
end

local function setDangerButtonStyle(button)
	if not button then return end
	if button.GetFontString and button:GetFontString() then
		local fs = button:GetFontString()
		fs:SetTextColor(1, 0.3, 0.3, 1)
		fs:SetShadowOffset(1, -1)
	end
	button:SetNormalFontObject(GameFontHighlightSmall)
	button:SetHighlightFontObject(GameFontHighlightSmall)
	button:SetDisabledFontObject(GameFontDisableSmall)
end

function Editor:QueueRuntimeRefresh()
	if self._refreshQueued then return end
	self._refreshQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0.03, function()
			Editor._refreshQueued = nil
			if not (Editor.frame and Editor.frame:IsShown()) then return end
			if GF and GF.RefreshHealerBuffPlacement then GF:RefreshHealerBuffPlacement() end
		end)
	else
		self._refreshQueued = nil
		if GF and GF.RefreshHealerBuffPlacement then GF:RefreshHealerBuffPlacement() end
	end
end

function Editor:RefreshRuntimeNow()
	if GF and GF.RefreshHealerBuffPlacement then GF:RefreshHealerBuffPlacement() end
end

function Editor:GetContext()
	if not self.kind then return nil, nil end
	local cfg = getKindConfig(self.kind)
	if not cfg then return nil, nil end
	local placement = cfg.healerBuffPlacement
	if not placement then return nil, nil end
	return cfg, placement
end

function Editor:EnsureSelection()
	local _, placement = self:GetContext()
	if not placement then
		self.selectedGroupId = nil
		self.selectedRuleId = nil
		return
	end
	if self.selectedGroupId == nil or not (placement.groupsById and placement.groupsById[self.selectedGroupId]) then self.selectedGroupId = placement.groupOrder and placement.groupOrder[1] or nil end
	local selectedRule = self.selectedRuleId and placement.rulesById and placement.rulesById[self.selectedRuleId]
	if selectedRule and self.selectedGroupId and selectedRule.groupId ~= self.selectedGroupId then selectedRule = nil end
	if selectedRule == nil then
		self.selectedRuleId = getFirstRuleIdForGroup(placement, self.selectedGroupId)
		if self.selectedRuleId == nil then self.selectedRuleId = placement.ruleOrder and placement.ruleOrder[1] or nil end
	end
end

function Editor:SyncSelectedRuleToGroup(force)
	local _, placement = self:GetContext()
	if not placement then
		self.selectedRuleId = nil
		return
	end
	if not self.selectedGroupId or not (placement.groupsById and placement.groupsById[self.selectedGroupId]) then
		if force and placement.ruleOrder then self.selectedRuleId = placement.ruleOrder[1] end
		return
	end
	local selectedRule = self.selectedRuleId and placement.rulesById and placement.rulesById[self.selectedRuleId]
	if force or not selectedRule or selectedRule.groupId ~= self.selectedGroupId then
		self.selectedRuleId = getFirstRuleIdForGroup(placement, self.selectedGroupId)
		if force then self.ruleOffset = 0 end
	end
end

function Editor:EnsureFrame()
	if self.frame then return self.frame end

	local frame = CreateFrame("Frame", "EQOL_UF_GroupHealerBuffEditor", UIParent, "BackdropTemplate")
	frame:SetSize(1120, 760)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(600)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	local frameShade = frame:CreateTexture(nil, "BACKGROUND")
	frameShade:SetAllPoints(frame)
	frameShade:SetTexture(ASSET_BG_DARK)
	frameShade:SetAlpha(0.94)
	frame.FrameShade = frameShade
	applyPanelBorder(frame)
	frame:Hide()

	local title = createLabel(frame, "Healer Buff Placement", 15, "OUTLINE")
	title:SetPoint("TOPLEFT", 18, -14)
	frame.Title = title

	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetText("Configure shared spell-family placements for Party and Raid frames.")
	subtitle:SetTextColor(0.75, 0.75, 0.75, 1)
	frame.Subtitle = subtitle

	local closeButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
	closeButton:SetSize(22, 22)
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 20, 12)
	closeButton:SetFrameStrata(frame:GetFrameStrata())
	closeButton:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
	closeButton:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	closeButton:SetBackdropColor(0.35, 0.08, 0.08, 0.95)
	closeButton:SetBackdropBorderColor(0.82, 0.24, 0.24, 1)
	closeButton.Text = closeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	closeButton.Text:SetPoint("CENTER", 0, 0)
	closeButton.Text:SetText("X")
	closeButton.Text:SetTextColor(1, 0.9, 0.9, 1)
	closeButton:SetScript("OnEnter", function(self)
		self:SetBackdropColor(0.46, 0.1, 0.1, 0.98)
		self:SetBackdropBorderColor(1, 0.35, 0.35, 1)
	end)
	closeButton:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.35, 0.08, 0.08, 0.95)
		self:SetBackdropBorderColor(0.82, 0.24, 0.24, 1)
	end)
	closeButton:SetScript("OnClick", function() frame:Hide() end)
	frame.CloseButton = closeButton

	local kindLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kindLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
	kindLabel:SetText("Scope:")
	frame.KindLabel = kindLabel

	local kindValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	kindValue:SetPoint("LEFT", kindLabel, "RIGHT", 8, 0)
	kindValue:SetText("Shared (Party + Raid)")
	frame.KindValue = kindValue

	local enabledCheck = createCheck(frame, "Enable Healer Buff Placement")
	enabledCheck:SetPoint("LEFT", kindValue, "RIGHT", 20, 0)
	frame.EnabledCheck = enabledCheck

	local groupPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	groupPanel:SetSize(330, 286)
	groupPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -106)
	applyCardBackground(groupPanel, false)
	frame.GroupPanel = groupPanel

	local groupTitle = createLabel(groupPanel, "Indicators", 12, "OUTLINE")
	groupTitle:SetPoint("TOPLEFT", 10, -10)
	groupPanel.Title = groupTitle

	local addGroup = createButton(groupPanel, "+", 22, 20)
	addGroup:SetPoint("TOPRIGHT", -10, -8)
	setDangerButtonStyle(addGroup)
	groupPanel.AddButton = addGroup

	local groupUp = createButton(groupPanel, "Up", 45, 20)
	groupUp:SetPoint("TOPRIGHT", addGroup, "TOPLEFT", -6, 0)
	groupPanel.UpButton = groupUp

	local groupDown = createButton(groupPanel, "Down", 45, 20)
	groupDown:SetPoint("TOPRIGHT", groupUp, "TOPLEFT", -6, 0)
	groupPanel.DownButton = groupDown

	local deleteGroup = createButton(groupPanel, "Delete", 65, 20)
	deleteGroup:SetPoint("TOPRIGHT", groupDown, "TOPLEFT", -6, 0)
	groupPanel.DeleteButton = deleteGroup
	groupUp:Hide()
	groupDown:Hide()
	deleteGroup:Hide()

	groupPanel.RowHolder = CreateFrame("Frame", nil, groupPanel)
	groupPanel.RowHolder:SetPoint("TOPLEFT", groupTitle, "BOTTOMLEFT", 0, -10)
	groupPanel.RowHolder:SetPoint("BOTTOMRIGHT", groupPanel, "BOTTOMRIGHT", -26, 10)

	groupPanel.Rows = {}
	for i = 1, GROUP_VISIBLE_ROWS do
		local row = CreateFrame("Button", nil, groupPanel.RowHolder, "BackdropTemplate")
		row:SetHeight(GROUP_ROW_HEIGHT)
		row:SetPoint("TOPLEFT", groupPanel.RowHolder, "TOPLEFT", 0, -((i - 1) * (GROUP_ROW_HEIGHT + GROUP_ROW_GAP)))
		row:SetPoint("TOPRIGHT", groupPanel.RowHolder, "TOPRIGHT", 0, -((i - 1) * (GROUP_ROW_HEIGHT + GROUP_ROW_GAP)))
		row:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 1,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		row:SetBackdropColor(0.07, 0.09, 0.12, 0.82)
		row:SetBackdropBorderColor(0.2, 0.26, 0.32, 0.9)
		row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.Text:SetPoint("LEFT", 6, 0)
		row.Text:SetPoint("RIGHT", -28, 0)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetText("")
		row:RegisterForDrag("LeftButton")
		row:EnableMouseWheel(true)
		row.DeleteButton = createButton(row, "x", 18, 18)
		row.DeleteButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		setDangerButtonStyle(row.DeleteButton)
		row:SetScript("OnMouseWheel", function(_, delta)
			if groupPanel.ScrollBar then groupPanel.ScrollBar:Step(delta) end
		end)
		row:Hide()
		groupPanel.Rows[i] = row
	end
	groupPanel.ScrollBar = createThinListBar(groupPanel, groupPanel.RowHolder, 2, function()
		local _, placement = Editor:GetContext()
		local count = placement and placement.groupOrder and #placement.groupOrder or 0
		return max(0, count - GROUP_VISIBLE_ROWS)
	end, function() return Editor.groupOffset or 0 end, function(value)
		Editor.groupOffset = roundInt(value or 0)
		Editor:RefreshGroupList()
	end)
	groupPanel.RowHolder:EnableMouseWheel(true)
	groupPanel.RowHolder:SetScript("OnMouseWheel", function(_, delta)
		if groupPanel.ScrollBar then groupPanel.ScrollBar:Step(delta) end
	end)

	local rulePanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	rulePanel:SetSize(420, 286)
	rulePanel:SetPoint("TOPLEFT", groupPanel, "TOPRIGHT", 10, 0)
	applyCardBackground(rulePanel, false)
	frame.RulePanel = rulePanel

	local ruleTitle = createLabel(rulePanel, "Spell Rules", 12, "OUTLINE")
	ruleTitle:SetPoint("TOPLEFT", 10, -10)
	rulePanel.Title = ruleTitle

	local addRule = createButton(rulePanel, "Create", 70, 20)
	addRule:SetPoint("TOPRIGHT", -10, -8)
	addRule:SetSize(22, 20)
	addRule:SetText("+")
	setDangerButtonStyle(addRule)
	rulePanel.AddButton = addRule

	local ruleUp = createButton(rulePanel, "Up", 45, 20)
	ruleUp:SetPoint("TOPRIGHT", addRule, "TOPLEFT", -6, 0)
	rulePanel.UpButton = ruleUp

	local ruleDown = createButton(rulePanel, "Down", 45, 20)
	ruleDown:SetPoint("TOPRIGHT", ruleUp, "TOPLEFT", -6, 0)
	rulePanel.DownButton = ruleDown

	local deleteRule = createButton(rulePanel, "Delete", 65, 20)
	deleteRule:SetPoint("TOPRIGHT", ruleDown, "TOPLEFT", -6, 0)
	rulePanel.DeleteButton = deleteRule
	ruleUp:Hide()
	ruleDown:Hide()
	deleteRule:Hide()

	rulePanel.RowHolder = CreateFrame("Frame", nil, rulePanel)
	rulePanel.RowHolder:SetPoint("TOPLEFT", ruleTitle, "BOTTOMLEFT", 0, -8)
	rulePanel.RowHolder:SetPoint("BOTTOMRIGHT", rulePanel, "BOTTOMRIGHT", -18, 10)

	rulePanel.Rows = {}
	for i = 1, RULE_VISIBLE_ROWS do
		local row = CreateFrame("Button", nil, rulePanel.RowHolder, "BackdropTemplate")
		row:SetHeight(RULE_ROW_HEIGHT)
		row:SetPoint("TOPLEFT", rulePanel.RowHolder, "TOPLEFT", 0, -((i - 1) * (RULE_ROW_HEIGHT + RULE_ROW_GAP)))
		row:SetPoint("TOPRIGHT", rulePanel.RowHolder, "TOPRIGHT", 0, -((i - 1) * (RULE_ROW_HEIGHT + RULE_ROW_GAP)))
		row:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 1,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		row:SetBackdropColor(0.07, 0.09, 0.12, 0.82)
		row:SetBackdropBorderColor(0.2, 0.26, 0.32, 0.9)
		row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.Text:SetPoint("LEFT", 6, 0)
		row.Text:SetPoint("RIGHT", -28, 0)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetText("")
		row:RegisterForDrag("LeftButton")
		row:EnableMouseWheel(true)
		row.DeleteButton = createButton(row, "x", 18, 18)
		row.DeleteButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		setDangerButtonStyle(row.DeleteButton)
		row:SetScript("OnMouseWheel", function(_, delta)
			if rulePanel.ScrollBar then rulePanel.ScrollBar:Step(delta) end
		end)
		row:Hide()
		rulePanel.Rows[i] = row
	end
	rulePanel.ScrollBar = createThinListBar(rulePanel, rulePanel.RowHolder, 4, function()
		local _, placement = Editor:GetContext()
		if not placement then return 0 end
		if Editor.selectedGroupId == nil then return 0 end
		local visible = getVisibleRuleIds(placement, Editor.selectedGroupId, Editor._ruleScrollScratch)
		Editor._ruleScrollScratch = visible
		return max(0, #visible - RULE_VISIBLE_ROWS)
	end, function() return Editor.ruleOffset or 0 end, function(value)
		Editor.ruleOffset = roundInt(value or 0)
		Editor:RefreshRuleList()
	end)
	rulePanel.RowHolder:EnableMouseWheel(true)
	rulePanel.RowHolder:SetScript("OnMouseWheel", function(_, delta)
		if rulePanel.ScrollBar then rulePanel.ScrollBar:Step(delta) end
	end)

	local previewPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	previewPanel:SetSize(334, 286)
	previewPanel:SetPoint("TOPLEFT", rulePanel, "TOPRIGHT", 10, 0)
	applyCardBackground(previewPanel, false)
	frame.PreviewPanel = previewPanel

	local previewTitle = createLabel(previewPanel, "Live Preview", 12, "OUTLINE")
	previewTitle:SetPoint("TOPLEFT", 10, -10)
	previewPanel.Title = previewTitle

	local previewFrame = CreateFrame("Frame", nil, previewPanel, "BackdropTemplate")
	previewFrame:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -8)
	previewFrame:SetPoint("TOPRIGHT", previewPanel, "TOPRIGHT", -10, -30)
	previewFrame:SetHeight(238)
	applyCardBackground(previewFrame, true)
	previewFrame:SetClipsChildren(true)
	previewPanel.Frame = previewFrame

	local unitFrame = CreateFrame("Frame", nil, previewFrame, "BackdropTemplate")
	unitFrame:SetSize(250, 118)
	unitFrame:SetPoint("CENTER")
	unitFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	unitFrame:SetBackdropColor(0.07, 0.08, 0.095, 0.98)
	unitFrame:SetBackdropBorderColor(0.38, 0.44, 0.5, 0.95)
	previewFrame.UnitFrame = unitFrame

	local health = unitFrame:CreateTexture(nil, "BACKGROUND")
	health:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 0, 0)
	health:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", 0, 14)
	health:SetDrawLayer("ARTWORK", 1)
	health:SetColorTexture(0.08, 0.42, 0.19, 1)
	unitFrame.HealthTexture = health

	local power = unitFrame:CreateTexture(nil, "BACKGROUND")
	power:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOMLEFT", 0, 0)
	power:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", 0, 0)
	power:SetHeight(14)
	power:SetDrawLayer("ARTWORK", 2)
	power:SetColorTexture(0.1, 0.18, 0.45, 1)
	unitFrame.PowerTexture = power

	local nameText = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nameText:SetPoint("CENTER", unitFrame, "CENTER", 0, 4)
	nameText:SetText("Preview Unit")
	unitFrame.NameText = nameText

	unitFrame.SampleIcons = {}
	for i = 1, 40 do
		local icon = CreateFrame("Frame", nil, unitFrame, "BackdropTemplate")
		icon:SetSize(14, 14)
		icon:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 1,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		icon:SetBackdropColor(0, 0, 0, 0.3)
		icon:SetBackdropBorderColor(0, 0, 0, 0.8)
		icon.Texture = icon:CreateTexture(nil, "ARTWORK")
		icon.Texture:SetAllPoints(icon)
		icon.Texture:SetTexture(134400)
		icon:Hide()
		unitFrame.SampleIcons[i] = icon
	end

	unitFrame.SampleTints = {}
	for i = 1, 24 do
		local tint = unitFrame:CreateTexture(nil, "ARTWORK", nil, 2)
		tint:SetAllPoints(unitFrame)
		tint:SetColorTexture(0, 0, 0, 0)
		tint:Hide()
		unitFrame.SampleTints[i] = tint
	end

	unitFrame.SampleBars = {}
	for i = 1, 24 do
		local bar = unitFrame:CreateTexture(nil, "ARTWORK", nil, 3)
		bar:SetColorTexture(0, 0, 0, 0)
		bar:Hide()
		unitFrame.SampleBars[i] = bar
	end

	unitFrame.SampleBorders = {}
	for i = 1, 24 do
		local border = CreateFrame("Frame", nil, unitFrame, "BackdropTemplate")
		border:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 2,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		border:SetBackdropColor(0, 0, 0, 0)
		border:Hide()
		unitFrame.SampleBorders[i] = border
	end

	local settingsPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	settingsPanel:SetPoint("TOPLEFT", groupPanel, "BOTTOMLEFT", 0, -10)
	settingsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
	applyCardBackground(settingsPanel, false)
	frame.SettingsPanel = settingsPanel

	local groupSettingsTitle = createLabel(settingsPanel, "Indicator Settings", 12, "OUTLINE")
	groupSettingsTitle:SetPoint("TOPLEFT", 14, -10)
	settingsPanel.GroupSettingsTitle = groupSettingsTitle

	local groupControlCard = CreateFrame("Frame", nil, settingsPanel, "BackdropTemplate")
	groupControlCard:SetPoint("TOPLEFT", groupSettingsTitle, "BOTTOMLEFT", -4, -6)
	groupControlCard:SetPoint("BOTTOMLEFT", settingsPanel, "BOTTOMLEFT", 10, 10)
	groupControlCard:SetWidth(540)
	applyCardBackground(groupControlCard, true)

	local groupControlViewport = CreateFrame("ScrollFrame", nil, groupControlCard)
	groupControlViewport:SetPoint("TOPLEFT", groupControlCard, "TOPLEFT", 12, -10)
	groupControlViewport:SetPoint("BOTTOMRIGHT", groupControlCard, "BOTTOMRIGHT", -20, 10)
	settingsPanel.GroupControlViewport = groupControlViewport

	local groupControlContent = CreateFrame("Frame", nil, groupControlViewport)
	groupControlContent:SetPoint("TOPLEFT", groupControlViewport, "TOPLEFT", 0, 0)
	groupControlContent:SetHeight(860)
	groupControlContent:SetWidth(500)
	groupControlViewport:SetScrollChild(groupControlContent)
	settingsPanel.GroupControlContent = groupControlContent

	local groupControlScroll = createThinScrollFrameBar(groupControlViewport, 4)
	settingsPanel.GroupControlScroll = groupControlScroll

	local function updateGroupControlScroll()
		local viewportWidth = max(1, (groupControlViewport:GetWidth() or 1) - 6)
		groupControlContent:SetWidth(viewportWidth)
		if groupControlScroll and groupControlScroll.Sync then groupControlScroll:Sync() end
	end
	frame._updateGroupControlScroll = updateGroupControlScroll

	local ruleSettingsTitle = createLabel(settingsPanel, "Rule Settings", 12, "OUTLINE")
	ruleSettingsTitle:SetPoint("TOPLEFT", 572, -10)
	settingsPanel.RuleSettingsTitle = ruleSettingsTitle

	local controls = {}
	frame.Controls = controls
	local groupControlParent = groupControlContent

	controls.GroupNameLabel = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.GroupNameLabel:SetPoint("TOPLEFT", groupControlParent, "TOPLEFT", 0, 0)
	controls.GroupNameLabel:SetText("Name")
	controls.GroupName = createEditBox(groupControlParent, 220)
	controls.GroupName:SetPoint("TOPLEFT", controls.GroupNameLabel, "TOPRIGHT", 12, 0)

	controls.GroupStyleLabel = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.GroupStyleLabel:SetPoint("TOPLEFT", controls.GroupNameLabel, "BOTTOMLEFT", 0, -16)
	controls.GroupStyleLabel:SetText("Style (locked)")
	controls.GroupStyleValue = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	controls.GroupStyleValue:SetPoint("LEFT", controls.GroupStyleLabel, "TOPRIGHT", 10, -2)
	controls.GroupStyleValue:SetWidth(190)
	controls.GroupStyleValue:SetJustifyH("LEFT")
	controls.GroupStyleValue:SetText("-")

	controls.GroupAnchorLabel = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.GroupAnchorLabel:SetPoint("TOPLEFT", controls.GroupStyleLabel, "BOTTOMLEFT", 0, -18)
	controls.GroupAnchorLabel:SetText("Anchor")
	controls.GroupAnchor = createDropdown(groupControlParent, 160)
	controls.GroupAnchor:SetPoint("TOPLEFT", controls.GroupAnchorLabel, "TOPRIGHT", 0, 12)

	controls.GroupGrowthLabel = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.GroupGrowthLabel:SetPoint("TOPLEFT", controls.GroupAnchorLabel, "BOTTOMLEFT", 0, -18)
	controls.GroupGrowthLabel:SetText("Growth")
	controls.GroupGrowth = createDropdown(groupControlParent, 160)
	controls.GroupGrowth:SetPoint("TOPLEFT", controls.GroupGrowthLabel, "TOPRIGHT", 0, 12)

	controls.GroupBarOrientationLabel = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.GroupBarOrientationLabel:SetPoint("TOPLEFT", controls.GroupGrowthLabel, "BOTTOMLEFT", 0, -18)
	controls.GroupBarOrientationLabel:SetText("Bar Orientation")
	controls.GroupBarOrientation = createDropdown(groupControlParent, 160)
	controls.GroupBarOrientation:SetPoint("TOPLEFT", controls.GroupBarOrientationLabel, "TOPRIGHT", 0, 12)

	local function createSettingSlider(anchorLabel, text, minValue, maxValue, step)
		local label = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -22)
		label:SetText(text)
		local slider = createSlider(groupControlParent, 180, minValue, maxValue, step)
		slider:SetPoint("TOPLEFT", label, "TOPRIGHT", 8, 8)
		local valueText = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
		valueText:SetWidth(44)
		valueText:SetJustifyH("RIGHT")
		valueText:SetText("0")
		return label, slider, valueText
	end

	controls.PerRowLabel, controls.PerRow, controls.PerRowValue = createSettingSlider(controls.GroupBarOrientationLabel, "Per Row", 1, 20, 1)
	controls.MaxLabel, controls.MaxCount, controls.MaxValue = createSettingSlider(controls.PerRowLabel, "Max", 0, 40, 1)
	controls.SpacingLabel, controls.Spacing, controls.SpacingValue = createSettingSlider(controls.MaxLabel, "Spacing", 0, 20, 1)
	controls.SizeLabel, controls.Size, controls.SizeValue = createSettingSlider(controls.SpacingLabel, "Icon Size", 4, 64, 1)
	controls.XLabel, controls.XOffset, controls.XValue = createSettingSlider(controls.SizeLabel, "X Offset", -200, 200, 1)
	controls.YLabel, controls.YOffset, controls.YValue = createSettingSlider(controls.XLabel, "Y Offset", -200, 200, 1)
	controls.ThicknessLabel, controls.Thickness, controls.ThicknessValue = createSettingSlider(controls.YLabel, "Bar Thickness", 1, 64, 1)
	controls.InsetLabel, controls.Inset, controls.InsetValue = createSettingSlider(controls.ThicknessLabel, "Inset", 0, 40, 1)
	controls.BorderSizeLabel, controls.BorderSize, controls.BorderSizeValue = createSettingSlider(controls.InsetLabel, "Border Size", 1, 16, 1)

	controls.ColorLabel = groupControlParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.ColorLabel:SetPoint("TOPLEFT", controls.BorderSizeLabel, "BOTTOMLEFT", 0, -22)
	controls.ColorLabel:SetText("Color")
	controls.ColorButton = CreateFrame("Button", nil, groupControlParent, "BackdropTemplate")
	controls.ColorButton:SetSize(26, 26)
	controls.ColorButton:SetPoint("TOPLEFT", controls.ColorLabel, "TOPRIGHT", 10, -2)
	controls.ColorButton:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	controls.ColorButton:SetBackdropColor(0, 0, 0, 0.65)
	controls.ColorButton:SetBackdropBorderColor(0.28, 0.33, 0.4, 1)
	controls.ColorSwatch = controls.ColorButton:CreateTexture(nil, "ARTWORK")
	controls.ColorSwatch:SetPoint("TOPLEFT", controls.ColorButton, "TOPLEFT", 3, -3)
	controls.ColorSwatch:SetPoint("BOTTOMRIGHT", controls.ColorButton, "BOTTOMRIGHT", -3, 3)
	controls.ColorSwatch:SetColorTexture(1, 1, 1, 1)
	controls.ColorButton.ColorSwatch = controls.ColorSwatch
	controls.ColorButton._eqolColorSwatch = controls.ColorSwatch
	groupControlContent:SetHeight(340)

	local function layoutGroupControlRows()
		local LABEL_X = 8
		local CONTROL_X = 84
		local FIRST_ROW_Y = -8
		local GAP_DROPDOWN = 20
		local GAP_SLIDER = 20
		local GAP_COLOR = 20
		local prevLabel
		local lastBottom

		local function includeBottom(control)
			if control and control:IsShown() then lastBottom = control end
		end

		local function beginRow(label, gap)
			label:ClearAllPoints()
			if prevLabel then
				label:SetPoint("TOPLEFT", prevLabel, "BOTTOMLEFT", 0, -(gap or GAP_DROPDOWN))
			else
				label:SetPoint("TOPLEFT", groupControlParent, "TOPLEFT", LABEL_X, FIRST_ROW_Y)
			end
			prevLabel = label
		end

		controls.GroupNameLabel:ClearAllPoints()
		controls.GroupNameLabel:SetPoint("TOPLEFT", groupControlParent, "TOPLEFT", LABEL_X, FIRST_ROW_Y)
		controls.GroupName:ClearAllPoints()
		controls.GroupName:SetPoint("TOPLEFT", controls.GroupNameLabel, "TOPLEFT", CONTROL_X - LABEL_X, 2)
		prevLabel = controls.GroupNameLabel
		includeBottom(controls.GroupName)

		local function placeDropdown(label, control)
			if not (label:IsShown() and control:IsShown()) then return end
			beginRow(label, GAP_DROPDOWN)
			control:ClearAllPoints()
			control:SetPoint("TOPLEFT", label, "TOPLEFT", CONTROL_X - LABEL_X, 12)
			includeBottom(control)
		end

		local function placeSlider(label, slider, valueText)
			if not (label:IsShown() and slider:IsShown() and valueText:IsShown()) then return end
			beginRow(label, GAP_SLIDER)
			slider:ClearAllPoints()
			slider:SetPoint("TOPLEFT", label, "TOPLEFT", CONTROL_X - LABEL_X, 8)
			valueText:ClearAllPoints()
			valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
			includeBottom(slider)
		end

		local function placeColor(label, button)
			if not (label:IsShown() and button:IsShown()) then return end
			beginRow(label, GAP_COLOR)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", label, "TOPLEFT", CONTROL_X - LABEL_X, 0)
			includeBottom(button)
		end

		placeDropdown(controls.GroupAnchorLabel, controls.GroupAnchor)
		placeDropdown(controls.GroupGrowthLabel, controls.GroupGrowth)
		placeDropdown(controls.GroupBarOrientationLabel, controls.GroupBarOrientation)

		placeSlider(controls.PerRowLabel, controls.PerRow, controls.PerRowValue)
		placeSlider(controls.MaxLabel, controls.MaxCount, controls.MaxValue)
		placeSlider(controls.SpacingLabel, controls.Spacing, controls.SpacingValue)
		placeSlider(controls.SizeLabel, controls.Size, controls.SizeValue)
		placeSlider(controls.XLabel, controls.XOffset, controls.XValue)
		placeSlider(controls.YLabel, controls.YOffset, controls.YValue)
		placeSlider(controls.ThicknessLabel, controls.Thickness, controls.ThicknessValue)
		placeSlider(controls.InsetLabel, controls.Inset, controls.InsetValue)
		placeSlider(controls.BorderSizeLabel, controls.BorderSize, controls.BorderSizeValue)
		placeColor(controls.ColorLabel, controls.ColorButton)

		local top = controls.GroupNameLabel:GetTop()
		local bottom = lastBottom and lastBottom:GetBottom()
		local height = 260
		if top and bottom then height = (top - bottom) + 34 end
		if height < 220 then height = 220 end
		groupControlContent:SetHeight(height)
	end
	frame._layoutGroupControlRows = layoutGroupControlRows

	controls.RuleEnabled = createCheck(settingsPanel, "Rule enabled")
	controls.RuleEnabled:SetPoint("TOPLEFT", ruleSettingsTitle, "BOTTOMLEFT", 0, -10)

	controls.RuleNot = createCheck(settingsPanel, "NOT (active when missing)")
	controls.RuleNot:SetPoint("TOPLEFT", controls.RuleEnabled, "BOTTOMLEFT", 0, -6)

	controls.RuleAppliesParty = createCheck(settingsPanel, "Party")
	controls.RuleAppliesParty:SetPoint("TOPLEFT", controls.RuleNot, "BOTTOMLEFT", 0, -6)

	controls.RuleAppliesRaid = createCheck(settingsPanel, "Raid")
	controls.RuleAppliesRaid:SetPoint("TOPLEFT", controls.RuleAppliesParty, "BOTTOMLEFT", 0, -6)

	controls.RuleIconModeLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.RuleIconModeLabel:SetPoint("TOPLEFT", controls.RuleAppliesRaid, "BOTTOMLEFT", 0, -14)
	controls.RuleIconModeLabel:SetText("Icon Rule Mode")
	controls.RuleIconMode = createDropdown(settingsPanel, 260)
	controls.RuleIconMode:SetPoint("TOPLEFT", controls.RuleIconModeLabel, "TOPRIGHT", 0, 12)
	controls.RuleIconModeLabel:Hide()
	controls.RuleIconMode:Hide()

	controls.RuleMatchLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	controls.RuleMatchLabel:SetPoint("TOPLEFT", controls.RuleAppliesRaid, "BOTTOMLEFT", 0, -14)
	controls.RuleMatchLabel:SetText("Tint Trigger")
	controls.RuleMatch = createDropdown(settingsPanel, 260)
	controls.RuleMatch:SetPoint("TOPLEFT", controls.RuleMatchLabel, "TOPRIGHT", 0, 12)
	controls.RuleMatchLabel:Hide()
	controls.RuleMatch:Hide()

	controls.RuleInfo = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	controls.RuleInfo:SetPoint("TOPLEFT", controls.RuleAppliesRaid, "BOTTOMLEFT", 0, -10)
	controls.RuleInfo:SetPoint("RIGHT", settingsPanel, "RIGHT", -14, 0)
	controls.RuleInfo:SetJustifyH("LEFT")
	controls.RuleInfo:SetTextColor(0.75, 0.75, 0.75, 1)
	controls.RuleInfo:SetText("Add rules via + and remove them via x in the list.")

	self.frame = frame
	self.groupOffset = 0
	self.ruleOffset = 0
	self._controlUpdateLock = nil

	local function createGroupFromStyle(style)
		local _, placement = Editor:GetContext()
		if not placement then return end
		style = tostring(style or "ICON")
		local newId = HB.GetNextGroupId and HB.GetNextGroupId(placement) or tostring((#placement.groupOrder or 0) + 1)
		local group = HB.CreateDefaultGroup and HB.CreateDefaultGroup(newId) or { id = newId, name = "Indicator " .. newId, style = style }
		group.style = style
		if group.name == nil or group.name == "" or tostring(group.name):match("^Group%s+") then group.name = "Indicator " .. newId end
		if style == "TINT" then
			group.color = group.color or { 1, 0.82, 0.1, 0.22 }
			if (group.color[4] or 1) > 0.35 then group.color[4] = 0.22 end
		end
		placement.groupsById[newId] = group
		tinsert(placement.groupOrder, newId)
		Editor.selectedGroupId = newId
		Editor:SyncSelectedRuleToGroup(true)
		Editor:RefreshAll()
		Editor:RefreshRuntimeNow()
	end

	local function deleteGroupById(groupId)
		local _, placement = Editor:GetContext()
		if not (placement and groupId) then return end
		placement.groupsById[groupId] = nil
		for i = #placement.groupOrder, 1, -1 do
			if placement.groupOrder[i] == groupId then table.remove(placement.groupOrder, i) end
		end
		for i = #placement.ruleOrder, 1, -1 do
			local ruleId = placement.ruleOrder[i]
			local rule = placement.rulesById[ruleId]
			if rule and rule.groupId == groupId then
				placement.rulesById[ruleId] = nil
				table.remove(placement.ruleOrder, i)
			end
		end
		Editor.selectedGroupId = placement.groupOrder[1]
		Editor:SyncSelectedRuleToGroup(true)
		Editor:RefreshAll()
		Editor:RefreshRuntimeNow()
	end

	local function createRuleForSelectedGroup(familyId)
		local _, placement = Editor:GetContext()
		if not placement then return end
		local groupId = Editor.selectedGroupId
		if not groupId then return end

		local function addRuleToGroupFamily(targetFamilyId)
			if targetFamilyId == nil then return nil, false end
			targetFamilyId = tostring(targetFamilyId)
			local existingRuleId = findExistingRuleForGroupFamily(placement, groupId, targetFamilyId)
			if existingRuleId then return existingRuleId, false end
			local newId = HB.GetNextRuleId and HB.GetNextRuleId(placement) or tostring((#placement.ruleOrder or 0) + 1)
			placement.rulesById[newId] = HB.CreateDefaultRule and HB.CreateDefaultRule(newId, targetFamilyId, groupId)
				or { id = newId, spellFamilyId = targetFamilyId, groupId = groupId, ["not"] = false, enabled = true, appliesParty = true, appliesRaid = true }
			tinsert(placement.ruleOrder, newId)
			return newId, true
		end

		local function addManyRulesForSelectedGroup(familyIds)
			if type(familyIds) ~= "table" or #familyIds == 0 then return end
			local firstNew, firstExisting, createdAny = nil, nil, false
			for i = 1, #familyIds do
				local ruleId, created = addRuleToGroupFamily(familyIds[i])
				if ruleId then
					if created then
						createdAny = true
						if not firstNew then firstNew = ruleId end
					elseif not firstExisting then
						firstExisting = ruleId
					end
				end
			end
			Editor.selectedRuleId = firstNew or firstExisting or Editor.selectedRuleId
			Editor:RefreshAll()
			if createdAny then Editor:RefreshRuntimeNow() end
		end

		if familyId == nil then
			local familyOptions = buildFamilyOptionsForEditor()
			if #familyOptions == 0 then return end
			for i = 1, #familyOptions do
				local candidateFamilyId = familyOptions[i].value
				if findExistingRuleForGroupFamily(placement, groupId, candidateFamilyId) == nil then
					familyId = candidateFamilyId
					break
				end
			end
			if familyId == nil then return end
		end
		if type(familyId) == "table" then
			addManyRulesForSelectedGroup(familyId)
			return
		end
		local newId, created = addRuleToGroupFamily(familyId)
		if newId then
			Editor.selectedRuleId = newId
			Editor:RefreshAll()
			if created then Editor:RefreshRuntimeNow() end
		end
	end

	local function deleteRuleById(ruleId)
		local _, placement = Editor:GetContext()
		if not (placement and ruleId) then return end
		placement.rulesById[ruleId] = nil
		for i = #placement.ruleOrder, 1, -1 do
			if placement.ruleOrder[i] == ruleId then table.remove(placement.ruleOrder, i) end
		end
		if Editor.selectedRuleId == ruleId then Editor.selectedRuleId = getFirstRuleIdForGroup(placement, Editor.selectedGroupId) or placement.ruleOrder[1] end
		Editor:RefreshAll()
		Editor:RefreshRuntimeNow()
	end

	local function deleteSelectedRule()
		local selected = Editor.selectedRuleId
		if not selected then return end
		deleteRuleById(selected)
	end

	local ruleFamilyMenu = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
	ruleFamilyMenu.displayMode = "MENU"
	UIDropDownMenu_Initialize(ruleFamilyMenu, function(_, level, menuList)
		local buckets, classOrder = buildFamilyOptionsByClass()
		local allFamilies = buildFamilyOptionsForEditor()
		local _, placement = Editor:GetContext()
		local selectedGroupId = Editor.selectedGroupId
		local usedFamilyMap = buildUsedFamilyMapForGroup(placement, selectedGroupId, Editor._ruleMenuUsedFamilyMap)
		Editor._ruleMenuUsedFamilyMap = usedFamilyMap
		if level == 1 then
			local allAvailableFamilyIds = {}
			for i = 1, #allFamilies do
				local familyId = allFamilies[i] and allFamilies[i].value
				if familyId ~= nil and usedFamilyMap[tostring(familyId)] == nil then allAvailableFamilyIds[#allAvailableFamilyIds + 1] = familyId end
			end
			do
				local info = UIDropDownMenu_CreateInfo()
				info.text = "Add all spells"
				info.notCheckable = true
				info.disabled = #allAvailableFamilyIds == 0
				if #allAvailableFamilyIds > 0 then
					local batch = copyArray(allAvailableFamilyIds)
					info.func = function() createRuleForSelectedGroup(batch) end
				end
				UIDropDownMenu_AddButton(info, level)
			end
			for i = 1, #classOrder do
				local classToken = classOrder[i]
				local bucket = buckets[classToken]
				if bucket and bucket.spells and #bucket.spells > 0 then
					local hasAvailable = false
					for si = 1, #bucket.spells do
						local option = bucket.spells[si]
						if option and usedFamilyMap[tostring(option.value)] == nil then
							hasAvailable = true
							break
						end
					end
					local info = UIDropDownMenu_CreateInfo()
					info.text = bucket.label
					info.notCheckable = true
					info.hasArrow = hasAvailable
					info.disabled = not hasAvailable
					if hasAvailable then info.menuList = classToken end
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif level == 2 and menuList then
			local bucket = buckets[menuList]
			if not (bucket and bucket.spells) then return end
			local classAvailableFamilyIds = {}
			for i = 1, #bucket.spells do
				local option = bucket.spells[i]
				if option and usedFamilyMap[tostring(option.value)] == nil then classAvailableFamilyIds[#classAvailableFamilyIds + 1] = option.value end
			end
			do
				local info = UIDropDownMenu_CreateInfo()
				info.text = "Add all"
				info.notCheckable = true
				info.disabled = #classAvailableFamilyIds == 0
				if #classAvailableFamilyIds > 0 then
					local batch = copyArray(classAvailableFamilyIds)
					info.func = function() createRuleForSelectedGroup(batch) end
				end
				UIDropDownMenu_AddButton(info, level)
			end
			for i = 1, #bucket.spells do
				local option = bucket.spells[i]
				local info = UIDropDownMenu_CreateInfo()
				info.text = getDropdownOptionText(option, true)
				info.notCheckable = true
				local isUsed = usedFamilyMap[tostring(option.value)] ~= nil
				info.disabled = isUsed
				if not isUsed then info.func = function() createRuleForSelectedGroup(option.value) end end
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end, "MENU")

	local groupStyleMenu = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
	groupStyleMenu.displayMode = "MENU"
	UIDropDownMenu_Initialize(groupStyleMenu, function(_, level)
		local styleOptions = buildStyleOptionsForMenu()
		for i = 1, #styleOptions do
			local option = styleOptions[i]
			local info = UIDropDownMenu_CreateInfo()
			info.text = getDropdownOptionText(option, true)
			info.notCheckable = true
			info.func = function() createGroupFromStyle(option.value) end
			UIDropDownMenu_AddButton(info, level)
		end
	end, "MENU")

	enabledCheck:SetScript("OnClick", function()
		local _, placement = Editor:GetContext()
		if not placement then return end
		placement.enabled = enabledCheck:GetChecked() == true
		Editor:RefreshRuntimeNow()
		Editor:RefreshLists()
	end)

	addGroup:SetScript("OnClick", function(self)
		if _G.UIDROPDOWNMENU_OPEN_MENU == groupStyleMenu then
			if CloseDropDownMenus then CloseDropDownMenus(1) end
			return
		end
		if ToggleDropDownMenu then
			ToggleDropDownMenu(1, nil, groupStyleMenu, self, 0, 0)
			return
		end
		local styleOptions = buildStyleOptionsForMenu()
		for i = 1, #styleOptions do
			local option = styleOptions[i]
			if option and option.value then
				createGroupFromStyle(option.value)
				return
			end
		end
	end)

	deleteGroup:SetScript("OnClick", function() deleteGroupById(Editor.selectedGroupId) end)

	groupUp:SetScript("OnClick", function()
		local _, placement = Editor:GetContext()
		if not placement then return end
		local idx = indexOf(placement.groupOrder, Editor.selectedGroupId)
		if not idx or idx <= 1 then return end
		placement.groupOrder[idx], placement.groupOrder[idx - 1] = placement.groupOrder[idx - 1], placement.groupOrder[idx]
		Editor:RefreshLists()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	groupDown:SetScript("OnClick", function()
		local _, placement = Editor:GetContext()
		if not placement then return end
		local idx = indexOf(placement.groupOrder, Editor.selectedGroupId)
		if not idx or idx >= #placement.groupOrder then return end
		placement.groupOrder[idx], placement.groupOrder[idx + 1] = placement.groupOrder[idx + 1], placement.groupOrder[idx]
		Editor:RefreshLists()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	addRule:SetScript("OnClick", function(self)
		if _G.UIDROPDOWNMENU_OPEN_MENU == ruleFamilyMenu then
			if CloseDropDownMenus then CloseDropDownMenus(1) end
			return
		end
		if ToggleDropDownMenu then
			ToggleDropDownMenu(1, nil, ruleFamilyMenu, self, 0, 0)
			return
		end
		createRuleForSelectedGroup()
	end)

	deleteRule:SetScript("OnClick", function() deleteSelectedRule() end)

	ruleUp:SetScript("OnClick", function()
		local _, placement = Editor:GetContext()
		if not placement then return end
		local selected = Editor.selectedRuleId
		local rule = selected and placement.rulesById and placement.rulesById[selected]
		if not rule then return end
		local idx = indexOf(placement.ruleOrder, selected)
		if not idx then return end
		local swapIdx = nil
		for i = idx - 1, 1, -1 do
			local ruleId = placement.ruleOrder[i]
			local candidate = ruleId and placement.rulesById and placement.rulesById[ruleId]
			if candidate and candidate.groupId == rule.groupId then
				swapIdx = i
				break
			end
		end
		if not swapIdx then return end
		placement.ruleOrder[idx], placement.ruleOrder[swapIdx] = placement.ruleOrder[swapIdx], placement.ruleOrder[idx]
		Editor:RefreshLists()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	ruleDown:SetScript("OnClick", function()
		local _, placement = Editor:GetContext()
		if not placement then return end
		local selected = Editor.selectedRuleId
		local rule = selected and placement.rulesById and placement.rulesById[selected]
		if not rule then return end
		local idx = indexOf(placement.ruleOrder, selected)
		if not idx then return end
		local swapIdx = nil
		for i = idx + 1, #placement.ruleOrder do
			local ruleId = placement.ruleOrder[i]
			local candidate = ruleId and placement.rulesById and placement.rulesById[ruleId]
			if candidate and candidate.groupId == rule.groupId then
				swapIdx = i
				break
			end
		end
		if not swapIdx then return end
		placement.ruleOrder[idx], placement.ruleOrder[swapIdx] = placement.ruleOrder[swapIdx], placement.ruleOrder[idx]
		Editor:RefreshLists()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	for i = 1, GROUP_VISIBLE_ROWS do
		local row = groupPanel.Rows[i]
		row:SetScript("OnClick", function(self)
			if not self.groupId then return end
			Editor.selectedGroupId = self.groupId
			Editor:SyncSelectedRuleToGroup(true)
			Editor:RefreshAll()
		end)
		row:SetScript("OnDragStart", function(self)
			if not self.groupId then return end
			Editor.draggingList = "groups"
			Editor.dragGroupId = self.groupId
			Editor.dragGroupTarget = nil
			self:SetAlpha(0.6)
		end)
		row:SetScript("OnDragStop", function(self)
			self:SetAlpha(1)
			if Editor.draggingList ~= "groups" then return end
			local fromId = Editor.dragGroupId
			local targetId = Editor.dragGroupTarget
			Editor.draggingList = nil
			Editor.dragGroupId = nil
			Editor.dragGroupTarget = nil
			if not fromId or not targetId or fromId == targetId then
				Editor:RefreshGroupList()
				return
			end
			local _, placement = Editor:GetContext()
			if placement and moveIdInOrder(placement.groupOrder, fromId, targetId) then
				Editor.selectedGroupId = fromId
				Editor:RefreshAll()
				Editor:RefreshRuntimeNow()
				return
			end
			Editor:RefreshGroupList()
		end)
		row:SetScript("OnEnter", function(self)
			if Editor.draggingList == "groups" and self.groupId then
				Editor.dragGroupTarget = self.groupId
				self:SetBackdropColor(0.16, 0.48, 0.24, 0.95)
				self:SetBackdropBorderColor(0.4, 0.9, 0.5, 1)
			end
		end)
		row:SetScript("OnLeave", function()
			if Editor.draggingList == "groups" then Editor:RefreshGroupList() end
		end)
		if row.DeleteButton then
			row.DeleteButton:SetScript("OnClick", function(btn)
				local parent = btn:GetParent()
				if not (parent and parent.groupId) then return end
				deleteGroupById(parent.groupId)
			end)
		end
	end

	for i = 1, RULE_VISIBLE_ROWS do
		local row = rulePanel.Rows[i]
		row:SetScript("OnClick", function(self)
			if not self.ruleId then return end
			Editor.selectedRuleId = self.ruleId
			Editor:RefreshAll()
		end)
		row:SetScript("OnDragStart", function(self)
			if not self.ruleId then return end
			Editor.draggingList = "rules"
			Editor.dragRuleId = self.ruleId
			Editor.dragRuleTarget = nil
			self:SetAlpha(0.6)
		end)
		row:SetScript("OnDragStop", function(self)
			self:SetAlpha(1)
			if Editor.draggingList ~= "rules" then return end
			local fromId = Editor.dragRuleId
			local targetId = Editor.dragRuleTarget
			Editor.draggingList = nil
			Editor.dragRuleId = nil
			Editor.dragRuleTarget = nil
			if not fromId or not targetId or fromId == targetId then
				Editor:RefreshRuleList()
				return
			end
			local _, placement = Editor:GetContext()
			local fromRule = placement and placement.rulesById and placement.rulesById[fromId]
			local targetRule = placement and placement.rulesById and placement.rulesById[targetId]
			if fromRule and targetRule and fromRule.groupId == targetRule.groupId and moveIdInOrder(placement.ruleOrder, fromId, targetId) then
				Editor.selectedRuleId = fromId
				Editor:RefreshAll()
				Editor:RefreshRuntimeNow()
				return
			end
			Editor:RefreshRuleList()
		end)
		row:SetScript("OnEnter", function(self)
			if Editor.draggingList == "rules" and self.ruleId then
				Editor.dragRuleTarget = self.ruleId
				self:SetBackdropColor(0.16, 0.48, 0.24, 0.95)
				self:SetBackdropBorderColor(0.4, 0.9, 0.5, 1)
			end
		end)
		row:SetScript("OnLeave", function()
			if Editor.draggingList == "rules" then Editor:RefreshRuleList() end
		end)
		if row.DeleteButton then
			row.DeleteButton:SetScript("OnClick", function(btn)
				local parent = btn:GetParent()
				if not (parent and parent.ruleId) then return end
				deleteRuleById(parent.ruleId)
			end)
		end
	end

	local function groupFromSelection()
		local _, placement = Editor:GetContext()
		if not placement then return nil end
		local groupId = Editor.selectedGroupId
		return groupId and placement.groupsById and placement.groupsById[groupId] or nil
	end

	local function ruleFromSelection()
		local _, placement = Editor:GetContext()
		if not placement then return nil end
		local ruleId = Editor.selectedRuleId
		return ruleId and placement.rulesById and placement.rulesById[ruleId] or nil
	end

	local function updateGroupFromSlider(field, slider, valueText, minValue, maxValue, step)
		slider:SetScript("OnValueChanged", function(self, value)
			if Editor._controlUpdateLock then return end
			local group = groupFromSelection()
			if not group then return end
			if step and step >= 1 then
				value = roundInt(value)
			else
				value = tonumber(string.format("%.2f", value))
			end
			if minValue ~= nil and value < minValue then value = minValue end
			if maxValue ~= nil and value > maxValue then value = maxValue end
			group[field] = value
			if field == "x" or field == "y" then
				local preview = Editor.frame and Editor.frame.PreviewPanel and Editor.frame.PreviewPanel.Frame and Editor.frame.PreviewPanel.Frame.UnitFrame
				if preview then
					group.x, group.y = HB.ClampOffsets(group.anchorPoint, group.x, group.y, preview:GetWidth(), preview:GetHeight(), 0)
					if field == "x" then
						value = group.x
					else
						value = group.y
					end
				end
			end
			if valueText then
				if step and step < 1 then
					valueText:SetText(string.format("%.2f", value))
				else
					valueText:SetText(tostring(value))
				end
			end
			Editor:RefreshPreview()
			Editor:QueueRuntimeRefresh()
		end)
	end

	updateGroupFromSlider("perRow", controls.PerRow, controls.PerRowValue, 1, 20, 1)
	updateGroupFromSlider("max", controls.MaxCount, controls.MaxValue, 0, 40, 1)
	updateGroupFromSlider("spacing", controls.Spacing, controls.SpacingValue, 0, 20, 1)
	updateGroupFromSlider("size", controls.Size, controls.SizeValue, 4, 64, 1)
	updateGroupFromSlider("x", controls.XOffset, controls.XValue, -200, 200, 1)
	updateGroupFromSlider("y", controls.YOffset, controls.YValue, -200, 200, 1)
	updateGroupFromSlider("barThickness", controls.Thickness, controls.ThicknessValue, 1, 64, 1)
	updateGroupFromSlider("inset", controls.Inset, controls.InsetValue, 0, 40, 1)
	updateGroupFromSlider("borderSize", controls.BorderSize, controls.BorderSizeValue, 1, 16, 1)

	controls.GroupName:SetScript("OnEnterPressed", function(self)
		local group = groupFromSelection()
		if not group then return end
		local text = self:GetText()
		if text == nil or text == "" then text = "Indicator " .. tostring(group.id or "") end
		group.name = text
		self:ClearFocus()
		Editor:RefreshGroupList()
		Editor:RefreshRuleList()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)
	controls.GroupName:SetScript("OnEditFocusLost", function(self)
		local group = groupFromSelection()
		if not group then return end
		local text = self:GetText()
		if text == nil or text == "" then text = "Indicator " .. tostring(group.id or "") end
		group.name = text
		Editor:RefreshGroupList()
		Editor:RefreshRuleList()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	setDropdown(controls.GroupAnchor, HB.ANCHOR_OPTIONS, nil, function(value)
		local group = groupFromSelection()
		if not group then return end
		group.anchorPoint = value
		local preview = frame.PreviewPanel and frame.PreviewPanel.Frame and frame.PreviewPanel.Frame.UnitFrame
		if preview then
			group.x, group.y = HB.ClampOffsets(group.anchorPoint, group.x, group.y, preview:GetWidth(), preview:GetHeight(), 0)
		end
		Editor:RefreshGroupControls()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	setDropdown(controls.GroupGrowth, HB.GROWTH_OPTIONS, nil, function(value)
		local group = groupFromSelection()
		if not group then return end
		group.growth = value
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	setDropdown(controls.GroupBarOrientation, HB.ORIENTATION_OPTIONS, nil, function(value)
		local group = groupFromSelection()
		if not group then return end
		group.barOrientation = value
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	controls.ColorButton:SetScript("OnClick", function()
		local group = groupFromSelection()
		if not group then return end
		group.color = group.color or { 1, 0.82, 0.1, 0.9 }
		showColorPicker(group.color, function(r, g, b, a)
			group.color[1], group.color[2], group.color[3], group.color[4] = r, g, b, a
			Editor:RefreshGroupControls()
			Editor:RefreshPreview()
			Editor:QueueRuntimeRefresh()
		end)
	end)

	controls.RuleEnabled:SetScript("OnClick", function(self)
		local rule = ruleFromSelection()
		if not rule then return end
		rule.enabled = self:GetChecked() == true
		Editor:RefreshRuleList()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	controls.RuleNot:SetScript("OnClick", function(self)
		local rule = ruleFromSelection()
		if not rule then return end
		rule["not"] = self:GetChecked() == true
		Editor:RefreshRuleList()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	controls.RuleAppliesParty:SetScript("OnClick", function(self)
		local rule = ruleFromSelection()
		if not rule then return end
		rule.appliesParty = self:GetChecked() == true
		if rule.appliesParty == false and rule.appliesRaid == false then
			rule.appliesRaid = true
			controls.RuleAppliesRaid:SetChecked(true)
		end
		Editor:RefreshRuleList()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	controls.RuleAppliesRaid:SetScript("OnClick", function(self)
		local rule = ruleFromSelection()
		if not rule then return end
		rule.appliesRaid = self:GetChecked() == true
		if rule.appliesRaid == false and rule.appliesParty == false then
			rule.appliesParty = true
			controls.RuleAppliesParty:SetChecked(true)
		end
		Editor:RefreshRuleList()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	setDropdown(controls.RuleIconMode, HB.ICON_MODE_OPTIONS or {
		{ value = "ALL", label = "Show All Active Spells" },
		{ value = "PRIORITY", label = "Show Highest Priority Only" },
	}, nil, function(value)
		local _, placement = Editor:GetContext()
		if not placement then return end
		local groupId = Editor.selectedGroupId
		local group = groupId and placement.groupsById and placement.groupsById[groupId]
		if not group then return end
		group.iconMode = tostring(value or "ALL"):upper()
		Editor:RefreshGroupControls()
		Editor:RefreshRuleControls()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	setDropdown(controls.RuleMatch, HB.RULE_MATCH_OPTIONS or {
		{ value = "ANY", label = "Require Any Spell" },
		{ value = "ALL", label = "Require All Spells" },
	}, nil, function(value)
		local _, placement = Editor:GetContext()
		if not placement then return end
		local groupId = Editor.selectedGroupId
		local group = groupId and placement.groupsById and placement.groupsById[groupId]
		if not group then return end
		group.ruleMatch = tostring(value or "ANY"):upper()
		Editor:RefreshRuleControls()
		Editor:RefreshPreview()
		Editor:RefreshRuntimeNow()
	end)

	frame:SetScript("OnShow", function()
		if frame._updateGroupControlScroll then frame._updateGroupControlScroll() end
	end)
	frame:SetScript("OnSizeChanged", function()
		if frame._updateGroupControlScroll then frame._updateGroupControlScroll() end
	end)
	if frame._updateGroupControlScroll then frame._updateGroupControlScroll() end

	return frame
end

function Editor:RefreshGroupList()
	local frame = self:EnsureFrame()
	local _, placement = self:GetContext()
	local rows = frame.GroupPanel.Rows
	if not placement then
		for i = 1, #rows do
			rows[i]:Hide()
		end
		if frame.GroupPanel and frame.GroupPanel.ScrollBar and frame.GroupPanel.ScrollBar.Sync then frame.GroupPanel.ScrollBar:Sync() end
		return
	end
	local order = placement.groupOrder or EMPTY
	if self.selectedGroupId == nil or indexOf(order, self.selectedGroupId) == nil then self.selectedGroupId = order[1] end
	local maxOffset = max(0, #order - GROUP_VISIBLE_ROWS)
	if (self.groupOffset or 0) > maxOffset then self.groupOffset = maxOffset end
	if (self.groupOffset or 0) < 0 then self.groupOffset = 0 end

	for i = 1, GROUP_VISIBLE_ROWS do
		local index = i + (self.groupOffset or 0)
		local row = rows[i]
		local groupId = order[index]
		local group = groupId and placement.groupsById and placement.groupsById[groupId]
		if group then
			row.groupId = groupId
			row:Show()
			if row.DeleteButton then row.DeleteButton:Show() end
			local label = string.format("%d. %s  [%s]", index, tostring(group.name or ("Indicator " .. tostring(groupId))), tostring(group.style or "ICON"))
			row.Text:SetText(label)
			if groupId == self.selectedGroupId then
				row:SetBackdropColor(0.12, 0.19, 0.3, 0.95)
				row:SetBackdropBorderColor(0.52, 0.76, 1, 1)
			else
				row:SetBackdropColor(0.07, 0.09, 0.12, 0.82)
				row:SetBackdropBorderColor(0.2, 0.26, 0.32, 0.9)
			end
		else
			row.groupId = nil
			if row.DeleteButton then row.DeleteButton:Hide() end
			row:Hide()
		end
	end
	if frame.GroupPanel and frame.GroupPanel.ScrollBar and frame.GroupPanel.ScrollBar.Sync then frame.GroupPanel.ScrollBar:Sync() end
end

function Editor:RefreshRuleList()
	local frame = self:EnsureFrame()
	local _, placement = self:GetContext()
	local rows = frame.RulePanel.Rows
	if frame.RulePanel and frame.RulePanel.Title then
		local groupLabel = (placement and self.selectedGroupId) and getGroupLabel(placement, self.selectedGroupId) or nil
		frame.RulePanel.Title:SetText(groupLabel and ("Spell Rules - " .. groupLabel) or "Spell Rules")
	end
	if not placement then
		for i = 1, #rows do
			rows[i]:Hide()
		end
		if frame.RulePanel and frame.RulePanel.ScrollBar and frame.RulePanel.ScrollBar.Sync then frame.RulePanel.ScrollBar:Sync() end
		return
	end
	local order = getVisibleRuleIds(placement, self.selectedGroupId, self._ruleScratch)
	self._ruleScratch = order
	if self.selectedRuleId and placement.rulesById and placement.rulesById[self.selectedRuleId] then
		local selectedRule = placement.rulesById[self.selectedRuleId]
		if self.selectedGroupId and selectedRule.groupId ~= self.selectedGroupId then
			self.selectedRuleId = order[1]
		elseif indexOf(order, self.selectedRuleId) == nil then
			self.selectedRuleId = order[1]
		end
	elseif self.selectedRuleId ~= nil then
		self.selectedRuleId = order[1]
	end
	local maxOffset = max(0, #order - RULE_VISIBLE_ROWS)
	if (self.ruleOffset or 0) > maxOffset then self.ruleOffset = maxOffset end
	if (self.ruleOffset or 0) < 0 then self.ruleOffset = 0 end

	for i = 1, RULE_VISIBLE_ROWS do
		local index = i + (self.ruleOffset or 0)
		local row = rows[i]
		local ruleId = order[index]
		local rule = ruleId and placement.rulesById and placement.rulesById[ruleId]
		if rule then
			row.ruleId = ruleId
			row:Show()
			if row.DeleteButton then row.DeleteButton:Show() end
			local familyLabel = getFamilyLabel(rule.spellFamilyId, true)
			local marker = rule["not"] and " [NOT]" or ""
			local state = (rule.enabled ~= false) and "" or " [OFF]"
			local appliesParty = rule.appliesParty ~= false
			local appliesRaid = rule.appliesRaid ~= false
			local scope = " [NONE]"
			if appliesParty and appliesRaid then
				scope = " [P/R]"
			elseif appliesParty then
				scope = " [P]"
			elseif appliesRaid then
				scope = " [R]"
			end
			local label = string.format("%d. %s%s%s%s", index, familyLabel, scope, marker, state)
			row.Text:SetText(label)
			if ruleId == self.selectedRuleId then
				row:SetBackdropColor(0.12, 0.19, 0.3, 0.95)
				row:SetBackdropBorderColor(0.52, 0.76, 1, 1)
			else
				row:SetBackdropColor(0.07, 0.09, 0.12, 0.82)
				row:SetBackdropBorderColor(0.2, 0.26, 0.32, 0.9)
			end
		else
			row.ruleId = nil
			if row.DeleteButton then row.DeleteButton:Hide() end
			row:Hide()
		end
	end
	if frame.RulePanel and frame.RulePanel.ScrollBar and frame.RulePanel.ScrollBar.Sync then frame.RulePanel.ScrollBar:Sync() end
end

function Editor:RefreshLists()
	self:RefreshGroupList()
	self:RefreshRuleList()
end

function Editor:RefreshRuleControls()
	local frame = self:EnsureFrame()
	local controls = frame.Controls
	local _, placement = self:GetContext()
	self:SyncSelectedRuleToGroup(false)
	local rule = placement and self.selectedRuleId and placement.rulesById and placement.rulesById[self.selectedRuleId] or nil
	local selectedGroup = placement and self.selectedGroupId and placement.groupsById and placement.groupsById[self.selectedGroupId] or nil
	local selectedGroupStyle = tostring(selectedGroup and selectedGroup.style or "")
	local showIconRuleMode = selectedGroupStyle == "ICON" or selectedGroupStyle == "SQUARE"
	local showTintRuleMatch = selectedGroupStyle == "TINT"
	local iconModeOptions = HB.ICON_MODE_OPTIONS or {
		{ value = "ALL", label = "Show All Active Spells" },
		{ value = "PRIORITY", label = "Show Highest Priority Only" },
	}
	local ruleMatchOptions = HB.RULE_MATCH_OPTIONS or {
		{ value = "ANY", label = "Require Any Spell" },
		{ value = "ALL", label = "Require All Spells" },
	}

	setControlVisible(controls.RuleIconModeLabel, showIconRuleMode)
	setControlVisible(controls.RuleIconMode, showIconRuleMode)
	setControlEnabled(controls.RuleIconMode, showIconRuleMode)
	if showIconRuleMode then setDropdown(controls.RuleIconMode, iconModeOptions, tostring(selectedGroup.iconMode or "ALL"):upper(), controls.RuleIconMode._eqolOnSelect) end

	setControlVisible(controls.RuleMatchLabel, showTintRuleMatch)
	setControlVisible(controls.RuleMatch, showTintRuleMatch)
	setControlEnabled(controls.RuleMatch, showTintRuleMatch)
	if showTintRuleMatch then setDropdown(controls.RuleMatch, ruleMatchOptions, tostring(selectedGroup.ruleMatch or "ANY"):upper(), controls.RuleMatch._eqolOnSelect) end

	controls.RuleInfo:ClearAllPoints()
	if showTintRuleMatch then
		controls.RuleInfo:SetPoint("TOPLEFT", controls.RuleMatchLabel, "BOTTOMLEFT", 0, -10)
	elseif showIconRuleMode then
		controls.RuleInfo:SetPoint("TOPLEFT", controls.RuleIconModeLabel, "BOTTOMLEFT", 0, -10)
	else
		controls.RuleInfo:SetPoint("TOPLEFT", controls.RuleAppliesRaid, "BOTTOMLEFT", 0, -10)
	end
	controls.RuleInfo:SetPoint("RIGHT", frame.SettingsPanel, "RIGHT", -14, 0)

	controls.RuleEnabled:SetChecked(rule and rule.enabled ~= false)
	controls.RuleNot:SetChecked(rule and rule["not"] == true)
	controls.RuleAppliesParty:SetChecked(rule and rule.appliesParty ~= false)
	controls.RuleAppliesRaid:SetChecked(rule and rule.appliesRaid ~= false)
	setControlEnabled(controls.RuleEnabled, rule ~= nil)
	setControlEnabled(controls.RuleNot, rule ~= nil)
	setControlEnabled(controls.RuleAppliesParty, rule ~= nil)
	setControlEnabled(controls.RuleAppliesRaid, rule ~= nil)
	setControlEnabled(frame.RulePanel and frame.RulePanel.AddButton, self.selectedGroupId ~= nil)
	if controls.RuleInfo then
		local groupLabel = placement and self.selectedGroupId and getGroupLabel(placement, self.selectedGroupId) or "selected indicator"
		if showTintRuleMatch then
			controls.RuleInfo:SetText("Showing rules for " .. groupLabel .. ". Scope is set per rule (Party/Raid). Tint can require any or all active spells.")
		elseif showIconRuleMode then
			controls.RuleInfo:SetText("Showing rules for " .. groupLabel .. ". Scope is set per rule (Party/Raid). Priority follows the rule order in this list.")
		else
			controls.RuleInfo:SetText("Showing rules for " .. groupLabel .. ". Scope is set per rule (Party/Raid). Add via +, remove via x.")
		end
	end
end

function Editor:RefreshGroupControls()
	local frame = self:EnsureFrame()
	local controls = frame.Controls
	local _, placement = self:GetContext()
	local group = placement and self.selectedGroupId and placement.groupsById and placement.groupsById[self.selectedGroupId] or nil

	local function setFieldState(label, control, visible, enabled)
		setControlVisible(label, visible)
		setControlVisible(control, visible)
		setControlEnabled(control, enabled and visible)
	end

	local function setSliderState(label, slider, valueText, visible, enabled)
		setControlVisible(label, visible)
		setControlVisible(slider, visible)
		setControlVisible(valueText, visible)
		setControlEnabled(slider, enabled and visible)
	end

	local function setColorState(visible, enabled)
		setControlVisible(controls.ColorLabel, visible)
		setControlVisible(controls.ColorButton, visible)
		setControlEnabled(controls.ColorButton, enabled and visible)
	end

	self._controlUpdateLock = true
	setControlVisible(controls.GroupStyleLabel, false)
	setControlVisible(controls.GroupStyleValue, false)
	if group then
		local style = tostring(group.style or "ICON")
		group.iconMode = tostring(group.iconMode or "ALL"):upper()
		local isPriorityIconMode = (style == "ICON" or style == "SQUARE") and group.iconMode == "PRIORITY"
		local showAnchor = style ~= "TINT"
		local showGrowth = (style == "ICON" or style == "SQUARE") and not isPriorityIconMode
		local showGrid = showGrowth
		local showSize = style == "ICON" or style == "SQUARE"
		local showOffsets = style ~= "TINT"
		local showBar = style == "BAR"
		local showInset = style == "BAR" or style == "BORDER"
		local showBorder = style == "BORDER"
		local showColor = style == "SQUARE" or style == "BAR" or style == "BORDER" or style == "TINT"

		controls.GroupName:SetText(group.name or "")
		setDropdown(controls.GroupAnchor, HB.ANCHOR_OPTIONS, group.anchorPoint or "CENTER", controls.GroupAnchor._eqolOnSelect)
		setDropdown(controls.GroupGrowth, HB.GROWTH_OPTIONS, group.growth or "RIGHTDOWN", controls.GroupGrowth._eqolOnSelect)
		setDropdown(controls.GroupBarOrientation, HB.ORIENTATION_OPTIONS, group.barOrientation or "HORIZONTAL", controls.GroupBarOrientation._eqolOnSelect)

		local preview = frame.PreviewPanel and frame.PreviewPanel.Frame and frame.PreviewPanel.Frame.UnitFrame
		if preview then
			group.x, group.y = HB.ClampOffsets(group.anchorPoint, group.x, group.y, preview:GetWidth(), preview:GetHeight(), 0)
		end

		controls.PerRow:SetValue(group.perRow or 3)
		controls.PerRowValue:SetText(tostring(group.perRow or 3))
		controls.MaxCount:SetValue(group.max or 3)
		controls.MaxValue:SetText(tostring(group.max or 3))
		controls.Spacing:SetValue(group.spacing or 0)
		controls.SpacingValue:SetText(tostring(group.spacing or 0))
		controls.Size:SetValue(group.size or 16)
		controls.SizeValue:SetText(tostring(group.size or 16))
		controls.XOffset:SetValue(group.x or 0)
		controls.XValue:SetText(tostring(group.x or 0))
		controls.YOffset:SetValue(group.y or 0)
		controls.YValue:SetText(tostring(group.y or 0))
		controls.Thickness:SetValue(group.barThickness or 6)
		controls.ThicknessValue:SetText(tostring(group.barThickness or 6))
		controls.Inset:SetValue(group.inset or 0)
		controls.InsetValue:SetText(tostring(group.inset or 0))
		controls.BorderSize:SetValue(group.borderSize or 2)
		controls.BorderSizeValue:SetText(tostring(group.borderSize or 2))

		group.color = group.color or { 1, 0.82, 0.1, 0.22 }
		setColorPreview(controls.ColorButton, group.color)

		setControlEnabled(controls.GroupName, true)
		setFieldState(controls.GroupAnchorLabel, controls.GroupAnchor, showAnchor, true)
		setFieldState(controls.GroupGrowthLabel, controls.GroupGrowth, showGrowth, true)
		setFieldState(controls.GroupBarOrientationLabel, controls.GroupBarOrientation, showBar, true)
		setSliderState(controls.PerRowLabel, controls.PerRow, controls.PerRowValue, showGrid, true)
		setSliderState(controls.MaxLabel, controls.MaxCount, controls.MaxValue, showGrid, true)
		setSliderState(controls.SpacingLabel, controls.Spacing, controls.SpacingValue, showGrid, true)
		setSliderState(controls.SizeLabel, controls.Size, controls.SizeValue, showSize, true)
		setSliderState(controls.XLabel, controls.XOffset, controls.XValue, showOffsets, true)
		setSliderState(controls.YLabel, controls.YOffset, controls.YValue, showOffsets, true)
		setSliderState(controls.ThicknessLabel, controls.Thickness, controls.ThicknessValue, showBar, true)
		setSliderState(controls.InsetLabel, controls.Inset, controls.InsetValue, showInset, true)
		setSliderState(controls.BorderSizeLabel, controls.BorderSize, controls.BorderSizeValue, showBorder, true)
		setColorState(showColor, true)
	else
		controls.GroupName:SetText("")
		setControlEnabled(controls.GroupName, false)
		setFieldState(controls.GroupAnchorLabel, controls.GroupAnchor, false, false)
		setFieldState(controls.GroupGrowthLabel, controls.GroupGrowth, false, false)
		setFieldState(controls.GroupBarOrientationLabel, controls.GroupBarOrientation, false, false)
		setSliderState(controls.PerRowLabel, controls.PerRow, controls.PerRowValue, false, false)
		setSliderState(controls.MaxLabel, controls.MaxCount, controls.MaxValue, false, false)
		setSliderState(controls.SpacingLabel, controls.Spacing, controls.SpacingValue, false, false)
		setSliderState(controls.SizeLabel, controls.Size, controls.SizeValue, false, false)
		setSliderState(controls.XLabel, controls.XOffset, controls.XValue, false, false)
		setSliderState(controls.YLabel, controls.YOffset, controls.YValue, false, false)
		setSliderState(controls.ThicknessLabel, controls.Thickness, controls.ThicknessValue, false, false)
		setSliderState(controls.InsetLabel, controls.Inset, controls.InsetValue, false, false)
		setSliderState(controls.BorderSizeLabel, controls.BorderSize, controls.BorderSizeValue, false, false)
		setColorState(false, false)
		setColorPreview(controls.ColorButton, { 1, 1, 1, 1 })
	end
	self._controlUpdateLock = nil

	if frame._layoutGroupControlRows then frame._layoutGroupControlRows() end
	if frame._updateGroupControlScroll then frame._updateGroupControlScroll() end
end

local function clearPreview(unitFrame)
	if not unitFrame then return end
	for i = 1, #(unitFrame.SampleIcons or {}) do
		unitFrame.SampleIcons[i]:Hide()
	end
	for i = 1, #(unitFrame.SampleTints or {}) do
		unitFrame.SampleTints[i]:Hide()
	end
	for i = 1, #(unitFrame.SampleBars or {}) do
		unitFrame.SampleBars[i]:Hide()
	end
	for i = 1, #(unitFrame.SampleBorders or {}) do
		unitFrame.SampleBorders[i]:Hide()
	end
	if unitFrame.HealthTexture then unitFrame.HealthTexture:SetColorTexture(0.08, 0.42, 0.19, 1) end
end

local function resolveColor(color)
	if type(color) == "table" then return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 end
	return 1, 1, 1, 1
end

local function applyPreviewHealthTint(unitFrame, tintR, tintG, tintB, tintA)
	if not (unitFrame and unitFrame.HealthTexture) then return end
	local baseR, baseG, baseB, baseA = 0.08, 0.42, 0.19, 1
	if tintA == nil then
		unitFrame.HealthTexture:SetColorTexture(baseR, baseG, baseB, baseA)
		return
	end
	local strength = max(0, min(1, tonumber(tintA) or 0))
	if strength <= 0 then
		unitFrame.HealthTexture:SetColorTexture(baseR, baseG, baseB, baseA)
		return
	end
	local inv = 1 - strength
	unitFrame.HealthTexture:SetColorTexture((baseR * inv) + ((tintR or baseR) * strength), (baseG * inv) + ((tintG or baseG) * strength), (baseB * inv) + ((tintB or baseB) * strength), baseA)
end

local function ruleAppliesToPreviewKind(rule, kind)
	if not rule then return false end
	kind = tostring(kind or "party"):lower()
	if kind == "mt" or kind == "ma" then kind = "raid" end
	if kind == "raid" then return rule.appliesRaid ~= false end
	return rule.appliesParty ~= false
end

local function getRuleIdsForGroup(placement, groupId, kind, classToken)
	local list = {}
	eachGroupRule(placement, groupId, function(ruleId, rule)
		if rule and rule.enabled ~= false and ruleAppliesToPreviewKind(rule, kind) then
			if classToken == nil or isRuleForClass(rule, classToken) then list[#list + 1] = ruleId end
		end
	end)
	return list
end

local function isPreviewRuleActive(rule)
	if not rule or rule.enabled == false then return false end
	local active = true
	if rule["not"] then active = not active end
	return active
end

local function isPreviewGroupTintActive(placement, group, kind, classToken)
	if not (placement and group and group.id) then return false end
	local ruleIds = getRuleIdsForGroup(placement, group.id, kind, classToken)
	local ruleMatch = tostring(group.ruleMatch or "ANY"):upper()
	if ruleMatch == "ALL" then
		if #ruleIds == 0 then return false end
		for i = 1, #ruleIds do
			local rule = placement.rulesById and placement.rulesById[ruleIds[i]]
			if not isPreviewRuleActive(rule) then return false end
		end
		return true
	end
	for i = 1, #ruleIds do
		local rule = placement.rulesById and placement.rulesById[ruleIds[i]]
		if isPreviewRuleActive(rule) then return true end
	end
	return false
end

function Editor:RefreshPreview()
	local frame = self:EnsureFrame()
	local _, placement = self:GetContext()
	local preview = frame.PreviewPanel and frame.PreviewPanel.Frame and frame.PreviewPanel.Frame.UnitFrame
	if not preview then return end
	clearPreview(preview)

	if not placement then return end
	local order = placement.groupOrder or EMPTY
	local iconIndex, barIndex, borderIndex = 1, 1, 1
	local tintR, tintG, tintB, tintA
	local hasTint = false
	local w, h = preview:GetWidth(), preview:GetHeight()
	for index = 1, #order do
		local groupId = order[index]
		local group = placement.groupsById and placement.groupsById[groupId]
		if group then
			local style = tostring(group.style or "ICON"):upper()
			local iconMode = tostring(group.iconMode or "ALL"):upper()
			local anchorPoint = group.anchorPoint or "CENTER"
			local selected = groupId == self.selectedGroupId
			local anchor = ANCHOR_COORDS[anchorPoint] or ANCHOR_COORDS.CENTER
			local anchorX = (anchor[1] or 0) * w
			local anchorY = (anchor[2] or 0) * h
			local x = group.x or 0
			local y = group.y or 0
			x, y = HB.ClampOffsets(anchorPoint, x, y, w, h, 0)
			group.x, group.y = x, y
			local baseX = anchorX + x
			local baseY = anchorY + y

			if style == "ICON" or style == "SQUARE" then
				local ruleIds = getRuleIdsForGroup(placement, group.id, self.kind)
				local isPriorityMode = iconMode == "PRIORITY"
				if isPriorityMode and #ruleIds > 1 then
					for trim = #ruleIds, 2, -1 do
						ruleIds[trim] = nil
					end
				end
				local size = max(4, tonumber(group.size) or 16)
				local spacing = max(0, tonumber(group.spacing) or 0)
				local perRow = max(1, tonumber(group.perRow) or 1)
				local maxIcons = max(0, tonumber(group.max) or 3)
				local previewCount = isPriorityMode and min(maxIcons, 1) or min(maxIcons, 3)
				local shown
				if isPriorityMode then
					shown = maxIcons > 0 and 1 or 0
				else
					shown = min(maxIcons, max(#ruleIds, previewCount))
				end
				local primary, secondary = HB.GetGrowthAxes(group.growth)
				local primaryHorizontal = primary == "LEFT" or primary == "RIGHT"
				for i = 1, shown do
					local row, col
					if primaryHorizontal then
						row = floor((i - 1) / perRow)
						col = (i - 1) % perRow
					else
						row = (i - 1) % perRow
						col = floor((i - 1) / perRow)
					end
					local horizontalDir = primaryHorizontal and primary or secondary
					local verticalDir = primaryHorizontal and secondary or primary
					local xSign = horizontalDir == "RIGHT" and 1 or -1
					local ySign = verticalDir == "UP" and 1 or -1
					local px = x + (col * (size + spacing) * xSign)
					local py = y + (row * (size + spacing) * ySign)
					local icon = preview.SampleIcons[iconIndex]
					iconIndex = iconIndex + 1
					if icon then
						icon:SetSize(size, size)
						icon:ClearAllPoints()
						icon:SetPoint(anchorPoint, preview, anchorPoint, px, py)
						local ruleId = ruleIds[i]
						if ruleId == nil and #ruleIds > 0 then
							local cycleIndex = ((i - 1) % #ruleIds) + 1
							ruleId = ruleIds[cycleIndex]
						end
						local rule = ruleId and placement.rulesById and placement.rulesById[ruleId]
						local family = rule and HB.GetFamilyById and HB.GetFamilyById(rule.spellFamilyId)
						local iconTex = family and family._resolvedIcon or nil
						if not iconTex and family and family.spellIds and family.spellIds[1] then
							if C_Spell and C_Spell.GetSpellTexture then
								iconTex = C_Spell.GetSpellTexture(family.spellIds[1])
							elseif GetSpellTexture then
								iconTex = GetSpellTexture(family.spellIds[1])
							end
						end
						if style == "SQUARE" then
							local r, g, b, a = resolveColor(group.color)
							icon.Texture:SetTexture("Interface\\Buttons\\WHITE8x8")
							icon.Texture:SetVertexColor(r, g, b, a)
						else
							icon.Texture:SetTexture(iconTex or 134400)
							icon.Texture:SetVertexColor(1, 1, 1, 1)
						end
						icon:SetBackdropBorderColor(selected and 0.95 or 0, selected and 0.8 or 0, selected and 0.25 or 0, selected and 1 or 0.8)
						icon:Show()
					end
				end
			elseif style == "BAR" then
				local bar = preview.SampleBars[barIndex]
				barIndex = barIndex + 1
				if bar then
					local r, g, b, a = resolveColor(group.color)
					if not selected then a = min(a, 0.45) end
					bar:SetColorTexture(r, g, b, a)
					bar:ClearAllPoints()
					local inset = max(0, tonumber(group.inset) or 0)
					local thickness = max(1, tonumber(group.barThickness) or 6)
					if tostring(group.barOrientation or "HORIZONTAL") == "VERTICAL" then
						bar:SetPoint("TOP", preview, "TOP", baseX, baseY - inset)
						bar:SetPoint("BOTTOM", preview, "BOTTOM", baseX, baseY + inset)
						bar:SetWidth(thickness)
					else
						bar:SetPoint("LEFT", preview, "LEFT", baseX + inset, baseY)
						bar:SetPoint("RIGHT", preview, "RIGHT", baseX - inset, baseY)
						bar:SetHeight(thickness)
					end
					bar:Show()
				end
			elseif style == "BORDER" then
				local border = preview.SampleBorders[borderIndex]
				borderIndex = borderIndex + 1
				if border then
					local r, g, b, a = resolveColor(group.color)
					if not selected then a = min(a, 0.6) end
					local inset = max(0, tonumber(group.inset) or 0)
					local size = max(1, tonumber(group.borderSize) or 1)
					border:ClearAllPoints()
					border:SetPoint("TOPLEFT", preview, "TOPLEFT", baseX + inset, baseY - inset)
					border:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", baseX - inset, baseY + inset)
					border:SetBackdrop({
						bgFile = "Interface\\Buttons\\WHITE8x8",
						edgeFile = "Interface\\Buttons\\WHITE8x8",
						tile = false,
						edgeSize = size,
						insets = { left = 0, right = 0, top = 0, bottom = 0 },
					})
					border:SetBackdropColor(0, 0, 0, 0)
					border:SetBackdropBorderColor(r, g, b, a)
					border:Show()
				end
			elseif style == "TINT" then
				local active = isPreviewGroupTintActive(placement, group, self.kind)
				if active or selected then
					local r, g, b, a = resolveColor(group.color)
					if not active and selected then a = min(a, 0.35) end
					if selected then
						tintR, tintG, tintB, tintA = r, g, b, a
						hasTint = true
					elseif not hasTint then
						tintR, tintG, tintB, tintA = r, g, b, a
						hasTint = true
					end
				end
			end
		end
	end

	applyPreviewHealthTint(preview, tintR, tintG, tintB, hasTint and tintA or nil)
end

function Editor:RefreshControls()
	local frame = self:EnsureFrame()
	local _, placement = self:GetContext()
	if frame.KindValue then frame.KindValue:SetText("Shared (Party + Raid)") end
	if frame.EnabledCheck and placement then frame.EnabledCheck:SetChecked(placement.enabled == true) end
	self:RefreshGroupControls()
	self:RefreshRuleControls()
end

function Editor:RefreshAll()
	self:EnsureSelection()
	self:RefreshLists()
	self:RefreshControls()
	self:RefreshPreview()
end

function Editor:Show(kind)
	kind = tostring(kind or "party"):lower()
	if kind ~= "party" and kind ~= "raid" then kind = "party" end
	self.kind = kind
	self:EnsureFrame()
	self.groupOffset = 0
	self.ruleOffset = 0
	self:EnsureSelection()
	self:RefreshAll()
	self.frame:Show()
	self.frame:Raise()
end

function Editor:Hide()
	if self.frame then self.frame:Hide() end
end

function Editor:Toggle(kind)
	self:EnsureFrame()
	if self.frame:IsShown() then
		self:Hide()
		return
	end
	self:Show(kind)
end

function Editor:IsShown() return self.frame and self.frame:IsShown() == true end
