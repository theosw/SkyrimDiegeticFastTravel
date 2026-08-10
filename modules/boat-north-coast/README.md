# Northern coast public ferry network

This isolated candidate adapts the gameplay-proven parchment ferry contract to
the seven ordinary public providers in CFTO's Route 1 faction:

- Harlaug at Dawnstar;
- Jolf at Solitude;
- Gort at Windhelm;
- Radding at Morthal;
- Perius at Solitude Lighthouse;
- Jollsen at Winterhold; and
- Rolf at Dragon Bridge.

The dialogue is restricted by CFTO's travel-dialogue faction plus an exact
nine-actor whitelist: seven public providers, private Windstad, and the
quest-special Enthralled Ferryman at Icewater Jetty.

Every available provider shows the other available ports plus the one-way
Frostflow Lighthouse destination on the Skyrim parchment. The service
revalidates the speaker, destination, current
`KmodFerryCost`, and player gold before charging exactly once and executing the
same fade plus `Game.FastTravel` pattern already proven on Lake Honrich, Lake
Ilinalta, and Solstheim.

The beta uses the same minimal presentation as Lake Ilinalta: anchors for
available ports without dynamic route strokes. The current and focused boat
icons provide selection context. The
authored Sea of Ghosts water graph and charcoal artwork remain as dormant,
reproducible sources for a post-release visual pass, but are not activated.

Frostflow Lighthouse is deliberately destination-only: every available
provider can reach it, but it has no service actor and can never become a return
source. Windstad joins only while CFTO's placed service ref is enabled.
Icewater/Volkihar joins when `KmodFerryVolkihar >= 1`, retains CFTO's 100-gold
outbound fare, and remains free when leaving from its Enthralled Ferryman.

The module references the installed `battlemap01.dds`; the shared picker ships
no dependency artwork, route overlay, or audio. The minimal beta presentation
is offline-proven and awaits a live regression pass. The prior package hash is
retired until the destination-only candidate is repackaged.
