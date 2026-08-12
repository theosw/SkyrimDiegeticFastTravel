# Lake Honrich boat vertical slice

This workspace-only candidate adapts the provider-neutral parchment picker to
CFTO's smallest public ferry lane:

```text
Riften <-> Heartwood Mill <-> Ivarstead
```

Honeyside is a private fourth provider. It is visible only while CFTO's placed
Honeyside ferryman is enabled, preserving CFTO's ownership/porch/service state
without cloning its prerequisite quests.

## Boundaries

- CFTO remains the authority for ferrymen, price globals, destination markers,
  and the existing dialogue fallback.
- The new dialogue option uses an exact whitelist of CFTO's three public
  ferrymen plus the private Honeyside ferryman.
- `DNT_BoatParchmentPicker` presents every other currently available stop on
  that waterway; Honeyside is omitted whenever CFTO disables its service ref.
- The beta uses the same minimal presentation as Lake Ilinalta: anchors for
  available docks without dynamic route strokes. The current and focused boat
  icons provide selection context. The
  ten-segment lake ring and its charcoal artwork remain as dormant authoring
  sources for a post-release visual pass, but are not activated or shipped.
- `DNT_BoatTravelService` revalidates the speaker, destination, and current
  `KmodFerryCostLocal`, charges once, then mirrors the installed CFTO ferry
  fragment: fade, over-encumbrance allowance, `Game.FastTravel`, and fade back.
- The Heartwood destination also mirrors CFTO's dedicated follower and horse
  marker handoff. Riften and Ivarstead retain CFTO's normal fast-travel party
  handling.
- Cancel is inert. The ordinary CFTO destination dialogue remains available as
  a fallback.
- The OnEnd provider requests a normal native `Dialogue Menu` close, confirms
  that the menu is gone, and only then opens the parchment. Close-request,
  already-closed, confirmation-tick, and timeout paths are logged.

The candidate requires CFTO plus the existing Diegetic Travel parchment native
runtime. It does not require Better Carriage Destinations and does not ship the
external RUSTIC MAPS texture or the deferred route artwork.

## Evidence

The lane, actors, fare global, and markers were decoded during the discovery
pass and captured in this module's source/configuration. The one-off xEdit
inventory remains recoverable from Git history. Bethesda's local Papyrus
assembler was also used against copied PEX files to verify the exact six Lake
Honrich travel fragments without altering LoreRim.

An independent voice audit resolves Heirmir, Thalldar, and Haennr to
`MaleEvenToned` and verifies the exact Dawnguard shared-response FUZ in the
vanilla archive for `DialogueFerryWhereDoYouWantToGo` (`0201683A`, “Where are
you headed?”). The module therefore relies on a real voice/lip asset rather
than a guessed SharedInfo compatibility path.

The first monitored gameplay pass resolved all three ferrymen, showed the
correct two-stop map at each provider, completed Heartwood -> Ivarstead,
Ivarstead -> Riften, and Riften -> Heartwood at CFTO's live 30-gold fare, and
proved cancellation plus denials at 0 and 10 gold. No DNT error or crash was
recorded. Heartwood and Ivarstead required the player to press Escape before
the map became visible, while Riften closed dialogue normally. That evidence
isolated the defect to dialogue teardown rather than map rendering.

The explicit native close-and-confirm handoff is gameplay-proven at Heartwood,
Ivarstead, and Riften. Every provider emitted a native close request followed
by `BOAT_DIALOGUE_HANDOFF_COMPLETE ... waitTicks=0`, and each parchment opened
without manual Escape. The regression completed Riften -> Ivarstead,
Ivarstead -> Heartwood, and Heartwood -> Riften at 30 gold. Combined with the
first pass, all six directed lane trips are proven. Heartwood follower/horse
handoff remains the only Lake Honrich-specific live gate.

The beta's icon-only presentation is compiled and offline-validated; the
charcoal-ring experiment remains only as reproducible authoring data. Candidate
package SHA-256:
`5819E92CA88BB7944133EA0D5F5B1B706A0AB09B3A7713C2C744AFB866A27087`.
