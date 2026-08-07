# Diegetic Travel handoff

Updated: 2026-08-02

## Mirabelle presentation and parchment handoff

The 2026-08-02 actor-targeted voice candidate is Rejected. Selecting
Mirabelle's parchment prompt queued the voice request and immediately crashed
Skyrim before the parchment `Show` call. It was rolled back to a subtitle-only
safe fallback before this new candidate was built.

The implementation deliberately does not call `ObjectReference.Say` on the
original `MG01` topic: the installed quest fragment proves that First Lessons
calls `Stop()` at completion, so that architecture would normally be silent.
The first `ConsoleUtil.SetSelectedReference` experiment is rejected:
ConsoleUtil queues the selection change through the UI message queue, then
immediately reads the current console target for `ExecuteCommand`, creating a
targeting race that produced no Mirabelle audio in the live test. The new
actor-targeted replacement scheduled a game-thread task, resolved Mirabelle,
and called CommonLibSSE-NG `Script::CompileAndRun`. CrashLogger proves the
access violation occurred inside that exact call with Mirabelle, the temporary
Script, and the `SpeakSound` path on the stack. The module's configured
CommonLib uses AE relocation ID `21890`; OStim NG's maintained workaround uses
`441582` for runtime patches 1.6.1130 and newer. LoreRim is 1.6.1170, so the
outdated relocation—not Menu Framework—is the immediate crash cause. The
checkout itself is official CommonLibSSE-NG at upstream commit
`b93280e832f263dbef44e44cbe2936622a02f91a`; replacing it with a random fork is
not the fix.

The new isolated Candidate retains official CommonLib and bypasses only the
stale convenience method. `dependencies.lock.json` pins the exact Skyrim,
SKSE, Address Library, Menu Framework, RUSTIC MAPS, Skyrim Paper Map by Caro
Tuts for FWMF, wizard-core, CommonLib, and
vcpkg inputs. Its read-only audit decodes the locked Address Library database
and proves legacy ID `21890` is absent, ID `21891` maps to the rejected crash
offset `0x33D880`, and modern ID `441582` maps to the required `0x33D6A0`.
The native bridge refuses every runtime except Skyrim 1.6.1170, refuses any
offset mismatch, and accepts only Mirabelle reference `0001C1B9` with the exact
installed MG01 FUZ path.

For the first focused test, selecting Mirabelle's parchment prompt queues only
the voice probe and returns before parchment request creation or `Show`.
Therefore no map is expected from Mirabelle. Other faculty retain the existing
map behavior. This deliberately separates the corrected voice call from Menu
Framework; it is offline-audited, not yet gameplay-proven.

The first focused monitored pass promoted the corrected relocation and native
playback to Proven: four Mirabelle attempts queued and dispatched at ID
`441582` / offset `0x33D6A0`, the player heard the matching line with proper lip
sync, Skyrim exited normally, and no new crash report or DNT error was produced.
The remaining defect was ordering: `OpenMap` waited for the subtitle-only INFO
to finish and the Dialogue Menu to close, producing a silent subtitle/lip-sync
presentation before the audible native FUZ. The follow-up timing Candidate
queues Mirabelle's proven probe immediately from the INFO OnBegin path; its
native game-thread task pauses that silent response, and Mirabelle still returns
before any parchment request or Menu Framework call. This timing change still
needed the focused live check recorded below.

That focused timing check is now Proven: two clean OnBegin probes started the
voice at the intended moment with correct lip sync, normal exit, no new crash,
and no DNT error. The resulting line had no subtitle because
`PauseCurrentDialogue` also removes the Fuz Ro D-oh-generated silent subtitle,
while `SpeakSound` creates audio/lip data but no subtitle entry. The follow-up
Candidate adds the hard-coded matching text to Skyrim's normal
`SubtitleManager` immediately after playback starts, under the manager's own
spin lock and with Mirabelle's speaker handle plus forced display. It does not
draw custom HUD text or change the active Fuz Ro D-oh/Lingering Subtitles Fix
mods.

That focused subtitle pass is now Proven for insertion and visible display.
Two Mirabelle attempts queued and dispatched cleanly at relocation ID `441582`
/ offset `0x33D6A0`; both logged `subtitleAdded=true`. The player confirmed the
subtitle, voice, and lip sync worked together. Skyrim exited normally, no new
crash report was created, and neither native nor DNT Papyrus logging reported
an error. Subtitle lifetime/cleanup was not separately reported and remains a
minor later regression check rather than a blocker.

The currently deployed Candidate restores the parchment handoff. Direct extraction from
`Skyrim - Voices_en0.bsa` measures the exact MG01 XWM payload at 2.147846
seconds. After the proven OnBegin voice/subtitle dispatch, the provider now
reserves 2.35 seconds for playback plus a short queued-task/cleanup margin,
then enters the existing proven dialogue-close and parchment `Show` path. It
marks the request as opening before the wait to prevent re-entry. A rejected
voice dispatch no longer denies travel; it falls back to opening the map. This
end-to-end voice -> subtitle -> map -> travel sequence is offline-audited and
needs one focused live test.

The workspace now advances that deployed one-off into a provider-neutral
offline candidate. `PlayPresentation` accepts a live actor, constrained
installed FUZ path, subtitle text, and measured duration; it returns the exact
duration plus a 0.20-second task margin. The queued task retains an
`ObjectRefHandle`, inserts the provider subtitle through the proven normal
subtitle path, and preserves the exact 1.6.1170 relocation guard. Mirabelle is
the first configured provider, while `PlayVoiceProbe` remains a compatibility
wrapper. This workspace revision is not deployed while another Skyrim test is
active. It needs the same focused voice -> subtitle -> map -> travel pass after
the game closes.

The generated DIAL now contains two mutually exclusive INFOs: the general
faculty response explicitly excludes Mirabelle, while the dedicated response
requires exact `MirabelleErvine` identity and also sets her exact speaker.
Both retain the proven OnBegin parchment fragment. The quest script binds
`MirabelleBase` alongside the existing wizard service.

Offline evidence:

- all three Papyrus scripts compile with zero errors and warnings;
- the independent xEdit audit passes the quest properties, two INFOs, exact
  conditions/speaker, matching response text, and both fragments;
- ESP regeneration is byte-identical at SHA-256
  `5A6E8305BB1C0E9EDD62A32B3C144700AA788AD427F968F2451BD3742018A8CC`;
- provider PEX SHA-256 is
  `2C79AF9C28581BB51608234972AB135B48EB74FB7C64F5098B057BFAB5063784`;
- native-contract PEX SHA-256 is
  `3B2CF967E7B4C9671FD918E6FD3999AE08DF93DA598CBE2BE130A08E354D2956`;
- native DLL SHA-256 is
  `1F0E2C1DB15896614582618CC63BDBB8169D76E99B9DC4FE80A42F3FCB800043`;
- native tests pass, and source/package audits report zero bundled artwork or
  audio;
- all three Papyrus scripts compile with zero errors and warnings, and the
  independent xEdit adapter audit passes;
- the dependency audit proves the exact runtime hashes, pinned CommonLib
  commit, and corrected Address Library mapping before build.

Do not retest the rejected DLL. The corrected candidate now tests Mirabelle's
complete voice/subtitle-to-parchment handoff. Before launch, verify its deployed
hashes against the workspace and run the non-launching profile preflight. Do
not launch without explicit user approval.

Broad offline checkpoint package hashes:

- `DiegeticTravel-alpha.zip`:
  `9D729A230725A984AEB510180C472EF6EDCDEAF5FF26FAB4238D2E4D7A5B979A`;
- `DiegeticTravelParchmentPicker-offline-candidate.zip`:
  `CC90A93C56A65AC3601126EFCD97E09BD4BDA547889B6FEBEAE294024A4B7671`;
- `DiegeticTravelWizardGuides-phase1.zip`:
  `0F5BF619466BF2A8E72345CBB9C9DFC43D8E561E95F768674CA3E72165E83C55`;
- `DiegeticTravelWizardMapAdapter-alpha.zip`:
  `CDFF6A1F4297B77073B50526FFED4A2B71B8AE6781E973EBCBBB6CCC99A41994`.

The workspace-only suite, Python routing tests, all native/Papyrus builds,
staging-only xEdit audits, and packages pass. No workspace candidate from this
checkpoint has been deployed to LoreRim while the parallel gameplay test is
active.

## Seven-spoke wizard live pass and Morthal follow-up

The College-centred star now has seven spokes: Farengar/Whiterun,
Wylandriah/Riften, Sybille/Solitude, Wuunferth/Windhelm, Calcelmo/Markarth,
Madena/Dawnstar, and Falion/Morthal. Every spoke wizard offers only the College;
permanent College faculty offer all seven capitals. Trust and quest gating
remain deliberately out of scope.

