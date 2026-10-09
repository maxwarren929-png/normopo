#!/usr/bin/env python3
"""Export a prefetched mkxp-z player and byte-exact archive for GitHub Pages.

No network access, uploads, Git operations, or archive repacking occur here.
Only a missing or empty output directory is accepted. Failed exports are left
in place for inspection; this tool never recursively deletes an output.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

MIB = 1024 * 1024
DEFAULT_CHUNK_SIZE = 32 * MIB
MAX_CHUNK_SIZE = 100 * MIB
ENTRY_URL = "https://white-axe.github.io/mkxp-z-libretro-emscripten/nostalgist-knight-blade-howling-of-kerberos/"
MAIN_JS = "assets/index-CHY6ZlLi.js"
ASSETS = (MAIN_JS, "assets/index-lP0ZUypO.css", "mkxp-z_libretro.js",
          "mkxp-z_libretro.wasm", "coi-serviceworker.min.js", "vite.svg")
GAME_NAME = "knight-blade-howling-of-kerberos.mkxpz"
DEFAULT_CACHE = Path("normanhurst/build/web-player-review/player-assets")
FRONTEND = Path(__file__).with_name("web_player_frontend.cjs")


def validate_chunk_size(size: int) -> None:
    if isinstance(size, bool) or not isinstance(size, int) or not 0 < size < MAX_CHUNK_SIZE:
        raise ValueError("Chunk size must be positive and below 100 MiB")


def write_new(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)


def split_archive(archive: Path, output: Path, chunk_size: int = DEFAULT_CHUNK_SIZE) -> dict:
    """Split any nonempty binary without changing a byte; return its manifest."""
    archive, output = Path(archive), Path(output)
    validate_chunk_size(chunk_size)
    if output.is_symlink() or (output.exists() and
                              (not output.is_dir() or any(output.iterdir()))):
        raise ValueError("Chunk output must be missing or empty")
    if output.resolve() in archive.resolve().parents:
        raise ValueError("Archive cannot be inside chunk output")
    if not archive.is_file() or archive.stat().st_size == 0:
        raise ValueError("Archive must be a nonempty regular file")
    chunks = []
    digest = hashlib.sha256()
    total = 0
    with archive.open("rb") as stream:
        while data := stream.read(chunk_size):
            sha = hashlib.sha256(data).hexdigest()
            name = f"chunks/{len(chunks):05d}-{sha}.bin"
            write_new(output / name, data)
            chunks.append({"url": name, "size": len(data), "sha256": sha})
            digest.update(data)
            total += len(data)
    if not total:
        raise ValueError("Archive became empty during export")
    manifest = {"version": 1, "size": total, "sha256": digest.hexdigest(), "chunks": chunks}
    write_new(output / "game-manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    return manifest


def split_engine(data: bytes, output: Path, chunk_size: int = 4 * MIB) -> dict:
    """Preserve the pinned WASM binary, using small hash-verified transfers."""
    validate_chunk_size(chunk_size)
    if not data:
        raise ValueError('Engine binary must not be empty')
    chunks = []
    for index, offset in enumerate(range(0, len(data), chunk_size)):
        part = data[offset:offset + chunk_size]
        sha = hashlib.sha256(part).hexdigest()
        name = f'engine-chunks/{index:05d}-{sha}.bin'
        write_new(output / name, part)
        chunks.append({'url': name, 'size': len(part), 'sha256': sha})
    manifest = {'version': 1, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'chunks': chunks}
    write_new(output / 'engine-manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
    return manifest


def cached_assets(cache: Path) -> dict:
    """Use only the exact sample URLs, and verify cache metadata and bytes."""
    result = {}
    required = {ENTRY_URL + name: name for name in ASSETS}
    required[ENTRY_URL] = "index.html"
    for metadata_path in sorted(cache.glob("*.json")):
        if metadata_path.is_symlink():
            raise ValueError("Symlink cache metadata is not allowed")
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        url = metadata.get("url")
        if url not in required:
            continue
        key = hashlib.sha256(url.encode()).hexdigest()
        if metadata_path.name != key + ".json":
            raise ValueError("Cache key does not match URL")
        asset = cache / (key + ".asset")
        if asset.is_symlink() or not asset.is_file():
            raise ValueError("Missing or unsafe cached asset")
        data = asset.read_bytes()
        if (len(data) != metadata.get("size") or
                hashlib.sha256(data).hexdigest() != metadata.get("sha256")):
            raise ValueError("Cache size or SHA-256 mismatch: " + url)
        name = required[url]
        if name in result:
            raise ValueError("Duplicate cache asset: " + url)
        result[name] = (data, metadata)
    missing = set(required.values()) - set(result)
    if missing:
        raise ValueError("Missing prefetched assets: " + ", ".join(sorted(missing)))
    return result


def archive_credits(archive: Path) -> dict[str, bytes]:
    credits = {}
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            name = member.filename
            path = PurePosixPath(name)
            if (path.is_absolute() or ".." in path.parts or "\\" in name or
                    any(ord(char) < 32 for char in name) or ":" in name):
                raise ValueError("Unsafe archive path: " + repr(name))
            if member.compress_type != zipfile.ZIP_STORED:
                raise ValueError("The game archive must use ZIP_STORED")
            if len(path.parts) == 1 and name.upper().startswith("CREDITS") and not member.is_dir():
                if name in credits:
                    raise ValueError("Duplicate credits filename")
                credits[name] = package.read(member)
    if not credits:
        raise ValueError("Archive has no root CREDITS files")
    return credits


def patch_frontend(source: bytes, identity: dict) -> tuple[bytes, str, str]:
    script = """const fs=require('node:fs');
