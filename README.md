# Pokémon Normanhurst

Play: https://maxwarren929-png.github.io/normopo/

Experimental browser demo. Click the play symbol if prompted, then wait for the title screen to finish loading. The first visit downloads roughly 232 MiB. Later visits reuse unchanged cached files.

[Own-region opening](docs/own-region-opening.md): New Game now starts in your house. Visit Mum and Ms Harman's lab, choose a starter, then investigate the station cancellation and Bush Track sabotage. The next town and Max's story Gym are not built yet. Existing development-room saves can choose **Menu → Story opening**. In the opening, **Menu → Development room** returns to the test features.

[Compact map redesign](docs/opening-map-redesign-review.md): furnished house/lab, rebuilt station forecourt and platform, physical doors/boards, no floating entrance labels. Older opening saves reload the new maps and recover blocked positions without resetting Pokémon or story progress.

The separate development room has the gacha and Gym Leader challenge NPCs, plus a storage PC at `[6,2]`. The pause menu also has a PC shortcut. [Cleanup notes](docs/two-npc-room.md).

[Banner navigation and PC update](docs/banner-controls-pc.md): both-direction banner cycling was checked, and the storage box screen opens from the new terminal.

[Martin and level matching](docs/martin-level-matching.md): Martin has a level-55 Dragonite. Choose Use my party and your entire team temporarily matches the opponent, from level 15 to 85. Original levels are restored after battle.

[Isaac and the sprite check](docs/isaac-and-fusion-sprite-check.md): Gym 5 now has Quagsire, Breloom and Flapple at provisional level 55. Two new IF favourites were checked, not imported without a character assignment.

[Website Mega Stone gift](docs/website-mega-stone-gift.md): new and existing saves receive every Mega Stone and a Mega Ring. Equip the stone, then use your own party in challenges. Desktop editions are unchanged.

[Selected Mega update](docs/selected-megas-and-ceruledge.md): IF Mega Tyranitar art, new Mega Honchkrow with Honchkrowite, and Ceruledge added to Isaac. Honchkrow is obtainable in the Champions banner; older website saves receive the new stone.

Approved Mega balance: Tyranitar is Rock/Fire, Thermal Armor, 685 BST. Honchkrow is Dark/Flying, Plague Doctor, 620 BST. See [mechanics and final stats](docs/selected-megas-and-ceruledge.md). Banner pools remain separate; no banner-pool redesign has been approved.

[Mahoraga and Mega Tropius](docs/mahoraga-mega-tropius.md): claim Mahoraga from the room pause menu; roll Tropius in Champions and equip the gifted Tropiusite. Adaptation works midway through multihit moves. Fruitful Canopy has a 25% chance to heal ¼ HP after a Grass move.

[Mega Breloom](docs/mega-breloom.md): Isaac now has a Mega-capable Breloom with the selected IF art. Players receive Breloomite through the website gift. Provisional Grass/Fighting, Technician, 560 BST.

[Mr Lin and Mr Howel](docs/elite-four-lin-howel.md): one Elite Four doubles duo, six Pokémon each, provisional level 95. Mr Lin has our Mega Tyranitar; Mr Howel uses the approved sound-themed team. Select them at the development-room battle NPC. The approved compact map redesign is now included.

[Smaller engine downloads](docs/browser-engine-chunks.md): the browser engine now transfers in eleven verified pieces of at most 4 MiB instead of one 43 MB request. The engine binary and saves are unchanged.

[Download retries](docs/browser-download-retries.md): interrupted downloads get up to three attempts and show the failed filename with a retry button instead of leaving an unexplained percentage. Missing loader font requests are removed. This does not clear saves; persistent network blocks can still require troubleshooting.

## Gacha

Talk to the scientist at `[10,2]`, near the upper-right corner of the test room. You receive **30 tickets once per save**, with a shared **30-pull maximum** across all banners. Extra tickets cannot bypass it.

All prizes are fully evolved, level-50 Pokémon. Choose from Kanto/Johto, Hoenn to Unova and Paldea banners. Legendary pity is ten pulls per banner, and the configured shiny chance is 5%. The screen shows how many pulls remain.

[Safari layout and input fixes](docs/safari-controls-fix.md): stable page layout, bounded startup reloads and disabled speed shortcuts. Close the old tab and reopen to update. Physical Safari verification is pending.

## Controls

- Enter, Space or C: confirm or interact.
- Escape or X: back.
- Z: menu. In gacha, this opens the rates sheet.
- Arrows: move or navigate.

Mobile has a directional pad plus Confirm, Back and Menu buttons. Rotate to landscape for a wider view. Touch layouts, navigation, rates and one actual gacha pull were tested in Chrome's phone emulation. Physical Android/iPhone testing is still pending; older phones may be too slow or have insufficient memory.

Refresh to load an update. If you still see the old unlimited-ticket option, hard-refresh or close and reopen the page. Game identity and archive hashes change with each release, so the old game cache is not reused as the new game.

See [change notes and test details](docs/browser-gacha-mobile.md) and [browser runtime notes](docs/browser-runtime-test.md). Browser save persistence, audio, battles and long sessions are not fully verified. Do not assume browser saves are portable or backed up.

## Source and ownership

This is a noncommercial fan game. Pokémon, imported artwork/music/plugins and runtime components belong to their original owners. No general MIT license is granted for the game or its assets. Read [third-party notices](THIRD-PARTY.md), `credits/` and `licenses/`.

The runtime is mkxp-z `2.4.2/5cd3203`. Its pinned upstream source is linked in THIRD-PARTY.md. Frontend/export/probe source is in `tools/`; the Normanhurst gacha adaptation is in `game-source/`. This repository is a deployment snapshot, not the complete desktop authoring workspace.

GitHub Actions deploys `main` to Pages. Source, tests and documentation are committed with updates. Archive chunks, the manifest and frontend identity must be published together.
