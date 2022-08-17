CombatTimer = LibStub("AceAddon-3.0"):NewAddon("CombatTimer", "AceConsole-3.0", "AceEvent-3.0")

local instanceType
local endTime
local externalManaGainTimestamp = 0
local FTE
local dur = 2.02
local durations = {[1] = dur, [2] = dur*2, [3] = dur*3, [4] = dur*4, [5] = dur*5}
local expirationTime = {}
local outOfCombatTime
local oocTime
local UnitAffectingCombat = UnitAffectingCombat
local UnitGUID = UnitGUID
local m_abs = math.abs
local TimeSinceLastUpdate = 0
local ONUPDATE_INTERVAL = 0.05
local fakeTick

function CombatTimer:OnInitialize()
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("CombatTimerDB", self:GetDefaultConfig())
	self.media = LibStub:GetLibrary("LibSharedMedia-3.0")
	self:SetupOptions()
	
	--monitor for zone change
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")
	
	self:CreateDisplay()
	self:UpdateSettings()
end

function CombatTimer:InEnabledZone()
	local type = select(2, IsInInstance())
	return self.db.profile.inside[type]
end

function CombatTimer:OnEnable()
	if( not self:InEnabledZone() ) then
		return
	end

	self:RegisterEvent("PLAYER_REGEN_DISABLED") --entered combat
	self:RegisterEvent("PLAYER_REGEN_ENABLED") --left combat
end

function CombatTimer:OnDisable()
	self:UnregisterAllEvents()
	
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")
	self.frame:Hide()
end

function CombatTimer:Reload()
	self:OnDisable()

	-- Check to see if we should enable it
	if( self:InEnabledZone() ) then
		self:OnEnable()
	end
end

function CombatTimer:TestMode()
--	if not CombatTimer.db.test then return end
	
	self.frame:Show()
	self.frame.text:SetText("TEST")
	self.frame:SetValue(7)
	self.frame:SetStatusBarColor(CombatTimer.db.profile.visual.r, CombatTimer.db.profile.visual.g, CombatTimer.db.profile.visual.b, CombatTimer.db.profile.visual.a)
	self.frame:SetStatusBarTexture(self.media:Fetch(self.media.MediaType.STATUSBAR, self.db.profile.texture))
end

function CombatTimer:PLAYER_REGEN_DISABLED()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("UNIT_POWER_UPDATE")
	self:StartTimer()
end

function CombatTimer:PLAYER_REGEN_ENABLED()
--	local diff = GetTime() - outOfCombatTime
--	debug("OOC", "difference", "GetTime() - estimated outOfCombatTime:", math.abs(diff))
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:UnregisterEvent("UNIT_SPELLCAST_FAILED")
	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("UNIT_POWER_UPDATE")
	self:StopTimer()
end

local eventRegistered = {
	["SWING_DAMAGE"] = true,
	["RANGE_DAMAGE"] = true,
	["SPELL_DAMAGE"] = true,
	["SWING_MISSED"] = true,
	["SPELL_MISSED"] = true,
	["RANGE_MISSED"] = true,
	["SPELL_PERIODIC_DAMAGE"] = true,
	["SPELL_PERIODIC_LEECH"] = true,
	["SPELL_HEAL"] = true,
	["SPELL_CAST_SUCCESS"] = true,
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_AURA_REFRESH"] = true,
	["SPELL_PERIODIC_ENERGIZE"] = true,
	["SPELL_ENERGIZE"] = true,
}

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo;
local COMBATLOG_FILTER_ME = COMBATLOG_FILTER_ME;
local COMBATLOG_FILTER_FRIENDLY_UNITS = COMBATLOG_FILTER_FRIENDLY_UNITS;
local COMBATLOG_FILTER_MY_PET = COMBATLOG_FILTER_MY_PET;
local COMBATLOG_FILTER_HOSTILE_PLAYERS = COMBATLOG_FILTER_HOSTILE_PLAYERS;
local COMBATLOG_FILTER_UNKNOWN_UNITS = COMBATLOG_FILTER_UNKNOWN_UNITS;
local Unitids = { "target", "focus", "party1", "party2", "party3", "party4", "pet", "mouseover" }

