Diegetic Travel — consolidated beta

Requirements:
- Skyrim Special Edition / Anniversary Edition 1.6.1170
- SKSE64 2.2.6
- Address Library for SKSE Plugins
- SKSE Menu Framework
- Carriage and Ferry Travel Overhaul (CFTO)
- RUSTIC MAPS (physical carriage/ferry parchment artwork)
- Skyrim Paper Map by Caro Tuts for FWMF (wizard parchment artwork)

Plugin layout:
- Enable DiegeticTravel.esp after CFTO.esp.
- DiegeticTravel.esp is an ESL-flagged ESP (ESP-FE) and does not consume a
  full load-order slot.
- Do not enable the old DiegeticTravelWizardGuides,
  DiegeticTravelWizardParchment, DiegeticTravelCarriageParchment, or
  DiegeticTravelBoat* development plugins beside this release.

The consolidated beta includes the College wizard-guide star, physical wizard
and carriage parchment menus, and the supported Lake Honrich, Lake Ilinalta,
north-coast, and Solstheim ferry services. A separately downloadable Baan Malur
ESP-FE can add Captain Remyris's merchant network when Journey to Baan Malur
and its external FWMF chart are installed; neither is required by this main
file. The legacy Better Carriage Destinations wizard adapter is not included.

Because this release consolidates records that previously lived in several
development plugins, begin testing on a new/disposable save. Existing saves
that have seen the modular development plugins are not a valid migration test.

Map artwork remains supplied by its separately installed dependency; this
package contains only the code and permitted/derived marker assets described
in THIRD_PARTY_NOTICES.txt.

Configuration:
- SKSE\Plugins\DiegeticTravel.ini controls carriage price/time coefficients,
  the College fare, optional CFTO ferry-fare overrides, and carriage estimate
  display. It is read once when Skyrim starts, so restart after editing it.
- Missing or invalid individual values keep safe defaults. By default ferries
  continue to follow CFTO's live local/regional/extra fare globals.
- The optional Baan Malur add-on retains its externally owned fixed fare.
