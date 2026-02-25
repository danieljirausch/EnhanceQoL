local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local ENHANCEMENT_SPEC_ID = 263
local MAX_STACKS = 10
local SEGMENT_COUNT = 5
local RESOURCE_ID = "maelstromWeapon"
local POINT_SIZE = 20
local POINT_SPACING = 4
local BG_ATLAS = "UF-DruidCP-BG-Dis"
local SWIRL_TEXTURE = "Interface\\AddOns\\EnhanceQoL\\Assets\\SwirlShaman.tga"
local LIGHTNING_FRAMES = {
	"Interface\\AddOns\\EnhanceQoL\\Assets\\SL0.tga",
	"Interface\\AddOns\\EnhanceQoL\\Assets\\SL1.tga",
	"Interface\\AddOns\\EnhanceQoL\\Assets\\SL2.tga",
	"Interface\\AddOns\\EnhanceQoL\\Assets\\SL3.tga",
	"Interface\\AddOns\\EnhanceQoL\\Assets\\SL4.tga",
}
local LIGHTNING_FRAME_TIME = 0.06
local LIGHTNING_ALPHA_MIN = 0.35
local LIGHTNING_ALPHA_MAX = 1.0
local LIGHTNING_SCALE = 1.25
local HIGH_BURST_IN = 0.06
local HIGH_BURST_OUT = 0.18
local HIGH_BURST_ALPHA = 1.0
local HIGH_BURST_SETTLE = 0.6

local min = math.min
local max = math.max
local NewTimer = C_Timer and C_Timer.NewTimer

local function isShaman()
	local _, class = UnitClass("player")
	return class == "SHAMAN"
end

local function isUFPlayerEnabled()
	local cfg = addon.db and addon.db.ufFrames and addon.db.ufFrames.player
	if not (cfg and cfg.enabled == true) then return false end
	local resourceCfg = cfg.classResource
	if resourceCfg and resourceCfg.enabled == false then return false end
	local resourceEntries = resourceCfg and resourceCfg.resources
	local maelstromCfg = type(resourceEntries) == "table" and resourceEntries[RESOURCE_ID] or nil
	if type(maelstromCfg) == "table" and maelstromCfg.enabled == false then return false end
	return true
end

local function shouldBuildBar() return isShaman() and isUFPlayerEnabled() end

local function getCurrentSpecId()
	if not (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecializationInfo) then return nil end
	local specIndex = C_SpecializationInfo.GetSpecialization()
	if type(specIndex) ~= "number" or specIndex <= 0 then return nil end
	local specId = C_SpecializationInfo.GetSpecializationInfo(specIndex)
	if type(specId) == "table" then specId = specId.specID end
	if type(specId) ~= "number" then return nil end
	return specId
end

local function getMaelstromWeaponStacksFromResourceBars()
	local rb = addon and addon.Aura and addon.Aura.ResourceBars
	if not (rb and rb.GetAuraPowerCounts) then return 0 end

	local stacks = rb.GetAuraPowerCounts("MAELSTROM_WEAPON")
	if type(stacks) ~= "number" then return 0 end
	return stacks
end

local function resetPointVisuals(self)
	if self.StopLightning then self:StopLightning() end
	if self.highBurstAnim then self.highBurstAnim:Stop() end
	if self._highPulseTimer then
		self._highPulseTimer:Cancel()
		self._highPulseTimer = nil
	end
	if self.activateAnim then self.activateAnim:Stop() end
	if self.deactivateAnim then self.deactivateAnim:Stop() end
	if self.highPulseAnim then self.highPulseAnim:Stop() end

	if self.Swirl then
		self.Swirl:SetAlpha(0)
		self.Swirl:SetRotation(0)
	end
	if self.SwirlGlow then self.SwirlGlow:SetAlpha(0) end
	if self.HighGlow then self.HighGlow:SetAlpha(0) end
	if self.Lightning then
		self.Lightning:SetAlpha(0)
		self.Lightning:Hide()
	end
end

local function setPointState(self, state)
	if self.state == state then return end

	self.state = state
	self:ResetVisuals()

	if state == "empty" then
		if self.deactivateAnim then self.deactivateAnim:Play() end
		return
	end

	if state == "high" and self.highPulseAnim then
		if self.highBurstAnim then self.highBurstAnim:Play() end
		self.highPulseAnim:Stop()
		self._highPulseTimer = C_Timer.NewTimer(0.12, function()
			if self.state == "high" and self.highPulseAnim then self.highPulseAnim:Play() end
		end)
	end

	if self.activateAnim then self.activateAnim:Play() end

	if state == "high" and self.PlayLightning then self:PlayLightning(0.05) end
