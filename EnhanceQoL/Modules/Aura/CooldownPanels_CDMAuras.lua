local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.CooldownPanels = addon.Aura.CooldownPanels or {}
local CooldownPanels = addon.Aura.CooldownPanels
local Helper = CooldownPanels.helper or {}
local Api = Helper.Api or {}
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")

CooldownPanels.CDMAuras = CooldownPanels.CDMAuras or {}
local CDMAuras = CooldownPanels.CDMAuras

local ENTRY_TYPE = "CDM_AURA"
local ICON_VIEWER = "BuffIconCooldownViewer"
local BAR_VIEWER = "BuffBarCooldownViewer"
local SOURCE_ICON = "icon"
local SOURCE_BAR = "bar"
local IMPORT_SOURCE_ICON = "BUFF_ICON"
local IMPORT_SOURCE_BAR = "BUFF_BAR"

local function isSecretValue(value) return Api.issecretvalue and Api.issecretvalue(value) end

local function showErrorMessage(msg)
	if UIErrorsFrame and msg then UIErrorsFrame:AddMessage(msg, 1, 0.2, 0.2, 1) end
end

local function createTrackedUnitBuckets()
	return {
		player = {},
		target = {},
	}
end

local function normalizeTrackedUnit(unit)
	if unit == "player" or unit == "target" then return unit end
	return nil
end

local function getRuntime()
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime.cdmAuras
	if runtime then
		if not (runtime.auraEntries and runtime.auraEntries.player and runtime.auraEntries.target) then runtime.auraEntries = createTrackedUnitBuckets() end
		if not (runtime.unitPanels and runtime.unitPanels.player and runtime.unitPanels.target) then runtime.unitPanels = createTrackedUnitBuckets() end
		return runtime
	end
	runtime = {
		scan = nil,
		entryStates = {},
		auraEntries = createTrackedUnitBuckets(),
		unitPanels = createTrackedUnitBuckets(),
		frameEntries = {},
		hookedFrames = {},
		targetEpoch = 0,
	}
	CooldownPanels.runtime.cdmAuras = runtime
	return runtime
end

local function getEntryKey(panelId, entryId) return Helper.GetEntryKey(panelId, entryId) end

local function requestPanelRefresh(panelId)
	if not panelId then return end
	if CooldownPanels.RequestPanelRefresh then
		CooldownPanels:RequestPanelRefresh(panelId)
	elseif CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) and CooldownPanels.RefreshPanel then
		CooldownPanels:RefreshPanel(panelId)
	end
end

local function getPanelEntry(panelId, entryId)
	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	local entry = panel and panel.entries and panel.entries[entryId] or nil
	return panel, entry
end

local function isValidCooldownID(value)
	if type(value) == "number" then return value > 0 end
	if type(value) == "string" then return value ~= "" end
	return false
end

local function cooldownIDsEqual(a, b)
	if a == b then return true end
	if not (isValidCooldownID(a) and isValidCooldownID(b)) then return false end
	return tostring(a) == tostring(b)
end

local function normalizeSourceType(value)
	if value == SOURCE_BAR then return SOURCE_BAR end
	return SOURCE_ICON
end

local function getImportSourceType(sourceKind)
	if sourceKind == IMPORT_SOURCE_BAR then return SOURCE_BAR end
	if sourceKind == IMPORT_SOURCE_ICON then return SOURCE_ICON end
	return nil
end

local function hasAuraInstanceID(value) return type(value) == "number" and not isSecretValue(value) and value > 0 end

local function resolveAuraStackCount(auraUnit, auraInstanceID, applications)
	local displayCount = applications
	if auraUnit and auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
		local count = C_UnitAuras.GetAuraApplicationDisplayCount(auraUnit, auraInstanceID, 2, 1000)
		if count ~= nil then displayCount = count end
	end
	if displayCount == nil then return nil end
	if isSecretValue(displayCount) then return displayCount end
	if type(displayCount) == "number" then
		if displayCount > 1 then return tostring(displayCount) end
		return nil
	end
	if type(displayCount) == "string" and displayCount ~= "" then return displayCount end
	return nil
end

local function getSpellName(spellId)
	if not spellId then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local name = C_Spell.GetSpellName(spellId)
		if name and name ~= "" then return name end
	end
	if GetSpellInfo then
		local name = GetSpellInfo(spellId)
		if name and name ~= "" then return name end
	end
	return nil
end

local function getSpellTexture(spellId)
	if not spellId then return nil end
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

local isUsableSpellID

local function getAuraInstanceID(auraData)
	local auraInstanceID = auraData and auraData.auraInstanceID
	if not hasAuraInstanceID(auraInstanceID) then return nil end
	return auraInstanceID
end

local function getCooldownIDFromFrame(frame, sourceType)
	if not frame then return nil end
	local cooldownID = frame.cooldownID
	if not cooldownID and frame.cooldownInfo then cooldownID = frame.cooldownInfo.cooldownID end
	if not cooldownID and sourceType == SOURCE_BAR and frame.Icon and frame.Icon.cooldownID then cooldownID = frame.Icon.cooldownID end
	if not isValidCooldownID(cooldownID) then return nil end
	return cooldownID
end

local function getFrameIconTexture(frame)
	if not frame then return nil end
	if frame.Icon and frame.Icon.Icon and frame.Icon.Icon.GetTexture then
		local texture = frame.Icon.Icon:GetTexture()
		if texture then return texture end
	end
	if frame.Icon and frame.Icon.GetTexture then
		local texture = frame.Icon:GetTexture()
		if texture then return texture end
	end
	if frame.GetTexture then
		local texture = frame:GetTexture()
		if texture then return texture end
	end
	return nil
end

local function getFrameCooldownValues(frame)
	if not (frame and frame.GetCooldownValues) then return nil, nil, nil, nil end
	local ok, expirationTime, duration, timeMod, paused = pcall(frame.GetCooldownValues, frame)
	if not ok then return nil, nil, nil, nil end
	return expirationTime, duration, timeMod, paused
end

local function getFrameApplications(frame)
	if not (frame and frame.GetApplicationsText) then return nil end
	local ok, applications = pcall(frame.GetApplicationsText, frame)
	if not ok or applications == "" then return nil end
	return applications
end

local function getTotemSlot(frame)
	if not frame then return nil end
	if frame.preferredTotemUpdateSlot then return frame.preferredTotemUpdateSlot end
	if frame.totemData then
		local ok, slot = pcall(function() return frame.totemData.slot end)
		if ok then return slot end
	end
	return nil
end

local function getTotemCooldownInfo(frame)
	if not (frame and frame.totemData ~= nil and GetTotemInfo) then return nil, nil, nil end
	local slot = getTotemSlot(frame)
	if not slot then return nil, nil, nil end
	local _, _, startTime, duration = GetTotemInfo(slot)
	if not duration then return nil, nil, nil end
	local modRate = 1
	local okMod, rawModRate = pcall(function() return frame.totemData and frame.totemData.modRate end)
	if okMod and rawModRate then modRate = rawModRate end
	return startTime, duration, modRate
end

isUsableSpellID = function(value) return type(value) == "number" and not isSecretValue(value) and value > 0 end

local function getFirstUsableSpellID(...)
	for i = 1, select("#", ...) do
		local spellID = select(i, ...)
		if isUsableSpellID(spellID) then return spellID end
	end
	return nil
end

