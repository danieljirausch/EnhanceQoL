local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local ResourceBars = addon.Aura and addon.Aura.ResourceBars
if not ResourceBars then return end

local function resolveVisibilityFlag(cfg, cfgKey, globalKey, defaultValue)
	if type(cfg) == "table" and cfg[cfgKey] ~= nil then return cfg[cfgKey] == true end
	local db = addon and addon.db
	if db and db[globalKey] ~= nil then return db[globalKey] == true end
	return defaultValue == true
end

function ResourceBars.ShouldHideInClientScene(cfg) return resolveVisibilityFlag(cfg, "hideClientScene", "resourceBarsHideClientScene", true) end

function ResourceBars.ShouldHideOutOfCombat(cfg) return resolveVisibilityFlag(cfg, "hideOutOfCombat", "resourceBarsHideOutOfCombat", false) end

function ResourceBars.ShouldHideMounted(cfg) return resolveVisibilityFlag(cfg, "hideMounted", "resourceBarsHideMounted", false) end

function ResourceBars.ShouldHideInVehicle(cfg) return resolveVisibilityFlag(cfg, "hideVehicle", "resourceBarsHideVehicle", false) end

function ResourceBars.ShouldHideInPetBattle(cfg) return resolveVisibilityFlag(cfg, "hidePetBattle", "resourceBarsHidePetBattle", false) end

function ResourceBars.ApplyClientSceneAlphaToFrame(frame, forceHide)
	if not (frame and frame.SetAlpha) then return end
	if forceHide then
		frame._rbClientSceneAlphaHidden = true
		if frame.GetAlpha and frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
	elseif frame._rbClientSceneAlphaHidden then
		frame._rbClientSceneAlphaHidden = nil
		if frame.GetAlpha and frame:GetAlpha() == 0 then frame:SetAlpha(1) end
	end
end

local function normalizeGradientColor(value)
	if type(value) == "table" then
		if value.r ~= nil then return value.r or 1, value.g or 1, value.b or 1, value.a or 1 end
		return value[1] or 1, value[2] or 1, value[3] or 1, value[4] or 1
	end
	return 1, 1, 1, 1
end

local function resolveDiscreteSegmentBackground(cfg, fallbackTexture, fallbackR, fallbackG, fallbackB, fallbackA)
	local bd = cfg and cfg.backdrop
	if bd and bd.enabled == false then return nil, 0, 0, 0, 0, false end

	if bd and bd.enabled ~= false then
		local tex = bd.backgroundTexture or fallbackTexture or "Interface\\DialogFrame\\UI-DialogBox-Background"
		local r, g, b, a = normalizeGradientColor(bd.backgroundColor or { 0, 0, 0, 0.8 })
		return tex, r, g, b, a, true
	end

	return fallbackTexture, fallbackR, fallbackG, fallbackB, fallbackA, true
end

local DISCRETE_LEGACY_BORDER_TEXTURE_IDS = {
	EQOL_BORDER_RUNES = true,
	EQOL_BORDER_GOLDEN = true,
	EQOL_BORDER_MODERN = true,
	EQOL_BORDER_CLASSIC = true,
}

local function resolveDiscreteSegmentBorderStyle(cfg, forceSegmentBorders)
	if forceSegmentBorders ~= true then return false end
	local bd = cfg and cfg.backdrop
	if not bd or bd.enabled == false then return false end

	local edgeSize = tonumber(bd.edgeSize) or 0
	if edgeSize <= 0 then return false end

	local borderTexture = bd.borderTexture or "Interface\\Tooltips\\UI-Tooltip-Border"
	if DISCRETE_LEGACY_BORDER_TEXTURE_IDS[borderTexture] then borderTexture = "Interface\\Tooltips\\UI-Tooltip-Border" end
	if not borderTexture or borderTexture == "" then return false end

	local outset = tonumber(bd.outset) or 0
	local br, bg, bb, ba = normalizeGradientColor(bd.borderColor or { 0, 0, 0, 0 })
	return true, borderTexture, edgeSize, outset, br, bg, bb, ba
end

local function isGradientDebugEnabled()
	if _G and _G.EQOL_DEBUG_RB_GRADIENT == true then return true end
	return addon and addon.db and addon.db.debugResourceBarsGradient == true
end

local function formatColor(r, g, b, a) return string.format("%.2f/%.2f/%.2f/%.2f", r or 0, g or 0, b or 0, a or 1) end

local function debugGradient(bar, reason, cfg, baseR, baseG, baseB, baseA, sr, sg, sb, sa, er, eg, eb, ea, force)
	if not isGradientDebugEnabled() then return end
	local now = GetTime and GetTime() or 0
	if bar then
		bar._rbGradDebugNext = bar._rbGradDebugNext or 0
		if now < bar._rbGradDebugNext then return end
		bar._rbGradDebugNext = now + 0.75
	end
	local name = (bar and bar.GetName and bar:GetName()) or tostring(bar) or "bar"
	local cfgStart, cfgEnd = "nil", "nil"
	if cfg then
		local csr, csg, csb, csa = normalizeGradientColor(cfg.gradientStartColor)
		local cer, ceg, ceb, cea = normalizeGradientColor(cfg.gradientEndColor)
		cfgStart = formatColor(csr, csg, csb, csa)
		cfgEnd = formatColor(cer, ceg, ceb, cea)
	end
	local msg = string.format(
		"grad %s %s base=%s cfgStart=%s cfgEnd=%s outStart=%s outEnd=%s force=%s",
		reason or "?",
		name,
		formatColor(baseR, baseG, baseB, baseA),
		cfgStart,
		cfgEnd,
		formatColor(sr, sg, sb, sa),
		formatColor(er, eg, eb, ea),
		force and "1" or "0"
	)
	print("|cff00ff98Enhance QoL|r: " .. msg)
end

local function resolveGradientColors(cfg, baseR, baseG, baseB, baseA)
	local sr, sg, sb, sa = normalizeGradientColor(cfg and cfg.gradientStartColor)
	local er, eg, eb, ea = normalizeGradientColor(cfg and cfg.gradientEndColor)
	local br, bg, bb, ba = baseR or 1, baseG or 1, baseB or 1, baseA or 1
	return br * sr, bg * sg, bb * sb, (ba or 1) * (sa or 1), br * er, bg * eg, bb * eb, (ba or 1) * (ea or 1)
