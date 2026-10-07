'use strict';

// Runs before the COI worker and deferred player module, including on Safari.
const BOOTSTRAP = `<script>
(()=>{
 const key='cli-isolation-reloads:'+location.pathname;
 let attempts=0;
 try{attempts=Number(sessionStorage.getItem(key)||0)}catch{}
 const failure=()=>{
  const show=()=>{
   document.getElementById('cli-loading')?.remove();
   let message=document.getElementById('cli-startup-error');
   if(!message){message=document.createElement('p');message.id='cli-startup-error';message.style.cssText='position:fixed;inset:20px;z-index:2000;background:#111;color:white;padding:24px;font:18px system-ui';document.body.appendChild(message)}
   message.textContent='The browser could not enable the isolation required by this game. Automatic reloads have stopped. Open the site directly in a normal Safari tab, not an in-app browser. If this continues, try an updated browser.';
   if(!document.getElementById('cli-startup-retry')){const retry=document.createElement('button');retry.id='cli-startup-retry';retry.textContent='Retry startup';retry.style.cssText='position:fixed;bottom:40px;left:40px;z-index:2001;padding:12px;font:18px system-ui';retry.onclick=()=>{attempts=0;try{sessionStorage.removeItem(key)}catch{}window.__cliReload()};document.body.appendChild(retry)}
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',show,{once:true});else show();
 };
 window.__cliReload=()=>{
  if(attempts>=2){failure();return false}
  attempts++;
  try{sessionStorage.setItem(key,String(attempts))}catch{failure();return false}
  location.reload();return true;
 };
 // Every asset is same-origin. Safari does not need credentialless COEP.
 window.coi={...window.coi,coepCredentialless:()=>false,doReload:window.__cliReload};
 window.addEventListener('cli-player-ready',()=>{attempts=0;try{sessionStorage.removeItem(key)}catch{}});
})();
</script>`;
module.exports={BOOTSTRAP};
