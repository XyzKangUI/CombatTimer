# CombatTimer
W.I.P.

Displays a timer bar showing how long it will be till a player exits PvP combat. This is primarily aimed at stealth classes and for heal drinking. Since it is useless in PvE, by default it will only be enabled in Arenas and Battlegrounds.

Configure via Interface->Addons->CombatTimer.

# Notes:

- Works best for Rogue class due to accurate energy ticks. It is not intended for rage classes.
- The timer will re-sync - according to the remaining time of the next energy tick - when it has 1 second remaining.
- If you have frequently used abilities that are causing problems, I suggest you look at the CombatTimer_Quirks.lua file and add your spell to the whitelist.
- Works best with max rank spells at level 70.
- Frost trap effect will keep you in combat while standing on top of it. The timer will just refresh the timer based on the energy tick remaining time and not the full duration.

# Credits:

* Author: STFX - https://www.wowinterface.com/downloads/info8493-CombatTimer.html
* Testing scenario's: Macumba
* Help with API & Debug code: Knall
