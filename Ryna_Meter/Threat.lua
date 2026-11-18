-- Threat: who in the group is how close to pulling an enemy, read from the game while a fight is on
-- (docs/forever-client-api.md, "Threat"; probed in The Deadmines on 2026-11-15). The client answers
-- UnitDetailedThreatSituation(unit, mob) with plain numbers when the enemy is named directly: the
-- player's target, or one of the nameplates on screen. Through a compound unit ("targettarget") the
-- same numbers come back secret, so an enemy is never reached that way. A raid may hide them too:
-- every read first asks C_Secrets, and a hidden reading is kept as it is (hidden = true), to be drawn
-- and never compared.
--
--   T.Read(unit, mob)   a reading { pct, tanking, status, hidden }, or nil when the unit isn't on that
--                       enemy's list (the call returns nothing) or the client has no such call
--   T.Group()           the group's units, the player first; empty when alone
--   T.Enemies()         the nameplates of enemies on screen
--   T.Snapshot()        what the bar draws: { mob, via, rows, warn, hidden, top }, or nil
--
-- Nothing here writes, prints or acts.

local _, ns = ...
if ns.off then return end

local T = {}
ns.Threat = T

-- A bar turns to the warning colour from here (percent of the way to pulling the enemy).
T.WARN = 80
-- The rows a snapshot keeps: the highest, and always the player's own.
T.MAX_ROWS = 8
-- Nameplate units walked each read. The client shows at most this many.
T.MAX_PLATES = 40

local function call(a, b, ...)
  return ns.Try(ns.Fn(a, b), ...)
end

-- True when any of the values is secret: nothing may be compared then.
local function anySecret(...)
  for i = 1, select("#", ...) do
    if ns.IsSecret((select(i, ...))) then return true end
  end
  return false
end

-- The threat state (0 to 3), which the docs say stays readable where the values are hidden; nil when
-- it is hidden too or the client can't say.
local function state(unit, mob)
  local s = call("UnitThreatSituation", nil, unit, mob)
  if ns.IsSecret(s) or type(s) ~= "number" then return nil end
  return s
end

function T.Read(unit, mob)
  local fn = ns.Fn("UnitDetailedThreatSituation")
  if not fn then return nil end
  local tanking, status, pct = ns.Try(fn, unit, mob)
  local told = call("C_Secrets", "ShouldUnitThreatValuesBeSecret", unit, mob)
  if anySecret(tanking, status, pct) or (not ns.IsSecret(told) and told == true) then
    -- A unit that isn't on the enemy's list returns nothing, hidden or not: nothing to draw.
    if not ns.IsSecret(pct) and pct == nil then return nil end
    return { hidden = true, pct = pct, tanking = tanking, status = state(unit, mob) }
  end
  if type(pct) ~= "number" then return nil end
  return {
    hidden = false,
    pct = pct,
    tanking = tanking == true,
    status = type(status) == "number" and status or 0,
  }
end

