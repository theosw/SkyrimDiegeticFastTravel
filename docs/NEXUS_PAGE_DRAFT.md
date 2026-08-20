# Nexus page draft — Diegetic Fast Travel

> Draft only. Do not publish or upload the release archive until the private
> release checklist at the end of this file is complete.

## Initial page fields

**Mod name**

Diegetic Fast Travel

**Short description**

Morrowind-inspired fast travel through physical route maps. Ask carriage
drivers, ferrymen, and wizard guides where they travel, choose a destination,
pay the fare, and learn a connected network built around Skyrim's existing
services.

**Game**

Skyrim Special Edition

**Category**

Immersion

**Suggested initial version**

0.1.0-beta

## Long description

[center]
[size=7][b]DIEGETIC FAST TRAVEL[/b][/size]
[size=4][i]Learn the network. Plan the journey. Travel through the world.[/i][/size]
[/center]

[line]

[b]Diegetic Fast Travel[/b] replaces destination lists with physical route maps.
Ask a carriage driver, ferryman, or wizard guide where they travel, choose a
destination on their map, and pay their fare.

There is no universal menu: every service keeps its own destinations, prices,
and limitations. Learning those connections is part of travelling Skyrim.

[size=5][color=#d8b46a][b]THE NETWORKS[/b][/color][/size]

[list]
[*][b]Carriages:[/b] all 28 executable CFTO destinations, using configurable
distance-based fares and estimates plus CFTO's arrival markers and availability
rules.
[*][b]Ferries:[/b] Lake Honrich, Lake Ilinalta, the northern coast, and
Solstheim—including supported private and one-way landings.
[*][b]Wizard guides:[/b] a College of Winterhold hub connected to seven court
wizards and their hold capitals.
[/list]

[size=5][color=#d8b46a][b]FEATURES[/b][/color][/size]

[list]
[*]Interactive physical maps with mouse and controller support.
[*]Click/A to travel; Escape/B to cancel without being charged.
[*]Distinct indicators for return service and one-way destinations.
[*]Fares and availability rechecked before payment.
[*]Live CFTO private-ferry and Hearthfire availability.
[*]Optional Wait Carriage in Inns and Apparition Travel integration.
[*]One ESL-flagged ESP, one native SKSE plugin, and no JContainers dependency.
[/list]

[i]Speak to a supported provider, ask to see their route map, then select a
destination. Not every trip promises a ride back.[/i]

[size=5][color=#d8b46a][b]PRICING[/b][/color][/size]

[list]
[*][b]Carriages:[/b] direct-distance pricing from 50 to 400 gold with the public
defaults. Nearby trips are inexpensive; cross-country trips remain meaningful.
[*][b]Wizard guides:[/b] 250 gold per trip to or from the College hub.
[*][b]Ferries:[/b] CFTO's live local/regional/extra prices by default—normally
30/50/100 gold—with the return trip from Icewater Jetty free.
[*][b]Baan Malur optional file:[/b] its external service owns a fixed 30-gold
fare.
[/list]

Carriage coefficients, wizard fare, ferry overrides, estimate display, and the
preferred formal-versus-physical College/carriage artwork can be changed in
[b]SKSE/Plugins/DiegeticTravel.ini[/b]. Set
[b]PreferFormalMapArtwork=false[/b] to prefer the calibrated physical map
without changing your normal FWMF world map. Restart Skyrim after editing it.

[line]

[size=5][color=#d8b46a][b]REQUIREMENTS[/b][/color][/size]

[list]
[*][url=https://skse.silverlock.org/]SKSE64[/url] — built and tested with 2.2.6
for Skyrim 1.6.1170.
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/32444]Address Library
for SKSE Plugins[/url].
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/120352]SKSE Menu
Framework[/url].
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/8379]Carriage and
Ferry Travel Overhaul (CFTO)[/url].
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/40651]Carriage and
Ferry Travel Overhaul - Fixes and Winterhold[/url] 3.0 — install after the base
mod; this supplies the supported CFTO.esp record layout.
[/list]

[b]Initial beta target:[/b] Skyrim 1.6.1170 / SKSE 2.2.6.

[size=5][color=#d8b46a][b]RECOMMENDED MAP STYLE[/b][/color][/size]

The screenshots and my personal setup use these two map mods, but neither is
required:

[list]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/42614]RUSTIC
MAPS[/url] — recommended physical ferry-map artwork.
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/62705]Skyrim Paper
Map by Caro Tuts for FWMF[/url] — preferred wizard and carriage chart.
[/list]

Without them, ferry sheets use Bethesda's archived physical maps and wizard /
carriage sheets use a separately calibrated Bethesda battle-map layout. No map
DDS is redistributed by Diegetic Travel.