The two new speaker records are exact and locally inventoried:

- Madena `01361D`, reference `01A6C3`, voice `FemaleCondescending`;
- Falion `0135E9`, reference `01AA5E`, voice `MaleSlyCynical`.

Dawnstar arrives at purpose-built `MadenaServiceMarkerREF` (`0877B4`). The
first Morthal candidate, `MorthalMapMarkerRef` (`0177B0`), was rejected by the
2026-08-01 live pass because COTN geometry places the player on a roof. A
full-profile VFS xEdit audit identified Skyrim's purpose-built ground-level
`MorthalCarriageEastDestinationMarker` (`0EB7CC`) as the replacement; no active
plugin overrides it. Both new properties have runtime FormID repair so
existing active-quest saves cannot retain stale serialized values.

The generator and independent audit prove seven exact direct routes, seven hub
links, two new three-INFO destination topics, mutually exclusive funded/denial
conditions, exact fragment destinations, and both marker properties. Madena
and Falion have genuine voiced/lip-synced generic `Of course.` assets; Madena
also has the chosen house-purchase refusal. Falion now uses generic SharedInfo
`CantBeHelped` (`000DBA24`, "It can't be helped."), whose distinct 1.35-second
`MaleSlyCynical` FUZ/LIP was extracted, decoded, and level-checked. Both wizard
Papyrus scripts compile with zero errors or warnings.
Running the generator a second time produced the same ESP hash byte-for-byte.

The parchment provider now adds Dawnstar at normalized `(0.570,0.177)` and
Morthal at `(0.402,0.298)`. Native tests, three Papyrus compiles, the adapter
xEdit audit, the seven-destination source audit, and the zero-bundled-asset
audit pass. The proven native UI core/DLL and adapter ESP are otherwise
unchanged. Exact artifacts:

- wizard ESP SHA-256
  `174CD2B86AC08693C4B708CDB1141190B5093F2BC6C594BCBE03916840D47B56`;
- wizard service PEX SHA-256
  `2250E1D4C750B424419957EB6C2D5C9EC40E2498348FF02D7E2A4842F34E6D68`;
- wizard package `dist\DiegeticTravelWizardGuides-seven-spoke-candidate.zip`,
  SHA-256 `29844E10D041790F0898B564B939DC562AFE1001EED008E6F9053F970E233F86`;
- parchment provider PEX SHA-256
  `116ED9A31FFBC2795F648695B8D52BFADBA54B1B642E2BCBC5E673C10A65795A`;
- parchment package `dist\DiegeticTravelParchmentPicker-offline-candidate.zip`,
  SHA-256 `3335140DEAD3319BFC5E2E202A6AF65AD555D38DA182C867615082E61769D83B`.

An earlier monitored 2026-08-01 run recorded two clean trip completions with no
Papyrus/native warning. The replacement Morthal carriage marker is now Proven:
the player arrived on the ground. Falion's zero-gold branch correctly denied
travel, and his funded route returned to the College. With the rebuilt
1.75-second delay, the player heard only "course." Direct extraction proves the
correct 0.93-second FUZ is valid; the service also played `ITMGoldDown` at the
exact start of the response, making audio masking the stronger explanation than
end cutoff. All thirteen reused success recordings are at most 1.11 seconds.
The current build therefore reserves 1.5 seconds for dialogue, then calls
`FarePaymentSound.PlayAndWait`, then teleports. A focused monitored retest proved
the full lip-synced `It can't be helped.` denial, the full `Of course.` funded
confirmation, payment cue, and completed teleport. Papyrus recorded the denial
and two Falion funded start/completion pairs; the same run also completed a
Mirabelle parchment trip to Morthal with clean HUD hide/restore. The voice and
payment sequencing is now Proven. Dawnstar/Morthal crest alignment and the
seven-choice dialogue fallback remain useful later regression checks. Do not
launch without explicit user approval.

## Parchment-picker live checkpoint

The reusable parchment destination picker is implemented under
`modules\parchment-picker` as a separate, workspace-only candidate. It does not
modify the proven wizard core or BCD adapter. `DNTParchmentPicker.dll` uses the
installed SKSE Menu Framework through its dynamic v3 interface and exposes a
small Papyrus request/result bridge. Provider scripts supply artwork path,
artwork aspect ratio, labels, fares, and normalized marker positions; the
native picker returns only a selection index or cancel. The wizard provider
then maps that index to the existing stable destination ID and calls the
proven `DNT_WizardTravelService`.

The generated `DiegeticTravelWizardParchment.esp` owns a separate permanent-
faculty dialogue branch with the prompt `Could you show me your travel map?
(250 gold per trip)`. Its OnBegin fragment waits for the Dialogue Menu to close
before opening the blocking parchment window. The ESP masters the wizard core
but not Better Carriage Destinations, defines no FormList/world-map whitelist,
and leaves the core dialogue fallback and proven BCD adapter available. The
current core dialogue fallback now contains seven destinations; the older BCD
adapter remains intentionally limited to its five-city world-map whitelist.

Build and structural evidence:

- C++ request/layout tests pass at 16:9, 21:9, and 32:9;
- all three Papyrus scripts compile with zero errors and warnings;
- the AE native DLL builds cleanly against the existing local
  CommonLibSSE-NG checkout;
- all dynamically resolved functions exist in LoreRim's exact installed SKSE
  Menu Framework DLL, including the polyline and concave-fill primitives used
  by the cursor revision;
- the independent headless-xEdit audit proves quest/service binding, the
  dedicated top-level dialogue branch, exact faculty conditions, OnBegin
  fragment binding, no BCD master, and no FLST;
- ESP regeneration is byte-identical at SHA-256
  `90DB9BF3FFE1823D0403D4739BF694B8FACC89E498276C66363C5E3C4D760E0B`;
- Champollion readback proves the provider PEX embeds the default texture path
  and provider-owned aspect ratio and preserves properly capitalized display
  labels;
- the package contains zero artwork/audio assets.

The previously gameplay-proven no-default-focus/translucent-cursor DLL SHA-256
was `506A373F5899D13C519F44E992755296BA28D2866483F0895979F6C83F1025CF`.
The rejected actor-targeted voice DLL SHA-256 was
`EB99DB57F4E0A2F2C893D4976549F7EBBE371EBD49EDA7DED28274A60F19C0A4`.
The subtitle-only safe fallback DLL SHA-256 was
`577F2BC6B6BEF62D1B41EB8AD5A3BC1E18F73A0EDD57F3B14B135973F7FB333E`.
The gameplay-proven corrected-relocation/timing DLL SHA-256 is
`A8661EABDFF32795ED8FFD881E69E4FF6340B619DE168F7A6F878C2CB5B6BCA2`.
The current forced-subtitle Candidate DLL SHA-256 is
`1F0E2C1DB15896614582618CC63BDBB8169D76E99B9DC4FE80A42F3FCB800043`.
The complete package is
`dist\DiegeticTravelParchmentPicker-offline-candidate.zip`, SHA-256
`CA785A6BDE17AC9F0A11D262920A731439FCCD9B9EE33201B1537F7EDDD059EC`.
The prior five-route DLL was deployed and tested at SHA-256
`CFEA7975EB13EE34629A70A0BEA94974DDC5A63ADBD900B6BE7108DF31B15CD1`.
The current forced-subtitle revision is deployed to the owned test mod
`D:\Lorerim\mods\DiegeticTravel - Parchment Picker Test`. All six runtime
files match the audited workspace byte-for-byte. Its identifiers include DLL
SHA-256
`1F0E2C1DB15896614582618CC63BDBB8169D76E99B9DC4FE80A42F3FCB800043`
and provider PEX SHA-256
`2C79AF9C28581BB51608234972AB135B48EB74FB7C64F5098B057BFAB5063784`.
Its non-launching `UltraDiegeticTravel` preflight passes with the wizard core
and parchment picker enabled, the original carriage module disabled, and no
map adapter required.
It references LoreRim's already-enabled RUSTIC MAPS texture at
`Data\textures\dungeons\imperial\battlemap01.dds`; no map image is shipped.
Inspection places the useful parchment edge at texture row 3016. The provider
now requests UV max `0.736328` with aspect `1.358090`, removing the thin opaque
backing strip that the prior 0.75 crop displayed. Its corrected destination
coordinates target the five printed city crests. LoreRim's installed 4K texture
SHA-256 is
`C77E6B93129577CD23C6AC733310A5EA6A028F4BE00B472F9AA62018C4C239F8`.
If the image is missing, the native picker logs once per request and renders a
diagnostic selection fallback instead of disabling travel.

