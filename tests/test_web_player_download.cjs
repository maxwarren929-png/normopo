'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {downloadPlayerAsset}=require('../tools/web_player_download.cjs');
test('body read failure retries and rolls back partial progress',async()=>{
 const old={fetch:global.fetch,setTimeout:global.setTimeout,location:global.location};
 let calls=0,rollbacks=0;
 global.location={href:'https://example.test/normopo/'};
 global.setTimeout=fn=>fn();
 global.fetch=async()=>{calls++;return {ok:true,blob:async()=>{if(calls<2)throw new TypeError('Failed to fetch');return 'whole body'}}};
 try{assert.equal(await downloadPlayerAsset('./core.wasm',r=>r.blob(),()=>rollbacks++),'whole body');assert.equal(calls,2);assert.equal(rollbacks,1)}finally{Object.assign(global,old)}
});
test('three failures name the asset and show retry UI event without deleting saves',async()=>{
 const old={fetch:global.fetch,setTimeout:global.setTimeout,location:global.location,window:global.window,CustomEvent:global.CustomEvent};
 let calls=0,event;
 global.location={href:'https://example.test/normopo/'};global.setTimeout=fn=>fn();
 global.CustomEvent=class{constructor(type,options){this.type=type;this.detail=options.detail}};
 global.window={dispatchEvent:e=>event=e};global.fetch=async()=>{calls++;throw new TypeError('Failed to fetch')};
 try{await assert.rejects(downloadPlayerAsset('./core.wasm',()=>{},()=>{}),/core.wasm after 3 attempts/);assert.equal(calls,3);assert.equal(event.type,'cli-download-error');assert.match(event.detail,/Failed to fetch/)}finally{Object.assign(global,old)}
});
test('caller abort and already exhausted chunk retries are not retried again',async()=>{
 const old=global.fetch;
 try{for(const err of [Object.assign(new Error('cancelled'),{name:'AbortError'}),Object.assign(new Error('chunk exhausted'),{cliDownloadFinal:true})]){
 let calls=0;global.fetch=async()=>{calls++;throw err};await assert.rejects(downloadPlayerAsset('url',()=>{},()=>{}),e=>e===err);assert.equal(calls,1)
 }}finally{global.fetch=old}
});
