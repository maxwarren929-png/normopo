#!/usr/bin/env python3
"""Optional live Essentials test in an isolated Xvfb display, not the user's desktop."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from essentials_cli.headless import default_xvfb, xvfb_environment
from essentials_cli.maps import ValidationError
from essentials_cli.project import Project
from essentials_cli.runtime import Runtime, release_game


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default='demo')
    parser.add_argument('--release', action='store_true', help='test without the debug argument')
    parser.add_argument('--plugin-ui', action='store_true', help='also test installed bag and modular UI plugins')
    parser.add_argument('--gym-tests', action='store_true', help='test the six Normanhurst trainer battles and Oliver Mega Blastoise')
    parser.add_argument('--battle', action='store_true', help='also complete one basic wild battle; requires --plugin-ui')
    parser.add_argument('--expanded-pokemon', action='store_true', help='test Gen 9 data and follower NPC/movement/toggle; requires --plugin-ui')
    parser.add_argument('--mega', action='store_true', help='test NPC Mega Raichu X/Y battles; requires --expanded-pokemon --battle')
    parser.add_argument('--trainer-intros', action='store_true', help='test animated trainer NPC battle; requires --expanded-pokemon --battle')
    parser.add_argument('--mega-scenes', action='store_true', help='test the DBK Mega preview and automatic exit; requires --plugin-ui')
    parser.add_argument('--vs-styles', action='store_true', help='test all four demo VS transitions and state restoration; requires --plugin-ui')
    parser.add_argument('--world-plugins', action='store_true', help='test indicators, puddles, news and market; requires --expanded-pokemon')
    parser.add_argument('--xvfb', default=default_xvfb())
    parser.add_argument('--wine', action='store_true',
                        help='test the windows-x86_64 runtime through Wine; implies --release')
    args = parser.parse_args()
    if (args.battle or args.expanded_pokemon) and not args.plugin_ui:
        parser.error('--battle and --expanded-pokemon require --plugin-ui for the disposable Pokemon fixture')
    if args.mega_scenes and not args.plugin_ui:
        parser.error('--mega-scenes requires --plugin-ui')
    if args.vs_styles and not args.plugin_ui:
        parser.error('--vs-styles requires --plugin-ui')
    if args.mega and not (args.expanded_pokemon and args.battle):
        parser.error('--mega requires --expanded-pokemon --battle')
    if args.trainer_intros and not (args.expanded_pokemon and args.battle):
        parser.error('--trainer-intros requires --expanded-pokemon --battle')
    if args.world_plugins and not args.expanded_pokemon:
        parser.error('--world-plugins requires --expanded-pokemon')
    if args.wine:
        args.release = True
        if not shutil.which('wine'):
            parser.error('--wine requires Wine on the development host')
    project = Project(args.project)
    target = 'windows-x86_64' if args.wine else 'linux-x86_64'
    runtime = Runtime(project.root / 'runtimes' / target, target)
    if not Path(args.xvfb).is_file():
        parser.error('Supply Xvfb using --xvfb or install it on the development host')
    # Release runs use exactly what a package ships: compiled data, no sources.
    game = release_game(project, runtime, args.xvfb) if args.release else project.build()
    source_manifest = project.root / 'plugin-sources.json'
    plugins = json.loads(source_manifest.read_text())['plugins'] if source_manifest.is_file() else []
    expected_plugins = {plugin['name']: plugin['version'] for plugin in plugins}
    results = project.root / 'build/runtime-smoke-results.json'
    results.unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix='.smoke-', dir=project.root / 'build') as temp:
        root = Path(temp) / 'game'
        runtime.compose(game, root, project.name, project.slug, release=args.release,
                        excludes=project.excludes if args.release else (), keeps=project.keeps)
        probe = Path(__file__).resolve().parents[1] / 'tests/runtime_smoke.rb'
        shutil.copyfile(probe, root / 'poke-runtime-smoke.rb')
        preloads = ['poke-runtime-smoke.rb']
        if args.plugin_ui or args.gym_tests:
            shutil.copyfile(probe.with_name('normanhurst_gacha_smoke.rb'), root / 'poke-normanhurst-gacha-smoke.rb')
            preloads.append('poke-normanhurst-gacha-smoke.rb')
        if args.gym_tests:
            shutil.copyfile(probe.with_name('normanhurst_gyms_smoke.rb'), root / 'poke-normanhurst-gyms-smoke.rb')
            preloads.append('poke-normanhurst-gyms-smoke.rb')
        if args.plugin_ui:
            shutil.copyfile(probe.with_name('custom_variants_smoke.rb'), root / 'poke-custom-variants-smoke.rb')
            preloads.append('poke-custom-variants-smoke.rb')
        if args.vs_styles:
            shutil.copyfile(probe.with_name('vs_styles_smoke.rb'), root / 'poke-vs-styles-smoke.rb')
            preloads.append('poke-vs-styles-smoke.rb')
        if args.mega_scenes:
            shutil.copyfile(probe.with_name('mega_scenes_smoke.rb'), root / 'poke-mega-scenes-smoke.rb')
            preloads.append('poke-mega-scenes-smoke.rb')
        config = json.loads((root / 'mkxp.json').read_text())
        config.update(preloadScript=preloads,
                      syncToRefreshrate=False, vsync=False, fixedFramerate=60)
        (root / 'mkxp.json').write_text(json.dumps(config, indent=2) + '\n')
        with xvfb_environment(args.xvfb, project.root / 'build/xvfb.log', Path(temp) / 'userdata') as env:
            env.update(POKE_SMOKE_GYMS='1' if args.gym_tests else '0',
                       POKE_EXPECTED_PLUGINS=json.dumps(expected_plugins),
                       POKE_SMOKE_PLUGIN_UI='1' if args.plugin_ui else '0',
                       POKE_SMOKE_BATTLE='1' if args.battle else '0',
                       POKE_SMOKE_EXPANDED='1' if args.expanded_pokemon else '0',
                       POKE_SMOKE_MEGA='1' if args.mega else '0',
                       POKE_SMOKE_WORLD='1' if args.world_plugins else '0',
                       POKE_SMOKE_TRAINER='1' if args.trainer_intros else '0',
                       POKE_SMOKE_VS_STYLES='1' if args.vs_styles else '0',
                       POKE_SMOKE_MEGA_SCENES='1' if args.mega_scenes else '0',
                       POKE_EXPECTED_TITLE=project.name, POKE_EXPECTED_SLUG=project.slug)
            arguments = [str(root / runtime.entrypoint)] + ([] if args.release else ['debug'])
            if args.wine:
                # A disposable prefix keeps saves and registry state out of ~/.wine.
                env.update(WINEPREFIX=str(Path(temp) / 'wineprefix'), WINEDEBUG='-all',
                           WINEDLLOVERRIDES='mscoree,mshtml=')
                arguments = ['wine'] + arguments
            timeout = 420 if args.vs_styles else 300 if args.trainer_intros else 210 if args.world_plugins else 150 if args.mega else 90
            if args.plugin_ui or args.gym_tests:
                timeout = max(timeout, 360)
            if args.wine:
                timeout += 120  # first-run prefix creation
            with (project.root / 'build/runtime-smoke.log').open('w') as log:
                try:
                    process = subprocess.run(arguments, cwd=root, env=env, stdout=log,
                                             stderr=subprocess.STDOUT, timeout=timeout)
                finally:
                    # Essentials may show a blocking native exception dialog.
                    # Retain its report even when the process times out.
                    for report in Path(temp).rglob('errorlog.txt'):
                        shutil.copyfile(report, project.root / 'build/runtime-smoke-errorlog.txt')
                    if args.wine:
                        subprocess.run(['wineserver', '-k'], env=env, check=False)
            produced = root / 'smoke-results.json'
            if not produced.is_file():
                raise RuntimeError(f'Runtime exited {process.returncode} without test results; '
                                   'see build/runtime-smoke.log')
            shutil.copyfile(produced, results)
            for image in root.glob('smoke-*.png'):
                shutil.copyfile(image, project.root / 'build' / ('runtime-' + image.name))
            payload = json.loads(results.read_text())
            print(json.dumps(payload, indent=2))
            return 0 if process.returncode == 0 and payload.get('passed') else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, ValidationError, subprocess.TimeoutExpired) as error:
        print(f'error: {error}', file=sys.stderr)
        raise SystemExit(1)