end

local function stopLightning(self)
	if self._lightningTicker then
		self._lightningTicker:Cancel()
		self._lightningTicker = nil
	end
	if self._lightningTimer then
		self._lightningTimer:Cancel()
		self._lightningTimer = nil
	end
	if self.Lightning then
		self.Lightning:SetAlpha(0)
		self.Lightning:Hide()
		if LIGHTNING_FRAMES[1] then self.Lightning:SetTexture(LIGHTNING_FRAMES[1]) end
	end
end

local function playLightning(self, delay)
	if not self.Lightning or #LIGHTNING_FRAMES == 0 then return end

	self:StopLightning()

	local function start()
		local frameCount = #LIGHTNING_FRAMES
		local idx = 1

		self.Lightning:SetTexture(LIGHTNING_FRAMES[idx])
		self.Lightning:SetAlpha(LIGHTNING_ALPHA_MIN)
		self.Lightning:Show()

		if frameCount == 1 then
			self.Lightning:SetAlpha(LIGHTNING_ALPHA_MAX)
			return
		end

		self._lightningTicker = C_Timer.NewTicker(LIGHTNING_FRAME_TIME, function()
			if not self.Lightning then return end

			idx = idx + 1
			if idx >= frameCount then
				self.Lightning:SetTexture(LIGHTNING_FRAMES[frameCount])
				self.Lightning:SetAlpha(LIGHTNING_ALPHA_MAX)
				if self._lightningTicker then
					self._lightningTicker:Cancel()
					self._lightningTicker = nil
				end
				return
			end

			self.Lightning:SetTexture(LIGHTNING_FRAMES[idx])
			local progress = (idx - 1) / (frameCount - 1)
			local alpha = LIGHTNING_ALPHA_MIN + (LIGHTNING_ALPHA_MAX - LIGHTNING_ALPHA_MIN) * progress
			self.Lightning:SetAlpha(alpha)
		end)
	end

	if delay and delay > 0 then
		self._lightningTimer = C_Timer.NewTimer(delay, start)
	else
		start()
	end
end

local function createPointAnimations(point)
	local activate = point:CreateAnimationGroup()
	activate:SetToFinalAlpha(true)
	point.activateAnim = activate

	local swirlAlpha = activate:CreateAnimation("Alpha")
	swirlAlpha:SetTarget(point.Swirl)
	swirlAlpha:SetFromAlpha(0)
	swirlAlpha:SetToAlpha(1)
	swirlAlpha:SetDuration(0.18)
	swirlAlpha:SetOrder(1)

	local swirlScale = activate:CreateAnimation("Scale")
	swirlScale:SetTarget(point.Swirl)
	swirlScale:SetScaleFrom(0.5, 0.5)
	swirlScale:SetScaleTo(1, 1)
	swirlScale:SetDuration(0.25)
	swirlScale:SetOrder(1)
	swirlScale:SetSmoothing("OUT")

	local swirlRot = activate:CreateAnimation("Rotation")
	swirlRot:SetTarget(point.Swirl)
	swirlRot:SetDegrees(-360)
	swirlRot:SetDuration(0.6)
	swirlRot:SetOrder(1)
	swirlRot:SetSmoothing("OUT")

	local glowIn = activate:CreateAnimation("Alpha")
	glowIn:SetTarget(point.SwirlGlow)
	glowIn:SetFromAlpha(0)
	glowIn:SetToAlpha(0.6)
	glowIn:SetDuration(0.08)
	glowIn:SetOrder(1)

	local glowOut = activate:CreateAnimation("Alpha")
	glowOut:SetTarget(point.SwirlGlow)
	glowOut:SetFromAlpha(0.6)
	glowOut:SetToAlpha(0)
	glowOut:SetStartDelay(0.08)
	glowOut:SetDuration(0.2)
	glowOut:SetOrder(1)

	local deactivate = point:CreateAnimationGroup()
	deactivate:SetToFinalAlpha(true)
	point.deactivateAnim = deactivate

	local swirlFade = deactivate:CreateAnimation("Alpha")
	swirlFade:SetTarget(point.Swirl)
	swirlFade:SetFromAlpha(1)
	swirlFade:SetToAlpha(0)
	swirlFade:SetDuration(0.12)
	swirlFade:SetOrder(1)

	local glowFade = deactivate:CreateAnimation("Alpha")
	glowFade:SetTarget(point.SwirlGlow)
	glowFade:SetFromAlpha(0.2)
	glowFade:SetToAlpha(0)
	glowFade:SetDuration(0.12)
	glowFade:SetOrder(1)

	local pulse = point:CreateAnimationGroup()
	pulse:SetLooping("REPEAT")
	point.highPulseAnim = pulse

	local pulseIn = pulse:CreateAnimation("Alpha")
	pulseIn:SetTarget(point.HighGlow)
	pulseIn:SetFromAlpha(0.25)
	pulseIn:SetToAlpha(0.6)
	pulseIn:SetDuration(0.6)
	pulseIn:SetOrder(1)

	local pulseOut = pulse:CreateAnimation("Alpha")
	pulseOut:SetTarget(point.HighGlow)
	pulseOut:SetFromAlpha(0.6)
	pulseOut:SetToAlpha(0.25)
	pulseOut:SetDuration(0.6)
	pulseOut:SetOrder(2)

	local burst = point:CreateAnimationGroup()
	burst:SetToFinalAlpha(true)
	point.highBurstAnim = burst

	local burstIn = burst:CreateAnimation("Alpha")
	burstIn:SetTarget(point.HighGlow)
	burstIn:SetFromAlpha(0)
	burstIn:SetToAlpha(HIGH_BURST_ALPHA)
	burstIn:SetDuration(HIGH_BURST_IN)
	burstIn:SetOrder(1)

	local burstOut = burst:CreateAnimation("Alpha")
	burstOut:SetTarget(point.HighGlow)
	burstOut:SetFromAlpha(HIGH_BURST_ALPHA)
	burstOut:SetToAlpha(HIGH_BURST_SETTLE)
	burstOut:SetDuration(HIGH_BURST_OUT)
	burstOut:SetOrder(2)
