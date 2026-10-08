#!/usr/bin/env python3
"""Import the two approved Mega fronts from local IF cells, without network access.

Does not compile, export, or change existing PBS/scripts. Run from the authoring
root. Sources and the first Tyranitar artwork backup are permanent game sources.
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

SELECTIONS = [('TYRANITAR', '248.248', 'dabouiw'),
              ('HONCHKROW', '256.256a', 'vultures')]
FOLDERS = ['Front', 'Front shiny', 'Back', 'Back shiny', 'Icons', 'Icons shiny']
FORMS = """# Approved Rock/Fire Tyranitar form 1 redesign is in pokemon_forms.txt.
[HONCHKROW,1]
FormName = Mega Honchkrow
MegaStone = HONCHKROWITE
UnmegaForm = 0
Types = DARK,FLYING
BaseStats = 100,150,72,86,140,72
Abilities = PLAGUEDOCTOR
HiddenAbilities = PLAGUEDOCTOR
"""
ITEMS = """[HONCHKROWITE]
Name = Honchkrowite
NamePlural = Honchkrowites
Pocket = 1
Price = 0
Flags = MegaStone
Description = A Mega Stone that enables Honchkrow to become Mega Honchkrow.
"""
METRICS = """[HONCHKROW,1]
BackSprite = 0,-10
FrontSprite = 0,0
ShadowX = 0
ShadowSize = 2
"""


def block_network(event, args):
    if event in ('socket.connect', 'socket.getaddrinfo', 'socket.sendto'):
        raise RuntimeError('Selected Mega import forbids network access')


def resolve_local(fuser):
    # No bytecode/cache writes outside the approved output paths.
    sys.dont_write_bytecode = True
    sys.addaudithook(block_network)
    spec = importlib.util.spec_from_file_location('selected_megas_if_server', fuser / 'server.py')
    server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(server)

    def cached_sheet(head, alt):
        path = Path(server.SHEETCACHE) / str(head) / f'{head}{alt}.png'
        return str(path) if path.is_file() else None

    result = []
    # Replace fetch_sheet with cache-only lookup, plus block urlopen and sockets.
    with patch.object(server, 'fetch_sheet', cached_sheet), patch.object(
            server.urllib.request, 'urlopen', side_effect=RuntimeError('Network forbidden')):
        for species, fusion, artist in SELECTIONS:
            match = re.fullmatch(r'(\d+)\.(\d+)([a-z]*)', fusion)
            image, source, author = server.resolve_sprite(
                int(match[1]), int(match[2]), match[3])
            if image is None or not image.getbbox() or source.startswith('autogen'):
                raise ValueError(f'Approved native cell unavailable locally: {fusion}: {source}')
            if author != artist:
                raise ValueError(f'Artist mismatch for {fusion}: {author!r}, expected {artist!r}')
            if image.size != (96, 96):
                raise ValueError(f'Expected full native 96x96 cell: {fusion}: {image.size}')
            result.append((species, fusion, artist, image.convert('RGBA'), source))
    return result


def link_new(destination, source):
    # Normanhurst's Graphics directory already links to the shared Demo tree.
    # Do not create a self-link when both names resolve to the same new file.
    if destination.resolve() == source.resolve():
        return
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
    sources = graphics / 'Selected Megas Sources'
    backup = sources / 'original-mega-tyranitar'
    # Fail before any writes if another form/item occupies our new IDs.
    for path in (game / 'PBS').glob('pokemon_forms*.txt'):
        if path.name != 'pokemon_forms_Selected_Megas.txt' and re.search(
                r'^\[HONCHKROW,1\]', path.read_text(encoding='utf-8-sig'), re.M):
            raise ValueError(f'Honchkrow form 1 already occupied in {path}')
    for path in (game / 'PBS').glob('items*.txt'):
        if path.name != 'items_Selected_Megas.txt' and '[HONCHKROWITE]' in path.read_text(encoding='utf-8-sig'):
            raise ValueError(f'Honchkrowite already defined in {path}')
    resolved = resolve_local(args.fuser)
    credits = [
        'Selected Mega artwork, Infinite Fusion community fan art.',
        'TYRANITAR form 1: IF 248.248, artist dabouiw.',
        'HONCHKROW form 1: IF 256.256a, artist vultures.',
        'Third-party art is not covered by the CLI MIT license. Keep artist credits.',
        'Resolved with /home/ko/if-fuser/server.py resolve_sprite, local files/cache only.',
        'Native full 96x96 RGBA source cells are retained without HGSS export or palette quantization.',
        'Battle art uses the full visible front, cropped only to transparent bounds,',
        'scaled exactly 2x nearest-neighbor and bottom-centered in a 192x192 frame.',
        'Back sprites mirror fronts as placeholders, not genuine rear views.',
        'Shiny battle art and icons match normal art as placeholders.',
        'Two-frame 128x64 menu icons derive from the native fronts.',
        '',
        'Tyranitar form 1 uses the approved Rock/Fire Thermal Armor redesign.',
        'Original form record and art are preserved; stone and existing metrics remain.',
        'Existing Tyranitar offsets are FrontSprite 11,10 and BackSprite 0,48.',
        'Those offsets predate this art; battle placement has not been checked in-game.',
        'Honchkrow form 1 was unused in all shared form PBS files, including Gen 9.',
        'Honchkrow is Dark/Flying, 620 BST, Plague Doctor, Honchkrowite, UnmegaForm 0.',
        'Custom abilities are registered separately by CLI_Selected_Mega_Abilities.',
        'The import tool does not alter moves, Mega animation hooks or Trainer PBS.',
        'Uses the existing generic DBK Mega presentation.',
        'Form and item PBS both live in Demo, with matching Normanhurst symlinks.',
        'Import tool performs no compilation, tests, network access or deployment.',
        'Honchkrowite reuses the existing Tyranitarite item icon as a placeholder.',
        '',
        'Permanent original Tyranitar form 1 assets, first-import backup, never overwritten:',
    ]
    for folder in FOLDERS:
        original = graphics / folder / 'TYRANITAR_1.png'
        saved = backup / folder / original.name
        if not saved.exists():
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, saved)
        credits.append(f'{saved.relative_to(game)} SHA256 {hashlib.sha256(saved.read_bytes()).hexdigest()}')
    sources.mkdir(parents=True, exist_ok=True)
    preview = Image.new('RGBA', (400, 234), (44, 48, 56, 255))
    draw = ImageDraw.Draw(preview)
    for i, (species, fusion, artist, native, source) in enumerate(resolved):
        native.save(sources / f'{fusion}.png')
        credits.append(f'Native {fusion}: {source}; credited artist {artist}.')
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
            destination = graphics / folder / f'{species}_1.png'
            destination.parent.mkdir(parents=True, exist_ok=True)
            # Existing Tyranitar assets are shared hardlinks between editions.
            # Saving in place keeps that explicit art replacement shared.
            frame.save(destination)
            if species == 'HONCHKROW':
                link_new(norm / 'Graphics/Pokemon' / folder / destination.name, destination)
        # Contact sheet shows full native cells at exactly 2x, including padding.
        preview.alpha_composite(native.resize((192, 192), Image.Resampling.NEAREST), (i * 200 + 4, 38))
        draw.text((i * 200 + 4, 4), f'{species} {fusion}', fill='white')
        draw.text((i * 200 + 4, 18), artist, fill='white')
    preview.save(sources / 'native-front-contact-sheet.png')
    for name, text in [('pokemon_forms_Selected_Megas.txt', FORMS),
                       ('items_Selected_Megas.txt', ITEMS),
                       ('pokemon_metrics_Selected_Megas.txt', METRICS)]:
        destination = game / 'PBS' / name
        destination.write_text(text, encoding='utf-8')
        link_new(norm / 'PBS' / name, destination)
    shutil.copyfile(game / 'Graphics/Items/TYRANITARITE.png',
                    game / 'Graphics/Items/HONCHKROWITE.png')
    destination = game / 'CREDITS-Selected-Megas.txt'
    destination.write_text('\n'.join(credits) + '\n', encoding='utf-8')
    link_new(norm / destination.name, destination)
    print(f'Native front contact sheet: {sources / "native-front-contact-sheet.png"}')


if __name__ == '__main__':
    main()
