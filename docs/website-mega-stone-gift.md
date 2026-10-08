# Website Mega Stone gift

The GitHub website build gives each save one of every registered item with the MegaStone flag, plus a Mega Ring. This includes Venusaurite X and the ordinary Mega Stones. Red Orb and Blue Orb are not Mega Stones and are not included.

The gift arrives silently in the Bag when the overworld first updates, after either New Game or Continue. Older saves qualify. The saved completion flag prevents repeat gifts; already-present items are not duplicated. If the Bag is full, missing items retry every two seconds and the gift is not marked complete prematurely. Save manually to retain the gift with the rest of your progress.

Give a compatible Pokémon its stone from the Bag, then choose Use my party at the challenge scientist. In the staged website build, the temporary challenge Bag keeps your Mega Ring so player Mega Evolution is eligible. The no-Bag rule still blocks consumable use. The original Bag and team are restored afterward, and the existing DBK Mega presentation is unchanged.

This is a staged website-only change. It does not grant items in desktop Demo, desktop Normanhurst or Hornsby, does not alter the gacha pools or 30-pull cap, and does not add items to the temporary battle Bag through the gift handler.

## Rebuild

```sh
python3 tools/build_web_test.py --project normanhurst \
  --buffered-animation-load --defer-battle-animations --no-path-cache \
  --gpu-gacha-text --web-mega-gift
```

Export the archive ending `-gpu-gacha-web-mega-gift.mkxpz`. The builder appends `tools/web_mega_gift.rb` only to the staged gacha script, and patches only the staged challenge Bag initialization to retain the Mega Ring. Both changes fail closed if the expected script layout is absent. Original desktop scripts remain unchanged.

The isolated Ruby gift check covers ordinary/custom stones, the Mega Ring, excluded non-stones, duplicate prevention, a full-Bag retry and avoiding the temporary battle Bag. Browser gameplay and physical Safari Mega Evolution have not been newly verified for this gift.
