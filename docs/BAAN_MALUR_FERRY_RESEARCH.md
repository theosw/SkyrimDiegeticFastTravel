# Journey to Baan Malur ferry adapter research

## Recommendation

Treat Journey to Baan Malur's sea travel as a separate commercial network.
Do not merge it into CFTO's rough local-ferryman Solstheim triangle. Captain
Remyris is a merchant-captain serving longer interregional routes, so the clean
`Solstheim and Baan Malur Paper Map for FWMF` chart is a better diegetic fit
than the Dragonborn cloth chart used by Maslyn, Bildul, and Gauldis.

The adapter should require the external chart but ship no copy of it. The
installed chart mod is texture/mesh-only, so it does not need to become an ESP
master.

## Installed source evidence

The provider belongs to `Journey to Baan Malur.esp`:

- `RavenRockSailorCaptain` (`0710F3BE` in the isolated inspection) is Captain
  Remyris. The live runtime FormID prefix changes with load order.
- The travel root is `SOMRFerrySystemMain` (`0733708F`), a Start Game Enabled
  quest whose DNAM explicitly enables `Allow repeated stages`.
- `SOMRFerrySystemGreeting` asks `I would like to hire your ship.` and responds
  `Where are you headed?` for actors in `SOMRSailorCaptainFaction`.
- The root links nine destinations at 30 septims: Baan Malur, Cormaris, Raven
  Rock, Pryai, Llethrin Fel, Sunmul, Seyda Neen, Vivec, and Old Silgrad.
- From Raven Rock, Baan Malur and Cormaris have only the shared captain-faction
  gate plus a `GetIsID != destination captain` gate. The other destinations
  additionally depend on hidden check actors joining destination-unlock
  factions. This is why Remyris currently offers only the two routes observed
  in game.
- The Baan Malur, Cormaris, and Raven Rock INFOs are Goodbye/OnEnd responses.
  Their fragments set a stage on the owning ferry quest.
- Bethesda PapyrusAssembler disassembly proved the exact public stage map:
  Baan Malur INFO `06337095` sets stage `1`, Cormaris INFO `06337097`
  sets stage `2`, and Raven Rock INFO `06337099` sets stage `3`.
- The owning quest fragment maps those stages to
  `SOMRBoatTravelBaanMalurScript.ExecuteBoatTravel()`,
  `SOMRBoatTravelCormarisScript.ExecuteBoatTravel()`, and
  `SOMRBoatTravelRavenRockScript.ExecuteBoatTravel()` respectively.
- The ferry quest owns destination scripts whose `ExecuteBoatTravel` functions
  use the original arrival markers. Extracted PEX evidence shows the scripts
  resolve Skyrim's gold form, check `GetItemCount`, call `RemoveItem`, wait,
  then `MoveTo`, with their own insufficient-funds notification.

The original repeatable xEdit inspection was a discovery tool and was removed
after its findings were captured here. The provider implementation is now
maintained as a separately built optional ESP-FE; it is not part of the
consolidated release and does not add a master to `DiegeticTravel.esp`.

## Chart contract

Installed dependency:

`Solstheim and Baan Malur Paper Map for FWMF\textures\terrain\dlc2solstheimworld\solstheim.dds`

Measured properties:

- DDS dimensions: `8192 x 8192`;
- nontransparent bounds: `(0, 1298)` through `(8192, 6637)`;
- renderer UV crop: `(0.0, 0.158447)` through `(1.0, 0.810181)`;
- cropped artwork aspect ratio: approximately `1.534:1`.

The artwork shows Solstheim and the northwest Morrowind coast together and is
therefore substantially clearer for Remyris's Raven Rock -> Baan Malur /
Cormaris service than for the local CFTO triangle.

Calibrated normalized positions in that cropped artwork space:

- Raven Rock: `(0.572274, 0.405605)`;
- Baan Malur: `(0.510018, 0.640516)`;
- Cormaris: `(0.157237, 0.323277)`.

The calibrator keeps these positions separate from the local Solstheim ferry
coordinates because the two networks use different maps and UV transforms.

## Optional public-slice add-on

The maintained optional add-on implements this design:

1. adds the parchment option only to the three public captain bases;
2. hides Journey's original destination dialogue for those three providers by
   default, while preserving it for every unsupported Journey captain;
3. shares Journey's original `Where are you headed?` response record;
4. puts Raven Rock, Baan Malur, and Cormaris on the calibrated FWMF chart;
5. delegates selections to the proved original stages `1`, `2`, and `3`;
6. adds the verified stage-5 trip to Sunmul from all three public captains as
   one-way;
7. packages no chart, voice assets, native DLL, or copy of the main runtime.

The provider boundary is a static local form list checked directly by the
overridden INFO. `DNT_ShowBaanMalurNativeDialogue` defaults to `0`; setting it
to `1` restores the native prompt for diagnosis. This is a dialogue-condition
gate, not a Papyrus polling or initialization path.

`DiegeticTravelBoatBaanMalur.esp` requires Journey to Baan Malur and the main
Diegetic Fast Travel installation. Its chart remains a separately installed
texture dependency. Users without Journey to Baan Malur omit the optional
archive; the main release and all CFTO/wizard services remain unaffected.

The other gated ports remain a later slice and must mirror each original
hidden check-actor faction condition exactly.
