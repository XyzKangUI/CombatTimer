# CombatTimer - WOTLKC (3.4.x)
W.I.P.

Displays a timer bar showing how long it will be till a player exits PvP combat. This is primarily aimed at stealth classes and for heal drinking.

Configurable via Interface->Addons->CombatTimer or /combattimer menu

# Notes:

- The initial timer will not be the most accurate, because it has to sync first through spending mana/energy or leaving combat (rage/runic power).
- If you have frequently used abilities that are causing problems, then add your spell(s) to the whitelist in the CombatTimer_Quirks.lua file. Also do not hestitate to open a ticket under "issues".

# Inaccuracies:
- Frost trap effect keeps you combat while you stand on top of it. This will cause the timer to loop infinitely and become innacurate. 
- Mass Dispel will always reset the ooc timer, eventhough the reset will not always be warranted. This is caused by the limitation of combat log events not showing if someone got caught in the mass dispel.
- Unholy blight keeps you in combat for the entire duration. When the debuff falls off the combat timer starts ticking down.

# Credits:

* Author: STFX - https://www.wowinterface.com/downloads/info8493-CombatTimer.html
* Testing: Macumba
* Help with API, timer improvement and debugger: Knall
