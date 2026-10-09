# Smaller browser-engine downloads

The user's new error panel identified `mkxp-z_libretro.wasm` as failing after three attempts. This isolates the failed asset, not the underlying cause of that laptop's network/body-read failure. Its single download was 42,539,967 bytes.

The static exporter now also splits that pinned binary into eleven SHA-256-verified pieces, each at most 4 MiB. `engine-manifest.json` identifies their sizes, hashes and ordered filenames. The HTML pins the engine's complete size and original SHA-256, intercepts its same-origin WASM request and reassembles the exact binary into an `application/wasm` response. No changed engine code or third-party binary is introduced. Browser-engine caches retain the original URL/hash and the game archive/save URL is unchanged.

Each failed piece gets at most three attempts, including body-read and checksum failures. Previously verified pieces stay in memory while a later piece retries. Engine pieces are fetched sequentially; status text shows the current part. A final failure names the piece and preserves the existing retry button. This is a transfer-size mitigation, not a promise to solve a persistent offline connection, blocked requests or GPU failure. The original large WASM file remains published for older loader versions.

Checks: ten exporter cases pass, including exact engine-byte reassembly and recovery of one failed middle piece without requesting earlier pieces again. An isolated loopback Chrome probe assembled the real 42,539,967-byte engine, verified its original SHA-256 and successfully compiled it with WebAssembly.compile. An injected failure of piece 5 recovered with two requests for that piece and one for every other piece. No direct large WASM network request occurred. This probe does not establish a complete game start or resolution on the user's laptop.

Hard-refresh the same website to load the new HTML. Do not clear site data. If startup still fails, send the error panel's filename/message.
