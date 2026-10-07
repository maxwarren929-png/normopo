# Pokémon Normanhurst

Current state: the reverted demo room with only the gacha and Gym Leader challenge NPCs, plus a storage PC at [6, 2]. The pause menu also offers PC access in this room. New games start on map 1 at [5, 5]. The Home Suburb/station content described below is inactive and backed up in `backups/story-maps-20261003-185938/`. Font fixes and resource downloads remain. Do not run the story map generator unless the user requests restoring those maps.

Banner controls and the browser-only GPU text fix are documented in [banner-controls-pc.md](../docs/banner-controls-pc.md).

Red-branded development edition. Start it from the repository root:

```sh
./poke --project normanhurst play
```

The scientist at **2,7** opens the provisional challenges: Max level 15, Ko 25, Warren 35, Karna 45, Martin 55 with Dragonite, Oliver 65 and Kaelan 85. Your own party is copied, healed and matched to the opponent's level for battle, then restored unchanged. Borrowing a matching six-Pokémon team remains optional. See [Martin and level matching](../docs/martin-level-matching.md). Your originals are restored afterwards. No experience, prize money or badges are awarded; Bag use is disabled and defeat is allowed. Karna uses doubles with the two custom variants leading. Oliver's Blastoise uses normal enemy Mega Evolution with DBK. Existing trainer artwork is used as a placeholder. Isaac and Gym 7 are not added yet. These are test battles, not restored story gyms. See [the roster and provisional settings](../docs/normanhurst-gym-leaders.md).

The scientist at **10,2** opens Gacha System or gives 10 free test tickets. Single and ten-pulls cost one ticket per pull. Default prize pools and pity rules are unchanged. The scientist has only an animated icon, not a floating text box.

Karna's ability UI uses compact labels, Thousand Faces and Protect Instinct, and shortened descriptions. The BOL icon matches the existing status borders and pixel-font grid in the summary, battle and Bag Party screens.

Verify them with `python3 tools/smoke_linux.py --project normanhurst --release --gym-tests`. This also checks gacha logic/UI and captures custom ability summary screens. Battle screenshots are in `build/runtime-smoke-gym-*.png`. Trainer definitions are edition-only `game/PBS/trainers_GymTests.txt`; new custom PBS dependencies link to the demo.

Its maps and builds are independent. Scripts, plugins, assets and runtime are shared with `demo/`; changes there affect both editions. Edition-specific PBS files live in `game/PBS/`. Saves use `pokemon-normanhurst`, separate from Hornsby and the old demo.

Start a New Game for the Home Suburb opening. Mum sends you to Ms Harman's lab, where you choose one of three level-5 starters. One Grass, Fire and Water starter is rolled from generations 1–9 and saved for that playthrough. Your rival picks the offered starter with the type advantage. Talk to the rival to battle, then receive a Pokédex, five Poké Balls and three Potions. Mum heals your team when you return home. The opening continues at Home Suburb Station and the Bush Track, where you stop Team Ozerim sabotaging a signal, deliver a research parcel and report back to Ms Harman. Later towns and routes are not authored yet. See [the shared story plan](../docs/story.md).

Run `python3 tools/test_home_suburb.py` from the repository root for disposable native runtime checks of both editions. The shared opening code is `demo/scripts/0400-Home_Suburb.rb`. `tools/author_home_suburb.py` regenerates both editions' five chapter-one maps from the imported artwork and overwrites later map edits. Do not rerun it after hand-editing maps without backing them up.

 [Edition setup and tested behavior](../docs/editions.md).
