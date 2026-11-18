-- Bars: damage, healing and the rest, live, in a small frame of its own (docs/ryna-agent-cores-mods.md
-- 7.5, "The meter"). The combat log is closed to addons, but the game keeps its own tallies and gives
-- them out (C_DamageMeter; docs/forever-client-api.md, "The game's damage meter"): for this fight or
-- for everything since the last reset, each source's total and per-second amount, already in order.
--
-- During a fight those numbers are secret. They are shown anyway, because a status bar and a label
-- take a secret value and the game's own number formatter does too: every amount goes from the game
-- to the widget untouched, and nothing here compares, adds or keeps one. Which rows to draw needs no
-- comparison either: the game hands the sources sorted, and says which one is the player.
--
--   M.VIEWS            what the meter can show, in the order a click goes through them
--   M.Read(view, session)   { sources, max, duration } from the game, or nil and why
--   M.Draw(), M.Tick()      draw now; the driver's read (twice a second in a fight, every two seconds
--                           out of one, and at once when the game says a tally changed)
--   M.Menu(owner)           the pick-list: what to show, and which fight
--   M.Pick(view), M.Choose(kind, id, name)   what the pick-list does
--   M.Next(), M.Session()   the next view; this fight or overall (the clicks on a client without menus)
--
-- Click the first line for the pick-list, right-click it for this fight or overall, drag to move.
-- "This fight" is the game's current tally; when that is empty (it is cleared between fights on some
-- clients) the newest fight the game still holds is shown instead, so the meter never sits empty
-- after a pull. The pick-list also opens another window (up to four: damage beside healing, DPS beside
-- HPS) and closes one, and locks a window under or beside any other one on screen, named by what it
-- shows ("Under DPS", "Beside Threat"), so they sit together and drag as one. Each window's view,
-- tally, lock and place are kept in RynaDB.meter (bars, bars2, ...);
-- a past fight picked from the list is kept only until /reload, since the game's fight numbers start
-- over. The list also announces a window's rows to party, raid, guild or say: only on that click, and
-- only once the fight is over, since hidden amounts can't be sent. Nothing is written elsewhere,
-- nothing else is ever said in chat, and the game's own meter is left as the player set it.

local _, ns = ...
if ns.off then return end
local L = ns.L
local N = ns.N
local BF = ns.BarFrame

local M = {}
ns.Bars = M

M.KEY = "meterBars"
M.ROWS = 8
M.INTERVAL = 0.5

ns.API.Settings.AddDefaults({ [M.KEY] = true })

-- `type` is the name in Enum.DamageMeterType, `value` its number there (used when the client's Enum
-- lacks the name); `rate` shows the per-second amount instead of the total.
M.VIEWS = {
  { key = "damage", type = "DamageDone", value = 0, label = N("Damage") },
  { key = "dps", type = "Dps", value = 1, label = N("DPS"), rate = true },
  { key = "healing", type = "HealingDone", value = 2, label = N("Healing") },
  { key = "hps", type = "Hps", value = 3, label = N("HPS"), rate = true },
  { key = "taken", type = "DamageTaken", value = 7, label = N("Damage taken") },
  { key = "absorbs", type = "Absorbs", value = 4, label = N("Absorbs") },
  { key = "interrupts", type = "Interrupts", value = 5, label = N("Interrupts") },
  { key = "dispels", type = "Dispels", value = 6, label = N("Dispels") },
}
-- Enum.DamageMeterSessionType: overall 0, current 1.
local SESSIONS = { current = { name = "Current", value = 1 }, overall = { name = "Overall", value = 0 } }

function M.On()
  return ns.API.Settings.Get(M.KEY) and true or false
end

-- Several windows can be open at once (damage beside healing, say), each with its own view, tally
-- and place. Every function below takes the window's number last and means the first without one.
M.MAX_WINDOWS = 4
-- The space between two windows locked together.
M.GAP = 2
M.frames = {}
-- A past fight picked for a window, this session: pickedBy[w] = { id, name }.
local pickedBy = {}

-- The key a window's state is kept under in RynaDB.meter: "bars", "bars2", ...
local function keyOf(w)
  if w == "threat" then return "threatBar" end
  return (w or 1) == 1 and "bars" or ("bars" .. w)
end

-- What is kept for a window: { view, session, open, point, rel, x, y }.
local function kept(w)
  local saved = BF.Saved()
  if not saved then return {} end
  local key = keyOf(w)
  if type(saved[key]) ~= "table" then saved[key] = {} end
  return saved[key]
