DNT Parchment Picker - development spike

This payload contains no background map artwork. The College and carriage
providers prefer the separately installed Skyrim Paper Map by Caro Tuts for
FWMF texture:

  Data/textures/terrain/tamriel/skyrim.dds

It displays the illustration crop (0.088379,0.187012)-(0.932129,0.783691) of
that 8192-square texture at aspect 1.414075. If the file is absent, the picker
loads Bethesda's archived `battlemap01.dds` through Skyrim's resource stream
and switches to its 1.35809 aspect, UV crop, and affine marker/text transform.
Boat providers use the same archive bridge when no loose physical-map replacer
is installed. The core parchment flow has passed its first gameplay test. The
old dialogue destination menu is retained only behind the default-off
diagnostic compatibility global.

The current revision hides vanilla, TrueHUD, and common LoreRim widget movies
while the parchment is open, restores each movie's previous visibility and
root alpha on close, and uses an ASCII hyphen in the fare footer. Destination
icons use collision-aware invisible hitboxes. Boat and College providers draw
no dynamic route lines for the beta. Boats communicate focus with their boat
icon and subtle halo; the College keeps each location's vanilla-derived icon
and enlarges the focused icon slightly, without a red selector halo or icon
swap. An asset-free monochrome pointer drawn with Menu Framework primitives
resembles LoreRim's active Norden cursor. Its dark center is translucent so the
map remains visible beneath it. Opening the map starts with no active focus;
mouse hover activates one immediately, while keyboard/controller focus becomes
visible only after keyboard/controller input. No cursor artwork is copied or
shipped. The College provider exposes seven destinations: the five previously
gameplay-proven capitals plus Dawnstar and Morthal.

Ordinary College faculty reuse Skyrim's genuine OfCourse SharedInfo and its
voice-type-specific FUZ. Mirabelle's unique voice has no matching asset, so her
mutually exclusive exact-speaker response displays the same "Of course."
subtitle without fake audio or an added wait. Both terminal responses open the
map from OnBegin and contain no submenu link. The static seven-destination
College request is assembled in one native call to avoid repeated Papyrus/native
scheduling stalls.

Requires the user's separately installed Skyrim/SKSE/Address Library, SKSE Menu
Framework, and DiegeticTravelWizardGuides.esp. RUSTIC MAPS and Skyrim Paper Map
by Caro Tuts for FWMF are recommended visual overrides, not requirements.
`PreferFormalMapArtwork=false` in DiegeticTravel.ini prefers the calibrated
physical College/carriage profile without modifying FWMF. This package excludes
the deferred ferry-route artwork for the beta. It includes
AI-assisted/user-edited Docks and Ship markers, nine vanilla-derived hold-capital markers, and one
vanilla-derived neutral town marker. It also includes fourteen exact NORDIC UI
discovered-map symbols for carriage destinations under outobugi's published
open-art permission, plus the exact Norden UI round-trip
loading symbol used as the formal-map selection ring. The
previously evaluated custom wizard markers and Dragonborn Reskin - Wheeler icon
are not bundled. The package includes no background map artwork, voice asset,
or dependency binary.
