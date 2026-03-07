local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local UnitLevel = UnitLevel
local GetNumSpecializationsForClassID = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID) or GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local tinsert = table.insert
local tsort = table.sort
local C_Item_GetItemInfo = C_Item and C_Item.GetItemInfo
local C_Item_GetItemNameByID = C_Item and C_Item.GetItemNameByID
local C_Item_RequestLoadItemDataByID = C_Item and C_Item.RequestLoadItemDataByID
local CreateFrame = CreateFrame
local STAT_HASTE_LABEL = _G.STAT_HASTE
local STAT_CRIT_LABEL = _G.STAT_CRITICAL_STRIKE
local STAT_MASTERY_LABEL = _G.STAT_MASTERY
local STAT_VERSATILITY_LABEL = _G.STAT_VERSATILITY
local ROLE_TANK_LABEL = _G.TANK
local ROLE_HEALER_LABEL = _G.HEALER
local ROLE_DAMAGER_LABEL = _G.ROLE_DAMAGER
local ROLE_RANGED_LABEL = _G.RANGED
local ROLE_MELEE_LABEL = _G.MELEE

addon.Flasks = addon.Flasks or {}
addon.Flasks.functions = addon.Flasks.functions or {}
addon.Flasks.filteredFlasks = addon.Flasks.filteredFlasks or {}
addon.Flasks.bagItemCountCache = addon.Flasks.bagItemCountCache or {}

addon.Flasks.typeOrder = { "haste", "criticalStrike", "mastery", "versatility", "alchemicalChaos" }
addon.Flasks.roleOrder = { "tank", "healer", "ranged", "melee" }
addon.Flasks.typeLabels = addon.Flasks.typeLabels or {
	haste = STAT_HASTE_LABEL,
	criticalStrike = STAT_CRIT_LABEL,
	mastery = STAT_MASTERY_LABEL,
	versatility = STAT_VERSATILITY_LABEL,
}
addon.Flasks.roleLabels = addon.Flasks.roleLabels
	or {
		tank = ROLE_TANK_LABEL,
		healer = ROLE_HEALER_LABEL,
		ranged = ROLE_RANGED_LABEL and ROLE_DAMAGER_LABEL and (ROLE_RANGED_LABEL .. " " .. ROLE_DAMAGER_LABEL) or ROLE_RANGED_LABEL,
		melee = ROLE_MELEE_LABEL and ROLE_DAMAGER_LABEL and (ROLE_MELEE_LABEL .. " " .. ROLE_DAMAGER_LABEL) or ROLE_MELEE_LABEL,
	}

