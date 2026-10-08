#!/usr/bin/env python3
"""Import approved Mahoraga and Mega Tropius native IF cells, cache-only.

Creates only new form PBS, credits and art. No compilation or deployment.
"""
import argparse
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import shutil
import sys
from unittest.mock import patch

from PIL import Image, ImageDraw

SELECTIONS = [('MACHAMP', 1, '315.68c', '15kazuki'),
              ('TROPIUS', 1, '556.556', 'nighthawk3380')]
FOLDERS = ['Front', 'Front shiny', 'Back', 'Back shiny', 'Icons', 'Icons shiny']
FORMS = """# Name is not accepted by the Essentials form schema. The edition plugin
# must supply the Mahoraga display name; FormName retains the intended name.
[MACHAMP,1]
FormName = Mahoraga
Types = FIGHTING,STEEL
BaseStats = 90,130,100,70,65,100
Abilities = ADAPTATION
HiddenAbilities = ADAPTATION

[TROPIUS,1]
FormName = Mega Tropius
MegaStone = TROPIUSITE
UnmegaForm = 0
Types = GRASS,DRAGON
BaseStats = 99,88,113,31,112,117
Abilities = FRUITFULCANOPY
HiddenAbilities = FRUITFULCANOPY
"""
ITEMS = """[TROPIUSITE]
Name = Tropiusite
NamePlural = Tropiusites
Pocket = 1
Price = 0
Flags = MegaStone
Description = A Mega Stone that enables Tropius to become Mega Tropius.
"""
METRICS = """[MACHAMP,1]
BackSprite = 0,-10
FrontSprite = 0,0
ShadowX = 0
ShadowSize = 2

[TROPIUS,1]
BackSprite = 0,-10
FrontSprite = 0,0
ShadowX = 0
ShadowSize = 2
"""


def block_network(event, args):
    if event in ('socket.connect', 'socket.getaddrinfo', 'socket.sendto'):
        raise RuntimeError('Mahoraga/Tropius import forbids network access')


def resolve_local(fuser):
    sys.dont_write_bytecode = True
    sys.addaudithook(block_network)
    spec = importlib.util.spec_from_file_location('mahoraga_tropius_if_server', fuser / 'server.py')
    server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(server)

    def cached_sheet(head, alt):
        path = Path(server.SHEETCACHE) / str(head) / f'{head}{alt}.png'
        return str(path) if path.is_file() else None

    result = []
    with patch.object(server, 'fetch_sheet', cached_sheet), patch.object(
            server.urllib.request, 'urlopen', side_effect=RuntimeError('Network forbidden')):
        for species, form, fusion, artist in SELECTIONS:
            match = re.fullmatch(r'(\d+)\.(\d+)([a-z]*)', fusion)
            image, source, author = server.resolve_sprite(int(match[1]), int(match[2]), match[3])
            if image is None or not image.getbbox() or source.startswith('autogen'):
                raise ValueError(f'Approved native cell unavailable locally: {fusion}: {source}')
            if author != artist:
                raise ValueError(f'Artist mismatch for {fusion}: {author!r}, expected {artist!r}')
            if image.size != (96, 96):
                raise ValueError(f'Expected native 96x96 cell: {fusion}: {image.size}')
            result.append((species, form, fusion, artist, image.convert('RGBA'), source))
    return result


