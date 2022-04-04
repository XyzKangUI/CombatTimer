# CombatTimer - TBCC (2.5.x)
W.I.P.

Displays a timer bar showing how long it will be till a player exits PvP combat. This is primarily aimed at stealth classes and for heal drinking.

Configurable via Interface->Addons->CombatTimer or /combattimer menu

# Notes:

- This addon works best with energy (e.g. rogue) and mana using classes. Every time you enter combat the timer will start. This initial timer will not be the most accurate, because it has to sync first through spending mana/energy. The reason behind this is that ticks stop when you are at max energy, which means that ticks cannot be accurately tracked until a first tick happends.
- The addon does not support Rage using classes (i.e. warrior, bear form druid)
- If you have frequently used abilities that are causing problems, then add your spell(s) to the whitelist in the CombatTimer_Quirks.lua file. Also do not hestitate to open a ticket under "issues".

# Inaccuracies:
- Frost trap effect keeps you combat while you stand on top of it. This will cause the timer to loop infinitely and become innacurate. 
- Mass Dispel will always reset the ooc timer, eventhough the reset will not always be warranted. This is caused by the limitation of combat log events not showing if someone got caught in the mass dispel.

# Credits:

* Author: STFX - https://www.wowinterface.com/downloads/info8493-CombatTimer.html
* Testing: Macumba
* Help with API, timer improvement and debugger: Knall
