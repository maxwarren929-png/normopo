# Browser download failure handling

A laptop Chrome user reported a loader stuck at 87%, missing Roboto font requests and `Uncaught TypeError: Failed to fetch`. The error did not identify the failed URL, so the exact cause on that laptop is not yet known. The font failures are separate from the fatal download rejection.

The player now retries a failed engine JS/WASM download up to three times, including failures while reading the response body. A 200 response header alone is not enough. Partial download progress is rolled back before retrying. The game-manifest reader and each hash-verified archive chunk also have three attempts. Previously verified chunks remain in the in-memory assembly while a later chunk retries. Abort requests are not retried. An exhausted chunk failure is marked so the outer player does not repeat the whole archive download.

On exhaustion, the loader displays the failed filename and error, with a Retry download button. This manually reloads the page. It does not delete IndexedDB, saved games, local storage or service workers. Retries are bounded, not an automatic page reload loop. Persistent network filtering, an extension block, an offline connection or GPU/runtime failures are not fixed by retrying.

The sample loader CSS referenced Roboto font files absent from the pinned asset export. Those font-face declarations were removed; loader/controls text uses a system UI font. In-game FireRed bitmap fonts and all game assets are unchanged.

Checks: 10 focused Node cases and 9 exporter cases passed. A fresh isolated Chrome run before this patch downloaded the current archive and reached 100%; it did not reproduce the user's 87% stall or establish a full game startup. A separate isolated loopback Chrome fixture injected HTTP 503 for the WASM file, observed exactly three requests, verified the named error/retry panel and no font 404s, and captured an inspected screenshot. The body's failure/retry and progress rollback callback were checked in a lightweight fixture. No complete browser gameplay or resolution on the user's laptop is claimed yet.

Release: frontend/static export only. The approved map/duo game archive, six chunks, manifest SHA and saved-game URL are unchanged. Reload the existing site with Ctrl+Shift+R, or Cmd+Shift+R on macOS, to get the new loader without clearing site data. If it still fails, report the filename shown by the new error panel.
