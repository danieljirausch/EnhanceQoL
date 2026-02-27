local addonName, addon = ...

addon.EditMode = addon.EditMode or {}
local EditMode = addon.EditMode

local LibEditMode = LibStub("LibEQOLEditMode-1.0")

local DEFAULT_LAYOUT = "_Global"
local SHARED_STORAGE_KEY = "editModeData"
local LEGACY_LAYOUTS_KEY = "editModeLayouts"
local PROFILE_MIGRATION_FLAG = "_editModeDataMigratedV1"
local ROOT_MIGRATION_FLAG = "_editModeDataMigratedAllProfilesV1"
local POSITION_ONLY_FLAG = "_editModeDataPositionOnlyV1"
local ROOT_POSITION_ONLY_FLAG = "_editModeDataPositionOnlyAllProfilesV1"
local POSITION_FIELDS = {
	point = true,
	relativePoint = true,
	x = true,
	y = true,
}

local function getSelection(lib, frame)
	if not lib or not lib.frameSelections then return nil end
	return lib.frameSelections[frame]
end

local function copyDefaults(target, defaults)
	if not defaults then return end
	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = CopyTable(value)
			else
				target[key] = value
			end
		end
	end
end

EditMode.frames = EditMode.frames or {}
EditMode.lib = LibEditMode
EditMode.activeLayout = EditMode.activeLayout

function EditMode:IsAvailable() return self.lib ~= nil end

function EditMode:IsInEditMode() return self:IsAvailable() and self.lib:IsInEditMode() end

local function copyValue(value)
	if type(value) == "table" then return CopyTable(value) end
	return value
end

