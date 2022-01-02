CombatTimer = LibStub("AceAddon-3.0"):NewAddon("CombatTimer", "AceConsole-3.0", "AceEvent-3.0")

local instanceType
local endTime
local externalManaGainTimestamp = 0

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

function CombatTimer:PLAYER_REGEN_DISABLED()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:StartTimer()
end

function CombatTimer:PLAYER_REGEN_ENABLED()
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:StopTimer()
end

local eventRegistered = {
	SWING_DAMAGE = true,
	SWING_EXTRA_ATTACKS = true,
	SWING_MISSED = true,
	RANGE_DAMAGE = true,
	RANGE_MISSED = true,
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
	SPELL_PERIODIC_LEECH = true,
	SPELL_MISSED = true,
	SPELL_HEAL = true,
	SPELL_CAST_SUCCESS = true,
	SPELL_AURA_APPLIED = true,
	SPELL_PERIODIC_ENERGIZE = true,
	SPELL_ENERGIZE = true
--	SPELL_AURA_REMOVED = true -- do we really need to track when lets say dots fall off? Dispels trigger spell_cast_success
}

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo;
local COMBATLOG_FILTER_ME = COMBATLOG_FILTER_ME;
local COMBATLOG_FILTER_FRIENDLY_UNITS = COMBATLOG_FILTER_FRIENDLY_UNITS;
local COMBATLOG_FILTER_MY_PET = COMBATLOG_FILTER_MY_PET;
local Yunit = "target", "focus", "party1", "party2", "party3", "party4", "pet", "mouseover"


function CombatTimer:COMBAT_LOG_EVENT_UNFILTERED()
	local _, eventType, _, sourceGUID, _, sourceFlags, _, destGUID, _, destFlags, _, spellID, spellName = CombatLogGetCurrentEventInfo()
	if not (eventRegistered[eventType]) then return end

	local isDestPlayer = CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_ME)
	local isSourcePlayer = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME)
	local isSourcePet = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MY_PET)
	local isSourceFriend = CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_FRIENDLY_UNITS)
	local isDestFriend = CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_FRIENDLY_UNITS)

	-- return if event dest or source is not player.
	if (not isDestPlayer and not isSourcePlayer) then
		return
	end

	if (isSourcePlayer and ((eventType == "RANGE_DAMAGE" or eventType == "RANGE_MISSED") and not FirstEvent)) then
		FirstEvent = true
		return
	end

        if (eventType == "SPELL_PERIODIC_ENERGIZE" or eventType == "SPELL_ENERGIZE") then
		if isDestPlayer then
			externalManaGainTimestamp = GetTime()
		end
		return
        end

	--return if player heals or dispels out of combat friendly target
	if (eventType == "SPELL_HEAL" or
		eventType == "SPELL_AURA_APPLIED" or
		eventType == "SPELL_CAST_SUCCESS") then
		if (isSourcePlayer and isDestFriend and not UnitAffectingCombat(Yunit)) then
			return
		end
	end

	--return if player only gets healed, dispelled or buffed by someone/self
	if ((eventType == "SPELL_HEAL" or
		eventType == "SPELL_AURA_APPLIED" or
--		eventType == "SPELL_AURA_REMOVED" or
		eventType == "SPELL_CAST_SUCCESS") and (isDestPlayer and (isSourceFriend or isSourcePlayer))) then
			return
	end

	-- return on own buffs
	if (eventType == "SPELL_AURA_APPLIED") then
		if (isDestPlayer and isSourcePlayer) then
			return
		end 
	end

	if (eventType == "SPELL_CAST_SUCCESS") then
		if (not isDestPlayer and isSourcePlayer) then
			return
		end 
	end

	-- return if devour magic (max rank @ LvL70)
	if (isSourcePet or isSourceFriend) and ((spellID == 27277 or spellID == 27279) and (isDestPlayer or (isDestFriend and not UnitAffectingCombat(Yunit)))) then
		return
	end

	-- return if periodic dmg but its not a max rank channeling spell
	if (eventType == "SPELL_PERIODIC_DAMAGE") then
		if (spellID ~= 27220 or spellID ~= 27217 or spellID ~= 1120 or spellID ~= 25387) then
			return
		end
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
	self.frame:RegisterEvent("UNIT_POWER_FREQUENT")
	self.frame:SetScript("OnUpdate", onUpdate)
	self.frame:Show()
end

function CombatTimer:StopTimer()
--	self.frame:UnregisterEvent("UNIT_POWER_FREQUENT")
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
	endTime = GetTime() + 5.5
	self.frame:SetStatusBarColor(0.0, 1.0, 0.0, 1.0)
end

function debug(...)
    local val
   local text = "|cff0384fc" .. "DEBUG" .. "|r:"
    for i = 1, select("#", ...) do
        val = select(i, ...)
        if (type(val) == 'boolean') then val = val and "true" or false end
        text = text .. " " .. tostring(val)
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function onUpdate()
	local currentEnergy = UnitPower("player", 3)
	local maxEnergy = UnitPowerMax("player", 3)
	local currentMana = UnitPower("player", 0)
	local type = UnitPowerType("player")
	local now = GetTime()
	local v = now - last_tick
	local left = endTime - GetTime()
	local remaining = 2.02 - v

	if type == 3 then
		if (((currentEnergy == last_value + 20 or 
			currentEnergy == last_value + 21 or 
			currentEnergy == last_value + 40 or 
			currentEnergy == last_value + 41) and 
			currentEnergy ~= maxEnergy) or (now >= last_tick + 2.02)) then
    			last_tick = now
--		debug("im a rogue")
		end
	last_value = currentEnergy
	elseif type == 0 then
		if now - externalManaGainTimestamp < 0.02 then
			externalManaGainTimestamp = 0
			return
--		debug("external mana tick")
		end
		if (currentMana > last_value) or (now >= last_tick + 2.02) then
			last_tick = now
		end
--		debug("i use mana")
	last_value = currentMana
	end
	
	if (left < 1) then
		left = remaining
	end
	
	if (left <= 0) then left = 0 end

	local passed = 6 - left
	
	CombatTimer.frame:SetValue(passed)
	CombatTimer.frame:SetStatusBarColor(1.0 * passed / 5, 1.0, 0.0, 1.0)
	
	local alpha 
	if (left > CombatTimer.db.profile.fadeInStart) then
		alpha = 0
	elseif (left < CombatTimer.db.profile.fadeInEnd) then
		alpha = 1
	else
		alpha = 1 / (CombatTimer.db.profile.fadeInStart - CombatTimer.db.profile.fadeInEnd) * (CombatTimer.db.profile.fadeInStart - left)
	end
	
	CombatTimer.frame:SetAlpha(alpha)
		
	CombatTimer.frame.text:SetText(string.format("%.1f", left))
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
