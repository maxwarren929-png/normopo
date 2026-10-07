'use strict';

// Inline UI is shared by the localhost proxy and static Pages exporter.
// Native engine/game code is unchanged. Pointer IDs and key codes pair inputs.
const SUPPORT = `<style>
#cli-controls{position:fixed;z-index:1000;right:8px;top:8px;background:#111d;color:white;padding:6px 9px;font:12px sans-serif;border-radius:4px;opacity:.25}
#cli-controls:hover,#cli-controls:focus-within{opacity:1}
#cli-loading{position:fixed;z-index:999;bottom:8%;width:100%;text-align:center;color:white;font:14px sans-serif;pointer-events:none}
#gamepad-target{display:none!important}
#cli-touch{display:none;position:absolute;inset:0;z-index:1000;pointer-events:none}
#cli-touch button{pointer-events:auto;touch-action:none;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;min-width:44px;min-height:44px;border:1px solid #a6adc2;border-radius:12px;color:#fff;background:#202839e8;font:600 15px system-ui,sans-serif;padding:8px}
#cli-touch button:disabled{opacity:.4}
#cli-touch button[data-held=true]{background:#4368a2;border-color:#d3e5ff}
#cli-dpad{position:absolute;display:grid;grid-template-columns:repeat(3,48px);grid-template-rows:repeat(3,48px);gap:3px;left:max(12px,env(safe-area-inset-left));bottom:max(20px,env(safe-area-inset-bottom))}
#cli-dpad [data-game-button=up]{grid-column:2;grid-row:1}
#cli-dpad [data-game-button=left]{grid-column:1;grid-row:2}
#cli-dpad [data-game-button=right]{grid-column:3;grid-row:2}
#cli-dpad [data-game-button=down]{grid-column:2;grid-row:3}
#cli-actions{position:absolute;display:grid;grid-template-columns:repeat(2,64px);gap:8px;right:max(12px,env(safe-area-inset-right));bottom:max(38px,env(safe-area-inset-bottom))}
#cli-actions [data-game-button=a]{grid-column:1/3;min-height:60px;background:#254944e8}
body[data-cli-layout]{position:fixed;inset:0;bottom:auto;width:100%;height:100%;height:100svh;margin:0;overflow:hidden;overscroll-behavior:none;touch-action:none;background:#000}
body[data-cli-layout] #nostalgist-canvas,body[data-cli-layout] #canvas{position:fixed!important;left:var(--cli-left)!important;top:var(--cli-top)!important;width:var(--cli-width)!important;height:var(--cli-height)!important;object-fit:contain!important;image-rendering:pixelated!important}
body[data-cli-layout] #cli-touch{display:block}
body[data-cli-layout] #cli-controls{opacity:1;top:max(6px,env(safe-area-inset-top))}
body[data-cli-layout] #cli-keyboard-help{display:none}
body[data-cli-layout] #cli-loading{bottom:auto;top:50px;padding:0 12px;box-sizing:border-box;font-size:12px}
body[data-cli-layout=landscape] #cli-dpad{top:calc(50% - 75px);bottom:auto}
body[data-cli-layout=landscape] #cli-actions{top:calc(50% - 58px);bottom:auto}
</style>
<div id="cli-controls"><button type="button" id="cli-focus">Focus game</button><span id="cli-keyboard-help"> Enter: confirm · X/Esc: back · Z: menu · Arrows: move</span></div>
<p id="cli-loading">Loading Pokémon Normanhurst. First load is large. Wait for the title screen.</p>
<div id="cli-touch" role="group" aria-label="Touch game controls">
 <div id="cli-dpad" role="group" aria-label="Movement">
  <button type="button" data-game-button="up" aria-label="Move up" disabled>↑</button>
  <button type="button" data-game-button="left" aria-label="Move left" disabled>←</button>
  <button type="button" data-game-button="right" aria-label="Move right" disabled>→</button>
  <button type="button" data-game-button="down" aria-label="Move down" disabled>↓</button>
 </div>
 <div id="cli-actions">
  <button type="button" data-game-button="a" aria-label="Confirm or interact" disabled>Confirm</button>
  <button type="button" data-game-button="b" aria-label="Back or cancel" disabled>Back</button>
  <button type="button" data-game-button="x" aria-label="Open menu" disabled>Menu</button>
 </div>
</div>
<script>
(()=>{
 const held=new Map(),started=new Map(),pending=new Map(),savedStyles=new WeakMap();
 const buttons=[...document.querySelectorAll('#cli-touch [data-game-button]')];
 const canvas=()=>window.__cliNostalgist?.getCanvas()||document.getElementById('nostalgist-canvas')||document.getElementById('canvas');
 const focus=()=>{const c=canvas();if(c&&document.activeElement!==c){c.tabIndex=0;c.focus({preventScroll:true})}};
 const paint=()=>{for(const b of buttons)b.dataset.held=String([...held.values()].includes(b.dataset.gameButton))};
 const hold=(id,button)=>{if(!window.__cliNostalgist)return;if(pending.has(id))release(id);if(held.has(id))return;const already=[...held.values()].includes(button);held.set(id,button);started.set(id,performance.now());if(!already)window.__cliNostalgist.pressDown(button);paint()};
 const release=id=>{if(pending.has(id)){clearTimeout(pending.get(id));pending.delete(id)}const button=held.get(id);if(!button)return;held.delete(id);started.delete(id);if(![...held.values()].includes(button))window.__cliNostalgist?.pressUp(button);paint()};
 const pointerUp=id=>{const minimum=['up','down','left','right'].includes(held.get(id))?80:50;const delay=minimum-(performance.now()-(started.get(id)??0));if(delay>0){if(!pending.has(id))pending.set(id,setTimeout(()=>release(id),delay))}else release(id)};
 const releaseAll=()=>{for(const timer of pending.values())clearTimeout(timer);pending.clear();for(const button of new Set(held.values()))window.__cliNostalgist?.pressUp(button);held.clear();started.clear();paint()};
 window.addEventListener('blur',releaseAll);
 document.addEventListener('visibilitychange',()=>{if(document.hidden)releaseAll()});
 document.getElementById('cli-focus').addEventListener('click',focus);
 document.addEventListener('pointerdown',e=>{if(e.target===canvas())focus()});
 for(const b of buttons){
  b.addEventListener('pointerdown',e=>{if(e.button!==0||!window.__cliNostalgist)return;e.preventDefault();focus();hold('pointer:'+e.pointerId,b.dataset.gameButton);try{b.setPointerCapture(e.pointerId)}catch{}});
  b.addEventListener('lostpointercapture',e=>{const id='pointer:'+e.pointerId;if(!pending.has(id))release(id)});
  b.addEventListener('contextmenu',e=>e.preventDefault());
 }
 for(const type of ['pointerup','pointercancel'])document.addEventListener(type,e=>{const id='pointer:'+e.pointerId;if(held.has(id)){e.preventDefault();if(type==='pointerup')pointerUp(id);else release(id)}},true);
 for(const type of ['keydown','keyup'])document.addEventListener(type,e=>{
  const id='key:'+e.code;
  if(type==='keyup'&&held.has(id)){release(id);e.preventDefault();e.stopImmediatePropagation();return}
  if(/^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)||e.target.isContentEditable)return;
  if(['Enter','ArrowUp','ArrowDown','ArrowLeft','ArrowRight',' '].includes(e.key))e.preventDefault();
  const alias=({enter:'a',' ':'a',escape:'b',c:'a',x:'b',z:'x',arrowup:'up',arrowdown:'down',arrowleft:'left',arrowright:'right'})[e.key.toLowerCase()];
  if(type==='keydown'&&alias&&window.__cliNostalgist){e.preventDefault();e.stopImmediatePropagation();hold(id,alias)}
 },true);
 const coarse=window.matchMedia('(any-pointer: coarse)');
 const layout=()=>{
  const mobile=coarse.matches||window.innerWidth<=720;
  const c=canvas();
  if(!mobile){delete document.body.dataset.cliLayout;if(c&&savedStyles.has(c)){c.style.cssText=savedStyles.get(c);savedStyles.delete(c);window.__cliNostalgist?.resize({width:window.innerWidth,height:window.innerHeight})}return}
  const landscape=window.innerWidth>window.innerHeight;
  document.body.dataset.cliLayout=landscape?'landscape':'portrait';
  if(!c)return;
  if(!savedStyles.has(c))savedStyles.set(c,c.style.cssText);
  const height=document.body.getBoundingClientRect?.().height||window.innerHeight;
  const availableWidth=Math.max(64,window.innerWidth-(landscape?340:24));
  const availableHeight=Math.max(48,height-(landscape?56:244));
  let scale=Math.min(availableWidth/512,availableHeight/384);
  if(scale>=1)scale=Math.floor(scale);
  const w=Math.floor(512*scale),h=Math.floor(384*scale);
  const top=landscape?Math.max(36,(height-h)/2):56;
  // CSS rules, not inline width/height: Emscripten removes those on resize.
  for(const [name,value] of Object.entries({'--cli-left':Math.floor((window.innerWidth-w)/2)+'px','--cli-top':Math.floor(top)+'px','--cli-width':w+'px','--cli-height':h+'px'}))c.style.setProperty(name,value);
 };
 let mode=(coarse.matches||window.innerWidth<=720)?(window.innerWidth>window.innerHeight?'landscape':'portrait'):'desktop';
 const changed=()=>{const next=(coarse.matches||window.innerWidth<=720)?(window.innerWidth>window.innerHeight?'landscape':'portrait'):'desktop';if(next!==mode){releaseAll();mode=next}layout()};
 window.addEventListener('resize',changed);
 coarse.addEventListener('change',changed);
 window.addEventListener('cli-player-ready',()=>{for(const b of buttons)b.disabled=false;document.getElementById('cli-loading')?.remove();if(coarse.matches||window.innerWidth<=720)window.__cliNostalgist?.resize({width:512,height:384});layout();focus()});
 layout();
})();
</script>`;

module.exports = { SUPPORT };
