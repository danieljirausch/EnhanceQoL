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
local LSM = LibStub("LibSharedMedia-3.0")

local frameLoad = CreateFrame("Frame")

local brButton
local brAnchor
local defaultButtonSize = 60
local defaultFontSize = 16

local EditMode = addon.EditMode
local BR_EDITMODE_ID = "mythicPlusBRTracker"
local brEditModeRegistered = false

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

local function buildBRLayoutSnapshot()
	return {
		point = addon.db["mythicPlusBRTrackerPoint"] or "CENTER",
		relativePoint = addon.db["mythicPlusBRTrackerPoint"] or "CENTER",
		x = addon.db["mythicPlusBRTrackerX"] or 0,
		y = addon.db["mythicPlusBRTrackerY"] or 0,
		size = addon.db["mythicPlusBRButtonSize"] or defaultButtonSize,
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

	local point = config.point or "CENTER"
	local relativePoint = config.relativePoint or point
	local x = config.x or 0
	local y = config.y or 0
	local size = config.size or defaultButtonSize

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
					minValue = 20,
					maxValue = 100,
					valueStep = 1,
					default = addon.db["mythicPlusBRButtonSize"] or defaultButtonSize,
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

ensureBRAnchor()

local function setBRInfo(info)
	if brButton and brButton.cooldownFrame and info then
		local current = info.currentCharges
		local max = info.maxCharges

		if issecretvalue and issecretvalue(current) then
			brButton.cooldownFrame:SetCooldown(info.cooldownStartTime, info.cooldownDuration, info.chargeModRate)
			brButton.cooldownFrame.startTime = info.cooldownStartTime
			brButton.cooldownFrame.charges = C_StringUtil.TruncateWhenZero(current)

			-- TODO actually no way to do saturation stuff in m+/raid in midnight
			-- if current > 0 then
			brButton.charges:SetTextColor(0, 1, 0)
			brButton.icon:SetDesaturated(false)
			brButton.cooldownFrame:SetSwipeColor(0, 0, 0, 0.3)
			brButton.charges:Show()
			-- else
			-- 	brButton.cooldownFrame:SetSwipeColor(0, 0, 0, 1)
			-- 	brButton.icon:SetDesaturated(true)
			-- 	brButton.charges:SetTextColor(1, 0, 0)
			-- 	brButton.charges:Hide()
			-- end
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
	elseif event == "ENCOUNTER_START" then
		local _, _, diff = GetInstanceInfo()
		if isRaidDifficulty(diff) and shouldShowBRTracker() then
			if not brButton or not brButton.cooldownFrame then createBRFrame() end
			local info = C_Spell.GetSpellCharges(20484)
			setBRInfo(info)
		end
	elseif event == "ENCOUNTER_END" then
		-- In raids we hide after encounter; in M+ we keep showing
		if not shouldShowBRTracker() then removeBRFrame() end
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

	if addon.db["mythicPlusEnableDungeonFilter"] then addon.MythicPlus.functions.addDungeonFilter() end
end
