#!/usr/bin/env python3
"""Import approved Mega Breloom native IF art, cache-only, without compilation."""
import argparse
import csv
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import shutil
import sys
from unittest.mock import patch

from PIL import Image, ImageDraw

SPECIES, FORM, FUSION = 'BRELOOM', 1, '355.368b'
ARTIST = 'hero.drawing & ramxxxxxxxxxse'
FOLDERS = ['Front', 'Front shiny', 'Back', 'Back shiny', 'Icons', 'Icons shiny']
FORMS = """# Provisional Mega Breloom design, approved IF Breloom + Haxorus artwork.
[BRELOOM,1]
FormName = Mega Breloom
MegaStone = BRELOOMITE
UnmegaForm = 0
Types = GRASS,FIGHTING
BaseStats = 60,160,100,100,60,80
Abilities = TECHNICIAN
HiddenAbilities = TECHNICIAN
"""
ITEMS = """[BRELOOMITE]
Name = Breloomite
NamePlural = Breloomites
Pocket = 1
Price = 0
Flags = MegaStone
Description = A Mega Stone that enables Breloom to become Mega Breloom.
"""
METRICS = """[BRELOOM,1]
BackSprite = 0,-10
FrontSprite = 0,0
ShadowX = 0
ShadowSize = 2
"""


def block_network(event, args):
    if event in ('socket.connect', 'socket.getaddrinfo', 'socket.sendto'):
        raise RuntimeError('Mega Breloom import forbids network access')


def resolve_local(fuser):
    sys.dont_write_bytecode = True
    sys.addaudithook(block_network)
    spec = importlib.util.spec_from_file_location('mega_breloom_if_server', fuser / 'server.py')
    server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(server)
    with open(server.CREDITS_CSV, encoding='utf-8-sig', newline='') as stream:
        rows = [row for row in csv.reader(stream) if row and row[0] == FUSION]
    if len(rows) != 1 or len(rows[0]) < 2 or rows[0][1] != ARTIST:
        raise ValueError(f'Exact selected double-artist CSV credit mismatch: {rows!r}')

    def cached_sheet(head, alt):
        path = Path(server.SHEETCACHE) / str(head) / f'{head}{alt}.png'
        return str(path) if path.is_file() else None

    with patch.object(server, 'fetch_sheet', cached_sheet), patch.object(
            server.urllib.request, 'urlopen', side_effect=RuntimeError('Network forbidden')):
        image, source, author = server.resolve_sprite(355, 368, 'b')
    if image is None or not image.getbbox() or source.startswith('autogen'):
        raise ValueError(f'Approved native cell unavailable locally: {FUSION}: {source}')
    if author != ARTIST:
        raise ValueError(f'Artist mismatch: {author!r}, expected {ARTIST!r}')
    if image.size != (96, 96):
        raise ValueError(f'Expected full native 96x96 cell: {image.size}')
    return image.convert('RGBA'), source, rows[0]


