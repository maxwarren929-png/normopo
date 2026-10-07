# Browser runtime test

Published prototype: https://maxwarren929-png.github.io/normopo/
Repository: https://github.com/maxwarren929-png/normopo
Initial deployment commit: `897f7af`. Pages workflow succeeded. The live HTTPS site was checked in an isolated Chrome profile with screenshots of the title, New Game, map, movement and pause menu. Fresh-profile initialization including downloads took approximately 74 seconds in that run.

Normanhurst reaches its title, starts a new game, walks around the test room, and opens/closes the pause menu in Chrome. Screenshots were checked. This is not a full browser compatibility pass.

## Controls and loading

Enter now uses Nostalgist's paired C-button API. Escape uses its B-button API. C/X/Z and arrows retain the frontend's original mappings. A focus button is available. Held aliases release on blur/visibility loss, and repeat downs are ignored. The title's initial animation and transitions must finish before accepting input.

The localhost server caches the upstream engine/frontend on disk. HTTP validators avoid retransferring unchanged assets. The frontend also caches the engine and game in IndexedDB, with the actual game size and SHA-256 instead of the sample game's identity. Pages contains the engine files itself; it does not proxy GitHub at runtime.

The unused XP sample RTP, approximately 20.5 MiB, is no longer downloaded. No Pokémon art/forms, music, cries or move animations were removed. The existing release packaging already excludes native executables, development PBS/plugins and other development files. Further game-asset pruning needs a reference audit.

The game archive runs from MEMFS rather than synchronous OPFS. Large archive indexes were slow through the OPFS filesystem bridge. In the same local browser probe, initialization through the `512x384` geometry stage took about 56 seconds with OPFS and 22–28 seconds with MEMFS. This is an initialization metric, not a measured first-download or fully interactive-title time. Browser/renderer, cache state and hardware affect it.

## Package adjustments

The clean web package uses three opt-in adjustments:

- `pathCache=false` avoids recursive asset indexing over 21,786 archive entries.
- `Marshal.load(File.binread("Data/PkmnAnimations.rxdata"))` bulk-reads the unchanged 14.8 MB database. The streamed loader stopped progressing during initial experiments.
- `StartGame.initialize` no longer eagerly loads that database. The existing cached lazy loader remains, including custom Gojo animation cloning. First battle-animation use may take extra time.

Only staged scripts/config change. Shared desktop game scripts and edition maps are untouched. Desktop smoke results do not establish browser behaviour. The exact internal cause of the slow stream read has not been proven.

## Reproduce locally

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/build_web_test.py \
  --project normanhurst --buffered-animation-load \
  --defer-battle-animations --no-path-cache
node tools/serve_web_player.cjs
```

Open http://localhost:8123/ in Chrome. The server binds only to `127.0.0.1`. `WEB_PORT`, `WEB_ARCHIVE` and `WEB_ASSET_CACHE` override defaults. Already cached engine files work without contacting upstream; uncached files need internet access.

The screenshot probe requires Playwright Core and Chrome:

```sh
PLAYWRIGHT_CORE=/home/ko/projects/fun/node_modules/playwright-core \
WEB_URL=http://localhost:8123/ \
node tools/try_web_player.cjs --gameplay
```

The probe uses a separate browser profile and explicit SwiftShader. It waits for initialization and allows title transitions to settle. Its screenshot results require manual review; it does not automatically assert complete compatibility. The user's browser profile and desktop scaling are unchanged.

## Static Pages export

```sh
python3 tools/export_web_site.py \
  --archive normanhurst/build/web-player-review/pokemon-normanhurst-buffered-deferred-no-cache.mkxpz \
  --output /path/to/new-empty-site-directory
```

Prefetch the required engine/frontend into the asset cache first. `serve_web_player.cjs --prefetch <relative URLs...>` provides that step. The exporter verifies cached bytes, copies engine files, patches the frontend and preserves root credit files. It splits the unchanged ZIP_STORED archive into six SHA-256-verified chunks below GitHub's single-file limit. The fetch shim reconstructs the archive before the engine mounts it. It never uploads by itself.

GitHub Pages uses the COI service worker to provide cross-origin isolation. A first-visit reload can occur while that worker installs. A Pages Actions workflow deploys the static repository.

## Evidence and limits

Output: `normanhurst/build/web-player-review/`.

- `local-player*.png`: title, New Game, map, walking, pause menu and return to map.
- `pages-local-test/local-player*.png`: the static, chunked site tested on a plain local HTTP server without COOP/COEP headers.
- `web-timing.json`: initialization timings and request/resource records.
- `pages-release/`: published static snapshot, credits, license notices and build helper source.
- `pages-live-test/`: screenshots and timing from the deployed GitHub Pages site.

Python suite: 87 passing tests. Node server/frontend/touch suite: 18 passing tests.

The subsequent 30-pull gacha and mobile update is documented in [browser-gacha-mobile.md](browser-gacha-mobile.md). Touch-only browser testing verified the one-time 30-ticket grant, rates sheet and a single pull leaving 29. Portrait and landscape layouts were checked.

Still unverified in the browser: gym battles, ten-pulls/the complete spending cap, all custom mechanics/move animations, audible audio, save/reload persistence, long sessions, physical phones, other browsers and hardware graphics. Native tests verify the complete 30-pull cap and save-state serialization. Phone-sized viewports were checked using touch emulation; that is not a physical-phone compatibility pass. The fallback uses IDBFS when available, but that is not proof of reliable save persistence. Essentials emits its runtime-version warning.

Third-party material is not relicensed under the CLI's MIT license. The public prototype retains imported credits and runtime notices, identifies itself as noncommercial, and links pinned upstream source. Further reuse of individual assets still requires respecting their original terms.