local function getCooldownViewerInfo(cooldownID)
	if not (type(cooldownID) == "number" and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return nil end
	return C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
end

local function resolveSpellFromCooldownID(cooldownID, frame)
	local spellID = nil
	local buffName = nil
	local iconTextureID

	local frameInfo = frame and frame.cooldownInfo or nil
	local info = getCooldownViewerInfo(cooldownID) or frameInfo
	if info then
		local auraSpellID = frame and frame.auraSpellID or nil
		local linkedSpellID = frameInfo and frameInfo.linkedSpellID or nil
		local baseSpellID = info.spellID
		local overrideSpellID = info.overrideSpellID
		local overrideTooltipSpellID = info.overrideTooltipSpellID
		local linkedSpellIDs = info.linkedSpellIDs
		local firstLinkedSpellID = linkedSpellIDs and linkedSpellIDs[1] or nil
		local displaySpellID = getFirstUsableSpellID(auraSpellID, linkedSpellID, overrideTooltipSpellID, firstLinkedSpellID, overrideSpellID, baseSpellID)
		spellID = spellID or displaySpellID or getFirstUsableSpellID(overrideTooltipSpellID, firstLinkedSpellID, overrideSpellID, baseSpellID)
		if spellID then
			buffName = getSpellName(spellID)
			iconTextureID = getSpellTexture(spellID)
		end
		if (not buffName or not iconTextureID) and isUsableSpellID(overrideTooltipSpellID) then
			buffName = buffName or getSpellName(overrideTooltipSpellID)
			iconTextureID = iconTextureID or getSpellTexture(overrideTooltipSpellID)
		end
		if (not buffName or not iconTextureID) and isUsableSpellID(overrideSpellID) then
			buffName = buffName or getSpellName(overrideSpellID)
			iconTextureID = iconTextureID or getSpellTexture(overrideSpellID)
		end
		if (not buffName or not iconTextureID) and isUsableSpellID(baseSpellID) then
			buffName = buffName or getSpellName(baseSpellID)
			iconTextureID = iconTextureID or getSpellTexture(baseSpellID)
		end
	end

	iconTextureID = iconTextureID or getFrameIconTexture(frame)
	return spellID, buffName, iconTextureID
end

local function ensureScanInfo(scan, cooldownID)
	local info = scan.byCooldownID[cooldownID]
	if info then return info end
	info = {
		cooldownID = cooldownID,
		availableSources = {},
		sourceType = nil,
		sourceViewer = nil,
		iconFrame = nil,
		barFrame = nil,
		spellID = nil,
		buffName = nil,
		iconTextureID = nil,
		isActive = false,
	}
	scan.byCooldownID[cooldownID] = info
	return info
end

local function mergeScanInfo(primary, duplicate)
	if not (primary and duplicate) or primary == duplicate then return primary end
	primary.availableSources = primary.availableSources or {}
	for sourceType in pairs(duplicate.availableSources or {}) do
		primary.availableSources[sourceType] = true
	end
	if duplicate.iconFrame and not primary.iconFrame then primary.iconFrame = duplicate.iconFrame end
	if duplicate.barFrame and not primary.barFrame then primary.barFrame = duplicate.barFrame end
	if duplicate.auraUnit and not primary.auraUnit then primary.auraUnit = duplicate.auraUnit end
	if duplicate.spellID and not primary.spellID then primary.spellID = duplicate.spellID end
	if duplicate.buffName and (not primary.buffName or primary.buffName == "") then primary.buffName = duplicate.buffName end
	if duplicate.iconTextureID and not primary.iconTextureID then primary.iconTextureID = duplicate.iconTextureID end
	if duplicate.isActive then primary.isActive = true end
	if primary.sourceType ~= SOURCE_ICON and duplicate.sourceType == SOURCE_ICON then
		primary.sourceType = SOURCE_ICON
		primary.sourceViewer = ICON_VIEWER
	elseif not primary.sourceType and duplicate.sourceType then
		primary.sourceType = duplicate.sourceType
		primary.sourceViewer = duplicate.sourceViewer
	end
	return primary
end

local function getTrackedSpellKey(info)
	local spellID = tonumber(info and info.spellID)
	if not spellID then return nil end
	local auraUnit = normalizeTrackedUnit(info and info.auraUnit) or ""
	return auraUnit .. ":" .. tostring(spellID)
end

local function seedScanFromCategorySet(scan, category, sourceType)
	if not (scan and category and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then return false end
	local ok, cooldownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
	if not ok or type(cooldownIDs) ~= "table" then return false end
	local seeded = false
	for _, cooldownID in ipairs(cooldownIDs) do
		if isValidCooldownID(cooldownID) then
			seeded = true
			local info = ensureScanInfo(scan, cooldownID)
			info.availableSources[sourceType] = true
			if sourceType == SOURCE_ICON or not info.sourceType then
				info.sourceType = sourceType
				info.sourceViewer = sourceType == SOURCE_BAR and BAR_VIEWER or ICON_VIEWER
			end
			local spellID, buffName, iconTextureID = resolveSpellFromCooldownID(cooldownID, nil)
			if spellID and not info.spellID then info.spellID = spellID end
			if buffName and (not info.buffName or info.buffName == "") then info.buffName = buffName end
			if iconTextureID and not info.iconTextureID then info.iconTextureID = iconTextureID end
		end
	end
	return seeded
end

local function collectFrame(scan, frame, sourceType, viewerName, seenFrames)
	if not frame or seenFrames[frame] then return end
	local cooldownID = getCooldownIDFromFrame(frame, sourceType)
	if not cooldownID then return end
	seenFrames[frame] = true

	local info = scan.byCooldownID[cooldownID]
	if not info then
		if scan.hasAuthoritativeSeed then return end
		info = ensureScanInfo(scan, cooldownID)
	end
	info.availableSources[sourceType] = true
	if sourceType == SOURCE_ICON then
		info.iconFrame = frame
	else
		info.barFrame = frame
	end
	if sourceType == SOURCE_ICON or not info.sourceType then
		info.sourceType = sourceType
		info.sourceViewer = viewerName
	end
	local auraUnit = nil
	if type(frame.GetAuraDataUnit) == "function" then
		local ok, frameAuraUnit = pcall(frame.GetAuraDataUnit, frame)
		if ok then auraUnit = normalizeTrackedUnit(frameAuraUnit) end
	end
	if not auraUnit then auraUnit = normalizeTrackedUnit(frame.auraDataUnit) end
	if auraUnit and not info.auraUnit then info.auraUnit = auraUnit end

	local spellID, buffName, iconTextureID = resolveSpellFromCooldownID(cooldownID, frame)
	if spellID and not info.spellID then info.spellID = spellID end
	if buffName and (not info.buffName or info.buffName == "") then info.buffName = buffName end
	if iconTextureID and not info.iconTextureID then info.iconTextureID = iconTextureID end
	if hasAuraInstanceID(frame.auraInstanceID) or frame.totemData ~= nil then info.isActive = true end
end

local function collectFramesFromContainer(scan, container, sourceType, viewerName, seenFrames)
	if not container then return end
	if container.GetChildren then
		local children = { container:GetChildren() }
		for _, child in ipairs(children) do
			collectFrame(scan, child, sourceType, viewerName, seenFrames)
		end
	end

	local layoutChildren = container.layoutChildren
	if type(layoutChildren) == "table" then
		if #layoutChildren > 0 then
			for i = 1, #layoutChildren do
				collectFrame(scan, layoutChildren[i], sourceType, viewerName, seenFrames)
			end
		else
			local numericKeys = {}
			for key in pairs(layoutChildren) do
				if type(key) == "number" then numericKeys[#numericKeys + 1] = key end
			end
			table.sort(numericKeys)
			for _, key in ipairs(numericKeys) do
				collectFrame(scan, layoutChildren[key], sourceType, viewerName, seenFrames)
			end
		end
	end
end

local function collectViewer(scan, viewerName, sourceType, seenFrames)
	local viewer = _G[viewerName]
	if not viewer then return end
	local containers = {
		viewer,
		viewer.oldGridSettings,
		viewer.gridSettings,
		viewer.currentGridSettings,
		viewer.settings,
	}
	for i = 1, #containers do
		collectFramesFromContainer(scan, containers[i], sourceType, viewerName, seenFrames)
	end
end

local function sortTrackedBuffs(a, b)
	local leftName = tostring(a and a.buffName or ""):lower()
	local rightName = tostring(b and b.buffName or ""):lower()
	if leftName ~= rightName then return leftName < rightName end
	return tostring(a and a.cooldownID or "") < tostring(b and b.cooldownID or "")
end

function CDMAuras:InvalidateScan()
	local runtime = getRuntime()
	runtime.scan = nil
end

function CDMAuras:ScanTrackedBuffs(force)
	local runtime = getRuntime()
	if not force and runtime.scan and runtime.scan.list and runtime.scan.byCooldownID then return runtime.scan.list, runtime.scan.byCooldownID, runtime.scan.bySpellID end

	local scan = {
		list = {},
		byCooldownID = {},
		bySpellID = {},
		hasAuthoritativeSeed = false,
	}
	local seenFrames = {}

	local trackedBuffCategory = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff or nil
	local trackedBarCategory = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar or nil
	if seedScanFromCategorySet(scan, trackedBuffCategory, SOURCE_ICON) then scan.hasAuthoritativeSeed = true end
	if seedScanFromCategorySet(scan, trackedBarCategory, SOURCE_BAR) then scan.hasAuthoritativeSeed = true end

	collectViewer(scan, ICON_VIEWER, SOURCE_ICON, seenFrames)
	collectViewer(scan, BAR_VIEWER, SOURCE_BAR, seenFrames)

	local mergedBySpellID = {}
	for cooldownID, info in pairs(scan.byCooldownID) do
		local spellKey = getTrackedSpellKey(info)
		if spellKey then
			local primary = mergedBySpellID[spellKey]
			if primary and primary ~= info then
				mergeScanInfo(primary, info)
				scan.byCooldownID[cooldownID] = primary
			else
				mergedBySpellID[spellKey] = info
			end
		end
	end

	local seenInfo = {}
	for cooldownID, info in pairs(scan.byCooldownID) do
		if not seenInfo[info] then
			seenInfo[info] = true
			if not info.spellID then
				local spellID, buffName, iconTextureID = resolveSpellFromCooldownID(cooldownID, info.iconFrame or info.barFrame)
				if spellID and not info.spellID then info.spellID = spellID end
				if buffName and not info.buffName then info.buffName = buffName end
				if iconTextureID and not info.iconTextureID then info.iconTextureID = iconTextureID end
			end
			info.spellID = tonumber(info.spellID)
			info.buffName = info.buffName or getSpellName(info.spellID) or tostring(cooldownID)
			info.iconTextureID = info.iconTextureID or getSpellTexture(info.spellID) or Helper.PREVIEW_ICON
			info.sourceType = normalizeSourceType(info.sourceType or (info.availableSources[SOURCE_ICON] and SOURCE_ICON or SOURCE_BAR))
			info.sourceViewer = info.sourceType == SOURCE_BAR and BAR_VIEWER or ICON_VIEWER
			if info.spellID and not scan.bySpellID[info.spellID] then scan.bySpellID[info.spellID] = info end
			scan.list[#scan.list + 1] = info
		end
	end

	table.sort(scan.list, sortTrackedBuffs)
	runtime.scan = scan
	return scan.list, scan.byCooldownID, scan.bySpellID
end

local function clearAuraMapping(runtime, key, state, clearTrackedAura)
	local auraID = state and state.mappedAuraInstanceID
	local auraUnit = normalizeTrackedUnit(state and state.mappedAuraUnit)
	if auraID and auraUnit then
		local auraEntries = runtime.auraEntries[auraUnit]
		local mapped = auraEntries and auraEntries[auraID]
		if mapped then
			mapped[key] = nil
			if not next(mapped) then auraEntries[auraID] = nil end
		end
		state.mappedAuraInstanceID = nil
		state.mappedAuraUnit = nil
	end
	if clearTrackedAura and state then
		state.trackedAuraInstanceID = nil
		state.trackedAuraUnit = nil
		state.pandemicActive = nil
		if auraUnit == "target" or normalizeTrackedUnit(state.trackUnit) == "target" then state.targetAuraEpoch = nil end
	end
end

local function registerAuraMapping(runtime, key, state, auraID, auraUnit)
	if not state then return end
	auraUnit = normalizeTrackedUnit(auraUnit)
	if auraID and state.mappedAuraInstanceID == auraID and state.mappedAuraUnit == auraUnit then return end
	clearAuraMapping(runtime, key, state, false)
	if not (auraID and auraUnit) then return end
	runtime.auraEntries[auraUnit][auraID] = runtime.auraEntries[auraUnit][auraID] or {}
	runtime.auraEntries[auraUnit][auraID][key] = true
	state.mappedAuraInstanceID = auraID
	state.mappedAuraUnit = auraUnit
end

local function unregisterFrameBinding(runtime, key, frame)
	if not (runtime and key and frame) then return end
	local keys = runtime.frameEntries[frame]
	if not keys then return end
	keys[key] = nil
	if not next(keys) then runtime.frameEntries[frame] = nil end
end

local function hookFrame(frame)
	if not frame then return end
	local runtime = getRuntime()
	if runtime.hookedFrames[frame] then return end
	runtime.hookedFrames[frame] = true

	if frame.SetAuraInstanceInfo then hooksecurefunc(frame, "SetAuraInstanceInfo", function(self) CDMAuras:HandleFrameAuraMutation(self, false) end) end
	if frame.ClearAuraInstanceInfo then hooksecurefunc(frame, "ClearAuraInstanceInfo", function(self) CDMAuras:HandleFrameAuraMutation(self, true) end) end
	if frame.ShowPandemicStateFrame then hooksecurefunc(frame, "ShowPandemicStateFrame", function(self) CDMAuras:HandleFramePandemicStateChanged(self, true) end) end
	if frame.HidePandemicStateFrame then hooksecurefunc(frame, "HidePandemicStateFrame", function(self) CDMAuras:HandleFramePandemicStateChanged(self, false) end) end
end

local function registerFrameBinding(runtime, key, frame)
	if not (runtime and key and frame) then return end
	local keys = runtime.frameEntries[frame]
	if not keys then
		keys = {}
		runtime.frameEntries[frame] = keys
	end
	keys[key] = true
	hookFrame(frame)
end

local function clearEntryState(key, state, clearTrackedAura)
	if not state then return end
	local runtime = getRuntime()
	clearAuraMapping(runtime, key, state, clearTrackedAura == true)
	if state.boundFrame then
		unregisterFrameBinding(runtime, key, state.boundFrame)
		state.boundFrame = nil
	end
	state.boundSource = nil
	state.lastActive = nil
	state.pandemicActive = nil
	state.targetAuraEpoch = nil
end

function CDMAuras:SweepInvalidStates()
	local runtime = getRuntime()
	local valid = {}
	local root = CooldownPanels.GetRoot and CooldownPanels:GetRoot() or nil
	if root and root.panels then
		for panelId, panel in pairs(root.panels) do
			for entryId, entry in pairs(panel and panel.entries or {}) do
				if entry and entry.type == ENTRY_TYPE then valid[getEntryKey(panelId, entryId)] = true end
			end
		end
	end
	for key, state in pairs(runtime.entryStates) do
		if not valid[key] then
			clearEntryState(key, state, true)
			runtime.entryStates[key] = nil
		end
	end
	for _, auraEntries in pairs(runtime.auraEntries) do
		for auraID, mapped in pairs(auraEntries) do
			for key in pairs(mapped) do
				if not valid[key] then mapped[key] = nil end
			end
			if not next(mapped) then auraEntries[auraID] = nil end
		end
	end
end

local function getEntryTrackedUnit(scanInfo, state, frame)
	local trackedUnit = nil
	if frame and type(frame.GetAuraDataUnit) == "function" then
		local ok, auraUnit = pcall(frame.GetAuraDataUnit, frame)
		if ok then trackedUnit = normalizeTrackedUnit(auraUnit) end
	end
	if not trackedUnit and frame then trackedUnit = normalizeTrackedUnit(frame.auraDataUnit) end
	if not trackedUnit and scanInfo then trackedUnit = normalizeTrackedUnit(scanInfo.auraUnit) end
	if not trackedUnit and state then trackedUnit = normalizeTrackedUnit(state.trackUnit) or normalizeTrackedUnit(state.trackedAuraUnit) or normalizeTrackedUnit(state.mappedAuraUnit) end
	return trackedUnit
end

local function clearTrackedPanelIndex(runtime) runtime.unitPanels = createTrackedUnitBuckets() end

local function registerTrackedPanel(runtime, unit, panelId)
	unit = normalizeTrackedUnit(unit)
	if not (unit and panelId) then return end
	runtime.unitPanels[unit][panelId] = true
end

local function clearRuntimeTrackingState()
	local runtime = getRuntime()
	for _, state in pairs(runtime.entryStates) do
		clearEntryState(getEntryKey(state.panelId, state.entryId), state, true)
		state.trackUnit = nil
	end
	clearTrackedPanelIndex(runtime)
	wipe(runtime.auraEntries.player)
	wipe(runtime.auraEntries.target)
end

function CDMAuras:HasActiveTrackedPanels()
	local root = CooldownPanels.GetRoot and CooldownPanels:GetRoot() or nil
	if not (root and root.panels) then return false end

	local enabledPanels = CooldownPanels.runtime and CooldownPanels.runtime.enabledPanels or nil
	local useEnabledFilter = enabledPanels ~= nil

	for panelId, panel in pairs(root.panels) do
		local panelEnabled = useEnabledFilter and enabledPanels[panelId] == true or (panel and panel.enabled ~= false)
		if panelEnabled and panel and panel.entries then
			for _, entry in pairs(panel.entries) do
				if entry and entry.type == ENTRY_TYPE then return true end
			end
		end
	end

	return false
end

function CDMAuras:UpdateEventRegistration()
	local shouldRegister = self:HasActiveTrackedPanels()
	local frame = self.eventFrame

	if not shouldRegister then
		if frame and self.eventsRegistered then
			frame:UnregisterAllEvents()
			self.eventsRegistered = nil
		end
		clearRuntimeTrackingState()
		return false
	end

	self:EnsureEventFrame()
	frame = self.eventFrame
	if not self.eventsRegistered then
		frame:RegisterEvent("PLAYER_LOGIN")
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		frame:RegisterEvent("PLAYER_TARGET_CHANGED")
		frame:RegisterEvent("PLAYER_TOTEM_UPDATE")
		frame:RegisterUnitEvent("UNIT_AURA", "player", "target")
		frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		self.eventsRegistered = true
	end

	return true
end

function CDMAuras:RebuildTrackedPanelIndex()
	local runtime = getRuntime()
	clearTrackedPanelIndex(runtime)
	if not self:HasActiveTrackedPanels() then return end

	local root = CooldownPanels.GetRoot and CooldownPanels:GetRoot() or nil
	if not (root and root.panels) then return end

	local enabledPanels = CooldownPanels.runtime and CooldownPanels.runtime.enabledPanels or nil
	local useEnabledFilter = enabledPanels ~= nil
	local _, byCooldownID, bySpellID = self:ScanTrackedBuffs(false)

	for panelId, panel in pairs(root.panels) do
		local panelEnabled = useEnabledFilter and enabledPanels[panelId] == true or (panel and panel.enabled ~= false)
		if panelEnabled and panel and panel.entries then
			for entryId, entry in pairs(panel.entries) do
				if entry and entry.type == ENTRY_TYPE then
					local key = getEntryKey(panelId, entryId)
					local state = runtime.entryStates[key]
					local scanInfo = byCooldownID and byCooldownID[entry.cooldownID] or nil
					if not scanInfo and isUsableSpellID(entry.spellID) then scanInfo = bySpellID and bySpellID[entry.spellID] or nil end
					local trackedUnit = getEntryTrackedUnit(scanInfo, state, scanInfo and (scanInfo.iconFrame or scanInfo.barFrame) or nil)
					if state then state.trackUnit = trackedUnit end
					registerTrackedPanel(runtime, trackedUnit, panelId)
				end
			end
		end
	end
end

local function isFrameShowingTrackedSpell(frame, entry, trackedUnit)
	if not (frame and entry and entry.spellID) then return true end
	local trackedSpellID = entry.spellID
	local strictMatch = normalizeTrackedUnit(trackedUnit) == "target"
	if type(frame.SpellIDMatchesAnyAssociatedSpellIDs) == "function" then
		local ok, matches = pcall(frame.SpellIDMatchesAnyAssociatedSpellIDs, frame, trackedSpellID)
		if ok then return matches == true end
	end
	local sawAssociatedSpellID = false
	local sawSecretLinkedSpellID = false

	local function matchesSpellID(candidateSpellID, source)
		if not candidateSpellID then return false end
		sawAssociatedSpellID = true
		local ok, matches = pcall(function() return candidateSpellID == trackedSpellID end)
		if ok then return matches end
		if source == "linkedSpellID" then sawSecretLinkedSpellID = true end
		return false
	end

	if matchesSpellID(frame.auraSpellID, "auraSpellID") then return true end

	local function checkCooldownInfo(info)
		if not info then return false end
		if matchesSpellID(info.linkedSpellID, "linkedSpellID") then return true end
		if matchesSpellID(info.overrideTooltipSpellID, "overrideTooltipSpellID") then return true end
		if matchesSpellID(info.overrideSpellID, "overrideSpellID") then return true end
		if matchesSpellID(info.spellID, "spellID") then return true end
		local linkedSpellIDs = info.linkedSpellIDs
		if type(linkedSpellIDs) == "table" then
			for i = 1, #linkedSpellIDs do
				if matchesSpellID(linkedSpellIDs[i], "linkedSpellIDs") then return true end
			end
		end
		return false
	end

	if checkCooldownInfo(frame.cooldownInfo) then return true end
	if checkCooldownInfo(getCooldownViewerInfo(entry.cooldownID)) then return true end
	if sawSecretLinkedSpellID then return true end
	if strictMatch then return false end
	return not sawAssociatedSpellID
end

local function getFrameAuraUnit(frame)
	if not frame then return nil end
	if type(frame.GetAuraDataUnit) == "function" then
		local ok, auraUnit = pcall(frame.GetAuraDataUnit, frame)
		if ok and type(auraUnit) == "string" and auraUnit ~= "" then return auraUnit end
	end
	if type(frame.auraDataUnit) == "string" and frame.auraDataUnit ~= "" then return frame.auraDataUnit end
	return nil
end

local function getFrameAuraData(frame)
	if not frame then return nil, nil, nil end
	local auraUnit = getFrameAuraUnit(frame)
	local auraInstanceID = hasAuraInstanceID(frame.auraInstanceID) and frame.auraInstanceID or nil
	if auraUnit and auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
		local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(auraUnit, auraInstanceID)
		if auraData then return auraData, auraUnit, auraInstanceID end
	end
	return nil, auraUnit, auraInstanceID
end

local function frameHasPandemicState(frame)
	local pandemicIcon = frame and frame.PandemicIcon
	if not (pandemicIcon and pandemicIcon.IsShown) then return false end
	local ok, shown = pcall(pandemicIcon.IsShown, pandemicIcon)
	return ok and shown == true
end

function CDMAuras:HandleFrameAuraMutation(frame, wasCleared)
	if not frame then return end
	local runtime = getRuntime()
	local keys = runtime.frameEntries[frame]
	if not keys then return end
	local auraData, auraUnit, newAuraID = getFrameAuraData(frame)
	local refreshedPanels = {}

	for key in pairs(keys) do
		local state = runtime.entryStates[key]
		if state then
			local _, entry = getPanelEntry(state.panelId, state.entryId)
			if not entry or entry.type ~= ENTRY_TYPE then
				clearEntryState(key, state, true)
			elseif wasCleared then
				clearAuraMapping(runtime, key, state, false)
				state.trackedAuraInstanceID = nil
				state.trackedAuraUnit = nil
				state.pandemicActive = nil
				state.targetAuraEpoch = nil
			elseif newAuraID and isFrameShowingTrackedSpell(frame, entry, state.trackUnit or auraUnit) then
				state.trackUnit = normalizeTrackedUnit(auraUnit) or state.trackUnit
				state.trackedAuraInstanceID = newAuraID
				state.trackedAuraUnit = auraUnit or state.trackedAuraUnit
				state.pandemicActive = normalizeTrackedUnit(auraUnit) == "target" and frameHasPandemicState(frame) or nil
				if normalizeTrackedUnit(auraUnit) == "target" then state.targetAuraEpoch = runtime.targetEpoch or 0 end
				registerAuraMapping(runtime, key, state, newAuraID, auraUnit)
			end
			refreshedPanels[state.panelId] = true
		end
	end

	for panelId in pairs(refreshedPanels) do
		requestPanelRefresh(panelId)
	end
end

function CDMAuras:HandleFramePandemicStateChanged(frame, isActive)
	if not frame then return end
	local runtime = getRuntime()
	local keys = runtime.frameEntries[frame]
	if not keys then return end

	local auraUnit = normalizeTrackedUnit(getFrameAuraUnit(frame))
	local pandemicActive = isActive == true and frameHasPandemicState(frame) and auraUnit == "target"
	local refreshedPanels = {}

	for key in pairs(keys) do
		local state = runtime.entryStates[key]
		if state then
			local _, entry = getPanelEntry(state.panelId, state.entryId)
			if not entry or entry.type ~= ENTRY_TYPE then
				clearEntryState(key, state, true)
			else
				local nextPandemicActive = false
				if pandemicActive and isFrameShowingTrackedSpell(frame, entry, state.trackUnit or auraUnit) then nextPandemicActive = true end
				if (state.pandemicActive == true) ~= nextPandemicActive then
					state.pandemicActive = nextPandemicActive or nil
					refreshedPanels[state.panelId] = true
				end
			end
		end
	end

	for panelId in pairs(refreshedPanels) do
		requestPanelRefresh(panelId)
	end
end

function CDMAuras:NormalizeEntry(entry)
	if type(entry) ~= "table" then return end
	entry.type = ENTRY_TYPE
	if not isValidCooldownID(entry.cooldownID) then entry.cooldownID = tonumber(entry.cooldownID) end
	entry.spellID = tonumber(entry.spellID)
	entry.buffName = type(entry.buffName) == "string" and entry.buffName or nil
	entry.iconTextureID = entry.iconTextureID or getSpellTexture(entry.spellID)
	entry.sourceType = normalizeSourceType(entry.sourceType)
	entry.sourceViewer = entry.sourceType == SOURCE_BAR and BAR_VIEWER or ICON_VIEWER
	entry.alwaysShow = entry.alwaysShow == true
	entry.showCooldown = entry.showCooldown ~= false
	entry.showCooldownText = entry.showCooldownText ~= false
	if entry.showStacks == nil then
		entry.showStacks = false
	else
		entry.showStacks = entry.showStacks == true
	end
	entry.showCharges = false
	entry.showItemCount = false
	entry.showItemUses = false
	entry.showWhenEmpty = false
	entry.showWhenNoCooldown = false
	entry.showWhenMissing = false
	entry.useHighestRank = false
	entry.glowReady = entry.glowReady == true
	entry.pandemicGlow = entry.pandemicGlow == true
	if entry.glowReady and entry.pandemicGlow then entry.glowReady = false end
	entry.soundReady = false
end

function CDMAuras:CreateEntryData(idValue, overrides, defaults)
	local info = idValue
	if type(info) ~= "table" then
		local _, byCooldownID = self:ScanTrackedBuffs(false)
		info = byCooldownID and byCooldownID[idValue] or nil
	end
	if type(info) ~= "table" or not isValidCooldownID(info.cooldownID) then return nil end

	defaults = defaults or {}
	local entryDefaults = defaults.entry or Helper.ENTRY_DEFAULTS or {}
	local entry = Helper.CopyTableShallow(entryDefaults)
	for key, value in pairs(Helper.ENTRY_DEFAULTS or {}) do
		if entry[key] == nil then entry[key] = value end
	end

	entry.type = ENTRY_TYPE
	entry.cooldownID = info.cooldownID
	entry.spellID = tonumber(info.spellID)
	entry.buffName = info.buffName or getSpellName(entry.spellID) or tostring(info.cooldownID)
	entry.iconTextureID = info.iconTextureID or getSpellTexture(entry.spellID) or Helper.PREVIEW_ICON
	entry.sourceType = normalizeSourceType(info.sourceType)
	entry.sourceViewer = info.sourceViewer or (entry.sourceType == SOURCE_BAR and BAR_VIEWER or ICON_VIEWER)
	entry.alwaysShow = false
	entry.showCooldown = true
	entry.showCooldownText = true
	entry.showStacks = false
	entry.glowReady = false
	entry.pandemicGlow = false
	entry.soundReady = false

	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			entry[key] = value
		end
	end

	self:NormalizeEntry(entry)
	return entry
end

function CDMAuras:FindEntryByValue(panel, idValue)
	if not panel or not panel.entries then return nil end
	local lookup = type(idValue) == "table" and idValue.cooldownID or idValue
	local lookupSpellID = type(idValue) == "table" and tonumber(idValue.spellID) or nil
	if not isValidCooldownID(lookup) then return nil end
	for entryId, entry in pairs(panel.entries) do
		if entry and entry.type == ENTRY_TYPE then
			if isValidCooldownID(lookup) and cooldownIDsEqual(entry.cooldownID, lookup) then return entryId, entry end
			if lookupSpellID and tonumber(entry.spellID) == lookupSpellID then return entryId, entry end
		end
	end
	return nil
end

function CDMAuras:GetEntryIcon(entry)
	if not (entry and entry.type == ENTRY_TYPE) then return nil end
	if entry.iconTextureID then return entry.iconTextureID end
	return getSpellTexture(entry.spellID) or Helper.PREVIEW_ICON
end

function CDMAuras:GetEntryName(entry)
	if not (entry and entry.type == ENTRY_TYPE) then return nil end
	return entry.buffName or getSpellName(entry.spellID) or (L["CooldownPanelCDMAuraType"] or "Tracked Aura")
end

function CDMAuras:GetEntryTypeLabel(entryType)
	if entryType ~= ENTRY_TYPE then return nil end
	return L["CooldownPanelCDMAuraType"] or "Tracked Aura"
end

function CDMAuras:GetEntryIdText(entry)
	if not (entry and entry.type == ENTRY_TYPE) then return nil end
	return tostring(entry.cooldownID or "")
end

function CDMAuras:EntryIsAvailableForPreview(entry) return entry and entry.type == ENTRY_TYPE and isValidCooldownID(entry.cooldownID) end

function CDMAuras:ApplyPreview(icon, entry)
	if not (icon and entry and entry.type == ENTRY_TYPE) then return end
	if entry.showStacks and icon.count then
		icon.count:SetText("2")
		icon.count:Show()
	end
end

function CDMAuras:AttachEditor(editor)
	if not (editor and editor.inspector and editor.inspector.content) then return end
	local inspector = editor.inspector
	if inspector.cdmAuraCooldownIDLabel then return end

	local idLabel = inspector.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	idLabel:SetJustifyH("LEFT")
	idLabel:SetWidth(200)
	idLabel:SetTextColor(0.85, 0.85, 0.85, 1)

	inspector.cdmAuraCooldownIDLabel = idLabel
end

function CDMAuras:RefreshInspector(editor, _, entry)
	local inspector = editor and editor.inspector
	if not inspector then return end

	local isEntry = entry and entry.type == ENTRY_TYPE
	local idLabel = inspector.cdmAuraCooldownIDLabel
	if not idLabel then return end

	if not isEntry then
		idLabel:Hide()
		return
	end

	idLabel:SetText(string.format(L["CooldownPanelCDMAuraCooldownID"] or "Cooldown ID: %s", tostring(entry.cooldownID or "")))
end

function CDMAuras:LayoutInspector(inspector, entry, prev)
	local idLabel = inspector and inspector.cdmAuraCooldownIDLabel
	if not idLabel then return prev end

	if not (entry and entry.type == ENTRY_TYPE) then
		idLabel:Hide()
		return prev
	end

	idLabel:ClearAllPoints()
	idLabel:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
	idLabel:Show()
	return idLabel
end

function CDMAuras:AppendAddMenu(rootDescription, panelId)
	if not (rootDescription and panelId) then return end
	local buffsMenu = rootDescription:CreateButton(L["CooldownPanelCDMAuraAdd"] or "Tracked Aura (CDM)")
	if not buffsMenu then return end
	if buffsMenu.SetScrollMode then buffsMenu:SetScrollMode(340) end
	buffsMenu:CreateTitle(L["CooldownPanelCDMAuraPickerTitle"] or "Tracked Auras from Cooldown Manager")

	local buffs = self:ScanTrackedBuffs(true)
	local list = buffs
	if not list or #list == 0 then
		buffsMenu:CreateTitle(L["CooldownPanelCDMAuraNoBuffs"] or "No tracked auras found.")
		return
	end

	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	local existingCooldownIDs = {}
	local existingSpellIDs = {}
	for _, entry in pairs(panel and panel.entries or {}) do
		if entry and entry.type == ENTRY_TYPE then
			if isValidCooldownID(entry.cooldownID) then existingCooldownIDs[tostring(entry.cooldownID)] = true end
			if isUsableSpellID(entry.spellID) then existingSpellIDs[entry.spellID] = true end
		end
	end

	local availableCount = 0
	buffsMenu:CreateTitle(L["CooldownPanelCDMAuraPickerNote"] or "Auras set to Always Display can be added while inactive. Others only appear while active.")
	for _, info in ipairs(list) do
		local spellID = tonumber(info and info.spellID)
		if not existingCooldownIDs[tostring(info.cooldownID)] and not (spellID and existingSpellIDs[spellID]) then
			availableCount = availableCount + 1
			local icon = tostring(info.iconTextureID or Helper.PREVIEW_ICON)
			local label = string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t %s", icon, tostring(info.buffName or info.cooldownID))
			buffsMenu:CreateButton(label, function()
				if CooldownPanels.AddEntrySafe then
					CooldownPanels:AddEntrySafe(panelId, ENTRY_TYPE, info)
					CooldownPanels:RefreshEditor()
				end
			end)
		end
	end
	if availableCount == 0 then buffsMenu:CreateTitle(L["CooldownPanelCDMAuraAllAdded"] or "All tracked auras are already in this panel.") end
end

function CDMAuras:GetImportSourceLabel(sourceKind)
	if sourceKind == IMPORT_SOURCE_BAR then return L["CooldownPanelImportCDMBuffBar"] or "Buff Bar" end
	if sourceKind == IMPORT_SOURCE_ICON then return L["CooldownPanelImportCDMBuffIcon"] or "Buff Icon" end
	return nil
end

function CDMAuras:ImportEntries(panelId, sourceKind)
	local sourceType = getImportSourceType(sourceKind)
	local sourceLabel = self:GetImportSourceLabel(sourceKind)
	if not sourceType then return nil, "SOURCE_NOT_FOUND", sourceLabel end

	local viewerName = sourceType == SOURCE_BAR and BAR_VIEWER or ICON_VIEWER
	if type(_G[viewerName]) ~= "table" then return nil, "SOURCE_NOT_FOUND", sourceLabel end

	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	if not panel then return nil, "PANEL_NOT_FOUND", sourceLabel end
	local root = CooldownPanels.GetRoot and CooldownPanels:GetRoot() or nil
	if not root then return nil, "NO_DB", sourceLabel end

	panel.entries = panel.entries or {}
	panel.order = panel.order or {}

	local existingByCooldownID = {}
	local existingBySpellID = {}
	for _, entry in pairs(panel.entries) do
		if entry and entry.type == ENTRY_TYPE then
			if isValidCooldownID(entry.cooldownID) then existingByCooldownID[tostring(entry.cooldownID)] = true end
			if isUsableSpellID(entry.spellID) then existingBySpellID[entry.spellID] = true end
		end
	end

	local list = self:ScanTrackedBuffs(true)
	local stats = { added = 0, duplicates = 0, invalid = 0, seen = 0, sourceLabel = sourceLabel }

	for _, info in ipairs(list or {}) do
		if info and info.availableSources and info.availableSources[sourceType] then
			stats.seen = stats.seen + 1
			if not isValidCooldownID(info.cooldownID) then
				stats.invalid = stats.invalid + 1
			else
				local cooldownKey = tostring(info.cooldownID)
				local spellID = tonumber(info.spellID)
				if existingByCooldownID[cooldownKey] or (spellID and existingBySpellID[spellID]) then
					stats.duplicates = stats.duplicates + 1
				else
					local entryInfo = {
						cooldownID = info.cooldownID,
						spellID = info.spellID,
						buffName = info.buffName,
						iconTextureID = info.iconTextureID,
						sourceType = sourceType,
						sourceViewer = viewerName,
					}
					local entryId = Helper.GetNextNumericId(panel.entries)
					local entry = Helper.CreateEntry(ENTRY_TYPE, entryInfo, root.defaults)
					if entry and entry.cooldownID then
						entry.id = entryId
						panel.entries[entryId] = entry
						panel.order[#panel.order + 1] = entryId
						existingByCooldownID[cooldownKey] = true
						if isUsableSpellID(entry.spellID) then existingBySpellID[entry.spellID] = true end
						stats.added = stats.added + 1
					else
						stats.invalid = stats.invalid + 1
					end
				end
			end
		end
	end

	if stats.added > 0 then
		Helper.SyncOrder(panel.order, panel.entries)
		if CooldownPanels.RebuildSpellIndex then CooldownPanels:RebuildSpellIndex() end
		if CooldownPanels.RefreshPanel then CooldownPanels:RefreshPanel(panelId) end
	end

	return stats
end

function CDMAuras:AddEntrySafe(panelId, idValue, overrides)
	local info = idValue
	if type(info) ~= "table" then
		local _, byCooldownID = self:ScanTrackedBuffs(false)
		info = byCooldownID and byCooldownID[idValue] or nil
	end
	if type(info) ~= "table" or not isValidCooldownID(info.cooldownID) then
		showErrorMessage(L["CooldownPanelCDMAuraNotFound"] or "Tracked aura not found in Cooldown Manager.")
		return nil
	end
	if CooldownPanels.FindEntryByValue and CooldownPanels:FindEntryByValue(panelId, ENTRY_TYPE, info) then
		showErrorMessage("Entry already exists.")
		return nil
	end
	if not CooldownPanels.AddEntry then return nil end
	return CooldownPanels:AddEntry(panelId, ENTRY_TYPE, info, overrides)
end

function CDMAuras:HandleRootRefresh()
	self:SweepInvalidStates()
	if not self:UpdateEventRegistration() then return end
	self:RebuildTrackedPanelIndex()
end

function CDMAuras:BuildRuntimeData(panelId, entryId, entry)
	if not (entry and entry.type == ENTRY_TYPE) then return nil end

	local runtime = getRuntime()
	local key = getEntryKey(panelId, entryId)
	local state = runtime.entryStates[key]
	if not state then
		state = {
			panelId = panelId,
			entryId = entryId,
			signature = nil,
			boundFrame = nil,
			boundSource = nil,
			mappedAuraInstanceID = nil,
			mappedAuraUnit = nil,
			trackedAuraInstanceID = nil,
			trackedAuraUnit = nil,
			pandemicActive = nil,
			targetAuraEpoch = nil,
			trackUnit = nil,
			lastActive = nil,
		}
		runtime.entryStates[key] = state
	end

	local signature = string.format("%s|%s|%s", tostring(entry.cooldownID or ""), tostring(entry.spellID or ""), tostring(entry.sourceType or SOURCE_ICON))
	if state.signature ~= signature then
		clearEntryState(key, state, true)
		state.signature = signature
	end
	state.panelId = panelId
	state.entryId = entryId

	local _, byCooldownID, bySpellID = self:ScanTrackedBuffs(false)
	local scanInfo = byCooldownID and byCooldownID[entry.cooldownID] or nil
	if not scanInfo and isUsableSpellID(entry.spellID) then scanInfo = bySpellID and bySpellID[entry.spellID] or nil end
	if not scanInfo then
		self:InvalidateScan()
		local _, rescanned, rescannedBySpellID = self:ScanTrackedBuffs(true)
		scanInfo = rescanned and rescanned[entry.cooldownID] or nil
		if not scanInfo and isUsableSpellID(entry.spellID) then scanInfo = rescannedBySpellID and rescannedBySpellID[entry.spellID] or nil end
	end

	local availableSources = {}
	if scanInfo and scanInfo.availableSources then
		for sourceType in pairs(scanInfo.availableSources) do
			availableSources[sourceType] = true
		end
	end
	if not next(availableSources) then availableSources[normalizeSourceType(entry.sourceType)] = true end

	local preferredSource = normalizeSourceType(entry.sourceType)
	local preferredFrame = scanInfo and ((preferredSource == SOURCE_BAR) and scanInfo.barFrame or scanInfo.iconFrame) or nil
	local fallbackFrame = scanInfo and ((preferredSource == SOURCE_BAR) and scanInfo.iconFrame or scanInfo.barFrame) or nil

	local chosenFrame = preferredFrame
	local chosenSource = preferredSource
	if chosenFrame and not cooldownIDsEqual(getCooldownIDFromFrame(chosenFrame, chosenSource), entry.cooldownID) then chosenFrame = nil end
	if not chosenFrame and fallbackFrame then
		local fallbackSource = preferredSource == SOURCE_BAR and SOURCE_ICON or SOURCE_BAR
		if cooldownIDsEqual(getCooldownIDFromFrame(fallbackFrame, fallbackSource), entry.cooldownID) then
			chosenFrame = fallbackFrame
			chosenSource = fallbackSource
		end
	end

	if state.boundFrame ~= chosenFrame then
		if state.boundFrame then unregisterFrameBinding(runtime, key, state.boundFrame) end
		state.boundFrame = chosenFrame
		state.boundSource = chosenSource
		if chosenFrame then registerFrameBinding(runtime, key, chosenFrame) end
	end
	state.trackUnit = getEntryTrackedUnit(scanInfo, state, chosenFrame or fallbackFrame)
	registerTrackedPanel(runtime, state.trackUnit, panelId)

	local auraData
	local auraUnit
	local auraInstanceID
	local targetEpoch = runtime.targetEpoch or 0
	local canUseTargetAuraCache = normalizeTrackedUnit(state.trackUnit) ~= "target" or state.targetAuraEpoch == targetEpoch

	if chosenFrame and canUseTargetAuraCache and isFrameShowingTrackedSpell(chosenFrame, entry, state.trackUnit) then
		local currentAuraData, currentAuraUnit, currentAuraID = getFrameAuraData(chosenFrame)
		if currentAuraData then
			auraData = currentAuraData
			auraUnit = currentAuraUnit
			auraInstanceID = currentAuraID or getAuraInstanceID(currentAuraData)
			if auraInstanceID then
				state.trackUnit = normalizeTrackedUnit(auraUnit) or state.trackUnit
				state.trackedAuraInstanceID = auraInstanceID
				state.trackedAuraUnit = auraUnit
				if normalizeTrackedUnit(auraUnit) == "target" then state.targetAuraEpoch = targetEpoch end
			end
		end
	end

	if not auraData and canUseTargetAuraCache and hasAuraInstanceID(state.trackedAuraInstanceID) and state.trackedAuraUnit then
		local cachedAuraData = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID and C_UnitAuras.GetAuraDataByAuraInstanceID(state.trackedAuraUnit, state.trackedAuraInstanceID)
		if cachedAuraData then
			auraData = cachedAuraData
			auraUnit = state.trackedAuraUnit
			auraInstanceID = state.trackedAuraInstanceID
			state.trackUnit = normalizeTrackedUnit(auraUnit) or state.trackUnit
		else
			state.trackedAuraInstanceID = nil
			state.trackedAuraUnit = nil
			state.targetAuraEpoch = nil
		end
	end

	registerAuraMapping(runtime, key, state, auraInstanceID, auraUnit)

	local hasTotemData = chosenFrame and chosenFrame.totemData ~= nil
	local active = auraData ~= nil or hasTotemData
	local trackedAuraUnit = normalizeTrackedUnit(auraUnit) or normalizeTrackedUnit(state.trackUnit) or normalizeTrackedUnit(state.trackedAuraUnit) or normalizeTrackedUnit(state.mappedAuraUnit)
	local pandemicActive = false
	if active and trackedAuraUnit == "target" then
		if chosenFrame and canUseTargetAuraCache and isFrameShowingTrackedSpell(chosenFrame, entry, state.trackUnit) then
			pandemicActive = frameHasPandemicState(chosenFrame)
		else
			pandemicActive = state.pandemicActive == true
		end
	end
	state.pandemicActive = pandemicActive or nil
	local iconTextureID = auraData and auraData.icon
		or getFrameIconTexture(chosenFrame)
		or entry.iconTextureID
		or (scanInfo and scanInfo.iconTextureID)
		or getSpellTexture(entry.spellID)
		or Helper.PREVIEW_ICON
	local applications = auraData and auraData.applications or nil
	local stackCount = resolveAuraStackCount(auraUnit, auraInstanceID, applications)
	local rawDuration = auraData and auraData.duration or nil
	local rawExpirationTime = auraData and auraData.expirationTime or nil
	local rawTimeMod = auraData and auraData.timeMod or 1
	local cooldownStart = 0
	local cooldownDuration = 0
	local cooldownRate = 1
	local durationActive = false
	local cooldownUsesExpirationTime = false
	local cooldownUsesStartTime = false

	if auraData and active and rawDuration ~= nil and rawExpirationTime ~= nil then
		if isSecretValue(rawDuration) or isSecretValue(rawExpirationTime) then
			cooldownStart = rawExpirationTime
			cooldownDuration = rawDuration
			cooldownRate = isSecretValue(rawTimeMod) and 1 or (tonumber(rawTimeMod) or 1)
			durationActive = true
			cooldownUsesExpirationTime = true
		else
			local duration = tonumber(rawDuration) or 0
			local expirationTime = tonumber(rawExpirationTime) or 0
			if duration > 0 and expirationTime > 0 then
				cooldownStart = expirationTime - duration
				cooldownDuration = duration
				if cooldownStart < 0 then cooldownStart = 0 end
				cooldownRate = tonumber(rawTimeMod) or 1
				durationActive = true
				cooldownUsesExpirationTime = false
			end
		end
	end

	if not durationActive and hasTotemData then
		local startTime, duration, modRate = getTotemCooldownInfo(chosenFrame)
		if duration then
			cooldownStart = startTime
			cooldownDuration = duration
			cooldownRate = modRate or 1
			durationActive = true
			cooldownUsesStartTime = true
		end
	end

	local show = active or entry.alwaysShow ~= false
	local data = {
		show = show,
		active = active,
		durationActive = durationActive,
		cooldownStart = cooldownStart,
		cooldownDuration = cooldownDuration,
		cooldownEnabled = durationActive,
		cooldownRate = cooldownRate,
		cooldownUsesExpirationTime = cooldownUsesExpirationTime,
		cooldownUsesStartTime = cooldownUsesStartTime,
		cooldownID = entry.cooldownID,
		spellID = entry.spellID,
		buffName = entry.buffName or (scanInfo and scanInfo.buffName) or getSpellName(entry.spellID) or tostring(entry.cooldownID),
		iconTextureID = iconTextureID,
		stackCount = stackCount,
		pandemicActive = pandemicActive,
		auraInstanceID = auraInstanceID,
		auraUnit = auraUnit,
		sourceType = chosenSource or preferredSource,
		availableSources = availableSources,
	}

	if state.lastActive == true and not active then requestPanelRefresh(panelId) end
	state.lastActive = active
	return data
end

local function refreshAllTrackedPanels(unit)
	unit = normalizeTrackedUnit(unit)
	local runtime = getRuntime()
	if unit and runtime.unitPanels and runtime.unitPanels[unit] and next(runtime.unitPanels[unit]) then
		for panelId in pairs(runtime.unitPanels[unit]) do
			requestPanelRefresh(panelId)
		end
		return
	end

	local root = CooldownPanels.GetRoot and CooldownPanels:GetRoot() or nil
	if not (root and root.panels) then return end
	for panelId, panel in pairs(root.panels) do
		for _, entry in pairs(panel and panel.entries or {}) do
			if entry and entry.type == ENTRY_TYPE then
				requestPanelRefresh(panelId)
				break
			end
		end
	end
end

local function clearTrackedUnitAuras(unit)
	unit = normalizeTrackedUnit(unit)
	if not unit then return end
	local runtime = getRuntime()
	for _, state in pairs(runtime.entryStates) do
		local trackedUnit = normalizeTrackedUnit(state.trackUnit) or normalizeTrackedUnit(state.trackedAuraUnit) or normalizeTrackedUnit(state.mappedAuraUnit)
		if trackedUnit == unit then clearAuraMapping(runtime, getEntryKey(state.panelId, state.entryId), state, true) end
	end
	wipe(runtime.auraEntries[unit])
end

function CDMAuras:HandleUnitAura(_, unit, updateInfo)
	unit = normalizeTrackedUnit(unit)
	if not unit then return end
	local runtime = getRuntime()
	local auraEntries = runtime.auraEntries[unit]
	if not (auraEntries and next(auraEntries) ~= nil) then return end

	if not updateInfo or updateInfo.isFullUpdate then
		refreshAllTrackedPanels(unit)
		return
	end

	local panelsToRefresh = {}

	local function collectMapped(auraID)
		local mapped = auraEntries[auraID]
		if not mapped then return end
		for key in pairs(mapped) do
			local state = runtime.entryStates[key]
			if state then panelsToRefresh[state.panelId] = true end
		end
	end

	if updateInfo.updatedAuraInstanceIDs then
		for _, auraID in ipairs(updateInfo.updatedAuraInstanceIDs) do
			collectMapped(auraID)
		end
	end

	if updateInfo.removedAuraInstanceIDs then
		for _, auraID in ipairs(updateInfo.removedAuraInstanceIDs) do
			local mapped = auraEntries[auraID]
			if mapped then
				for key in pairs(mapped) do
					local state = runtime.entryStates[key]
					if state then
						if state.trackedAuraInstanceID == auraID and normalizeTrackedUnit(state.trackedAuraUnit) == unit then
							state.trackedAuraInstanceID = nil
							state.trackedAuraUnit = nil
							state.pandemicActive = nil
							if unit == "target" then state.targetAuraEpoch = nil end
						end
						state.mappedAuraInstanceID = nil
						state.mappedAuraUnit = nil
						panelsToRefresh[state.panelId] = true
					end
				end
				auraEntries[auraID] = nil
			end
		end
	end

	for panelId in pairs(panelsToRefresh) do
		requestPanelRefresh(panelId)
	end
end

function CDMAuras:HandleTargetChanged()
	local runtime = getRuntime()
	runtime.targetEpoch = (runtime.targetEpoch or 0) + 1
	self:InvalidateScan()
	clearTrackedUnitAuras("target")
	refreshAllTrackedPanels("target")
end

function CDMAuras:HandleResetEvent(event, ...)
	if event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		if unit and unit ~= "player" then return end
	end
	self:InvalidateScan()
	self:SweepInvalidStates()
	local runtime = getRuntime()
	for key, state in pairs(runtime.entryStates) do
		clearEntryState(key, state, true)
	end
	self:RebuildTrackedPanelIndex()
	refreshAllTrackedPanels()
end

function CDMAuras:HandleTotemUpdate()
	self:InvalidateScan()
	refreshAllTrackedPanels("player")
end

function CDMAuras:EnsureEventFrame()
	if self.eventFrame then return end
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_AURA" then
			CDMAuras:HandleUnitAura(event, ...)
		elseif event == "PLAYER_TARGET_CHANGED" then
			CDMAuras:HandleTargetChanged(event, ...)
		elseif event == "PLAYER_TOTEM_UPDATE" then
			CDMAuras:HandleTotemUpdate(event, ...)
		else
			CDMAuras:HandleResetEvent(event, ...)
		end
	end)
	self.eventFrame = frame
end
