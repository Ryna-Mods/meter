-- English (enUS): every string Meter by Ryna shows, keyed by the English text itself. `true` means "the
-- text is the key"; ns.L returns the key for anything no locale file translates, so English is always
-- the fallback. The other Locales/*.lua files are templates for translators, generated from this one:
-- after adding, changing or removing a string here, run (from the repository root)
--
--   node cores/wow/addon/tools/strings.mjs --templates
--
-- which rewrites them with the same keys, keeping every translation already in them. Without
-- --templates it only checks that this list matches what the code uses (L["..."] and N("...")).
-- Debug lines (ns.Debug) are English on purpose and are not listed. A key the core addon's
-- Locales/enUS.lua already has isn't repeated here: Meter's L falls back to it.

local _, ns = ...
if ns.off then return end
local L = ns.L

-- Init.lua
-- /ryna's help line for the command.
L["/ryna meter: the meter on or off; /ryna meter threat: place the threat bar"] = true
-- Answers to /ryna meter.
L["The meter is on."] = true
L["The meter is off."] = true
-- Answers to /ryna meter threat.
L["The threat bar is off: turn it on in /ryna, under Meter."] = true
L["The threat bar is showing an example: drag it where you want it, then type /ryna meter threat again."] = true

-- The minimap button's menu.
L["Threat bar"] = true
L["Another meter window"] = true

-- Tab.lua: the Meter tab of /ryna.
L["Meter"] = true
L["Meter shows a fight as it happens: a meter of what the game itself counts, and a threat bar while your "
  .. "group is fighting. It reads the game only: it does nothing for you, keeps nothing and says nothing in "
  .. "chat."] = true
L["Show the meter"] = true
L["Damage, healing and more for everyone in the fight, as the game counts them, live. Click its first line "
  .. "to choose what to show (damage, DPS, healing, HPS, damage taken, absorbs, interrupts, dispels) and "
  .. "which fight, right-click it for this fight or overall, and drag it to move it."] = true
L["Show the threat bar while my group is fighting"] = true
L["A small bar per group member for the enemy you have targeted: how close each is to pulling it. With a "
  .. "friend targeted, it follows the enemy that friend is on, from the nameplates on screen. Past 80% a bar "
  .. "turns orange. Hidden when you are alone. Drag it to move it; /ryna meter threat shows it with an "
  .. "example so you can place it outside a fight."] = true

L["Keep it on screen between fights"] = true
L["On: the threat bar stays where you put it, empty, when nobody is fighting or you are alone. Off: it only "
  .. "appears while your group is fighting."] = true

-- Bars.lua: the meter's views, as its first line names them.
L["Damage"] = true
L["DPS"] = true
L["Healing"] = true
L["HPS"] = true
L["Damage taken"] = true
L["Absorbs"] = true
L["Interrupts"] = true
L["Dispels"] = true
-- Beside the view: which tally, and (after " · ") the fight's length.
L["this fight"] = true
L["last fight"] = true
L["an earlier fight"] = true
L["overall"] = true
-- The hint on the first line.
L["Click: choose what to show. Right-click: this fight or overall. Drag to move."] = true
-- The pick-list a click opens: its two headings, the two standing tallies, and a past fight the game
-- gave no name for. %d: the game's number for that fight.
L["Show"] = true
L["From"] = true
L["This fight (or the last one)"] = true
L["Overall"] = true
L["Fight %d"] = true
-- A row's detail, shown while the mouse is over it: a spell the game couldn't name, the lines under the
-- spells, and the row's share of the whole tally. %s: a percentage to two decimals ("32.10").
L["A spell"] = true
L["The game hides who this is during a fight."] = true
L["Nothing counted for this row."] = true
L["%s%% of everyone's"] = true
-- Announcing a window's rows in chat, from the pick-list: the heading and the channels.
L["Announce to"] = true
L["Party"] = true
L["Raid"] = true
L["Guild"] = true
L["Say"] = true
-- The first line said in chat. %s: the view ("DPS"); %s: which fight and its length ("last fight · 1:05").
L["Meter by Ryna: %s, %s"] = true
-- Told to the player alone when an announcement wasn't made.
L["There is nothing to announce yet."] = true
L["The game hides the numbers during a fight: announce when it is over."] = true
L["The game wouldn't send that here."] = true
-- The pick-list's last rows: a second (third, fourth) meter window, and closing one.
L["Open another window"] = true
L["Close this window"] = true
-- Locking a window to another on screen, so they sit together and drag as one, and freeing it. %s: the
-- other window by what it shows ("DPS", "Healing (2)", "Threat").
L["Lock this window"] = true
L["Under %s"] = true
L["Beside %s"] = true
L["Unlock from %s"] = true
-- Under the rows when there is nothing to show.
L["The game's meter isn't available here."] = true
L["Nothing yet."] = true

-- ThreatBar.lua: the bar on screen during a fight.
-- A row's right side for whoever the enemy is attacking, and (numbers hidden) for someone near pulling it.
L["has it"] = true
L["close"] = true
-- Beside the enemy's name: who it is on. %s: a group member's name.
L["on %s"] = true
-- Stand-ins for a name the game didn't give.
L["An enemy"] = true
L["Someone"] = true
-- Under the rows, where the game won't give threat as numbers (a raid may not).
L["The game hides the numbers here."] = true
-- Under the rows: the player's highest threat on another enemy. %s: that enemy; %d: percent.
L["Your highest: %s, %d%%"] = true
L["Your highest elsewhere: %d%%"] = true
-- The hint on the bar's first line, and its list when there is no meter window to lock to.
L["Click: lock this to another window. Drag to move."] = true
L["Open the meter to lock this to it."] = true
-- The bar between fights, when it is set to stay: its name, and the line under it.
L["Threat"] = true
L["Nobody is fighting."] = true
-- The example the bar shows for /ryna meter threat.
L["Example enemy"] = true
L["An example. Drag the bar where you want it."] = true
L["The tank"] = true
L["A damage dealer"] = true
L["You"] = true
