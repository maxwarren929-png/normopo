'use strict';
const fs=require('node:fs');
const crypto=require('node:crypto');

function replaceOnce(source,before,after){
 if(source.split(before).length!==2)throw new Error('Upstream player changed: missing or repeated '+before);
 return source.replace(before,after);
}

function patchPlayerJS(source,identity){
 // Keep the known-working XP C binding; map physical Enter to it in the UI.
 source=replaceOnce(source,'input_player1_a:`c`','input_player1_a:`c`');
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
 // This marker is also used by the local timing/input probe.
 return source+'\nwindow.__cliNostalgist=Z;window.dispatchEvent(new Event("cli-player-ready"));\n';
}

const SUPPORT=`<style>
#cli-controls{position:fixed;z-index:1000;right:8px;top:8px;background:#111d;color:white;padding:6px 9px;font:12px sans-serif;border-radius:4px;opacity:.25}#cli-controls:hover,#cli-controls:focus-within{opacity:1}
#cli-loading{position:fixed;z-index:999;bottom:8%;width:100%;text-align:center;color:white;font:14px sans-serif;pointer-events:none}
</style><div id="cli-controls"><button type="button" id="cli-focus">Focus game</button> Enter: confirm · X/Esc: back · Z: menu · Arrows: move</div>
<p id="cli-loading">Loading Pokémon Normanhurst. Engine files are cached on this machine.</p>
<script>
(()=>{const held=new Map();const canvas=()=>window.__cliNostalgist?.getCanvas()||document.getElementById('nostalgist-canvas')||document.getElementById('canvas');
const releaseAll=()=>{for(const button of held.values())window.__cliNostalgist?.pressUp(button);held.clear()};
window.addEventListener('blur',releaseAll);document.addEventListener('visibilitychange',()=>{if(document.hidden)releaseAll()});
const focus=()=>{const c=canvas();if(c){c.tabIndex=0;c.focus({preventScroll:true})}};
document.getElementById('cli-focus').addEventListener('click',focus);
document.addEventListener('pointerdown',e=>{if(e.target===canvas())focus()});
window.addEventListener('cli-player-ready',()=>{document.getElementById('cli-loading')?.remove();focus()});
for(const type of ['keydown','keyup'])document.addEventListener(type,e=>{
 if(type==='keyup'&&held.has(e.code)){const alias=held.get(e.code);held.delete(e.code);window.__cliNostalgist?.pressUp(alias);e.preventDefault();e.stopImmediatePropagation();return}
 if(/^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)||e.target.isContentEditable)return;
 if(['Enter','ArrowUp','ArrowDown','ArrowLeft','ArrowRight',' '].includes(e.key))e.preventDefault();
 const alias=e.key==='Enter'?'a':e.key==='Escape'?'b':null;
 if(type==='keydown'&&alias&&window.__cliNostalgist){e.preventDefault();e.stopImmediatePropagation();if(!held.has(e.code)){held.set(e.code,alias);window.__cliNostalgist.pressDown(alias)}}
},true);
})();
</script>`;

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
   html=replaceOnce(html,'<title>mkxp-z-nostalgist</title>','<title>Pokémon Normanhurst</title>');
   return replaceOnce(html,'</body>',SUPPORT+'</body>');
  }
  if(pathname.endsWith('/assets/index-CHY6ZlLi.js'))return patchPlayerJS(body.toString('utf8'),await identity());
  return null;
 };
}
module.exports={createFrontendTransform,patchPlayerJS,replaceOnce,SUPPORT};
