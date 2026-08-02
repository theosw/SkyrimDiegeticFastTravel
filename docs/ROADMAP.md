# Roadmap

## Beta release gates

- [x] Provider-separated carriage compilation.
- [x] Up-to-three candidate paths with deterministic selection.
- [x] Live-state pricing and chokepoint refusal reference implementation.
- [x] Strict hazard sensor and CFTO endpoint validation.
- [x] Resolve and author live sensors for every routed dragon mound.
- [x] Author the ESP generator for dialogue overrides, globals, quests, and VMAD properties.
- [x] Compile Papyrus against Skyrim, SKSE, JContainers, and CFTO sources.
- [x] Smoke-test the unattended xEdit generator and inspect the resulting ESP.
- [x] Verify the generated TES4 master order and expected generated-record counts.
- [ ] Verify the nine CFTO driver actor identities in the target load order.
- [ ] Verify CFTO charge handoff and free-carriage faction behavior in game.
- [ ] Verify conditional endpoints (three Hearthfire manors and intact Helgen).
- [ ] Eyeball all low-confidence roads in game.
- [ ] Run the Valtheim reroute smoke test and save/load regression test.

## After beta

- [x] Establish the College-centred wizard-guide infrastructure and seven
  capital spokes without trust/quest gates.
- [x] Live-test the optional wizard-guide BCD adapter at 32:9, including map cancel,
  core fare denial, one selected trip, and the dialogue-list fallback.
- [x] Build and statically audit the provider-neutral SKSE parchment picker,
  including an external-art contract and 32:9-safe layout.
- [ ] Run the remaining parchment picker matrix: Dawnstar/Morthal alignment,
  the replacement Morthal carriage-marker arrival, controller selection/cancel,
  missing artwork, and dialogue fallback.
- [x] Prove a physical parchment selection surface with route highlighting,
  HUD suppression, mouse input, cancel, and external-art fallback.
- [x] Prove Mirabelle voice, subtitle, and lip sync before picker handoff.
- [ ] Live-test the generalized presentation-then-picker handoff.
- [ ] Add controller focus/confirm/cancel only with the intended No Delete
  Controller compatibility stack enabled.
- [ ] Adapt the parchment/BCD selection contract to CFTO carriages while
  retaining CFTO ride execution and live graph fare/time revalidation.
- [ ] Decode and author each CFTO ferryman's real lane graph, then implement a
  boat-provider adapter.
- [ ] Define optional compatibility adapters for intervention and Mark/Recall
  mods instead of immediately cloning their spell suites.
- [ ] Prototype the propylon-style ancient-site loop after discovery, follower,
  and quest-safe arrival policies are specified.
- [ ] Add optional favor/relationship gates only after the travel infrastructure
  is otherwise release-ready.

See `docs/PILLAR_RESEARCH.md` for the rationale and provider order.
