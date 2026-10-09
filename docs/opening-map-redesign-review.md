# Opening map redesign

The user approved publication after reviewing the local screenshots. This release includes the compact maps and retains the Mr Lin/Mr Howel Elite Four duo.

## What changed

- House 201 now has a bounded 12×9 room on a 16×12 canvas, not floor extended across a 20×15 map. The existing kitchen/dining artwork is retained, the unused demo stairs are removed and a bed/bookshelf nook is added. Mum stands beside the kitchen rather than on the dining rug/table.
- Lab 202 has a bounded 13×11 room on a 16×12 canvas. Two empty rows are removed. Equipment, shelf banks, starter table, plants and exit mat remain. NPCs/balls are remapped to actual floor/table positions. The rival has distinct overworld art and matching RIVAL1 battle type only in Normanhurst's map 202; other editions retain their previous trainer type.
- Both indoor canvases exactly match the game's 16×12-tile viewport. SnapEdges now holds the camera still, so it cannot crop the back walls when the player stands near the exit.
- Station 203 is 22×16 rather than 32×24. Its complete credited Cherubi facade and wagon remain, surrounded by the same remastered grass/gravel family used outside. A single bordered forecourt, two-tile north approach, yellow platform edge, siding, bench and physical boards replace the broad flat paving field.
- Home/rival house doors use matching purple door sprites. Both sides of the lab's opening use glass doors. All floating Entrance HOME/LAB/OUT/STATION/TRACK/TOWN labels are removed from maps 200–204. The welcome sign is an actual wooden sign beside the houses.
- Incoming positions, indoor exits, station/track transfers, New Game start `[201,5,9]` and development-room story access are adjusted together. Map 1, gacha, Gym challenges and PC events are unchanged.

The black area outside an interior is deliberate RPG room framing. The old generator incorrectly replaced that opaque void tile with floor, causing the empty-room appearance. It is not walkable space and is no longer shown as an oversized floor.

## Files and regeneration

`tools/redesign_normanhurst_opening.py` handles these bounded layouts and remapped events. `tools/import_normanhurst_opening.py` calls it after the raw remastered import, so regenerating no longer restores the rejected prototypes. Source room fragments are read from imported Essentials Maps 003/004; no original source map or shared old graphic is overwritten.

Station graphics use a new `CLI-Normanhurst-Station.png` atlas and private tileset 27. Existing `Home Suburb Station.png`, Cherubi map-76 hook and base tilesets are unchanged. `CLI_Field_Sign.png` copies the real remastered wooden-board artwork; `CLI_Map_Interaction.png` is a transparent named event frame for wall-mounted/tile-backed interactions. A named frame is necessary because an empty-graphic Essentials event otherwise uses under-player interaction, making a blocked wall/sign inaccessible from in front.

Original contributor credits remain applicable. No art is relicensed. The station rail/fence/bench fragments remain the original locally drawn assets from the earlier station assembly.

## Review evidence

Screenshots and full-layout previews are in `normanhurst/build/map-redesign-review/`. The `native/` subdirectory contains actual 512×384 native frames and `report.json`. `opening-*.png` are untinted static layouts with event sprites; they are not substituted for runtime screenshots. The review probe fixes time to noon only in the disposable runtime, not in the real game.

Native startup, room framing and approach reachability passed. The probe also physically walked into and out of the house and lab, confirming actual event transfers rather than only checking adjacent passability. Story dialogue is intercepted and no rival/grunt battle is exercised. Full story progression and browser gameplay are not claimed.

On Continue, Normanhurst opening maps 200–204 are reloaded from the new authored data, even if the engine's magic number matches. This avoids keeping old serialized map events and dimensions. A valid walkable saved position is retained; a blocked or out-of-bounds position is moved to that map's safe entry. Old lab `[6,12]` and station `[15,21]` positions were checked through the real Game.load_map hook, and a valid house position was preserved. Party, story flags and other save data are not reset.

The Tilesets overlay now lives in a real edition-private Data directory, not through the historical shared Data symlink. Shared animation links remain intact, and the temporary appended Tilesets file was removed from Demo's overlay. Base Essentials tilesets are unchanged.

The previous desktop game window is an isolated older snapshot and does not update live when these sources change. Reload the website to obtain the new package. Full story/battle and physical Safari checks remain outside this map review.
