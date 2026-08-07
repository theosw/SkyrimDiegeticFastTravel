Diegetic Travel - Lake Honrich Boats (offline candidate)

This module adds a physical parchment route picker to CFTO's public Lake
Honrich ferry lane:

    Riften <-> Heartwood Mill <-> Ivarstead

Requirements:

- Carriage and Ferry Travel Overhaul / the installed CFTO.esp
- Diegetic Travel's provider-neutral parchment picker runtime with the
  RequestDialogueClose native contract
- The external parchment artwork dependency used by that picker

Load this plugin after CFTO.esp. It neither requires nor masters Better
Carriage Destinations. The original CFTO destination dialogue remains as a
fallback.

The dialogue response finishes before the module asks the parchment runtime to
close Skyrim's Dialogue Menu and waits for confirmed closure. It does not fake
an Escape keypress.

Honeyside is intentionally not included in this first slice because CFTO gates
that private stop behind ownership and ferryman state. No artwork or audio is
bundled in this package.