-- Current expansion set (highest rank -> lowest rank). Keep this table easy to extend.
addon.Flasks.typeFlasks = addon.Flasks.typeFlasks
	or {
		haste = {
			-- Midnight
			{ key = "FlaskOfTheBloodKnights2", id = 241324, requiredLevel = 81, rank = 2, typeKey = "haste", label = STAT_HASTE_LABEL },
			{ key = "FlaskOfTheBloodKnights1", id = 241325, requiredLevel = 81, rank = 1, typeKey = "haste", label = STAT_HASTE_LABEL },
			-- TWW legacy
			{ key = "FlaskOfTemperedSwiftness3", id = 212274, requiredLevel = 71, rank = 3, typeKey = "haste", label = STAT_HASTE_LABEL },
			{ key = "FlaskOfTemperedSwiftness2", id = 212273, requiredLevel = 71, rank = 2, typeKey = "haste", label = STAT_HASTE_LABEL },
			{ key = "FlaskOfTemperedSwiftness1", id = 212272, requiredLevel = 71, rank = 1, typeKey = "haste", label = STAT_HASTE_LABEL },
		},
		criticalStrike = {
			-- Midnight
			{ key = "FlaskOfTheShatteredSun2", id = 241326, requiredLevel = 81, rank = 2, typeKey = "criticalStrike", label = STAT_CRIT_LABEL },
			{ key = "FlaskOfTheShatteredSun1", id = 241327, requiredLevel = 81, rank = 1, typeKey = "criticalStrike", label = STAT_CRIT_LABEL },
			-- TWW legacy
			{ key = "FlaskOfTemperedAggression3", id = 212271, requiredLevel = 71, rank = 3, typeKey = "criticalStrike", label = STAT_CRIT_LABEL },
			{ key = "FlaskOfTemperedAggression2", id = 212270, requiredLevel = 71, rank = 2, typeKey = "criticalStrike", label = STAT_CRIT_LABEL },
			{ key = "FlaskOfTemperedAggression1", id = 212269, requiredLevel = 71, rank = 1, typeKey = "criticalStrike", label = STAT_CRIT_LABEL },
		},
		mastery = {
			-- Midnight
			{ key = "FlaskOfTheMagisters2", id = 241322, requiredLevel = 81, rank = 2, typeKey = "mastery", label = STAT_MASTERY_LABEL },
			{ key = "FlaskOfTheMagisters1", id = 241323, requiredLevel = 81, rank = 1, typeKey = "mastery", label = STAT_MASTERY_LABEL },
			-- TWW legacy
			{ key = "FlaskOfTemperedMastery3", id = 212280, requiredLevel = 71, rank = 3, typeKey = "mastery", label = STAT_MASTERY_LABEL },
			{ key = "FlaskOfTemperedMastery2", id = 212279, requiredLevel = 71, rank = 2, typeKey = "mastery", label = STAT_MASTERY_LABEL },
			{ key = "FlaskOfTemperedMastery1", id = 212278, requiredLevel = 71, rank = 1, typeKey = "mastery", label = STAT_MASTERY_LABEL },
		},
		versatility = {
			-- Midnight
			{ key = "FlaskOfThalassianResistance2", id = 241320, requiredLevel = 81, rank = 2, typeKey = "versatility", label = STAT_VERSATILITY_LABEL },
			{ key = "FlaskOfThalassianResistance1", id = 241321, requiredLevel = 81, rank = 1, typeKey = "versatility", label = STAT_VERSATILITY_LABEL },
			-- TWW legacy
			{ key = "FlaskOfTemperedVersatility3", id = 212277, requiredLevel = 71, rank = 3, typeKey = "versatility", label = STAT_VERSATILITY_LABEL },
			{ key = "FlaskOfTemperedVersatility2", id = 212276, requiredLevel = 71, rank = 2, typeKey = "versatility", label = STAT_VERSATILITY_LABEL },
			{ key = "FlaskOfTemperedVersatility1", id = 212275, requiredLevel = 71, rank = 1, typeKey = "versatility", label = STAT_VERSATILITY_LABEL },
		},
		alchemicalChaos = {
			{ key = "FlaskOfAlchemicalChaos3", id = 212283, requiredLevel = 71, rank = 3, typeKey = "alchemicalChaos" },
			{ key = "FlaskOfAlchemicalChaos2", id = 212282, requiredLevel = 71, rank = 2, typeKey = "alchemicalChaos" },
			{ key = "FlaskOfAlchemicalChaos1", id = 212281, requiredLevel = 71, rank = 1, typeKey = "alchemicalChaos" },
		},
	}

