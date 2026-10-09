#!/usr/bin/env python3
"""Static, untinted opening previews, including the real event character frames."""
from pathlib import Path
import ast
import json
import sys
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from essentials_cli import marshal as rm


def render(mid, grid=False):
    data=json.loads(next((ROOT/'normanhurst/maps').glob(f'{mid:03d}-*.json')).read_text())
    sets=rm.loads((ROOT/'normanhurst/game/Data/Tilesets.rxdata').read_bytes())
    record=sets[data['tileset']]
    def art(kind,name):
        for base in [ROOT/'demo/game/Graphics',ROOT/'demo/essentials/Graphics']:
            p=base/kind/(name+'.png')
            if p.is_file():return Image.open(p).convert('RGBA')
        raise FileNotFoundError(name)
    name=rm.get(record,'tileset_name').data.decode()
    atlas=art('Tilesets',name)
    auto=[art('Autotiles',n.data.decode()) if n.data else None for n in rm.get(record,'autotile_names')]
    source=(ROOT/'demo/scripts/0075-TileDrawingHelper.rb').read_text()
    patterns=[p for group in ast.literal_eval(source.split('AUTOTILE_PATTERNS = ',1)[1].split('\n\n',1)[0].strip()) for p in group]
    w,h=data['size'];canvas=Image.new('RGBA',(w*32,h*32),(0,0,0,255));cache={}
    for layer in data['layers']:
        for y,row in enumerate(layer['rows']):
            for x,c in enumerate(row):
                tid=layer['legend'][c]
                if not tid:continue
                if tid not in cache:
                    if tid>=384:
                        sx,sy=(tid-384)%8*32,(tid-384)//8*32
                        tile=atlas.crop((sx,sy,sx+32,sy+32))
                    else:
                        sheet=auto[tid//48-1]
                        if sheet.height==32:tile=sheet.crop((0,0,32,32))
                        else:
                            tile=Image.new('RGBA',(32,32))
                            for q,index in enumerate(patterns[tid%48]):
                                sx,sy=(index-1)%6*16,(index-1)//6*16
                                tile.alpha_composite(sheet.crop((sx,sy,sx+16,sy+16)),(q%2*16,q//2*16))
                    cache[tid]=tile
                canvas.alpha_composite(cache[tid],(x*32,y*32))
    for e in sorted(data['events'],key=lambda e:e['position'][1]):
        if not e.get('graphic'):continue
        sheet=art('Characters',e['graphic']);cw,ch=sheet.width//4,sheet.height//4
        sprite=sheet.crop((0,0,cw,ch));x,y=e['position']
        canvas.alpha_composite(sprite,(x*32+16-cw//2,y*32+32-ch))
    if grid:
        draw=ImageDraw.Draw(canvas)
        for y in range(h):
            for x in range(w):
                draw.rectangle((x*32,y*32,x*32+31,y*32+31),outline='#555')
                draw.text((x*32,y*32),f'{x},{y}',fill='white',stroke_width=1,stroke_fill='black')
    dest=ROOT/'normanhurst/build/map-redesign-review';dest.mkdir(exist_ok=True,parents=True)
    canvas.save(dest/f'opening-{mid}{"-grid" if grid else ""}.png')
    return canvas

if __name__=='__main__':
    for mid in range(200,205):render(mid)
    render(200,True)
