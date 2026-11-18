-- German (deDE) strings for Meter by Ryna. Loaded on every client, applied only when the game
-- runs in deDE: GetLocale() is "deDE".
--
-- How to translate:
--   - Each line is L["English"] = nil. Replace nil with your text in double quotes:
--       L["Take part in the census"] = "..."
--     A line left as nil shows the English, so a partial translation is fine.
--   - Keep every %s and %d, in the same order (WoW's string.format can't reorder them).
--   - Keep "||" as it is: it prints one "|" in chat. Inside a command (/ryna debug on||off||toggle,
--     /who, /reload) keep the words in English: they are what the player types.
--   - Plurals: a pair like "%d player" / "%d players" is used for 1 / everything else.
--     For a language with more forms, use the wording that reads best for most numbers.
--   - Keys are the English text and must stay exactly as they are; only change the values.
--   - Test: set the client's language (Battle.net -> Settings -> Game Settings -> Text Language,
--     or SET textLocale "deDE" in WTF/Config.wtf, with that language installed), log in, then
--     /ryna, /ryna status and /ryna help.
-- This file is generated from enUS.lua by cores/wow/addon/tools/strings.mjs --templates, which keeps the
-- translations already here; run it after enUS.lua changes.

local _, ns = ...
if ns.off then return end
if ns.Locale() ~= "deDE" then return end
local L = ns.L

-- Init.lua
-- /ryna's help line for the command.
L["/ryna meter: the meter on or off; /ryna meter threat: place the threat bar"] = nil
-- Answers to /ryna meter.
L["The meter is on."] = nil
L["The meter is off."] = nil
-- Answers to /ryna meter threat.
L["The threat bar is off: turn it on in /ryna, under Meter."] = nil
L["The threat bar is showing an example: drag it where you want it, then type /ryna meter threat again."] = nil

-- The minimap button's menu.
L["Threat bar"] = nil
L["Another meter window"] = nil

-- Tab.lua: the Meter tab of /ryna.
L["Meter"] = nil
L["Meter shows a fight as it happens: a meter of what the game itself counts, and a threat bar while your "
  .. "group is fighting. It reads the game only: it does nothing for you, keeps nothing and says nothing in "
  .. "chat."] = nil
L["Show the meter"] = nil
L["Damage, healing and more for everyone in the fight, as the game counts them, live. Click its first line "
  .. "to choose what to show (damage, DPS, healing, HPS, damage taken, absorbs, interrupts, dispels) and "
  .. "which fight, right-click it for this fight or overall, and drag it to move it."] = nil
L["Show the threat bar while my group is fighting"] = nil
L["A small bar per group member for the enemy you have targeted: how close each is to pulling it. With a "
  .. "friend targeted, it follows the enemy that friend is on, from the nameplates on screen. Past 80% a bar "
  .. "turns orange. Hidden when you are alone. Drag it to move it; /ryna meter threat shows it with an "
  .. "example so you can place it outside a fight."] = nil

L["Keep it on screen between fights"] = nil
L["On: the threat bar stays where you put it, empty, when nobody is fighting or you are alone. Off: it only "
  .. "appears while your group is fighting."] = nil

-- Bars.lua: the meter's views, as its first line names them.
L["Damage"] = nil
L["DPS"] = nil
L["Healing"] = nil
L["HPS"] = nil
L["Damage taken"] = nil
L["Absorbs"] = nil
L["Interrupts"] = nil
L["Dispels"] = nil
-- Beside the view: which tally, and (after " · ") the fight's length.
L["this fight"] = nil
L["last fight"] = nil
L["an earlier fight"] = nil
L["overall"] = nil
-- The hint on the first line.
L["Click: choose what to show. Right-click: this fight or overall. Drag to move."] = nil
-- The pick-list a click opens: its two headings, the two standing tallies, and a past fight the game
-- gave no name for. %d: the game's number for that fight.
L["Show"] = nil
L["From"] = nil
L["This fight (or the last one)"] = nil
L["Overall"] = nil
L["Fight %d"] = nil
-- A row's detail, shown while the mouse is over it: a spell the game couldn't name, the lines under the
-- spells, and the row's share of the whole tally. %s: a percentage to two decimals ("32.10").
L["A spell"] = nil
L["The game hides who this is during a fight."] = nil
L["Nothing counted for this row."] = nil
L["%s%% of everyone's"] = nil
-- Announcing a window's rows in chat, from the pick-list: the heading and the channels.
L["Announce to"] = nil
L["Party"] = nil
L["Raid"] = nil
L["Guild"] = nil
L["Say"] = nil
-- The first line said in chat. %s: the view ("DPS"); %s: which fight and its length ("last fight · 1:05").
L["Meter by Ryna: %s, %s"] = nil
-- Told to the player alone when an announcement wasn't made.
L["There is nothing to announce yet."] = nil
L["The game hides the numbers during a fight: announce when it is over."] = nil
L["The game wouldn't send that here."] = nil
-- The pick-list's last rows: a second (third, fourth) meter window, and closing one.
L["Open another window"] = nil
L["Close this window"] = nil
-- Locking a window to another on screen, so they sit together and drag as one, and freeing it. %s: the
-- other window by what it shows ("DPS", "Healing (2)", "Threat").
L["Lock this window"] = nil
L["Under %s"] = nil
L["Beside %s"] = nil
L["Unlock from %s"] = nil
-- Under the rows when there is nothing to show.
L["The game's meter isn't available here."] = nil
L["Nothing yet."] = nil

-- ThreatBar.lua: the bar on screen during a fight.
-- A row's right side for whoever the enemy is attacking, and (numbers hidden) for someone near pulling it.
L["has it"] = nil
L["close"] = nil
-- Beside the enemy's name: who it is on. %s: a group member's name.
L["on %s"] = nil
-- Stand-ins for a name the game didn't give.
L["An enemy"] = nil
L["Someone"] = nil
-- Under the rows, where the game won't give threat as numbers (a raid may not).
L["The game hides the numbers here."] = nil
-- Under the rows: the player's highest threat on another enemy. %s: that enemy; %d: percent.
L["Your highest: %s, %d%%"] = nil
L["Your highest elsewhere: %d%%"] = nil
-- The hint on the bar's first line, and its list when there is no meter window to lock to.
L["Click: lock this to another window. Drag to move."] = nil
L["Open the meter to lock this to it."] = nil
-- The bar between fights, when it is set to stay: its name, and the line under it.
L["Threat"] = nil
L["Nobody is fighting."] = nil
-- The example the bar shows for /ryna meter threat.
L["Example enemy"] = nil
L["An example. Drag the bar where you want it."] = nil
L["The tank"] = nil
L["A damage dealer"] = nil
L["You"] = nil