The next workspace-only wizard candidate deliberately separates visual themes:
boats/carriages retain the rough RUSTIC map, while wizards reference Caro
Tuts/FWMF's formal `Data\textures\terrain\tamriel\skyrim.dds`. The formal map
uses crop `(0.088379,0.187012)-(0.932129,0.783691)` at aspect `1.414075`.
Marker coordinates are derived from FWMF's exported Tamriel quad and exact
vanilla marker reference positions, not hand-tuned. It also normalizes all
eight vanilla hold icons to full alpha, removes the custom hat/origin assets
from the package, and uses the vanilla Winterhold castle for the origin only.
Each destination keeps its own hold icon under the red hover halo.
The full candidate is built, audited, and deployed to the owned parchment test
mod. Its archive SHA-256 is
`23A405ADB880028E7922F9309F9AB499233F49CA76E6368024B02F46C2F21E0C`;
the deployed DLL is
`20723F48EA920B887390FBD2E83A10816025BCC9663FCA480CD370AA24487C45`
and the deployed wizard-provider PEX is
`75B2FC84E7188A0036930D64D5EE4F6C8466348ED2BC145D53F55584CD98F411`.
The no-launch `UltraDiegeticTravel` preflight passes with the formal-map
dependency enabled.

The first formal-map gameplay pass on 2026-08-04 exposed one existing-save
edge case: the new PEX supplied the formal UV crop and new icons, but the quest
auto-property still supplied the saved `battlemap01.dds` path. Native logging
proved the mismatch at `PARCHMENT_OPEN`. The provider now hardcodes the texture
path alongside its effective crop/aspect values, so all parts of the artwork
profile bypass stale save properties. That pass otherwise opened cleanly,
loaded all seven destination icons, restored all 12 HUD layers, selected
Whiterun, and reached the expected `250 required / 140 available` denial with
no DNT errors. The follow-up 32:9 pass visually approved the formal Caro map,
all eight hold icons, exact marker alignment, and destination-preserving hover.
Native/Papyrus logs recorded the formal texture, all seven destination assets,
12-layer HUD restoration, an exact 250-gold charge, and completed Whiterun
travel with no DNT warning/error. The formal wizard-map candidate is Proven.

The parchment core is now gameplay-proven. At 32:9, the RUSTIC texture rendered
centered and unstretched with aligned city buttons. Native logs recorded four
clean opens, button cancellation, a funded Whiterun selection handed to the
existing travel service, and underfunded Whiterun and Solitude selections that
charged and moved nothing. Papyrus recorded two completed trips and no native
or script errors/warnings. The result event, payment boundary, and cancel-button
path are therefore proven; Escape, controller B, and the missing-art fallback
remain pending. A later monitored pass displayed the corrected ASCII footer
and completed a funded Solitude selection, proving a non-default destination.

The dialogue branch initially remained absent until the user made and reloaded
a save with the adapter installed. This matches the Creation Kit community's
documented custom-dialogue save/load bug. Treat one save/reload as an
installation compatibility step when the prompt is missing; quest stop/start
alone did not repair the live save. Do not add a quest-reset migration for this
engine behavior.

The ASCII footer is now live-proven. The first HUD attempt called
`SetVisible(false)` on the vanilla `HUD Menu`; logs proved the call and exact
restore executed, but the screenshot retained the bottom-left meters and
widgets. That approach is rejected for LoreRim because Norden enables a
separate TrueHUD player widget and STB movies.

The multi-menu replacement mirrors LoreRim's installed Ultimate Immersion Toggle
targets as optional menu names (`HUD Menu`, `TrueHUD`, `lvlWidget`, STB, and
related movies). For every present movie it saves both visibility and numeric
`_root._alpha`, hides it, and restores the exact values on selection/cancel.
No LoreRim configuration is edited and absent optional menus are skipped. A
monitored pass visually proved the HUD was absent while the parchment was open;
native logs recorded 12 present movies hidden from visibility/alpha 100 and
restored to those exact values. The same pass completed a funded Markarth trip
without native or Papyrus errors. This lifecycle is now gameplay-proven.

The corrected crop, five crest centers, Winterhold origin, and five-route star
are now visually gameplay-proven at 32:9; the user confirmed that everything
was in the right spot and that route selection worked. That pass also rejected
the subdued idle treatment as too hard to see and the yellow custom pointer as
stylistically inconsistent with LoreRim's other screens. The current candidate
enlarges each visible ring to 46% of its hitbox, draws every idle ring and route
in strong gold, and changes only the hovered or controller-focused route and
ring to red. Selection still occurs on release inside the invisible hitbox, so
a press-drag outside remains safe.

LoreRim's active cursor is `Norden UI 16x9\Interface\cursormenu.swf`, a
Scaleform movie. Menu Framework renders its ImGui layer after Skyrim's
Scaleform menus and exposes only ImGui/Windows cursor selection, so the exact
SWF cursor cannot be placed above this parchment without a deeper framework or
Scaleform integration. The candidate instead redraws the same monochrome arrow
silhouette and palette with installed Menu Framework primitives. It copies and
ships no cursor asset.

The monitored visibility pass proved the large gold idle rings/routes and red
active route at 32:9. The user said the result looked good and confirmed that
the new monochrome cursor appeared. Native logs recorded one clean cancel, then
a Markarth selection and completed 250-gold trip; all 12 HUD layers restored
exactly and no DNT error/warning appeared. The apparent initial Whiterun state
was ImGui's explicitly requested first-item focus, not a travel selection. The
polish candidate removes that default focus, suppresses retained navigation
focus until actual keyboard/gamepad input, and reduces the cursor's dark-center
alpha from 245 to 150 while retaining the pale edge and outline. The full
native/Papyrus/xEdit/asset/test suite passes.

That polish pass is now complete. The user confirmed the no-default startup and
translucent cursor looked good. The monitored run completed a parchment trip to
Markarth and Calcelmo's direct return to the College, then proved both Escape
and close-button cancellation on separate parchment opens. Native logs restored
all 12 HUD layers exactly after every selection/cancel, and no DNT error or
warning appeared. No-default startup, the translucent cursor center, and Escape
cancellation are gameplay-proven. Controller navigation/B cancellation are
deliberately deferred while both controller layers are disabled; retest them
only with the intended `No Delete Controller` compatibility stack enabled.

The isolated owned mod is
`D:\Lorerim\mods\DiegeticTravel - Parchment Picker Test`; it contains no
artwork. The non-launching preflight targets `UltraDiegeticTravel`: the core,
test mod, parchment ESP, and RUSTIC MAPS dependency must be enabled, while the
original carriage module remains disabled.
`tools\Run-WizardGuidesTest.ps1 -RequireParchmentPicker` monitors both Papyrus
and `DNTParchmentPicker.log`. Batch the new picker matrix with the remaining
Wylandriah, Calcelmo, and Wuunferth service spot checks. Do not launch Skyrim
without the user's explicit approval.

## Evidence ledger

