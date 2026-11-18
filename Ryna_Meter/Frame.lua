-- Frame: the small bar frame the threat bar and the meter share (ThreatBar.lua, Bars.lua): a dark
-- panel with a one-pixel edge, a title and a dimmer label on the first line, rows that are status bars
-- with a name on the left and words on the right, and a line under them. It is dragged with the left
-- button and its place is kept in RynaDB.meter[<key>]. Nothing here reads the game.
--
--   F.Create{ name, key, rows, x, y, onClick, onEnter }   the frame, hidden; onClick(button) makes the
--                                                         first line a button (it still drags);
--                                                         onRowEnter(bar, i) and onRowLeave(bar, i)
--                                                         make the rows answer the mouse; tip = true
--                                                         makes a frame that floats over the rest
--                                                         and takes no mouse (a row's detail)
--   F.Place(f), F.Forget(f)    put it where it was left (or at its default); forget that and put it back
--   F.Pin(f)                   hold it by its top left corner where it stands, so it grows downwards
--   f.mover                    set by the owner: a function naming the frame a drag of this one moves
--   F.Edge(f, warn)            the edge in its usual colour, or the warning one
--   F.Fit(f, rows, foot)       its height for that many rows, with or without the line under them
--   F.Foot(f, text)            the line under the rows, or none; returns whether there is one
--   F.ClassRGB(class)          a class's colour for a bar, grey without one

local _, ns = ...
if ns.off then return end

local F = {}
ns.BarFrame = F

F.WIDTH, F.ROW, F.HEAD, F.PAD = 220, 17, 16, 4
F.WARN, F.GOLD, F.DIM = { 0.94, 0.54, 0.17 }, { 1, 0.82, 0 }, { 0.62, 0.59, 0.67 }
local EDGE, PLAIN_BAR = { 0.23, 0.21, 0.28 }, { 0.56, 0.54, 0.61 }
local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- RynaDB.meter, the mod's own key (made on first use); nil before the client has loaded RynaDB.
function F.Saved()
  local db = ns.API.DB()
  if type(db) ~= "table" then return nil end
  if type(db.meter) ~= "table" then db.meter = {} end
  return db.meter
end

local function fontString(parent, justify)
  local ok, fs = pcall(parent.CreateFontString, parent, nil, "OVERLAY", "GameFontHighlightSmall")
  if not ok or not fs then fs = parent:CreateFontString(nil, "OVERLAY") end
  fs:SetJustifyH(justify)
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  return fs
end

local function colour(tex, c, a)
  tex:SetColorTexture(c[1], c[2], c[3], a or 1)
end

-- Pins a frame by its top left corner, where it stands, so that more rows make it grow downwards: a
-- frame held by its centre grows both ways, and one the client re-anchored to a bottom corner after a
-- drag grows upwards. Returns the corner (from the screen's bottom left), or nil on a client that
-- can't say where the frame is, which leaves it as it was.
function F.Pin(f)
  local left, top = ns.Try(f.GetLeft, f), ns.Try(f.GetTop, f)
  if type(left) ~= "number" or type(top) ~= "number" then return nil end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", left, top)
  return left, top
end

function F.Place(f)
  local saved = F.Saved()
  local at = saved and saved[f.key]
  f:ClearAllPoints()
  if type(at) == "table" and type(at.point) == "string" and type(at.x) == "number" and type(at.y) == "number" then
    f:SetPoint(at.point, _G.UIParent, type(at.rel) == "string" and at.rel or at.point, at.x, at.y)
  else
    f:SetPoint("CENTER", _G.UIParent, "CENTER", f.defaultX, f.defaultY)
  end
  f.pinned = F.Pin(f) ~= nil
end

-- Forgets where it was dragged, keeping whatever else is kept under the key.
function F.Forget(f, key)
  local saved = F.Saved()
  local at = saved and saved[key or (f and f.key)]
  if type(at) == "table" then at.point, at.rel, at.x, at.y = nil, nil, nil, nil end
  if f then F.Place(f) end
end

local function newRow(f, i)
  local bar = CreateFrame("StatusBar", nil, f)
  bar:SetStatusBarTexture(TEXTURE)
  bar:SetMinMaxValues(0, 100)
  bar:SetHeight(F.ROW - 1)
  bar:SetPoint("TOPLEFT", f, "TOPLEFT", F.PAD, -(F.PAD + F.HEAD + (i - 1) * F.ROW))
  bar:SetPoint("RIGHT", f, "RIGHT", -F.PAD, 0)
  bar.back = bar:CreateTexture(nil, "BACKGROUND")
  bar.back:SetAllPoints()
  colour(bar.back, { 0.16, 0.15, 0.21 }, 0.9)
  -- The mark on the player's own row.
  bar.mine = bar:CreateTexture(nil, "OVERLAY")
  bar.mine:SetPoint("TOPLEFT")
  bar.mine:SetPoint("BOTTOMLEFT")
  bar.mine:SetWidth(2)
  colour(bar.mine, F.GOLD)
  bar.left = fontString(bar, "LEFT")
  bar.left:SetPoint("LEFT", bar, "LEFT", 5, 0)
  bar.right = fontString(bar, "RIGHT")
  bar.right:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  bar.left:SetPoint("RIGHT", bar.right, "LEFT", -4, 0)
  bar:Hide()
  return bar
end

function F.Create(spec)
  local f = CreateFrame("Frame", spec.name, _G.UIParent)
  f.key, f.defaultX, f.defaultY = spec.key, spec.x or 0, spec.y or 0
  f.floats = spec.tip and true or false
  f:SetSize(F.WIDTH, F.HEAD + F.ROW + 2 * F.PAD)
  f:SetFrameStrata(spec.tip and "TOOLTIP" or "MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(not spec.tip)
  f:EnableMouse(not spec.tip)
  if not spec.tip then f:RegisterForDrag("LeftButton") end
  -- A drag moves this frame, or the one f.mover() names (a frame locked to another moves that one, and
  -- so the whole group); the place kept is the moved frame's.
  local moving
  local function dragStart()
    moving = (type(f.mover) == "function" and f.mover()) or f
    moving:StartMoving()
  end
  local function dragStop()
    local m = moving or (type(f.mover) == "function" and f.mover()) or f
    moving = nil
    m:StopMovingOrSizing()
    ns.Run(spec.key .. " place", function()
      -- The client leaves a dragged frame on whichever corner was nearest: back to its top left.
      F.Pin(m)
      local point, _, rel, x, y = m:GetPoint(1)
      local saved = F.Saved()
      if not saved or type(point) ~= "string" then return end
      if type(saved[m.key]) ~= "table" then saved[m.key] = {} end
      local at = saved[m.key]
      at.point, at.rel, at.x, at.y = point, rel, x, y
    end)
  end
  f:SetScript("OnDragStart", dragStart)
  f:SetScript("OnDragStop", dragStop)

  f.back = f:CreateTexture(nil, "BACKGROUND")
  f.back:SetAllPoints()
  colour(f.back, { 0.08, 0.07, 0.1 }, 0.88)
  f.edges = {}
  for i, points in ipairs({
    { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "v" }, { "TOPRIGHT", "BOTTOMRIGHT", "v" },
  }) do
    local e = f:CreateTexture(nil, "BORDER")
    e:SetPoint(points[1])
    e:SetPoint(points[2])
    if points[3] == "h" then e:SetHeight(1) else e:SetWidth(1) end
    f.edges[i] = e
  end
  F.Edge(f, false)

  f.title = fontString(f, "LEFT")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", F.PAD + 2, -F.PAD)
  f.title:SetTextColor(F.GOLD[1], F.GOLD[2], F.GOLD[3])
  f.holder = fontString(f, "RIGHT")
  f.holder:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(F.PAD + 2), -F.PAD)
  f.holder:SetTextColor(F.DIM[1], F.DIM[2], F.DIM[3])
  f.title:SetPoint("RIGHT", f.holder, "LEFT", -6, 0)
  f.foot = fontString(f, "LEFT")
  f.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", F.PAD + 2, F.PAD)
  f.foot:SetPoint("RIGHT", f, "RIGHT", -F.PAD, 0)
  f.foot:SetTextColor(F.DIM[1], F.DIM[2], F.DIM[3])
  f.foot:Hide()

  if type(spec.onClick) == "function" then
    -- The first line as a button. It takes the mouse there, so it starts the frame's drag itself.
    local head = CreateFrame("Button", nil, f)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(F.HEAD + F.PAD)
    head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", dragStart)
    head:SetScript("OnDragStop", dragStop)
    head:SetScript("OnClick", function(_, button) ns.Run(spec.key .. " click", spec.onClick, button) end)
    if type(spec.onEnter) == "function" then
      head:SetScript("OnEnter", function(self) ns.Run(spec.key .. " hint", spec.onEnter, self) end)
      head:SetScript("OnLeave", function()
        if _G.GameTooltip and _G.GameTooltip.Hide then _G.GameTooltip:Hide() end
      end)
    end
    f.head = head
  end

  f.rows = {}
  for i = 1, spec.rows do
    local bar = newRow(f, i)
    f.rows[i] = bar
    if type(spec.onRowEnter) == "function" then
      -- A row that answers the mouse takes it from the frame, so it carries the frame's drag itself.
      bar:EnableMouse(true)
      bar:RegisterForDrag("LeftButton")
      bar:SetScript("OnDragStart", dragStart)
      bar:SetScript("OnDragStop", dragStop)
      bar:SetScript("OnEnter", function(self) ns.Run(spec.key .. " row", spec.onRowEnter, self, i) end)
      bar:SetScript("OnLeave", function(self)
        if type(spec.onRowLeave) == "function" then ns.Run(spec.key .. " row", spec.onRowLeave, self, i) end
      end)
    end
  end
  F.Place(f)
  f:Hide()
  return f
end

function F.Edge(f, warn)
  local c = warn and F.WARN or EDGE
  for _, e in ipairs(f.edges) do colour(e, c) end
  f.warn = warn and true or false
end

function F.Foot(f, text)
  if text then
    f.foot:SetText(text)
    f.foot:Show()
    return true
  end
  f.foot:Hide()
  return false
end

function F.Fit(f, rows, foot)
  -- A frame the client couldn't place yet when it was made (no size, no corner) is pinned on its first
  -- fit instead; one locked to another frame, or floating beside a row, is held by that already.
  if not f.pinned and not f.locked and not f.floats then f.pinned = F.Pin(f) ~= nil end
  f:SetHeight(F.HEAD + rows * F.ROW + 2 * F.PAD + (foot and 14 or 0))
end

function F.ClassRGB(class)
  local colors = _G.RAID_CLASS_COLORS
  local c = type(class) == "string" and type(colors) == "table" and colors[class]
  if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
  return PLAIN_BAR[1], PLAIN_BAR[2], PLAIN_BAR[3]
end
