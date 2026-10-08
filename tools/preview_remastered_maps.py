#!/usr/bin/env python3
"""Render static map layers with Essentials' exact 48 autotile patterns."""
from pathlib import Path
import argparse, ast, struct, sys
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from essentials_cli import marshal as rm
ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'demo/build/remastered-map-pack-review/extracted/Remastered Kanto Johto Map Pack'

def get(obj, name):
    return rm.get(obj, name)

def text(value):
    return value.data.decode('utf-8')

def render(mid, output):
    source = (ROOT / 'demo/scripts/0075-TileDrawingHelper.rb').read_text()
    patterns = ast.literal_eval(source.split('AUTOTILE_PATTERNS = ', 1)[1].split('\n\n', 1)[0].strip())
    patterns = [p for group in patterns for p in group]
    maps = rm.loads((PACK / f'Data/Map{mid:03d}.rxdata').read_bytes())
    sets = rm.loads((PACK / 'Data/Tilesets.rxdata').read_bytes())
    tileset = sets[get(maps, 'tileset_id')]
    atlas = Image.open(PACK / 'Graphics/Tilesets' / (text(get(tileset, 'tileset_name')) + '.png')).convert('RGBA')
    auto = []
    for name in get(tileset, 'autotile_names'):
        name = text(name)
        path = PACK / 'Graphics/Autotiles' / (name + '.png')
        if name and not path.exists():
            path = ROOT / 'demo/essentials/Graphics/Autotiles' / (name + '.png')
        auto.append(Image.open(path).convert('RGBA') if name and path.exists() else None)
    table = get(maps, 'data').data
    _, w, h, depth, count = struct.unpack_from('<5i', table)
    values = struct.unpack_from(f'<{count}h', table, 20)
    canvas = Image.new('RGBA', (w*32,h*32), (0,0,0,255))
    cache = {}
    for z in range(depth):
        for y in range(h):
            for x in range(w):
                tid = values[x + y*w + z*w*h]
                if not tid: continue
                if tid not in cache:
                    if tid >= 384:
                        sx,sy = ((tid-384)%8)*32,((tid-384)//8)*32
                        tile = atlas.crop((sx,sy,sx+32,sy+32))
                    else:
                        sheet = auto[tid//48-1]
                        if sheet is None: raise ValueError(f'Missing autotile {tid}')
                        if sheet.height == 32:
                            tile = sheet.crop((0,0,32,32))
                        else:
                            tile = Image.new('RGBA',(32,32))
                            for q, index in enumerate(patterns[tid%48]):
                                sx,sy = ((index-1)%6)*16,((index-1)//6)*16
                                tile.alpha_composite(sheet.crop((sx,sy,sx+16,sy+16)),((q%2)*16,(q//2)*16))
                    cache[tid] = tile
                canvas.alpha_composite(cache[tid],(x*32,y*32))
    output.mkdir(parents=True,exist_ok=True)
    canvas.save(output/f'map-{mid:03d}.png')
    canvas.resize((w*16,h*16),Image.Resampling.NEAREST).save(output/f'map-{mid:03d}-overview.png')
    print(mid,w,h,output/f'map-{mid:03d}-overview.png')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ids',nargs='+',type=int)
    args=parser.parse_args()
    for mid in args.ids: render(mid,ROOT/'demo/build/remastered-map-pack-review/previews')
