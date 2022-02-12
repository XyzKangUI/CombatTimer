function CombatTimer:GetDefaultConfig()
	local defaults = {
		profile = {
			scale = 1.00,
			width = 60,
			texture = "Glaze",
			fadeInStart = 7,
			fadeInEnd = 0,
			hide = true,
			inside = {["arena"] = true, ["none"] = true},
			visual = {
				r = 0.15,
				g = 1.0,
				b = 0.0,
				a = 1.0,
			}
		},
	}
	
	return defaults
end

--common functions for options callbacks
local function toggleTableEntry(k, v)
	CombatTimer.db.profile[k.arg][v] = not CombatTimer.db.profile[k.arg][v]
	
	if( select(2, IsInInstance()) == v ) then
		if( CombatTimer.db.profile[k.arg][v] ) then
			CombatTimer:OnEnable()
		else
			CombatTimer:OnDisable()
		end
	end
	CombatTimer:UpdateSettings()
end

local function getOption(info, value)	
	if( value ) then
		return CombatTimer.db.profile[info.arg][value]
	else
		return CombatTimer.db.profile[info.arg]
	end
end

local function setOption(info, value)
	CombatTimer.db.profile[info.arg] = value
	CombatTimer:UpdateSettings()
end

local function slashHandler(option)
	if option == "menu" then
		InterfaceOptionsFrame_OpenToFrame("Combat Timer")
	elseif option == "lock" then
		CombatTimer.db.profile.lock = not CombatTimer.db.profile.lock
		CombatTimer:UpdateSettings()
	else
		CombatTimer:Print("Revision "..tonumber(string.match(GetAddOnMetadata("CombatTimer", "Version"), "(%d+)") or 1))
		CombatTimer:Print("/combattimer lock")
		CombatTimer:Print("/combattimer menu")
	end
end

function CombatTimer:SetupOptions()
	self.media:Register(self.media.MediaType.STATUSBAR, "BantoBar", "Interface\\Addons\\CombatTimer\\images\\banto")
	self.media:Register(self.media.MediaType.STATUSBAR, "Smooth", "Interface\\Addons\\CombatTimer\\images\\smooth")
	self.media:Register(self.media.MediaType.STATUSBAR, "Perl", "Interface\\Addons\\CombatTimer\\images\\perl")
	self.media:Register(self.media.MediaType.STATUSBAR, "Glaze", "Interface\\Addons\\CombatTimer\\images\\glaze")
	self.media:Register(self.media.MediaType.STATUSBAR, "Charcoal", "Interface\\Addons\\CombatTimer\\images\\Charcoal")
	self.media:Register(self.media.MediaType.STATUSBAR, "Otravi", "Interface\\Addons\\CombatTimer\\images\\otravi")
	self.media:Register(self.media.MediaType.STATUSBAR, "Striped", "Interface\\Addons\\CombatTimer\\images\\striped")
	self.media:Register(self.media.MediaType.STATUSBAR, "LiteStep", "Interface\\Addons\\CombatTimer\\images\\LiteStep")
	
	local enabledIn = {
		arena = "Arenas",
		pvp = "Battlegrounds",
		none = "Everywhere else",
	}
	
	self.options = {
		type = "group",
		name = "Combat Timer",
		get = getOption,
		set = setOption,
		args = {
			width = {
				order = 1,
				name = "Width",
				type = "range", isPercent = false,
				min = 20, max = 600, step = 1,
				arg = "width",
			},
			scale = {
				order = 2,
				name = "Scale",
				type = "range", isPercent = false,
				min = 0.5, max = 2, step = 0.05,
				arg = "scale",
			},
			fadeInStart = {
				order = 3,
				name = "Fade in start",
				type = "range", isPercent = false,
				min = 1, max = 7, step = 0.1,
				arg = "fadeInStart",
			},
			fadeInEnd = {
				order = 4,
				name = "Fade in end",
				type = "range", isPercent = false,
				min = 0, max = 7, step = 0.1,
				arg = "fadeInEnd",
			},
			hide = {
				order = 5,
				name = "Hide out of combat",
				type = "toggle",
				arg = "hideTimer",
			},
			lock = {
				order = 6,
				name = "Lock",
				type = "toggle",
				arg = "lock",
			},
			color = {
				order = 7,
				name = "Color",
				type = "color",
				set = function(info, r, g, b, a) self:OnColorSet(r, g, b, a) end,
				get = function(info) return self.db.profile.visual.r, self.db.profile.visual.g, self.db.profile.visual.b, self.db.profile.visual.a; end,
			},
			texture = {
				order = 8,
				type = "select",
				name = "Texture",
				values = self.media:List('statusbar'),
				get=function(info)
					local mt = self.media:List('statusbar')
					for k,v in pairs(mt) do
						if v == self.db.profile.texture then
							return k
						end
					end
				end,
				set=function(info,v)
					local mt = self.media:List('statusbar')
					self.db.profile.texture = mt[v]
					self:UpdateSettings()
				end,
			},
			inside = {
				order = 9,
				name = "Only enable inside",
				values = enabledIn,
				type = "multiselect",
				arg = "inside",
				set = toggleTableEntry,
			},
			resetPos = {
				order = 10,
				name = "Reset position",
				type = "execute",
				func = function() self.db.profile.position = nil; self:SetPosition(); end,
			},
			test = {
				order = 11,
				name = "Test",
				desc = "Enable test mode. Re-enable Lock when done",
				type = "execute",
				func = function() self.db.profile.lock = nil self:TestMode() end,
			},
		}
	}
	
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Combat Timer", self.options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Combat Timer", "Combat Timer")
	self:RegisterChatCommand("ctimer", slashHandler)
	self:RegisterChatCommand("combattimer", slashHandler)
end

function CombatTimer:OnColorSet(r, g, b, a)
	self.db.profile.visual.r = r;
	self.db.profile.visual.g = g;
	self.db.profile.visual.b = b;
	self.db.profile.visual.a = a;

	self:ResetTimer();
end
