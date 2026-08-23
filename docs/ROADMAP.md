# Roadmap

This file tracks the current consolidated product. Historical graph, overlay,
BCD wizard-adapter, and split-plugin experiments are preserved in
`docs/EVIDENCE_LEDGER.md` and Git history rather than listed as future work.

## Complete for the public beta candidate

- [x] One ESL-flagged `DiegeticTravel.esp`, one native SKSE plugin, one flat
  28-stop carriage catalogue, and an explicit 22-script/22-texture package
  inventory.
- [x] Physical parchment selection with mouse and controller input, stable-ID
  selection, cancellation, HUD restoration, and one-way/return indicators.
- [x] Native carriage quote and marker resolution with final Papyrus-side
  availability, payment, and travel revalidation.
- [x] Public-balanced carriage defaults: 50–400 gold from the nine physical
  drivers; wizard guides remain 250 gold; ferries retain CFTO's live
  30/50/100 globals and free Icewater return.
- [x] College hub and seven capital spokes, including corrected Morthal arrival
  and audited voice/subtitle fallbacks.
- [x] Lake Honrich, Lake Ilinalta, north-coast, and Solstheim ferry networks,
  including private and one-way destination gates.
- [x] Wait Carriage in Inns and soft-detected Apparition Travel integration.
- [x] Optional Baan Malur network and LoreRim BCD coexistence packages with the
  same version/timestamp convention as the main archive.
- [x] Reproducible native/Papyrus/xEdit builds, exact package audits, dependency
  locking, and MO2 Quick Install metadata.

## Final live checks before publishing this beta

- [x] Install the new timestamped three-archive set with the full LoreRim
  BCD/CFTO/WCI chain still enabled and verify the intended plugin order.
- [ ] Confirm the new carriage envelope in game: representative 150-, 200-,
  and 400-gold labels, exact one-time payment, insufficient-funds denial, and a
  CFTO-designated free driver.
- [x] Open the sheet from Gunjar, Engar, and Markus; verify Lakeview, Windstad,
  and Heljarchen source labels, free destination labels, and one completed trip
  with no gold deduction or unresolved-origin log.
- [ ] Recheck a physical carriage, a WCI summoned carriage, Thalmor Embassy,
  and one conditional Hearthfire or Helgen endpoint after the pricing change.
- [ ] Verify that the LoreRim BCD coexistence file hides only the three competing
  selectors and that `DNT_ShowBcdTravelDialogue=1` restores them.
- [ ] Run one controller selection/cancel trip with the release controller stack.
- [ ] Run one ordinary timed trip and one Apparition trip, then disable
  Apparition normally and confirm timed travel resumes.
- [ ] Check `DNTParchmentPicker.log`, the Papyrus log, and crash output after a
  clean shutdown; no fatal, error, unresolved-origin, or duplicate-payment
  messages are acceptable.
- [ ] Preserve the previous proven archive/tag until this replacement passes;
  only then promote the new commit and publish its SHA-256 manifest.

## Good beta follow-ups

- [ ] Finish the companion-placement matrix at Heartwood, Brittleshin,
  Guardian Stones, and the private/destination-only ferry stops.
- [ ] Exercise every physical carriage origin and the complete conditional
  endpoint matrix on a release-clean save.
- [ ] Curate optional LoreRim-added settlements such as Granite Hill without
  claiming BCD's unrestricted map-marker universe as native CFTO parity.
- [ ] Define optional intervention and Mark/Recall compatibility adapters.
- [ ] Prototype a propylon-style ancient-site loop after discovery, follower,
  and quest-safe arrival policies are specified.
- [ ] Consider relationship gates only after public beta feedback confirms the
  travel infrastructure is stable.

See `docs/PILLAR_RESEARCH.md` for the pillar rationale and provider order.