end

local function createPoint(parent)
	local point = CreateFrame("Frame", nil, parent)
	point:SetSize(POINT_SIZE, POINT_SIZE)

	point.BG = point:CreateTexture(nil, "BACKGROUND")
	point.BG:SetAtlas(BG_ATLAS, true)
	point.BG:SetPoint("CENTER")

	point.Swirl = point:CreateTexture(nil, "ARTWORK")
	point.Swirl:SetTexture(SWIRL_TEXTURE)
	point.Swirl:SetAllPoints()
	point.Swirl:SetAlpha(0)

	point.SwirlGlow = point:CreateTexture(nil, "OVERLAY")
	point.SwirlGlow:SetTexture(SWIRL_TEXTURE)
	point.SwirlGlow:SetAllPoints()
	point.SwirlGlow:SetBlendMode("ADD")
	point.SwirlGlow:SetAlpha(0)

	point.HighGlow = point:CreateTexture(nil, "OVERLAY")
	point.HighGlow:SetTexture(SWIRL_TEXTURE)
	point.HighGlow:SetAllPoints()
	point.HighGlow:SetBlendMode("ADD")
	point.HighGlow:SetAlpha(0)

	point.Lightning = point:CreateTexture(nil, "OVERLAY")
	point.Lightning:SetTexture(LIGHTNING_FRAMES[1])
	point.Lightning:SetAllPoints()
	point.Lightning:SetScale(LIGHTNING_SCALE)
	point.Lightning:SetBlendMode("ADD")
	point.Lightning:SetAlpha(0)
	point.Lightning:Hide()

	createPointAnimations(point)

	point.state = nil
	point.ResetVisuals = resetPointVisuals
	point.SetState = setPointState
	point.StopLightning = stopLightning
	point.PlayLightning = playLightning
	point:ResetVisuals()
	return point
end

local function applyFallbackLayout(self)
	if self:GetNumPoints() > 0 then return end
	if InCombatLockdown and InCombatLockdown() then return end

	local parent = PlayerFrameBottomManagedFramesContainer or PlayerFrame or UIParent
	if parent and self.SetParent then self:SetParent(parent) end
	self:ClearAllPoints()

	if parent and parent.BottomManagedLayoutContainer then
		self:SetPoint("CENTER", parent.BottomManagedLayoutContainer, "CENTER", 0, 0)
	elseif parent == PlayerFrame then
		self:SetPoint("TOP", parent, "BOTTOM", 30, 25)
	else
		self:SetPoint("CENTER", parent, "CENTER", 0, -200)
	end
end

local ShamanMaelstromWeaponBar = {}

function ShamanMaelstromWeaponBar:EnsurePoints()
	if self.points and #self.points == SEGMENT_COUNT then return end

	self.points = {}

	for i = 1, SEGMENT_COUNT do
		local point = createPoint(self)
		if i == 1 then
			point:SetPoint("LEFT", self, "LEFT", 0, 0)
		else
			point:SetPoint("LEFT", self.points[i - 1], "RIGHT", self.spacing, 0)
		end
		point:Show()
		self.points[i] = point
	end

	local width = (SEGMENT_COUNT * POINT_SIZE) + ((SEGMENT_COUNT - 1) * self.spacing)
	self:SetSize(width, POINT_SIZE)
