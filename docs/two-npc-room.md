# Two-NPC demo room

Normanhurst's test room now contains only:

- Gacha scientist at `[10,2]`, event 8.
- Gym Leader challenge scientist at `[2,7]`, event 7.

Removed the guide, plugin tester, news reader and market trader. Their floating news/market indicators are gone too. The invisible player initialization and follower anchor remain, with their original event IDs. Room tiles, the 30-pull budget, pools, Gym Leader rosters, mobile controls and other editions are unchanged.

Source: `game-source/001-first-room.json` in the deployment repository, authored from `normanhurst/maps/001-first-room.json` in the workspace. No story-map generator was run.

Before the request to skip further testing, validation, the 89-test Python suite, a web rebuild and the local mobile startup/movement/menu probe completed. The resulting room screenshot shows just the two retained NPCs. No further gameplay or live-browser tests were run for this cleanup.

Refresh the site for the updated package. If an existing save retains old map state and still shows removed NPCs, start a new game. That starts a fresh team and 30-pull allowance.