Use `docs\EVIDENCE_LEDGER.md` as the source of truth for working assumptions,
rejected approaches, live-proven behavior, and the next candidate test. In
particular, do not treat xEdit accepting a dialogue field as runtime proof.
Commit `ae1dc5c`, whose ESP is SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550`, is the
previous live-proven Solitude checkpoint. The exterior-College build then
rebound `CollegeMarker` to `WinterholdCollegeMapMarkerRef`. The monitored pass migrated
an existing save exactly once, completed two city-to-College returns, and the
user confirmed that the exterior landing was usable. Its exact payload is
`dist\DiegeticTravelWizardGuides-exterior-college-candidate.zip`, SHA-256
`E958E0AD2B43F282A9C214FEFFBABA5097601F77566DAB5789DB92C0C6625F0B`.
Because quest-script properties persist in existing saves,
`DNT_WizardTravelService.GetCollegeMarker` resolves `00046BDF:Skyrim.esm` on
first access and replaces a stale serialized sleep-marker property. A migrated
save emits `WIZARD_TRAVEL_MIGRATE` before its first College trip.

The fare-feedback build is now the latest live-proven Phase 1 checkpoint. It is
byte-idempotent at ESP SHA-256
`2DF34217F6576D3FCFE720E1E101690216E6D94157C26A9D79544A1E7BA83C21`.
It replaces the ordinary insufficient-funds modal with a top-left
`Debug.Notification` and binds `FarePaymentSound` to vanilla `ITMGoldDown`
`000334AB:Skyrim.esm`, played only after successful silent gold removal. The
promoted exact package is `dist\DiegeticTravelWizardGuides-phase1.zip`, SHA-256
`0029CC61CE6A9D94A900033BA1BACB341F9756F2E8F611F57F534DC4F3DDE759`.
Both scripts compile with zero errors and warnings; the generator is
byte-idempotent; and the independent wizard-star and map-adapter audits pass.
The monitored pass proved a funded map trip, a direct-dialogue denial and
funded retry, and a map-initiated denial. The two denials displayed the
top-left notification, charged nothing, and did not move the player; the
funded trips played the payment cue and completed normally. The remaining UX
debt is semantic: a terminal dialogue INFO may still play its affirmative
vanilla response before the service discovers that the player lacks gold.
Read-only base-game and DLC research is recorded in
`docs\WIZARD_FARE_DENIAL_VOICES.md`. Two genuine SharedInfo donors cover eight
of the thirteen target voice types, including four of five direct court
wizards. The recommended next candidate adds inverse player-gold conditions to
terminal INFOs, uses those four voiced direct refusals, and uses subtitle-only
fallbacks for Wuunferth and the College destination menu. The map path remains
notification-only.

## Wizard-guide Phase 1

Phase 1 of the separate wizard-guide pillar is implemented under
`modules\wizard-guides`. It does not modify the carriage checkpoint or depend
on CFTO/Better Carriage Destinations.

Network:

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire (`013BBB:Skyrim.esm`) offers the College.
- Wylandriah (`019DEF:Skyrim.esm`) offers the College.
- Sybille Stentor (`0132AA:Skyrim.esm`) offers the College.
- Wuunferth the Unliving (`014146:Skyrim.esm`) offers the College.
- Calcelmo (`01338E:Skyrim.esm`) offers the College.
- Permanent College faculty at faction rank 3 or higher offer Whiterun,
  Riften, Solitude, Windhelm, or Markarth; students remain ineligible.
- All services are immediately available; faction, relationship, quest, and
  trust gates are deliberately deferred.
- Every hop costs 250 gold.
- Travel waits one second for dialogue to close and then calls `MoveTo`: no
  elapsed game time, rest, or recovery.

The UI-independent `DNT_WizardTravelService` exposes stable destination IDs plus
`GetFare`, `CanTravel`, and `RequestTravel`. New dialogue records call that
service through `DNT_WizardTravelFragment`; the optional BCD/Shazdeh adapter now
calls the same service without duplicating travel logic.

The generated plugin is `DiegeticTravelWizardGuides.esp`. It defines one
start-game-enabled quest, one top-level player branch, five custom topics, and
twelve INFOs. It overrides no existing records. Its SEQ and two compiled PEX
files live beside it in the module.

The three-node star passed its monitored gameplay test. INFO `000806` presents
`Can you teleport me to the College of Winterhold? (250 gold)` to Farengar and
binds `DestinationId=college`; INFO `000807` provides the corresponding
Wylandriah-to-College route. INFO `000808` is the College hub:
`Can you teleport me somewhere? (250 gold per trip)`. It carries no travel
fragment and links to exactly two destination topics:

- `000803` / INFO `00080B`: Whiterun (`DestinationId=whiterun`)
- `000804` / INFO `00080C`: Riften (`DestinationId=riften`)

The currently deployed voiced build gives each terminal travel INFO an
explicit, genuine vanilla Shared Response Data donor:

- Farengar (`MaleEvenTonedAccented`): `Yes.` from `000730FA:Skyrim.esm`
- Wylandriah (`FemaleEvenToned`): `Of course.` from `000DBA22:Skyrim.esm`
- Sybille (`FemaleSultry`): `Of course.` from `000DBA22:Skyrim.esm`
- all three general faculty destinations: `Of course.` from
  `000DBA22:Skyrim.esm`
- Mirabelle's three exact-speaker fallbacks: owned subtitle-only `Of course.`

Voiced travel INFOs retain only the vanilla `Goodbye` response flag, have no
`LinkTo`, and run `DNT_WizardTravelFragment` on `OnBegin`. Mirabelle's terminal
INFOs additionally force subtitles and have no LIP file. The branching hub
owns the unvoiced response `Where do you need to go?`, has
`Force Subtitle + No LIP File`, no VMAD, and exactly three `LinkTo` entries.
This experiment exposed a semantic hole in the original audit. `000730FA` and
`000DBA22` are genuine SharedInfo records, but `00079AD7` is ordinary dialogue
from `Favor258Reject` in the Thane of Falkreath quest. xEdit permits that INFO
reference in `DNAM`, but Skyrim does not consider the two Phinis destination
INFOs valid choices: the owned hub says `Where do you need to go?` and the
dialogue closes with no travel trace. An earlier hub experiment similarly used
ordinary generic Hello INFO `00087940`; it spoke `Yes?` and failed to expose
the links. These tests reject arbitrary INFO donors, not SharedInfo on linked
topics generally. A vanilla-data scan found 1,037 linked-topic INFOs using
genuine Shared Response Data.

The proven baseline uses an owned Phinis hub and genuine SharedInfo `000DBA22`
(`OfCourse`) on both child INFOs. The generator and independent audit require a
non-empty donor EditorID, Misc/SharedInfo topic identity, and actual
parent-child membership. That baseline passed its monitored gameplay
regressions on 2026-07-31: the submenu, all four directed routes, fare denial,
and audible lip-synced replies for Farengar, Phinis, and Wylandriah all worked.
The live-proven faculty-access expansion generalizes those same records as
described below.

Arrival markers reuse stable Skyrim references whose effective positions
already reflect the installed JK interiors:

- College: `046BDF:Skyrim.esm`
  (`WinterholdCollegeMapMarkerRef`), vanilla winner. This replaces Phinis's
  private-room sleep marker with Skyrim's exterior College fast-travel anchor;
  the focused monitored pass confirmed the public exterior arrival is usable.
- Whiterun: `0B7AA5:Skyrim.esm` (`FarengarLabMARKER`), vanilla winner
- Riften: `044A4A:Skyrim.esm` (`RiftenKeepWizardLabMarker`), winner
  `JK's Mistveil Keep.esp`
- Solitude: `02C194:Skyrim.esm` (`BluePalaceAudienceMarker`), winner
  `JK's Blue Palace.esp`
- Windhelm: `0A3F1C:Skyrim.esm` (`WindhelmWuunferthLabMarker`), focused
  inventory winner `Unofficial Skyrim Special Edition Patch.esp`
- Markarth: `03692A:Skyrim.esm`
  (`MarkarthCastleWizardVendorMarkerREF`), focused inventory winner Skyrim.esm

Both scripts compile with 0 errors and 0 warnings. The workspace plugin parses
successfully off-order and has zero dangling references or missing masters.
The compact headless-xEdit audit confirms exact speakers, response donors,
flags, hub links, fragment timing, bound service, and destination IDs. A
separate BSA filename-table audit confirms all three selected vanilla FUZ files
exist. Arrival-marker geometry and audio playback remain gameplay-only checks.

An earlier live pass proved that Farengar's top-level option appeared, but
the borrowed response played and no `WIZARD_TRAVEL_*` trace was emitted. The
fragment never entered the service. The new build removes both suspect layers:
there is no Shared Info inheritance, and the fragment runs on `OnBegin` rather
than `OnEnd`. `DNT_WizardTravelService` then waits one second before charging
and moving the player.

The replacement build passed its live two-way test on 2026-07-31. With only
72 gold, Farengar's route emitted `WIZARD_TRAVEL_DENIED` and did not move the
player. After adding test funds, Farengar completed the College trip:

- `WIZARD_TRAVEL_START destination=college fare=250`
- `WIZARD_TRAVEL_COMPLETE destination=college fare=250`

Phinis then completed the return trip:

- `WIZARD_TRAVEL_START destination=Whiterun fare=250`
- `WIZARD_TRAVEL_COMPLETE destination=Whiterun fare=250`

The player confirmed arrival at the College and then back in Whiterun. This
proves the full dialogue -> fragment -> fare -> delayed `MoveTo` path in both
directions and establishes the College-centred star's first working spoke.

The expanded star then completed three monitored trips:

- Farengar -> College
- Phinis -> Riften
- Wylandriah -> College

Every trip emitted one `WIZARD_TRAVEL_START` and one
`WIZARD_TRAVEL_COMPLETE`, and Skyrim exited normally. The simultaneous
`IsPoison()` errors belong to LoreRim's
`Nox_WAR_ThrowingKnife_PoisonApply.OnItemRemoved`; its listener reacts to the
gold removal but does not interrupt travel.

Rollback commit `a03262d` checkpoints the proven two-way build. Commit
`9aa25ef` checkpoints the live-proven three-node star before voice changes, and
commit `ed004f2` checkpoints the fully proven voiced Phase 1 build.
Commit `4dfb646` checkpoints the live-proven permanent-faculty expansion.
`tools/Audit-WizardGuideStar.ps1` checks the seven visible INFOs, while
`tools/Audit-WizardVoiceAssets.ps1` checks the exact FUZ paths. The voice
patcher produces byte-identical output on a second run. Both the generator and
the independent audit now prove that every donor belongs to a special
Misc/SharedInfo topic and has an EditorID; the separate archive audit proves
the expected speaker-specific FUZ paths. See `docs\EVIDENCE_LEDGER.md` for the
promoted live evidence and the gate future dialogue changes must pass.

