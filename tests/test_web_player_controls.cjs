'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const {SUPPORT} = require('../tools/web_player_controls.cjs');

function harness({width=390,height=844,coarse=true,prepared=true}={}) {
 const calls=[],sizes=[],timers=new Map();let now=0,nextTimer=0;
 const node = (tagName='BUTTON') => ({tagName,dataset:{},disabled:true,listeners:{},style:{cssText:'image-rendering:pixelated',values:{},setProperty(k,v){this.values[k]=v}},addEventListener(type,fn){(this.listeners[type]??=[]).push(fn)},focus(){},setPointerCapture(){},remove(){this.removed=true}});
 const canvas=node('CANVAS'),focus=node(),loading=node('P');
 const buttons=['up','down','left','right','a','b','x'].map(button=>{const n=node();n.dataset.gameButton=button;return n});
 const media={matches:coarse,addEventListener(){}};
 const document=node('DOCUMENT');document.body={dataset:{}};
 document.querySelectorAll=()=>buttons;
 document.getElementById=id=>id==='cli-focus'?focus:id==='cli-loading'?loading:canvas;
 const window=node('WINDOW');Object.assign(window,{innerWidth:width,innerHeight:height,matchMedia:()=>media});
 const engine={getCanvas:()=>canvas,pressDown:b=>calls.push(['down',b]),pressUp:b=>calls.push(['up',b]),resize:s=>sizes.push({...s})};
 if(prepared)window.__cliNostalgist=engine;
 const advance=ms=>{now+=ms;for(const [id,timer] of timers)if(timer.at<=now){timers.delete(id);timer.fn()}};
 vm.runInNewContext(SUPPORT.match(/<script>([\s\S]*)<\/script>/)[1],{window,document,Map,WeakMap,Set,performance:{now:()=>now},setTimeout:(fn,delay)=>{const id=++nextTimer;timers.set(id,{fn,at:now+delay});return id},clearTimeout:id=>timers.delete(id)});
 const fire=(target,type,props={})=>{const e={target,button:0,pointerId:1,preventDefault(){this.prevented=true},stopImmediatePropagation(){this.stopped=true},...props};for(const fn of target.listeners[type]??[])fn(e);return e};
 const button=b=>buttons.find(n=>n.dataset.gameButton===b);
 const down=(b,id=1)=>fire(button(b),'pointerdown',{pointerId:id});
 const up=(id=1,type='pointerup')=>{advance(100);return fire(document,type,{pointerId:id})};
 const key=(type,key='Enter',target=canvas,extra={})=>fire(document,type,{key,code:key,target,...extra});
 return {window,document,canvas,buttons,loading,calls,sizes,engine,fire,button,down,up,key,advance};
}

test('phone layout reserves touch space, native backing buffer, and disabled-until-prepared controls',()=>{
 const h=harness({prepared:false});
 assert.equal(h.document.body.dataset.cliLayout,'portrait');
 assert.equal(h.canvas.style.values['--cli-width'],'366px');
 assert.equal(h.canvas.style.values['--cli-height'],'274px');
 assert.equal(h.buttons.every(b=>b.disabled),true);
 h.down('a');assert.deepEqual(h.calls,[]);
 h.window.__cliNostalgist=h.engine;h.fire(h.window,'cli-player-ready');
 assert.equal(h.buttons.every(b=>!b.disabled),true);
 assert.deepEqual(h.sizes,[]);
});

test('paired pointer inputs and multi-touch release independently',()=>{
 const h=harness();h.down('left',1);h.down('a',2);
 assert.equal(h.button('left').dataset.held,'true');
 h.up(1);assert.equal(h.button('left').dataset.held,'false');
 h.up(2);
 assert.deepEqual(h.calls,[['down','left'],['down','a'],['up','left'],['up','a']]);
});

test('same virtual button is reference counted across keyboard and multiple fingers',()=>{
 const h=harness();h.key('keydown');h.down('a',3);h.down('a',4);
 h.key('keyup');h.up(3);assert.deepEqual(h.calls,[['down','a']]);
 h.up(4);assert.deepEqual(h.calls,[['down','a'],['up','a']]);
});

