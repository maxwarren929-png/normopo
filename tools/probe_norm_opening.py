#!/usr/bin/env python3
"""Render only the five current Normanhurst region maps in isolated native runtime."""
import json, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from essentials_cli.headless import default_xvfb, xvfb_environment
from essentials_cli.project import Project
from essentials_cli.runtime import Runtime, release_game

def main():
    project = Project(ROOT / 'normanhurst')
    runtime = Runtime(project.root / 'runtimes/linux-x86_64', 'linux-x86_64')
    game = release_game(project, runtime, default_xvfb())
    out = project.root / 'build/own-region-review'
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.own-region-', dir=project.root / 'build') as temp:
        root = Path(temp) / 'game'
        runtime.compose(game, root, project.name, project.slug, release=True)
        shutil.copyfile(ROOT / 'tests/own_region_opening_probe.rb', root / 'own-region-probe.rb')
        config = json.loads((root / 'mkxp.json').read_text())
        config.update(preloadScript=['own-region-probe.rb'], syncToRefreshrate=False, vsync=False, fixedFramerate=60)
        (root / 'mkxp.json').write_text(json.dumps(config, indent=2) + '\n')
        display = default_xvfb()
        with xvfb_environment(display, out / 'xvfb.log', Path(temp) / 'userdata') as env:
            log = (out / 'runtime.log').open('w')
            try:
                proc = subprocess.run([str(root / runtime.entrypoint)], cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            finally:
                log.close()
                for p in Path(temp).rglob('errorlog.txt'): shutil.copyfile(p, out / 'errorlog.txt')
        report = root / 'own-region-report.json'
        if report.exists():
            shutil.copyfile(report, out / 'report.json')
            for p in root.glob('norm-opening-*.png'): shutil.copyfile(p, out / p.name)
            data = json.loads(report.read_text())
        else:
            data = {'passed': False, 'error': 'probe produced no report'}
        print(json.dumps(data, indent=2))
        return int(proc.returncode != 0 or not data.get('passed'))
if __name__ == '__main__': raise SystemExit(main())