function T.Group()
  local units = {}
  if call("IsInRaid") == true then
    local n = tonumber(call("GetNumGroupMembers")) or 0
    for i = 1, n do
      local unit = "raid" .. i
      if call("UnitExists", nil, unit) == true then
        -- The player has a raid unit of its own: it goes first, as "player".
        if call("UnitIsUnit", nil, unit, "player") == true then
          table.insert(units, 1, "player")
        else
          units[#units + 1] = unit
        end
      end
    end
    if units[1] ~= "player" then table.insert(units, 1, "player") end
    return units
  end
  if call("IsInGroup") ~= true then return units end
  units[1] = "player"
  for i = 1, 4 do
    local unit = "party" .. i
    if call("UnitExists", nil, unit) == true then units[#units + 1] = unit end
  end
  return units
end

local function attackable(unit)
  return call("UnitExists", nil, unit) == true and call("UnitCanAttack", nil, "player", unit) == true
    and call("UnitIsDead", nil, unit) ~= true
end

function T.Enemies()
  local out = {}
  for i = 1, T.MAX_PLATES do
    local unit = "nameplate" .. i
    if attackable(unit) then out[#out + 1] = unit end
  end
  return out
end

-- Whether any of the group is fighting: the bar shows for a healer who hasn't cast yet.
function T.Fighting(group)
  for _, unit in ipairs(group) do
    if call("UnitAffectingCombat", nil, unit) == true then return true end
  end
  return false
end

-- How high a reading is for choosing between enemies: holding one counts above any percentage; a
-- hidden reading counts by its state alone.
local function height(reading)
  if not reading then return -1 end
  if reading.hidden then return (reading.status or 0) >= 2 and 1000 or (reading.status or 0) end
  if reading.tanking then return 1000 end
  return reading.pct
end

-- The enemy among `plates` that `unit` is highest on, with that reading; nil when on none.
local function highest(unit, plates)
  local best, bestReading, bestHeight
  for _, mob in ipairs(plates) do
    local reading = T.Read(unit, mob)
    local h = height(reading)
    if reading and (not best or h > bestHeight) then
      best, bestReading, bestHeight = mob, reading, h
    end
  end
  return best, bestReading
end

-- Which enemy the bar follows: the player's target when it is one; with a friend targeted, the enemy
-- on screen that friend is highest on; with nothing targeted, the one the player is highest on, and
-- failing that (a healer who hasn't cast yet) the one the first of the others is highest on.
-- Returns the enemy's unit, how it was chosen ("target", "friend", "self" or "group") and the friend's unit.
function T.Choose(plates, group)
  if attackable("target") then return "target", "target" end
  local friend = call("UnitExists", nil, "target") == true and call("UnitIsPlayer", nil, "target") == true
  if friend then
    local mob = highest("target", plates)
    if mob then return mob, "friend", "target" end
  end
  local mob = highest("player", plates)
  if mob then return mob, "self" end
  for _, unit in ipairs(group or {}) do
    if unit ~= "player" then
      mob = highest(unit, plates)
      if mob then return mob, "group", unit end
    end
  end
  return nil
end

local function row(unit, reading)
  local _, class = call("UnitClass", nil, unit)
  return {
    unit = unit,
    me = unit == "player",
    name = ns.NonEmpty(call("UnitName", nil, unit)),
    class = type(class) == "string" and not ns.IsSecret(class) and class or nil,
    pct = reading.pct,
    tanking = reading.tanking,
    status = reading.status,
    hidden = reading.hidden,
  }
end

-- Whether a row is close to pulling: by its number, or by its state when the number is hidden (state
-- 1 is "above whoever holds the enemy, and not holding it").
function T.Close(r)
  if r.hidden then return r.status == 1 end
  return not r.tanking and r.pct >= T.WARN
end

-- Whether a row holds the enemy.
function T.Holds(r)
  if r.hidden then return (r.status or 0) >= 2 end
  return r.tanking
end

function T.Snapshot()
  local group = T.Group()
  if #group < 2 or not T.Fighting(group) then return nil end
  local plates = T.Enemies()
  local mob, via, friend = T.Choose(plates, group)
  if not mob then return nil end

  local rows, hidden = {}, false
  for _, unit in ipairs(group) do
    local reading = T.Read(unit, mob)
    if reading then
      rows[#rows + 1] = row(unit, reading)
      hidden = hidden or reading.hidden
    end
  end
  if #rows == 0 then return nil end

  if hidden then
    -- Nothing may be compared: the player first, then whoever the states single out, in group order.
    local kept = {}
    for _, r in ipairs(rows) do
      if r.me or (r.status or 0) >= 1 then kept[#kept + 1] = r end
    end
    for _, r in ipairs(rows) do
      if #kept >= T.MAX_ROWS then break end
      if not r.me and (r.status or 0) < 1 then kept[#kept + 1] = r end
    end
    rows = kept
  else
    for i, r in ipairs(rows) do r.order = i end
    table.sort(rows, function(a, b)
      if a.tanking ~= b.tanking then return a.tanking end
      if a.pct ~= b.pct then return a.pct > b.pct end
      return a.order < b.order
    end)
  end
  -- The highest rows, and always the player's own in the last place when it would fall off.
  if #rows > T.MAX_ROWS then
    local mine
    for i = T.MAX_ROWS + 1, #rows do
      if rows[i].me then mine = rows[i] end
    end
    for i = #rows, T.MAX_ROWS + 1, -1 do rows[i] = nil end
    if mine then rows[T.MAX_ROWS] = mine end
  end

  local warn = false
  for _, r in ipairs(rows) do warn = warn or T.Close(r) end

  local snap = { mob = mob, via = via, friend = friend, rows = rows, warn = warn, hidden = hidden }

  -- The player's highest on any other enemy on screen, when it is above their place on this one. Only
  -- with plain numbers on both sides.
  local topMob, top = highest("player", plates)
  if topMob and topMob ~= mob and not top.hidden and not top.tanking then
    local here = 0
    for _, r in ipairs(rows) do
      if r.me then here = (r.hidden and 101) or (r.tanking and 101) or r.pct end
    end
    if top.pct > here + 1 then snap.top = { mob = topMob, pct = top.pct } end
  end
  return snap
end
