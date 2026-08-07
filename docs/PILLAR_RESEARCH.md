# Travel-pillar research and scope

The project should integrate Skyrim's existing travel actors and specialist
mods around one provider-neutral service rather than attempt to replace every
implementation. The useful split is:

1. **Provider** decides who offers travel, its presentation, and which stable
   destination IDs are offered.
2. **Picker** displays those destinations and returns only a selection.
3. **Service** re-evaluates availability and fare, charges once, advances time
   when appropriate, and invokes movement.
4. **Executor** performs the provider-specific movement: direct teleport,
   CFTO carriage/ferry handoff, boat journey, spell, or wayshrine.

This prevents a polished selector from bypassing route, price, or safety rules.

## Five-pillar fit

| Pillar | Existing work to learn from | Diegetic Travel focus |
| --- | --- | --- |
| Carriages | CFTO already owns drivers and ride execution. [Better Carriage Destinations](https://github.com/shazdeh/Better-Carriage-Destinations/tree/136dc7b3ad9754877c485fd5cea29550af108888) demonstrates a filtered map selector. | Keep CFTO execution; own reachable-route evaluation, graph fare/time, and final revalidation. Offer parchment and optional BCD selectors over the same service. |
| Boats | CFTO supplies four distinct waterway factions, ferrymen, fares, markers, voiced dialogue, and travel fragments. BCD demonstrates a map surface but exposes a broader marker whitelist than CFTO's sparse stop graph. | Preserve CFTO's real per-waterway topology and execution. Lake Honrich proves the contract; Lake Ilinalta is the second isolated public triangle. Expand lane by lane without flattening private or destination-only stops. |
| Wizard guides | Court Wizard Teleport Services proves dialogue-to-teleport, but duplicates one payment/refund fragment and one hard-coded movement fragment per destination. | The College-centred seven-spoke star is the first complete pillar. Reuse one service, a physical parchment picker, provider-specific voice/subtitle presentation, and stable destination IDs. |
| Personal magic | [Translocate](https://www.nexusmods.com/skyrimspecialedition/mods/11467), [Alteration Mark and Recall](https://www.nexusmods.com/skyrimspecialedition/mods/138974), [Divine Intervention](https://www.nexusmods.com/skyrimspecialedition/mods/10235), and [Mysticism - The Lost Art](https://www.nexusmods.com/skyrimspecialedition/mods/14285) already cover much of Mark/Recall and intervention magic. | Do not clone a spell suite during infrastructure work. Define optional adapters and a common retreat/arrival policy, then decide later whether to ship spells or integrate a chosen implementation. |
| Ancient network | [SWIFT](https://www.nexusmods.com/skyrimspecialedition/mods/17905) and [Unmoored](https://www.nexusmods.com/skyrimspecialedition/mods/134945) demonstrate discovered/unlocked nodes, visible activation state, optional fees, follower handling, and low-background-script designs. | Build this last as an unlockable loop or sparse graph. The hard work is world placement, discovery state, follower policy, and quest-safe arrivals—not the picker. |

## Decisions

- Retain the College as the wizard-network hub. Court wizards connect their
  capital to the College; College faculty can serve all unlocked capital
  spokes. Direct capital-to-capital travel is deliberately not the default.
- Keep the parchment picker provider-neutral. Wizard, carriage, boat, and
  ancient-network providers may use different artwork and coordinates without
  native-code changes.
- Treat BCD as an optional selection surface, never as the travel authority.
  Its injection waits for map markers to exist and intercepts marker clicks;
  it does not know our graph fares or live route hazards.
- Revalidate after selection. Time can pass between opening a picker and the
  click, and another mod may change money, quest state, or actor availability.
- Use stable lowercase destination IDs across dialogue, parchment, BCD, logs,
  and future save data. Display labels are presentation only.
- Keep trust, disposition, favor, and discovery quests out of the current
  infrastructure milestone. They should become conditions on an already
  reliable network, not prerequisites for proving it.

## Provider expansion order

1. Finish and regress the seven-spoke wizard network.
2. Prove the provider contract on the small Lake Honrich boat lane.
3. Prove the structurally similar Lake Ilinalta public triangle, then tackle
   Solstheim and the more complex north coast.
4. Adapt the same picker/service lessons to the carriage graph without
   replacing CFTO execution.
5. Define compatibility adapters for intervention and Mark/Recall magic.
6. Prototype an unlockable ancient-site loop after arrival and follower
   policies are explicit.

Each new provider must pass the same contract tests: cancel is inert, denied
travel never charges, successful travel charges exactly once, selection is
revalidated, arrival is safe, and the provider's picker can fail back to a
dialogue path.