-- Fleeting variants (provided item IDs). Preferred over cauldrons when cauldron preference is enabled.
addon.Flasks.fleetingTypeFlasks = addon.Flasks.fleetingTypeFlasks
	or {
		haste = {
			-- Midnight
			{ key = "FleetingFlaskOfTheBloodKnights2", id = 245931, requiredLevel = 81, rank = 2, typeKey = "haste" },
			{ key = "FleetingFlaskOfTheBloodKnights1", id = 245930, requiredLevel = 81, rank = 1, typeKey = "haste" },
			-- TWW legacy
			{ key = "FleetingFlaskOfTemperedSwiftness3", id = 212731, requiredLevel = 71, rank = 3, typeKey = "haste" },
			{ key = "FleetingFlaskOfTemperedSwiftness2", id = 212730, requiredLevel = 71, rank = 2, typeKey = "haste" },
			{ key = "FleetingFlaskOfTemperedSwiftness1", id = 212729, requiredLevel = 71, rank = 1, typeKey = "haste" },
		},
		criticalStrike = {
			-- Midnight
			{ key = "FleetingFlaskOfTheShatteredSun2", id = 245929, requiredLevel = 81, rank = 2, typeKey = "criticalStrike" },
			{ key = "FleetingFlaskOfTheShatteredSun1", id = 245928, requiredLevel = 81, rank = 1, typeKey = "criticalStrike" },
			-- TWW legacy
			{ key = "FleetingFlaskOfTemperedAggression3", id = 212728, requiredLevel = 71, rank = 3, typeKey = "criticalStrike" },
			{ key = "FleetingFlaskOfTemperedAggression2", id = 212727, requiredLevel = 71, rank = 2, typeKey = "criticalStrike" },
			{ key = "FleetingFlaskOfTemperedAggression1", id = 212725, requiredLevel = 71, rank = 1, typeKey = "criticalStrike" },
		},
		mastery = {
			-- Midnight
			{ key = "FleetingFlaskOfTheMagisters2", id = 245933, requiredLevel = 81, rank = 2, typeKey = "mastery" },
			{ key = "FleetingFlaskOfTheMagisters1", id = 245932, requiredLevel = 81, rank = 1, typeKey = "mastery" },
			-- TWW legacy
			{ key = "FleetingFlaskOfTemperedMastery3", id = 212738, requiredLevel = 71, rank = 3, typeKey = "mastery" },
			{ key = "FleetingFlaskOfTemperedMastery2", id = 212736, requiredLevel = 71, rank = 2, typeKey = "mastery" },
			{ key = "FleetingFlaskOfTemperedMastery1", id = 212735, requiredLevel = 71, rank = 1, typeKey = "mastery" },
		},
		versatility = {
			-- Midnight
			{ key = "FleetingFlaskOfThalassianResistance2", id = 245926, requiredLevel = 81, rank = 2, typeKey = "versatility" },
			{ key = "FleetingFlaskOfThalassianResistance1", id = 245927, requiredLevel = 81, rank = 1, typeKey = "versatility" },
			-- TWW legacy
			{ key = "FleetingFlaskOfTemperedVersatility3", id = 212734, requiredLevel = 71, rank = 3, typeKey = "versatility" },
			{ key = "FleetingFlaskOfTemperedVersatility2", id = 212733, requiredLevel = 71, rank = 2, typeKey = "versatility" },
			{ key = "FleetingFlaskOfTemperedVersatility1", id = 212732, requiredLevel = 71, rank = 1, typeKey = "versatility" },
		},
	}

local function sortEntriesDescending(list)
	if type(list) ~= "table" then return end
	tsort(list, function(a, b)
		local aLevel = tonumber(a and a.requiredLevel) or 0
		local bLevel = tonumber(b and b.requiredLevel) or 0
		if aLevel ~= bLevel then return aLevel > bLevel end
		local aRank = tonumber(a and a.rank) or 0
		local bRank = tonumber(b and b.rank) or 0
		if aRank ~= bRank then return aRank > bRank end
		return (tonumber(a and a.id) or 0) > (tonumber(b and b.id) or 0)
	end)
end

local function sortFlaskTable(flaskTable)
	if type(flaskTable) ~= "table" then return end
	for _, typeKey in ipairs(addon.Flasks.typeOrder) do
		sortEntriesDescending(flaskTable[typeKey])
	end
end

sortFlaskTable(addon.Flasks.typeFlasks)
sortFlaskTable(addon.Flasks.fleetingTypeFlasks)

local function requestTypeNameData()
	if not C_Item_RequestLoadItemDataByID then return end
	for _, typeKey in ipairs(addon.Flasks.typeOrder) do
		local entries = addon.Flasks.typeFlasks[typeKey]
		if entries then
			for i = 1, #entries do
				local entry = entries[i]
				if entry and entry.id then C_Item_RequestLoadItemDataByID(entry.id) end
			end
		end
	end
end

requestTypeNameData()

local VALID_TYPES = {}
for _, key in ipairs(addon.Flasks.typeOrder) do
	VALID_TYPES[key] = true
end

local VALID_ROLES = {}
for _, key in ipairs(addon.Flasks.roleOrder) do
	VALID_ROLES[key] = true
end

-- Explicit ranged specs to split DAMAGER into ranged/melee.
local RANGED_DPS_SPEC_IDS = {
	[62] = true, -- Mage Arcane
	[63] = true, -- Mage Fire
	[64] = true, -- Mage Frost
	[102] = true, -- Druid Balance
	[253] = true, -- Hunter Beast Mastery
	[254] = true, -- Hunter Marksmanship
	[258] = true, -- Priest Shadow
	[262] = true, -- Shaman Elemental
	[265] = true, -- Warlock Affliction
	[266] = true, -- Warlock Demonology
	[267] = true, -- Warlock Destruction
	[1467] = true, -- Evoker Devastation
	[1473] = true, -- Evoker Augmentation
}

local function normalizeTypeKey(value)
	if type(value) ~= "string" then return "none" end
	if VALID_TYPES[value] then return value end
	return "none"
end

