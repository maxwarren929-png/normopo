# Normanhurst's own opening region

The game now starts inside the player's house, not the development room. Only selected remastered layouts are used: a cropped Pallet Town exterior for Home Suburb and a cropped Route 1 for Bush Track. These are adapted into our transport-sabotage region, not named or connected as Kanto.

## Current playable area

| Map | ID | Source |
| --- | --- | --- |
| Home Suburb | 200 | Remastered Pallet layout, cropped 24×20 |
| Your house | 201 | Preserved opening interior/events |
| Ms Harman's lab | 202 | Preserved opening interior/events |
| Home Suburb Station | 203 | Preserved Cherubi-based station and story events |
| Bush Track | 204 | Remastered Route 1 layout, cropped 24×40 |
| Development room | 1 | Existing gacha, Gym challenges, PC unchanged |

New Game starts at house `[3,8]`. Talk to Mum, visit Ms Harman, choose a starter, battle the rival and collect supplies/research notes. The station cancellation and fake-maintenance-worker signal incident reuse the existing Ozerim story logic. Reporting back to the professor remains the end of this opening segment. Bush Track has provisional level-2–4 Pidgey, Rattata and Caterpie encounters.

The next town, Max's story Gym, working passenger transport and later chapters are not built yet. Gym challenges in the development room remain tests, not story badges. The interiors/station retain their older prototype layouts and signs; this is a functional opening, not final mapping polish.

## Existing saves and development features

Existing saves are not reset or migrated automatically. A save in the development room can choose **Menu → Story opening** to enter the house. On an opening map, **Menu → Development room** returns to the existing test room. These debug transfers intentionally bypass the lab travel gate. Normal town-to-station and station-to-track events still enforce their story prerequisites.

Existing Pokémon, gacha counters, gifts and Ozerim flags are preserved. Starting the story with an existing level-50 development party does not rebalance the rival or grunt, and a full party must make room for the starter. Use the development PC if needed. A fresh save is the intended opening experience; it does not overwrite an older save unless the player saves over it.

## Safe integration

`tools/import_normanhurst_opening.py` reads the preserved story-map backup and the downloaded pack, remaps transitions to 200–204 and writes only Normanhurst map/PBS data. Map 1 is retained. It does not run either old story generator and does not edit Hornsby, Demo map sources or the imported Essentials base.

Exterior tileset 26 and station tileset 27 are appended to a private complete `normanhurst/game/Data/Tilesets.rxdata` overlay. The compiler now validates this overlay and uses it for map-reference checks. Imported exterior graphics use `CLI-Remastered-*` names. New namespaced graphics are shared files, but only Normanhurst's private tileset/maps reference them. No pack MapInfos or map-connections file is copied, and no existing tileset IDs are replaced. All connections are explicit event transfers.

Map metadata and encounters are edition-only overlays based on the preserved base files. The old Cherubi map-76 hook remains untouched; station 203 has its own proper tileset record instead.

Source archive/hash, resource terms and contributor credits are recorded in `remastered-map-pack-import.md` and `remastered-credits-followup.md`. Full associated graphics credits are included in `CREDITS-Remastered-Maps.txt`; pack music is not imported. These fan resources are not MIT relicensed and no commercial or unrestricted standalone-asset redistribution permission is claimed.

## Checks and limits

All five maps compiled and loaded in the isolated native runtime. Fresh startup from house 201 passed. Reachability checks passed for the house/lab approaches, town doors/station path, station staff/colleague/track approach and Bush Track story-event approaches. Native house, town, station and track screenshots were inspected. The static layout renderer uses Essentials' exact 48 autotile patterns, not guessed atlas offsets.

The native probe intercepts dialogue and moves between maps. It does not prove the complete rival/grunt story sequence, manual doorway interaction, wild encounters or browser/Safari startup. No new full-story or physical-device playthrough is claimed. The prototype signs and time-of-day outdoor tint remain visible in the screenshots.
