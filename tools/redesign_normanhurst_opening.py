#!/usr/bin/env python3
"""Bounded opening-room layouts, private station atlas, and physical entry tiles.

Run after import_normanhurst_opening.py. Never edits another edition's maps or
existing shared graphics. Tile fragments are copied from inspected source rooms.
"""
from pathlib import Path
import copy
import json
import struct
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from essentials_cli import marshal as rm
MAPS = ROOT / 'normanhurst/maps'


def decode(obj):
    raw = rm.get(obj, 'data').data
    _, w, h, z, count = struct.unpack_from('<5i', raw)
    vals = struct.unpack_from(f'<{count}h', raw, 20)
    return [[[vals[x + y*w + d*w*h] for x in range(w)] for y in range(h)] for d in range(z)]


def unpack(d):
    return [[[layer['legend'][c] for c in row] for row in layer['rows']] for layer in d['layers']]


def encode(grids):
    layers = []
    for grid in grids:
        vals = sorted({v for row in grid for v in row})
        symbols = {v: chr(0x100+i) for i, v in enumerate(vals)}
        layers.append({'legend': {c: v for v, c in symbols.items()},
                       'rows': [''.join(symbols[v] for v in row) for row in grid]})
    return layers


def load(mid):
    p = next(MAPS.glob(f'{mid:03d}-*.json'))
    return p, json.loads(p.read_text())


def save(d):
    p, _ = load(d['id'])
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n')


def source(mid):
    return decode(rm.loads((ROOT/f'demo/essentials/Data/Map{mid:03d}.rxdata').read_bytes()))


def blank(w, h, floor):
    return [[[floor if z == 0 else 0 for _ in range(w)] for _ in range(h)] for z in range(3)]


def cell(dst, src, sx, sy, x, y):
    for z in range(3):
        dst[z][y][x] = src[z][sy][sx]


def rooms(data):
    original = source(3)
    # An actual 12x9 footprint, surrounded by intentional indoor void. Preserve
    # the source's opaque void tile 542, rather than painting floor to map edges.
    house = blank(16, 12, 542)
    for y in range(9):
        for x in range(12):
            cell(house, original, x, y, x+2, y+2)
    # Remove the demo upstairs staircase. Restore wall and floor underneath.
    for y in range(1, 4):
        for x in range(9, 12):
            sx, sy = (4, 1) if y == 1 else (8, 2)
            cell(house, original, sx, sy, x+2, y+2)
    # Sleeping nook, copied as a complete sprite footprint from the upstairs
    # reference. A bookshelf sits against the back wall beside it.
    for y in range(2):
        for x in range(3):
            cell(house, original, 20+x, 5+y, 10+x, 6+y)
    for y in range(2):
        for x in range(2):
            cell(house, original, 23+x, 1+y, 11+x, 3+y)
    d = data[201]
    d.update(size=[16, 12], tileset=3, layers=encode(house))
    for e in d['events']:
        e.pop('graphic', None) if e['name'] == 'Front door' else None
        if e['name'] == 'Mum': e['position'] = [6, 4]
        if e['name'] == 'Front door': e['position'] = [5, 10]

    original = source(4)
    lab = blank(16, 12, 542)
    # Keep the walls, research equipment, starter table and two shelf banks.
    # Remove two empty floor rows from the old room. The exit is the red mat.
    rows = list(range(9))+[11, 12]
    for y, sy in enumerate(rows):
        for x in range(13):
            cell(lab, original, x, sy, x+1, y)
    d = data[202]
    d.update(size=[16, 12], tileset=3, layers=encode(lab))
    positions = {1:[7,3], 2:[9,4], 3:[10,4], 4:[11,4],
                 5:[7,6], 6:[7,10], 7:[7,1], 8:[4,9]}
    for e in d['events']:
        e['position'] = positions[e['id']]
        if e['name'] == 'Exit': e.pop('graphic', None)
        if e['name'] == 'Rival': e['graphic']='trainer_RIVAL1'


def table(obj):
    raw = obj.data
    count = struct.unpack_from('<5i', raw)[4]
    return list(struct.unpack_from(f'<{count}h', raw, 20))