def link_new(destination, source):
    if destination.resolve() == source.resolve():
        return  # Graphics is already shared through a directory symlink.
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
    sources = graphics / 'Mahoraga Tropius Sources'
    records = [('pokemon_forms_Mahoraga_Tropius.txt', FORMS),
               ('items_Mahoraga_Tropius.txt', ITEMS),
               ('pokemon_metrics_Mahoraga_Tropius.txt', METRICS)]
    credits_path = game / 'CREDITS-Mahoraga-Tropius.txt'
    # Include the Gen 9 backups when checking form occupancy.
    for path in (game / 'PBS').rglob('pokemon_forms*.txt'):
        text = path.read_text(encoding='utf-8-sig')
        for species, form, _, _ in SELECTIONS:
            if re.search(rf'^\[{species},\s*{form}\]', text, re.M):
                raise ValueError(f'{species} form {form} already occupied in {path}')
    for path in (game / 'PBS').rglob('items*.txt'):
        if '[TROPIUSITE]' in path.read_text(encoding='utf-8-sig'):
            raise ValueError(f'Tropiusite already defined in {path}')
    targets = [game / 'PBS' / name for name, _ in records] + [credits_path, sources,
               game / 'Graphics/Items/TROPIUSITE.png']
    targets += [graphics / folder / f'{species}_{form}.png'
                for species, form, _, _ in SELECTIONS for folder in FOLDERS]
    targets += [norm / 'PBS' / name for name, _ in records] + [norm / credits_path.name]
    for target in targets:
        if target.exists() or target.is_symlink():
            raise ValueError(f'Refusing to replace existing path: {target}')
    stone = game / 'Graphics/Items/TYRANITARITE.png'
    if not stone.is_file():
        raise ValueError(f'Missing existing stone icon: {stone}')
    resolved = resolve_local(args.fuser)
    credits = [
        'Mahoraga Machamp and Mega Tropius, Infinite Fusion community fan art.',
        'MACHAMP form 1: Mahoraga, IF 315.68c, artist 15kazuki.',
        'TROPIUS form 1: Mega Tropius, IF 556.556, artist nighthawk3380.',
        'Third-party art is not covered by the CLI MIT license. Keep artist credits.',
        'Resolved with /home/ko/if-fuser/server.py resolve_sprite, local files/cache only.',
        'Native full 96x96 RGBA source cells are retained without palette quantization.',
        'Source backup directory: Graphics/Pokemon/Mahoraga Tropius Sources.',
        'Battle fronts crop transparent bounds, scale exactly 2x nearest-neighbor,',
        'and bottom-center in 192x192 frames. No artwork is redrawn.',
        'Back sprites mirror fronts as placeholders, not genuine rear views.',
        'Shiny battle art and icons match normal art as placeholders.',
        'Two-frame 128x64 menu icons use the selected-Mega 40x56 thumbnail method.',
        'Tropiusite copies the existing Tyranitarite icon as a placeholder.',
        'Both form 1 IDs were unused in shared form PBS, including Gen 9 backups.',
        'Base Machamp/Tropius forms, art, main PBS and existing items remain untouched.',
        'Mahoraga: Fighting/Steel, 555 BST, Adaptation. Not a Mega Evolution.',
        'Mega Tropius: Grass/Dragon, 560 BST, Fruitful Canopy, Tropiusite, UnmegaForm 0.',
        'Essentials Species.schema(true) does not accept Name for form records.',
        'FormName = Mahoraga records the intended name. The edition plugin must',
        'supply the species display name; this import does not change schema or scripts.',
        'Ability records/handlers and Mahoraga obtainability are implemented separately.',
        'New form/item/metrics PBS and credits have matching Normanhurst symlinks.',
        'Graphics are shared by the existing Normanhurst Graphics directory symlink.',
        'No compilation, suites, browser checks, network access or deployment performed.',
        '',
    ]
    sources.mkdir(parents=True)
    preview = Image.new('RGBA', (400, 234), (44, 48, 56, 255))
    draw = ImageDraw.Draw(preview)
    for i, (species, form, fusion, artist, native, source) in enumerate(resolved):
        saved = sources / f'{fusion}.png'
        native.save(saved)
        credits.append(f'Native {fusion}: {source}; credited artist {artist}.')
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
            destination = graphics / folder / f'{species}_{form}.png'
            frame.save(destination)
            link_new(norm / 'Graphics/Pokemon' / folder / destination.name, destination)
        preview.alpha_composite(native.resize((192, 192), Image.Resampling.NEAREST), (i * 200 + 4, 38))
        draw.text((i * 200 + 4, 4), f'{species} {fusion}', fill='white')
        draw.text((i * 200 + 4, 18), artist, fill='white')
    preview.save(sources / 'native-front-contact-sheet.png')
    for name, text in records:
        destination = game / 'PBS' / name
        destination.write_text(text, encoding='utf-8')
        link_new(norm / 'PBS' / name, destination)
    shutil.copyfile(stone, game / 'Graphics/Items/TROPIUSITE.png')
    credits_path.write_text('\n'.join(credits) + '\n', encoding='utf-8')
    link_new(norm / credits_path.name, credits_path)
    print(f'Native front contact sheet: {sources / "native-front-contact-sheet.png"}')


if __name__ == '__main__':
    main()
