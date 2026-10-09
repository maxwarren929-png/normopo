#!/usr/bin/env python3
"""Build only Normanhurst's opening from reviewed layouts and preserved story events."""
from pathlib import Path
import copy, json, re, shutil, struct, sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from essentials_cli import marshal as rm
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'demo/build/remastered-map-pack-review/extracted/Remastered Kanto Johto Map Pack'
SOURCE=ROOT/'backups/story-maps-20261003-185938/normanhurst/maps'
DEST=ROOT/'normanhurst/maps'
ID_MAP={2:200,3:201,4:202,76:203,77:204}

def rewrite(value):
    if isinstance(value,dict):
        return {k:ID_MAP.get(v,v) if k=='map' and isinstance(v,int) else rewrite(v) for k,v in value.items()}
    if isinstance(value,list):return [rewrite(v) for v in value]
    if isinstance(value,str):
        return re.sub(r'OzerimStory\.travel\((\d+),',lambda m:'OzerimStory.travel('+str(ID_MAP.get(int(m[1]),int(m[1])))+',',value)
    return value

def layers(mid,x0,width):
    obj=rm.loads((PACK/f'Data/Map{mid:03d}.rxdata').read_bytes())
    raw=rm.get(obj,'data').data
    _,w,h,z,count=struct.unpack_from('<5i',raw)
    values=struct.unpack_from(f'<{count}h',raw,20)
    result=[]
    for depth in range(z):
        legend={}; symbols={};rows=[]
        for y in range(h):
            row=''
            for x in range(x0,x0+width):
                tile=values[x+y*w+depth*w*h]
                if tile not in symbols:
                    char=chr(0x100+len(symbols));symbols[tile]=char;legend[char]=tile
                row+=symbols[tile]
            rows.append(row)
        result.append({'legend':legend,'rows':rows})
    return result,[width,h]

def main():
    assert (DEST/'001-first-room.json').exists()
    data={}
    for old,new in ID_MAP.items():
        source=next(SOURCE.glob(f'{old:03d}-*.json'))
        d=rewrite(json.loads(source.read_text()));d['id']=new;data[new]=(source.name.split('-',1)[1],d)
    town=data[200][1];town['layers'],town['size']=layers(55,13,24);town['tileset']=26
    positions={1:[5,7],2:[15,14],3:[10,10],4:[15,7],5:[9,12],6:[11,0],7:[12,0]}
    for event in town['events']:event['position']=positions[event['id']]
    # Retain the existing labels above entries, with room in front to approach.
    data[201][1]['events'][2]['actions'][0]['transfer']['position']=[5,8]
    data[202][1]['events'][5]['actions'][0]['transfer']['position']=[15,15]
    for event in data[203][1]['events']:
        if event['name']=='Return to Home Suburb':event['actions'][0]['transfer']['position']=[11,1]
        if event['name']=='Bush track entrance':event['actions'][0]['script']='OzerimStory.travel(204, 12, 38, 8, true)'
    track=data[204][1];track['layers'],track['size']=layers(10,12,24);track['tileset']=26
    positions={1:[19,22],2:[18,22],3:[20,22],4:[12,39],5:[13,39],6:[12,0]}
    for event in track['events']:event['position']=positions[event['id']]
    # New private tileset array. Never replace imported Essentials source data.
    sets=rm.loads((ROOT/'demo/essentials/Data/Tilesets.rxdata').read_bytes())
    packsets=rm.loads((PACK/'Data/Tilesets.rxdata').read_bytes())
    assert len(sets)==26,'Review tileset ID allocation before rerunning'
    exterior=copy.deepcopy(packsets[21]);rm.set_field(exterior,'id',26)
    rm.set_field(exterior,'name',rm.string('Normanhurst remastered exterior'))
    name=rm.get(exterior,'tileset_name').data.decode();newname='CLI-Remastered-'+name
    rm.set_field(exterior,'tileset_name',rm.string(newname))
    graphics=ROOT/'demo/game/Graphics'
    shutil.copyfile(PACK/'Graphics/Tilesets'/(name+'.png'),graphics/'Tilesets'/(newname+'.png'))
    (graphics/'Autotiles').mkdir(exist_ok=True)
    names=[]
    for entry in rm.get(exterior,'autotile_names'):
        name=entry.data.decode();src=PACK/'Graphics/Autotiles'/(name+'.png')
        if name and src.exists():
            new='CLI-Remastered-'+name;shutil.copyfile(src,graphics/'Autotiles'/(new+'.png'));names.append(rm.string(new))
        else:names.append(rm.string(''))
    rm.set_field(exterior,'autotile_names',names);sets.append(exterior)
    # Existing Cherubi scenery gets a proper edition-local tileset, not a map-ID hook.
    station=copy.deepcopy(sets[1]);rm.set_field(station,'id',27)
    rm.set_field(station,'name',rm.string('Normanhurst station'))
    rm.set_field(station,'tileset_name',rm.string('Home Suburb Station'))
    rm.set_field(station,'autotile_names',[rm.string('') for _ in range(7)])
    for field in ['passages','priorities','terrain_tags']:
        values=[0]*494
        if field=='passages':values[387:494]=[15]*107
        if field=='priorities':values[0]=5
        rm.set_field(station,field,rm.UserData('Table',struct.pack('<5i',1,494,1,1,494)+struct.pack('<494h',*values)))
    sets.append(station);data[203][1]['tileset']=27
    overlay=ROOT/'normanhurst/game/Data'
    assert not overlay.is_symlink(), 'Create an edition-private game/Data directory before importing; preserve shared animation links'
    overlay.mkdir(exist_ok=True)
    (overlay/'Tilesets.rxdata').write_bytes(rm.dumps(sets))
    for mid,(name,d) in data.items():(DEST/f'{mid:03d}-{name}').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    metadata=(ROOT/'demo/essentials/PBS/map_metadata.txt').read_text(encoding='utf-8-sig')
    for mid,(name,d) in data.items():
        metadata+=f'\n# Normanhurst opening\n[{mid:03d}]\nName = {d["name"]}\nSnapEdges = true\n'
        if mid in [200,203,204]:metadata+='Outdoor = true\n'
    (ROOT/'normanhurst/game/PBS/map_metadata.txt').write_text(metadata)
    encounters=(ROOT/'demo/essentials/PBS/encounters.txt').read_text(encoding='utf-8-sig')
    encounters+='\n# Normanhurst Bush Track\n[204]\nLand,15\n    40,PIDGEY,2,4\n    35,RATTATA,2,4\n    25,CATERPIE,2,3\n'
    (ROOT/'normanhurst/game/PBS/encounters.txt').write_text(encounters)
    credits=(ROOT/'docs/remastered-map-pack-import.md').read_text()+'\n'+(ROOT/'docs/remastered-credits-followup.md').read_text()
    (ROOT/'normanhurst/game/CREDITS-Remastered-Maps.txt').write_text('Selected adapted layouts: Pallet Town and Route 1. Not the Kanto region.\n'+credits)
    from redesign_normanhurst_opening import redesign
    redesign()
    print('Normanhurst maps 200-204, exterior tileset 26 and station tileset 27. Map 1 and start preserved.')

if __name__=='__main__':main()
