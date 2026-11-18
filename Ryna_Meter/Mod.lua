-- Mod: Meter's namespace, built from the core's mod API (the `Ryna` table, the core addon's Mods.lua).
-- Meter is what is happening in a fight, live, read from the game itself
-- (docs/ryna-agent-cores-mods.md 7.5, "The Meter mod"): the meter (Bars.lua), the game's own tallies of
-- damage, healing and the rest drawn in a small frame, and the threat bar (Threat.lua, ThreatBar.lua),
-- each group member's threat on one enemy while the group is fighting. Both frames are Frame.lua's.
-- The finished fight, its story and its timeline are the Fights mod's, from the combat log as the
-- Ryna app reads it; Meter needs nothing from the app.
--
-- It keeps two settings (meterBars, meterThreat) and, in RynaDB.meter, where the frames were dragged
-- and which view the meter shows. It sends nothing to Ryna and never prints to chat unasked;
-- the one thing it says to others is a meter window's rows, when the player picks Announce.
--
-- Every file starts with `if ns.off then return end`: without the mod API (a core addon from before
-- it), Meter loads nothing at all, and says nothing either.

local addonName, ns = ...

local R = _G.Ryna
-- The core API level this mod needs is the TOC's (## X-Ryna-API), the one place it is written;
-- on a core below it nothing loads, and the core's Mods tab says why.
local needs, known = 1, false
do
  local read = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  local ok, level = pcall(function() return tonumber(read(addonName, "X-Ryna-API")) end)
  if ok and level then needs, known = level, true end
end
-- Nor on a core that no longer serves this mod's level (R.API_MIN, absent on a core before it);
-- only when the TOC's level could be read, so a client that won't say never turns the mod off.
local tooOld = known and type(R) == "table" and type(R.API_MIN) == "number" and needs < R.API_MIN
if type(R) ~= "table" or type(R.API) ~= "number" or R.API < needs or tooOld or type(R.RegisterMod) ~= "function" then
  ns.off = true
  return
end

ns.NAME = addonName
ns.API = R

-- The version is the TOC's, so there is no second copy to keep in step.
local metadata = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
ns.VERSION = R.Try(metadata, addonName, "Version")

for _, name in ipairs({ "Try", "Fn", "IsSecret", "NonEmpty", "Print", "Debug", "Run", "ReportError", "N", "Locale" }) do
  ns[name] = R[name]
end

-- Meter's strings (Locales/), falling back to the core's (Ryna.L), which fall back to the key.
ns.L = setmetatable({}, {
  __index = function(_, key) return R.L[key] end,
  __newindex = function(t, key, value)
    if type(value) == "string" and value ~= "" then rawset(t, key, value) end
  end,
})
