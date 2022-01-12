# CombatTimer
W.I.P.

Displays a timer bar showing how long it will be till a player exits PvP combat. This is primarily aimed at stealth classes and for heal drinking. Since it is useless in PvE, by default it will only be enabled in Arenas and Battlegrounds.

Configure via Interface->Addons->CombatTimer.

# Notes:

- Works best for Rogues and Mana classes. The timer will have to sync first, therefore spend some mana/energy to get an accurate timer. 
- The addon does not support 'RAGE' powertype classes. 
- If you have frequently used abilities that are causing problems, I suggest you look at the CombatTimer_Quirks.lua file and add your spell to the whitelist.
- Works best with max rank spells at level 70.
- Frost trap effect keeps you combat while you stand on top of it. Haven't tested what the addon does, probably doesn't function well in that scenario.

# Credits:

* Author: STFX - https://www.wowinterface.com/downloads/info8493-CombatTimer.html
* Testing scenario's: Macumba
* Help with API, Timer Improvement and debugger: Knall