`tools/Patch-WizardGuideDialogue.ps1` now defaults to the patched headless
xEdit at `build/xedit-patched/SSEEdit64.exe`, patches the workspace copy only,
and deploys to LoreRim only when passed `-Deploy`; deployment is refused while
`SkyrimSE` is running. `-Deploy` copies the complete owned module payload so
the ESP, SEQ, and newly compiled PEX files stay in sync. The latest fully proven
ESP is the fare-feedback build at SHA-256
`2DF34217F6576D3FCFE720E1E101690216E6D94157C26A9D79544A1E7BA83C21`.
Its exact live-tested payload is `dist\DiegeticTravelWizardGuides-phase1.zip`,
SHA-256
`0029CC61CE6A9D94A900033BA1BACB341F9756F2E8F611F57F534DC4F3DDE759`.
A normal package build recompiles the PEX files and changes their binary hashes;
use `-PackageOnly` when checkpointing already-tested artifacts, or require a
new live pass after recompilation.

### BCD wizard map adapter

The optional adapter lives under `modules\wizard-map-picker` and is deployed as
additional files inside the existing owned
`houseCARL - DiegeticTravelWizardGuides` mod directory. It does not modify the
live-proven core ESP. `DiegeticTravelWizardMap.esp` hard-masters the core wizard
plugin and Better Carriage Destinations, adds a second faculty dialogue option,
and opens BCD with a whitelist containing exactly these world-map markers:

- Whiterun `000162CE`
- Riften `0001C390`
- Solitude `0004D0F4`
- Windhelm `00038436`
- Markarth `0001C38A`

`DNT_WizardMapPicker` receives `BCD_SetDestination`, resolves the selected
marker while MapMenu is open, translates it to the existing lowercase stable
destination ID, closes the map, and calls
`DNT_WizardTravelService.RequestTravel`. It never calls BCD's pricing, scene,
or travel functions. Cancelling does not invoke the core service, and the old
five-choice dialogue submenu remains available.

Research is pinned to current BCD HEAD
`136dc7b3ad9754877c485fd5cea29550af108888`; LoreRim has BCD 1.0.10 enabled in
`UltraDiegeticTravel`. Both adapter scripts compile with 0 errors and 0
warnings.

The first monitored adapter build loaded its quest and all properties at runtime
but exposed no map option. It incorrectly assigned the new topic to the existing
faculty top-level branch; Skyrim exposes only that branch's designated Starting
Topic. That ESP (`85AE4DEF...`) is rejected. The corrected generator gives the
map prompt its own non-blocking, non-exclusive top-level branch and makes it that
branch's Starting Topic. Generation is byte-idempotent, and the independent
audit now rejects core-branch reuse while requiring the two-way branch/topic
links, adapter-quest ownership, whitelist, seven quest properties, faculty
conditions, and OnBegin fragment. The corrected adapter ESP is SHA-256
`74D1EF6F6268BFAF5CCC12FA3D6CF4B074790ECC655A233E0AA4481132A08FE4`; the core
ESP remains
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.

The corrected candidate package is
`dist\DiegeticTravelWizardMapAdapter-alpha.zip`, SHA-256
`F55A9B42C6DF05F90A612DEC25168D43CC748C5CD36B3E1F80920B84E6BA3D95`.
`DiegeticTravelWizardMap.esp`, BCD, and the core plugin are enabled in the
dedicated profile. The complete monitored matrix in
`docs\WIZARD_MAP_ADAPTER.md` now passes.

The unchanged corrected adapter subsequently passed its first end-to-end live
selection run at 32:9. Its prompt appeared after saving once with the adapter
installed and reloading that save. Mirabelle opened the map, selecting Solitude
emitted `WIZARD_MAP_SELECT` and one matching core start/complete pair, and
Sybille returned the player to the College. Phinis then opened the map,
selecting Riften completed another matching pair, and Wylandriah returned the
player to the College. The prior pass with the same adapter installed also
completed a retained-list Faralda-to-Windhelm and Wuunferth-to-College
regression. The exterior-College pass then proved Ancano exclusion, the exact
five-marker whitelist, and cancellation with no payment or movement. The final
pass selected Windhelm through Mirabelle with only 22 gold and emitted
`WIZARD_MAP_SELECT` followed by `WIZARD_TRAVEL_DENIED reason=gold`, with no
start/completion, payment, or movement. A funded trip in the same pass played
the payment sound and completed normally. The adapter is therefore Proven as
a selection-only front end to the core service.

Run that matrix with
`tools\Run-WizardGuidesTest.ps1 -RequireMapAdapter`. This mode fails preflight
unless the adapter ESP, BCD ESP, adapter SEQ, and both adapter PEX files are
active/present, and it streams both `WIZARD_MAP_*` and `WIZARD_TRAVEL_*` traces.

### Faculty access

The current workspace and deployment broaden the College hub from exact
speaker Phinis to members of `CollegeofWinterholdFaction` at rank 3 or higher.
This selects twelve permanent faculty: Sergius, Mirabelle, Savos, Tolfdir,
Arniel, Enthir, Nirya, Colette, Phinis, Drevis, Faralda, and Urag. The condition
explicitly excludes Arniel's summoned shade and the dead Alftand NPC Endrast;
rank-0 students and Nelacar remain ineligible.

The generic `Of course.` SharedInfo has shipped audio for ten of the eleven
faculty voice types. Mirabelle's unique voice lacks it, so each destination
topic has a second exact-Mirabelle, subtitle-only INFO. The two inbound court
wizard routes are unchanged. The candidate is byte-idempotent at ESP SHA-256
`4EEAED7C6556ADC159A128C9D95FB66124C3C90FC3FB9200D4CF7CC797567E89`.
Both the workspace and deployed copy pass the strengthened seven-record xEdit
audit, and the archive audit passes all ten voiced faculty types. The focused
gameplay matrix passed on 2026-07-31: J'zargo had no option, every encountered
eligible faculty member had the hub and both choices, and Mirabelle's owned
subtitle-only confirmation completed travel as designed.
The fragment now passes `akSpeakerRef` into the service, and every denial,
start, and completion trace includes `source=<actor reference>` so the monitor
can distinguish faculty members that share the same destination INFO.

### Solitude-spoke proof

The proven build adds Sybille Stentor as the Solitude court wizard and a
third outward faculty choice, preserving the College hub topology. Sybille's
direct route uses the same genuine `Of course.` SharedInfo proven for
`FemaleSultry`; the BSA audit confirms her exact FUZ/LIP. General faculty use
the existing voiced response and Mirabelle receives a third owned
subtitle-only fallback.

