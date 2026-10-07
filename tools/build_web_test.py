#!/usr/bin/env python3
"""Build a local, uncompressed .mkxpz test archive. Does not publish anything."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import zipfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from essentials_cli.project import Project, copy_tree
from essentials_cli.runtime import RELEASE_EXCLUDED, RELEASE_EXCLUDED_SUFFIXES, Runtime, release_game, remove_excluded
from essentials_cli import config, marshal as rm
from essentials_cli.headless import default_xvfb


def buffered_animation_scripts(data):
    """Patch only the staged archive; keep the project's scripts unchanged."""
    archive = rm.loads(data)
    before = b'load_data("Data/PkmnAnimations.rxdata")'
    after = b'Marshal.load(File.binread("Data/PkmnAnimations.rxdata"))'
    matches = 0
    for row in archive:
        if row[1].data != b'MiscPBSData':
            continue
        source = zlib.decompress(row[2].data)
        matches += source.count(before)
        row[2].data = zlib.compress(source.replace(before, after))
    if matches != 1:
        raise ValueError(f'Expected one battle-animation loader, found {matches}')
    return rm.dumps(archive)


def deferred_battle_animation_scripts(data):
    """Remove only StartGame's eager load from the staged web scripts."""
    archive = rm.loads(data)
    starts = [row for row in archive if row[1].data == b'StartGame']
    loaders = [row for row in archive if row[1].data == b'MiscPBSData']
    if len(starts) != 1 or len(loaders) != 1:
        raise ValueError('Expected one StartGame and one MiscPBSData script')
    # Include the initialize prefix, not just the call, so another method's
    # adjacent calls cannot silently become the deferral target.
    before = (
        b'  def self.initialize\n'
        b'    $game_temp          = Game_Temp.new\n'
        b'    $game_system        = Game_System.new\n'
        b'    $data_animations    = load_data("Data/Animations.rxdata")\n'
        b'    $data_tilesets      = load_data("Data/Tilesets.rxdata")\n'
        b'    $data_common_events = load_data("Data/CommonEvents.rxdata")\n'
        b'    $data_system        = load_data("Data/System.rxdata")\n'
        b'    pbLoadBattleAnimations\n'
        b'    GameData.load_all\n'
    )
    source = zlib.decompress(starts[0][2].data)
    newline = b'\r\n' if b'\r\n' in source else b'\n'
    before = before.replace(b'\n', newline)
    if source.count(before) != 1 or source.count(b'  def self.initialize' + newline) != 1:
        raise ValueError('Expected one eager battle-animation load in StartGame.initialize')
    loader = zlib.decompress(loaders[0][2].data).replace(b'\r\n', b'\n')
    lazy = (
        b'def pbLoadBattleAnimations\n'
        b'  $game_temp = Game_Temp.new if !$game_temp\n'
        b'  if !$game_temp.battle_animations_data && pbRgssExists?("Data/PkmnAnimations.rxdata")\n'
        b'    $game_temp.battle_animations_data = LOAD\n'
        b'  end\n'
        b'  return $game_temp.battle_animations_data\n'
        b'end\n'
    )
    reads = (b'load_data("Data/PkmnAnimations.rxdata")',
             b'Marshal.load(File.binread("Data/PkmnAnimations.rxdata"))')
    if (sum(loader.count(lazy.replace(b'LOAD', read)) for read in reads) != 1
            or loader.count(b'def pbLoadBattleAnimations\n') != 1):
        raise ValueError('Expected the existing lazy battle-animation loader')
    after = before.replace(b'    pbLoadBattleAnimations' + newline, b'')
    starts[0][2].data = zlib.compress(source.replace(before, after, 1))
    return rm.dumps(archive)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default='normanhurst', type=Path)
    parser.add_argument('--xvfb', default=default_xvfb())
    parser.add_argument('--buffered-animation-load', action='store_true',
                        help='Apply the tested web-only bulk-read workaround to the staged scripts')
    parser.add_argument('--defer-battle-animations', action='store_true',
                        help='Defer the staged web battle-animation database load until first use')
    parser.add_argument('--no-path-cache', action='store_true',
                        help='Skip slow recursive asset indexing in the experimental browser runtime')
    args = parser.parse_args()
    project = Project(args.project)
    runtime = Runtime(project.root / 'runtimes/linux-x86_64', 'linux-x86_64')
    game = release_game(project, runtime, args.xvfb)
    output = project.root / 'build/web-player-review'
    output.mkdir(parents=True, exist_ok=True)
    suffix = (('-buffered' if args.buffered_animation_load else '')
              + ('-deferred' if args.defer_battle_animations else '')
              + ('-no-cache' if args.no_path_cache else ''))
    archive = output / (project.slug + suffix + '.mkxpz')
    with tempfile.TemporaryDirectory(prefix='.web-package-', dir=output) as temp:
        stage = Path(temp) / 'game'
        def ignore(directory, names):
            if Path(directory) != game:
                return []
            return [name for name in names if name in RELEASE_EXCLUDED or name in {'.poke-build', 'mkxp-z', 'mkxp', 'Game', 'game'} or Path(name).suffix.lower() in RELEASE_EXCLUDED_SUFFIXES | {'.exe', '.dll', '.so', '.dylib', '.app'}]
        copy_tree(game, stage, ignore=ignore)
        remove_excluded(stage, project.excludes, project.keeps)
        settings = config.loads((stage / 'mkxp.json').read_text(encoding='utf-8'))
        settings.update(windowTitle=project.name, dataPathApp=project.slug, rgssVersion=1, debugMode=False)
        if args.no_path_cache:
            settings['pathCache'] = False
        config.write(stage / 'mkxp.json', settings)
        if args.buffered_animation_load or args.defer_battle_animations:
            scripts = stage / 'Data/Scripts.rxdata'
            data = scripts.read_bytes()
            if args.buffered_animation_load:
                data = buffered_animation_scripts(data)
            if args.defer_battle_animations:
                data = deferred_battle_animation_scripts(data)
            scripts.write_bytes(data)
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_STORED, allowZip64=True) as bundle:
            for path in sorted(stage.rglob('*')):
                bundle.write(path, path.relative_to(stage).as_posix())
    manifest = {
        'project': project.slug, 'archive': archive.name,
        'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'size_bytes': archive.stat().st_size, 'compression': 'store',
        'web_runtime_tested': False,
        'compatibility_adjustments': (['buffered battle-animation load'] if args.buffered_animation_load else []) + (['deferred battle-animation load'] if args.defer_battle_animations else []) + (['pathCache disabled'] if args.no_path_cache else []),
        'note': 'Local compatibility experiment only. Not permission to redistribute third-party assets.'
    }
    (output / ('package' + suffix + '.json')).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(archive)
    print(f'{manifest["size_bytes"] / 1024**2:.1f} MiB, SHA256 {manifest["sha256"]}')


if __name__ == '__main__':
    main()
