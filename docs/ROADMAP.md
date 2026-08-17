# Roadmap

## Beta release gates

- [x] Replace the experimental graph runtime with a flat CFTO destination manifest.
- [x] Use the restart-time pricing INI for deterministic distance-based carriage
  fares and approximate hours; retain CFTO's live globals for ferries.
- [x] Remove route-derived hours, hazards, and variable rates from beta UI/runtime.
- [x] Author the ESP generator for dialogue overrides, cost/availability globals,
  quests, and VMAD properties.
- [x] Compile Papyrus against Skyrim, SKSE, and CFTO sources; JContainers is no
  longer a runtime or build dependency.
- [x] Smoke-test the unattended xEdit generator and inspect the resulting ESP.
- [x] Verify the generated TES4 master order and expected generated-record counts.
- [ ] Verify the nine CFTO driver actor identities in the target load order.
- [ ] Reverify configured carriage payment, estimate calibration, and free-ride
  behavior in game.
- [ ] Verify the complete Apparition lifecycle in one monitored run: normal
  travel, toggle on with zero elapsed time, toggle off through the power, and
  restored normal elapsed time. Keep raw `removespell` as a diagnostic only.
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
  - The formal Caro/FWMF wizard map, including Dawnstar/Morthal placement and
    destination-preserving mouse hover, passed its 32:9 gameplay test.
- [x] Prove a physical parchment selection surface with route highlighting,
  HUD suppression, mouse input, cancel, and external-art fallback.
- [x] Add a provider-neutral route-segment graph with connectivity validation
  and shortest-path hover highlighting; convert Lake Honrich and the northern
  coast to water-following networks without changing wizard spokes.
- [ ] Revisit graph fares, hazards, variable rates, and predicted hours only
  after release, starting from observed engine time passage.
- [ ] Live-test the route-network visual candidate: Lake Honrich ring placement,
  northern-coast sea/channel placement, idle gold network, red hover path, and
  selection/cancel regression.
- [x] Prove Mirabelle voice, subtitle, and lip sync before picker handoff.
- [ ] Live-test the generalized presentation-then-picker handoff.
- [x] Add explicit native D-pad/left-stick focus, A-confirm, and B-cancel
  without replacing LoreRim's controller object or changing mouse activation.
- [ ] Live-test controller focus/confirm/cancel with the intended No Delete
  Controller compatibility stack enabled.
- [x] Decode CFTO's four ferryman route factions and destination records.
- [x] Build and structurally audit a provider-neutral Lake Honrich boat slice
  for Riften, Heartwood Mill, and Ivarstead while preserving CFTO execution.
- [ ] Live-test the Lake Honrich slice: all three providers, alignment, cancel,
  denial, exact payment, both Heartwood directions, and follower/horse handoff.
  - First pass proved all providers, alignment, cancel, live 30-gold payment,
    0/10-gold denials, and Heartwood -> Ivarstead -> Riften -> Heartwood.
  - Follow-up proved the explicit Dialogue Menu close handoff at all three
    providers plus Riften -> Ivarstead -> Heartwood -> Riften. All six directed
    public-lane trips are exercised; Heartwood follower/horse arrival remains.
- [x] Add Honeyside as a private provider gated by CFTO's live placed-ferryman
  enable state.
- [x] Build and structurally audit the public Lake Ilinalta Route 3 slice for
  Brittleshin Pass, Half-Moon Mill, and Guardian Stones.
- [x] Live-test Lake Ilinalta: all three providers, no-Escape handoff, map
  alignment, cancel, 0/10-gold denial, exact 30-gold payment, and one full
  three-stop cycle.
  - Bundle Brittleshin horse and Guardian Stones follower/horse placement with
    the existing Heartwood companion regression.
- [x] Add Ilinata's Deep as a destination-only 50-gold regional trip with its
  dedicated follower/horse markers and no return provider.
- [x] Add Lakeview Manor as a private provider gated by CFTO's live
  placed-ferryman enable state, with dedicated companion markers.
- [x] Build and independently audit the public Solstheim Route 4 triangle for
  Raven Rock, Tel Mithryn, and Skaal Village. The functional live pass exposed
  the narrow physical-map art. A follow-up exposed stale saved auto properties;
  a 1.5:1 live pass proved too wide. The current candidate hard-codes a square
  1:1 physical-map presentation so visual revisions apply to existing saves.
- [ ] Live-test Solstheim: all three providers, map crop/alignment, cancel,
  0/low-gold denial, exact 50-gold payment, one full three-stop cycle, and the
  Northshore/Bujold destination-only trips with no return provider.
- [x] Build and independently audit the seven ordinary public north-coast
  Route 1 providers as one network: Dawnstar, Solitude, Windhelm, Morthal,
  Solitude Lighthouse, Winterhold, and Dragon Bridge. The exact provider
  whitelist also admits gated Windstad and Icewater without admitting unrelated
  actors. Frostflow is an explicit destination-only stop; private Windstad
  follows its placed-ref gate and Icewater/Volkihar follows its live state,
  extra outbound fare, and free-return contract.
- [ ] Live-test the north-coast module in one session: seven public providers,
  gated Windstad and Icewater providers, map alignment, cancel, denial, normal
  and Volkihar fares, one eastbound trip, one westbound trip, and Frostflow with
  no return provider.
- [x] Soft-detect Wizarding Traversal's Apparition holder effect and use a
  zero-time `MoveTo` arrival for direct DNT travel without adding a master or
  mutating the source mod's fast-travel-speed global.
- [x] Expand and independently audit the carriage parchment adapter to all 27
  destinations with a native CFTO handoff. The beta uses an immutable native
  pricing snapshot, revalidates at purchase, and deliberately draws no
  synthetic routes.
- [ ] Live-test the carriage parchment adapter: paid and free driver roots,
  all expected destinations from one origin, capital/minor marker readability,
  full executable-endpoint visibility, first-open latency, fare/time labels, cancel,
  denial, exact payment, and one completed CFTO ride.
- [ ] Define optional compatibility adapters for intervention and Mark/Recall
  mods instead of immediately cloning their spell suites.
- [ ] Prototype the propylon-style ancient-site loop after discovery, follower,
  and quest-safe arrival policies are specified.
- [ ] Add optional favor/relationship gates only after the travel infrastructure
  is otherwise release-ready.

See `docs/PILLAR_RESEARCH.md` for the rationale and provider order.
