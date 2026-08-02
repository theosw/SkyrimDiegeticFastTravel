# Wizard fare-denial voice research

Date: 2026-07-31

## Question

Dialogue currently selects an affirmative response before the service performs
its authoritative fare check. With insufficient gold, the wizard can therefore
say `Yes.` or `Of course.` immediately before the top-left denial notification.

The research goal was to find semantically correct vanilla response donors that
are both genuine SharedInfo records and voiced for the actual wizard voice
types. An ordinary INFO is not accepted merely because xEdit permits it in
`DNAM`; earlier live tests disproved that architecture.

## Authoritative inventory

`tools\Inventory-WizardFareDenials.ps1` scans staged copies of Skyrim, Update,
Dawnguard, HearthFires, and Dragonborn. It reports genuine Misc/SharedInfo
records separately from ordinary quest dialogue. No deployed file is read or
changed.

`tools\Inventory-WizardFareDenialVoiceCoverage.ps1` scans the filename table in
`Skyrim - Voices_en0.bsa`. Voice filenames use the plugin-local eight-digit
object ID, not xEdit's staged load-order prefix.

The relevant roster contains 13 distinct voice types: the ten ordinary faculty
types, Mirabelle's unique type, Farengar's accented type, and Wylandriah's
even-toned type. Sybille, Wuunferth, and Calcelmo overlap faculty types.

## Safe donors

| Plugin / INFO | Response | Useful target coverage |
|---|---|---|
| `Skyrim.esm` `000C6E2D` `PlayerHouseDecorateBroke` | `I'm sorry, but you don't seem to have enough gold to pay for that.` | 5/13: `MaleEvenTonedAccented`, `FemaleEvenToned`, `MaleCondescending`, `MaleOldKindly`, `MaleCoward` |
| `HearthFires.esm` `0000B0B2` `BYOHHouseStewardFurnishingsNoGold` | `I'm sorry, but you can't afford that right now.` | 4/13: `FemaleEvenToned`, `FemaleSultry`, `MaleEvenToned`, `MaleOrc` |
| `HearthFires.esm` `000094FD` `BYOHHouseStewardShortOfGold` | `Ah. Unfortunately, I'm afraid you're a bit short of funds at the moment.` | The same 4/13 as `0000B0B2` |
| `Dawnguard.esm` `0001683F` `DialogueFerryComeBackWithMoney` | `You think I do this for my health? Come back when you've got the coin.` | 1/13: `MaleEvenToned`; valid but unnecessarily hostile for a generic wizard service |

The best two donors cover eight distinct target voice types together. Five
remain without a suitable voiced fare refusal: `MaleOldGrumpy`,
`MaleSlyCynical`, `FemaleElfHaughty`, `FemaleShrill`, and
`FemaleUniqueMirabelleErvine`.

The inventory also found many excellent-sounding ordinary lines, including
hireling and stable refusals. They are not SharedInfo and are rejected as
donors. Context-specific SharedInfos such as `Not now. I'm too upset to talk.`
were also rejected on semantic grounds.

### Later Falion-specific finding

A deeper Skyrim-only pass subsequently found generic SharedInfo
`CantBeHelped` (`DIAL 0001F319`, `INFO 000DBA24`), response
`It can't be helped.` Unlike the rejected ordinary INFO donors, this record is
genuine SharedInfo and Skyrim ships its exact
`MaleSlyCynical` FUZ/LIP. The extracted 1.35-second asset decoded normally and
is now used by Falion's exact-speaker denial branch. This supersedes the
earlier statement that `MaleSlyCynical` had no suitable voiced refusal; the
remaining uncovered types are `MaleOldGrumpy`, `FemaleElfHaughty`,
`FemaleShrill`, and `FemaleUniqueMirabelleErvine`.

## Recommended Phase 1 candidate

Use mutually exclusive player-gold conditions on terminal dialogue INFOs while
leaving the Papyrus service check authoritative:

1. Existing affirmative terminal INFOs require player `GetItemCount Gold001 >=
   250`.
2. New denial terminal INFOs require player `GetItemCount Gold001 < 250`, call
   the same service fragment, and therefore still produce the proven denial
   trace and notification without charging or moving.
3. Farengar, Wylandriah, and Calcelmo use Skyrim SharedInfo `000C6E2D`.
4. Sybille uses HearthFires SharedInfo `0000B0B2`.
5. Wuunferth uses an owned forced-subtitle response with no LIP file.
6. Each of the five College destination topics receives one owned
   forced-subtitle denial INFO covering all eligible faculty. Per-voice faculty
   denial branches are deferred; they would add considerable record and audit
   complexity for provisional voice polish.
7. The map adapter remains notification-only because its selection happens
   after dialogue closes.

This candidate adds ten denial INFOs: five exact court-wizard records and one
faculty record under each destination topic. It fixes the affirmative-before-
denial mismatch without introducing custom voice assets or weakening the
service-side fare check.

The existing carriage generator already proves the required CTDA encoding for
inverse player `GetItemCount Gold001` conditions. Static audits must verify the
two condition ranges, the genuine SharedInfo/topic membership, exact FUZ paths,
the subtitle fallbacks, and that every denial INFO still calls the service.

## Implementation status

The candidate is generated, deployed, and has passed its first monitored live
gameplay validation.
The second generator pass was byte-identical at ESP SHA-256
`3D469B2441FFEBCC0AF57D4F77ADB3FE49B940C56707C0B027133EE6799A2CA5`.
The exact-record audit passes against the deployed copy, the vanilla archive
audit confirms every used FUZ, and the independent map-adapter audit remains
green. Candidate package:
`dist\DiegeticTravelWizardGuides-fare-denials-candidate.zip`, SHA-256
`45219F0C475EF0EAE020F6BE332F761E44E3376BC0E332F6A5B017D55EBFB793`.

The live pass confirmed Farengar's Skyrim refusal and Sybille's HearthFires
refusal, including clean service denials and funded direct regressions. It also
confirmed the intended silent College subtitle fallback with Tolfdir, Nirya,
and Sergius, silent notification-only map denials, and funded map travel.
Wylandriah and Calcelmo retain statically verified assets but await focused live
voice spot-checks. Wuunferth remains intentionally subtitle-only.

The later seven-spoke candidate adds Falion's voiced `CantBeHelped` refusal.
Its exact-record and archive audits pass. A focused monitored live test proved
the full audible line and lip sync, followed by a clean service denial with no
payment or movement.
