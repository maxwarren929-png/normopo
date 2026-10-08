# Mahoraga and Mega Tropius

Mahoraga is Machamp form 1, Fighting/Steel. Stats in HP/Attack/Defense/Special Attack/Special Defense/Speed order are 90/130/100/65/100/70, total 555. It retains Machamp's learnset. Its display name is Mahoraga, without replacing ordinary Machamp.

Adaptation remembers each individual move ID after an actual damaging hit. The first Flamethrower is normal damage, subsequent Flamethrowers do half. Fire Blast has its own independent entry. It never stacks below half. Learning occurs per hit, so a multihit move's first hit is normal and subsequent hits are halved immediately. Switching, including Baton Pass, clears the memory. Misses, protection and Substitute-only damage do not teach it. Normal ability suppression and Mold Breaker apply to resistance. Fixed-damage moves also receive the reduction; their AI estimates are not adjusted.

In the Normanhurst room, use **Menu → Mahoraga** to claim one free level-50 development gift per save, including older saves. It goes to your party or boxes; a failed capacity check does not consume the claim. This gift is separate from the unchanged 30-pull gacha budget. This makes the new variant available without replacing ordinary Machamp or disguising a custom form as an ordinary-species roll.

Mega Tropius is Tropius form 1, Grass/Dragon. Stats are 99/88/113/112/117/31, total 560. Give ordinary Tropius Tropiusite and use the usual Mega command. Existing DBK animation remains intact.

Fruitful Canopy rolls once after using a Grass-type move, with a 25% chance to restore one quarter of the user's maximum HP, rounded down with minimum 1. It needs no berry and does not replace Tropiusite. Grass status moves count, as do misses and blocked uses. Being unable to act or lacking PP does not count. Healing requires an active ability and the normal canHeal? check, so fainting, full HP, Heal Block and Bond of Life retain their normal restrictions. Multihit and spread moves do not add extra rolls.

Ordinary Tropius is added to the common pool in Hoenn to Unova Champions. Website saves receive Tropiusite through the existing Mega gift, including saves that completed the previous gift. Per-item tracking prevents repeat stones. The banner pools remain separate; other pool entries and the 30-pull cap are unchanged.

## Artwork and source

Mahoraga uses IF `315.68c` by 15kazuki. Mega Tropius uses IF `556.556` by nighthawk3380. Their native cells were resolved locally with networking blocked, preserved and visually inspected. Ordinary Machamp and Tropius art remain untouched. Mirrored backs, identical shiny colours and the copied Tropiusite icon are placeholders. Credits remain third-party fan-art notices, not MIT relicensing.

Sources include `tools/import_mahoraga_tropius.py`, `*_Mahoraga_Tropius.txt`, `0400-CLI_Mahoraga_Tropius_Abilities.rb`, `0400-CLI_Mahoraga_Gift.rb` and the two native images. Ability wrappers install after plugins to avoid DBK/Gen 9 alias recursion.

## Checks and limits

The focused native Ruby preload harness passed with controlled handler fixtures. It checks move-specific per-hit learning, reset, fixed damage and healing paths. Release compilation validated the new PBS and scripts. Sprite contact sheet was inspected. These checks are not full live battles. No new browser gameplay or physical Safari verification is claimed.