The service binds `SolitudeMarker` to persistent Skyrim reference `0002C194`,
`BluePalaceAudienceMarker`. A focused xEdit inventory loaded JK's Blue Palace
and confirmed that it wins this reference and moves it to the remodeled court
floor. The generator adds DIAL `00080F`, child INFOs `000810` and `000811`, and
Sybille root INFO `000812`; it is byte-idempotent at ESP SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550`.
The independent audit verifies the three-link hub, all new speaker/response
conditions and fragments, and the service marker property. The monitored
2026-07-31 pass verified the three-choice menu, Mirabelle-to-Solitude travel,
safe Blue Palace arrival, Sybille's audible lip-synced response and return to
the College, and a Riften/Wylandriah regression.

### Windhelm/Markarth proof

The proven build extends the same College-centred star with Wuunferth the
Unliving and Calcelmo. A repeatable headless-xEdit inventory loads USSEP, JK's
Palace of the Kings, JK's Understone Keep, and the installed Snazzy interior
plugins. It resolves Wuunferth as `MaleOldGrumpy` NPC `00014146` with persistent
reference `0001B132`, and Calcelmo as `MaleOldKindly` NPC `0001338E` with
persistent reference `00019908`. The existing `000DBA22` `Of course.` FUZ/LIP
exists for both voice types.

The service binds `WindhelmMarker` to persistent reference `000A3F1C`,
`WindhelmWuunferthLabMarker`, and `MarkarthMarker` to persistent reference
`0003692A`, `MarkarthCastleWizardVendorMarkerREF`. Both are purpose-named
markers beside the relevant wizard. The focused winners are USSEP and
Skyrim.esm respectively; live arrival geometry is still required.

The generator adds Windhelm DIAL `000813`, voiced INFO `000814`, Mirabelle INFO
`000815`, and Wuunferth root INFO `000816`; Markarth uses DIAL `000817`, voiced
INFO `000818`, Mirabelle INFO `000819`, and Calcelmo root INFO `00081A`. The
faculty hub now links to exactly five destination topics. Both Papyrus scripts
compile with zero errors and warnings, all exact-record and voice-asset audits
pass, and a second generation is byte-identical at ESP SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.
The initial live build `9B4545B8...` completed five trips, including both new
round trips, but exposed a semantic audit hole: INFO `ANAM` did not gate the
top-level response. Ancano reference `0001E7D8` received a court-wizard route,
and both he and Calcelmo could select another identical root INFO and therefore
play the wrong donor voice. The corrected generator adds one subject
`GetIsID == 1` condition to every exact-speaker INFO, including Mirabelle's
fallbacks. The strengthened audit now requires both `ANAM` and that condition.
The monitored corrected-build pass confirmed Ancano no longer had the option;
faculty-to-Markarth, Calcelmo-to-College, Mirabelle-to-Windhelm,
Wuunferth-to-College, and a faculty-to-Whiterun regression all completed. The
user confirmed the tested voices matched their speakers and both arrivals were
usable. Wuunferth's line ended slightly early because travel begins after one
second; timing polish is deferred while the final voice set remains unsettled.
The complete live-proven fare-feedback build is deployed to the owned LoreRim
mod under `UltraDiegeticTravel`. Its core payload is synchronized with the
workspace, and the unchanged live-proven map-adapter payload remains installed.
The generator and both independent audits pass, and the final monitored pass
proved direct and map denials plus funded payment feedback.

At this checkpoint MO2's active profile is `UltraDiegeticTravel`. The complete
workspace payload has been deployed to
`D:\Lorerim\mods\houseCARL - DiegeticTravelWizardGuides`, and the installed
ESP, README, SEQ, PEX, and PSC files hash-match the workspace copies. Direct
reads of the MO2 profile files confirm the mod is enabled in the left pane and
`DiegeticTravelWizardGuides.esp` is checked in the right pane. The installed
build passes the strengthened structural audit and the monitored faculty and
five-city gameplay regressions. Do not launch Skyrim without coordinating with
the user; a parallel PickUpAsJunk task may also use MO2.

## Wizard-guide live tests

### Windhelm/Markarth exact-speaker regression

The monitored corrected-build pass recorded five trips and five matching
completions: faculty `0001C1A1` -> Markarth, Calcelmo `00019908` -> College,
Mirabelle `0001C1B9` -> Windhelm, Wuunferth `0001B132` -> College, and faculty
`0001C1A8` -> Whiterun. Ancano had no option and produced no travel trace. The
tested voices matched their actors; Wuunferth's line was only slightly clipped
by the former one-second travel delay. The current candidate separates dialogue
from the payment cue and waits for both before `MoveTo`.
Skyrim exited normally.

### Solitude-spoke regression

The monitored 2026-07-31 Solitude pass recorded four trips and four matching
completions. Mirabelle (`0001C1B9`) reached Solitude using her intentional
subtitle-only fallback; the player reported a safe Blue Palace arrival.
Sybille (`000198C5`) audibly delivered the lip-synced `Of course.` and returned
the player to the College. A faculty member (`0001C1A8`) then reached Riften,
and Wylandriah (`00019DF0`) returned the player to the College. Skyrim exited
normally with no wizard-travel denial or unpaired start.

### Faculty-access regression

The monitored 2026-07-31 faculty pass confirmed the rank-gated service in the
`UltraDiegeticTravel` profile. J'zargo, a rank-0 student, did not receive the
travel option. Every eligible faculty member encountered by the player did,
while Phinis retained both destinations. Mirabelle displayed her owned
subtitle-only `Of course.` fallback and completed the selected trip.

Papyrus recorded nine trips and nine matching completions, with no wizard
script warning. The run exercised faculty travel to both Whiterun and Riften
and returns through both Farengar and Wylandriah. Source references were
present on every trace, including the Phinis (`0001C1A7`), Farengar
(`0001A67E`), and Wylandriah (`00019DF0`) regressions. Skyrim exited normally.

### Presentation regression

The monitored 2026-07-31 presentation pass completed this sequence:

- Phinis -> Whiterun at 12:17:14;
- Farengar -> College at 12:17:46;
- Phinis -> Riften at 12:18:01;
- Wylandriah -> College at 12:18:31.

Each trip emitted exactly one start and one completion one second apart. The
player confirmed that Farengar's `Yes.` and Phinis's and Wylandriah's
`Of course.` were audible, lip-synced, and finished as expected. Phinis's
preceding custom `Where do you need to go?` remained silent and subtitled as
designed. Skyrim exited after four completed trips.

### Transport and fare regression

The monitored 2026-07-31 run covered all four directed edges and the failure
branch. Skyrim logged five successful trips, each with exactly one start and
one completion:

- College at 11:51:50, then Whiterun at 11:52:11;
- College at 11:52:27, then Riften at 11:52:39;
- College again at 11:53:12 after adding funds.

At 11:52:59, a College trip with only 72 gold logged exactly one denial
(`required=250 available=72`) and no start or completion. The player confirmed
that the route dialogue and Phinis submenu worked. That earlier run did not
check audio or lip sync. In particular, the owned hub response
`Where do you need to go?` is intentionally subtitle-only; the subsequent
destination response `Of course.` was verified in the later presentation pass.
No DNT errors were present in Papyrus, and Skyrim was no longer running when
the logs were collected.

## Safety and environment

- Treat the released LoreRim list as the clean baseline. Do not disable, reorder,
  replace, or edit mods in its stack to manufacture a "clean" test.
- The development mod is installed at
  `D:\Lorerim\mods\DiegeticTravel`.
- The user's current `[No Delete] 32x9 AIO` is enabled in
  `UltraDiegeticTravel`. The older
  `32x9 USERS ENABLE THIS - Misc AIO Patch for LoreRim` is intentionally
  disabled and must remain disabled; it is obsolete and has a broken BTPS icon.
- Do not launch Skyrim without the user's explicit approval.
- Do not edit `C:\Users\Theo\Documents\PickUpAsJunk`; another Codex task may be
  using it.

## Last carriage live test

- The fixed root fragment fired and matched the Whiterun driver.
- The destination menu showed only its first generated entry, Darkwater
  Crossing, because INFO OnBegin refreshed globals too late for the menu's
  choice snapshot.
- Darkwater Crossing displayed 800 gold / 5.60 hours.
- The purchase trace committed exactly 800 gold with CFTO destination code 11,
  and the player arrived at Darkwater Crossing. The stale-price/payment defect
  is fixed; menu population timing remains the target.

## Root cause and current source fix

Inspection found that generated root INFO `CFTO.esp:09D8C7` in
`DiegeticTravel.esp` had no VMAD subrecord. Consequently,
`DNT_PrepareOrigin.Fragment_0` never ran, while the destination purchase
fragments did run.

`tools/xedit/DNT_GeneratePlugin.pas` now makes INFO VMAD creation explicit:

- create the destination VMAD container;
- copy the template VMAD into it;
- set the fragment to `DNT_PrepareOrigin.Fragment_0`;
- explicitly set the INFO fragment timing flag to OnBegin;
- fail generation if the expected VMAD/script/fragment structure is absent.

The fix was regenerated and deployed on 2026-07-30. The active
`UltraDiegeticTravel` load-order winner now carries:

- `DNT_PrepareOrigin.Fragment_0` as the root INFO's OnBegin fragment;
- a bound `DNT_PrepareOrigin` script attachment;
- a non-null `Coordinator` property pointing at
  `000853:DiegeticTravel.esp`.

The deployed ESP SHA-256 is
`ED86F4205C6DE6B3391A5878B63A6001C414B7006D8883C2256AAE2E268205F1`.
The pre-deployment mod folder is backed up at
`build\backups\DiegeticTravel-20260730-184454`.

This deployed build was tested successfully for payment and CFTO handoff, but
confirmed the INFO OnBegin timing defect described above.

The workspace source now implements the timing fix:

- `DNT_DialogueMenuListener` is a player `ReferenceAlias` script;
- it registers for `Dialogue Menu` on initialization and after every save load;
- menu open resolves `Game.GetCurrentCrosshairRef()` and preloads every quote
  for the matched origin;
- `DNT_PrepareOrigin` reuses the completed cache instead of clearing it;
- `DNT_OriginService.RefreshQuotes` returns the available-route count, logged as
  `MENU_QUOTES_READY origin=<origin> available=<count>`;
- the generator adds the player alias/VMAD listener binding and emits the
  eligible start-game quest FormIDs; the PowerShell launcher serializes them
  into `Seq\DiegeticTravel.seq`;
- the origin services no longer all refresh the shared globals during startup.

The six Papyrus scripts compile cleanly, all ten Python tests pass, and the
generated ESP completed both off-order and active-load structural readback. The
coordinator quest has a forced player alias (ID 0), the alias VMAD points back
to that quest and alias ID, and `DNT_DialogueMenuListener.Coordinator` points at
the coordinator quest.

The first Pascal binary SEQ writer was rejected during validation:
JvInterpreter wrote twelve copies of `0x00000013` instead of raw FormIDs, and it
included an already-SGE CFTO quest override. The final build mirrors xEdit's
built-in eligibility rule, writes the fixed FormIDs to a text manifest, and lets
PowerShell serialize the four-byte little-endian entries with format,
uniqueness, and byte-count checks. The deployed 44-byte SEQ contains the 11
unique IDs `0x06000852` through `0x0600085C`.

The timing-fix package was deployed on 2026-07-30 after Skyrim closed. Only
`D:\Lorerim\mods\DiegeticTravel` was overlaid; no profile or other mod was
changed. The pre-deployment folder is backed up at
`build\backups\DiegeticTravel-20260730-201745`.

Deployed/package hashes:

- `DiegeticTravel.esp`:
  `63170DA469959069D8BD8841657AEEAD9E0D6522B7CB8EBBBA2FAD88F31B1E8C`
- `Seq\DiegeticTravel.seq`:
  `50BF3B406D9033462103C045C8727C29197C5747DC11504D4FC4E437ECA6ED4D`
- `dist\DiegeticTravel-alpha.zip`:
  `DA98AAF9FDE2FB9C4031EB477067C6132FA444E57F2B6D608B58003DAFFC1061`

No live Skyrim test of the menu-preload listener has been launched yet. Because
this update adds an alias to an already start-game-enabled quest, prefer the
gameplay harness's fresh test save/new-game path; an existing save may retain
the old running quest instance instead of reconstructing its new alias.

## xEdit work

- `tools/Generate-Plugin.ps1` now defaults to the locally built patched xEdit,
  runs it hidden against copied staging data, and needs no Module Selection
  click. Managed Windows UI Automation remains only when a stock executable is
  passed explicitly; the temporary dynamic C#/PInvoke implementation remains
  removed after Defender flagged the Codex transcript containing it.
- The first full headless carriage attempt proved the CLI patch worked but
  exposed a generator error: it redundantly rewrote the copied player alias's
  non-editable `Specific Reference` union. Removing that write produced a clean
  full build with 11 SEQ quest IDs. Failed headless runs now write compact error
  detail and cannot leave their own hidden xEdit process behind.
- The exact xEdit 4.1.5f source checkout is under ignored `.tools/`.
- The distributable source patch is
  `tools/xedit/patches/xedit-4.1.5f-script-autoload-autoexit.patch`.
- The patch makes `-autoload` and `-autoexit` available in Script mode. Stock
  xEdit parses those switches only in Edit mode even though Script mode has the
  corresponding load/shutdown paths.
- Delphi 12 Community is installed with its Win64 compiler files. The exact
  xEdit 4.1.5f source targets Delphi 11; all pinned source submodules (including
  nested JCL/JEDI) were initialized on 2026-07-30. MSBuild reaches `dcc64` but
  Community reports that the product does not support command-line compiling
  and produces no executable. Build the patched project through the RAD Studio
  IDE; the patched executable has not yet been produced or tested.

## houseCARL

houseCARL looks highly relevant because it provides headless Mutagen-backed MO2
record inspection, plugin authoring, Papyrus compilation, and dialogue/VMAD
validation. It may eventually replace the xEdit generator while leaving xEdit
as an independent verifier.

Both required runtimes are installed and verified:

- `Microsoft.NETCore.App 9.0.18`
- `Microsoft.AspNetCore.App 9.0.18`

houseCARL is installed and persistently configured to the MO2 instance at
`D:\Lorerim`. `UltraDiegeticTravel` had `DiegeticTravel` and
`DiegeticTravel.esp` active during the recorded validation; do not assume the
currently selected profile while the parallel gameplay test is running.

Post-deployment read-only validation of the timing-fix build on 2026-07-30
found:

- the root carriage topic winner is `DiegeticTravel.esp`;
- the root topic graph is OK and its one INFO has a bound, compiled result
  fragment;
- the Mixwater topic graph is OK and its purchase fragment is bound and
  compiled;
- the coordinator's forced player alias, alias VMAD quest/ID link, listener
  script, and `Coordinator` property all resolve to the generated coordinator
  quest;
- `DiegeticTravel.esp` has 0 dangling references, 0 missing masters, and
  0 unscannable records;
- 39 scripted records have 0 unbound properties, 0 bound-null properties, and
  0 unverifiable attachments.

`TasteOfDeath_Addon_Dialogue.esp` remains excluded from Mutagen inspection due
to an unrelated PKCU data-count mismatch. Every other plugin, including
DiegeticTravel, remains inspectable; do not alter that upstream mod as part of
this project.

## Verification at checkpoint

`$env:PYTHONPATH='src'; python -m unittest discover -s tests -v`

passes all 10 tests. The six current Papyrus scripts also compile with 0 errors
and 0 warnings.

`tools\Generate-Plugin.ps1 -LoreRimRoot D:\Lorerim` completed successfully.
The staged CFTO SHA-256 exactly matched the current `D:\Lorerim` source:
`17581B6A701A90F0F8DE71AB893B7D24F0BAA39E8B35B9522DF5FDC254B6710D`.
After the six-script compile and structural validation,
`tools\Build-Alpha.ps1 -PackageOnly` wrote
`dist\DiegeticTravel-alpha.zip` with SHA-256
`DA98AAF9FDE2FB9C4031EB477067C6132FA444E57F2B6D608B58003DAFFC1061`.
`Compress-Archive` includes fresh directory timestamps, so rebuilding the same
contents can change the ZIP hash; the ESP, SEQ, PEX, and runtime hashes are the
stable artifact checks.

## 2026-08-05 carriage beta checkpoint

- The LoreRim boarding path is intentionally removed. Live evidence showed the
  winning carriage reference cannot accept CFTO's missing custom seat link;
  the safe repair failed before payment.
- Clicking a parchment marker now revalidates the quote, resolves CFTO's own
  ground-level arrival marker, charges atomically, and immediately uses the
  boat-proven fade/encumbrance/`Game.FastTravel` sequence.
- The carriage sheet now uses fourteen exact Norden UI discovered-map symbols:
  nine unique capitals plus Town, Settlement, Farm, Wood Mill, and Mine. The
  project owner supplied direct permission from the Norden UI author. Sources,
  hashes, and attribution are retained under
  `assets/norden-interface/carriage-markers/` and `THIRD_PARTY_NOTICES.txt`.
- Eight Papyrus scripts compile with zero errors/warnings. The strict asset
  audit, isolated xEdit/SEQ audit, native CTest, ten Python tests, and no-launch
  `UltraDiegeticTravel` preflight all pass.
- The verified candidates are deployed only to the three existing isolated
  test mods. No MO2 profile file was changed. The next action is one live test:
  click a capital and minor-stop marker and confirm immediate travel, one
  payment, correct CFTO ground arrival, elapsed time, and paired direct-travel
  log lines.

## 2026-08-05 marker aspect and mainland ferry-landmark checkpoint

- The first Norden carriage build forced both SVG dimensions to 512 pixels,
  distorting non-square symbols before transparent padding. The builder now
  constrains width only, then alpha-crops, proportionally fits, and centers the
  result on a 512-square canvas. Runtime hitboxes remain collision-sized and
  independent of the artwork.
- Lake Ilinalta's original three-Honrich-anchor estimates are replaced by
  CFTO's exact shoreline arrival markers projected with the newer nine-point
  carriage parchment calibration: Brittleshin `(0.454414, 0.665229)`,
  Half-Moon Mill `(0.399755, 0.670970)`, and Guardian Stones
  `(0.501218, 0.685304)`.
- North-coast, Lake Honrich, and Lake Ilinalta now expose every other mainland
  waterway's docks as non-interactive grey landmarks. Active origins and
  destinations retain the boat/anchor interaction language.
- All nine changed boat scripts compile with zero errors/warnings. The shared
  parchment asset audit, native CTest, and all three isolated xEdit/SEQ audits
  pass. The owned LoreRim test mods are deployed; no MO2 profile file changed.
- Candidate package SHA-256 values: parchment picker
  `8A06341AAF8792DBA42C8A1B4E42F47E18DC27700F063F5DF7AC41A4BBE8D338`;
  Ilinalta `08A0283C8E21DAC87FFA951EE345BDD939F1063411187D8375D2B60BA1156F4B`;
  Honrich `06D8D54B116FBDD43C95298DBB216728CE4E3C9C297668878E8630310897A1D5`;
  North coast `43263F77FDDD2C23E7078A52D3BF4121CAFF714468200F66B84E02777A941C5D`.
- Remaining claim boundary: live-check one capital plus one generic carriage
  marker for aspect/cropping, then open one provider from each mainland boat
  network and verify the corrected Ilinalta placements and reciprocal grey
  anchors.

## 2026-08-05 beta route-artwork deferral checkpoint

- Mainland ferry maps now share the cleaner Lake Ilinalta beta presentation:
  no static chalk overlay and no activated authored route graph. They retain
  interactive anchors, current/destination boats, direct selection lines, and
  the reciprocal grey inactive-network anchors.
- The user-authored overlay PNG, conversion tool, and Honrich/North-coast
  geometry remain in the repository as post-release authoring sources. The DDS
  is absent from the runtime tree and package, and deployment removes any stale
  installed copy from the owned parchment test mod.
- The provider audits reject calls that reactivate `SetOverlayTexture` or the
  dormant route-network functions. Optional native overlay/segment APIs remain
  tested so future artwork can return without an architectural rewrite.
- Honrich and North-coast Papyrus compile with zero errors/warnings. The shared
  parchment audit, native CTest, and both isolated xEdit/SEQ audits pass.
- Candidate package SHA-256 values: parchment picker
  `792EBED6A5FB9A0A7080336836B727AD46F68030E362942994888A5CCAF0BCB9`;
  Honrich `5819E92CA88BB7944133EA0D5F5B1B706A0AB09B3A7713C2C744AFB866A27087`;
  North coast `830432532BE67A3BBE167D4A4A42ED4DCAD45E68DBF284959CEB1F2662C877E3`.
- Remaining claim boundary: live-open one Honrich and one North-coast provider
  and confirm the maps match Ilinalta's uncluttered direct-line presentation.

## 2026-08-05 icon-only maps and full carriage-endpoint checkpoint

- The shared native renderer now suppresses all dynamic route geometry for
  `boat` and `college` requests. Boat maps retain origin/destination boats and
  inactive grey dock landmarks. College selection keeps each destination's
  own location icon, enlarges the focused icon by 18%, and draws no red halo,
  selector icon, yellow spokes, or red route.
- Lake Ilinalta's Brittleshin coordinate is superseded by the visually
  corrected `(0.454414, 0.632000)`. The northward offset accounts for the
  anchor texture being centered while its map pin is the bottom tip. Ilinalta,
  Honrich, and North-coast providers all use the corrected point.
- Carriage beta quoting no longer removes valid CFTO endpoints when an active
  or unknown chokepoint is present. Hazards add their normal surcharge and the
  cheapest candidate remains selectable. Genuine endpoint gates (including
  unavailable Hearthfire destinations) remain enforced separately.
- `DNT_RouteService.EndQuoteBatch()` now retains its allocated typed arrays and
  resets only the logical count, eliminating the observed `None` to typed-array
  Papyrus cast errors.
- Verification passed: native build; parchment asset/source audit; native CTest
  1/1; Python compiler/evaluator tests 10/10; carriage, Ilinalta, Honrich, and
  North-coast xEdit/SEQ audits; carriage and North-coast validation-only MO2
  preflights. The wizard-only preflight is intentionally incompatible with the
  combined carriage profile because it demands the shared core ESP be disabled.
- Built/deployed artifacts match byte-for-byte. Candidate SHA-256 values: core
  `67B6582C81F728ED40F252EEDE222840AB9BBB73BC9C6DC9FA922327FCE4BCBE`;
  parchment `5DE187CF6832389FDABBE1FA2CA334E1B85F8C5EA658C8DF16FC9F91CB82BAB7`;
  carriage `0606159F79EEFDF6A6376493CB11B99CEAA01338AF71CD2DB238659561976EF1`;
  Ilinalta `5A4AE213C2A08F4D5B2B5605FED5228E542896E4785BAC6B220C9F8ECB6EA071`;
  Honrich `97244C9A97F7E0978E816BF574224AA8C33ED151D757D582B4A5953A19C8D821`;
  North coast `707D2631B8DFEBCCF882D0C90726A40F49CCF9A89C1FB2E01C6899145D5125B2`.
- No MO2 profile file or LoreRim baseline mod was changed. Remaining claim
  boundary: live-check the three presentations and confirm the expanded
  carriage sheet count from at least Winterhold and Falkreath.

## 2026-08-05 live map-presentation diagnosis and recalibration

- The live Lake Ilinalta request logged provider `Boat`, zero route segments,
  and no overlay. The visible yellow line was therefore not stale save data;
  it was the native renderer's case-sensitive comparison against lowercase
  `boat`. Provider presentation policy now compares `boat`, `college`, and
  `carriage` case-insensitively, and the audit rejects direct case-sensitive
  provider comparisons.
- Carriage capital art is 25% larger and non-capital stop art is 16% smaller;
  hitboxes are unchanged. Dawnstar moves north from `(0.570000,0.177000)` to
  `(0.570000,0.160000)` to cover the crest baked into the parchment.
- Brittleshin's anchor center moves farther north to
  `(0.454414,0.632000)` so the anchor's bottom tip, rather than its image
  center, lands on the calibrated shoreline point. Ilinalta and the inactive
  landmark lists in both other mainland boat providers share the value.
- Remaining claim boundary: live-check route-line suppression with the
  capitalized provider ID, Dawnstar coverage, marker size hierarchy, and the
  Brittleshin anchor tip.
- Offline verification passed: shared source/asset audit, native build and
  CTest 1/1, all affected Papyrus compiles with zero errors/warnings, Python
  compiler/evaluator tests 10/10, and carriage/Ilinalta/Honrich/North-coast
  xEdit/SEQ audits. Carriage and North-coast combined-profile validation-only
  preflights pass with the LoreRim BCD stack retained.
- Candidate package SHA-256 values: parchment picker
  `24C072A4631C78A86CABD80F4879B4AE4A5EB6131F2CBA4B4AD18A34478CB6DB`;
  carriage `D5C53F8CE9A455C9E9E2DD851BA382F71AFFC3FA51F8FF9FCE09197F2697454F`;
  Ilinalta `A8775C8CB32016EBA17538175D5D35EFEE1695A69AE37E95AAFEDE5C0AD1F5E8`;
  Honrich `1D9508E977D59EB831293405306769D7F4D8A02DE4C239FEB49253761C630999`;
  North coast `686F066DA1379338358AA43CB46ED124F42B94D57233F154F86CFD90C51A2E01`.
- Deployment touched only the existing isolated test mods. The deployed DLL
  and all four changed picker PEX files match their workspace builds
  byte-for-byte; no MO2 profile file or LoreRim baseline mod changed.

## 2026-08-06 live line-suppression and marker-calibration checkpoint

- Live evidence proves the provider-case repair: Ilinalta opened as provider
  `Boat` with `routeSegments=0`, `overlay=<none>`, and no visible yellow line.
  HUD hide/restore and Escape cancellation also completed cleanly.
- The `(0.454414,0.632000)` Brittleshin candidate is Rejected: it moved the
  anchor north of the desired shoreline. The next candidate restores the
  original affine projection `(0.454414,0.665229)`, moving it south.
- Capital/minor size hierarchy is visually accepted. From the 32:9 frame,
  Falkreath, Riften, and Windhelm remain offset up/left of their baked crests.
  Their next positions are respectively `(0.443000,0.792000)`,
  `(0.936000,0.828000)`, and `(0.823000,0.382000)`.
- Travel execution is Proven for Dawnstar to Morthal (200 gold) and Morthal
  to Winterhold (1250 gold); both emitted `CARRIAGE_TRAVEL_COMPLETE`.
- Remaining live gate: confirm the restored Ilinalta shoreline point and the
  three capital alignment corrections.
- Offline verification passed: four Papyrus targets compiled with zero
  errors/warnings; carriage/Ilinalta/Honrich/North-coast xEdit/SEQ audits;
  carriage and North-coast combined-profile preflights. All four deployed
  picker PEX files match the workspace builds byte-for-byte. No MO2 profile
  file or LoreRim baseline mod changed.
- Coordinate-pass package SHA-256 values: carriage
  `4894CBB7E97E719F7F1F87F009869DF2BD9316BA8EE068620D1039F2A1C3D914`;
  Ilinalta `08DBC4FA0CFCD829328DCA5DC23DAFE13715A103633DB990FA6CFCF057CA5735`;
  Honrich `F0FA68EBF9DD228B5814CAA4EFE14537BFA258D1F1E8344C2894722287E7FC72`;
  North coast `1CE578E02A7D1363BCEDBCB5DEA7700B854FF3263D6B6463BA267151A3597FED`.