local function sortedKeys(source)
	local result = {}
	if type(source) ~= "table" then return result end
	for key in pairs(source) do
		if type(key) == "string" then result[#result + 1] = key end
	end
	table.sort(result)
	return result
end

local function mergeMissingRecord(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then return end
	for key, value in pairs(source) do
		if target[key] == nil then target[key] = copyValue(value) end
	end
end

local function mergeMissingFrames(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then return end
	for frameId, data in pairs(source) do
		local existing = target[frameId]
		if existing == nil then
			target[frameId] = copyValue(data)
		elseif type(existing) == "table" and type(data) == "table" then
			mergeMissingRecord(existing, data)
		end
	end
end

local function pruneRecordToPositionOnly(record)
	if type(record) ~= "table" then return end
	for field in pairs(record) do
		if not POSITION_FIELDS[field] then record[field] = nil end
	end
end

local function pruneStoreToPositionOnly(store)
	if type(store) ~= "table" then return end
	for id, record in pairs(store) do
		if type(record) == "table" then
			pruneRecordToPositionOnly(record)
		else
			store[id] = nil
		end
	end
end

local function pickPreferredLegacyLayout(layouts, preferred)
	if preferred and type(layouts[preferred]) == "table" and next(layouts[preferred]) ~= nil then return preferred end
	if type(layouts[DEFAULT_LAYOUT]) == "table" and next(layouts[DEFAULT_LAYOUT]) ~= nil then return DEFAULT_LAYOUT end
	for _, key in ipairs(sortedKeys(layouts)) do
		local layout = layouts[key]
		if type(layout) == "table" and next(layout) ~= nil then return key end
	end
	return nil
end

function EditMode:_migrateLegacyLayoutStore(profile, preferredLayoutName)
	if type(profile) ~= "table" then return end
	if profile[PROFILE_MIGRATION_FLAG] and profile[POSITION_ONLY_FLAG] and profile[LEGACY_LAYOUTS_KEY] == nil and type(profile[SHARED_STORAGE_KEY]) == "table" then return end

	local target = profile[SHARED_STORAGE_KEY]
	if type(target) ~= "table" then
		target = {}
		profile[SHARED_STORAGE_KEY] = target
	end

	local legacyLayouts = profile[LEGACY_LAYOUTS_KEY]
	if type(legacyLayouts) == "table" then
		if next(target) == nil then
			local preferred = pickPreferredLegacyLayout(legacyLayouts, preferredLayoutName)
			if preferred and type(legacyLayouts[preferred]) == "table" then mergeMissingFrames(target, legacyLayouts[preferred]) end
		end

		for _, key in ipairs(sortedKeys(legacyLayouts)) do
			local layout = legacyLayouts[key]
			if type(layout) == "table" then mergeMissingFrames(target, layout) end
		end

		profile[LEGACY_LAYOUTS_KEY] = nil
	end

	pruneStoreToPositionOnly(target)

	profile[PROFILE_MIGRATION_FLAG] = true
	profile[POSITION_ONLY_FLAG] = true
end

function EditMode:MigrateProfileData(profile, preferredLayoutName) self:_migrateLegacyLayoutStore(profile, preferredLayoutName or self:GetActiveLayoutName()) end

function EditMode:_migrateAllProfiles()
	local db = _G.EnhanceQoLDB
	if type(db) ~= "table" then return end
	if db[ROOT_MIGRATION_FLAG] and db[ROOT_POSITION_ONLY_FLAG] then return end
	local profiles = db.profiles
	if type(profiles) ~= "table" then
		db[ROOT_MIGRATION_FLAG] = true
		db[ROOT_POSITION_ONLY_FLAG] = true
		return
	end

	local preferred = self:GetActiveLayoutName()
	for _, profile in pairs(profiles) do
		self:_migrateLegacyLayoutStore(profile, preferred)
	end

	db[ROOT_MIGRATION_FLAG] = true
	db[ROOT_POSITION_ONLY_FLAG] = true
end

function EditMode:_ensureDB()
	if not addon.db then return nil end
	if self.runtimeProfileRef ~= addon.db then
		self.runtimeProfileRef = addon.db
		self.runtimeLayoutData = {}
	end
	self:_migrateAllProfiles()
	self:_migrateLegacyLayoutStore(addon.db, self:GetActiveLayoutName())
	addon.db[SHARED_STORAGE_KEY] = addon.db[SHARED_STORAGE_KEY] or {}
	return addon.db[SHARED_STORAGE_KEY]
end

function EditMode:GetActiveLayoutName()
	if self:IsAvailable() then
		local layoutName = self.lib:GetActiveLayoutName()
		if layoutName and layoutName ~= "" then
			if self.activeLayout and self.activeLayout ~= layoutName then self.lastActiveLayout = self.activeLayout end
			self.activeLayout = layoutName
			return layoutName
		end
	end
	return self.activeLayout or DEFAULT_LAYOUT
end

function EditMode:_resolveLayoutName(layoutName)
	if layoutName and layoutName ~= "" then return layoutName end
	return self:GetActiveLayoutName()
end

local function isInCombat() return InCombatLockdown and InCombatLockdown() end

function EditMode:_ensureCombatWatcher()
	if self.combatWatcher then return end
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	watcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			EditMode:_flushPendingLayout()
			EditMode:_flushPendingVisibility()
			EditMode:_refreshAllVisibility()
		else
			EditMode:_refreshAllVisibility()
		end
	end)
	self.combatWatcher = watcher
end

function EditMode:_flushPendingVisibility()
	local pending = self.pendingVisibility
	if not pending then return end
	self.pendingVisibility = nil
	for entry, shouldShow in pairs(pending) do
		if entry then self:_applyVisibility(entry, nil, entry._lastEnabled, true) end
	end
end

function EditMode:_flushPendingLayout()
	local pending = self.pendingLayout
	if not pending then return end
	self.pendingLayout = nil
	for entry, data in pairs(pending) do
		if entry and data then self:_applyLayoutPosition(entry, data, true) end
	end
end

function EditMode:_refreshAllVisibility()
	for _, entry in pairs(self.frames) do
		self:_applyVisibility(entry, nil, entry._lastEnabled, true)
	end
end

function EditMode:_setFrameShown(entry, shouldShow, immediate)
	local frame = entry.frame
	if not frame then return end

	local isProtected = frame.IsProtected and frame:IsProtected()
	if not immediate and isProtected and isInCombat() then
		self.pendingVisibility = self.pendingVisibility or {}
		self.pendingVisibility[entry] = shouldShow
		self:_ensureCombatWatcher()
		return
	end

	if self.pendingVisibility then self.pendingVisibility[entry] = nil end

	local currentlyShown = frame:IsShown()
	if shouldShow then
		if not currentlyShown then frame:Show() end
	else
		if currentlyShown then frame:Hide() end
	end
end

local function resolveRelativeFrame(entry)
	if not entry then return UIParent end
	local relative = entry.relativeTo
	if type(relative) == "function" then relative = relative() end
	return relative or UIParent
end

function EditMode:_applyLayoutPosition(entry, data, immediate)
	local frame = entry.frame
	if not frame then return end

	if frame.IsProtected and frame:IsProtected() and not immediate and isInCombat() then
		self.pendingLayout = self.pendingLayout or {}
		local config = {
			point = data.point,
			relativePoint = data.relativePoint,
			x = data.x,
			y = data.y,
		}
		self.pendingLayout[entry] = config
		self:_ensureCombatWatcher()
		return
	end

	if self.pendingLayout then self.pendingLayout[entry] = nil end

	local point = data.point
	local relativePoint = data.relativePoint or point
	local x = data.x or 0
	local y = data.y or 0
	local relative = resolveRelativeFrame(entry)

	frame:ClearAllPoints()
	frame:SetPoint(point, relative, relativePoint, x, y)
end

function EditMode:_seedStoredPosition(record, entry)
	record.point = record.point or (entry and entry.defaults and entry.defaults.point) or "CENTER"
	record.relativePoint = record.relativePoint or record.point or (entry and entry.defaults and entry.defaults.relativePoint) or "CENTER"
	if record.x == nil then record.x = (entry and entry.defaults and entry.defaults.x) or 0 end
	if record.y == nil then record.y = (entry and entry.defaults and entry.defaults.y) or 0 end
end

function EditMode:_writeStoredPosition(id, entry, point, relativePoint, x, y)
	local container = self:_ensureDB()
	if not container then return end
	local record = container[id]
	if type(record) ~= "table" then
		record = {}
		container[id] = record
	end
	pruneRecordToPositionOnly(record)
	self:_seedStoredPosition(record, entry)

	if point ~= nil then record.point = point end
	if relativePoint ~= nil then
		record.relativePoint = relativePoint
	elseif point ~= nil then
		record.relativePoint = point
	end
	if x ~= nil then record.x = x end
	if y ~= nil then record.y = y end
	if not record.relativePoint then record.relativePoint = record.point end
end

function EditMode:EnsureLayoutData(id, layoutName)
	local entry = self.frames[id]
	if not entry then return nil end

	local container = self:_ensureDB()
	if not container then
		entry._fallback = entry._fallback or {}
		copyDefaults(entry._fallback, entry.defaults)
		return entry._fallback
	end

	local record = container[id]
	if type(record) ~= "table" then
		record = {}
		container[id] = record
	end
	pruneRecordToPositionOnly(record)
	self:_seedStoredPosition(record, entry)

	self.runtimeLayoutData = self.runtimeLayoutData or {}
	local runtime = self.runtimeLayoutData[id]
	if type(runtime) ~= "table" then
		runtime = {}
		if entry.legacy then
			for field, key in pairs(entry.legacy) do
				local value = addon.db and addon.db[key]
				if value ~= nil then runtime[field] = value end
			end
		end
		copyDefaults(runtime, entry.defaults)
		self.runtimeLayoutData[id] = runtime
	end

	runtime.point = record.point or runtime.point or (entry.defaults and entry.defaults.point) or "CENTER"
	runtime.relativePoint = record.relativePoint or runtime.relativePoint or runtime.point
	if runtime.x == nil then runtime.x = record.x or (entry.defaults and entry.defaults.x) or 0 end
	if runtime.y == nil then runtime.y = record.y or (entry.defaults and entry.defaults.y) or 0 end

	if record.point ~= runtime.point or record.relativePoint ~= runtime.relativePoint or record.x ~= runtime.x or record.y ~= runtime.y then
		self:_writeStoredPosition(id, entry, runtime.point, runtime.relativePoint, runtime.x, runtime.y)
	end

	return runtime
end

function EditMode:GetLayoutData(id, layoutName) return self:EnsureLayoutData(id, layoutName) end

function EditMode:SetFramePosition(id, point, x, y, layoutName, skipApply)
	local data = self:EnsureLayoutData(id, layoutName)
	if not data then return end
	local entry = self.frames[id]

	data.point = point
	data.relativePoint = point
	data.x = x
	data.y = y
	self:_writeStoredPosition(id, entry, data.point, data.relativePoint, data.x, data.y)

	if not skipApply then self:ApplyLayout(id, layoutName) end
end

function EditMode:SetValue(id, field, value, layoutName, skipApply)
	local data = self:EnsureLayoutData(id, layoutName)
	if not data then return end
	local entry = self.frames[id]

	data[field] = value
	if POSITION_FIELDS[field] then self:_writeStoredPosition(id, entry, data.point, data.relativePoint, data.x, data.y) end
	if not skipApply then self:ApplyLayout(id, layoutName) end
end

function EditMode:GetValue(id, field, layoutName)
	local data = self:EnsureLayoutData(id, layoutName)
	return data and data[field]
end

function EditMode:_isEntryEnabled(entry)
	if entry.isEnabled then
		local ok, result = pcall(entry.isEnabled, entry.frame)
		if not ok then
			geterrorhandler()(result)
			return true
		end
		return not not result
	end
	return true
end

function EditMode:_applyVisibility(entry, layoutName, enabled, forceImmediate)
	local frame = entry.frame
	local lib = self.lib
	if enabled == nil then enabled = self:_isEntryEnabled(entry) end
	entry._lastEnabled = enabled

	local selection = getSelection(lib, frame)
	local inEditMode = self:IsInEditMode()
	local inCombat = isInCombat()

	if frame then
		local shouldShow = false
		if enabled then
			if entry.showOutsideEditMode then shouldShow = true end
			if inEditMode and not inCombat then shouldShow = true end
		end
		self:_setFrameShown(entry, shouldShow, forceImmediate)
	end

	if selection then
		if enabled and inEditMode and not inCombat then
			selection:Show()
		else
			selection:Hide()
			selection.isSelected = false
		end
	end

	return enabled
end

function EditMode:RefreshFrame(id, layoutName)
	local entry = self.frames[id]
	if not entry then return end
	layoutName = self:_resolveLayoutName(layoutName)
	self:ApplyLayout(id, layoutName)
end

function EditMode:ApplyLayout(id, layoutName)
	local entry = self.frames[id]
	if not entry or not entry.frame then return end

	layoutName = self:_resolveLayoutName(layoutName)
	local data = self:EnsureLayoutData(id, layoutName)
	if not data then return end
	self:_writeStoredPosition(id, entry, data.point, data.relativePoint, data.x, data.y)

	if entry.managePosition ~= false then
		local position = {
			point = data.point or entry.defaults.point or "CENTER",
			relativePoint = data.relativePoint or entry.defaults.relativePoint or data.point or entry.defaults.point or "CENTER",
			x = data.x or entry.defaults.x or 0,
			y = data.y or entry.defaults.y or 0,
		}
		self:_applyLayoutPosition(entry, position)
	end

	if entry.onApply then entry.onApply(entry.frame, layoutName, data) end

	self:_applyVisibility(entry, layoutName)
end

function EditMode:_registerCallbacks()
	if self.callbacksRegistered then return end
	if not self:IsAvailable() then return end
	self.callbacksRegistered = true

	self.lib:RegisterCallback("enter", function() self:OnEnterEditMode() end)
	self.lib:RegisterCallback("exit", function() self:OnExitEditMode() end)
end

function EditMode:OnEnterEditMode()
	for _, entry in pairs(self.frames) do
		local layoutName = self:GetActiveLayoutName()
		local enabled = self:_applyVisibility(entry, layoutName)
		if enabled and entry.onEnter then entry.onEnter(entry.frame, layoutName, self:EnsureLayoutData(entry.id)) end
	end
end

function EditMode:OnExitEditMode()
	for _, entry in pairs(self.frames) do
		if entry.onExit and entry._lastEnabled then entry.onExit(entry.frame, self:GetActiveLayoutName(), self:EnsureLayoutData(entry.id)) end
		self:_applyVisibility(entry, self:GetActiveLayoutName())
	end
end

function EditMode:OnLayoutChanged(layoutName)
	-- Edit Mode layout switches must not mutate addon-managed frame state.
	-- Data is layout-agnostic (single store per addon profile), so applying
	-- all frames here only causes redundant SetPoint churn and visible jitter.
	return
end

function EditMode:OnLayoutRenamed(oldName, newName, layoutIndex)
	if not oldName or oldName == "" or not newName or newName == "" or oldName == newName then return end
	if self.activeLayout == oldName then self.activeLayout = newName end
	if self.lastActiveLayout == oldName then self.lastActiveLayout = newName end
end

function EditMode:OnLayoutAdded(layoutIndex, activateNewLayout, isLayoutImported, layoutType, layoutName)
	if activateNewLayout then self:OnLayoutChanged(layoutName or self:GetActiveLayoutName()) end
end

function EditMode:OnLayoutDuplicate(addedLayoutIndex, dupes, isLayoutImported, layoutType, newName)
	if newName and newName ~= "" and self:GetActiveLayoutName() == newName then self:OnLayoutChanged(newName) end
end

function EditMode:_prepareSetting(id, setting)
	local copy = {}
	for key, value in pairs(setting) do
		if key ~= "field" and key ~= "onValueChanged" then copy[key] = value end
	end

	local field = setting.field
	local onChange = setting.onValueChanged

	local requiresField = not copy.generator and copy.kind ~= EditMode.lib.SettingType.Label and copy.kind ~= EditMode.lib.SettingType.Divider and copy.kind ~= EditMode.lib.SettingType.Collapsible

	if not copy.get and requiresField then
		assert(field, "setting.field required when getter is omitted")
		copy.get = function(layoutName)
			local data = self:EnsureLayoutData(id, layoutName)
			return data and data[field]
		end
	end

	if not copy.set and requiresField then
		assert(field, "setting.field required when setter is omitted")
		copy.set = function(layoutName, value)
			self:SetValue(id, field, value, layoutName, true)
			local data = self:EnsureLayoutData(id, layoutName)
			if onChange then onChange(layoutName, value, data) end
			self:ApplyLayout(id, layoutName)
		end
	end

	local entry = self.frames[id]
	if requiresField and copy.default == nil and entry and entry.defaults then copy.default = entry.defaults[field] end

	return copy
end

function EditMode:RegisterSettings(id, settings)
	if not settings or #settings == 0 then return end
	if not self:IsAvailable() then return end

	local entry = self.frames[id]
	if not entry or not entry.frame then return end

	local prepared = {}
	for index = 1, #settings do
		local s = self:_prepareSetting(id, settings[index])
		prepared[index] = s
		if s.field then
			entry.settingsByField = entry.settingsByField or {}
			entry.settingsByField[s.field] = s
		end
	end

	self.lib:AddFrameSettings(entry.frame, prepared)
end

function EditMode:RegisterButtons(id, buttons)
	if not buttons or #buttons == 0 then return end
	if not self:IsAvailable() then return end

	local entry = self.frames[id]
	if not entry or not entry.frame then return end

	entry.buttons = entry.buttons or {}
	for index = 1, #buttons do
		local source = buttons[index]
		if source and source.text and source.click then
			local prepared = {
				text = source.text,
				click = function(...)
					local ok, err = pcall(source.click, ...)
					if not ok then geterrorhandler()(err) end
				end,
			}
			self.lib:AddFrameSettingsButton(entry.frame, prepared)
			entry.buttons[#entry.buttons + 1] = prepared
		elseif source and source.text then
			local prepared = {
				text = source.text,
				click = function() end,
			}
			self.lib:AddFrameSettingsButton(entry.frame, prepared)
			entry.buttons[#entry.buttons + 1] = prepared
		end
	end
end

function EditMode:RegisterFrame(id, opts)
	assert(type(id) == "string" and id ~= "", "frame id must be a non-empty string")
	opts = opts or {}

	local frame = opts.frame
	if not frame and opts.createFrame then frame = opts.createFrame() end
	assert(frame, "EditMode:RegisterFrame requires a frame")

	local defaults = opts.layoutDefaults or {}
	defaults.point = defaults.point or "CENTER"
	defaults.relativePoint = defaults.relativePoint or defaults.point
	defaults.x = defaults.x or 0
	defaults.y = defaults.y or 0

	local entry = {
		id = id,
		frame = frame,
		defaults = defaults,
		legacy = opts.legacyKeys,
		isEnabled = opts.isEnabled,
		managePosition = opts.managePosition,
		relativeTo = opts.relativeTo,
		showOutsideEditMode = not not opts.showOutsideEditMode,
		onApply = opts.onApply,
		onEnter = opts.onEnter,
		onExit = opts.onExit,
	}

	self.frames[id] = entry

	if opts.title then frame.editModeName = opts.title end

	self:EnsureLayoutData(id, nil)

	if not entry.showOutsideEditMode then frame:Hide() end

	if self:IsAvailable() then
		self:_registerCallbacks()

		local defaultPosition = {
			point = self:GetValue(id, "point") or defaults.point,
			x = self:GetValue(id, "x") or defaults.x,
			y = self:GetValue(id, "y") or defaults.y,
			enableOverlayToggle = opts.enableOverlayToggle or false,
			collapseExclusive = opts.collapseExclusive or false,
			allowDrag = opts.allowDrag,
			settingsSpacing = opts.settingsSpacing,
			sliderHeight = opts.sliderHeight,
			dropdownHeight = opts.dropdownHeight,
			checkboxColorHeight = opts.checkboxColorHeight,
			multiDropdownSummaryHeight = opts.multiDropdownSummaryHeight,
			dividerHeight = opts.dividerHeight,
			showSettingsReset = opts.showSettingsReset,
			showReset = opts.showReset,
			settingsMaxHeight = opts.settingsMaxHeight,
		}

		self.lib:AddFrame(frame, function(_, layoutName, point, x, y)
			self:SetFramePosition(id, point, x, y, layoutName, true)
			if opts.onPositionChanged then opts.onPositionChanged(frame, layoutName, self:EnsureLayoutData(id, layoutName)) end
			self:ApplyLayout(id, layoutName)
		end, defaultPosition)

		if opts.settings then self:RegisterSettings(id, opts.settings) end
		if opts.buttons then self:RegisterButtons(id, opts.buttons) end
	end

	self:ApplyLayout(id, self:GetActiveLayoutName())
	-- self.lib:AddManagerCheckbox({
	--     label = frame.editModeName,
	--     frames = frame,
	--     category = "EnhanceQoL",
	--     id = id,
	-- })

	return frame
end

function EditMode:UnregisterFrame(id, purgeData)
	if not id then return end
	id = tostring(id)
	local entry = self.frames and self.frames[id]
	if not entry then return end

	if self.pendingLayout then self.pendingLayout[entry] = nil end
	if self.pendingVisibility then self.pendingVisibility[entry] = nil end

	if self:IsAvailable() and entry.frame and self.lib then
		local frame = entry.frame
		local lib = self.lib
		local selection = lib.frameSelections and lib.frameSelections[frame]
		if selection then
			if lib.internal and lib.internal.magnetismManager and lib.internal.magnetismManager.UnregisterFrame then lib.internal.magnetismManager:UnregisterFrame(selection) end
			selection:Hide()
			selection:SetParent(nil)
			lib.frameSelections[frame] = nil
		end
		if lib.frameCallbacks then lib.frameCallbacks[frame] = nil end
		if lib.frameDefaults then lib.frameDefaults[frame] = nil end
		if lib.frameSettings then lib.frameSettings[frame] = nil end
		if lib.frameButtons then lib.frameButtons[frame] = nil end
	end

	local data = addon.db and addon.db[SHARED_STORAGE_KEY]
	if purgeData and type(data) == "table" then data[id] = nil end
	if self.runtimeLayoutData then self.runtimeLayoutData[id] = nil end

	self.frames[id] = nil
end