end

-- The first window is open whenever the meter is on; the others when they were opened.
function M.IsOpen(w)
  return (w or 1) == 1 or kept(w).open == true
end

function M.View(w)
  local key = kept(w).view
  for i, v in ipairs(M.VIEWS) do
    if v.key == key then return v, i end
  end
  return M.VIEWS[1], 1
end

-- Which tally: "current", "overall", or "id" (a past fight picked this session).
function M.SessionKey(w)
  if pickedBy[w or 1] then return "id" end
  return kept(w).session == "overall" and "overall" or "current"
end

local function groupUnits()
  local units = { "player" }
  if ns.Try(ns.Fn("IsInRaid")) == true then
    for i = 1, 40 do units[#units + 1] = "raid" .. i end
  else
    for i = 1, 4 do units[#units + 1] = "party" .. i end
  end
  return units
end

-- Whether the player or anyone in the group is fighting: a healer who hasn't cast yet still watches.
function M.Fighting()
  local inCombat = ns.Fn("UnitAffectingCombat")
  if not inCombat then return false end
  for _, unit in ipairs(groupUnits()) do
    if ns.Try(inCombat, unit) == true then return true end
  end
  return false
end

-- The fights the game still holds, oldest first: { id, name, duration }.
function M.Fights()
  local list = ns.Try(ns.Fn("C_DamageMeter", "GetAvailableCombatSessions"))
  local out = {}
  if type(list) ~= "table" or ns.IsSecret(list) then return out end
  for _, f in ipairs(list) do
    if type(f) == "table" and type(f.sessionID) == "number" and not ns.IsSecret(f.sessionID) then
      out[#out + 1] = { id = f.sessionID, name = ns.NonEmpty(f.name), duration = f.durationSeconds }
    end
  end
  return out
end

local function enum(group, name, fallback)
  local e = _G.Enum
  local g = type(e) == "table" and e[group]
  local v = type(g) == "table" and g[name]
  if type(v) == "number" then return v end
  return fallback
end

-- The game's tally for a view and session. Returns nil and "absent" (no such API), "unavailable" (the
-- game says the meter can't be used) or "empty" (nothing yet).
function M.Read(view, sessionKey, w)
  local get = ns.Fn("C_DamageMeter", "GetCombatSessionFromType")
  if not get then return nil, "absent" end
  local available = ns.Try(ns.Fn("C_DamageMeter", "IsDamageMeterAvailable"))
  if available == false then return nil, "unavailable" end
  local kind = enum("DamageMeterType", view.type, view.value)
  local function shaped(session)
    if type(session) ~= "table" then return nil end
    local sources = session.combatSources
    if type(sources) ~= "table" or ns.IsSecret(sources) then return nil end
    local n = ns.Try(function() return #sources end)
    if type(n) ~= "number" or n == 0 then return nil end
    return { sources = sources, count = n, max = session.maxAmount, total = session.totalAmount,
      duration = session.durationSeconds }
  end
  local byId = ns.Fn("C_DamageMeter", "GetCombatSessionFromID")
  local picked = pickedBy[w or 1]
  if sessionKey == "id" and picked and byId then
    local data = shaped(ns.Try(byId, picked.id, kind))
    if data then
      data.id = picked.id
      return data
    end
    return nil, "empty"
  end
  local s = SESSIONS[sessionKey] or SESSIONS.current
  local data = shaped(ns.Try(get, enum("DamageMeterSessionType", s.name, s.value), kind))
  if data then return data end
  -- The current tally is empty: the newest fight the game still holds, if it has one.
  if s == SESSIONS.current and byId then
    local fights = M.Fights()
    local last = fights[#fights]
    data = last and shaped(ns.Try(byId, last.id, kind))
    if data then
      data.last, data.id = true, last.id
      return data
    end
  end
  return nil, "empty"
end

-- Numbers are shown to two decimals: "18.57", "1.23K", "4.56M". A plain number (out of a fight) is
-- formatted here. A secret one (in a fight) can only be formatted by the game, so the game's formatter
-- is given the same rule as its options, once it has shown at login, on plain numbers, that it follows
-- it: with the rule for numbers under a thousand if it takes that, else without, else its own default.
-- One step of the rule: from `from` up, the number over `per`, cut to two decimals, then `letter`.
local function step(from, letter, per)
  return { breakpoint = from, abbreviation = letter, significandDivisor = per / 100, fractionDivisor = 100,
    abbreviationIsGlobal = false }
end

local function rule(small)
  local data = { step(1e9, "B", 1e9), step(1e6, "M", 1e6), step(1e3, "K", 1e3) }
  if small then data[#data + 1] = step(0, "", 1) end
  local config = ns.Try(ns.Fn("CreateAbbreviateConfig"), data)
  if config ~= nil then return { config = config } end
  return { breakpointData = data }
end

local function reads(out, pattern)
  return type(out) == "string" and not ns.IsSecret(out) and out:find(pattern) ~= nil
end

-- The options the game's formatter takes for two decimals: a table, or false when it follows none.
-- Found once (M.options), by asking it for 1234.5 and 18.5 and reading what comes back.
function M.Options()
  if M.options ~= nil then return M.options end
  M.options = false
  local abbreviate = ns.Fn("AbbreviateNumbers")
  if not abbreviate then return false end
  for _, small in ipairs({ true, false }) do
    local o = rule(small)
    local thousands = ns.Try(abbreviate, 1234.5, o)
    if reads(thousands, "^1[.,]23%s?K$") and (not small or reads(ns.Try(abbreviate, 18.5, o), "^18[.,]50?$")) then
      M.options, M.optionsSmall = o, small
      break
    end
  end
  ns.Debug("meter: two decimals from the game's formatter: %s", M.options and (M.optionsSmall and "all" or
    "thousands and up") or "no")
  return M.options
end

local function plain(v)
  if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
  if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
  if v >= 1e3 then return string.format("%.2fK", v / 1e3) end
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.2f", v)
end

-- A number for a label. A secret is never touched: it goes to the game's own formatter, or to the
-- label as it is.
function M.Short(v)
  if not ns.IsSecret(v) then
    if type(v) ~= "number" then return v end
    return plain(v)
  end
  local abbreviate = ns.Fn("AbbreviateNumbers") or ns.Fn("AbbreviateLargeNumbers")
  if not abbreviate then return v end
  local options = M.Options()
  local out
  if options then out = ns.Try(abbreviate, v, options) else out = ns.Try(abbreviate, v) end
  if ns.IsSecret(out) or out ~= nil then return out end
  return v
end

-- "1:05" for a fight's length; nil when the game won't say or it is secret.
local function clock(seconds)
  if ns.IsSecret(seconds) or type(seconds) ~= "number" or seconds <= 0 then return nil end
  local s = math.floor(seconds + 0.5)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- The rows to draw: the first M.ROWS sources, with the player's own in the last row when it is
-- further down. `isLocalPlayer` is never secret, so finding it compares nothing hidden.
function M.Rows(data)
  local rows, mine = {}, nil
  for i = 1, data.count do
    local src = data.sources[i]
    if type(src) == "table" then
      if i <= M.ROWS then rows[#rows + 1] = { rank = i, src = src } end
      if src.isLocalPlayer == true and i > M.ROWS then mine = { rank = i, src = src } end
    end
  end
  if mine then rows[M.ROWS] = mine end
  return rows
end

local function build(w)
  w = w or 1
  if not M.frames[w] then
    M.frames[w] = BF.Create({
      name = w == 1 and "RynaMeter" or ("RynaMeter" .. w), key = keyOf(w), rows = M.ROWS,
      x = 280, y = -220 - (w - 1) * 40,
      onClick = function(button)
        if button == "RightButton" then
          M.Session(w)
        elseif not M.Menu(M.frames[w].head, w) then
          M.Next(w)
        end
      end,
      onRowEnter = function(bar) M.Hover(w, bar) end,
      onRowLeave = function() M.Hover(nil) end,
      onEnter = function(owner)
        local tip = _G.GameTooltip
        if not tip or not tip.SetOwner then return end
        tip:SetOwner(owner, "ANCHOR_TOP")
        tip:AddLine(L["Click: choose what to show. Right-click: this fight or overall. Drag to move."], 1, 1, 1, true)
        tip:Show()
      end,
    })
    if w == 1 then M.frame = M.frames[1] end
  end
  return M.frames[w]
end

-- The open window before `w`: what a lock kept without a target (the first form of it) means.
function M.Before(w)
  for i = (w or 1) - 1, 1, -1 do
    if M.IsOpen(i) then return i end
  end
  return nil
end

-- Locking: a window can be held under or beside any other one on screen. The windows are the meter's
-- (their numbers) and the threat bar ("threat"), which locks like any of them; what one is locked to
-- is kept as that number or "threat".
local function frameOf(id)
  if id == "threat" then
    local bar = ns.ThreatBar
    return bar and bar.On() and bar.frame or nil
  end
  if type(id) == "number" and M.On() and M.IsOpen(id) then return M.frames[id] end
  return nil
end

-- What a window's kept lock points at, whether or not that is on screen.
local function keptTarget(w)
  local k = kept(w)
  if k.lock ~= "below" and k.lock ~= "beside" then return nil end
  if k.lockTo == "threat" or type(k.lockTo) == "number" then return k.lockTo end
  if w == "threat" then return nil end
  return M.Before(w)
end

-- Whether locking `w` to `id` would close a ring (a window locked, through others, to itself).
local function rings(w, id)
  local seen = 0
  while id ~= nil and seen <= M.MAX_WINDOWS + 1 do
    if id == w then return true end
    id = keptTarget(id)
    seen = seen + 1
  end
  return false
end

-- What a window is locked to and how: the target (a number or "threat") and "below" or "beside"; nil
-- when it is free, or its target is closed, off, or would make a ring.
function M.Lock(w)
  w = w or 1
  local id = keptTarget(w)
  if id == nil or rings(w, id) or not frameOf(id) then return nil end
  return kept(w).lock, id
end

-- The frame a drag of `w` moves: the head of its group (a meter window, or the threat bar).
local function head(w)
  local id = w
  for _ = 1, M.MAX_WINDOWS + 1 do
    local _, to = M.Lock(id)
    if not to then break end
    id = to
  end
  return frameOf(id) or frameOf(w)
end

-- Puts a window where its lock says: under or beside its target, moving with it and following its
-- height. A window just unlocked stays where it was drawn.
function M.Position(w, f)
  local how, to = M.Lock(w)
  local anchor = how and frameOf(to)
  f.mover = anchor and function() return head(w) end or nil
  if anchor then
    f:ClearAllPoints()
    if how == "below" then
      f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -M.GAP)
    else
      f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", M.GAP, 0)
    end
    f.locked = true
  elseif f.locked then
    f.locked = nil
    -- Its own place again: where it is now when the client can say, else where it was last left.
    local left, top = BF.Pin(f)
    if left then
      local k = kept(w)
      k.point, k.rel, k.x, k.y = "TOPLEFT", "BOTTOMLEFT", left, top
    else
      BF.Place(f)
    end
  end
end

-- Locks a window under or beside another ("below", "beside"; `to` a window's number or "threat", the
-- window before it when left out), or frees it (how = nil). False when that can't be: itself, a ring,
-- or nothing there.
function M.SetLock(w, how, to)
  w = w or 1
  local k = kept(w)
  if how ~= "below" and how ~= "beside" then
    k.lock, k.lockTo = nil, nil
    M.Draw()
    return true
  end
  if w ~= "threat" and type(w) ~= "number" then return false end
  if to == nil and w ~= "threat" then to = M.Before(w) end
  if to == nil or to == w or rings(w, to) or not frameOf(to) then return false end
  k.lock, k.lockTo = how, to
  M.Draw()
  return true
end

-- A window's name in another's list: what it shows ("DPS"), with its number when two show the same;
-- the threat bar is "Threat".
function M.Name(id)
  if id == "threat" then return L["Threat"] end
  local view = M.View(id)
  for i = 1, M.MAX_WINDOWS do
    if i ~= id and M.IsOpen(i) and M.View(i).key == view.key then
      return string.format("%s (%d)", L[view.label], id)
    end
  end
  return L[view.label]
end

-- What a window could be locked to now: the other open windows that wouldn't make a ring, then the
-- threat bar when it is on screen.
function M.Targets(w)
  w = w or 1
  local out = {}
  for i = 1, M.MAX_WINDOWS do
    if i ~= w and frameOf(i) and not rings(w, i) then out[#out + 1] = i end
  end
  if w ~= "threat" and frameOf("threat") and not rings(w, "threat") then out[#out + 1] = "threat" end
  return out
end

-- The locking rows of a window's list (the meter's windows and the threat bar share them): free from
-- what it is locked to, or under or beside anything else on screen, by name.
function M.LockRows(w)
  local rows = {}
  local how, to = M.Lock(w)
  if how then
    rows[#rows + 1] = { text = string.format(L["Unlock from %s"], M.Name(to)), button = true,
      pick = function() M.SetLock(w, nil) end }
    return rows
  end
  local targets = M.Targets(w)
  if #targets > 0 then rows[#rows + 1] = { title = L["Lock this window"] } end
  for _, id in ipairs(targets) do
    local name = M.Name(id)
    rows[#rows + 1] = { text = string.format(L["Under %s"], name), button = true,
      pick = function() M.SetLock(w, "below", id) end }
    rows[#rows + 1] = { text = string.format(L["Beside %s"], name), button = true,
      pick = function() M.SetLock(w, "beside", id) end }
  end
  return rows
end

-- Opens a list of rows ({ title }, { divider }, { text, button, pick } or { text, chosen, pick }) at
-- `owner` with the client's own menu; `list` gives the rows. Returns false on a client without it.
function M.OpenRows(owner, list)
  local open = ns.Fn("MenuUtil", "CreateContextMenu")
  if not open then return false end
  return (pcall(open, owner, function(_, root)
    for _, row in ipairs(list()) do
      if row.title then
        root:CreateTitle(row.title)
      elseif row.divider then
        root:CreateDivider()
      elseif row.button then
        root:CreateButton(row.text, function() ns.Run("meter window", row.pick) end)
      else
        root:CreateRadio(row.text, function() return row.chosen end, function()
          ns.Run("meter pick", row.pick)
        end)
      end
    end
  end))
end

-- Which tally a window is showing, in words, with the fight's length when the game says it plainly:
-- "last fight · 1:05".
function M.Where(sessionKey, data, w)
  local where
  if sessionKey == "id" then
    where = pickedBy[w or 1].name or L["an earlier fight"]
  elseif sessionKey == "overall" then
    where = L["overall"]
  elseif (data and data.last) or not M.Fighting() then
    where = L["last fight"]
  else
    where = L["this fight"]
  end
  local length = data and clock(data.duration)
  return length and string.format("%s · %s", where, length) or where
end

-- Draws one window.
function M.DrawOne(w)
  local f = build(w)
  M.Position(w or 1, f)
  local view = M.View(w)
  local sessionKey = M.SessionKey(w)
  f.title:SetText(L[view.label])
  local data, why = M.Read(view, sessionKey, w)
  f.holder:SetText(M.Where(sessionKey, data, w))

  local rows = data and M.Rows(data) or {}
  for i, bar in ipairs(f.rows) do
    local r = rows[i]
    if r then
      local src = r.src
      -- The name can be secret in a fight: the rank is added only if the client will format it.
      local ok, label = pcall(string.format, "%d. %s", r.rank, src.name)
      bar.left:SetText(ok and label or src.name)
      bar.right:SetText(M.Short(view.rate and src.amountPerSecond or src.totalAmount))
      bar:SetMinMaxValues(0, data.max)
      bar:SetValue(src.totalAmount)
      bar:SetStatusBarColor(BF.ClassRGB(src.classFilename))
      if src.isLocalPlayer == true then bar.mine:Show() else bar.mine:Hide() end
      bar.src = src
      bar:Show()
    else
      bar.src = nil
      bar:Hide()
    end
  end
  f.data, f.view = data, view

  local foot
  if why == "absent" or why == "unavailable" then
    foot = L["The game's meter isn't available here."]
  elseif why == "empty" then
    foot = L["Nothing yet."]
  end
  BF.Foot(f, foot)
  BF.Fit(f, #rows, foot)
  f:Show()
  -- The row under the mouse keeps its detail current.
  if M.hover and M.hover.w == (w or 1) then M.Tip(M.hover.w, M.hover.bar) end
end

-- A row's detail, shown while the mouse is over it: what that player used, as the game counted it.
M.TIP_ROWS = 8

-- The spells behind a row: { spells, max }, or nil and "hidden" (in a fight the game hides who a row
-- is unless they are in your group, and a hidden id can't be asked about), "absent" or "empty".
function M.Spells(w, src)
  local f = M.frames[w or 1]
  local data, view = f and f.data, f and f.view
  if not data or not view or type(src) ~= "table" then return nil, "empty" end
  local guid = src.sourceGUID
  if ns.IsSecret(guid) then return nil, "hidden" end
  local creature = src.sourceCreatureID
  if ns.IsSecret(creature) then creature = nil end
  local kind = enum("DamageMeterType", view.type, view.value)
  local result
  if data.id then
    local byId = ns.Fn("C_DamageMeter", "GetCombatSessionSourceFromID")
    if not byId then return nil, "absent" end
    result = ns.Try(byId, data.id, kind, guid, creature)
  else
    local byType = ns.Fn("C_DamageMeter", "GetCombatSessionSourceFromType")
    if not byType then return nil, "absent" end
    local s = SESSIONS[M.SessionKey(w)] or SESSIONS.current
    result = ns.Try(byType, enum("DamageMeterSessionType", s.name, s.value), kind, guid, creature)
  end
  local spells = type(result) == "table" and result.combatSpells
  if type(spells) ~= "table" or ns.IsSecret(spells) then return nil, "empty" end
  local n = ns.Try(function() return #spells end)
  if type(n) ~= "number" or n == 0 then return nil, "empty" end
  local list, plainAll = {}, true
  for i = 1, n do
    local sp = spells[i]
    if type(sp) == "table" then
      list[#list + 1] = sp
      if ns.IsSecret(sp.totalAmount) or type(sp.totalAmount) ~= "number" then plainAll = false end
    end
  end
  -- Out of a fight the amounts are plain and the biggest goes first; in one they stay as the game gave them.
  if plainAll then table.sort(list, function(a, b) return a.totalAmount > b.totalAmount end) end
  return { spells = list, max = result.maxAmount, plain = plainAll }
end

-- A spell's name for a label, with the pet or guardian that cast it when the game says so plainly.
local function spellName(sp)
  local name = ns.Try(ns.Fn("C_Spell", "GetSpellName"), sp.spellID)
  if not ns.IsSecret(name) and (type(name) ~= "string" or name == "") then name = L["A spell"] end
  local by = sp.creatureName
  if not ns.IsSecret(by) and type(by) == "string" and by ~= "" and not ns.IsSecret(name) then
    return string.format("%s (%s)", name, by)
  end
  return name
end

function M.Tip(w, bar)
  local src = bar and bar.src
  local f = M.frames[w or 1]
  if not src or not f or not f.view then return M.Hover(nil) end
  if not M.tip then
    M.tip = BF.Create({ name = "RynaMeterTip", key = "tip", rows = M.TIP_ROWS, tip = true })
  end
  local tip, view = M.tip, f.view
  tip:ClearAllPoints()
  tip:SetPoint("TOPLEFT", bar, "TOPRIGHT", 8, 0)
  tip.title:SetText(src.name)
  tip.holder:SetText(L[view.label])
  local found, why = M.Spells(w, src)
  local shown = 0
  local r, g, b = BF.ClassRGB(src.classFilename)
  for i, row in ipairs(tip.rows) do
    local sp = found and found.spells[i]
    if sp then
      row.left:SetText(spellName(sp))
      row.right:SetText(M.Short(view.rate and sp.amountPerSecond or sp.totalAmount))
      row:SetMinMaxValues(0, found.max)
      row:SetValue(sp.totalAmount)
      row:SetStatusBarColor(r, g, b)
      row.mine:Hide()
      row:Show()
      shown = shown + 1
    else
      row:Hide()
    end
  end
  local foot
  if why == "hidden" then
    foot = L["The game hides who this is during a fight."]
  elseif not found then
    foot = L["Nothing counted for this row."]
  else
    local total, all = src.totalAmount, f.data and f.data.total
    if not ns.IsSecret(total) and not ns.IsSecret(all) and type(total) == "number" and type(all) == "number"
      and all > 0 then
      foot = string.format(L["%s%% of everyone's"], string.format("%.2f", total / all * 100))
    end
  end
  BF.Foot(tip, foot)
  BF.Fit(tip, shown, foot)
  tip:Show()
end

-- The row the mouse is over (a window's number and its bar), or none.
function M.Hover(w, bar)
  if w and bar and bar.src then
    M.hover = { w = w, bar = bar }
    M.Tip(w, bar)
  else
    M.hover = nil
    if M.tip then M.tip:Hide() end
  end
end

-- Draws every open window, and puts away any that was closed.
function M.Draw()
  for w = 1, M.MAX_WINDOWS do
    if M.IsOpen(w) then
      M.DrawOne(w)
    elseif M.frames[w] then
      M.frames[w]:Hide()
    end
  end
  -- The threat bar may hang from one of these windows, or have just been freed from one.
  local bar = ns.ThreatBar
  if bar and bar.frame then M.Position("threat", bar.frame) end
  M.dirty = false
end

function M.Hide()
  for _, f in pairs(M.frames) do f:Hide() end
  M.Hover(nil)
end

-- The driver's read: every time while anyone in the group is fighting or the game said a tally
-- changed, and otherwise every fourth time (two seconds), so it can never sit on an old fight.
local idle = 0
function M.Tick()
  if not M.On() then return M.Hide() end
  if M.frame and M.frame:IsShown() and not M.dirty and not M.Fighting() then
    idle = idle + 1
    if idle < 4 then return end
  end
  idle = 0
  M.Draw()
end

function M.Pick(key, w)
  kept(w).view = key
  M.Draw()
end

-- A tally: "current" or "overall" (kept), or a past fight by its number (until /reload).
function M.Choose(kind, id, name, w)
  if kind == "id" and type(id) == "number" then
    pickedBy[w or 1] = { id = id, name = name }
  else
    pickedBy[w or 1] = nil
    kept(w).session = kind == "overall" and "overall" or "current"
  end
  M.Draw()
end

function M.Next(w)
  local _, i = M.View(w)
  M.Pick(M.VIEWS[i % #M.VIEWS + 1].key, w)
end

function M.Session(w)
  M.Choose(M.SessionKey(w) == "current" and "overall" or "current", nil, nil, w)
end

-- A view's partner, for what a new window shows beside an open one: damage with healing, DPS with HPS.
local PARTNER = { damage = "healing", healing = "damage", dps = "hps", hps = "dps" }

-- Opens another window: the partner of the first window's view when no open window shows it, else the
-- first view none shows. Returns its number, or nil when every window is open.
function M.Open()
  local shown, free = {}, nil
  for w = 1, M.MAX_WINDOWS do
    if M.IsOpen(w) then shown[M.View(w).key] = true elseif not free then free = w end
  end
  if not free then return nil end
  local view = PARTNER[M.View(1).key]
  if not view or shown[view] then
    view = nil
    for _, v in ipairs(M.VIEWS) do
      if not view and not shown[v.key] then view = v.key end
    end
  end
  local k = kept(free)
  k.open, k.view, k.session = true, view or M.VIEWS[1].key, kept(1).session
  pickedBy[free] = nil
  M.Draw()
  return free
end

-- Closes a window other than the first (the setting turns the meter off).
function M.Close(w)
  if (w or 1) == 1 then return false end
  kept(w).open = nil
  pickedBy[w] = nil
  M.Draw()
  return true
end

-- Announcing: a window's rows said in chat, when the player picks a channel from its list. Only ever
-- on that click, and only what the window shows.
M.ANNOUNCE_ROWS = 5
-- The channels offered, in order: the chat type, its name in the list, and whether it applies now.
M.CHANNELS = {
  { type = "PARTY", label = N("Party"), when = function() return ns.Try(ns.Fn("IsInGroup")) == true end },
  { type = "RAID", label = N("Raid"), when = function() return ns.Try(ns.Fn("IsInRaid")) == true end },
  { type = "GUILD", label = N("Guild"), when = function() return ns.Try(ns.Fn("IsInGuild")) == true end },
  { type = "SAY", label = N("Say"), when = function() return true end },
}

-- The lines an announcement would say: "Meter by Ryna: DPS, last fight · 1:05", then "1. Ilse 18.50".
-- Returns nil and "empty" (nothing to say) or "hidden" (a fight is on: the game hides the names and
-- amounts, and hidden text can't be sent or even put together).
function M.Report(w)
  local view = M.View(w)
  local sessionKey = M.SessionKey(w)
  local data = M.Read(view, sessionKey, w)
  if not data then return nil, "empty" end
  local lines = { string.format(L["Meter by Ryna: %s, %s"], L[view.label], M.Where(sessionKey, data, w)) }
  for i = 1, math.min(data.count, M.ANNOUNCE_ROWS) do
    local src = data.sources[i]
    if type(src) == "table" then
      local amount = view.rate and src.amountPerSecond or src.totalAmount
      if ns.IsSecret(src.name) or ns.IsSecret(amount) then return nil, "hidden" end
      if type(src.name) == "string" and type(amount) == "number" then
        lines[#lines + 1] = string.format("%d. %s %s", i, src.name, M.Short(amount))
      end
    end
  end
  if #lines < 2 then return nil, "empty" end
  return lines
end

-- Says a window's rows in a channel. Returns true, or false and why: "empty", "hidden", "absent" (no
-- way to send) or "refused" (the game wouldn't send it here).
function M.Announce(chatType, w)
  local lines, why = M.Report(w)
  if not lines then return false, why end
  local send = ns.Fn("C_ChatInfo", "SendChatMessage") or ns.Fn("SendChatMessage")
  if not send then return false, "absent" end
  for _, line in ipairs(lines) do
    if not pcall(send, line, chatType) then return false, "refused" end
  end
  return true
end

-- What the player is told when an announcement wasn't made (they asked, so it is answered).
local WHY_NOT = {
  empty = N("There is nothing to announce yet."),
  hidden = N("The game hides the numbers during a fight: announce when it is over."),
  absent = N("The game wouldn't send that here."),
  refused = N("The game wouldn't send that here."),
}

-- How many past fights the pick-list offers, newest first.
M.MENU_FIGHTS = 10

-- What the pick-list holds, as rows: { title }, { divider }, or { text, chosen, pick }. Apart from the
-- client's menu so it can be read without one.
function M.MenuRows(w)
  w = w or 1
  local rows = { { title = L["Show"] } }
  local view = M.View(w)
  for _, v in ipairs(M.VIEWS) do
    rows[#rows + 1] = { text = L[v.label], chosen = v.key == view.key, pick = function() M.Pick(v.key, w) end }
  end
  rows[#rows + 1] = { divider = true }
  rows[#rows + 1] = { title = L["From"] }
  local key = M.SessionKey(w)
  rows[#rows + 1] = { text = L["This fight (or the last one)"], chosen = key == "current",
    pick = function() M.Choose("current", nil, nil, w) end }
  rows[#rows + 1] = { text = L["Overall"], chosen = key == "overall",
    pick = function() M.Choose("overall", nil, nil, w) end }
  local fights = M.Fights()
  for i = #fights, math.max(1, #fights - M.MENU_FIGHTS + 1), -1 do
    local f = fights[i]
    local name = f.name or string.format(L["Fight %d"], f.id)
    local length = clock(f.duration)
    local text = length and string.format("%s · %s", name, length) or name
    rows[#rows + 1] = { text = text, chosen = key == "id" and pickedBy[w].id == f.id,
      pick = function() M.Choose("id", f.id, name, w) end }
  end
  rows[#rows + 1] = { divider = true }
  rows[#rows + 1] = { title = L["Announce to"] }
  for _, c in ipairs(M.CHANNELS) do
    if c.when() then
      rows[#rows + 1] = { text = L[c.label], button = true, pick = function()
        local ok, why = M.Announce(c.type, w)
        if not ok then ns.Print(L[WHY_NOT[why] or WHY_NOT.refused]) end
      end }
    end
  end
  -- Windows: another one while there is room, and closing this one when it isn't the first.
  local open = 0
  for i = 1, M.MAX_WINDOWS do
    if M.IsOpen(i) then open = open + 1 end
  end
  if open < M.MAX_WINDOWS or w > 1 then rows[#rows + 1] = { divider = true } end
  if open < M.MAX_WINDOWS then
    rows[#rows + 1] = { text = L["Open another window"], button = true, pick = function() M.Open() end }
  end
  if w > 1 then
    rows[#rows + 1] = { text = L["Close this window"], button = true, pick = function() M.Close(w) end }
  end
  local lock = M.LockRows(w)
  if #lock > 0 then rows[#rows + 1] = { divider = true } end
  for _, row in ipairs(lock) do rows[#rows + 1] = row end
  return rows
end

-- Opens the pick-list at `owner` with the client's own menu. Returns false on a client without it
-- (the click then goes to the next view).
function M.Menu(owner, w)
  return M.OpenRows(owner, function() return M.MenuRows(w) end)
end

function M.ResetPlace()
  for w = 1, M.MAX_WINDOWS do BF.Forget(M.frames[w], keyOf(w)) end
end

function M.Register()
  if M.driver then return end
  local driver = CreateFrame("Frame")
  local since = 0
  driver:SetScript("OnUpdate", function(_, elapsed)
    since = since + (tonumber(elapsed) or 0)
    if since < M.INTERVAL then return end
    since = 0
    ns.Run("meter bars", M.Tick)
  end)
  M.driver = driver
  M.dirty = true
  local function changed() M.dirty = true end
  for _, event in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_RESET", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    ns.API.On(event, changed)
  end
end