const {patchPlayerJS,SUPPORT,BOOTSTRAP}=require(process.argv[1]);
const input=JSON.parse(fs.readFileSync(0,'utf8'));
process.stdout.write(JSON.stringify({js:patchPlayerJS(input.source,input.identity),support:SUPPORT,bootstrap:BOOTSTRAP}));
"""
    result = subprocess.run(["node", "-e", script, str(FRONTEND.resolve())],
                            input=json.dumps({"source": source.decode("utf-8"),
                                              "identity": identity}),
                            text=True, capture_output=True, check=True)
    patched = json.loads(result.stdout)
    return patched["js"].encode("utf-8"), patched["support"], patched["bootstrap"]


def fetch_shim(identity: dict, runtime_identity: dict | None = None) -> str:
    # Pin manifest identity in the HTML. Hash only individual chunks, not a
    # second full-archive ArrayBuffer. The frontend's cache key is patched too.
    config = json.dumps({"size": identity["size"], "sha256": identity["sha256"]})
    return "<script>\n" + r"""(()=>{
'use strict';
const expected=CONFIG;
const runtimeExpected=RUNTIME_CONFIG;
const originalFetch=window.fetch.bind(window);
const base=new URL('.',document.baseURI);
const target=new URL('knight-blade-howling-of-kerberos.mkxpz',base);
const runtimeTarget=new URL('mkxp-z_libretro.wasm',base);
const hex=bytes=>Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,'0')).join('');
async function readWithRetry(url,options,consume){
 for(let attempt=0;attempt<3;attempt++){
  try{
   const response=await originalFetch(url,options);
   if(!response.ok)throw Error('HTTP '+response.status);
   return await consume(response);
  }catch(error){
   if(error?.name==='AbortError')throw error;
   if(attempt<2){await new Promise(resolve=>setTimeout(resolve,500*(attempt+1)));continue}
   const failure=Error('Could not download '+new URL(url,base).pathname.split('/').pop()+' after 3 attempts: '+error.message);
   failure.cliDownloadFinal=true;
   window.dispatchEvent(new CustomEvent('cli-download-error',{detail:failure.message}));
   throw failure;
  }
 }
}
window.fetch=async function(input,init){
 let url;
 try {url=new URL(input instanceof Request?input.url:String(input),document.baseURI)}
 catch {return originalFetch(input,init)}
 const isRuntime=runtimeExpected!==null&&url.pathname===runtimeTarget.pathname;
 if(url.origin!==location.origin||(!isRuntime&&url.pathname!==target.pathname)||url.search||url.hash)
  return originalFetch(input,init);
 const identity=isRuntime?runtimeExpected:expected;
 const prefix=isRuntime?'engine-chunks':'chunks';
 const manifestURL=new URL(isRuntime?'engine-manifest.json':'game-manifest.json',base);
 const method=(init?.method||(input instanceof Request?input.method:'GET')).toUpperCase();
 if(method!=='GET'&&method!=='HEAD')return originalFetch(input,init);
 const options={signal:init?.signal||(input instanceof Request?input.signal:undefined)};
 const manifest=await readWithRetry(manifestURL,options,response=>response.json());
 if(manifest.version!==1||manifest.size!==identity.size||manifest.sha256!==identity.sha256||
    !Array.isArray(manifest.chunks)||manifest.chunks.length===0)throw Error('Invalid '+(isRuntime?'engine':'game')+' manifest');
 let total=0;
 for(const [index,chunk] of manifest.chunks.entries()){
  if(!Number.isSafeInteger(chunk.size)||chunk.size<=0||chunk.size>=100*1024*1024||
     !/^[a-f0-9]{64}$/.test(chunk.sha256)||
     chunk.url!==prefix+'/'+String(index).padStart(5,'0')+'-'+chunk.sha256+'.bin')
   throw Error('Invalid game chunk');
  total+=chunk.size;
 }
 if(total!==identity.size)throw Error('Invalid download length');
 const headers={'Content-Type':isRuntime?'application/wasm':'application/octet-stream','Content-Length':String(total)};
 if(method==='HEAD')return new Response(null,{headers});
 const chunks=[];
 for(const [index,chunk] of manifest.chunks.entries()){
  if(isRuntime){const status=document.getElementById?.('cli-loading');if(status)status.textContent='Downloading browser engine: part '+(index+1)+' of '+manifest.chunks.length+'.'}
  const bytes=await readWithRetry(new URL(chunk.url,base),options,async part=>{
   const bytes=await part.arrayBuffer();
   if(bytes.byteLength!==chunk.size||hex(await crypto.subtle.digest('SHA-256',bytes))!==chunk.sha256)
    throw Error('Game chunk verification failed');
   return bytes;
  });
  chunks.push(bytes);
 }
 if(isRuntime){const status=document.getElementById?.('cli-loading');if(status)status.textContent='Browser engine downloaded. Waiting for game startup.'}
 return new Response(new Blob(chunks,{type:headers['Content-Type']}),{headers});
};
})();
""".replace("RUNTIME_CONFIG", json.dumps(None if runtime_identity is None else {key: runtime_identity[key] for key in ('size', 'sha256')})).replace("CONFIG", config) + "</script>\n"


PAGES_WORKFLOW = """name: Deploy Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: '.'
      - name: Deploy
        id: deployment
        uses: actions/deploy-pages@v4
