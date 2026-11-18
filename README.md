# Meter by Ryna

A mod of [Ryna](https://github.com/Ryna-Mods/ryna) for World of Warcraft: Forever. What is happening
in a fight, live, read from the game itself:

- **A meter** of the game's own tallies (damage, DPS, healing, HPS, damage taken, absorbs,
  interrupts, dispels), for this fight or overall. Up to four windows, each with its own view.
- **A threat bar** while your group is fighting, showing how close each member is to pulling the
  enemy you have targeted.

It needs nothing from the Ryna app, keeps nothing but where you put its frames, and sends nothing
anywhere. It says nothing in chat unless you pick Announce from a meter window's list. `/ryna meter`
turns it on and off.

## Installing

Meter needs **Ryna Core** (the folder `Ryna_Core`). Get both one of these ways:

- **With the Ryna app** ([download](https://github.com/MaddisonM79/ryna_agent/releases/latest)),
  which installs them and keeps them up to date.
- **The bundle**: every Ryna addon in one zip, from
  [Ryna-Mods/ryna](https://github.com/Ryna-Mods/ryna/releases/latest).
- **By hand**: this repository's releases hold `Ryna_Meter-<version>.zip`; unzip it into
  `Interface/AddOns` beside `Ryna_Core`.

## Working on it

`Ryna_Meter/` is the addon. Its tests (`test/`) run it against a fake client and the real core
addon, the oldest one Meter claims to work with ([`core.json`](core.json)), which
`node scripts/core.mjs` fetches into `.core/`.

```bash
scripts/check.sh
```

That is everything CI runs: luacheck, the strings (`tools/strings.mjs`: every string the code uses
is in `Locales/enUS.lua` and in each locale's template) and the tests. It needs Lua (5.1 is what the
game runs), [luacheck](https://github.com/lunarmodules/luacheck) and Node.

The core API level Meter needs is `## X-Ryna-API` in [`Ryna_Meter.toc`](Ryna_Meter/Ryna_Meter.toc);
its version is `## Version` there, and nowhere else. A release is a signed tag `vX.Y.Z` that matches
it; the bundle then names that release in its `bundle.json`
([how](https://github.com/Ryna-Mods/ryna/blob/main/RELEASING.md)).

## Where it came from

Meter was written in [MaddisonM79/ryna_agent](https://github.com/MaddisonM79/ryna_agent)
(`mods/wow/meter`), and its history up to 0.5.0 is there. Bugs and requests go to
[ryna_agent's issues](https://github.com/MaddisonM79/ryna_agent/issues).

## Licence

MIT.
