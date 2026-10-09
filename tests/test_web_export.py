import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

from tools.export_web_site import (
    ASSETS, ENTRY_URL, MAIN_JS, MAX_CHUNK_SIZE, archive_credits,
    cached_assets, export_site, fetch_shim, split_archive,
)


# These are the exact source anchors the shared frontend helper expects.
FRONTEND_FIXTURE = '''input_player1_a:`c`;
i=await(await fetch(n).then(O({onProgress:t=>{Bn+=t.transferred-e,e=t.transferred,Hn(),Rn!==null&&(In.stop(),Rn.style.display=`initial`)}}))).blob();
element:`#nostalgist-canvas`,retroarchConfig:{};
xn=new URL(`./Standard.mkxpz`,location.href).toString();
wn=22882414,
Dn=`5ef70c0075ace21ee105a48f616cb067a66a4a0b46ce8e9051869794ccd5a579`;
kn=`KNight-Blade: Howling of Kerberos`;
try{return await navigator.storage.getDirectory()}
var Q=document.getElementById(`gamepad-target`);
input_toggle_fast_forward:`space`,input_hold_fast_forward:`l`,input_toggle_slowmotion:`g`,input_hold_slowmotion:`e`;
e.persisted&&location.reload();
if(window.sessionStorage.getItem(Un)!==`ready`)throw window.sessionStorage.setItem(Un,`ready`),location.reload(),`Reloading once to make coi-serviceworker.js less flaky`;
location.reload(),`Reloading to enable cross-origin isolation`;
'''
HTML_FIXTURE = '''<!doctype html><html><head>
<title>mkxp-z-nostalgist</title>
<script type="module" crossorigin src="./assets/index-CHY6ZlLi.js"></script>
<link rel="stylesheet" href="./assets/index-lP0ZUypO.css">
</head><body><script src="./coi-serviceworker.min.js"></script></body></html>'''


class WebExportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "game.mkxpz"
        self.output = self.root / "site"
        self.cache = self.root / "cache"

    def fake_cache(self):
        self.cache.mkdir()
        for name in ("index.html",) + ASSETS:
            url = ENTRY_URL if name == "index.html" else ENTRY_URL + name
            data = (HTML_FIXTURE if name == "index.html" else
                    FRONTEND_FIXTURE if name == MAIN_JS else "fake " + name).encode()
            key = hashlib.sha256(url.encode()).hexdigest()
            (self.cache / (key + ".asset")).write_bytes(data)
            (self.cache / (key + ".json")).write_text(json.dumps({
                "url": url, "contentType": "application/octet-stream",
                "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            }))

    def fake_archive(self, **kwargs):
        with zipfile.ZipFile(self.archive, "w", **kwargs) as archive:
            archive.writestr("Data/raw.bin", bytes(range(256)) * 3)
            archive.writestr("CREDITS.txt", b"Original owners\r\n")
            archive.writestr("CREDITS.html", b"<p>More credits</p>")

    def test_chunks_reconstruct_arbitrary_binary_exactly(self):
        data = bytes(range(256)) * 5 + b"\x00\xfftail"
        self.archive.write_bytes(data)
        manifest = split_archive(self.archive, self.output, chunk_size=73)
        self.assertEqual(manifest["size"], len(data))
        self.assertEqual(manifest["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(json.loads((self.output / "game-manifest.json").read_text()), manifest)
        reconstructed = bytearray()
        for index, chunk in enumerate(manifest["chunks"]):
            part = (self.output / chunk["url"]).read_bytes()
            self.assertEqual(len(part), chunk["size"])
            self.assertLessEqual(len(part), 73)
            self.assertEqual(hashlib.sha256(part).hexdigest(), chunk["sha256"])
            self.assertEqual(chunk["url"], f"chunks/{index:05d}-{chunk['sha256']}.bin")
            reconstructed.extend(part)
        self.assertEqual(bytes(reconstructed), data)

    def test_rejects_empty_archive_and_invalid_chunk_sizes_without_writes(self):
        self.archive.touch()
        for size in (1, 0, -1, MAX_CHUNK_SIZE, MAX_CHUNK_SIZE + 1, True, 1.5):
            with self.subTest(size=size), self.assertRaises(ValueError):
                split_archive(self.archive, self.output, size)
        self.assertFalse(self.output.exists())
        self.archive.write_bytes(b"valid")
        for size in (0, -1, MAX_CHUNK_SIZE, MAX_CHUNK_SIZE + 1):
            with self.subTest(size=size), self.assertRaises(ValueError):
                split_archive(self.archive, self.output, size)

    @unittest.skipUnless(shutil.which("node"), "Node is required for frontend patching")
    def test_exports_site_using_shared_frontend_and_preserves_archive_and_cache(self):
        self.fake_archive()
        self.fake_cache()
        original = self.archive.read_bytes()
        cache_before = {file.name: file.read_bytes() for file in self.cache.iterdir()}
        manifest = export_site(self.archive, self.output, self.cache, chunk_size=100)
        self.assertEqual(self.archive.read_bytes(), original)
        self.assertEqual(cache_before, {file.name: file.read_bytes() for file in self.cache.iterdir()})
        self.assertEqual(b"".join((self.output / part["url"]).read_bytes()
                                  for part in manifest["chunks"]), original)
        modules = list((self.output / "assets").glob("normanhurst-*.js"))
        self.assertEqual(len(modules), 1)
        module = modules[0]
        js = module.read_text()
        self.assertEqual(module.name, "normanhurst-" + hashlib.sha256(module.read_bytes()).hexdigest() + ".js")
        self.assertIn("input_player1_a:`c`", js)
        self.assertIn("xn=null", js)
        self.assertNotIn("respondToGlobalEvents:!0", js)
        self.assertIn("try{return null}", js)
        self.assertIn("wn=" + str(len(original)), js)
        self.assertIn(manifest["sha256"], js)
        html = (self.output / "index.html").read_text()
        self.assertIn("<title>Pokémon Normanhurst</title>", html)
        self.assertIn('./assets/' + module.name, html)
        self.assertNotIn("index-CHY6ZlLi.js", html)
        self.assertLess(html.index("const originalFetch="), html.index('<script type="module"'))
        self.assertIn("cli-controls", html)
        self.assertIn("coi-serviceworker.min.js", html)
        for name in ASSETS:
            if name != MAIN_JS:
                self.assertEqual((self.output / name).read_bytes(), cached_assets(self.cache)[name][0])
        self.assertFalse((self.output / MAIN_JS).exists())
        self.assertFalse((self.output / "knight-blade-howling-of-kerberos.mkxpz").exists())
        self.assertEqual((self.output / "credits/CREDITS.txt").read_bytes(), b"Original owners\r\n")
        self.assertTrue((self.output / "credits/CREDITS.html").exists())
        notice = (self.output / "THIRD-PARTY.md").read_text()
        self.assertIn("NOT licensed under MIT", notice)
        self.assertIn("noncommercial", notice)
        self.assertIn("5cd3203660d16ab8cfb8dd962e04216662f8f8e9", notice)
        workflow = (self.output / ".github/workflows/pages.yml").read_text()
        for expected in ("branches: [main]", "pages: write", "id-token: write",
                         "actions/upload-pages-artifact@v3", "actions/deploy-pages@v4"):
            self.assertIn(expected, workflow)
        with self.assertRaises(ValueError):
            export_site(self.archive, self.output, self.cache)

    def test_refuses_existing_files_and_symlink_output(self):
        self.output.mkdir()
        unexpected = self.output / "unexpected"
        unexpected.write_bytes(b"keep me")
        with self.assertRaises(ValueError):
            export_site(self.archive, self.output, self.cache)
        self.assertEqual(unexpected.read_bytes(), b"keep me")
        link = self.root / "linked-output"
        link.symlink_to(self.output, target_is_directory=True)
        with self.assertRaises(ValueError):
            export_site(self.archive, link, self.cache)
        self.assertEqual(unexpected.read_bytes(), b"keep me")

    def test_chunk_helper_refuses_unowned_output(self):
        self.archive.write_bytes(b"arbitrary bytes")
        self.output.mkdir()
        marker = self.output / "keep"
        marker.write_bytes(b"untouched")
        with self.assertRaisesRegex(ValueError, "missing or empty"):
            split_archive(self.archive, self.output, 2)
        self.assertEqual(list(self.output.iterdir()), [marker])
        self.assertEqual(marker.read_bytes(), b"untouched")

    def test_cache_hash_and_key_validation(self):
        self.fake_cache()
        cached_assets(self.cache)
        key = hashlib.sha256((ENTRY_URL + MAIN_JS).encode()).hexdigest()
        asset = self.cache / (key + ".asset")
        asset.write_bytes(asset.read_bytes().replace(b"22882414", b"22882415"))
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            cached_assets(self.cache)
        asset.unlink()
        with self.assertRaisesRegex(ValueError, "Missing or unsafe"):
            cached_assets(self.cache)

    def test_cache_rejects_missing_assets(self):
        self.fake_cache()
        next(self.cache.glob("*.json")).unlink()
        with self.assertRaisesRegex(ValueError, "Missing prefetched"):
            cached_assets(self.cache)

    def test_archive_credits_requires_stored_zip_and_safe_paths(self):
        self.fake_archive(compression=zipfile.ZIP_DEFLATED)
        with self.assertRaisesRegex(ValueError, "ZIP_STORED"):
            archive_credits(self.archive)
        for name in ("../CREDITS.txt", "/CREDITS.txt", "..\\CREDITS.txt"):
            with zipfile.ZipFile(self.archive, "w") as package:
                package.writestr(name, b"unsafe")
            with self.subTest(name=name), self.assertRaises(ValueError):
                archive_credits(self.archive)
        with zipfile.ZipFile(self.archive, "w") as package:
            package.writestr("Data/normal.bin", b"no credits")
        with self.assertRaisesRegex(ValueError, "no root CREDITS"):
            archive_credits(self.archive)

    @unittest.skipUnless(shutil.which("node"), "Node is required for fetch shim tests")
    def test_fetch_shim_at_root_and_project_pages_and_corrupt_chunks(self):
        self.archive.write_bytes(bytes(range(256)) + b"\x00tail")
        manifest = split_archive(self.archive, self.output, 79)
        files = {part["url"]: list((self.output / part["url"]).read_bytes())
                 for part in manifest["chunks"]}
        shim = fetch_shim(manifest).removeprefix("<script>\n").removesuffix("</script>\n")
        script = r'''
const assert=require('node:assert/strict');
const vm=require('node:vm');
const crypto=require('node:crypto').webcrypto;
const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
(async()=>{
 for(const prefix of ['/', '/normopo/']){
  const base='https://example.test'+prefix;
  let calls=[],bad=false,manifestBad=false;
  const original=async function(url){
   assert.equal(this,window,'original fetch must remain bound');
   const absolute=new URL(url,base); calls.push(absolute.href);
   const name=absolute.pathname.slice(prefix.length);
   if(name==='game-manifest.json')return Response.json(manifestBad?{...input.manifest,size:0}:input.manifest);
   if(input.files[name]){
    const bytes=Uint8Array.from(input.files[name]);
    if(bad)bytes[0]^=1;
    return new Response(bytes);
   }
   return new Response('passthrough');
  };
  const window={fetch:original,dispatchEvent:()=>{}};
  vm.runInNewContext(input.shim,{window,document:{baseURI:base},location:{origin:'https://example.test'},
   URL,Request,Response,Blob,crypto,Uint8Array,setTimeout:fn=>fn(),CustomEvent:class{constructor(type,options){this.type=type;this.detail=options.detail}}});
  const result=await window.fetch(base+'knight-blade-howling-of-kerberos.mkxpz');
  assert.equal(result.headers.get('Content-Length'),String(input.manifest.size));
  assert.deepEqual(Array.from(new Uint8Array(await result.arrayBuffer())),input.original);
  assert.equal(calls.length,input.manifest.chunks.length+1,'no recursive interception');
  calls=[];
  for(const url of [base+'mkxp-z_libretro.wasm',base+'chunks/direct.bin',
   'https://elsewhere.test'+prefix+'knight-blade-howling-of-kerberos.mkxpz',
   base+'nested/knight-blade-howling-of-kerberos.mkxpz',
   base+'knight-blade-howling-of-kerberos.mkxpz?query=1']){
   assert.equal(await (await window.fetch(url)).text(),'passthrough');
  }
  assert.equal(calls.length,5);
  calls=[];
  const head=await window.fetch(new Request(base+'knight-blade-howling-of-kerberos.mkxpz',{method:'HEAD'}));
  assert.equal(await head.text(),'');assert.equal(calls.length,1);
  bad=true;
  await assert.rejects(window.fetch(base+'knight-blade-howling-of-kerberos.mkxpz'),/verification failed/);
  bad=false;manifestBad=true;
  await assert.rejects(window.fetch(base+'knight-blade-howling-of-kerberos.mkxpz'),/Invalid game manifest/);
 }
})().catch(error=>{console.error(error);process.exitCode=1});
'''
        result = subprocess.run(["node", "-e", script], input=json.dumps({
            "manifest": manifest, "files": files, "shim": shim,
            "original": list(self.archive.read_bytes()),
        }), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
