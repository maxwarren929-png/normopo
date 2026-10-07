# Banner controls and Pokémon storage

## Gacha navigation

The selected banner now shows its name and position, such as `2/3 Hoenn to Unova Champions`. Left/right changes one banner per press, with wraparound. Normanhurst uses a held-direction latch rather than depending solely on a trigger edge that may be missed during a fade. Input is captured before scene rendering.

The web frontend explicitly binds all four directions. Short direction taps stay down for at least 80 ms so slower game frames can sample them. Action taps retain the 50 ms minimum. Presses are sent immediately; only very short releases are extended.

The bitmap-font adapter creates a pixel-tinted atlas for a new colour. Gacha's old rainbow text requested a new colour every frame. In the browser this adds expensive work and can leave entire taps between input samples. The staged web build now draws a cached white label only when the banner changes and animates its GPU tone instead. The rainbow remains animated. Desktop font handling and animations are unchanged.

Enable this staging patch when rebuilding:

```sh
python3 tools/build_web_test.py --project normanhurst \
  --buffered-animation-load --defer-battle-animations --no-path-cache --gpu-gacha-text
```

This writes `pokemon-normanhurst-buffered-deferred-no-cache-gpu-gacha.mkxpz`. Export that archive, not an older build without the GPU-text flag.

Mobile layout still avoids renderer resizing on viewport changes. It initializes the backing buffer once when the player starts. Removing that startup initialization produced a black canvas in the software-rendered browser check, so it is retained.

## Storage PC

A stationary PC terminal stands at `[6,2]`, near the upper middle of the room. Face it and Confirm to open the standard Essentials PC menu, then choose the Pokémon storage PC and Organize Boxes, Withdraw or Deposit.

The room still has only two NPCs, the gacha and Gym Leader challenge scientists. The PC is an object with original CLI-drawn pixel art, not another character. Its source renderer is `tools/render_room_pc.py`.

A Normanhurst-only **PC** entry is also available in the pause menu in this room. It opens the same interface. This provides box access even if an older save retains a map without the new terminal, without requiring a new game or discarding its team. The pause shortcut uses the normal menu hide/refresh/show pattern; the direct terminal path was exercised in the browser.

The 30-pull budget, reward pools and Gym Leader teams are unchanged. Saving remains manual, and browser persistence across tab closure is still not established.

## Checks

Chrome touch emulation at 390×844 verified:

- All three banners in both directions, including right and left wraparound.
- Rates, one actual pull and the counter changing from 30 to 29.
- The PC terminal opening the standard Box 1 storage screen.
- The room layout, PC sprite and banner heading, with inspected screenshots.

These checks ran against a static `/normopo/` site. Physical Safari still needs user testing. No new claim is made about the earlier reported global speed-up after leaving gacha.

Python checks: 92 passing. Node checks: 25 passing. The browser probe now supports `--gameplay --mobile --gacha --banners --pc`. It needs Tesseract plus Python/Pillow. A PC-screen pixel landmark gives deterministic navigation rather than assuming a timed tap always moves one tile.
