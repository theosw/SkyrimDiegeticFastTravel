DNT Parchment Picker - development spike

This payload contains no map artwork. The College provider references the loose
RUSTIC MAPS texture already included in LoreRim:

  Data/textures/dungeons/imperial/battlemap01.dds

It displays rows 0-3016 of that 4096-square texture (UV max 0.736328) at aspect
1.358090, excluding the opaque strip below the parchment edge. If the file is
absent, the picker shows a diagnostic fallback while keeping destination
selection available. The core parchment flow has passed its first gameplay
test. If the new dialogue prompt is missing on an existing save, save and
reload once with this adapter installed. The existing dialogue destination
menu remains an available fallback during development.

The current revision hides vanilla, TrueHUD, and common LoreRim widget movies
while the parchment is open, restores each movie's previous visibility and
root alpha on close, and uses an ASCII hyphen in the fare footer. City crests
use large invisible hitboxes with prominent gold idle rings and red active
rings. The College provider draws five gold routes from the Winterhold crest;
hovering or focusing a destination turns only its route and ring red without
selecting it. An asset-free monochrome pointer, drawn with Menu Framework
primitives to resemble LoreRim's active Norden cursor, replaces the earlier
yellow pointer while the picker is open. Its dark center is translucent so the
map remains visible beneath it. Opening the map starts with no active route;
mouse hover activates one immediately, while keyboard/controller focus becomes
visible only after keyboard/controller input. No cursor artwork is copied or
shipped.
