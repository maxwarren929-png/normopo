# Isaac and the Infinite Fusion sprite check

Subsequent update: Isaac now also has Ceruledge, and both reviewed Mega sprites are implemented. See [selected-megas-and-ceruledge.md](selected-megas-and-ceruledge.md). The review below records the earlier selection check.

Isaac is Gym 5 in the existing Normanhurst plan. His approved team is Quagsire, Breloom and Flapple. This update adds him to the challenge menu, with all three at provisional level 55 in a single battle. Standard Clay trainer artwork is a placeholder. Gym 7 remains unassigned.

Use my party temporarily matches your team to level 55, recalculates stats and heals the copies. Your original Pokémon and levels are restored afterward. The existing no-experience, no-money, no-Bag and no-badge rules remain. No new NPC or story map is added.

Provisional moves and abilities:

| Pokémon | Ability | Moves |
| --- | --- | --- |
| Quagsire | Unaware | Scald, Earthquake, Recover, Toxic |
| Breloom | Technician | Spore, Mach Punch, Bullet Seed, Rock Tomb |
| Flapple | Ripen | Grav Apple, Dragon Claw, Dragon Dance, Acrobatics |

Quagsire holds Leftovers and Flapple holds a Sitrus Berry. Nature, IVs, moves and held items are development settings, not user-approved final balance.

## Sprite check

The local Infinite Fusion favourites now contain 18 selections. Compared with the previously documented and imported selections, two are new and not imported:

| ID | Fusion | Artist | Recorded reference |
| --- | --- | --- | --- |
| `248.248` | Tyranitar + Tyranitar | dabouiw | Mega Tyranitar |
| `256.256a` | Honchkrow + Honchkrow | vultures | Plague doctor |

Both have local native front artwork. Neither has a confirmed genuine back or an assignment to Isaac, so neither was imported or substituted for his Pokémon.

The seven existing custom sprite selections are unchanged: `296.296j`, `213.213`, `3.3d`, `324.287a`, `290.288a`, `197.287d`, `310.287j`. Saved native originals for Gojo and the five custom variants match current source cells. Shucklord still uses its existing HGSS export. Their rear artwork remains front-derived placeholder art, and their shiny palettes remain placeholders.

No checked favourite identifies Quagsire, Breloom or Flapple. Isaac therefore uses their existing ordinary game sprites. This check covered the local shortlist, not the entire online Infinite Fusion library.

Older favourite `293.68a` has conflicting credits: its favourite metadata says calicorn, while the documentation and sprite-credit CSV say knuckles3andknuckles. No credit or art was silently replaced.

## Verification limits

The trainer PBS is edition-only and the shared menu remains gated on Normanhurst trainer records. Release compilation validated the new PBS. The standalone native Ruby regression passed level matching and original-team restoration for all eight challenges, including Isaac. The expanded real-battle suite and physical Safari have not been rerun for this update. No claim is made that the earlier software-rendered browser worker failures are fixed.
