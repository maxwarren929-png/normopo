# Publishing Normanhurst changes

The maintainer wants completed work pushed with documentation, not left only on this machine.

Authorized public deployment repository: `git@github.com:maxwarren929-png/normopo.git`.
Live URL: https://maxwarren929-png.github.io/normopo/

For completed Normanhurst changes:

1. Preserve edition scope. Shared scripts/plugins/assets also affect Demo and Hornsby; gate Normanhurst behavior through its compiled edition records. Do not regenerate reverted story maps without approval.
2. Run appropriate tests and inspect screenshots for visible changes.
3. Rebuild/export the static package when game or frontend code changes. Use `--gpu-gacha-text` with the existing buffered/deferred/no-path-cache flags for the web build. It avoids per-frame bitmap-font tint work in gacha while preserving desktop behavior. Publish matching archive chunks, manifest and frontend identity together.
4. Include changed source, regression tests, credits/provenance and concise change/test documentation in the deployment commit.
5. Push normally to the authorized repo, wait for Pages Actions, and check the live URL before claiming deployment succeeded.

Do not blindly commit this whole authoring tree to the deployment repo. It contains unrelated editions, build/browser profiles, logs and imported assets. Never publish credentials or private browser state. Keep third-party rights/credits intact; the CLI MIT license does not license imported game assets.

The deployment working clone has been `/tmp/normopo-deploy-review`; inspect its origin, branch and status before reusing it. Export snapshots live under `normanhurst/build/web-player-review/`. Read `docs/browser-runtime-test.md` and `docs/browser-gacha-mobile.md` for current behavior, limits and test commands.
