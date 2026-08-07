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

The dialogue is restricted by CFTO's travel-dialogue and Route 1 factions plus
an exact seven-actor form list. This is important because CFTO also places the
quest-special Enthralled Ferryman in Route 1; he must not receive the ordinary
north-coast picker.

Every public provider shows the other six public ports on the Skyrim
parchment. The service revalidates the speaker, destination, current
`KmodFerryCost`, and player gold before charging exactly once and executing the
same fade plus `Game.FastTravel` pattern already proven on Lake Honrich, Lake
Ilinalta, and Solstheim.

The beta uses the same minimal presentation as Lake Ilinalta: anchors for
available ports without dynamic route strokes. The current and focused boat
icons provide selection context. The
authored Sea of Ghosts water graph and charcoal artwork remain as dormant,
reproducible sources for a post-release visual pass, but are not activated.

Frostflow Lighthouse remains destination-only. Icewater Jetty and the
Enthralled Ferryman are part of the Castle Volkihar quest-special flow.
Windstad Manor is ownership and construction gated. They are intentionally
deferred rather than flattened into this public network.

The module references the installed `battlemap01.dds`; the shared picker ships
no dependency artwork, route overlay, or audio. The minimal beta presentation
is offline-proven and awaits a live regression pass.
Candidate package SHA-256:
`830432532BE67A3BBE167D4A4A42ED4DCAD45E68DBF284959CEB1F2662C877E3`.
