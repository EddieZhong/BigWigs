---------------------------------
--      Addon Declaration      --
---------------------------------

local plugin = BigWigs:NewPlugin("Target Monitor")
if not plugin then return end

------------------------------
--      Are you local?      --
------------------------------

local enablezones, enablemobs, enableyells = {}, {}, {}
local monitoring = nil

------------------------------
--      Initialization      --
------------------------------

function plugin:OnPluginEnable()
	monitoring = nil
	for name, module in BigWigs:IterateBossModules() do
		self:RegisterZone(module.zoneName)
		self:RegisterMob(module)
	end

	self:RegisterMessage("BigWigs_ModulePackLoaded", "ZoneChanged")
	self:RegisterEvent("ZONE_CHANGED", "ZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZoneChanged")
	self:RegisterMessage("BigWigs_BossModuleRegistered")
	self:RegisterMessage("BigWigs_OnBossDisable")
	self:RegisterMessage("BigWigs_OnBossEnable")
	self:ZoneChanged()
end

function plugin:RegisterZone(zone) enablezones[zone] = true end
function plugin:RegisterMob(mod)
	local mob = mod.enabletrigger
	if type(mob) == "function" then enableyells[mob] = mod
	elseif type(mob) == "string" or type(mob) == "number" then enablemobs[mob] = mod
	else for i,m in next, mob do enablemobs[m] = mod end end
end
function plugin:UnregisterMob(mod)
	local mob = mod.enabletrigger
	if type(mob) == "function" then enableyells[mob] = nil
	elseif type(mob) == "string" or type(mob) == "number" then enablemobs[mob] = nil
	else for i,m in next, mob do enablemobs[m] = nil end end
end

------------------------------
--      Event Handlers      --
------------------------------

function plugin:BigWigs_OnBossEnable(event, mod) self:UnregisterMob(mod) end
function plugin:BigWigs_OnBossDisable(event, mod) self:RegisterMob(mod) end

function plugin:BigWigs_BossModuleRegistered(event, modname, mod)
	self:RegisterZone(mod.zoneName)
	self:RegisterMob(mod)
end

function plugin:ZoneChanged()
	if enablezones[GetRealZoneText()] or enablezones[GetSubZoneText()] or enablezones[GetZoneText()] then
		if not monitoring then
			monitoring = true
			self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
			self:RegisterEvent("PLAYER_TARGET_CHANGED")
			self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
		end
	elseif monitoring then
		monitoring = nil
		self:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
	end
end

local function targetCheck(unit)
	local n = UnitName(unit)
	if not n then return end
	if UnitIsCorpse(unit) or UnitIsDead(unit) or UnitPlayerControlled(unit) then return end
	local id = UnitGUID(unit)
	if not id then return end

	id = tonumber(id:sub(-12,-7),16)
	
	if n and enablemobs[n] then
		plugin:SendMessage("BigWigs_TargetSeen", unit, enablemobs[n])
	elseif id and enablemobs[id] then
		plugin:SendMessage("BigWigs_TargetSeen", unit, enablemobs[id])
	end
end

function plugin:CHAT_MSG_MONSTER_YELL(event, msg, source)
	for func, mod in pairs(enableyells) do
		local yell = func()
		if yell == msg then
			self:SendMessage("BigWigs_TargetSeen", "player", mod)
		end
	end
end
function plugin:UPDATE_MOUSEOVER_UNIT() targetCheck("mouseover") end
function plugin:PLAYER_TARGET_CHANGED() targetCheck("target") end

