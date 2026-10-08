"""Project validation and staged builds. The imported Essentials tree is read-only."""
from __future__ import annotations

import configparser
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import tomllib

from . import marshal as rm
from .maps import ValidationError, compile_map, dimensions, get, map_info, number, position, validate_map


EXAMPLE_MAP = {
    'id': 1, 'name': 'First room', 'size': [12, 10], 'tileset': 1,
    'layers': [{'fill': 384}, {'fill': 0}, {'fill': 0}],
    'events': [
        {'id': 1, 'name': 'Guide', 'position': [5, 4], 'trigger': 'action',
         'actions': [{'say': ['This room was generated from JSON.',
                              'No RPG Maker editor was used.']}]}
    ]
}

CONFIG = '''[project]
name = "My Pokemon game"
slug = "my-pokemon-game"
start = [1, 5, 5]

[essentials]
# Supply your own clean Essentials v21.1 project. Never use a shipped fan game.
path = "essentials"
'''


# Pixel-exact display settings for every target, not only the Linux payload.
# Runtime payloads may still override them for OS-specific reasons.
DISPLAY_SETTINGS = {
    'defScreenW': 512, 'defScreenH': 384, 'fixedAspectRatio': True,
    'integerScalingActive': True, 'integerScalingLastMile': False,
    'smoothScaling': 0, 'smoothScalingDown': 0, 'bitmapSmoothScaling': 0,
    # Nominal font heights clip the bottoms of Essentials' bitmap fonts.
    'fontHeightReporting': 1,
}

# The engine never writes these asset folders, so builds hardlink them instead
# of copying ~200 MB per build. Everything the game or compiler may rewrite in
# place (Data, PBS, Plugins, configs) is always a real copy.
LINKED_FOLDERS = ('Graphics', 'Audio', 'Fonts')

# Windows executables and DLLs from the imported project. Leaving them in
# build/game made it look like a runnable Windows release with stale data.
NATIVE_SUFFIXES = {'.exe', '.dll', '.so', '.dylib'}

COMPILED_STAMP = '.poke-compiled'


def link_or_copy(source, destination):
    if os.path.lexists(destination):
        os.unlink(destination)
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)
    return destination


def copy_tree(source, destination, ignore=None):
    """Copy a game tree, hardlinking the asset folders at its root."""
    source, destination = Path(source), Path(destination)

    def skip(directory, names):
        ignored = set(ignore(directory, names)) if ignore else set()
        if Path(directory) == source:
            ignored.update(name for name in names if name in LINKED_FOLDERS)
        return ignored

    shutil.copytree(source, destination, ignore=skip, dirs_exist_ok=True)
    for name in LINKED_FOLDERS:
        if (source / name).is_dir() and not (ignore and name in ignore(str(source), [name])):
            shutil.copytree(source / name, destination / name, copy_function=link_or_copy,
                            dirs_exist_ok=True, ignore=shutil.ignore_patterns('.git'))


def overlay_fingerprint(game):
    """Identify the PBS, plugin and script sources that compiled data came from."""
    digest = hashlib.sha256()
    game = Path(game)
    for folder in ('PBS', 'Plugins'):
        for path in sorted((game / folder).rglob('*')) if (game / folder).is_dir() else []:
            if path.is_file():
                digest.update(path.relative_to(game).as_posix().encode('utf-8') + b'\0')
                digest.update(hashlib.sha256(path.read_bytes()).digest())
    scripts = game / 'Data' / 'Scripts.rxdata'
    if scripts.is_file():
        digest.update(b'Scripts\0' + hashlib.sha256(scripts.read_bytes()).digest())
    return digest.hexdigest()


def read_json(path):
    if path.stat().st_size > 16 * 1024 * 1024:
        raise ValidationError(f'{path}: JSON file exceeds 16 MiB')
    return json.loads(path.read_text(encoding='utf-8'))


def read_data(path):
    if path.stat().st_size > 64 * 1024 * 1024:
        raise ValidationError(f'{path}: data file exceeds 64 MiB')
    return rm.loads(path.read_bytes())


