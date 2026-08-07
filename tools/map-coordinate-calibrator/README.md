# DNT Map Coordinate Calibrator

Local developer tool for placing parchment-menu markers in the exact normalized
coordinate space used by `DNTParchmentPicker`.

## Start it

From this directory:

```powershell
npm run sync
npm run dev
```

Open `http://localhost:3000`.

`npm run sync` copies the current carriage, mainland ferry, Lake Honrich, Lake Ilinalta,
Solstheim ferry, and wizard-map networks; converts the exact in-game DDS marker
textures to browser previews; and builds local reference images from the RUSTIC
MAPS and Skyrim Paper Map sources plus the installed Solstheim and Baan Malur
chart. The Solstheim tabs include both the square-corrected physical ferry map
used by the local ferrymen and the regional chart used to author Captain
Remyris's merchant route. These generated assets are ignored by Git and must
not be redistributed.

## Calibrate

1. Choose **Carriage network**, **Wizard guides**, **Mainland ferries**,
   **Lake Honrich**, **Lake Ilinalta**, **Solstheim ferries**, or
   **Remyris merchant route**.
2. For carriage or wizard maps, switch between **Norden** and **Vanilla** icon
   previews without changing coordinates.
3. Enable **Authoring-only locations** to place one-way, quest-locked, broken,
   or otherwise incomplete stops. They are styled separately and exported under
   `authoring_positions`; the tool never folds them into the playable `stops` list.
4. Drag markers or the payment label into place. Select one and use the arrow
   keys for one-pixel nudges; hold Shift for ten-pixel nudges.
5. Read or type normalized X/Y values in the inspector. X grows left-to-right;
   Y grows top-to-bottom.
6. Use **Copy changed patch** for a small reviewable JSON patch, or download a
   complete updated network JSON.

Draft positions are stored only in this browser. The tool never edits the mod
or deploys to LoreRim by itself.
