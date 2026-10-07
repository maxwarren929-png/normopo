# Martin and level-matched teams

Martin is an additional single-battle challenge in the existing Gym Leader challenge menu. He uses one ordinary Dragonite at provisional level 55, with Multiscale, Dragon Claw, Dragon Dance, Earthquake and Extreme Speed. Standard Ace Trainer artwork is a placeholder. No story gym number is assigned and no extra NPC is added.

The menu is ordered by level: Max 15, Ko 25, Warren 35, Karna 45, Martin 55, Oliver 65 and Kaelan 85.

Choose **Use my party** to battle with your gacha team. Every non-egg party Pokémon temporarily matches that opponent's level. Stats are recalculated and the copies are healed. Species, forms, moves, held items, IVs, EVs and shininess are retained. This applies to every owned party member, not only gacha rewards. Borrowing a matching test team remains available as the second option.

The stored Pokémon are not permanently levelled up or down. Rewards still arrive at level 50 outside battle, and your original team, levels and experience are restored afterward, including after an exception. Pokémon in boxes are unaffected until they join the party for a challenge. No experience, money, badges or forced saves are added.

The Normanhurst-only compiled trainer-data gate still keeps this out of Demo and Hornsby. Martin's level is provisional because no level was specified.

## Checks

- Native Ruby preload harness passed copy/level/stat-recalculation/healing/restoration checks for all seven opponent levels, plus the exception path.
- Normanhurst validation and the release/web build, including PBS compilation, succeeded.
- Existing native gym smoke coverage was updated for Martin and own-party level matching, but the full real-battle suite was not rerun for this update.
- A fresh browser diagnostic fetched all assets and reached preparation. The software-rendered worker then failed before game geometry in one configuration. The new menu and battles were not visually verified in the browser, and physical Safari remains unverified.

Source: `game-source/0400-CLI_Normanhurst_Gym_Tests.rb`, `game-source/trainers_GymTests.txt`. Regression harness: `tests/normanhurst_level_match_unit.rb`. Run it as a standalone relative preload in the bundled mkxp-z runtime with the source path supplied by `CLI_LEVEL_MATCH_SOURCE`; it writes `level-match-result.txt` on success.
