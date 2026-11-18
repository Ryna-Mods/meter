-- ThreatBar: the small frame that shows, while the group is fighting, how close each member is to
-- pulling one enemy (Threat.lua reads it; docs/ryna-agent-cores-mods.md 7.5, "The threat bar"). One
-- row per member, whoever holds the enemy on top, a full bar meaning "pulls". Past 80% a bar turns
-- orange and the frame's edge with it. It is silent: no chat line, no sound. Between fights and when
-- alone it stays on screen, empty ("Nobody is fighting."), unless meterThreatStay is off; it is away
-- while the setting (meterThreat) is off.
--
-- Where the client hides the numbers (a raid may), the bar is still filled, because a status bar
-- takes a secret value; the rows keep the group's order, the percentage is left out and the words
-- come from the threat state. Nothing secret is compared, measured or kept.
--
-- The frame is dragged with the left button and its place is kept in RynaDB.meter.threatBar.
-- /ryna meter threat shows it with example rows, to be placed outside a fight.

local _, ns = ...
if ns.off then return end
local L = ns.L
local T = ns.Threat
local BF = ns.BarFrame

local B = {}
ns.ThreatBar = B

B.KEY = "meterThreat"
-- Whether the frame stays on screen, empty, when nobody is fighting (on), or goes away (off).
B.STAY = "meterThreatStay"
B.INTERVAL = 0.25

ns.API.Settings.AddDefaults({ [B.KEY] = true, [B.STAY] = true })

function B.On()
  return ns.API.Settings.Get(B.KEY) and true or false
end

local function build()
  if not B.frame then
    B.frame = BF.Create({
      name = "RynaThreatBar", key = "threatBar", rows = T.MAX_ROWS, x = 280, y = -60,
      -- A click on its first line: the list that locks it to a meter window, or frees it.
      onClick = function() B.Menu() end,
      onEnter = function(owner)
        local tip = _G.GameTooltip
        if not tip or not tip.SetOwner then return end
        tip:SetOwner(owner, "ANCHOR_TOP")
        tip:AddLine(L["Click: lock this to another window. Drag to move."], 1, 1, 1, true)
        tip:Show()
      end,
    })
  end
  return B.frame
end

-- Where the frame goes: under or beside the meter window it is locked to (Bars.lua keeps every lock).
local function settle(f)
  if ns.Bars then ns.Bars.Position("threat", f) end
end

-- What a row says on the right: "has it", a percentage, or (numbers hidden) "close" or nothing.
function B.Label(r)
  if T.Holds(r) then return L["has it"] end
  if r.hidden then return T.Close(r) and L["close"] or "" end
  return string.format("%d%%", math.floor(r.pct + 0.5))
end

-- An enemy's name for a label. In combat it can be secret: it is passed on to the label untouched,
-- and only a missing one is replaced.
local function mobName(unit)
  local name = ns.Try(ns.Fn("UnitName"), unit)
  if ns.IsSecret(name) then return name end
  if type(name) == "string" and name ~= "" then return name end
  return L["An enemy"]
end

function B.Draw(snap)
  local f = build()
  f.title:SetText(snap.name or mobName(snap.mob))

  local holder
  for _, r in ipairs(snap.rows) do
    if not holder and T.Holds(r) then holder = r end
  end
  f.holder:SetText(holder and holder.name and string.format(L["on %s"], holder.name) or "")

  for i, bar in ipairs(f.rows) do
    local r = snap.rows[i]
    if r then
      bar.left:SetText(r.name or L["Someone"])
      bar.right:SetText(B.Label(r))
      if r.hidden then
        -- A secret goes straight to the bar: the client fills it, and nothing here reads it.
        bar:SetValue(r.pct)
      else
        bar:SetValue(r.tanking and 100 or math.min(r.pct, 100))
      end
      if T.Close(r) then
        bar:SetStatusBarColor(BF.WARN[1], BF.WARN[2], BF.WARN[3])
      else
        bar:SetStatusBarColor(BF.ClassRGB(r.class))
      end
      if r.me then bar.mine:Show() else bar.mine:Hide() end
      bar:Show()
    else
      bar:Hide()
    end
  end

  local foot
  if snap.note then
    foot = snap.note
  elseif snap.hidden then
    foot = L["The game hides the numbers here."]
  elseif snap.top then
    local pct = math.floor(snap.top.pct + 0.5)
    -- The enemy's name may be secret; if the client won't format it, the line goes without it.
    local ok, line = pcall(string.format, L["Your highest: %s, %d%%"], mobName(snap.top.mob), pct)
    foot = ok and line or string.format(L["Your highest elsewhere: %d%%"], pct)
  end
  BF.Foot(f, foot)
  BF.Edge(f, snap.warn)
  settle(f)
  BF.Fit(f, #snap.rows, foot)
  f:Show()
end

function B.Hide()
  if B.frame then B.frame:Hide() end
end

-- The threat bar's own list: lock it to a meter window on screen, or free it.
function B.MenuRows()
  local rows = ns.Bars and ns.Bars.LockRows("threat") or {}
  if #rows == 0 then rows[1] = { title = L["Open the meter to lock this to it."] } end
  return rows
end

function B.Menu()
  if not (ns.Bars and B.frame and B.frame.head) then return false end
  return ns.Bars.OpenRows(B.frame.head, B.MenuRows)
end

-- The frame with nothing to show: its name and one line, so it keeps its place on screen between fights.
function B.DrawIdle()
  local f = build()
  f.title:SetText(L["Threat"])
  f.holder:SetText("")
  for _, bar in ipairs(f.rows) do bar:Hide() end
  BF.Foot(f, L["Nobody is fighting."])
  BF.Edge(f, false)
  settle(f)
  BF.Fit(f, 0, true)
  f:Show()
end

-- Nothing to read: the empty frame when it is set to stay, else none.
local function idle()
  if ns.API.Settings.Get(B.STAY) then return B.DrawIdle() end
  return B.Hide()
end

-- One read and draw; the driver calls it four times a second.
function B.Tick()
  if B.placing then return end
  if not B.On() then return B.Hide() end
  local snap = T.Snapshot()
  if not snap then return idle() end
  B.Draw(snap)
end

-- The bar with example rows, to be dragged into place outside a fight. Returns whether it is now
-- showing them. A fight starting ends it.
function B.Place()
  if B.placing then
    B.placing = false
    B.Hide()
    return false
  end
  B.placing = true
  local _, class = ns.Try(ns.Fn("UnitClass"), "player")
  B.Draw({
    name = L["Example enemy"],
    note = L["An example. Drag the bar where you want it."],
    warn = true,
    rows = {
      { name = L["The tank"], class = "WARRIOR", tanking = true, pct = 100, status = 3 },
      { name = L["A damage dealer"], class = "MAGE", tanking = false, pct = 86, status = 0 },
      { name = ns.NonEmpty(ns.Try(ns.Fn("UnitName"), "player")) or L["You"], class = class, me = true,
        tanking = false, pct = 31, status = 0 },
    },
  })
  return true
end

function B.ResetPlace()
  BF.Forget(B.frame, "threatBar")
end

function B.Register()
  if B.driver then return end
  local driver = CreateFrame("Frame")
  local since = 0
  driver:SetScript("OnUpdate", function(_, elapsed)
    since = since + (tonumber(elapsed) or 0)
    if since < B.INTERVAL then return end
    since = 0
    ns.Run("threat bar", B.Tick)
  end)
  B.driver = driver
  ns.API.On("PLAYER_REGEN_DISABLED", function() B.placing = false end)
end