def link_new(destination, source):
    if destination.resolve() == source.resolve():
        return  # Normanhurst Graphics already shares the Demo directory.
    if destination.exists() or destination.is_symlink():
        raise ValueError(f'Refusing to replace existing Normanhurst path: {destination}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.symlink_to(os.path.relpath(source, destination.parent))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--fuser', type=Path, default=Path('/home/ko/if-fuser'))
    args = parser.parse_args()
    game = args.root / 'demo/game'
    norm = args.root / 'normanhurst/game'
    graphics = game / 'Graphics/Pokemon'
    sources = graphics / 'Mega Breloom Sources'
    records = [('pokemon_forms_Mega_Breloom.txt', FORMS),
               ('items_Mega_Breloom.txt', ITEMS),
               ('pokemon_metrics_Mega_Breloom.txt', METRICS)]
    credits_path = game / 'CREDITS-Mega-Breloom.txt'
    # Recursive checks include every Gen 9 backup, not just active PBS.
    for path in (game / 'PBS').rglob('pokemon_forms*.txt'):
        if re.search(r'^\[BRELOOM,\s*1\]', path.read_text(encoding='utf-8-sig'), re.M):
            raise ValueError(f'BRELOOM form 1 already occupied in {path}')
    for path in (game / 'PBS').rglob('items*.txt'):
        if '[BRELOOMITE]' in path.read_text(encoding='utf-8-sig'):
            raise ValueError(f'Breloomite already defined in {path}')
    targets = [game / 'PBS' / name for name, _ in records] + [credits_path, sources,
               game / 'Graphics/Items/BRELOOMITE.png']
    targets += [graphics / folder / 'BRELOOM_1.png' for folder in FOLDERS]
    targets += [norm / 'PBS' / name for name, _ in records] + [norm / credits_path.name]
    targets += [norm / 'Graphics/Pokemon' / folder / 'BRELOOM_1.png' for folder in FOLDERS]
    targets += [norm / 'Graphics/Items/BRELOOMITE.png']
    for target in targets:
        if target.exists() or target.is_symlink():
            raise ValueError(f'Refusing to replace existing path: {target}')
    stone = game / 'Graphics/Items/TYRANITARITE.png'
    if not stone.is_file():
        raise ValueError(f'Missing existing stone icon: {stone}')
    native, source, credit_row = resolve_local(args.fuser)
    credits = [
        'Mega Breloom, Infinite Fusion community fan art.',
        f'BRELOOM form 1: IF {FUSION}, Breloom + Haxorus, artists {ARTIST}.',
        f'Exact current Sprite_Credits.csv row: {",".join(credit_row)}',
        'Double credit checked exactly, including spacing around the ampersand.',
        'Third-party art is not covered by the CLI MIT license. Keep both artist credits.',
        'Resolved with /home/ko/if-fuser/server.py resolve_sprite, local files/cache only.',
        'Network sockets and urlopen blocked; fetch_sheet replaced with cache-only lookup.',
        'Resolver source suffix (dl) means patched cache lookup, not a network download.',
        'Native full 96x96 RGBA source cell retained without palette quantization.',
        'Source backup directory: Graphics/Pokemon/Mega Breloom Sources.',
        'Battle fronts crop transparent bounds, scale exactly 2x nearest-neighbor,',
        'and bottom-center in 192x192 frames. No artwork is redrawn.',
        'Back sprites mirror fronts as placeholders, not genuine rear views.',
        'Shiny battle art and icons match normal art as placeholders.',
        'Two-frame 128x64 menu icons use the selected-Mega 40x56 thumbnail method.',
        'Breloomite copies the existing Tyranitarite icon as a placeholder.',
        'BRELOOM form 1 was unused in shared form PBS, including all Gen 9 backups.',
        'Provisional Grass/Fighting, Technician, 560 BST, +100 over ordinary Breloom.',
        'PBS stat order HP/Attack/Defense/Speed/SpAtk/SpDef: 60,160,100,100,60,80.',
        'MegaStone BRELOOMITE, UnmegaForm 0. Normal Breloom is unchanged.',
        'New form/item/metrics PBS and credits have matching Normanhurst symlinks.',
        'Graphics are shared by the existing Normanhurst Graphics directory symlink.',
        'No scripts, manifests, gacha, Trainer PBS or gift edits.',
        'No compilation, suites, browser checks or deployment performed.',
        f'Native {FUSION}: {source}; credited artists {ARTIST}.',
    ]
    sources.mkdir(parents=True)
    saved = sources / f'{FUSION}.png'
    native.save(saved)
    credits.append(f'{saved.relative_to(game)} SHA256 {hashlib.sha256(saved.read_bytes()).hexdigest()}')
    art = native.crop(native.getbbox())
    art = art.resize((art.width * 2, art.height * 2), Image.Resampling.NEAREST)
    for folder in FOLDERS:
        if folder.startswith('Icons'):
            icon = native.crop(native.getbbox())
            icon.thumbnail((40, 56), Image.Resampling.NEAREST)
            frame = Image.new('RGBA', (128, 64))
            for x in (0, 64):
                frame.alpha_composite(icon, (x + (64 - icon.width) // 2, 64 - icon.height))
        else:
            sprite = art.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if folder.startswith('Back') else art
            frame = Image.new('RGBA', (192, 192))
            frame.alpha_composite(sprite, ((192 - sprite.width) // 2, 192 - sprite.height))
        destination = graphics / folder / 'BRELOOM_1.png'
        destination.parent.mkdir(parents=True, exist_ok=True)
        frame.save(destination)
        link_new(norm / 'Graphics/Pokemon' / folder / destination.name, destination)
    preview = Image.new('RGBA', (280, 234), (44, 48, 56, 255))
    draw = ImageDraw.Draw(preview)
    draw.text((4, 4), f'BRELOOM {FUSION}', fill='white')
    draw.text((4, 18), ARTIST, fill='white')
    preview.alpha_composite(native.resize((192, 192), Image.Resampling.NEAREST), (44, 38))
    preview.save(sources / 'native-front-contact-sheet.png')
    for name, text in records:
        destination = game / 'PBS' / name
        destination.write_text(text, encoding='utf-8')
        link_new(norm / 'PBS' / name, destination)
    destination = game / 'Graphics/Items/BRELOOMITE.png'
    shutil.copyfile(stone, destination)
    link_new(norm / 'Graphics/Items/BRELOOMITE.png', destination)
    credits_path.write_text('\n'.join(credits) + '\n', encoding='utf-8')
    link_new(norm / credits_path.name, credits_path)
    print(f'BRELOOM form {FORM}; exact artists {ARTIST!r}; native source {source}')
    print(f'Native front contact sheet: {sources / "native-front-contact-sheet.png"}')


if __name__ == '__main__':
    main()