end

local function clearGradientState(bar)
	bar._rbGradientEnabled = nil
	bar._rbGradientTex = nil
	bar._rbGradDir = nil
	bar._rbGradSR = nil
	bar._rbGradSG = nil
	bar._rbGradSB = nil
	bar._rbGradSA = nil
	bar._rbGradER = nil
	bar._rbGradEG = nil
	bar._rbGradEB = nil
	bar._rbGradEA = nil
end

function ResourceBars.DeactivateEssenceTicker(bar)
	if not bar then return end
	if bar:GetScript("OnUpdate") == bar._essenceUpdater then bar:SetScript("OnUpdate", nil) end
	bar._essenceAnimating = false
	bar._essenceAccum = 0
	bar._essenceUpdateInterval = nil
end

function ResourceBars.ComputeEssenceFraction(bar, current, maxPower, now, powerEnum)
	if not bar then return 0, 0 end
	if current == nil or maxPower == nil then
		bar._essenceNextTick = nil
		bar._essenceFraction = 0
		return 0, 0
	end
	if issecretvalue and (issecretvalue(current) or issecretvalue(maxPower)) then
		bar._essenceNextTick = nil
		bar._essenceFraction = 0
		return 0, 0
	end
	local regen = GetPowerRegenForPowerType and GetPowerRegenForPowerType(powerEnum)
	if not regen or regen <= 0 then regen = 0.2 end
	local tickDuration = 1 / regen

	bar._essenceTickDuration = tickDuration
	bar._essenceNextTick = bar._essenceNextTick or nil
	bar._essenceLastPower = bar._essenceLastPower or current

	if current > bar._essenceLastPower then
		if current < maxPower then
			bar._essenceNextTick = now + tickDuration
		else
			bar._essenceNextTick = nil
		end
	end

	if current < maxPower and not bar._essenceNextTick then bar._essenceNextTick = now + tickDuration end

	if current >= maxPower then bar._essenceNextTick = nil end

	bar._essenceLastPower = current

	local fraction = 0
	if current < maxPower and bar._essenceNextTick and tickDuration > 0 then
		local remaining = bar._essenceNextTick - now
		if remaining < 0 then remaining = 0 end
		fraction = 1 - (remaining / tickDuration)
		if fraction < 0 then
			fraction = 0
		elseif fraction > 1 then
			fraction = 1
		end
	end

	if UnitPartialPower and current < maxPower and powerEnum then
		local partial = UnitPartialPower("player", powerEnum)
		if partial ~= nil and not (issecretvalue and issecretvalue(partial)) then
			local partialFrac = partial / 1000
			if partialFrac < 0 then
				partialFrac = 0
			elseif partialFrac > 1 then
				partialFrac = 1
			end
			fraction = partialFrac
			if tickDuration > 0 then bar._essenceNextTick = now + (1 - fraction) * tickDuration end
		end
	end

	bar._essenceFraction = fraction
	return fraction, tickDuration
end

local function hideEssenceSegments(bar)
	if not bar then return end
	if bar.essences then
		for i = 1, #bar.essences do
			local sb = bar.essences[i]
			if sb then
				sb:Hide()
				if sb._rbSegmentBg then sb._rbSegmentBg:Hide() end
				if sb._rbSegmentBorder then sb._rbSegmentBorder:Hide() end
			end
		end
	end
	if bar.essenceGapMarks then
		for i = 1, #bar.essenceGapMarks do
			local mark = bar.essenceGapMarks[i]
			if mark then mark:Hide() end
		end
	end
	bar._essenceSegments = 0
	bar._essenceVertical = nil
	bar._essenceGap = nil
	bar._essenceGapRequested = nil
	bar._essenceSegmentStyled = nil
end

