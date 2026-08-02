# Parchment-picker design ledger

Status: core interaction and the original five routes are gameplay-proven in the isolated
`UltraDiegeticTravel` profile; the ASCII footer, funded Solitude/Markarth paths,
and multi-menu HUD lifecycle are gameplay-proven. The corrected crop, five
crest centers, Winterhold origin, and route behavior are also visually proven.
The stronger gold/red visibility treatment and Norden-style monochrome cursor
are now gameplay-proven. No-default-focus startup, the translucent cursor
center, and Escape cancellation are also gameplay-proven. Dawnstar and Morthal
form the current seven-route offline candidate and remain visually unproven.

Candidate artifacts:

- `DiegeticTravelWizardParchment.esp` SHA-256
  `90DB9BF3FFE1823D0403D4739BF694B8FACC89E498276C66363C5E3C4D760E0B`;
- `DNTParchmentPicker.dll` SHA-256
  `506A373F5899D13C519F44E992755296BA28D2866483F0895979F6C83F1025CF`;
- `dist/DiegeticTravelParchmentPicker-offline-candidate.zip` SHA-256
  `3335140DEAD3319BFC5E2E202A6AF65AD555D38DA182C867615082E61769D83B`.

## Accepted architecture

The reusable UI is a provider-neutral selection frontend. Wizard guides,
carriages, and later travel pillars provide their own allowed destinations and
interpret the returned index. Their existing service layer remains responsible
for payment, time, route rules, and movement.

This preserves the live-proven wizard service and avoids coupling the new UI to
Better Carriage Destinations or Skyrim's native MapMenu.

## Asset policy

Prototype and release integrations may reference a separately installed map or
sound dependency. Third-party assets are not copied into this repository,
package, or download. The provider exposes a configurable path and aspect ratio
so another mod manager dependency can supply the file. Licence and attribution
requirements still need to be recorded for each selected dependency before a
public release page is written.

The first local proof references LoreRim's already-enabled RUSTIC MAPS texture
at `Data/textures/dungeons/imperial/battlemap01.dds`. Source inspection places
the ragged parchment edge at row 3016 of 4096. The provider-owned crop is now
`(0,0)-(1,0.736328)` with aspect `1.358090`, excluding the opaque backing strip
that the prior 0.75 crop exposed. Five corrected destination coordinates are
gameplay-proven; Dawnstar `(0.570,0.177)` and Morthal `(0.402,0.298)` extend the
same normalized contract and await visual proof. The optional Winterhold route
origin targets its printed crest. The installed
4K texture remains outside the repository and candidate archive; its local-test
SHA-256 is
`C77E6B93129577CD23C6AC733310A5EA6A028F4BE00B472F9AA62018C4C239F8`.
Gamwich's page says not to repurpose or repost the textures without permission,
so this is local-test evidence only until release permission is clarified:
https://www.nexusmods.com/skyrimspecialedition/mods/42614

## Framework evidence

The implementation was based on the public dynamic interface demonstrated by
SKSE Menu Framework 3. The local source inspection was pinned to framework
commit `3a65dc0147388da177c324cff4d89d9e25094623` and example commit
`974e82a094b16c4e5469a0d2189b2caff3f9742a`. Only the original module's small
ABI wrapper is tracked; the downloaded upstream repositories remain under the
ignored `.tools` directory.

LoreRim's installed framework file is labelled 3.9.0, while the dynamic API
reported framework version `3.7` in the successful runtime log. The picker
limits itself to the established v3 window, input, texture, and basic ImGui
exports, all of which resolved successfully. Record both observations rather
than treating the packaging label and runtime API value as interchangeable.

## Evidence levels

- Source-backed: framework exposes blocking windows, input callbacks, and
  conventional image textures.
- Offline-proven: request validation, destination uniqueness, normalized
  coordinates, provider-specific art ratios, and centered 16:9/21:9/32:9
  layout math.
- Build-proven: the AE DLL builds cleanly; all three Papyrus scripts compile
  with zero errors and warnings; every dynamically used export exists in
  LoreRim's installed SKSE Menu Framework DLL; the generated ESP is
  byte-idempotent and passes its independent headless-xEdit audit.
- Gameplay-proven: dialogue-to-window timing after the compatibility reload,
  RUSTIC texture/crop and marker alignment at 32:9, mouse selection, button
  cancel, result-event handoff, funded Whiterun travel, and underfunded
  Whiterun/Solitude denial. Later passes proved the ASCII footer, funded
  Solitude/Markarth travel, and exact hide/restore of 12 LoreRim HUD movies.
- Still pending: Dawnstar/Morthal crest alignment, the replacement Morthal
  carriage-marker arrival, controller-B
  cancellation, keyboard/controller destination activation, missing-art
  fallback, and the seven-choice dialogue fallback.