[size=5][color=#d8b46a][b]OPTIONAL INTEGRATIONS[/b][/color][/size]

[list]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/83044]Wait Carriage
in Inns[/url] — summoned drivers use the normal carriage parchment without a
compatibility ESP.
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/124125]Wizarding
Traversal Magic[/url] — Apparition Travel is soft-detected and supported
without making the mod a master.
[*][b]Baan Malur Merchant Ferries — separate optional file.[/b] Adds the Raven
Rock, Baan Malur, and Cormaris triangle plus one-way Sunmul service. Requires
[url=https://www.nexusmods.com/skyrimspecialedition/mods/114518]Journey to Baan
Malur and Morrowind[/url] and
[url=https://www.nexusmods.com/skyrimspecialedition/mods/137315]Solstheim and
Baan Malur Paper Map for FWMF[/url]. The main file does not require either.
For those three public captains, this file replaces Journey's parallel native
destination prompt; all other Journey captains keep their original dialogue.
[/list]

[line]

[size=5][color=#d8b46a][b]INSTALLATION AND COMPATIBILITY[/b][/color][/size]

[list=1]
[*]Install the requirements with your mod manager.
[*]Install Diegetic Fast Travel.
[*]Enable [b]DiegeticTravel.esp[/b] after [b]CFTO.esp[/b]. It is ESP-FE.
[*]Start a new game for the initial beta.
[/list]

Do not install old standalone Diegetic Travel development plugins beside the
consolidated release. Better Carriage Destinations intercepts the same selector
flow. LoreRim users should keep its complete BCD chain enabled and install the
separate [b]Diegetic Travel - LoreRim BCD Coexistence[/b] optional file after
the main plugin. Do not disable and re-enable BCD in the curated profile.

The coexistence patch suppresses BCD's competing carriage, ferry, and WCI
dialogue entries; it does not add BCD's broad map-marker destination universe
to Diegetic Travel.

Legacy travel dialogue is hidden by default. For conflict diagnosis, restore
it with:

[code]set DNT_ShowLegacyTravelDialogue to 1[/code]

[line]

[spoiler=Credits and asset disclosure]

[list]
[*]Bethesda Game Studios; the SKSE team; meh321; Thiago / SkyrimThiago; Kinaga.
[*]Gamwich — RUSTIC MAPS; Caro Tuts and Caites — Skyrim Paper Map for FWMF.
The recommended map textures are referenced, not redistributed.
[*]outobugi — [url=https://www.nexusmods.com/skyrimspecialedition/mods/49881]NORDIC UI[/url]
marker artwork; the SkyUI and SkyHUD teams are also credited in accordance with
its author instructions.
[*]Nithog — [url=https://www.nexusmods.com/skyrimspecialedition/mods/166086]Norden UI[/url]
round-trip selection symbol, used with direct permission.
[*]Sluia; Kittytail; shazdeh.
[*]pancake0723 and the Journey to Baan Malur team; Caites and Limon for the
optional add-on's source service and separately installed chart.
[/list]

Some bundled ferry marker artwork began as AI-assisted concepts and was
manually edited by the mod author in Krita. Third-party map artwork, Bethesda
voice files, and dependency binaries are not redistributed by this mod.
[/spoiler]

[size=5][color=#d8b46a][b]BUG REPORTS[/b][/color][/size]

Please include your runtime/SKSE versions, provider and destination, mouse or
controller input, whether it reproduces on a new game, and
[b]Documents/My Games/Skyrim Special Edition/SKSE/DNTParchmentPicker.log[/b].
Include a crash log for crashes.

## Suggested file-page copy

**File name**

Diegetic Fast Travel - 0.1.0 Beta

**File description**

Main consolidated beta. Includes the ESL-flagged DiegeticTravel.esp, native
parchment-menu runtime, Papyrus services, carriage catalogue, and permitted
marker assets. Install the requirements listed on the Description page first
and load DiegeticTravel.esp after CFTO.esp.

**Suggested changelog**

Initial public beta:

- Added physical parchment selectors for CFTO carriages and four ferry
  networks.
- Added the College-centred wizard-guide network and seven court-wizard spokes.
- Added mouse and controller selection/cancellation.
- Added configurable, public-balanced 50–400 carriage fares/estimates plus CFTO
  live ferry fares,
  private-service, Hearthfire, and destination-only gates.
- Added optional Wait Carriage in Inns integration.
- Added optional Wizarding Traversal Apparition Travel compatibility.
- Consolidated the release into one ESL-flagged ESP.

**Optional file name**

Diegetic Fast Travel - Baan Malur Merchant Ferries - 0.1.0 Beta

**Optional file description**

Separate ESP-FE for Captain Remyris and the public Journey to Baan Malur ferry
triangle, plus the verified one-way trip to Sunmul from all three public
captains. For those providers it replaces Journey's parallel native destination
prompt by default; all other Journey captains retain their original dialogue.
Requires the main Diegetic Fast Travel file, Journey to Baan Malur and
Morrowind, and Solstheim and Baan Malur Paper Map for FWMF. Do not install this
optional file without those dependencies. The main file does not require it.

## Suggested image set and captions

The first three images should communicate the complete mod without requiring
the viewer to read the description. Capture them from the final release
candidate at the same resolution, UI scale, weather/lighting profile, and map
zoom.

1. **Thumbnail and hero — wizard map.** Use the formal Caro Tuts map with the
   College and several capital spokes visible. Keep the cursor away from the
   title area. Suggested caption: “Learn the network. Plan the journey. Travel
   through the world.”
2. **Carriage map — selected minor destination.** Show a mix of capital and
   on-route markers with the centred trip/fare label. Suggested caption:
   “CFTO's carriage network, presented as a physical map.”
3. **Northern ferry map — one-way destination focused.** Include the ferry-map
   art, parchment markers, and one-way indicator. Suggested caption: “Every
   waterway keeps its own providers, fares, and limits.”
4. **Provider dialogue.** Frame the NPC and the single route-map prompt together.
   Suggested caption: “Ask an in-world provider where they can take you.”
5. **Lake Ilinalta map.** Show both ordinary and private/destination-only stops
   if the release-state test permits it. Suggested caption: “Local networks
   remain local—and a trip out does not always promise a trip back.”
6. **Solstheim ferry map.** Show Raven Rock, Tel Mithryn, Skaal Village, and a
   supported one-way landing. Suggested caption: “Distinct services for
   Solstheim's coast.”
7. **Wizard arrival or carriage arrival.** Use an attractive exterior shot
   immediately after travel so the gallery is not seven menu screenshots.
   Suggested caption: “Choose the route, pay the provider, and arrive in the
   world.”
8. **Controller video or short GIF.** Demonstrate focus movement, A-confirm,
   B-cancel, and mouse takeover. Suggested caption: “Full mouse and controller
   navigation.”
9. **Optional-file image — Baan Malur chart.** Keep this after the main-file
   gallery so it cannot be mistaken for a base requirement. Suggested caption:
   “Optional merchant ferries connect Raven Rock, Baan Malur, Cormaris, and
   one-way Sunmul service.”

### Thumbnail direction

- Use a 16:9 crop of the wizard or carriage map rather than a dialogue screen.
- Add only the mod title and short tagline; the map already supplies the visual
  detail.
- Place the title over low-detail ocean or parchment space, not over markers.
- Use warm parchment/off-white type with a restrained dark outline. Avoid bright
  Nexus orange inside the artwork; the site chrome already supplies it.
- Verify readability at small search-result size before uploading.

### Description-page image use

Keep the public BBCode mostly textual and use Nexus's image gallery for the
full screenshot set. If a banner is embedded in the description, use only the
hero image beneath the title. Repeating every gallery image in the description
will make the requirements and compatibility information harder to scan.

## Private pre-publication checklist

Do not copy this section to the public Nexus description.

- [ ] Complete the release-blocking state-gated test matrix on the consolidated
  build: locked/unlocked private ferries and Hearthfire destinations.
- [ ] Complete one uninterrupted Apparition off → on → off test, proving normal,
  zero, then restored-normal time passage.
- [ ] Reverify configured paid/free carriage fares and all nine physical drivers.
- [ ] Reverify controller focus, A-confirm, B-cancel, and mouse takeover with the
  intended controller stack.
- [ ] Measure and accept first-open carriage-menu latency.
- [ ] Run a fresh-game, existing-clean-save, save/reload regression.
- [ ] Verify the exact public requirement version/file for SKSE Menu Framework.
- [ ] Verify the current Nexus Skyrim Paper Map release uses the texture/crop
  expected by the UI; the development lock used the installed 1.72 artwork.
- [ ] Decide whether the first public build officially supports only 1.6.1170.
- [ ] Confirm `THIRD_PARTY_NOTICES.txt` is present in the final ZIP and contains
  the NORDIC UI marker-art credit/open-permission record, the separate Norden UI
  selection-ring credit/direct-permission record, and the AI-assisted-asset
  disclosure.
- [ ] Choose Nexus permissions for translations, patches, asset reuse, uploads,
  and Donation Points; do not infer these from dependency permissions.
- [ ] Upload final screenshots captured from the release candidate rather than
  older modular development builds.
- [ ] Rebuild the final ZIP from a clean tree, rerun package audit, and record its
  SHA-256 on the private release checklist.
- [ ] Keep the page unpublished until all release-blocking items pass.