function ResourceBars.LayoutEssences(bar, cfg, count, texturePath)
	if not bar then return end
	local separatedOffset = math.max(0, math.floor((tonumber(cfg and cfg.separatedOffset) or 0) + 0.5))
	local useDiscreteLayout = separatedOffset > 0 and ResourceBars.LayoutDiscreteSegments ~= nil
	if not count or count <= 0 then
		hideEssenceSegments(bar)
		if ResourceBars.HideDiscreteSegments then ResourceBars.HideDiscreteSegments(bar) end
		return
	end

	if useDiscreteLayout then
		hideEssenceSegments(bar)
		ResourceBars.LayoutDiscreteSegments(bar, cfg, count, texturePath, (cfg and cfg.showSeparator == true and ((cfg and cfg.separatorThickness) or 1)) or 0, (cfg and cfg.separatorColor) or nil)
		return
	end

	if ResourceBars.HideDiscreteSegments then ResourceBars.HideDiscreteSegments(bar) end
	bar.essences = bar.essences or {}
	local inner = bar._rbInner or bar
	local w = math.max(1, inner:GetWidth() or (bar:GetWidth() or 0))
	local h = math.max(1, inner:GetHeight() or (bar:GetHeight() or 0))
	local vertical = cfg and cfg.verticalFill == true
	local requestedGap = separatedOffset > 0 and ((ResourceBars.ResolveDiscreteSegmentGap and ResourceBars.ResolveDiscreteSegmentGap(cfg, (cfg and cfg.separatorThickness) or 0)) or separatedOffset)
		or 0
	local gap = requestedGap
	local useSegmentStyling = separatedOffset > 0
	local borderEnabled, borderTexture, borderEdgeSize, borderOutset, borderR, borderG, borderB, borderA = resolveDiscreteSegmentBorderStyle(cfg, useSegmentStyling)
	local bgTexture, bgR, bgG, bgB, bgA, bgVisible
	if useSegmentStyling then
		bgTexture, bgR, bgG, bgB, bgA, bgVisible = resolveDiscreteSegmentBackground(cfg, texturePath, 0.35, 0.35, 0.35, 0.9)
	end
	local span = vertical and h or w
	local maxGap = (count > 1) and math.max(0, math.floor((span - count) / (count - 1))) or 0
	if gap > maxGap then gap = maxGap end
	local segPrimary
	if vertical then
		local available = h - (gap * (count - 1))
		if available < count then available = count end
		segPrimary = math.max(1, math.floor(available / count + 0.5))
	else
		local available = w - (gap * (count - 1))
		if available < count then available = count end
		segPrimary = math.max(1, math.floor(available / count + 0.5))
	end

	for i = 1, count do
		local sb = bar.essences[i]
		if not sb then
			sb = CreateFrame("StatusBar", bar:GetName() .. "Essence" .. i, inner)
			sb:SetMinMaxValues(0, 1)
			bar.essences[i] = sb
		end
		if texturePath and sb._rb_tex ~= texturePath then
			sb:SetStatusBarTexture(texturePath)
			sb._rb_tex = texturePath
		end
		sb:ClearAllPoints()
		if sb:GetParent() ~= inner then sb:SetParent(inner) end
		sb:SetFrameLevel((bar:GetFrameLevel() or 1) + 1)
		if vertical then
			sb:SetWidth(w)
			sb:SetHeight(segPrimary)
			sb:SetOrientation("VERTICAL")
			if i == 1 then
				sb:SetPoint("BOTTOM", inner, "BOTTOM", 0, 0)
			else
				sb:SetPoint("BOTTOM", bar.essences[i - 1], "TOP", 0, gap)
			end
			if i == count then sb:SetPoint("TOP", inner, "TOP", 0, 0) end
		else
			sb:SetHeight(h)
			sb:SetOrientation("HORIZONTAL")
			if i == 1 then
				sb:SetPoint("LEFT", inner, "LEFT", 0, 0)
			else
				sb:SetPoint("LEFT", bar.essences[i - 1], "RIGHT", gap, 0)
			end
			if i == count then
				sb:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
			else
				sb:SetWidth(segPrimary)
			end
		end
		if not sb._rbSegmentBg then
			sb._rbSegmentBg = sb:CreateTexture(nil, "BACKGROUND")
			sb._rbSegmentBg:SetAllPoints(sb)
		end
		if useSegmentStyling and bgVisible then
			if sb._rbSegmentBgPath ~= bgTexture then
				sb._rbSegmentBg:SetTexture(bgTexture)
				sb._rbSegmentBgPath = bgTexture
			end
			local bgColorKey = tostring(bgR) .. ":" .. tostring(bgG) .. ":" .. tostring(bgB) .. ":" .. tostring(bgA)
			if sb._rbSegmentBgColorKey ~= bgColorKey then
				sb._rbSegmentBg:SetVertexColor(bgR, bgG, bgB, bgA)
				sb._rbSegmentBgColorKey = bgColorKey
			end
			if not sb._rbSegmentBg:IsShown() then sb._rbSegmentBg:Show() end
		else
			if sb._rbSegmentBg:IsShown() then sb._rbSegmentBg:Hide() end
			sb._rbSegmentBgPath = nil
			sb._rbSegmentBgColorKey = nil
		end
		if ResourceBars.ApplyDiscreteSegmentBorder then
			ResourceBars.ApplyDiscreteSegmentBorder(sb, bar, useSegmentStyling and borderEnabled, borderTexture, borderEdgeSize, borderOutset, borderR, borderG, borderB, borderA)
		end
		if not sb:IsShown() then sb:Show() end
	end
	for i = count + 1, #bar.essences do
		if bar.essences[i] then
			bar.essences[i]:Hide()
			if bar.essences[i]._rbSegmentBg then bar.essences[i]._rbSegmentBg:Hide() end
			if bar.essences[i]._rbSegmentBorder then bar.essences[i]._rbSegmentBorder:Hide() end
		end
	end
	local separatorSize = math.max(0, math.floor((tonumber(cfg and cfg.separatorThickness) or 1) + 0.5))
	local markerThickness = math.min(separatorSize, gap)
	local showSeparatorRequested = useSegmentStyling and cfg and cfg.showSeparator == true and markerThickness > 0 and count > 1
	bar.essenceGapMarks = bar.essenceGapMarks or {}
	local gapMarks = bar.essenceGapMarks
	if showSeparatorRequested then
		local sr, sg, sbc, sa = normalizeGradientColor((cfg and cfg.separatorColor) or { 1, 1, 1, 0.5 })
		local markOffset = math.floor((gap - markerThickness) * 0.5)
		local markParent = bar._rbTextOverlay or inner
		local markLayer = markParent ~= inner and "ARTWORK" or "BACKGROUND"
		for i = 1, count - 1 do
			local mark = gapMarks[i]
			if not mark then
				mark = markParent:CreateTexture(nil, markLayer, nil, 1)
				gapMarks[i] = mark
			elseif mark:GetParent() ~= markParent then
				mark:SetParent(markParent)
			end
			if mark.SetDrawLayer then mark:SetDrawLayer(markLayer, 1) end
			mark:ClearAllPoints()
			mark:SetColorTexture(sr, sg, sbc, sa)
			if vertical then
				mark:SetPoint("BOTTOM", bar.essences[i], "TOP", 0, markOffset)
				mark:SetPoint("LEFT", inner, "LEFT", 0, 0)
				mark:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
				mark:SetHeight(markerThickness)
			else
				mark:SetPoint("LEFT", bar.essences[i], "RIGHT", markOffset, 0)
				mark:SetPoint("TOP", inner, "TOP", 0, 0)
				mark:SetPoint("BOTTOM", inner, "BOTTOM", 0, 0)
				mark:SetWidth(markerThickness)
			end
			if not mark:IsShown() then mark:Show() end
		end
		for i = count, #gapMarks do
			if gapMarks[i] then gapMarks[i]:Hide() end
		end
	else
		for i = 1, #gapMarks do
			if gapMarks[i] then gapMarks[i]:Hide() end
		end
	end
	bar._essenceSegments = count
	bar._essenceVertical = vertical
	bar._essenceGap = gap
	bar._essenceGapRequested = requestedGap
	bar._essenceSegmentStyled = useSegmentStyling
end

