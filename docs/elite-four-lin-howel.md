# Mr Lin and Mr Howel

One approved Elite Four slot, fought as a doubles duo. Each trainer owns six Pokémon, so the opponent side has twelve total. One Pokémon from each trainer is active at a time. Their parties remain independent; neither trainer takes over the other's reserves. The player's side uses the normal six-member party and controls both active Pokémon.

Both teams are provisionally level 95. Adjust levels later in `trainers_EliteFourDuo.txt` and the matching entry in `CLI_Normanhurst_Gym_Tests.rb`.

## Mr Lin

Dragapult, Chandelure, Tyranitar, Muk, Goodra, Gardevoir.

Tyranitar holds Tyranitarite and Mr Lin has a Mega Ring. Its normal Mega path uses our existing Rock/Fire Mega Tyranitar with Thermal Armor, not a second new form or a permanently Mega Pokémon. Gardevoir is ordinary form 0, not Warren/Karna's custom form. Muk and Goodra are also ordinary forms.

## Mr Howel

Noivern, Toxtricity, Exploud, Kommo-o, Primarina, Skeledirge.

The team uses Boomburst, Overdrive, Hyper Voice, Clanging Scales, Sparkling Aria and Torch Song. Existing sound flags, abilities and typing apply; the update does not retype the entire roster. Noivern keeps its established Flying/Sound typing and Boomburst keeps its established Sound type. Every team member has Protect. Gardevoir's Telepathy and Kommo-o's Soundproof can help around sound/spread attacks, but Boomburst and Sparkling Aria can still hit unprotected allies. This is not a claim of optimized coordinated AI.

Full moves, abilities and held items are recorded in `game-source/trainers_EliteFourDuo.txt`. Existing Will/Lucian artwork is reused as a disclosed placeholder, not presented as custom portraits.

## Access

The development room's existing battle NPC now offers **Mr Lin & Mr Howel - Elite Four doubles, Lv. 95**. Owned-party mode temporarily heals and level-matches copies to 95, preserving species, forms, moves, held items and original Pokémon. Borrowed-team mode is still available. At least two non-egg Pokémon are required for owned-party doubles.

This is a playable development challenge. The Elite Four building, story unlock and later region progression are not authored yet. No badge, experience or money is awarded. Party, Bag, Pokédex, stats, battle rules and settings are restored afterward, including exception paths.

Availability requires both trainer records and the existing Normanhurst roster. Demo/Hornsby do not acquire this challenge merely because they share scripts.

## Checks and release scope

Compilation passed. The isolated native probe loaded both exact six-member rosters, checked Lin's Tyranitarite/Mega Ring and form-1 eligibility, and started an actual 2v2 trainer battle. It verified enemy party starts `[0,6]`, twelve total opponents, Dragapult/Noivern leads and restored the original party when ending at the first command phase. The doubles screenshot was inspected. The lightweight level-matching fixture checks all nine challenges, two separate trainer arguments for the duo and exception restoration.

No complete twelve-opponent battle, Mega animation sequence or new browser gameplay is claimed. Enemy Mega eligibility is checked, not a claim that the AI has already been observed evolving Tyranitar in a full match.

The release is built from the previously published maps/start/private Tilesets, with only the battle addition. The unapproved local compact-map redesign and its new assets are excluded. Local map-review files and private browser state are not published. The existing buffered/deferred/no-path-cache/GPU-gacha/website-Mega-gift build options remain enabled.
