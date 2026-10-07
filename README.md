# Pokémon Normanhurst

Play: https://maxwarren929-png.github.io/normopo/

Experimental browser build using mkxp-z and the reference Ruby VM. Chrome is the tested browser. Click the play symbol when prompted, then allow the title screen to finish loading.

Controls:

- Enter or C: confirm.
- Escape or X: back.
- Z: pause menu.
- Arrow keys: move.
- Click "Focus game" if keyboard focus moves away from the game.

The first visit downloads roughly 232 MiB of game and engine files. The browser caches unchanged files for later visits. The game archive stays internally uncompressed and is split into SHA-256-verified chunks to fit GitHub's file limits. The unused XP sample RTP is omitted. Battle animations load on first use rather than before the title. The game runs from memory-backed files to avoid slow synchronous archive reads.

Title, new game, movement and the pause menu were checked with screenshots. Battles, gacha, audio, save/reload persistence and long sessions still need browser testing. Browser storage is local to this site and browser profile; do not assume a save is portable or backed up.

This is a noncommercial fan game. Pokémon and third-party artwork, music, plugins and runtime components belong to their original owners. No general MIT license is granted for the game or its assets. Read [third-party notices](THIRD-PARTY.md), `licenses/`, and all files in `credits/`. Original Essentials credits remain in the game and are also provided as source in `credits/Original-Essentials-Credits.rb`.

The runtime is mkxp-z `2.4.2/5cd3203`. Corresponding engine and browser build sources are linked in THIRD-PARTY.md. Frontend patch/export source is in `build-tools/`. This repository is a static deployment snapshot, not the complete desktop authoring workspace.

GitHub Actions deploys `main` to Pages. Do not delete or change individual archive chunks independently; export a matching manifest, frontend identity and all chunks together.
