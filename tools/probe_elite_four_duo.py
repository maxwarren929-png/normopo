#!/usr/bin/env python3
"""Disposable native validation and first-command-phase screenshot, not full battles."""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from essentials_cli.headless import default_xvfb,xvfb_environment
from essentials_cli.project import Project
from essentials_cli.runtime import Runtime,release_game


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=ROOT/'normanhurst')
    args=parser.parse_args()
    project=Project(args.project);runtime=Runtime(project.root/'runtimes/linux-x86_64','linux-x86_64')
    game=release_game(project,runtime,default_xvfb())
    out=ROOT/'normanhurst/build/elite-duo-review';out.mkdir(exist_ok=True,parents=True)
    with tempfile.TemporaryDirectory(prefix='.elite-duo-',dir=project.root/'build') as temp:
        folder=Path(temp)/'game';runtime.compose(game,folder,project.name,project.slug,release=True)
        config=json.loads((folder/'mkxp.json').read_text())
        config.update(preloadScript=['probe.rb'],syncToRefreshrate=False,vsync=False,fixedFramerate=60)
        (folder/'mkxp.json').write_text(json.dumps(config,indent=2)+'\n')
        for test,label in [('normanhurst_level_match_unit.rb','level-match'),('elite_four_duo_runtime.rb','duo')]:
            shutil.copyfile(ROOT/'tests'/test,folder/'probe.rb')
            with xvfb_environment(default_xvfb(),out/(label+'-xvfb.log'),Path(temp)/'userdata') as env:
                env['CLI_LEVEL_MATCH_SOURCE']=str(ROOT/'demo/scripts/0400-CLI_Normanhurst_Gym_Tests.rb')
                with (out/(label+'-runtime.log')).open('w') as log:
                    proc=subprocess.run([str(folder/runtime.entrypoint)],cwd=folder,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
            for name in ['elite-duo-report.json','elite-duo-battle.png','level-match-result.txt','errorlog.txt']:
                if (folder/name).exists():shutil.copyfile(folder/name,out/name)
            if proc.returncode:
                raise RuntimeError(f'{label} failed, see {out}')
        data=json.loads((out/'elite-duo-report.json').read_text());print(json.dumps(data,indent=2))
        assert data['passed']
if __name__=='__main__':main()
