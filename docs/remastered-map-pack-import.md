# Remastered Kanto and Johto map pack review

Reviewed Eevee Expo resource #828, version 3. The resource page links to this MEGA file:

- Resource: https://eeveeexpo.com/resources/828/
- Version download redirect: https://eeveeexpo.com/resources/828/version/2481/download
- Final archive URL: https://mega.nz/file/tKIhCRJK#WCAWAmrKbXaMvTJWDLsAUMz_h0K_hqN4onlPq2BMcvA
- Local archive: `demo/build/remastered-map-pack-review/Remastered Kanto Johto Map Packv1.7z`
- SHA-256: `0ec75515960c8ce8a5b415afb6698ceb3ad141448f0196f8659c3bcf6e436db2`

The archive is an 8,330,075-byte 7z file, not ZIP. Its listing had 199 entries. Before extracting, I rejected absolute paths, `..` path components and entries marked as links. Extraction stayed under `demo/build/remastered-map-pack-review/extracted/`. No game files were changed, no map was imported, and no build or publish was run. The downloaded source archive and hash are retained there.

## Contents and map data

There are 152 map files, IDs 2 through 153, plus `MapInfos.rxdata`, `map_connections.dat`, `Tilesets.rxdata`, graphics, music and `PBS v16 - v21` files. The parsed inventory is `demo/build/remastered-map-pack-review/map-inventory.csv`, generated with the repository's bounded Ruby Marshal reader. Each row records ID, map name, width, height and tileset ID. The pack uses tileset IDs 21-24, matching the resource instructions. IDs 35, 41, 53, 60-70, 72-76, 153 and other `MAPnnn` entries are placeholders/organizing maps, not useful story candidates.

Useful first-pass candidates for the Ozerim transport-sabotage plot:

- **Coastal arrival / harbor:** map 28 Vermilion Port (53x26, TS21), map 59 Vermilion City (53x48, TS21), map 94 Olivine Marina (56x67, TS24), maps 144 Goldenrod Sea Path (148x47, TS23) and 145 Olivine Sea Path (48x148, TS23).
- **Port town option:** map 97 Whiteport Town (54x40, TS23), a beta/lost Johto port town per the resource description.
- **Rail/station adaptation:** map 83 Goldenrod City (64x47, TS23) is the strongest urban base to inspect for a station-area adaptation; the pack does not identify a dedicated station map in its names. Do not assume a train or station is already mapped without visual inspection.
- **Woodland approach:** map 89 Ilex Forest (120x86, TS23), map 12 Viridian Forest (76x80, TS21), or route 35/36/37 (IDs 114/116/117; TS23). These are candidates, not confirmed story-fit or direct imports.
- **Regional town bases:** Johto towns IDs 79-88 (TS23); Kanto towns IDs 55-59 (TS21). The CSV has the full names and dimensions.

Map sizes are in RMXP map cells. IDs refer only to this pack and must be allocated/remapped for a destination project. Do not copy its MapInfos or connection data.

## Credits and use terms

The resource page says these credits are mandatory: **JohtoBlaziken** for base Kanto maps; **Earthescape/Orbitender** for Johto caves; **AenaonDusky**; and the source projects **PS: The First Journey** and **Red's Journey West**. The page's tileset credits name **GameFreak** (original FRLG maps and tiles, and music), **SirMalo** (HGSS rips for RMXP), **La Pampa** (tileset from Pokemon Epic Adventures, with a request to credit everyone mentioned there), **Kyledove** and **SailorVicious** (overworld tiles), **hek-el-grande, light-pa, zerudez and phyromatical** (lava/volcanic tiles), **Flurmimon** (some cave tiles), **Rayquaza Dot** (some overworld tiles), **ChaoticCherryCake** (truck from Public Tiles), and **DeepBluePacificWaves** (HGSS water). The page attributes map modifications and 50s/60s Kanto to AenaonDusky from PS: The First Journey. Music credits name GameFreak, **MarinaraSauce** (FRLG MIDI rips), and AenaonDusky (remastered/rearranged). The La Pampa credit asks users to include further credits listed with that tileset; those names are not transcribed in the resource page. The archive includes no separate, clearly identified license file. Treat the page's explicit credit requirement as binding, preserve any credits packaged with the assets, and seek permission/clarification from the resource author before public or commercial release. Download access and user authorization do not establish broader rights for every third-party asset, especially music.

## Integration boundaries and limitations

The author explicitly warns existing-project users: **never copy `MapInfos.rxdata`** and **do not replace the map connections data file**. Existing-project guidance also assumes tilesets 21-24 are available; this project must remap tileset IDs and resolve asset/tile-index collisions before any future use. That collision analysis has not been performed. A safer author-described option is graphical select-copying into newly allocated maps after setting up matching tilesets, followed by manual connection work. The resource says to preserve placeholders and notes the pack is a Gen 4-inspired template, not a faithful 1:1 recreation.

This is an inventory and acquisition review only. No files from the pack have been copied into active game folders, and no Normanhurst story flags, maps, PBS, MapInfos, connections or tilesets have been edited.
