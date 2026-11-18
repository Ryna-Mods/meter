-- Tab: Meter's tab in the core's panel (Ryna.Panel.AddTab), after Prices and before Messages, built
-- with the core's widgets: what the mod does, the meter's checkbox and the threat bar's.

local _, ns = ...
if ns.off then return end
local L = ns.L
local B = ns.ThreatBar
local M = ns.Bars

local W = ns.API.Panel and ns.API.Panel.Widgets
if type(W) ~= "table" or type(W.checkbox) ~= "function" then return end

local P = {}

local function build(f)
  P.intro = W.text(f, "GameFontHighlightSmall", 11)
  P.intro:SetText(L["Meter shows a fight as it happens: a meter of what the game itself counts, and a threat "
    .. "bar while your group is fighting. It reads the game only: it does nothing for you, keeps nothing "
    .. "and says nothing in chat."])
  P.meter = W.checkbox(f, L["Show the meter"],
    L["Damage, healing and more for everyone in the fight, as the game counts them, live. Click its first "
      .. "line to choose what to show (damage, DPS, healing, HPS, damage taken, absorbs, interrupts, dispels) "
      .. "and which fight, right-click it for this fight or overall, and drag it to move it."])
  W.toggle(P.meter, M.KEY, function()
    M.dirty = true
    M.Tick()
    ns.API.Panel.RefreshIfShown()
  end)
  P.bar = W.checkbox(f, L["Show the threat bar while my group is fighting"],
    L["A small bar per group member for the enemy you have targeted: how close each is to pulling it. With a "
      .. "friend targeted, it follows the enemy that friend is on, from the nameplates on screen. Past 80% a "
      .. "bar turns orange. Hidden when you are alone. Drag it to move it; /ryna meter threat shows it with "
      .. "an example so you can place it outside a fight."])
  W.toggle(P.bar, B.KEY, function()
    if not B.On() then B.Hide() end
    ns.API.Panel.RefreshIfShown()
  end)
  P.stay = W.checkbox(f, L["Keep it on screen between fights"],
    L["On: the threat bar stays where you put it, empty, when nobody is fighting or you are alone. Off: it "
      .. "only appears while your group is fighting."])
  W.toggle(P.stay, B.STAY, function()
    B.Tick()
    ns.API.Panel.RefreshIfShown()
  end)
end

local function layout(s, settings)
  s.text(P.intro, 0, 12)
  P.meter:SetChecked(settings[M.KEY] and true or false)
  P.meter.place(s, 4)
  P.bar:SetChecked(settings[B.KEY] and true or false)
  P.bar.place(s, 4)
  P.stay:SetChecked(settings[B.STAY] and true or false)
  P.stay.setActive(settings[B.KEY] and true or false)
  P.stay.place(s, 30)
end

ns.API.Panel.AddTab({ key = "meter", label = L["Meter"], order = 39, build = build, layout = layout })
