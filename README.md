# Pokémon Normanhurst

Play: https://maxwarren929-png.github.io/normopo/

Experimental browser demo. Click the play symbol if prompted, then wait for the title screen to finish loading. The first visit downloads roughly 232 MiB. Later visits reuse unchanged cached files.

The room has the gacha and Gym Leader challenge NPCs, plus a storage PC at `[6,2]`. The pause menu also has a PC shortcut. [Cleanup notes](docs/two-npc-room.md).

[Banner navigation and PC update](docs/banner-controls-pc.md): both-direction banner cycling was checked, and the storage box screen opens from the new terminal.

[Martin and level matching](docs/martin-level-matching.md): Martin has a level-55 Dragonite. Choose Use my party and your entire team temporarily matches the opponent, from level 15 to 85. Original levels are restored after battle.

[Isaac and the sprite check](docs/isaac-and-fusion-sprite-check.md): Gym 5 now has Quagsire, Breloom and Flapple at provisional level 55. Two new IF favourites were checked, not imported without a character assignment.

[Website Mega Stone gift](docs/website-mega-stone-gift.md): new and existing saves receive every Mega Stone and a Mega Ring. Equip the stone, then use your own party in challenges. Desktop editions are unchanged.

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