local function normalizeRoleKey(value)
	if type(value) ~= "string" then return nil end
	if VALID_ROLES[value] then return value end
	return nil
end

local function getRoleBucketFromRoleToken(roleToken, specID)
	if roleToken == "TANK" then return "tank" end
	if roleToken == "HEALER" then return "healer" end
	if roleToken == "DAMAGER" then
		if specID and RANGED_DPS_SPEC_IDS[specID] then return "ranged" end
		return "melee"
	end
	return nil
end

local function getCurrentSpecID()
	local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
	if not specIndex then return addon.variables and addon.variables.unitSpecId or nil end

	local specID
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local info = C_SpecializationInfo.GetSpecializationInfo(specIndex)
		if type(info) == "table" then
			specID = info.specID
		else
			specID = info
		end
	end

	if type(specID) ~= "number" or specID <= 0 then return addon.variables and addon.variables.unitSpecId or nil end
	return specID
end

local function getClassInfoById(classId)
	if GetClassInfo then return GetClassInfo(classId) end
	if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
		local info = C_CreatureInfo.GetClassInfo(classId)
		if info then return info.className, info.classFile, info.classID end
	end
	return nil, nil, nil
end

local function rebuildBagItemCountCache()
	local counts = {}
	local maxBag = tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or tonumber(NUM_BAG_SLOTS) or 4

	if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
		for bag = 0, maxBag do
			local slotCount = C_Container.GetContainerNumSlots(bag) or 0
			for slot = 1, slotCount do
				local info = C_Container.GetContainerItemInfo(bag, slot)
				local itemId = info and tonumber(info.itemID) or nil
				if itemId and itemId > 0 then counts[itemId] = (counts[itemId] or 0) + (tonumber(info.stackCount) or 1) end
			end
		end
	elseif GetContainerNumSlots and GetContainerItemID and GetContainerItemInfo then
		for bag = 0, maxBag do
			local slotCount = GetContainerNumSlots(bag) or 0
			for slot = 1, slotCount do
				local itemId = tonumber(GetContainerItemID(bag, slot))
				if itemId and itemId > 0 then
					local _, stackCount = GetContainerItemInfo(bag, slot)
					counts[itemId] = (counts[itemId] or 0) + (tonumber(stackCount) or 1)
				end
			end
		end
	end

	addon.Flasks.bagItemCountCache = counts
	addon.Flasks.bagItemCountCacheReady = true
	return counts
end

local function getBagItemCountCache()
	if addon.Flasks.bagItemCountCacheReady == true and type(addon.Flasks.bagItemCountCache) == "table" then return addon.Flasks.bagItemCountCache end
	return rebuildBagItemCountCache()
end

local function getDirectBagItemCount(itemId)
	local targetId = tonumber(itemId)
	if not targetId or targetId <= 0 then return 0 end

	local cache = getBagItemCountCache()
	return tonumber(cache[targetId]) or 0
end

local function getBestItemCount(itemId)
	local targetId = tonumber(itemId)
	if not targetId or targetId <= 0 then return 0, 0, 0 end

	local countApi = 0
	local countBag = getDirectBagItemCount(targetId)

	if GetItemCount then
		local direct = tonumber(GetItemCount(targetId, false, false)) or 0
		local defaultArgs = tonumber(GetItemCount(targetId)) or 0
		if direct > countApi then countApi = direct end
		if defaultArgs > countApi then countApi = defaultArgs end
	end

	if C_Item and C_Item.GetItemCount then
		local cNoBank = tonumber(C_Item.GetItemCount(targetId, false, false)) or 0
		local cDefault = tonumber(C_Item.GetItemCount(targetId)) or 0
		if cNoBank > countApi then countApi = cNoBank end
		if cDefault > countApi then countApi = cDefault end
	end

	local best = countApi
	if countBag > best then best = countBag end
	return best, countApi, countBag
end

local function isEntryAvailable(entry, playerLevel)
	if not entry or not entry.id then return false end
	if (entry.requiredLevel or 1) > playerLevel then return false end

	-- Do not gate candidate detection on C_Item.IsUsableItem().
	-- Some flask items report unusable in states where they are still valid reminders.
	local count = getBestItemCount(entry.id)
	return count > 0
end

