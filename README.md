# CombatTimer
W.I.P.

Displays a timer bar showing how long it will be till a player exits PvP combat. This is primarily aimed at stealth classes and for heal drinking. Since it is useless in PvE, by default it will only be enabled in Arenas and Battlegrounds.

Configure via Interface->Addons->CombatTimer.

# Note:

- Works best with rogues, because it syncs with energy ticks. Mana sync is still W.I.P.
- Timer will reset when it drops below 1sec and there is still time remaining till energy tick.
- If you have frequently used abilities that are causing problems, I suggest you look at the CombatTimer_Quirks.lua file and add your spell to the whitelist.
- Works best with max rank spells at level 70
- Frost trap effect will keep you permanent combat while standing on top of it. The timer will just refresh the timer until energy tick and not full ooc duration.

# Credits:

* Author: STFX - https://www.wowinterface.com/downloads/info8493-CombatTimer.html
* Testing scenario's: Macumba
* Help with API & Debug code: Knall