"""


def third_party(assets: dict) -> str:
    text = """# Third-party notices

Pokémon Normanhurst is a noncommercial fan game. The game and its bundled
artwork, music, data and scripts are NOT licensed under MIT by this export.
Pokémon belongs to Nintendo, Game Freak and Creatures. Pokémon Essentials
and other contributors retain their own rights. See every file in credits/
for the original game, Pokémon Essentials, and asset creator credits.
This exporter does not grant permission to reuse or redistribute those assets.

The browser runtime comes from white-axe's mkxp-z libretro Emscripten player.
Pinned frontend source, released under the Unlicense:
https://github.com/white-axe/mkxp-z-libretro-emscripten/tree/f0a1ff80f05dd0d1f8ca711485a5b0a601bc7502
Pinned mkxp-z engine source, GPL-2.0:
https://github.com/white-axe/mkxp-z/tree/5cd3203660d16ab8cfb8dd962e04216662f8f8e9
These components and their dependencies retain their upstream licenses.
The frontend includes Nostalgist.js by its contributors, https://github.com/arianrhodsandlot/nostalgist,
and Dexie.js by David Fahlander and contributors, https://github.com/dexie/Dexie.js.
COI service worker by Guido Zuidhof and contributors:
https://github.com/gzuidhof/coi-serviceworker . Vite's logo belongs to the Vite
contributors, https://github.com/vitejs/vite . Consult upstream license files;
this notice does not replace them or relicense the player.

