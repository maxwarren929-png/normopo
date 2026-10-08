# Normanhurst gym leaders

Approved order and current team plans. Seven provisional Gym Leader challenges
and Martin's trainer challenge are implemented in Normanhurst. These are not story gyms.

| Gym | Leader | Team | Format |
| --- | --- | --- | --- |
| 1 | Max | Morpeko, Ditto | Not specified |
| 2 | Ko | Fermentris, Porygon2 | Not specified |
| 3 | Warren | Sylveon, Vaporeon, new Gardevoir variant | Not specified |
| 4 | Karna | Gengar, Gallade variant, Gardevoir variant | Double battle |
| 5 | Isaac | Quagsire, Breloom, Flapple | Single, provisional |
| 6 | Oliver | Leafeon, Lapras, Mega Blastoise | Not specified |
| 7 | TBD | TBD | Not specified |
| 8 | Kaelan | Noivern, Glaceon, new regional Absol | Not specified |

Oliver's ace is Mega Blastoise. Other aces and lead orders are not confirmed;
the team lists above do not prescribe battle order.

Fermentris is the implemented evolution of Shuckle, internally SHUCKLORD.
Porygon2 is the existing species, not a new variant.

## Custom variants

- Warren's Gardevoir uses `324.287a` (Empoleon + Gardevoir, pinkpalkia).
  Implemented in the demo as Gardevoir form 2, Water/Femboy, with Fanfare Gauge
  and Salon Solitare. See [custom Pokémon plans](custom-pokemon-plans.md).
- Karna's variants are selected from IF favorites: Gardevoir uses `197.287d`
  (Umbreon + Gardevoir, qaffeine); Gallade uses `290.288a`
  (Kecleon + Gallade, sr.coiso). Both are implemented in the demo.
  Gardevoir form 3 is Dark/Fighting with Protective Instinct; Gallade form 2
  is Fighting/Normal with Man of a Thousand Faces and Operation Strix.
- Kaelan's regional Absol uses `310.287j` (Absol + Gardevoir, pinkpalkia).
  Implemented in the demo as Absol form 3, Fire/Dark, with Bond of Life and
  Blood-Debt Directive.

Warren and Karna use different Gardevoir variants.
All four variants have implemented typing, stats and abilities. See
[custom Pokémon plans](custom-pokemon-plans.md) for their mechanics and demo testers.

## Test battles

Talk to the scientist at 2,7 in Normanhurst's existing test room. Choose a
leader, then use healed copies of your own party at the opponent's level or
borrow a matching six-Pokémon team. Your actual Pokémon, Bag, Pokédex and statistics are
restored afterwards. No experience, prize money or badges are awarded, Bag
items are disabled, defeat is allowed and battles use set style.

| Leader | Provisional level | Placeholder trainer artwork |
| --- | --- | --- |
| Max | 15 | Cheren |
| Ko | 25 | Brock |
| Warren | 35 | Cilan |
| Karna | 45 | Morty |
| Isaac | 55 | Clay |
| Martin, separate trainer | 55 | Ace Trainer male |
| Oliver | 65 | Marlon |
| Kaelan | 85 | Drayden |

Levels, natures, IVs, movesets, non-Mega held items and artwork are provisional,
not approved final gym balance. Team species/forms are the approved selections.
Karna leads with the two custom variants in a double battle, with Gengar last
so Gallade can disguise itself. Oliver's last Pokémon holds Blastoisinite, and
his trainer inventory includes a Mega Ring for normal enemy Mega activation.

Trainer PBS is edition-only `normanhurst/game/PBS/trainers_GymTests.txt`.
The shared `demo/scripts/0400-CLI_Normanhurst_Gym_Tests.rb` checks whether those
records exist; Hornsby does not receive the roster or test NPC. Normanhurst's
custom PBS dependencies are symlinked from the demo without changing Hornsby.

Run `python3 tools/smoke_linux.py --project normanhurst --release --gym-tests`.
The updated probe covers all eight trainer challenges and executes an actual attack.
This expanded suite has not been rerun; the earlier six-Gym run passed. It
checks Karna's double leads and Oliver's real DBK Mega Blastoise, tests own-party
copy/restoration, and captures `normanhurst/build/runtime-smoke-gym-*.png`.

The separate Hornsby isolation smoke could not compile: its shared Riolu PBS
references Blindfold, but Hornsby's PBS overlay lacks `items_Gojo.txt`. That
pre-existing shared-data dependency is outside the gym test change. No Hornsby
files were edited, and the Normanhurst roster/test event remain edition-only.

Remaining aces, personalities, badges, gym locations and puzzles are undecided.
Gym 7's leader and team remain TBD. Isaac's approved team is Quagsire, Breloom
and Flapple. Level 55, lead order, moves and Clay artwork are provisional. No shared type restriction
has been specified. Do not apply this roster to Hornsby or regenerate story maps
without approval.
