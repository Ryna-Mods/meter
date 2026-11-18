-- The threat bar (Threat.lua, ThreatBar.lua) against the fake client, with a made-up group and enemies.
-- From the repository root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/threat_test.lua
--
-- It proves: a reading from plain numbers, from nothing and from secrets; no bar alone or out of a
-- fight; the rows in order (whoever holds the enemy, then by percentage) with the player's marked; the
-- warning colour past 80%; the enemy chosen by target, by a targeted friend's highest nameplate, and
-- by the player's own; friendly nameplates skipped; an enemy never reached through "targettarget";
-- the player's highest elsewhere; hidden numbers drawn without being compared, in group order, worded
-- from the state; the setting turning it off; its place kept when dragged and reset by Defaults; the
-- example for /ryna meter threat; nothing in chat unasked, no errors.
-- luacheck: ignore 1

local CORE = (os.getenv("RYNA_CORE") or ".core/Ryna_Core") .. "/"
local ADDON = "Ryna_Meter/"
local F = dofile("test/fake_client.lua")

local failures, checks = 0, 0
local function check(cond, what)
  checks = checks + 1
  if not cond then
    failures = failures + 1
    print("FAIL: " .. what)
  end
end
local function eq(got, want, what)
  check(got == want, what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
end

-- A secret: a value that raises on arithmetic and ordering, as the client's do, and that only
-- issecretvalue recognises.
local SECRET = {}
local function secret(v)
  return setmetatable({ hiddenValue = v }, SECRET)
end
SECRET.__lt = function() error("compared a secret") end
SECRET.__le = SECRET.__lt
SECRET.__add = function() error("arithmetic on a secret") end
SECRET.__sub, SECRET.__mul, SECRET.__div, SECRET.__unm = SECRET.__add, SECRET.__add, SECRET.__add, SECRET.__add
SECRET.__concat = function(a, b)
  local s = function(x) return getmetatable(x) == SECRET and "<secret>" or tostring(x) end
  return s(a) .. s(b)
end

-- The world the client answers from.
local world
local asked = {}
local function reset()
  world = {
    raid = false,
    units = {
      player = { name = "Dela", class = "PRIEST", combat = true, friend = true },
      party1 = { name = "Brom", class = "WARRIOR", combat = true, friend = true },
      party2 = { name = "Ilse", class = "MAGE", combat = true, friend = true },
      nameplate1 = { name = "Brom", class = "WARRIOR", friend = true }, -- a friend's plate: skipped
      nameplate2 = { name = "Quay Rat" },
      nameplate3 = { name = "Harbor Brute" },
    },
    alias = {},   -- target -> the unit it is
    threat = {},  -- threat[unit][mob] = { tanking, status, pct }
    secretFor = {}, -- mob -> true: the client hides this enemy's values
  }
  for k in pairs(asked) do asked[k] = nil end
end
local function unitOf(u) return world.alias[u] or u end
local function set(unit, mob, tanking, status, pct)
  world.threat[unit] = world.threat[unit] or {}
  world.threat[unit][mob] = { tanking, status, pct }
end

F.Install({ now = 1800003600 })
_G.issecretvalue = function(v) return getmetatable(v) == SECRET end
_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-0000000D" end end
_G.UnitExists = function(u) return world.units[unitOf(u)] ~= nil end
_G.UnitName = function(u) local x = world.units[unitOf(u)]; return x and x.name end
_G.UnitClass = function(u) local x = world.units[unitOf(u)]; if x then return x.class, x.class end end
_G.UnitIsPlayer = function(u) local x = world.units[unitOf(u)]; return x and x.class ~= nil or false end
_G.UnitIsDead = function(u) local x = world.units[unitOf(u)]; return x and x.dead or false end
_G.UnitIsUnit = function(a, b) return unitOf(a) == unitOf(b) end
_G.UnitCanAttack = function(_, u) local x = world.units[unitOf(u)]; return x ~= nil and not x.friend end
_G.UnitAffectingCombat = function(u) local x = world.units[unitOf(u)]; return x and x.combat or false end
_G.IsInRaid = function() return world.raid end
_G.IsInGroup = function() return world.units.party1 ~= nil end
_G.GetNumGroupMembers = function() return 0 end
_G.UnitDetailedThreatSituation = function(unit, mob)
  asked[#asked + 1] = mob
  local t = world.threat[unitOf(unit)] and world.threat[unitOf(unit)][unitOf(mob)]
  if not t then return end
  if world.secretFor[unitOf(mob)] then return secret(t[1]), secret(t[2]), secret(t[3]), secret(0), secret(0) end
  return t[1], t[2], t[3], t[3] * 1.3, 100
end
_G.UnitThreatSituation = function(unit, mob)
  local t = world.threat[unitOf(unit)] and world.threat[unitOf(unit)][unitOf(mob)]
  return t and t[2] or nil
end
_G.C_Secrets = { ShouldUnitThreatValuesBeSecret = function(_, mob) return world.secretFor[unitOf(mob)] == true end }
_G.C_AddOns = { GetAddOnMetadata = function() return "0.0.0" end }
_G.RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1, colorStr = "ffffffff" }
_G.RAID_CLASS_COLORS.MAGE = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" }
_G.RynaDB = { schema = 1, settings = {}, journal = {}, characters = {} }

reset()
local core, mod = {}, {}
F.LoadAddon(CORE, "Ryna_Core", core)
F.LoadAddon(ADDON, "Ryna_Meter", mod)
F.Fire("ADDON_LOADED", "Ryna_Core")
F.Fire("PLAYER_LOGIN")
F.DropTimers()

local T, B = mod.Threat, mod.ThreatBar
check(T ~= nil and B ~= nil, "the threat files loaded")
eq(_G.Ryna.Settings.Get("meterThreat"), true, "the bar is on by default")
eq(_G.Ryna.Settings.Get("meterThreatStay"), true, "and stays on screen between fights by default")
-- First with that off: the bar only while a fight is on.
_G.Ryna.Settings.Set("meterThreatStay", false)

-- Readings ---------------------------------------------------------------------------------------------

set("player", "nameplate2", false, 0, 16.9)
local r = T.Read("player", "nameplate2")
check(r and r.hidden == false and r.pct == 16.9 and r.tanking == false, "a plain reading")
eq(T.Read("player", "nameplate3"), nil, "not on the enemy's list: no reading")
world.secretFor.nameplate2 = true
r = T.Read("player", "nameplate2")
check(r and r.hidden == true and _G.issecretvalue(r.pct) and r.status == 0,
  "a hidden reading keeps its secret and its state")
world.secretFor.nameplate2 = nil

-- No bar alone, or out of a fight --------------------------------------------------------------------

reset()
world.units.party1, world.units.party2 = nil, nil
set("player", "nameplate2", true, 3, 100)
eq(T.Snapshot(), nil, "alone: nothing")
reset()
set("player", "nameplate2", true, 3, 100)
for _, u in pairs(world.units) do u.combat = false end
eq(T.Snapshot(), nil, "nobody fighting: nothing")

-- The player's target is the enemy ---------------------------------------------------------------------

reset()
world.alias.target = "nameplate3"
set("party1", "nameplate3", true, 3, 100)
set("party2", "nameplate3", false, 0, 61)
set("player", "nameplate3", false, 0, 8)
set("player", "nameplate2", false, 0, 58) -- higher on another enemy
local s = T.Snapshot()
check(s ~= nil, "a snapshot with an enemy targeted")
eq(s.mob, "target", "the target is followed")
eq(s.via, "target", "chosen by target")
eq(#s.rows, 3, "a row per member on its list")
eq(s.rows[1].name, "Brom", "whoever holds it is first")
eq(s.rows[2].name, "Ilse", "then by percentage")
eq(s.rows[3].me, true, "the player's row is marked")
eq(s.warn, false, "nobody close: no warning")
check(s.top and s.top.mob == "nameplate2" and s.top.pct == 58, "the player's highest elsewhere")
for _, mob in ipairs(asked) do
  check(mob ~= "targettarget", "an enemy is never reached through targettarget")
  check(mob ~= "nameplate1", "a friend's nameplate is never asked about")
end

set("party2", "nameplate3", false, 0, 91)
s = T.Snapshot()
eq(s.warn, true, "someone past 80%: the warning")
check(T.Close(s.rows[2]) and not T.Close(s.rows[1]), "the close one is the one near pulling, not the holder")

-- A friend targeted: the nameplate that friend is highest on -----------------------------------------

reset()
world.alias.target = "party1"
set("party1", "nameplate2", false, 0, 40)
set("party1", "nameplate3", true, 3, 100)
set("player", "nameplate3", false, 0, 31)
s = T.Snapshot()
eq(s.mob, "nameplate3", "the enemy the targeted friend holds")
eq(s.via, "friend", "chosen through the friend")

-- Nothing targeted: the player's own highest; and a healer on no list follows the group ------------

reset()
set("player", "nameplate2", false, 0, 22)
set("player", "nameplate3", false, 0, 9)
set("party1", "nameplate2", true, 3, 100)
s = T.Snapshot()
eq(s.mob, "nameplate2", "nothing targeted: the player's highest")
eq(s.top, nil, "no elsewhere line for the enemy already shown")
reset()
set("party1", "nameplate3", true, 3, 100)
s = T.Snapshot()
check(s and s.mob == "nameplate3" and s.via == "group", "on no list yet: the group's enemy")
eq(#s.rows, 1, "only those on its list get a row")

-- The bar ----------------------------------------------------------------------------------------------

reset()
world.alias.target = "nameplate3"
set("party1", "nameplate3", true, 3, 100)
set("party2", "nameplate3", false, 0, 91.4)
set("player", "nameplate3", false, 0, 7.69)
check(B.driver ~= nil, "the driver was started at login")
B.driver._scripts.OnUpdate(B.driver, 0.1)
check(B.frame == nil, "no read before the interval")
B.driver._scripts.OnUpdate(B.driver, 0.2)
local f = B.frame
check(f ~= nil and f:IsShown(), "the bar shows in a fight")
eq(f.title._text, "Harbor Brute", "the enemy's name")
eq(f.holder._text, "on Brom", "who it is on")
eq(f.rows[1].left._text, "Brom", "first row's name")
eq(f.rows[1].right._text, "has it", "the holder's words")
eq(f.rows[1]._value, 100, "the holder's bar is full")
eq(f.rows[2].right._text, "91%", "a percentage, rounded")
eq(f.rows[2]._value, 91.4, "the bar's value")
eq(f.rows[2]._barColor[1], 0.94, "past 80%: orange")
eq(f.rows[3].right._text, "8%", "the player's percentage")
eq(f.rows[3]._barColor[1], 1, "the player's class colour")
check(f.rows[3].mine:IsShown() and not f.rows[1].mine:IsShown(), "the player's row carries the mark")
check(not f.rows[4]:IsShown(), "unused rows are hidden")
eq(f.warn, true, "the frame is in its warning state")
eq(f.edges[1]._colorTexture[1], 0.94, "the edge is orange")
check(not f.foot:IsShown(), "no line under the rows")

-- Hidden numbers: drawn, never compared ---------------------------------------------------------------

world.secretFor.nameplate3 = true
world.threat.party2.nameplate3[2] = 1 -- above the holder, not holding: "close"
B.Tick()
eq(core.errors.count, 0, "no error with hidden numbers: " .. tostring(core.errors.last))
eq(f.rows[1].left._text, "Dela", "hidden: the player first")
eq(f.rows[1].right._text, "", "hidden and safe: no words")
check(_G.issecretvalue(f.rows[1]._value), "the secret went to the bar untouched")
eq(f.rows[2].left._text, "Brom", "then group order")
eq(f.rows[2].right._text, "has it", "hidden: the holder by state")
eq(f.rows[3].right._text, "close", "hidden: close by state")
eq(f.rows[3]._barColor[1], 0.94, "hidden and close: orange")
eq(f.foot._text, "The game hides the numbers here.", "the line under the rows")
world.secretFor.nameplate3 = nil

-- A secret enemy name goes to the label as it is ------------------------------------------------------

local hiddenName = secret("Harbor Brute")
world.units.nameplate3.name = hiddenName
B.Tick()
eq(f.title._text, hiddenName, "a secret name is passed on, not replaced")
eq(core.errors.count, 0, "no error with a secret name: " .. tostring(core.errors.last))
world.units.nameplate3.name = "Harbor Brute"

-- The fight ends; the setting turns it off ---------------------------------------------------------

for _, u in pairs(world.units) do u.combat = false end
B.Tick()
check(not f:IsShown(), "hidden when the fight ends")
for _, u in pairs(world.units) do if u.friend then u.combat = true end end
B.Tick()
check(f:IsShown(), "back in the next fight")
_G.Ryna.Settings.Set("meterThreat", false)
B.Tick()
check(not f:IsShown(), "hidden while the setting is off")
_G.Ryna.Settings.Set("meterThreat", true)

-- Its place ---------------------------------------------------------------------------------------------

f:ClearAllPoints()
f:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 40, -300)
f._scripts.OnDragStop(f)
local at = _G.RynaDB.meter and _G.RynaDB.meter.threatBar
check(at and at.point == "TOPLEFT" and at.x == 40 and at.y == -300, "its place is kept when dragged")
B.ResetPlace()
eq(_G.RynaDB.meter.threatBar.point, nil, "Defaults forgets the place")
eq((f:GetPoint(1)), "CENTER", "and puts it back")

-- Growing downwards: held by its top left corner -----------------------------------------------------

-- A client that can say where a frame is (the fake can't, unless told): after a drag the client has
-- re-anchored it to a bottom corner, which would make more rows grow it upwards.
f.GetLeft, f.GetTop = function() return 120 end, function() return 640 end
f:ClearAllPoints()
f:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 120, 580)
f._scripts.OnDragStop(f)
local pin = _G.RynaDB.meter.threatBar
check(pin.point == "TOPLEFT" and pin.rel == "BOTTOMLEFT" and pin.x == 120 and pin.y == 640,
  "after a drag it is kept by its top left corner")
check(f._points[1][1] == "TOPLEFT" and #f._points == 1, "and held there, so it grows downwards")
B.ResetPlace()
check(f._points[1][1] == "TOPLEFT" and f._points[1][3] == "BOTTOMLEFT", "its default place is pinned by the top too")
f.GetLeft, f.GetTop = nil, nil
B.ResetPlace()

-- /ryna meter threat -------------------------------------------------------------------------------

check(#F.chat == 0, "nothing in chat unasked: " .. table.concat(F.chat, " / "))
for _, u in pairs(world.units) do u.combat = false end
B.Tick()
_G.SlashCmdList.RYNA("meter threat")
check(B.placing and f:IsShown(), "the example shows")
eq(f.title._text, "Example enemy", "the example's enemy")
eq(f.rows[3].left._text, "Dela", "the example names the player")
eq(#F.chat, 1, "the command is answered once")
B.Tick()
check(f:IsShown(), "a read doesn't put the example away")
_G.SlashCmdList.RYNA("meter threat")
check(not B.placing and not f:IsShown(), "typed again: put away")
B.Place()
F.Fire("PLAYER_REGEN_DISABLED")
eq(B.placing, false, "a fight ends the example")

-- Kept on screen between fights ----------------------------------------------------------------------

_G.Ryna.Settings.Set("meterThreatStay", true)
for _, u in pairs(world.units) do u.combat = false end
B.Tick()
check(f:IsShown(), "set to stay: on screen with nobody fighting")
eq(f.title._text, "Threat", "under its own name")
eq(f.foot._text, "Nobody is fighting.", "saying why it is empty")
check(not f.rows[1]:IsShown() and f.warn == false, "with no rows and no warning")
world.units.party1, world.units.party2 = nil, nil
B.Tick()
check(f:IsShown(), "and when alone")
_G.Ryna.Settings.Set("meterThreat", false)
B.Tick()
check(not f:IsShown(), "the bar's own setting still turns it off")
_G.Ryna.Settings.Set("meterThreat", true)

eq(core.errors.count, 0, "no errors caught: " .. tostring(core.errors.last))
print(string.format("threat: %d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
