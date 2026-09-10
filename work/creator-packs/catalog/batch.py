"""Run a bounded two-process catalog build, preserving each command and result."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blender', required=True)
    parser.add_argument('--out', required=True)
    opt = parser.parse_args()
    out = Path(opt.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    modules = sorted((HERE/'packs').glob('*.py'))
    assert len(modules) == 9
    report = {'status': 'WORKING', 'started': time.time(),
              'source_sha256': {str(p.relative_to(HERE)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in [HERE/'build.py', HERE/'package.py', *modules]},
              'parallel_processes': 2, 'threads_per_blender': 2, 'packs': []}

    def run(module):
        slug = module.stem.replace('_', '-')
        target = out/slug
        (target/'evidence').mkdir(parents=True, exist_ok=True)
        command = [opt.blender, '--background', '--factory-startup', '--threads', '2',
                   '--python-exit-code', '1', '--python', str(HERE/'build.py'), '--',
                   '--module', str(module), '--out', str(target)]
        started = time.time()
        with (target/'evidence/build.log').open('w', encoding='utf-8') as log:
            completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        result = {'slug': slug, 'build_command': command, 'build_exit': completed.returncode}
        if completed.returncode == 0:
            package = subprocess.run([sys.executable, str(HERE/'package.py'), str(target)],
                                     capture_output=True, text=True)
            result['package_exit'] = package.returncode
            result['package_output'] = package.stdout
            result['package_error'] = package.stderr
        result['status'] = 'PASS' if result.get('package_exit') == 0 else 'FAIL'
        result['seconds'] = round(time.time()-started, 2)
        return result

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(run, module): module for module in modules}
        for future in as_completed(futures):
            try:
                result = future.result()
            except Exception as error:
                result = {'slug': futures[future].stem, 'status': 'FAIL', 'error': repr(error)}
            report['packs'].append(result)
            (out/'batch-validation.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
            print(json.dumps(result), flush=True)
    report['status'] = 'PASS' if all(p['status'] == 'PASS' for p in report['packs']) else 'FAIL'
    report['seconds'] = round(time.time()-report['started'], 2)
    (out/'batch-validation.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print('CATALOG_BATCH_'+report['status'], flush=True)
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
