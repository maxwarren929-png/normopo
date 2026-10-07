'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm');
const {BOOTSTRAP}=require('../tools/web_player_bootstrap.cjs');
function boot(storage=new Map(),blocked=false){
 let reloads=0;const listeners={},nodes=new Map();
 const window={addEventListener:(type,fn)=>listeners[type]=fn};
 const document={readyState:'complete',getElementById:id=>nodes.get(id),createElement:()=>({style:{}}),body:{appendChild:n=>nodes.set(n.id,n)}};
 const sessionStorage={getItem:k=>storage.get(k),setItem:(k,v)=>{if(blocked)throw Error('blocked');storage.set(k,v)},removeItem:k=>storage.delete(k)};
 vm.runInNewContext(BOOTSTRAP.match(/<script>([\s\S]*)<\/script>/)[1],{window,document,location:{pathname:'/normopo/',reload:()=>reloads++},sessionStorage});
 return{window,listeners,nodes,reloads:()=>reloads};
}
test('COI uses require-corp and at most two reloads across page loads',()=>{
 const storage=new Map();let b=boot(storage);assert.equal(b.window.coi.coepCredentialless(),false);
 assert.equal(b.window.__cliReload(),true);b=boot(storage);assert.equal(b.window.__cliReload(),true);
 b=boot(storage);assert.equal(b.window.__cliReload(),false);assert.equal(b.reloads(),0);
 assert.match(b.nodes.get('cli-startup-error').textContent,/Automatic reloads have stopped/);
});
test('successful startup clears retry state',()=>{
 const storage=new Map();const b=boot(storage);b.window.__cliReload();b.listeners['cli-player-ready']();assert.equal(storage.size,0);
});
test('blocked session storage cannot cause a reload loop',()=>{
 const b=boot(new Map(),true);assert.equal(b.window.__cliReload(),false);assert.equal(b.reloads(),0);
});
