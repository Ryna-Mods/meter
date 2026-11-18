-- Init: Meter registers with the core (Ryna.RegisterMod). Loaded last, so every handler exists. At
-- login it starts the meter (Bars.lua) and the threat bar (ThreatBar.lua). /ryna meter turns the meter
-- on or off; /ryna meter threat shows the threat bar with an example, to be dragged into place.

local _, ns = ...
if ns.off then return end
local L = ns.L

ns.API.RegisterMod({
  id = "meter",
  addon = ns.NAME,
  name = "Meter",
  version = ns.VERSION,
  onLogin = function()
    ns.Run("meter bars", ns.Bars.Register)
    ns.Run("threat bar", ns.ThreatBar.Register)
  end,
  onDefaults = function()
    ns.Run("meter place", ns.Bars.ResetPlace)
    ns.Run("threat bar place", ns.ThreatBar.ResetPlace)
  end,
})

-- The minimap button's menu: the meter and the threat bar as tick boxes, and another meter window.
local Mini = ns.API.Minimap
if type(Mini) == "table" and type(Mini.Add) == "function" then
  Mini.Add({ label = L["Meter"], order = 20, checked = function() return ns.Bars.On() end, run = function()
    ns.API.Settings.Set(ns.Bars.KEY, not ns.Bars.On())
    ns.Bars.dirty = true
    ns.Bars.Tick()
  end })
  Mini.Add({ label = L["Threat bar"], order = 21, checked = function() return ns.ThreatBar.On() end,
    run = function()
      ns.API.Settings.Set(ns.ThreatBar.KEY, not ns.ThreatBar.On())
      ns.ThreatBar.Tick()
      ns.Bars.dirty = true
    end })
  Mini.Add({ label = L["Another meter window"], order = 22, run = function()
    if ns.Bars.On() then ns.Bars.Open() end
  end })
end

local Slash = ns.API.Slash
if type(Slash) == "table" and type(Slash.Add) == "function" then
  Slash.Add({
    word = "meter",
    order = 72,
    help = L["/ryna meter: the meter on or off; /ryna meter threat: place the threat bar"],
    run = function(arg)
      if type(arg) == "string" and arg:lower() == "threat" then
        if not ns.ThreatBar.On() then
          ns.Print(L["The threat bar is off: turn it on in /ryna, under Meter."])
        elseif ns.ThreatBar.Place() then
          ns.Print(L["The threat bar is showing an example: drag it where you want it, then type "
            .. "/ryna meter threat again."])
        end
        return
      end
      local on = not ns.Bars.On()
      ns.API.Settings.Set(ns.Bars.KEY, on)
      ns.Bars.dirty = true
      ns.Bars.Tick()
      ns.Print(on and L["The meter is on."] or L["The meter is off."])
    end,
  })
end
