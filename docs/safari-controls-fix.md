# Safari layout and input fixes

The reported problem was the whole page bouncing on Safari, plus slow or unreliable controls and apparent speed changes around gacha.

## Changes

- Mobile layout uses a fixed body and Safari's stable small-viewport height. The portrait game stays at a fixed top position instead of moving whenever Safari's toolbar changes height.
- Game dimensions now live in CSS rules backed by custom properties. Emscripten can no longer undo the fit by removing inline width/height. Mobile layout no longer requests a canvas backing-buffer resize on every viewport event.
- Height-only viewport changes no longer release held directions. Orientation/layout transitions, cancellation, blur and hidden tabs still release them.
- Touch action taps have a 50 ms minimum, directions 32 ms, rather than 100/40 ms. A new tap no longer silently merges into an old pending release. Repeated keydowns remain ignored.
- Enter, Space and C confirm. Escape and X go back. Z opens the game menu or gacha rates. Arrows move. These bindings use the same paired input path and reference counting as the touch controls. Editable HTML fields are excluded.
- Inherited Space/L fast-forward and G/E slow-motion shortcuts are disabled. The gacha plugin does not change the global frame rate. The exact cause of the reported gacha speed change was not reproduced on the physical phone.
- The COI worker uses `require-corp`, not credentialless mode, because all assets are same-origin. This avoids relying on Safari support for credentialless isolation.
- Removed the unconditional extra preparation reload. All remaining automatic reload paths share a two-attempt limit across page loads. Failure displays an explanation and an explicit Retry startup button instead of reloading forever. Successful game startup clears the retry counter.

The game archive is unchanged, SHA-256 `f8af5d222047a9d2fbcbaa270f62a7764da366b1e67f6545a40baaa9f31061a1`. The two NPCs, gacha budget and Gym Leader mechanics are unchanged.

## Checks and limits

Targeted Node checks: 24 passing. Static-export checks: 9 passing. No additional gameplay/browser probes or physical Safari tests were run for this patch. Earlier screenshots document the old mobile layout, not this revised placement.

Close the old game tab and reopen the site to load the revised frontend. Browser-level crash messages such as "A problem occurred with this webpage so it was reloaded" are different from the JavaScript startup loop. Safari may still hit memory limits with this large reference-Ruby build; this patch cannot promise to prevent browser crashes.