test('pointer cancellation, capture loss, blur and hidden document release held input',()=>{
 const h=harness();h.down('right');h.up(1,'pointercancel');h.up();
 h.down('down',2);h.fire(h.button('down'),'lostpointercapture',{pointerId:2});
 h.down('a',3);h.down('b',4);h.fire(h.window,'blur');
 h.down('x',5);h.document.hidden=true;h.fire(h.document,'visibilitychange');
 assert.deepEqual(h.calls,[['down','right'],['up','right'],['down','down'],['up','down'],['down','a'],['down','b'],['up','a'],['up','b'],['down','x'],['up','x']]);
});

test('keyboard repeats are ignored and keyup releases even after focus moves to an input',()=>{
 const h=harness();h.key('keydown');h.key('keydown','Enter',h.canvas,{repeat:true});
 h.key('keyup','Enter',{tagName:'INPUT'});
 h.key('keydown','Escape',{tagName:'TEXTAREA'});
 assert.deepEqual(h.calls,[['down','a'],['up','a']]);
});

test('orientation change releases held input and landscape fits between control panels',()=>{
 const h=harness();h.down('left');h.window.innerWidth=844;h.window.innerHeight=390;h.fire(h.window,'resize');
 assert.deepEqual(h.calls,[['down','left'],['up','left']]);
 assert.equal(h.document.body.dataset.cliLayout,'landscape');
 assert.equal(h.canvas.style.values['--cli-width'],'445px');
 assert.equal(h.canvas.style.values['--cli-height'],'334px');
 assert.equal(h.canvas.style.values['--cli-top'],'36px');
});

test('desktop layout remains untouched and leaving a narrow layout restores styles',()=>{
 const h=harness({width:1100,height:850,coarse:false});
 assert.equal(h.document.body.dataset.cliLayout,undefined);
 assert.deepEqual(h.sizes,[]);
 h.window.innerWidth=600;h.fire(h.window,'resize');
 assert.equal(h.document.body.dataset.cliLayout,'portrait');
 h.window.innerWidth=1100;h.fire(h.window,'resize');
 assert.equal(h.document.body.dataset.cliLayout,undefined);
 assert.equal(h.canvas.style.cssText,'image-rendering:pixelated');
 assert.deepEqual(h.sizes.at(-1),{width:1100,height:850});
});

test('brief taps last at least 50ms and normal capture loss does not cut them short',()=>{
 const h=harness();h.down('a');h.fire(h.document,'pointerup');
 h.fire(h.button('a'),'lostpointercapture');
 h.advance(49);assert.deepEqual(h.calls,[['down','a']]);
 h.advance(1);assert.deepEqual(h.calls,[['down','a'],['up','a']]);
});

test('Safari height-only viewport changes keep held input and fixed portrait placement',()=>{
 const h=harness();h.down('up');h.window.innerHeight=744;h.fire(h.window,'resize');
 assert.deepEqual(h.calls,[['down','up']]);assert.equal(h.canvas.style.values['--cli-top'],'56px');assert.deepEqual(h.sizes,[]);h.up();
});

test('common keyboard bindings share the same reference count as touch',()=>{
 const h=harness();h.key('keydown','ArrowUp');h.down('up',2);h.key('keyup','ArrowUp');h.up(2);
 h.key('keydown',' ');h.key('keyup',' ');h.key('keydown','z');h.key('keyup','z');
 assert.deepEqual(h.calls,[['down','up'],['up','up'],['down','a'],['up','a'],['down','x'],['up','x']]);
});

test('a new tap does not silently merge into a previous pending release',()=>{
 const h=harness();h.down('a');h.fire(h.document,'pointerup');h.advance(40);h.down('a');
 assert.deepEqual(h.calls,[['down','a'],['up','a'],['down','a']]);h.up();
});

test('pending tap releases are cancelled immediately on blur or pointer cancellation',()=>{
 const h=harness();h.down('right');h.fire(h.document,'pointerup');h.fire(h.window,'blur');h.advance(100);
 h.down('left',2);h.fire(h.document,'pointercancel',{pointerId:2});h.advance(100);
 assert.deepEqual(h.calls,[['down','right'],['up','right'],['down','left'],['up','left']]);
});
