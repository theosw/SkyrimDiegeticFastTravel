# Nexus page draft — Diegetic Fast Travel

> Draft only. Do not publish or upload the release archive until the private
> release checklist at the end of this file is complete.

## Initial page fields

**Mod name**

Diegetic Fast Travel

**Short description**

Physical route maps for CFTO carriages and ferries, plus College wizard travel.
Choose a destination, pay the fare, and learn Skyrim's travel network.

**Game**

Skyrim Special Edition

**Category**

Immersion

**Suggested initial version**

0.1.0-beta

## Long description

[center]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1786766424-389268771.png[/img]
[/center]

[b]Diegetic Fast Travel[/b] replaces CFTO destination lists with physical route
maps. Ask a carriage driver, ferryman, or wizard guide where they travel. Pick a
marked destination and pay the fare.

Each service has its own routes and limits. A trip out may not include a trip
back.

[size=5][color=#d8b46a][b]What it adds[/b][/color][/size]

[list]
[*]The CFTO carriage network with distance based fares from 50 to 400 gold.
[*]Ferries on Lake Honrich, Lake Ilinalta, the northern coast, and Solstheim.
[*]Wizard travel between the College of Winterhold and seven hold capitals.
[*]Mouse and controller support. Click or A confirms. Escape or B cancels.
[*]Separate markers for return service and one way destinations.
[*]Live CFTO support for private ferries and Hearthfire carriage drivers.
[/list]

[center]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1787085681-997650187.png[/img]
[/center]

[spoiler=More route maps]
[b]Carriages[/b]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1786742699-1278707588.jpg[/img]

[b]Wizard guides[/b]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1786742715-462209272.jpg[/img]

[b]Mainland ferries[/b]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1786742780-258136289.jpg[/img]

[b]Solstheim ferries[/b]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1786742803-1336878116.jpg[/img]

[b]Baan Malur optional file[/b]
[img]https://staticdelivery.nexusmods.com/mods/1704/images/188221/188221-1786742816-1439779460.jpg[/img]
[/spoiler]

[line]

[size=5][color=#d8b46a][b]Requirements[/b][/color][/size]

[list]
[*]Skyrim 1.6.1170
[*][url=https://skse.silverlock.org/]SKSE64 2.2.6[/url]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/32444]Address Library for SKSE Plugins[/url]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/120352]SKSE Menu Framework[/url]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/8379]Carriage and Ferry Travel Overhaul[/url]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/40651]CFTO Fixes and Winterhold 3.0[/url]
[/list]

[size=5][color=#d8b46a][b]Recommended maps[/b][/color][/size]

These are the maps shown in the screenshots. They are not required.

[list]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/42614]RUSTIC MAPS[/url] for ferry maps.
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/62705]Skyrim Paper Map by Caro Tuts for FWMF[/url] for carriage and wizard maps.
[/list]

Without them, the menus use calibrated maps from Skyrim's archives. Diegetic
Fast Travel does not include either map texture.

[size=5][color=#d8b46a][b]Optional support[/b][/color][/size]

[list]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/83044]Wait Carriage in Inns[/url]
[*][url=https://www.nexusmods.com/skyrimspecialedition/mods/124125]Wizarding Traversal Magic[/url]
[*][b]Baan Malur Merchant Ferries[/b]. The separate optional file requires
[url=https://www.nexusmods.com/skyrimspecialedition/mods/114518]Journey to Baan Malur and Morrowind[/url] and
[url=https://www.nexusmods.com/skyrimspecialedition/mods/137315]Solstheim and Baan Malur Paper Map for FWMF[/url].
[/list]

[size=5][color=#d8b46a][b]Installation[/b][/color][/size]

[list=1]
[*]Install the requirements.
[*]Install the main Diegetic Fast Travel ZIP with your mod manager.
[*]Load [b]DiegeticTravel.esp[/b] after [b]CFTO.esp[/b].
[*]Start a new game for the beta.
[/list]

[size=5][color=#d8b46a][b]Compatibility[/b][/color][/size]

LoreRim users should keep Better Carriage Destinations enabled and install the
[b]LoreRim BCD Coexistence[/b] optional file after the main file. Do not disable
BCD in the curated profile.

The coexistence file hides the three BCD prompts that compete with these route
maps. It does not add BCD's unrestricted destination list.

To restore the original travel dialogue for testing, enter:

[code]set DNT_ShowLegacyTravelDialogue to 1[/code]

[spoiler=Credits and asset notes]
[list]
[*]Bethesda Game Studios, the SKSE team, meh321, Thiago and SkyrimThiago, Kinaga, Sluia, Kittytail, and shazdeh.
[*]outobugi for [url=https://www.nexusmods.com/skyrimspecialedition/mods/49881]NORDIC UI[/url] marker artwork. The SkyUI and SkyHUD teams receive upstream credit.
[*]Nithog for the [url=https://www.nexusmods.com/skyrimspecialedition/mods/166086]Norden UI[/url] selection symbol, used with direct permission.
[/list]

Some ferry markers began as AI assisted concepts and were edited by the mod
author in Krita. External map textures, voice files, and dependency binaries
are not included. Full notices are in [b]THIRD_PARTY_NOTICES.txt[/b].
[/spoiler]

[size=5][color=#d8b46a][b]Bug reports[/b][/color][/size]

Include your Skyrim and SKSE versions, the provider and destination, your input
method, and [b]DNTParchmentPicker.log[/b]. Include the crash log if Skyrim
crashed.

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
