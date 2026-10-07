'use strict';
const fs=require('node:fs');
const crypto=require('node:crypto');

function replaceOnce(source,before,after){
 if(source.split(before).length!==2)throw new Error('Upstream player changed: missing or repeated '+before);
 return source.replace(before,after);
}

function patchPlayerJS(source,identity){
 // Keep the known-working XP C binding; map physical Enter to it in the UI.
 source=replaceOnce(source,'input_player1_a:`c`','input_player1_up:`up`,input_player1_down:`down`,input_player1_left:`left`,input_player1_right:`right`,input_player1_a:`c`');
 source=replaceOnce(source,'element:`#nostalgist-canvas`,retroarchConfig:',
                    'element:`#nostalgist-canvas`,retroarchConfig:');
 // Normanhurst contains its own assets and does not use the XP sample RTP.
 source=replaceOnce(source,'xn=new URL(`./Standard.mkxpz`,location.href).toString()','xn=null');
 // Large ZIP indexes make thousands of seeks. MEMFS avoids synchronous OPFS
 // worker round trips; the upstream fallback persists saves with IDBFS.
 source=replaceOnce(source,'try{return await navigator.storage.getDirectory()}','try{return null}');
 source=replaceOnce(source,'wn=22882414,',`wn=${identity.size},`);
 source=replaceOnce(source,'Dn=`5ef70c0075ace21ee105a48f616cb067a66a4a0b46ce8e9051869794ccd5a579`',`Dn=\`${identity.sha256}\``);
 source=replaceOnce(source,'kn=`KNight-Blade: Howling of Kerberos`','kn=`Pokémon Normanhurst`');
 // Normal speed only. Space/L and G/E must not toggle global timing.
 for(const [setting,key] of [['input_toggle_fast_forward','space'],['input_hold_fast_forward','l'],['input_toggle_slowmotion','g'],['input_hold_slowmotion','e']])source=replaceOnce(source,setting+':`'+key+'`',setting+':`nul`');
 // Bound all automatic reloads, and remove the redundant preparation reload.
 source=replaceOnce(source,'e.persisted&&location.reload()','e.persisted&&window.__cliReload()');
 source=replaceOnce(source,'if(window.sessionStorage.getItem(Un)!==`ready`)throw window.sessionStorage.setItem(Un,`ready`),location.reload(),`Reloading once to make coi-serviceworker.js less flaky`;','try{window.sessionStorage.setItem(Un,`ready`)}catch{};');
 source=replaceOnce(source,'location.reload(),`Reloading to enable cross-origin isolation`','window.__cliReload(),`Cross-origin isolation unavailable`');
 // Replace the sample's tiny XYZ/save-state overlay with our labelled controls.
 source=replaceOnce(source,'var Q=document.getElementById(`gamepad-target`)','var Q=null');
 // This marker is also used by the local timing/input probe.
 return source+'\nwindow.__cliNostalgist=Z;window.dispatchEvent(new Event("cli-player-ready"));\n';
}

const {SUPPORT}=require('./web_player_controls.cjs');
const {BOOTSTRAP}=require('./web_player_bootstrap.cjs');

function createFrontendTransform(archive){
 let cached;
 async function identity(){
  const stat=await fs.promises.stat(archive,{bigint:true});
  const signature=String(stat.size)+':'+stat.mtimeNs+':'+stat.ctimeNs;
  if(!cached||cached.signature!==signature){
   const sha=crypto.createHash('sha256');
   for await(const chunk of fs.createReadStream(archive))sha.update(chunk);
   cached={signature,size:Number(stat.size),sha256:sha.digest('hex')};
  }
  return cached;
 }
 return async({url,body,contentType})=>{
  const pathname=new URL(url).pathname;
  if(/\/nostalgist-knight-blade-howling-of-kerberos\/$/.test(pathname)&&/text\/html/i.test(contentType)){
   let html=body.toString('utf8');
   html=replaceOnce(html,'<title>mkxp-z-nostalgist</title>',BOOTSTRAP+'<title>Pokémon Normanhurst</title>');
   return replaceOnce(html,'</body>',SUPPORT+'</body>');
  }
  if(pathname.endsWith('/assets/index-CHY6ZlLi.js'))return patchPlayerJS(body.toString('utf8'),await identity());
  return null;
 };
}
module.exports={createFrontendTransform,patchPlayerJS,replaceOnce,SUPPORT,BOOTSTRAP};