function ResourceBars.UpdateEssenceSegments(bar, cfg, current, maxPower, fraction, fallbackColor, layoutFunc, texturePath)
	if not bar then return end
	local separatedOffset = math.max(0, math.floor((tonumber(cfg and cfg.separatedOffset) or 0) + 0.5))
	local useDiscreteLayout = separatedOffset > 0 and ResourceBars.UpdateDiscreteSegments ~= nil and ResourceBars.LayoutDiscreteSegments ~= nil
	local base = bar._lastColor or bar._baseColor or fallbackColor or { 1, 1, 1, 1 }
	if not maxPower or maxPower <= 0 then
		hideEssenceSegments(bar)
		if ResourceBars.HideDiscreteSegments then ResourceBars.HideDiscreteSegments(bar) end
		return
	end

	if useDiscreteLayout then
		hideEssenceSegments(bar)
		local displayValue = (tonumber(current) or 0) + (tonumber(fraction) or 0)
		if displayValue < 0 then
			displayValue = 0
		elseif displayValue > maxPower then
			displayValue = maxPower
		end
		ResourceBars.UpdateDiscreteSegments(
			bar,
			cfg,
			maxPower,
			displayValue,
			base,
			texturePath,
			(cfg and cfg.showSeparator == true and ((cfg and cfg.separatorThickness) or 1)) or 0,
			(cfg and cfg.separatorColor) or nil
		)
		return
	end

	if ResourceBars.HideDiscreteSegments then ResourceBars.HideDiscreteSegments(bar) end
	local expectedGap = separatedOffset > 0 and ((ResourceBars.ResolveDiscreteSegmentGap and ResourceBars.ResolveDiscreteSegmentGap(cfg, (cfg and cfg.separatorThickness) or 0)) or separatedOffset)
		or 0
	local useSegmentStyling = separatedOffset > 0
	if
		not bar.essences
		or bar._essenceSegments ~= maxPower
		or bar._essenceVertical ~= (cfg and cfg.verticalFill == true)
		or bar._essenceGapRequested ~= expectedGap
		or bar._essenceSegmentStyled ~= useSegmentStyling
	then
		if layoutFunc then layoutFunc(bar, cfg, maxPower, texturePath) end
	end
	if not bar.essences then return end

	local fullR, fullG, fullB, fullA = base[1] or 1, base[2] or 1, base[3] or 1, base[4] or 1
	local dimFactor = 0.5
	local dimR, dimG, dimB, dimA = fullR * dimFactor, fullG * dimFactor, fullB * dimFactor, fullA
	local colorKey = fullR .. ":" .. fullG .. ":" .. fullB .. ":" .. fullA

	for i = 1, maxPower do
		local sb = bar.essences[i]
		if sb then
			local state
			local value
			if i <= current then
				state = "full"
				value = 1
			elseif i == current + 1 and fraction and fraction > 0 then
				state = "partial"
				value = fraction
			else
				state = "empty"
				value = 0
			end
			sb:SetMinMaxValues(0, 1)
			sb:SetValue(value)

			local wantR, wantG, wantB, wantA
			if state == "full" then
				wantR, wantG, wantB, wantA = fullR, fullG, fullB, fullA
			else
				wantR, wantG, wantB, wantA = dimR, dimG, dimB, dimA
			end

			local needsColor = sb._essenceState ~= state or sb._essenceColorKey ~= colorKey
			sb._essenceState = state
			sb._essenceColorKey = colorKey
			if needsColor then
				if ResourceBars.SetStatusBarColorWithGradient then
					ResourceBars.SetStatusBarColorWithGradient(sb, cfg, wantR, wantG, wantB, wantA)
				else
					sb:SetStatusBarColor(wantR, wantG, wantB, wantA or 1)
				end
				sb._rbColorInitialized = true
			elseif ResourceBars.RefreshStatusBarGradient then
				ResourceBars.RefreshStatusBarGradient(sb, cfg, wantR, wantG, wantB, wantA)
			end
			if sb._rbSegmentBg and useSegmentStyling then
				local bgTexture, bgR, bgG, bgB, bgA, bgVisible = resolveDiscreteSegmentBackground(cfg, texturePath, dimR, dimG, dimB, dimA)
				if bgVisible then
					if sb._rbSegmentBgPath ~= bgTexture then
						sb._rbSegmentBg:SetTexture(bgTexture)
						sb._rbSegmentBgPath = bgTexture
					end
					local bgColorKey = tostring(bgR) .. ":" .. tostring(bgG) .. ":" .. tostring(bgB) .. ":" .. tostring(bgA)
					if sb._rbSegmentBgColorKey ~= bgColorKey then
						sb._rbSegmentBg:SetVertexColor(bgR, bgG, bgB, bgA)
						sb._rbSegmentBgColorKey = bgColorKey
					end
					if not sb._rbSegmentBg:IsShown() then sb._rbSegmentBg:Show() end
				else
					if sb._rbSegmentBg:IsShown() then sb._rbSegmentBg:Hide() end
					sb._rbSegmentBgPath = nil
					sb._rbSegmentBgColorKey = nil
				end
			elseif sb._rbSegmentBg and sb._rbSegmentBg:IsShown() then
				sb._rbSegmentBg:Hide()
			end
			if not sb:IsShown() then sb:Show() end
		end
	end
	for i = maxPower + 1, #bar.essences do
		if bar.essences[i] then bar.essences[i]:Hide() end
	end
end

local function hideDiscreteSegments(bar)
	if not bar or not bar._rbDiscreteSegments then return end
	for i = 1, #bar._rbDiscreteSegments do
		local sb = bar._rbDiscreteSegments[i]
		if sb then
			sb:Hide()
			if sb._rbSegmentBorder then sb._rbSegmentBorder:Hide() end
		end
	end
end

local function ensureDiscreteSegmentBorderFrame(bar, sb)
	if not (bar and sb) then return nil end
	local border = sb._rbSegmentBorder
	if not border then
		border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
		border:EnableMouse(false)
		sb._rbSegmentBorder = border
	end
	local strata = bar:GetFrameStrata()
	if border:GetFrameStrata() ~= strata then border:SetFrameStrata(strata) end
	local level = min((bar:GetFrameLevel() or 1) + 2, 65535)
	if border:GetFrameLevel() ~= level then border:SetFrameLevel(level) end
	return border