## Pinned runtime files

The following upstream URLs identify the cached sample. The SHA-256 digests
pin the exact bytes used by this export, since the hosted URLs can change.
The entry HTML and main module are modified locally; all other listed files
are copied unchanged. Frontend modifications come from tools/web_player_frontend.cjs.

"""
    for name, (_, metadata) in sorted(assets.items()):
        text += f"- `{name}`\n  Source: {metadata['url']}\n  SHA-256: `{metadata['sha256']}`\n"
    return text


def export_site(archive: Path, output: Path, cache: Path = DEFAULT_CACHE,
                chunk_size: int = DEFAULT_CHUNK_SIZE) -> dict:
    archive, output, cache = Path(archive), Path(output), Path(cache)
    validate_chunk_size(chunk_size)
    if output.is_symlink():
        raise ValueError("Output must not be a symlink")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("Output must be missing or empty; refusing to overwrite files")
    resolved_output = output.resolve()
    for source in (archive.resolve(), cache.resolve()):
        if source == resolved_output or resolved_output in source.parents:
            raise ValueError("Input cannot be inside output")
    if not archive.is_file() or archive.stat().st_size == 0:
        raise ValueError("Archive must be a nonempty regular file")
    assets = cached_assets(cache)
    credits = archive_credits(archive)
    output.mkdir(parents=True, exist_ok=True)
    manifest = split_archive(archive, output, chunk_size)
    runtime_manifest = split_engine(assets['mkxp-z_libretro.wasm'][0], output)
    js, support, bootstrap = patch_frontend(assets[MAIN_JS][0], manifest)
    new_module = "assets/normanhurst-" + hashlib.sha256(js).hexdigest() + ".js"
    html = assets["index.html"][0].decode("utf-8")
    for before, after in (("<title>mkxp-z-nostalgist</title>", bootstrap + "<title>Pokémon Normanhurst</title>"),
                          ('<script type="module" crossorigin src="./' + MAIN_JS + '"></script>',
                           fetch_shim(manifest, runtime_manifest) + '<script type="module" crossorigin src="./' + new_module + '"></script>'),
                          ("</body>", support + "</body>")):
        if html.count(before) != 1:
            raise ValueError("Upstream HTML changed: " + before)
        html = html.replace(before, after)
    write_new(output / "index.html", html.encode("utf-8"))
    write_new(output / new_module, js)
    for name in ASSETS:
        if name != MAIN_JS:
            data = assets[name][0]
            if name.endswith('.css'):
                # The sample CSS refers to font files absent from its pinned
                # asset set. Use system UI fonts for the loader/controls only.
                # In-game FireRed bitmap fonts are untouched.
                import re
                text = re.sub(r'@font-face\{[^}]*\}', '', data.decode('utf-8'))
                text = text.replace('font-family:Roboto', 'font-family:system-ui')
                data = text.encode('utf-8')
            write_new(output / name, data)
    for name, data in credits.items():
        write_new(output / "credits" / name, data)
    write_new(output / "THIRD-PARTY.md", third_party(assets).encode("utf-8"))
    write_new(output / ".github/workflows/pages.yml", PAGES_WORKFLOW.encode())
    write_new(output / ".nojekyll", b"")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--asset-cache", type=Path, default=Path(os.environ.get("WEB_ASSET_CACHE", DEFAULT_CACHE)))
    parser.add_argument("--chunk-size", type=int, default=DEFAULT_CHUNK_SIZE, help="Bytes per chunk, below 100 MiB")
    args = parser.parse_args()
    try:
        manifest = export_site(args.archive, args.output, args.asset_cache, args.chunk_size)
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Export failed: {error}\n")
    print(f"Exported {manifest['size']} bytes in {len(manifest['chunks'])} chunks to {args.output}")
    print("No files were uploaded or deployed.")


if __name__ == "__main__":
    main()