local function appendAvailable(list, playerLevel, out)
	if not list then return end
	for i = 1, #list do
		local entry = list[i]
		if isEntryAvailable(entry, playerLevel) then out[#out + 1] = entry end
	end
end

function addon.Flasks.functions.getPlayerSpecs()
	local specs = {}
	local classID = addon.variables and addon.variables.unitClassID
	if not classID or not GetNumSpecializationsForClassID or not GetSpecializationInfoForClassID then return specs end

	local specCount = GetNumSpecializationsForClassID(classID) or 0
	for i = 1, specCount do
		local specID, specName = GetSpecializationInfoForClassID(classID, i)
		if specID then specs[#specs + 1] = {
			id = specID,
			name = specName or ("Spec " .. tostring(specID)),
		} end
	end
	return specs
end

function addon.Flasks.functions.getAllSpecs()
	local specs = {}
	local roleBucketBySpec = {}
	local getSpecCount = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID) or GetNumSpecializationsForClassID
	if not getSpecCount or not GetSpecializationInfoForClassID or not GetNumClasses then return addon.Flasks.functions.getPlayerSpecs() end

	local sex = UnitSex and UnitSex("player") or nil
	local numClasses = GetNumClasses() or 0
	for classIndex = 1, numClasses do
		local className, classToken, classID = getClassInfoById(classIndex)
		if classID then
			local specCount = getSpecCount(classID) or 0
			for specIndex = 1, specCount do
				local specID, specName, _, _, roleToken = GetSpecializationInfoForClassID(classID, specIndex, sex)
				if specID then
					local roleBucket = getRoleBucketFromRoleToken(roleToken, specID)
					roleBucketBySpec[specID] = roleBucket
					local specLabel = specName or ("Spec " .. tostring(specID))
					local classLabel = className or classToken
					if classLabel and classLabel ~= "" then specLabel = classLabel .. " - " .. specLabel end
					tinsert(specs, {
						id = specID,
						name = specName or ("Spec " .. tostring(specID)),
						label = specLabel,
						className = className or classToken,
						classToken = classToken,
						classID = classID,
						roleToken = roleToken,
						roleBucket = roleBucket,
					})
				end
			end
		end
	end

	if #specs == 0 then return addon.Flasks.functions.getPlayerSpecs() end

	tsort(specs, function(a, b)
		local aClass = tostring((a and a.className) or "")
		local bClass = tostring((b and b.className) or "")
		if aClass ~= bClass then return aClass < bClass end
		local aSpec = tostring((a and a.name) or "")
		local bSpec = tostring((b and b.name) or "")
		if aSpec ~= bSpec then return aSpec < bSpec end
		return (tonumber(a and a.id) or 0) < (tonumber(b and b.id) or 0)
	end)

	addon.Flasks.specRoleBucketByID = roleBucketBySpec

	return specs
end

function addon.Flasks.functions.getRoleBucketForSpec(specID)
	if type(specID) ~= "number" then return nil end

	local roleBucket = addon.Flasks.specRoleBucketByID and addon.Flasks.specRoleBucketByID[specID]
	roleBucket = normalizeRoleKey(roleBucket)
	if roleBucket then return roleBucket end

	if addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.getAllSpecs then
		addon.Flasks.functions.getAllSpecs()
		roleBucket = addon.Flasks.specRoleBucketByID and addon.Flasks.specRoleBucketByID[specID]
		roleBucket = normalizeRoleKey(roleBucket)
		if roleBucket then return roleBucket end
	end

	if addon.variables and addon.variables.unitSpecId == specID then return getRoleBucketFromRoleToken(addon.variables.unitRole, specID) end

	return nil
end

local function getEffectiveRoleBucketForSpec(specID)
	local roleBucket = addon.Flasks.functions.getRoleBucketForSpec and addon.Flasks.functions.getRoleBucketForSpec(specID) or nil
	roleBucket = normalizeRoleKey(roleBucket)
	if roleBucket then return roleBucket end

	roleBucket = addon.variables and getRoleBucketFromRoleToken(addon.variables.unitRole, specID) or nil
	roleBucket = normalizeRoleKey(roleBucket)
	if roleBucket then return roleBucket end

	if UnitGroupRolesAssigned then
		local assignedRole = UnitGroupRolesAssigned("player")
		roleBucket = getRoleBucketFromRoleToken(assignedRole, specID)
		roleBucket = normalizeRoleKey(roleBucket)
		if roleBucket then return roleBucket end
	end

	if GetSpecializationRole and C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		local specIndex = C_SpecializationInfo.GetSpecialization()
		if specIndex then
			local specRole = GetSpecializationRole(specIndex)
			roleBucket = getRoleBucketFromRoleToken(specRole, specID)
			roleBucket = normalizeRoleKey(roleBucket)
			if roleBucket then return roleBucket end
		end
	end

	return nil
