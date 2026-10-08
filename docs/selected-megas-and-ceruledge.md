# Selected Megas and Isaac's Ceruledge

## Mega Tyranitar

The selected `248.248` Tyranitar fusion by dabouiw now supplies Mega Tyranitar's artwork. It uses the existing form 1 and Tyranitarite. The approved redesign is Rock/Fire with Thermal Armor and a 685 base-stat total. Normal Tyranitar's artwork is unchanged.

The previous six Mega Tyranitar images are preserved under `Graphics/Pokemon/Selected Megas Sources/original-mega-tyranitar/`. Native source cells and their credits are retained. The shared Graphics directory makes the selected art visible in desktop Demo and Normanhurst as well as the website.

## Mega Honchkrow

The selected plague-doctor `256.256a` Honchkrow fusion by vultures is implemented as new form 1. Equip Honchkrowite and use the existing Mega command and DBK animation. It returns to form 0 after battle.

Approved mechanics after the requested 15-point buff:

- Dark/Flying, Plague Doctor.
- HP 100, Attack 150, Defense 72, Special Attack 140, Special Defense 72, Speed 86.
- 620 base-stat total, 115 above ordinary Honchkrow.
- No custom signature move.

Mega Tyranitar's proposed Attack was reduced by 10 and Speed by 5. Final stats are HP 100, Attack 145, Defense 125, Special Attack 125, Special Defense 100, Speed 90, total 685.

Thermal Armor halves incoming Water and Ground move damage. Rock/Fire's 4× weaknesses become effectively 2× while the ability is active. Normal suppression and Mold Breaker rules apply. There is no weather or damage bonus.

Plague Doctor gives damaging Dark moves a 30% normal-poison roll once per distinct target after actual HP damage. Misses, protection, Substitute-only damage, already-statused targets, normal poison immunities, Shield Dust and Covert Cloak block it. The ability must be active. Rare multihit cases where an earlier strike damages HP but the final successful strike deals zero HP damage do not roll. No core battle methods or DBK animation hooks are replaced.

Honchkrow is now a rare ordinary-form Pokémon in Hoenn to Unova Champions, making the new Mega obtainable through the website's gacha. Tyranitar remains in Kanto & Johto All-Stars. The shared 30-pull cap, pity, shiny chance and reward level are unchanged. Adding Honchkrow slightly changes the per-species probabilities in its banner.

The website Mega gift includes Honchkrowite for new saves and upgrades existing saves that already received their original stone gift. Delivered-item tracking prevents old stones being awarded again and supports later added stones. The existing staged challenge Bag keeps the Mega Ring, while the no-Bag battle rule remains.

## Artwork limits

Native 96×96 IF cells are kept without HGSS palette conversion. Fronts use nearest-neighbour 2× scaling. Backs are mirrored-front placeholders and shinies reuse normal colours, not new rear or shiny artwork. Honchkrowite temporarily uses the existing Tyranitarite item icon. Original Tyranitar metrics are unchanged; battle placement is not newly verified. Its original form record is also preserved alongside the art backup. The native front contact sheet was visually inspected.

The art is credited third-party fan content, not covered by the authoring CLI's MIT licence. The existing game credits and runtime licences remain.

## Isaac

Isaac's Gym 5 team is now Quagsire, Breloom, Flapple and Ceruledge, all provisionally level 55. Ceruledge uses Flash Fire, Bitter Blade, Shadow Sneak, Swords Dance and Close Combat. It is an ordinary form, not a new variant. Its moves, nature and IVs are provisional. Own-party level matching and restoration are unchanged.

Tyranitar's form record is updated in `pokemon_forms.txt`. Ability code is `0400-CLI_Selected_Mega_Abilities.rb`, with definitions in `abilities_Selected_Megas.txt`. Other source files are `pokemon_forms_Selected_Megas.txt`, `pokemon_metrics_Selected_Megas.txt`, `items_Selected_Megas.txt`, `trainers_GymTests.txt` and `tools/import_selected_megas.py`. The import tool blocks networking and checks exact artist credits before writing. It never overwrites the original Tyranitar backup.

Release compilation validated the new forms, stone, metrics and Isaac's expanded trainer PBS. The native Ruby gift check passed new-stone delivery, duplicate prevention, full-Bag retry and legacy Honchkrowite upgrade. The standalone native Ruby ability check passed Water/Ground multipliers, the 30% boundary and blocked poison conditions. It uses controlled handler fixtures, not full real battles. No fresh browser gameplay, physical Safari test or full Mega battle run is claimed for this update.