end

local function applyDiscreteSegmentBorder(sb, bar, enabled, texture, edgeSize, outset, r, g, b, a)
	if not sb then return end
	if enabled ~= true then
		if sb._rbSegmentBorder and sb._rbSegmentBorder:IsShown() then sb._rbSegmentBorder:Hide() end
		return
	end

	local border = ensureDiscreteSegmentBorderFrame(bar, sb)
	if not border then return end

	if border._rbOutset ~= outset then
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", sb, "TOPLEFT", -outset, outset)
		border:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", outset, -outset)
		border._rbOutset = outset
	end

	if border._rbTexture ~= texture or border._rbEdgeSize ~= edgeSize or (border.GetBackdrop and not border:GetBackdrop()) then
		border:SetBackdrop({
			bgFile = nil,
			edgeFile = texture,
			tile = false,
			edgeSize = edgeSize,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		border._rbTexture = texture
		border._rbEdgeSize = edgeSize
	end

	if border._rbR ~= r or border._rbG ~= g or border._rbB ~= b or border._rbA ~= a then
		border:SetBackdropBorderColor(r, g, b, a)
		border._rbR, border._rbG, border._rbB, border._rbA = r, g, b, a
	end

	if not border:IsShown() then border:Show() end
end

local function resolveDiscreteSeparatorSize(cfg, separatorThickness)
	local size = tonumber(separatorThickness)
	if size == nil then size = tonumber(cfg and cfg.separatorThickness) end
	if size == nil then size = 1 end
	return math.max(0, math.floor(size + 0.5))
end

local function resolveDiscreteSegmentOffset(cfg)
	local offset = tonumber(cfg and cfg.separatedOffset) or 0
	return math.max(0, math.floor(offset + 0.5))
end

local function resolveDiscreteSegmentGap(cfg, separatorThickness)
	local offset = resolveDiscreteSegmentOffset(cfg)
	if offset > 0 then return offset end
	return resolveDiscreteSeparatorSize(cfg, separatorThickness)
end

function ResourceBars.ResolveDiscreteSegmentBackground(cfg, fallbackTexture, fallbackR, fallbackG, fallbackB, fallbackA)
	return resolveDiscreteSegmentBackground(cfg, fallbackTexture, fallbackR, fallbackG, fallbackB, fallbackA)
end

function ResourceBars.ResolveDiscreteSegmentBorderStyle(cfg, forceSegmentBorders) return resolveDiscreteSegmentBorderStyle(cfg, forceSegmentBorders) end

function ResourceBars.ApplyDiscreteSegmentBorder(sb, bar, enabled, texture, edgeSize, outset, r, g, b, a) return applyDiscreteSegmentBorder(sb, bar, enabled, texture, edgeSize, outset, r, g, b, a) end

function ResourceBars.ResolveDiscreteSegmentGap(cfg, separatorThickness) return resolveDiscreteSegmentGap(cfg, separatorThickness) end

local function resolveMaelstromCarryMode(bar, cfg, count, clamped)
	if not (bar and cfg and cfg.useMaelstromCarryFill == true and cfg.useMaelstromTenStacks ~= true) then return false end
	if bar._usingMaxColor == true then return false end
	if (bar._rbType ~= "MAELSTROM_WEAPON") or count <= 0 then return false end
	local maelstromSegments = (ResourceBars and ResourceBars.MAELSTROM_WEAPON_SEGMENTS) or 5
	if count ~= maelstromSegments then return false end

	local rawStacks = tonumber(bar._rbDiscreteRawValue) or clamped or 0
	local overflow = rawStacks - count
	if overflow <= 0 then return false end
	if overflow > count then overflow = count end

	local carryR, carryG, carryB, carryA = normalizeGradientColor(bar._baseColor or { 1, 1, 1, 1 })
	return true, overflow, carryR, carryG, carryB, carryA
end

function ResourceBars.HideDiscreteSegments(bar)
	if not bar then return end
	hideDiscreteSegments(bar)
	if bar._rbDiscreteSeparatorBG then bar._rbDiscreteSeparatorBG:Hide() end
	if bar._rbDiscreteGapMarks then
		for i = 1, #bar._rbDiscreteGapMarks do
			local mark = bar._rbDiscreteGapMarks[i]
			if mark then mark:Hide() end
		end
	end
end

function ResourceBars.LayoutDiscreteSegments(bar, cfg, count, texturePath, separatorThickness, separatorColor)
	if not bar then return end
	count = tonumber(count) or 0
	if count < 1 then
		ResourceBars.HideDiscreteSegments(bar)
		bar._rbDiscreteCount = 0
		return
	end

	local inner = bar._rbInner or bar
	local w = math.max(1, inner:GetWidth() or (bar:GetWidth() or 0))
	local h = math.max(1, inner:GetHeight() or (bar:GetHeight() or 0))
	local vertical = cfg and cfg.verticalFill == true
	local reverse = cfg and cfg.reverseFill == true

	local separatorSize = resolveDiscreteSeparatorSize(cfg, separatorThickness)
	local segmentOffset = resolveDiscreteSegmentOffset(cfg)
	local requestedGap = resolveDiscreteSegmentGap(cfg, separatorThickness)
	local gap = requestedGap
	local useSegmentBorders = segmentOffset > 0 or (cfg and cfg.useGradient == true)
	local borderEnabled, borderTexture, borderEdgeSize, borderOutset, borderR, borderG, borderB, borderA = resolveDiscreteSegmentBorderStyle(cfg, useSegmentBorders)
	if count < 2 then
		requestedGap = 0
		gap = 0
	end

	local span = vertical and h or w
	local maxGap = (count > 1) and math.max(0, math.floor((span - count) / (count - 1))) or 0
	if gap > maxGap then gap = maxGap end
	local markerThickness = min(separatorSize, gap)

	local available = span - (gap * (count - 1))
	if available < count then available = count end
	local segPrimary = math.max(1, math.floor((available / count) + 0.5))

	local sr, sg, sb, sa = normalizeGradientColor(separatorColor or (cfg and cfg.separatorColor))
	bar._rbDiscreteGapMarks = bar._rbDiscreteGapMarks or {}
	local gapMarks = bar._rbDiscreteGapMarks

	bar._rbDiscreteSegments = bar._rbDiscreteSegments or {}
	local segments = bar._rbDiscreteSegments
	local nameBase = bar:GetName() or "EQOLDiscrete"
	local texPath = texturePath or "Interface\\Buttons\\WHITE8x8"

	for i = 1, count do
		local sb = segments[i]
		if not sb then
			sb = CreateFrame("StatusBar", nameBase .. "Seg" .. i, inner)
			sb:SetMinMaxValues(0, 1)
			segments[i] = sb
		end
		if sb:GetParent() ~= inner then sb:SetParent(inner) end
		sb:SetFrameLevel((bar:GetFrameLevel() or 1) + 1)
		if sb._rb_tex ~= texPath then
			sb:SetStatusBarTexture(texPath)
			sb._rb_tex = texPath
		end
		if sb.SetReverseFill then sb:SetReverseFill(reverse) end
		if not sb._rbSegmentBg then
			sb._rbSegmentBg = sb:CreateTexture(nil, "BACKGROUND")
			sb._rbSegmentBg:SetAllPoints(sb)
		end
		if sb._rbSegmentBgPath ~= texPath then
			sb._rbSegmentBg:SetTexture(texPath)
			sb._rbSegmentBgPath = texPath
		end
		sb:ClearAllPoints()
		if vertical then
			sb:SetWidth(w)
			sb:SetHeight(segPrimary)
			sb:SetOrientation("VERTICAL")
			if i == 1 then
				sb:SetPoint("BOTTOM", inner, "BOTTOM", 0, 0)
			else
				sb:SetPoint("BOTTOM", segments[i - 1], "TOP", 0, gap)
			end
			if i == count then sb:SetPoint("TOP", inner, "TOP", 0, 0) end
		else
			sb:SetHeight(h)
			sb:SetOrientation("HORIZONTAL")
			if i == 1 then
				sb:SetPoint("LEFT", inner, "LEFT", 0, 0)
			else
				sb:SetPoint("LEFT", segments[i - 1], "RIGHT", gap, 0)
			end
			if i == count then
				sb:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
			else
				sb:SetWidth(segPrimary)
			end
		end
		applyDiscreteSegmentBorder(sb, bar, borderEnabled, borderTexture, borderEdgeSize, borderOutset, borderR, borderG, borderB, borderA)
		if not sb:IsShown() then sb:Show() end
	end

	for i = count + 1, #segments do
		if segments[i] then
			segments[i]:Hide()
			if segments[i]._rbSegmentBorder then segments[i]._rbSegmentBorder:Hide() end
		end
	end

	local neededGaps = count - 1
	local showSeparatorRequested = cfg and cfg.showSeparator == true and separatorSize > 0 and count > 1
	if showSeparatorRequested and markerThickness > 0 and neededGaps > 0 then
		local markOffset = floor((gap - markerThickness) * 0.5)
		local markParent = bar._rbTextOverlay or inner
		local markLayer = markParent ~= inner and "ARTWORK" or "BACKGROUND"
		for i = 1, neededGaps do
			local mark = gapMarks[i]
			if not mark then
				mark = markParent:CreateTexture(nil, markLayer, nil, 1)
				gapMarks[i] = mark
			elseif mark:GetParent() ~= markParent then
				mark:SetParent(markParent)
			end
			if mark.SetDrawLayer then mark:SetDrawLayer(markLayer, 1) end
			mark:ClearAllPoints()
			mark:SetColorTexture(sr, sg, sb, sa)
			if vertical then
				mark:SetPoint("BOTTOM", segments[i], "TOP", 0, markOffset)
				mark:SetPoint("LEFT", inner, "LEFT", 0, 0)
				mark:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
				mark:SetHeight(markerThickness)
			else
				mark:SetPoint("LEFT", segments[i], "RIGHT", markOffset, 0)
				mark:SetPoint("TOP", inner, "TOP", 0, 0)
				mark:SetPoint("BOTTOM", inner, "BOTTOM", 0, 0)
				mark:SetWidth(markerThickness)
			end
			if not mark:IsShown() then mark:Show() end
		end
		for i = neededGaps + 1, #gapMarks do
			if gapMarks[i] then gapMarks[i]:Hide() end
		end
	else
		for i = 1, #gapMarks do
			if gapMarks[i] then gapMarks[i]:Hide() end
		end
	end

	bar._rbDiscreteCount = count
	bar._rbDiscreteVertical = vertical
	bar._rbDiscreteGapRequested = requestedGap
	bar._rbDiscreteGap = gap
	bar._rbDiscreteSeparatorSize = separatorSize
	bar._rbDiscreteShowSeparatorRequested = showSeparatorRequested
	bar._rbDiscreteReverse = reverse
end

function ResourceBars.UpdateDiscreteSegments(bar, cfg, count, value, color, texturePath, separatorThickness, separatorColor, chargedPoints)
	if not bar then return end
	count = tonumber(count) or 0
	if count < 1 then
		ResourceBars.HideDiscreteSegments(bar)
		return
	end

	local vertical = cfg and cfg.verticalFill == true
	local reverse = cfg and cfg.reverseFill == true
	local separatorSize = resolveDiscreteSeparatorSize(cfg, separatorThickness)
	local segmentOffset = resolveDiscreteSegmentOffset(cfg)
	local gap = resolveDiscreteSegmentGap(cfg, separatorThickness)
	local useSegmentBorders = segmentOffset > 0 or (cfg and cfg.useGradient == true)
	local borderEnabled, borderTexture, borderEdgeSize, borderOutset, borderR, borderG, borderB, borderA = resolveDiscreteSegmentBorderStyle(cfg, useSegmentBorders)
	if count < 2 then gap = 0 end
	local showSeparatorRequested = cfg and cfg.showSeparator == true and separatorSize > 0 and count > 1

	if
		not bar._rbDiscreteSegments
		or bar._rbDiscreteCount ~= count
		or bar._rbDiscreteVertical ~= vertical
		or bar._rbDiscreteGapRequested ~= gap
		or bar._rbDiscreteReverse ~= reverse
		or bar._rbDiscreteSeparatorSize ~= separatorSize
		or bar._rbDiscreteShowSeparatorRequested ~= showSeparatorRequested
	then
		ResourceBars.LayoutDiscreteSegments(bar, cfg, count, texturePath, separatorThickness, separatorColor)
	end

	local segments = bar._rbDiscreteSegments
	if not segments then return end
	local parentTex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if parentTex then parentTex:SetAlpha(0) end

	local baseR, baseG, baseB, baseA = normalizeGradientColor(color)
	local dimFactor = 0.35
	local dimR, dimG, dimB, dimA = baseR * dimFactor, baseG * dimFactor, baseB * dimFactor, (baseA or 1) * 0.9
	local fillColorKey = baseR .. ":" .. baseG .. ":" .. baseB .. ":" .. baseA
	local texPath = texturePath or "Interface\\Buttons\\WHITE8x8"
	local segmentBgPath, segmentBgR, segmentBgG, segmentBgB, segmentBgA, segmentBgVisible = resolveDiscreteSegmentBackground(cfg, texPath, dimR, dimG, dimB, dimA)
	local bgColorKey = segmentBgR .. ":" .. segmentBgG .. ":" .. segmentBgB .. ":" .. segmentBgA
	local clamped = tonumber(value) or 0
	if clamped < 0 then
		clamped = 0
	elseif clamped > count then
		clamped = count
	end
	local useMaelstromCarryFill, carryOverflow, carryR, carryG, carryB, carryA = resolveMaelstromCarryMode(bar, cfg, count, clamped)
	if useMaelstromCarryFill then clamped = count end
	local chargedStyleActive = bar and bar._rbType == "COMBO_POINTS" and addon and addon.variables and addon.variables.unitClass == "ROGUE" and (cfg and cfg.useChargedComboStyling ~= false)
	local chargedFillActive = chargedStyleActive and (cfg.chargedComboAffectFill ~= false)
	local chargedBgActive = chargedStyleActive and (cfg.chargedComboAffectBackground ~= false)
	local chargedUseCustomFillColor = chargedFillActive and cfg.chargedComboUseCustomFillColor == true
	local chargedUseCustomBackgroundColor = chargedBgActive and cfg.chargedComboUseCustomBackgroundColor == true
	local function clamp01(value, defaultValue)
		local n = tonumber(value)
		if n == nil then n = defaultValue end
		if n < 0 then
			n = 0
		elseif n > 1 then
			n = 1
		end
		return n
	end
	local chargedFillLighten = clamp01(cfg and cfg.chargedComboFillLighten, 0.35)
	local chargedFillAlphaBoost = clamp01(cfg and cfg.chargedComboFillAlphaBoost, 0.10)
	local chargedBackgroundLighten = clamp01(cfg and cfg.chargedComboBackgroundLighten, 0.30)
	local chargedBackgroundAlphaBoost = clamp01(cfg and cfg.chargedComboBackgroundAlphaBoost, 0.10)
	local chargedFillCustomR, chargedFillCustomG, chargedFillCustomB, chargedFillCustomA
	if chargedUseCustomFillColor then
		chargedFillCustomR, chargedFillCustomG, chargedFillCustomB, chargedFillCustomA = normalizeGradientColor((cfg and cfg.chargedComboFillColor) or { 1.0, 0.95, 0.45, 1.0 })
	end
	local chargedBgCustomR, chargedBgCustomG, chargedBgCustomB, chargedBgCustomA
	if chargedUseCustomBackgroundColor then
		chargedBgCustomR, chargedBgCustomG, chargedBgCustomB, chargedBgCustomA = normalizeGradientColor((cfg and cfg.chargedComboBackgroundColor) or { 0.75, 0.60, 0.25, 0.75 })
	end

	for physicalIndex = 1, count do
		local sb = segments[physicalIndex]
		if sb then
			local logicalIndex = reverse and (count - physicalIndex + 1) or physicalIndex
			local isChargedPoint = type(chargedPoints) == "table" and chargedPoints[logicalIndex] == true
			local segmentValue = clamped - (logicalIndex - 1)
			if segmentValue < 0 then
				segmentValue = 0
			elseif segmentValue > 1 then
				segmentValue = 1
			end

			if sb._rb_tex ~= texPath then
				sb:SetStatusBarTexture(texPath)
				sb._rb_tex = texPath
			end
			if sb.SetReverseFill then sb:SetReverseFill(reverse) end
			applyDiscreteSegmentBorder(sb, bar, borderEnabled, borderTexture, borderEdgeSize, borderOutset, borderR, borderG, borderB, borderA)
			if sb._rbSegmentBg then
				if segmentBgVisible then
					local bgR, bgG, bgB, bgA = segmentBgR, segmentBgG, segmentBgB, segmentBgA
					local segmentBgColorKey = bgColorKey
					if isChargedPoint and chargedBgActive then
						if chargedUseCustomBackgroundColor then
							bgR, bgG, bgB, bgA = chargedBgCustomR, chargedBgCustomG, chargedBgCustomB, chargedBgCustomA
						else
							bgR = min(1, bgR + (1 - bgR) * chargedBackgroundLighten)
							bgG = min(1, bgG + (1 - bgG) * chargedBackgroundLighten)
							bgB = min(1, bgB + (1 - bgB) * chargedBackgroundLighten)
							bgA = min(1, (bgA or 1) + chargedBackgroundAlphaBoost)
						end
						segmentBgColorKey = bgR .. ":" .. bgG .. ":" .. bgB .. ":" .. bgA .. ":charged"
					end
					if sb._rbSegmentBgPath ~= segmentBgPath then
						sb._rbSegmentBg:SetTexture(segmentBgPath)
						sb._rbSegmentBgPath = segmentBgPath
					end
					if sb._rbSegmentBgColorKey ~= segmentBgColorKey then
						sb._rbSegmentBg:SetVertexColor(bgR, bgG, bgB, bgA)
						sb._rbSegmentBgColorKey = segmentBgColorKey
					end
					if not sb._rbSegmentBg:IsShown() then sb._rbSegmentBg:Show() end
				else
					if sb._rbSegmentBg:IsShown() then sb._rbSegmentBg:Hide() end
					sb._rbSegmentBgPath = nil
					sb._rbSegmentBgColorKey = nil
				end
			end
			local segmentR, segmentG, segmentB, segmentA = baseR, baseG, baseB, baseA
			local segmentColorKey = fillColorKey
			if useMaelstromCarryFill and logicalIndex > carryOverflow then
				segmentR, segmentG, segmentB, segmentA = carryR, carryG, carryB, carryA
				segmentColorKey = segmentR .. ":" .. segmentG .. ":" .. segmentB .. ":" .. segmentA
			end
			if isChargedPoint and chargedFillActive then
				if chargedUseCustomFillColor then
					segmentR, segmentG, segmentB, segmentA = chargedFillCustomR, chargedFillCustomG, chargedFillCustomB, chargedFillCustomA
				else
					segmentR = min(1, segmentR + (1 - segmentR) * chargedFillLighten)
					segmentG = min(1, segmentG + (1 - segmentG) * chargedFillLighten)
					segmentB = min(1, segmentB + (1 - segmentB) * chargedFillLighten)
					segmentA = min(1, (segmentA or 1) + chargedFillAlphaBoost)
				end
			end
			segmentColorKey = segmentR .. ":" .. segmentG .. ":" .. segmentB .. ":" .. segmentA
			if sb._rbSegmentFillColorKey ~= segmentColorKey then
				if ResourceBars.SetStatusBarColorWithGradient then
					ResourceBars.SetStatusBarColorWithGradient(sb, cfg, segmentR, segmentG, segmentB, segmentA)
				else
					sb:SetStatusBarColor(segmentR, segmentG, segmentB, segmentA or 1)
				end
				sb._rbSegmentFillColorKey = segmentColorKey
			elseif ResourceBars.RefreshStatusBarGradient then
				ResourceBars.RefreshStatusBarGradient(sb, cfg, segmentR, segmentG, segmentB, segmentA)
			end

			sb:SetMinMaxValues(0, 1)
			sb:SetValue(segmentValue)
			if not sb:IsShown() then sb:Show() end
		end
	end

	for i = count + 1, #segments do
		if segments[i] then
			segments[i]:Hide()
			if segments[i]._rbSegmentBorder then segments[i]._rbSegmentBorder:Hide() end
		end
	end
end

function ResourceBars.ApplyBarGradient(bar, cfg, baseR, baseG, baseB, baseA, force)
	if not bar or not cfg or cfg.useGradient ~= true then return false end
	local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not tex or not tex.SetGradient then return false end
	local sr, sg, sb, sa, er, eg, eb, ea = resolveGradientColors(cfg, baseR, baseG, baseB, baseA)
	local direction = (cfg and cfg.gradientDirection) or "VERTICAL"
	if type(direction) == "string" then direction = direction:upper() end
	if direction ~= "HORIZONTAL" then direction = "VERTICAL" end
	if
		not force
		and bar._rbGradientEnabled
		and bar._rbGradientTex == tex
		and bar._rbGradDir == direction
		and bar._rbGradSR == sr
		and bar._rbGradSG == sg
		and bar._rbGradSB == sb
		and bar._rbGradSA == sa
		and bar._rbGradER == er
		and bar._rbGradEG == eg
		and bar._rbGradEB == eb
		and bar._rbGradEA == ea
	then
		return true
	end
	tex:SetGradient(direction, CreateColor(sr, sg, sb, sa), CreateColor(er, eg, eb, ea))
	debugGradient(bar, "apply", cfg, baseR, baseG, baseB, baseA, sr, sg, sb, sa, er, eg, eb, ea, force)
	bar._rbGradientEnabled = true
	bar._rbGradientTex = tex
	bar._rbGradDir = direction
	bar._rbGradSR, bar._rbGradSG, bar._rbGradSB, bar._rbGradSA = sr, sg, sb, sa
	bar._rbGradER, bar._rbGradEG, bar._rbGradEB, bar._rbGradEA = er, eg, eb, ea
	return true
end

function ResourceBars.SetStatusBarColorWithGradient(bar, cfg, r, g, b, a)
	if not bar then return end
	local alpha = a or 1
	bar:SetStatusBarColor(r, g, b, alpha)
	bar._lastColor = bar._lastColor or {}
	bar._lastColor[1], bar._lastColor[2], bar._lastColor[3], bar._lastColor[4] = r, g, b, alpha
	if cfg and cfg.useGradient == true then
		ResourceBars.ApplyBarGradient(bar, cfg, r, g, b, alpha, true)
	elseif bar._rbGradientEnabled then
		debugGradient(bar, "clear", cfg, r, g, b, a)
		clearGradientState(bar)
	end
end

function ResourceBars.RefreshStatusBarGradient(bar, cfg, r, g, b, a)
	if not bar then return end
	if cfg and cfg.useGradient == true then
		local br, bg, bb, ba = r, g, b, a
		if br == nil then
			if bar._lastColor then
				br, bg, bb, ba = bar._lastColor[1], bar._lastColor[2], bar._lastColor[3], bar._lastColor[4]
			elseif bar.GetStatusBarColor then
				br, bg, bb, ba = bar:GetStatusBarColor()
			end
		end
		ResourceBars.ApplyBarGradient(bar, cfg, br or 1, bg or 1, bb or 1, ba or 1, true)
	elseif bar._rbGradientEnabled then
		local br, bg, bb, ba = r, g, b, a
		if br == nil then
			if bar._lastColor then
				br, bg, bb, ba = bar._lastColor[1], bar._lastColor[2], bar._lastColor[3], bar._lastColor[4]
			elseif bar.GetStatusBarColor then
				br, bg, bb, ba = bar:GetStatusBarColor()
			end
		end
		if br ~= nil then bar:SetStatusBarColor(br, bg or 1, bb or 1, ba or 1) end
		clearGradientState(bar)
	end
end

function ResourceBars.ResolveRuneCooldownColor(cfg)
	local fallback = 0.35
	local c = cfg and cfg.runeCooldownColor
	return c and (c[1] or fallback) or fallback, c and (c[2] or fallback) or fallback, c and (c[3] or fallback) or fallback, c and (c[4] or 1) or 1
end