end

function ShamanMaelstromWeaponBar:UpdatePower()
	if not self.points or #self.points == 0 then self:EnsurePoints() end

	local stacks = min(getMaelstromWeaponStacksFromResourceBars(), MAX_STACKS)
	if self._lastStacks == stacks then return end
	self._lastStacks = stacks

	local lowCount = min(stacks, SEGMENT_COUNT)
	local highCount = max(stacks - SEGMENT_COUNT, 0)

	for i = 1, SEGMENT_COUNT do
		local point = self.points[i]
		if point then
			if i <= highCount then
				point:SetState("high")
			elseif i <= lowCount then
				point:SetState("low")
			else
				point:SetState("empty")
			end
		end
	end
end

function ShamanMaelstromWeaponBar:ShouldShowForCurrentSpec() return shouldBuildBar() and getCurrentSpecId() == ENHANCEMENT_SPEC_ID end

function ShamanMaelstromWeaponBar:ScheduleSetup(delay)
	if self._setupTimer then
		self._setupTimer:Cancel()
		self._setupTimer = nil
	end

	if not NewTimer then
		self:Setup()
		return
	end

	self._setupTimer = NewTimer(delay or 0.2, function()
		self._setupTimer = nil
		self:Setup()
	end)
end

function ShamanMaelstromWeaponBar:Setup()
	local showBar = self:ShouldShowForCurrentSpec()

	if showBar then
		self.unit = "player"
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:EnsurePoints()
		self:UpdatePower()
		applyFallbackLayout(self)
		local parent = self:GetParent()
		if parent and parent.GetFrameLevel then self:SetFrameLevel((parent:GetFrameLevel() or 0) + 5) end
	else
		self:UnregisterEvent("UNIT_AURA")
		if self.points then
			for i = 1, #self.points do
				local point = self.points[i]
				if point and point.ResetVisuals then point:ResetVisuals() end
			end
		end
	end

	self:SetShown(showBar)
	return showBar
end

function ShamanMaelstromWeaponBar:OnEvent(event, ...)
	if event == "UNIT_AURA" then
		local unit, info = ...
		if unit == "player" then
			local rb = addon and addon.Aura and addon.Aura.ResourceBars
			if rb and rb.UpdateAuraPowerState then rb.UpdateAuraPowerState(info) end
			self:UpdatePower()
		end
		return
	end

	if event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		if unit and unit ~= "player" then return end
		self:ScheduleSetup(0.2)
		return
	end

	if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
		self:ScheduleSetup(0.2)
		return
	end

	self:Setup()
end

local function ensureBarFrame()
	if not shouldBuildBar() then return nil, false end

	local frame = _G.ShamanMaelstromWeaponBarFrame
	local created = false
	if not frame then
		frame = CreateFrame("Frame", "ShamanMaelstromWeaponBarFrame", PlayerFrame or UIParent)
		created = true
	end

	Mixin(frame, ShamanMaelstromWeaponBar)
	frame.spacing = frame.spacing or POINT_SPACING
	frame._lastStacks = 0
	frame.ignoreFramePositionManager = true
	frame.eqolShouldShowClassResource = function(self) return self:ShouldShowForCurrentSpec() end

	frame:SetScript("OnEvent", frame.OnEvent)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_TALENT_UPDATE")
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
	frame:Setup()

	return frame, created
end

local hooksSet = false
local function refreshBar()
	if not isShaman() then return end

	if not isUFPlayerEnabled() then
		local frame = _G.ShamanMaelstromWeaponBarFrame
		if frame then
			if frame._setupTimer then
				frame._setupTimer:Cancel()
				frame._setupTimer = nil
			end
			frame:UnregisterEvent("UNIT_AURA")
			frame:SetShown(false)
		end
		return
	end

	local frame, created = ensureBarFrame()
	if not frame then return end

	frame:Setup()

	if created and addon.Aura and addon.Aura.UF and addon.Aura.UF.RefreshUnit and not (InCombatLockdown and InCombatLockdown()) then addon.Aura.UF.RefreshUnit("player") end
end

local function setupHooks()
	if hooksSet or not isShaman() then return end
	hooksSet = true

	local uf = addon.Aura and addon.Aura.UF
	if not (uf and hooksecurefunc) then return end

	if uf.Enable then hooksecurefunc(uf, "Enable", refreshBar) end
	if uf.Disable then hooksecurefunc(uf, "Disable", refreshBar) end
	if uf.Refresh then hooksecurefunc(uf, "Refresh", refreshBar) end
end

setupHooks()
refreshBar()
