const {chromium}=require('/home/ko/projects/fun/node_modules/playwright-core');
const fs=require('fs'),path=require('path'),http=require('http');
(async()=>{const root=path.resolve('normanhurst/build/web-player-review/pages-engine-chunks-release');
 const m=JSON.parse(fs.readFileSync(root+'/engine-manifest.json'));
 const server=http.createServer((req,res)=>{res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');const name=new URL(req.url,'http://localhost').pathname;const f=path.join(root,name==='/'?'index.html':name);try{res.setHeader('Content-Type',f.endsWith('.js')?'application/javascript':f.endsWith('.html')?'text/html':f.endsWith('.css')?'text/css':'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.writeHead(404).end()}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const b=await chromium.launch({executablePath:'/usr/bin/google-chrome-stable',headless:true,args:['--no-sandbox']});
 try{const c=await b.newContext();const p=await c.newPage();let largeDirect=0;const calls={};
 await p.route('**/assets/normanhurst-*.js',r=>r.fulfill({contentType:'application/javascript',body:''}));
 await p.route('**/mkxp-z_libretro.wasm',r=>{largeDirect++;return r.abort()});
 await p.route('**/engine-chunks/*.bin',r=>{const f=new URL(r.request().url()).pathname.split('/').pop();calls[f]=(calls[f]||0)+1;if(f.startsWith('00004-')&&calls[f]===1)return r.abort('failed');return r.continue()});
 await p.goto('http://127.0.0.1:'+server.address().port+'/',{waitUntil:'domcontentloaded'});
 const operation=p.evaluate(async()=>{const r=await fetch('mkxp-z_libretro.wasm');const bytes=await r.arrayBuffer();const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');await WebAssembly.compile(bytes);return {size:bytes.byteLength,sha256:hash,mime:r.headers.get('Content-Type'),browser_compile_passed:true}});
 await p.waitForFunction(()=>document.getElementById('cli-loading')?.textContent.includes('part 5 of'),{},{timeout:10000});
 fs.mkdirSync('normanhurst/build/engine-chunks-review',{recursive:true});
 await p.screenshot({path:'normanhurst/build/engine-chunks-review/downloading-engine.png'});
 const result=await operation;
 if(result.size!==m.size||result.sha256!==m.sha256||largeDirect!==0)throw Error(JSON.stringify({result,largeDirect}));
 for(const item of m.chunks){const f=item.url.split('/').pop();if(calls[f]!== (f.startsWith('00004-')?2:1))throw Error('wrong retry count '+f)}
 fs.mkdirSync('normanhurst/build/engine-chunks-review',{recursive:true});
 const report={passed:true,...result,direct_large_wasm_requests:largeDirect,chunk_count:m.chunks.length,max_chunk_size:Math.max(...m.chunks.map(c=>c.size)),injected_failure_recovered:true,full_gameplay_verified:false};
 fs.writeFileSync('normanhurst/build/engine-chunks-review/report.json',JSON.stringify(report,null,2)+'\n');console.log(report);
 }finally{await b.close();server.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