def initialize(root):
    root = Path(root)
    if root.exists() and any(root.iterdir()):
        raise ValidationError(f'{root}: directory must be empty or not yet exist')
    (root / 'maps').mkdir(parents=True, exist_ok=True)
    (root / 'game').mkdir()
    (root / 'poke.toml').write_text(CONFIG, encoding='utf-8')
    (root / 'maps' / '001-first-room.json').write_text(
        json.dumps(EXAMPLE_MAP, indent=2) + '\n', encoding='utf-8')
    (root / '.gitignore').write_text('essentials/\nruntimes/\nbuild/\ndist/\n', encoding='utf-8')
    (root / 'game' / 'README.md').write_text(
        'Optional overlays: PBS/, Plugins/, Graphics/, Audio/, Fonts/, '
        'Data/Animations.rxdata, Data/PkmnAnimations.rxdata, and CREDITS-*.txt.\n'
        'They are copied into builds, never into the imported Essentials project.\n', encoding='utf-8')


class Project:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.config = tomllib.loads((self.root / 'poke.toml').read_text(encoding='utf-8'))
        settings = self.config.get('project', {})
        self.name = settings.get('name')
        self.slug = settings.get('slug')
        if not isinstance(self.name, str) or not self.name.strip():
            raise ValidationError('poke.toml: project.name must be nonempty text')
        if (not isinstance(self.slug, str) or not self.slug or
                any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in self.slug)):
            raise ValidationError('poke.toml: project.slug must use lowercase letters, digits, or hyphens')
        self.start = settings.get('start')
        if not isinstance(self.start, list) or len(self.start) != 3:
            raise ValidationError('poke.toml: project.start must be [map_id, x, y]')
        number(self.start[0], 'project.start.map_id', 1, 999)
        number(self.start[1], 'project.start.x', 0, 499)
        number(self.start[2], 'project.start.y', 0, 499)
        base = self.config.get('essentials', {}).get('path')
        if not isinstance(base, str) or not base:
            raise ValidationError('poke.toml: essentials.path must be a path')
        self.base = (self.root / base).resolve()
        package_settings = self.config.get('package', {})
        self.excludes, self.keeps = ([self.game_pattern(pattern, f'package.{name}')
                                      for pattern in package_settings.get(name, [])]
                                     for name in ('exclude', 'keep'))
        self.output = self.root / 'build' / 'game'
        if self.output.parent.is_symlink() or self.output.is_symlink():
            raise ValidationError('build/ and build/game must not be symbolic links')
        # Copying a parent directory into one of its children would recurse.
        # Using the output itself as the base would destroy the imported source.
        if (self.base == self.output or self.base == self.root or
                self.base in self.output.parents or self.output in self.base.parents):
            raise ValidationError('Essentials must be a separate directory, outside build/game')
        self.maps = {}
        for path in sorted((self.root / 'maps').glob('*.json')):
            try:
                data = validate_map(read_json(path))
            except (ValueError, TypeError) as exc:
                raise ValidationError(f'{path.name}: {exc}') from exc
            if data['id'] in self.maps:
                raise ValidationError(f'{path.name}: duplicate map id {data["id"]}')
            self.maps[data['id']] = data
        if not self.maps:
            raise ValidationError('No maps/*.json source files found')
        self.validate_references(require_base=False)
        self.script_archive = None
        if (self.root / 'scripts').exists():
            from .scripts import compile_scripts
            self.script_archive = compile_scripts(self.root / 'scripts')

    @staticmethod
    def game_pattern(pattern, label):
        path = PurePosixPath(pattern) if isinstance(pattern, str) else None
        if not path or not pattern or path.is_absolute() or '..' in path.parts or '\\' in pattern:
            raise ValidationError(f'poke.toml: {label} must be relative paths or globs inside the game')
        return pattern

    def validate_references(self, require_base):
        sizes = {mid: data['size'] for mid, data in self.maps.items()}

        def lookup(mid):
            if mid not in sizes:
                path = self.base / 'Data' / f'Map{mid:03d}.rxdata'
                if not path.is_file():
                    raise ValidationError(f'Missing map {mid}')
                sizes[mid] = dimensions(read_data(path))
            return sizes[mid]

        mid, x, y = self.start
        width, height = lookup(mid)
        position([x, y], 'project.start', width, height)
        for data in self.maps.values():
            for event in data.get('events', []):
                for action in event['actions']:
                    if 'transfer' in action:
                        transfer = action['transfer']
                        width, height = lookup(transfer['map'])
                        position(transfer['position'], f'map {data["id"]} transfer', width, height)
        if not require_base:
            return
        for filename in ('MapInfos.rxdata', 'System.rxdata', 'Tilesets.rxdata', 'Scripts.rxdata'):
            if not (self.base / 'Data' / filename).is_file():
                raise ValidationError(f'Missing Essentials Data/{filename}; set essentials.path in poke.toml')
        if not (self.base / 'Game.ini').is_file() or not (self.base / 'PBS').is_dir():
            raise ValidationError('Expected an unpacked Essentials project with Game.ini and PBS/')
        self.infos = read_data(self.base / 'Data' / 'MapInfos.rxdata')
        self.system = read_data(self.base / 'Data' / 'System.rxdata')
        self.tilesets = read_data(self.base / 'Data' / 'Tilesets.rxdata')
        overlay_tilesets = self.root / 'game' / 'Data' / 'Tilesets.rxdata'
        if overlay_tilesets.is_file():
            self.tilesets = read_data(overlay_tilesets)
            if not isinstance(self.tilesets, list) or any(
                    entry is not None and (not isinstance(entry, rm.RubyObject) or
                                           entry.class_name != 'RPG::Tileset')
                    for entry in self.tilesets):
                raise ValidationError('Invalid tileset archive in game/Data/Tilesets.rxdata')
            for index, entry in enumerate(self.tilesets):
                if entry is None:
                    continue
                tileset_id = get(entry, 'id')
                if tileset_id != index:
                    raise ValidationError(f'Invalid tileset ID at slot {index} in game/Data/Tilesets.rxdata')
                for table_name in ('passages', 'priorities'):
                    table = get(entry, table_name)
                    if (not isinstance(table, rm.UserData) or table.class_name != 'Table' or
                            len(table.data) < 20):
                        raise ValidationError(f'Invalid tileset {table_name} table at slot {index}')
        if not isinstance(self.infos, dict) or not isinstance(self.tilesets, list):
            raise ValidationError('Invalid MapInfos or Tilesets data')
        if not isinstance(self.system, rm.RubyObject) or self.system.class_name != 'RPG::System':
            raise ValidationError('Invalid RPG::System data')
        for mid, data in self.maps.items():
            tid = data['tileset']
            if tid >= len(self.tilesets) or self.tilesets[tid] is None:
                raise ValidationError(f'map {mid}: tileset {tid} does not exist in Essentials')
            tileset = self.tilesets[tid]
            # The passage table bounds the usable tile IDs, including autotiles.
            passages = get(tileset, 'passages')
            if not isinstance(passages, rm.UserData) or passages.class_name != 'Table' or len(passages.data) < 20:
                raise ValidationError(f'map {mid}: invalid tileset passage table')
            import struct
            tile_count = struct.unpack_from('<5i', passages.data)[4]
            for layer in data['layers']:
                used = layer['legend'].values() if 'rows' in layer else [layer.get('fill', 0)]
                if any(tile >= tile_count for tile in used):
                    raise ValidationError(f'map {mid}: tile ID outside tileset {tid} passage table')
            for event in data.get('events', []):
                graphic = event.get('graphic', '')
                if graphic:
                    graphics_root = self.base / 'Graphics' / 'Characters'
                    overlay_root = self.root / 'game' / 'Graphics' / 'Characters'
                    if (Path(graphic).is_absolute() or '..' in Path(graphic).parts or
                            '\\' in graphic or ':' in graphic):
                        raise ValidationError(f'map {mid}: invalid character graphic path')
                    if not any((root / (graphic + suffix)).is_file()
                               for root in (overlay_root, graphics_root)
                               for suffix in ('', '.png', '.PNG', '.jpg', '.bmp')):
                        raise ValidationError(f'map {mid}: character graphic {graphic!r} not found')

    def build(self):
        self.validate_references(require_base=True)
        if self.output.exists() and not (self.output / '.poke-build').is_file():
            raise ValidationError(f'Refusing to replace unmanaged directory {self.output}')
        self.output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.stage-', dir=self.output.parent) as temp:
            stage = Path(temp) / 'game'
            base_ignore = shutil.ignore_patterns('.git', 'Save*.rxdata', '__pycache__')

            def ignore(directory, names):
                ignored = set(base_ignore(directory, names))
                if Path(directory) == self.base:
                    ignored.update(name for name in names if Path(name).suffix.lower() in NATIVE_SUFFIXES)
                return ignored

            copy_tree(self.base, stage, ignore=ignore)
            overlay = self.root / 'game'
            allowed = {'PBS', 'Plugins', 'Graphics', 'Audio', 'Fonts'}
            if overlay.is_dir():
                for path in overlay.iterdir():
                    if path.name == 'README.md':
                        continue
                    if path.name.startswith('CREDITS-') and path.suffix == '.txt' and path.is_file():
                        shutil.copy2(path, stage / path.name)
                        continue
                    if path.name == 'Data' and path.is_dir():
                        # Animation resources may replace overworld or battle
                        # animation archives, never maps/scripts or PBS caches.
                        for asset in path.iterdir():
                            if asset.name == 'Tilesets.rxdata' and asset.is_file():
                                # Validated against the complete replacement array above.
                                shutil.copy2(asset, stage / 'Data' / asset.name)
                                continue
                            if asset.name not in {'Animations.rxdata', 'PkmnAnimations.rxdata'} or not asset.is_file():
                                raise ValidationError('game/Data only supports Animations.rxdata, PkmnAnimations.rxdata, or Tilesets.rxdata')
                            if asset.name == 'PkmnAnimations.rxdata':
                                # PBAnimations subclasses Array with Ruby's C tag,
                                # which our map-focused Marshal reader doesn't support.
                                # Check its envelope only; runtime tests validate content.
                                if not asset.read_bytes().startswith(b'\x04\x08IC:\x11PBAnimations['):
                                    raise ValidationError('Invalid battle animation archive in game/Data/PkmnAnimations.rxdata')
                                shutil.copy2(asset, stage / 'Data' / asset.name)
                                continue
                            animations = read_data(asset)
                            if not isinstance(animations, list) or any(
                                    entry is not None and (not isinstance(entry, rm.RubyObject) or
                                                           entry.class_name != 'RPG::Animation')
                                    for entry in animations):
                                raise ValidationError('Invalid animation archive in game/Data/Animations.rxdata')
                            shutil.copy2(asset, stage / 'Data' / asset.name)
                        continue
                    if path.name not in allowed or not path.is_dir():
                        raise ValidationError(f'Unsupported game/ overlay {path.name}; allowed: {sorted(allowed)}')
                    if path.name in LINKED_FOLDERS:
                        shutil.copytree(path, stage / path.name, dirs_exist_ok=True, copy_function=link_or_copy)
                    else:
                        shutil.copytree(path, stage / path.name, dirs_exist_ok=True)
            data_dir = stage / 'Data'
            for order, (mid, data) in enumerate(sorted(self.maps.items()), 1):
                (data_dir / f'Map{mid:03d}.rxdata').write_bytes(rm.dumps(compile_map(data)))
                # Preserve existing hierarchy and ordering when replacing a map.
                if mid in self.infos:
                    rm.set_field(self.infos[mid], 'name', rm.string(data['name']))
                else:
                    self.infos[mid] = map_info(data['name'], len(self.infos) + order)
            (data_dir / 'MapInfos.rxdata').write_bytes(rm.dumps(self.infos))
            for field, value in zip(('start_map_id', 'start_x', 'start_y'), self.start):
                rm.set_field(self.system, field, value)
            (data_dir / 'System.rxdata').write_bytes(rm.dumps(self.system))
            if self.script_archive is not None:
                (data_dir / 'Scripts.rxdata').write_bytes(rm.dumps(self.script_archive))
            ini = configparser.ConfigParser(interpolation=None)
            ini.optionxform = str
            ini.read(stage / 'Game.ini', encoding='utf-8-sig')
            if not ini.has_section('Game'):
                raise ValidationError('Game.ini is missing [Game]')
            ini['Game']['Title'] = self.slug
            with (stage / 'Game.ini').open('w', encoding='utf-8') as handle:
                ini.write(handle)
            from . import config
            runtime_config = stage / 'mkxp.json'
            settings = config.loads(runtime_config.read_text(encoding='utf-8-sig')) if runtime_config.exists() else {}
            settings.update(DISPLAY_SETTINGS)
            settings.update(windowTitle=self.name, dataPathApp=self.slug, rgssVersion=1, debugMode=False)
            settings.pop('gameFolder', None)
            config.write(runtime_config, settings)
            (stage / '.poke-build').write_text('essentials-cli\n', encoding='utf-8')
            if self.output.exists():
                shutil.rmtree(self.output)
            shutil.move(str(stage), self.output)
        return self.output