The final package audit reports zero bundled artwork/audio assets. Champollion
readback confirms the provider PEX embeds the configurable default texture path
and aspect ratio, preserves capitalized display labels, and maps selection
indices back to the seven lowercase service IDs.

## Existing-save compatibility

On the first live install, the new top-level dialogue branch did not appear
until the user saved and reloaded once with the adapter installed. Stopping and
starting its quest did not fix the same session. This matches the documented
custom-dialogue save/load workaround on the Creation Kit Wiki discussion:
https://ck.uesp.net/wiki/Talk%3ABethesda_Tutorial_Dialogue

If the travel-map prompt is missing after installation, save and reload once.
This is a compatibility instruction, not a license to reset the service quest
or discard serialized travel state.

## Presentation lifecycle

ASCII ` - ` replaced the prior em dash because that character rendered as `?`
through the UI font/string path; the corrected footer is live-proven.

The first native HUD revision saved and toggled only the vanilla `HUD Menu`
movie's visibility. Runtime logs proved both calls executed, but a screenshot
still showed LoreRim's bottom-left player bars and widgets. Local configuration
inspection explains the result: Norden enables TrueHUD's custom player widget,
and LoreRim's Ultimate Immersion Toggle manages separate `TrueHUD`,
`lvlWidget`, `goldWidget`, STB, and related Scaleform movies by changing
`_root._alpha`.

The replacement treats those names as optional compatibility targets. For
each present movie it saves both `GetVisible()` and numeric `_root._alpha`,
hides it, and restores the exact values on all completion paths. Missing movies
are skipped, and no installed-mod settings are changed. A monitored pass
visually proved the hidden HUD and logged all 12 present layers restoring from
the exact saved values before successful Markarth travel.

The picker uses invisible hitboxes over the map's baked city crests. The first
small-ring coordinates missed several crest centers and are rejected. The
corrected five coordinates, exact crop, Winterhold origin, five spokes, and
hover/selection behavior passed a 32:9 gameplay pass: the user confirmed that
everything was in the right spot and successfully selected routes. The same
pass found the subdued idle routes difficult to see and the yellow custom
pointer unlike the rest of LoreRim's UI.

The live-tested visibility revision enlarges each visible ring to 46% of its hitbox, uses
strong gold for every idle ring and route, and changes only the hovered or
controller-focused destination and route to red. Mouse activation remains
release-inside, so a press-drag outside safely cancels that activation.

Local inspection identifies LoreRim's active cursor as Norden's
`Interface/cursormenu.swf`. It is a Scaleform movie rendered before Menu
Framework's ImGui layer; the framework API can choose ImGui/Windows cursor
shapes but cannot reuse that SWF above the parchment. The candidate therefore
draws a matching monochrome arrow silhouette and palette with framework
polyline and concave-fill primitives. No cursor file is copied or shipped. The
The monitored pass visually approved the gold/red presentation and confirmed
the new monochrome cursor. It logged one clean cancel followed by a successful
Markarth selection/trip, restored all 12 HUD layers exactly, and emitted no DNT
error or warning.

The apparent initial Whiterun highlight came from an explicit
`SetItemDefaultFocus` call and did not represent a selected destination. The
current candidate removes that call and gates visible navigation focus until a
keyboard/gamepad button is actually pressed, while mouse hover remains
immediate. It also changes the cursor's dark-center alpha from 245 to 150 so
more parchment shows through. The native/Papyrus/xEdit/asset/test suite passes,
and all six deployed runtime payloads match the workspace. Its non-launching
`UltraDiegeticTravel` preflight passes after switching back from the parallel
profile. In the monitored pass, the user confirmed the no-default startup and
translucent cursor looked good. Markarth parchment travel and Calcelmo's direct
College return completed, then separate parchment opens proved Escape and
close-button cancellation. Every completion restored all 12 HUD layers exactly
and no DNT error/warning appeared.

Controller navigation and B cancellation are intentionally deferred while the
two controller mods are disabled. Revisit them only with the intended
`No Delete Controller` compatibility layer enabled so the result represents
the actual release stack.

The controller implementation checklist is intentionally recorded now without
changing the proven mouse path:

- preserve no-default-focus behavior until the first navigation input;
- move focus among provider destinations without synthesizing mouse hover;
- confirm only the currently focused destination;
- map controller B to the same inert cancel result as Escape/close;
- never remove or replace LoreRim's controller object;
- test focus, confirm, cancel, dialogue fallback, and HUD restoration with the
  intended compatibility stack enabled.

## Presentation layer

The parchment itself and Mirabelle's spoken/subtitled lead-in are proven
independently. The current offline candidate exposes a provider-neutral
presentation API and returns a measured voice window before entering the same
picker. This keeps a future vanilla showing idle or custom folded-map prop
separate from selection and travel authority. See
`docs/PRESENTATION_CONTRACT.md` for the exact boundary and remaining live test.
