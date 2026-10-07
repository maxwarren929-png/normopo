// Isolated local/Pages browser probe; never sends game data upstream.
const {chromium}=require(process.env.PLAYWRIGHT_CORE||'playwright-core');
const fs=require('fs'),path=require('path');
const {execFileSync}=require('node:child_process');
const {createPlayerServer,ENTRY}=require('./serve_web_player.cjs');
const {createFrontendTransform}=require('./web_player_frontend.cjs');
(async()=>{
 const archive=path.resolve(process.env.WEB_ARCHIVE||'normanhurst/build/web-player-review/pokemon-normanhurst-buffered-deferred-no-cache.mkxpz');
 const output=path.resolve(process.env.WEB_OUTPUT||path.dirname(archive));fs.mkdirSync(output,{recursive:true});
 let server,c,url=process.env.WEB_URL;
 const mobile=process.argv.includes('--mobile');
 const viewport=mobile?{width:390,height:844}:{width:1100,height:850};
 const lines=[],requests=[];const started=Date.now();
 const record=s=>{lines.push(s);fs.writeFileSync(path.join(output,'local-player.log'),lines.join('\n'))};
 try{
 if(!url){
  server=createPlayerServer({archive,transformAsset:createFrontendTransform(archive)}).server;
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  url='http://127.0.0.1:'+server.address().port+ENTRY;
 }
 c=await chromium.launchPersistentContext(process.env.WEB_BROWSER_PROFILE||path.join(output,'local-player-profile'),{executablePath:process.env.CHROME||'/usr/bin/google-chrome-stable',headless:process.env.WEB_HEADLESS==='1',viewport,hasTouch:mobile,isMobile:mobile,deviceScaleFactor:mobile?2:1,args:['--no-sandbox','--ozone-platform=wayland','--enable-webgl','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const p=c.pages()[0]||await c.newPage();
 p.on('console',m=>{record(m.type()+': '+m.text());if(/Exception|WARNING|Mounted|RGSS version/.test(m.text()))console.log(m.text())});
 p.on('pageerror',e=>{record('pageerror: '+e.message+' '+e.stack);console.log(e.message+' '+e.stack)});
 p.on('dialog',async d=>{record('dialog: '+d.message());await d.accept()});
 p.on('request',r=>requests.push(r.url()));
 p.on('requestfailed',r=>{const message='request failed: '+r.url()+' '+r.failure()?.errorText;record(message);console.log(message)});
 await p.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
 await p.waitForTimeout(1000);
 if(mobile)await p.touchscreen.tap(viewport.width/2,viewport.height/2);
 else await p.mouse.click(viewport.width/2,viewport.height/2,{delay:100});
 await p.waitForFunction(()=>!!window.__cliNostalgist,null,{timeout:180000});
 const preparedSeconds=(Date.now()-started)/1000;
 for(let i=0;i<180&&!lines.some(s=>s.includes('SET_GEOMETRY: 512x384'));i++)await p.waitForTimeout(1000);
 if(!lines.some(s=>s.includes('SET_GEOMETRY: 512x384')))throw new Error('Game initialization did not reach resize_screen');
 const readySeconds=(Date.now()-started)/1000;
 await p.waitForTimeout(15000);await p.screenshot({path:path.join(output,'local-player.png'),timeout:15000});
 const touchSession=mobile?await c.newCDPSession(p):null;
 const touch=async(button,delay=250)=>{
  const box=await p.locator('#cli-touch [data-game-button="'+button+'"]').boundingBox();
  if(!box)throw new Error('Touch control is not visible: '+button);
  await touchSession.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:box.x+box.width/2,y:box.y+box.height/2,id:1}]});
  await p.waitForTimeout(delay);
  await touchSession.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 };
 const key=async k=>{if(mobile)await touch({Enter:'a',Escape:'b',z:'x',ArrowDown:'down',ArrowUp:'up',ArrowLeft:'left',ArrowRight:'right'}[k]);else await p.keyboard.press(k,{delay:250});await p.waitForTimeout(500)};
 await key('Enter');await p.waitForTimeout(5000);await p.screenshot({path:path.join(output,'local-player-enter.png'),timeout:15000});
 if(process.argv.includes('--gameplay')){
  await key('Enter');await p.waitForTimeout(6000);
  await p.screenshot({path:path.join(output,'local-player-map.png'),timeout:15000});
  const worldPosition=async()=>{
   const code='import sys,json,io\nfrom PIL import Image\ni=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert("RGB")\np=[(n%i.width,n//i.width) for n,c in enumerate(i.getdata()) if c==(35,107,118)]\nif not p: raise RuntimeError("PC screen not visible")\nx=sum(v[0] for v in p)/len(p)*512/i.width\ny=sum(v[1] for v in p)/len(p)*384/i.height\nprint(json.dumps({"x":round(6-(x-255.5)/32),"y":round(2-(y-177)/32)}))';
   return JSON.parse(execFileSync('python3',['-W','ignore::DeprecationWarning','-c',code],{input:await p.locator('canvas').screenshot()}).toString());
  };
  const walkWorld=async(direction,delay=100)=>{if(mobile)await touch(direction,delay);else await p.keyboard.press({up:'ArrowUp',down:'ArrowDown',right:'ArrowRight',left:'ArrowLeft'}[direction],{delay});await p.waitForTimeout(600)};
  const reach=async(x,y)=>{for(let i=0;i<30;i++){const at=await worldPosition();if(at.x===x&&at.y===y)return;await walkWorld(at.y!==y?(at.y>y?'up':'down'):(at.x>x?'left':'right'))}throw new Error('Could not reach room position '+x+','+y)};
  if(process.argv.includes('--challenges')){
   await reach(2,6);await walkWorld('down',200);await key('Enter');await p.waitForTimeout(1500);
   await p.screenshot({path:path.join(output,'local-challenge-roster.png'),timeout:15000});
   await key('Escape');
  }
  if(process.argv.includes('--gacha')){
   const step=async(direction,delay)=>{if(mobile)await touch(direction,delay);else await p.keyboard.press({up:'ArrowUp',right:'ArrowRight',left:'ArrowLeft'}[direction],{delay});await p.waitForTimeout(600)};
   // Anchor at the eastern map edge (11,5), step west, then walk north
   // to the gacha scientist (10,2). Stable event positions survive room cleanup.
   if(process.argv.includes('--banners')||process.argv.includes('--pc')){await reach(10,5);await walkWorld('up',1000)}
   else{await step('right',1800);await step('left',100);await step('up',1800)}
   await key('Enter');await p.waitForTimeout(6000);
   await p.screenshot({path:path.join(output,'local-gacha-grant.png'),timeout:15000});
   await key('Enter');await p.waitForTimeout(6000);
   await p.screenshot({path:path.join(output,'local-gacha-choice.png'),timeout:15000});
   await key('Enter');await p.waitForTimeout(4000);
   const ocr=async()=>execFileSync('tesseract',['stdin','stdout','--psm','11'],{input:await p.locator('canvas').screenshot(),stdio:['pipe','pipe','ignore']}).toString();
   let text=await ocr();
   for(let i=0;i<5&&!/[pf]ulls\s+left:\s*30/i.test(text);i++){await key('Enter');await p.waitForTimeout(2000);text=await ocr()}
   if(!/[pf]ulls\s+left:\s*30/i.test(text))throw new Error('Gacha 30-pull overlay was not found: '+text);
   await p.screenshot({path:path.join(output,'local-gacha-pool.png'),timeout:15000});
   if(process.argv.includes('--banners')){
    for(const [i,direction,name] of [[1,'ArrowRight',/Hoenn/i],[2,'ArrowRight',/[PF]aldea/i],[3,'ArrowRight',/K[ao]nto/i],[4,'ArrowLeft',/[PF]aldea/i],[5,'ArrowLeft',/Hoenn/i],[6,'ArrowLeft',/K[ao]nto/i]]){
     await key(direction);await p.waitForTimeout(1200);text=await ocr();
     if(!name.test(text))throw new Error('Banner navigation step '+i+' failed: '+text);
     await p.screenshot({path:path.join(output,'local-gacha-banner-'+i+'.png'),timeout:15000});
    }
    record('Verified all three banners in both directions, including wraparound.');
   }
   await key('z');await p.waitForTimeout(2000);
   await p.screenshot({path:path.join(output,'local-gacha-rates.png'),timeout:15000});
   await key('Escape');await p.waitForTimeout(1000);
   await key('Enter');await p.waitForTimeout(4000);
   await p.screenshot({path:path.join(output,'local-gacha-roll-choice.png'),timeout:15000});
   await key('Enter');await p.waitForTimeout(7000);
   await p.screenshot({path:path.join(output,'local-gacha-reward.png'),timeout:15000});
   text=await ocr();
   for(let i=0;i<5&&!/[pf]ulls\s+left:\s*29/i.test(text);i++){await key('Enter');await p.waitForTimeout(2000);text=await ocr()}
   if(!/[pf]ulls\s+left:\s*29/i.test(text))throw new Error('A single gacha pull did not reach 29 remaining: '+text);
   record('Verified browser gacha: 30 tickets granted, single pull leaves 29.');
   await p.screenshot({path:path.join(output,'local-gacha-after-pull.png'),timeout:15000});
   await key('Escape');await p.waitForTimeout(1000);
  }
  if(process.argv.includes('--pc')){
   if(!process.argv.includes('--gacha'))throw new Error('--pc currently requires --gacha');
   await reach(6,3);await walkWorld('up',200);await key('Enter');await p.waitForTimeout(2000);
   await p.screenshot({path:path.join(output,'local-pc-boot.png'),timeout:15000});
   for(let i=0;i<4;i++){await key('Enter');await p.waitForTimeout(1500)}
   await p.screenshot({path:path.join(output,'local-pc-boxes.png'),timeout:15000});
   await key('Escape');await key('Escape');await key('Escape');
  }
  if(mobile)await touch('down',300);else await p.keyboard.press('ArrowDown',{delay:300});await p.waitForTimeout(500);
  await p.screenshot({path:path.join(output,'local-player-walk.png'),timeout:15000});
  await key('z');await p.waitForTimeout(500);
  await p.screenshot({path:path.join(output,'local-player-menu.png'),timeout:15000});
  await key('Escape');await p.waitForTimeout(500);
  await p.screenshot({path:path.join(output,'local-player-back.png'),timeout:15000});
  if(mobile){
   await p.setViewportSize({width:844,height:390});await p.waitForTimeout(1500);
   await p.screenshot({path:path.join(output,'local-player-landscape.png'),timeout:15000});
   await key('z');await p.waitForTimeout(500);
   await p.screenshot({path:path.join(output,'local-player-landscape-menu.png'),timeout:15000});
   await key('Escape');
  }
 }
 fs.writeFileSync(path.join(output,'web-timing.json'),JSON.stringify({url,mobile,preparedSeconds,readySeconds,layout:await p.evaluate(()=>({mode:document.body.dataset.cliLayout,canvas:{width:window.__cliNostalgist.getCanvas().width,height:window.__cliNostalgist.getCanvas().height},rect:window.__cliNostalgist.getCanvas().getBoundingClientRect().toJSON()})),requests,resources:await p.evaluate(()=>performance.getEntriesByType('resource').map(r=>({url:r.name,durationMs:r.duration,transferBytes:r.transferSize,encodedBytes:r.encodedBodySize})))},null,2));
 console.log('Player ready in '+readySeconds+' seconds. Screenshots: '+output);
 }finally{if(c)await c.close().catch(()=>{});if(server){server.closeAllConnections();await new Promise(resolve=>server.close(resolve))}}
})().catch(e=>{console.error(e);process.exit(1)});
