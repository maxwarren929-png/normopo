# Selected Megas and Isaac's Ceruledge

## Mega Tyranitar

The selected `248.248` Tyranitar fusion by dabouiw now supplies Mega Tyranitar's artwork. It uses the existing form 1, Tyranitarite, Rock/Dark typing, Sand Stream and original Mega stats. Normal Tyranitar's artwork is unchanged.

The previous six Mega Tyranitar images are preserved under `Graphics/Pokemon/Selected Megas Sources/original-mega-tyranitar/`. Native source cells and their credits are retained. The shared Graphics directory makes the selected art visible in desktop Demo and Normanhurst as well as the website.

## Mega Honchkrow

The selected plague-doctor `256.256a` Honchkrow fusion by vultures is implemented as new form 1. Equip Honchkrowite and use the existing Mega command and DBK animation. It returns to form 0 after battle.

Provisional mechanics, since none were specified:

- Dark/Flying, Moxie.
- HP 100, Attack 155, Defense 72, Special Attack 105, Special Defense 72, Speed 101.
- 605 base-stat total, 100 above ordinary Honchkrow.
- No custom signature move or ability.

Honchkrow is now a rare ordinary-form Pokémon in Hoenn to Unova Champions, making the new Mega obtainable through the website's gacha. Tyranitar remains in Kanto & Johto All-Stars. The shared 30-pull cap, pity, shiny chance and reward level are unchanged. Adding Honchkrow slightly changes the per-species probabilities in its banner.

The website Mega gift includes Honchkrowite for new saves and upgrades existing saves that already received their original stone gift. Delivered-item tracking prevents old stones being awarded again and supports later added stones. The existing staged challenge Bag keeps the Mega Ring, while the no-Bag battle rule remains.

## Artwork limits

Native 96×96 IF cells are kept without HGSS palette conversion. Fronts use nearest-neighbour 2× scaling. Backs are mirrored-front placeholders and shinies reuse normal colours, not new rear or shiny artwork. Honchkrowite temporarily uses the existing Tyranitarite item icon. Original Tyranitar metrics are unchanged; battle placement is not newly verified. The native front contact sheet was visually inspected.

The art is credited third-party fan content, not covered by the authoring CLI's MIT licence. The existing game credits and runtime licences remain.

## Isaac

Isaac's Gym 5 team is now Quagsire, Breloom, Flapple and Ceruledge, all provisionally level 55. Ceruledge uses Flash Fire, Bitter Blade, Shadow Sneak, Swords Dance and Close Combat. It is an ordinary form, not a new variant. Its moves, nature and IVs are provisional. Own-party level matching and restoration are unchanged.

Source files are `pokemon_forms_Selected_Megas.txt`, `pokemon_metrics_Selected_Megas.txt`, `items_Selected_Megas.txt`, `trainers_GymTests.txt` and `tools/import_selected_megas.py`. The import tool blocks networking and checks exact artist credits before writing. It never overwrites the original Tyranitar backup.

Release compilation validated the new forms, stone, metrics and Isaac's expanded trainer PBS. The native Ruby gift check passed new-stone delivery, duplicate prevention, full-Bag retry and legacy Honchkrowite upgrade. No fresh browser gameplay, physical Safari test or full Mega battle run is claimed for this update.
