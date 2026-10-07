'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const {patchPlayerJS,createFrontendTransform}=require('../tools/web_player_frontend.cjs');
const fixture='input_player1_a:`c`;element:`#nostalgist-canvas`,retroarchConfig: {};xn=new URL(`./Standard.mkxpz`,location.href).toString();wn=22882414,Dn=`5ef70c0075ace21ee105a48f616cb067a66a4a0b46ce8e9051869794ccd5a579`;kn=`KNight-Blade: Howling of Kerberos`;try{return await navigator.storage.getDirectory()};var Q=document.getElementById(`gamepad-target`);input_toggle_fast_forward:`space`,input_hold_fast_forward:`l`,input_toggle_slowmotion:`g`,input_hold_slowmotion:`e`;e.persisted&&location.reload();if(window.sessionStorage.getItem(Un)!==`ready`)throw window.sessionStorage.setItem(Un,`ready`),location.reload(),`Reloading once to make coi-serviceworker.js less flaky`;location.reload(),`Reloading to enable cross-origin isolation`;';
test('Enter UI alias, canvas keyboard focus, sample RTP removal, and actual game identity',()=>{
 const result=patchPlayerJS(fixture,{size:12345,sha256:'abc123'});
 assert.match(result,/input_player1_a:`c`/);
 assert.doesNotMatch(result,/respondToGlobalEvents:!0/);
 assert.match(result,/xn=null/);
 assert.match(result,/var Q=null/);
 assert.match(result,/try\{return null\}/);
 assert.match(result,/wn=12345/);
 assert.match(result,/Dn=`abc123`/);
 assert.match(result,/kn=`Pokémon Normanhurst`/);
 assert.match(result,/cli-player-ready/);
 assert.match(fixture,/input_player1_a:`c`/);
});
test('unexpected upstream layout fails closed',()=>{
 assert.throws(()=>patchPlayerJS(fixture.replace('input_player1_a:`c`','input_player1_a:`z`'),{size:1,sha256:'x'}),/Upstream player changed/);
});
test('frontend transform changes game identity after replacing the archive',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'web-frontend-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const archive=path.join(root,'game.mkxpz');await fs.writeFile(archive,'first game');
 const transform=createFrontendTransform(archive);
 const args={url:'https://white-axe.github.io/mkxp-z-libretro-emscripten/nostalgist-knight-blade-howling-of-kerberos/assets/index-CHY6ZlLi.js',body:Buffer.from(fixture),contentType:'application/javascript'};
 const first=await transform(args);assert.ok(first.includes(crypto.createHash('sha256').update('first game').digest('hex')));
 await fs.writeFile(archive,'replacement game');const next=await transform(args);
 assert.notEqual(first,next);assert.match(next,/wn=16,/);
 assert.ok(next.includes(crypto.createHash('sha256').update('replacement game').digest('hex')));
});
test('HTML gets controls/focus and other assets stay unchanged',async()=>{
 const transform=createFrontendTransform('/unused');
 const html=await transform({url:'https://white-axe.github.io/mkxp-z-libretro-emscripten/nostalgist-knight-blade-howling-of-kerberos/',contentType:'text/html',body:Buffer.from('<title>mkxp-z-nostalgist</title><body></body>')});
 assert.match(html,/Focus game/);assert.match(html,/Enter: confirm/);
 assert.ok(html.includes("escape:'b'"));assert.ok(html.includes("enter:'a'"));
 assert.match(html,/coepCredentialless:\(\)=>false/);
 assert.match(html,/pressDown\(button\)/);
 assert.match(html,/pressUp\(button\)/);
 assert.match(html,/held.has\(id\)/);
 assert.match(html,/id="cli-touch"/);
 assert.equal(await transform({url:'https://white-axe.github.io/mkxp-z-libretro-emscripten/other.css',contentType:'text/css',body:Buffer.from('body{}')}),null);
});