def set_table(obj, field, values):
    n = len(values)
    rm.set_field(obj, field, rm.UserData('Table', struct.pack('<5i', 1, n, 1, 1, n)+struct.pack(f'<{n}h', *values)))


def station(data, sets):
    graphics = ROOT/'demo/game/Graphics/Tilesets'
    exterior = Image.open(graphics/'CLI-Remastered-KANTO50S_OUT.png').convert('RGBA')
    old = Image.open(graphics/'Home Suburb Station.png').convert('RGBA')
    # Reuse the credited assembled Cherubi facade/wagon, but use real remastered
    # ground around them. The old atlas itself and map-76 hook stay unchanged.
    combined = Image.new('RGBA', (256, exterior.height+old.height))
    combined.paste(exterior, (0, 0))
    combined.paste(old, (0, exterior.height))
    combined.save(graphics/'CLI-Normanhurst-Station.png')
    delta = exterior.height//32*8
    record = copy.deepcopy(sets[26])
    rm.set_field(record, 'id', 27)
    rm.set_field(record, 'name', rm.string('Normanhurst compact station'))
    rm.set_field(record, 'tileset_name', rm.string('CLI-Normanhurst-Station'))
    n = max(384+combined.height//32*8, len(table(rm.get(record, 'passages'))))
    for field in ['passages', 'priorities', 'terrain_tags']:
        vals = table(rm.get(record, field)); vals += [0]*(n-len(vals))
        # Custom opaque floor 384-386 is not used. Art/track/fence/bench blocked.
        for tid in range(384, 494):
            vals[tid+delta] = 15 if field == 'passages' and tid >= 387 else 0
        if field == 'priorities': vals[0] = 5
        set_table(record, field, vals)
    sets[27] = record
    d = data[203]
    original = json.loads((ROOT/'normanhurst/build/map-redesign-review/before/203.json').read_text())
    oldgrids = unpack(original)
    g = blank(22, 16, 385)  # Matching exterior grass, no hand-drawn flat field.
    # Gravel forecourt, framed once around its perimeter, not repeating patches.
    for y in range(9, 15):
        for x in range(2, 21):
            cx = 0 if x == 2 else 2 if x == 20 else 1
            cy = 0 if y == 9 else 2 if y == 14 else 1
            g[0][y][x] = 649+cx+cy*8
    for y in range(16):
        for x in [10, 11]:
            g[0][y][x] = (657 if x==10 else 659) if y<9 else 658
    # Station facade: the full original assembly occupies x2..9/y3..10. Move
    # north by two tiles, preserving every nonempty fragment of the roof/doors.
    for sy in range(3, 11):
        for sx in range(2, 10):
            tid = oldgrids[1][sy][sx]
            if tid: g[1][sy-2][sx-1] = tid+delta
    # Goods siding and complete carriage. Rail sleepers run horizontally.
    for x in range(12, 22):
        g[0][7][x] = 387+delta
        g[0][8][x] = 386+delta
    for sy in range(1, 7):
        for sx in range(21, 29):
            tid = oldgrids[1][sy][sx]
            if tid: g[1][sy+1][sx-8] = tid+delta
    # Low fence borders the forecourt, leaving both town and bush-path openings.
    for x in range(22):
        if x not in [10, 11]:
            g[1][15][x] = 388+delta
    for y in range(9, 15):
        g[1][y][0] = 388+delta
        g[1][y][21] = 388+delta
    # Existing bench footprint from the old scene, beside the platform.
    for sx in [23, 24]:
        tid = oldgrids[1][12][sx]
        if tid: g[1][12][sx-7] = tid+delta
    # Plant a hedge/tree boundary west of the north approach. The path stays
    # separate from the siding and every track/wagon cell remains impassable.
    for x in [1, 3, 5, 7]:
        for dy in range(2):
            for dx in range(2): g[1][dy][x+dx] = 880+dx+dy*8
    d.update(size=[22,16], tileset=27, layers=encode(g))
    positions = {1:[8,10],2:[4,11],3:[4,8],4:[12,10],5:[10,0],
                 6:[10,15],7:[11,0],8:[11,15],9:[9,12],10:[18,11],11:[19,9]}
    for e in d['events']:
        e['position'] = positions[e['id']]
        if e.get('graphic','').startswith('Entrance '): e.pop('graphic')
        if e['name'] in ['Departure board','Station directions']:
            # Actual wooden boards, not text floating over the playfield.
            x,y=e['position']
            g[1][y-1][x],g[1][y][x] = 1692,1700
            e['graphic']='CLI_Map_Interaction'
        if e['name']=='Ticket hall doors':
            # Closed double door in the facade, approached from the forecourt.
            g[1][8][4] = oldgrids[1][10][5]+delta
            e['trigger'] = 'action'
            e['graphic'] = 'CLI_Map_Interaction'
        if e['name']=='Station directions':
            e['actions']=[{'say':'Home Suburb Station\nPlatform: east. Bush Track: north.\nHome Suburb: south.'}]
    d['layers'] = encode(g)


def redesign():
    assert not (ROOT/'normanhurst/game/Data').is_symlink(), 'Tilesets must be an edition-private overlay'
    data = {mid:load(mid)[1] for mid in range(200, 205)}
    # Keep a recoverable before-copy once, rather than accumulating snapshots.
    backup = ROOT/'normanhurst/build/map-redesign-review/before'
    backup.mkdir(parents=True, exist_ok=True)
    for mid,d in data.items():
        p=backup/f'{mid}.json'
        if not p.exists(): p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n')
    # A transparent named charset gives tile-backed action events normal
    # front-facing interaction semantics. The art is drawn by the map, not UI.
    characters=ROOT/'demo/game/Graphics/Characters'
    Image.new('RGBA',(128,128)).save(characters/'CLI_Map_Interaction.png')
    rooms(data)
    data[202]['events'][6]['graphic']='CLI_Map_Interaction'
    town=unpack(data[200])
    for e in data[200]['events']:
        if e['name'] in ['Your house','Rival house']:
            e['graphic']='doors3'
        if e['name']=='Professor lab':e['graphic']='doors6'
        if e['name']=='Welcome sign':
            e['position']=[12,7]
            e['graphic']='CLI_Field_Sign'
            town[1][7][12]=0
    if not any(e['name']=='Lab doorway right' for e in data[200]['events']):
        door=copy.deepcopy(data[200]['events'][1])
        door.update(id=8,name='Lab doorway right',position=[16,14])
        data[200]['events'].append(door)
    data[200]['layers']=encode(town)
    exterior=Image.open(ROOT/'demo/game/Graphics/Tilesets/CLI-Remastered-KANTO50S_OUT.png').convert('RGBA')
    sign=Image.new('RGBA',(32,64))
    for y,tid in enumerate([1692,1700]):
        x0,y0=(tid-384)%8*32,(tid-384)//8*32
        sign.paste(exterior.crop((x0,y0,x0+32,y0+32)),(0,y*32))
    sheet=Image.new('RGBA',(128,256))
    for y in range(4):
        for x in range(4):sheet.paste(sign,(x*32,y*64))
    sheet.save(characters/'CLI_Field_Sign.png')
    path=ROOT/'normanhurst/game/Data/Tilesets.rxdata'
    sets=rm.loads(path.read_bytes())
    station(data, sets)
    path.write_bytes(rm.dumps(sets))
    # All destination changes are explicit. No unrelated IDs or coordinates.
    destinations = {201:[5,9], 202:[7,9], 203:[10,14]}
    for mid,d in data.items():
        for e in d['events']:
            if e.get('graphic','').startswith('Entrance '): e.pop('graphic')
            for a in e['actions']:
                if 'transfer' in a:
                    target=a['transfer']['map']
                    if target in destinations:
                        a['transfer']['position'] = [10,1] if mid==204 and target==203 else destinations[target]
                if mid==200 and 'script' in a and 'OzerimStory.travel(203,' in a['script']:
                    a['script']='OzerimStory.travel(203, 10, 14)'
        save(d)
    print('Rebuilt bounded house/lab and compact station. Local only; no publication.')

if __name__=='__main__': redesign()