end

function addon.Flasks.functions.getTypeDisplayName(typeKey)
	local entries = addon.Flasks and addon.Flasks.typeFlasks and addon.Flasks.typeFlasks[typeKey]
	if type(entries) == "table" then
		for i = 1, #entries do
			local label = entries[i] and entries[i].label
			if type(label) == "string" and label ~= "" then return label end
		end

		local seen = {}
		local uniqueNames = {}
		for i = 1, #entries do
			local itemID = entries[i] and entries[i].id
			if itemID then
				local itemName = nil
				if C_Item_GetItemNameByID then itemName = C_Item_GetItemNameByID(itemID) end
				if (not itemName or itemName == "") and C_Item_GetItemInfo then itemName = C_Item_GetItemInfo(itemID) end
				if itemName and itemName ~= "" and not seen[itemName] then
					seen[itemName] = true
					uniqueNames[#uniqueNames + 1] = itemName
					if #uniqueNames >= 2 then break end
				elseif C_Item_RequestLoadItemDataByID then
					C_Item_RequestLoadItemDataByID(itemID)
				end
			end
		end

		if #uniqueNames >= 2 then return uniqueNames[1] .. " / " .. uniqueNames[2] end
		if #uniqueNames == 1 then return uniqueNames[1] end
	end

	if addon.Flasks and addon.Flasks.typeLabels and addon.Flasks.typeLabels[typeKey] then return addon.Flasks.typeLabels[typeKey] end
	return tostring(typeKey or "")
end

function addon.Flasks.functions.normalizeTypeKey(value) return normalizeTypeKey(value) end

function addon.Flasks.functions.getAvailableCandidatesForSpec(specID)
	local playerLevel = UnitLevel("player") or 0
	local candidates = {}
	local selectedType = "none"
	local selectedPreference = "useRole"
	local selectedRoleKey = nil

	local db = addon.db or {}

	if db.flaskPreferredBySpec and specID and db.flaskPreferredBySpec[specID] ~= nil then selectedPreference = db.flaskPreferredBySpec[specID] end
	if selectedPreference == "useRole" then
		selectedRoleKey = getEffectiveRoleBucketForSpec(specID)
		local roleSelection = db.flaskPreferredByRole and selectedRoleKey and db.flaskPreferredByRole[selectedRoleKey] or nil
		selectedType = normalizeTypeKey(roleSelection)
	else
		selectedType = normalizeTypeKey(selectedPreference)
	end

	if db.flaskPreferCauldrons then
		-- "Prefer Cauldrons" maps to fleeting flasks in this implementation.
		if selectedType ~= "none" then
			local fleetingList = addon.Flasks.fleetingTypeFlasks and addon.Flasks.fleetingTypeFlasks[selectedType]
			appendAvailable(fleetingList, playerLevel, candidates)
		end
	end
	if selectedType ~= "none" then
		local normalList = addon.Flasks.typeFlasks[selectedType]
		appendAvailable(normalList, playerLevel, candidates)
	end

	return candidates, selectedType, selectedRoleKey, selectedPreference
end

function addon.Flasks.functions.updateAllowedFlasks(specID)
	local resolvedSpecID = specID or getCurrentSpecID()
	local candidates, selectedType, selectedRoleKey, selectedPreference = addon.Flasks.functions.getAvailableCandidatesForSpec(resolvedSpecID)
	addon.Flasks.filteredFlasks = candidates
	addon.Flasks.lastSpecID = resolvedSpecID
	addon.Flasks.lastSelectedType = selectedType
	addon.Flasks.lastSelectedRole = selectedRoleKey
	addon.Flasks.lastSelectedPreference = selectedPreference
	return candidates, selectedType
end

addon.Flasks.functions.rebuildBagItemCountCache = rebuildBagItemCountCache

local bagItemCountCacheFrame = addon.Flasks.bagItemCountCacheFrame or CreateFrame("Frame")
addon.Flasks.bagItemCountCacheFrame = bagItemCountCacheFrame
bagItemCountCacheFrame:RegisterEvent("PLAYER_LOGIN")
bagItemCountCacheFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bagItemCountCacheFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagItemCountCacheFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then rebuildBagItemCountCache() end
end)