local function isInCombat(guid)
	for _, unit in ipairs(Unitids) do
		if UnitGUID(unit) == guid and UnitAffectingCombat(unit) then
			return true
		end
	end
	return false
end

function CombatTimer:COMBAT_LOG_EVENT_UNFILTERED()
	local _, eventType, _, sourceGUID, _, sourceFlags, _, destGUID, _, destFlags, _, spellID = CombatLogGetCurrentEventInfo()
	if not (eventRegistered[eventType]) then return end

	local isDestPlayer = CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_ME)
	local isSourcePlayer = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME)
	local isSourcePet = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MY_PET)
	local isSourceFriend = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_FRIENDLY_UNITS)
	local isDestFriend = CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_FRIENDLY_UNITS)
	local isDestEnemy = CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_HOSTILE_PLAYERS)
	local isSourceEnemy = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_HOSTILE_PLAYERS)
	local isUnknown = CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_UNKNOWN_UNITS)

	-- Mass dispel returns an empty string as destGUID. This is a bad fix, because it will reset timer even when mass dispel does not keep you in combat. Although, when you drop combat the timer stops anyway.
	if (spellID == 32375 and (isSourcePlayer or isSourceEnemy)) then
		self:ResetTimer()
		DEFAULT_CHAT_FRAME:AddMessage("\124cff009cff[CombatTimer]\124r Mass dispel detected: timer might be inaccurate now.")
	end

	-- return if event dest or source is not player.
	if (not isDestPlayer and not isSourcePlayer and not isSourcePet) then
		return
	end

	-- if DestGUID is unknown
	if isSourcePlayer and isUnknown then
		return
	end

	-- Pet attacks keep the summoner in combat, while some pet cd's do not (mind blowing logic).
	-- The entire duration of "Seduction" the warlock does not drop combat. That means ooc is 8+ sec which will bug timer. A solution would be to reset timer on "SPELL_AURA_REMOVED" when seduction ends.
	if (isSourcePet and spellID ~= 6358 and (not (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE") or self.Pets[spellID])) then
		return
	end

	-- Don't reset timer on throwing. We have another event handling the reset.
	if ((eventType == "RANGE_DAMAGE" or eventType == "SPELL_CAST_SUCCESS") and isSourcePlayer and (spellID == 2764 or spellID == 3018)) then
		return
	end

	-- When you dodge/parry/resist etc an attack you drop combat
	if eventType == "SWING_MISSED" and isDestPlayer then
		return
	end

	if (eventType == "SPELL_PERIODIC_ENERGIZE" or eventType == "SPELL_ENERGIZE") then
		if isDestPlayer then
			externalManaGainTimestamp = GetTime()
		end
		return
	end

	--return if player heals or dispels out of combat friendly target. Holy Nova doesn't keep combat when it heals a friendly (intended?)
	 if (eventType == "SPELL_HEAL" or
		eventType == "SPELL_AURA_APPLIED" or
		eventType == "SPELL_CAST_SUCCESS" or
		eventType == "SPELL_AURA_REFRESH") then
		if isSourcePlayer and (self.Nova[spellID] or (isDestFriend and not isInCombat(destGUID))) then
			return
		end
	 end

	-- Healing self or enemy does not put combat
	if eventType == "SPELL_HEAL" and (isDestPlayer or (isSourcePlayer and isDestEnemy)) then
		return
	end

	--return if player only gets dispelled or buffed by someone/self
	if ((eventType == "SPELL_AURA_APPLIED" or
		eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_AURA_REFRESH") and (isDestPlayer and (isSourceFriend or isSourcePlayer))) then
			return
	end

	-- return if periodic damage is not a channeling spell
	if eventType == "SPELL_PERIODIC_DAMAGE" then
		if (spellID ~= nil and not self.Channeling[spellID]) or isSourcePlayer then
			return
		end
	end

	-- E.g. shout spams trigger refresh eventtype
	if eventType == "SPELL_AURA_REFRESH" then
		if ((not isSourceEnemy and not isDestPlayer) or spellID == 3600) then
			return
		end
	end

	-- Helfire doesn't put combat nor keeps combat
	if (isSourcePlayer and (spellID == 5857 or spellID == 11681 or spellID == 27214 or spellID == 11684)) then 
		return 
	end

	--return if the event is listed in our quirk table
	if ((spellID ~= nil) and (self.Quirks[spellID])) then
		return;
	end
	
	--reset timer because player participated in combat
	self:ResetTimer()
end

function CombatTimer:StartTimer()
	self:ResetTimer()
	self.frame:SetScript("OnUpdate", CombatTimer.onUpdate)
	self.frame:Show()
end

function CombatTimer:StopTimer()
	self.frame:SetScript("OnUpdate", nil)
	self.frame:SetValue(0)
	self.frame:SetAlpha(1.0)
	
	self.frame.text:SetText("ooc")
	
	if (self.db.profile.hideTimer and self.db.profile.lock) then
		self.frame:Hide()
	end
end

local last_value = 0
local last_tick = GetTime()

function CombatTimer:ResetTimer()
	endTime = GetTime()
	self.frame:SetStatusBarColor(CombatTimer.db.profile.visual.r, CombatTimer.db.profile.visual.g, CombatTimer.db.profile.visual.b, CombatTimer.db.profile.visual.a)
end

function CombatTimer.onUpdate(self, elapsed)
	local now = GetTime()
	TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed

	if TimeSinceLastUpdate >= ONUPDATE_INTERVAL then
		TimeSinceLastUpdate = 0
		if endTime and (endTime <= now) then
			outOfCombatTime = endTime + 5
			oocTime = outOfCombatTime - now
			for _,v in ipairs(expirationTime) do
				if v >= outOfCombatTime and m_abs(outOfCombatTime - v) <= dur then
					outOfCombatTime = v
					oocTime = v - now
					break
				end
			end
		end

		local passed = oocTime

		CombatTimer.frame:SetValue(passed)
		CombatTimer.frame:SetStatusBarColor(CombatTimer.db.profile.visual.r, CombatTimer.db.profile.visual.g, CombatTimer.db.profile.visual.b, CombatTimer.db.profile.visual.a)

		local alpha 
		if (oocTime > CombatTimer.db.profile.fadeInStart) then
			alpha = 0
		elseif (oocTime < CombatTimer.db.profile.fadeInEnd) then
			alpha = 1
		else
			alpha = 1 / (CombatTimer.db.profile.fadeInStart - CombatTimer.db.profile.fadeInEnd) * (CombatTimer.db.profile.fadeInStart - oocTime)
		end
		
		CombatTimer.frame:SetAlpha(alpha)
			
		CombatTimer.frame.text:SetText(string.format("%.1f", oocTime >= 0 and oocTime or 0))

		if FTE == true then
			CombatTimer:ResetTimer()
		end
	end
end

--see if we should enable CombatTimer in this zone
function CombatTimer:ZONE_CHANGED_NEW_AREA()
	local type = select(2, IsInInstance())

	if( type ~= instanceType ) then
		-- Check if it's supposed to be enabled in this zone
		if( self.db.profile.inside[type] ) then
			self:OnEnable()
		else
			self:OnDisable()
		end
	end
	
	instanceType = type
	FTE = false
end

function CombatTimer:UNIT_AURA()
	if AuraUtil.FindAuraByName(GetSpellInfo(13810), "player", "HARMFUL") then
		FTE = true
	else
		FTE = false
	end
end

function CombatTimer:UNIT_SPELLCAST_SUCCEEDED(event, unit, _, _, spellID)
	if unit ~= "player" then return end

	-- UNIT_POWER_UPDATE event fires on spells that change the energy. We must register these as fake ticks, because all we care for is the "natural" regen that fires off every 2 seconds.

	fakeTick = true

	-- Testing throw on target dummies sometimes doesn't invoke "SPELL_CAST_SUCCESS" subevent.
	if spellID == 2764 or spellID == 3018 then
		self:ResetTimer()
	end
end

function CombatTimer:UNIT_SPELLCAST_FAILED(event, unit)
	if unit ~= "player" then return end

	-- UNIT_POWER_UPDATE event can be forcefully triggered by this event. We don't want that
	fakeTick = true
end


function CombatTimer:UNIT_POWER_UPDATE(event, unitTarget, powerType)
	if unitTarget ~= "player" or powerType == "COMBO_POINTS" then return end

	local currentEnergy = UnitPower("player", 3)
	local maxEnergy = UnitPowerMax("player", 3)
	local currentMana = UnitPower("player", 0)
	local type = UnitPowerType("player")
	local now = GetTime()

	if fakeTick == true then
		fakeTick = false
		return
	end

	if type == 3 then
		if now - externalManaGainTimestamp < 0.02 then
			externalManaGainTimestamp = 0
			return
		end
		if (((currentEnergy == last_value + 20 or
				currentEnergy == last_value + 21 or
				currentEnergy == last_value + 40 or
				currentEnergy == last_value + 41) and
				currentEnergy ~= maxEnergy) or (now >= last_tick + dur)) then
			expirationTime[1] = now + durations[1]
			expirationTime[2] = now + durations[2]
			expirationTime[3] = now + durations[3]
			expirationTime[4] = now + durations[4]
			expirationTime[5] = now + durations[5]
			last_tick = now
		end
		last_value = currentEnergy
	elseif type == 0 then
		if now - externalManaGainTimestamp < 0.02 then
			externalManaGainTimestamp = 0
			return
		end
		if (currentMana > last_value) or (now >= last_tick + dur) then
			expirationTime[1] = now + durations[1]
			expirationTime[2] = now + durations[2]
			expirationTime[3] = now + durations[3]
			expirationTime[4] = now + durations[4]
			expirationTime[5] = now + durations[5]
			last_tick = now
		end
		last_value = currentMana
	end
end

-- Dragging functions
local function OnDragStart(self)
	self.isMoving = true
	self:StartMoving()
end

local function OnDragStop(self)
	if( self.isMoving ) then
		self.isMoving = nil
		self:StopMovingOrSizing()
		
		if( not CombatTimer.db.profile.position ) then
			CombatTimer.db.profile.position = { x = 0, y = 0 }
		end
		
		CombatTimer.db.profile.position.x = self:GetLeft() * CombatTimer.db.profile.scale
		CombatTimer.db.profile.position.y = self:GetTop() * CombatTimer.db.profile.scale
	end
end

function CombatTimer:SetPosition()
	if( self.db.profile.position ) then
		self.frame:ClearAllPoints()	
		self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.profile.position.x/self.db.profile.scale, self.db.profile.position.y/self.db.profile.scale)
	else
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER", UIParent, "CENTER")
	end
end

function CombatTimer:CreateDisplay()
	local backdrop = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1}}
		
	self.frame = CreateFrame("StatusBar", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
	self.frame:SetHeight(16)
	self.frame:SetMovable(true)
	self.frame:EnableMouse(true)
	self.frame:RegisterForDrag("LeftButton")
	self.frame:SetBackdrop(backdrop)
	self.frame:SetBackdropColor(0, 0, 0, 1.0)
	self.frame:SetBackdropBorderColor(0, 0, 0, 1.0)
	self.frame:SetScript("OnDragStart", OnDragStart)
	self.frame:SetScript("OnDragStop", OnDragStop)
	self.frame:SetMinMaxValues(0, 7)
	self.frame:SetValue(0)
	
	self.frame.text = self.frame:CreateFontString(nil)
	self.frame.text:SetFontObject(GameFontHighlight)
	self.frame.text:SetPoint("CENTER", self.frame)
	self.frame.text:SetShadowOffset(1, -1)
	self.frame.text:SetShadowColor(0, 0, 0, 1)
	self.frame.text:SetText("ooc")
end

function CombatTimer:UpdateSettings()
	self.frame:SetStatusBarTexture(self.media:Fetch(self.media.MediaType.STATUSBAR, self.db.profile.texture))
	self.frame:SetWidth(self.db.profile.width)
	self.frame:SetScale(self.db.profile.scale)
	self.frame:SetMovable(not self.db.profile.lock)
	self.frame:EnableMouse(not self.db.profile.lock)
	
	if (not self.db.profile.hideTimer or not self.db.profile.lock) then
		--only show frame if combat timer is enabled for that zone
		if( self:InEnabledZone()  ) then
			self.frame:Show()
		end
	else
		self.frame:Hide()
	end
	
	self:SetPosition()
end

function CombatTimer:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CombatTimer|r: " .. msg)
end