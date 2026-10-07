# Normanhurst gacha and touch controls

Play: https://maxwarren929-png.github.io/normopo/

## 30-pull allowance

The scientist at tile `[10,2]` grants 30 tickets once per save. All three banners share one 30-pull spending limit. Each ticket buys one Pokémon. Single pulls and ten-pulls are available. Extra tickets cannot bypass the spending limit. Failed payments, a full party/PC and a failed ticket grant do not consume the allowance.

The gacha screen shows `Pulls left: N/30`. The claim and spending counter are saved in `PokemonGlobalMetadata.normanhurst_gacha_claimed` and `normanhurst_gacha_pulls_used`. Saving is still the player's choice, not forced by gacha. Normal game-state save/reload was checked with a Marshal round trip; persistence across browser closure still needs testing.

Legacy saves receive the new 30-pull budget. The old build stored only resettable per-banner pity counters, so historical rolls cannot be reconstructed. A new game starts a new allowance and discards the previous game's team.

## Pokémon-only banners

- Kanto & Johto All-Stars.
- Hoenn to Unova Champions.
- Paldea Powerhouses.

Each curated banner has ten common, ten rare and three legendary candidates. Every candidate must exist as an ordinary form-0 species and have no remaining evolution in the game's actual data. Babies and intermediate stages are rejected. Shuckle is excluded because it evolves into Fermentris in this game. No items or custom regional forms are in these pools.

Rewards are level 50. Per-species base weights are 12 for common, 5 for rare and 1 for legendary. The UI shows normalized base rates. Legendary pity is per banner, guaranteed by ten pulls without a legendary, with soft pity starting at eight. Each reward has a 5% configured shiny chance.

The compiled Normanhurst gym-trainer records gate this adaptation. Demo and Hornsby keep their original gacha behavior. No story maps were regenerated.

## Mobile controls

Touchscreens and narrow browser windows get a directional pad plus Confirm, Back and Menu buttons. In gacha, Menu opens the rates sheet. Portrait puts controls beneath the game; landscape puts them on either side. Rotate to landscape if the screen feels small.

The controls use Nostalgist's paired button API, track individual pointers and share a reference count with keyboard aliases. They release on pointer cancellation, capture loss, window blur, hidden tabs and orientation changes. Brief action taps last at least 100 ms; direction taps last at least 40 ms. This avoids taps disappearing between game frames without extending every walking gesture.

The small sample XYZ/save-state overlay is disabled. Desktop keyboard bindings and scaling are unchanged. The mobile canvas preserves the 4:3 aspect ratio and uses nearest-neighbour scaling. Integer CSS scaling is used where it fits; small phones need fractional downscaling to show the whole screen.

Tested with Chrome's touch emulation at 390×844 and 844×390, using an isolated profile and software graphics. A real Android phone and iPhone/Safari are not yet verified. This large reference-Ruby build may be slow or run out of memory on older phones. The first visit downloads roughly 232 MiB.

## Verification

- Native Normanhurst release gym and plugin-UI smoke passed.
- Demo release plugin-UI smoke passed with its original item pools and pity.
- Ruby gacha unit harness passed through bundled mkxp-z.
- Python suite: 87 passing tests.
- Node server, frontend and touch-input suite: 18 passing tests.
- The static site was tested at a Pages-style `/normopo/` path without server COOP/COEP headers.
- Touch-only browser navigation reached the scientist, received 30 tickets, opened the rates sheet, completed a single pull and showed 29 remaining. Portrait and landscape screenshots were inspected.

Reproduce the browser checks in the authoring workspace:

```sh
PLAYWRIGHT_CORE=/path/to/playwright-core \
WEB_URL=http://localhost:8131/normopo/ \
WEB_OUTPUT=/path/to/test-output \
node tools/try_web_player.cjs --gameplay --mobile --gacha
```

The gacha probe needs Tesseract for paging checks and the 30-to-29 overlay assertion. Browser rendering screenshots still need manual review. Native tests cover the complete 30-pull cap and all pool candidates; the browser test covers one actual pull, not an exhaustive battle/gameplay pass.

Source is preserved in the deployment repository's `tools/` and `game-source/`, with regression tests and selected screenshots. Imported assets retain the notices in `THIRD-PARTY.md`, `credits/` and `licenses/`.
