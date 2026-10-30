"""Run the existing isolated smoke test on a newly created iOS simulator.

Does not download runtimes, change signing or use a physical iPhone. The new
simulator is shut down and deleted on completion; logs remain in a temp folder.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


def run(command, **kwargs):
    return subprocess.run(command, check=True, text=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--runtime', required=True, help='Installed iOS runtime identifier from simctl list runtimes')
    parser.add_argument('--device-type', default='com.apple.CoreSimulator.SimDeviceType.iPhone-17')
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Pass --flutter /absolute/path/to/flutter')
    listing = json.loads(run(['xcrun', 'simctl', 'list', 'runtimes', '--json'], capture_output=True).stdout)
    matches = [r for r in listing['runtimes'] if r['identifier'] == args.runtime and r.get('isAvailable') and r['name'].startswith('iOS')]
    if not matches:
        parser.error('Requested iOS runtime is not installed and available')
    project = Path(__file__).resolve().parents[1]
    artifacts = Path(tempfile.mkdtemp(prefix='pocket-plan-ios-smoke-logs-'))
    name = f'PocketPlanTest-{uuid.uuid4().hex}'
    device = run(['xcrun', 'simctl', 'create', name, args.device_type, args.runtime], capture_output=True).stdout.strip()
    if not device:
        raise RuntimeError('Simulator creation returned no identifier')
    print(f'Created test simulator: {name} ({device})', flush=True)
    print(f'Artifacts: {artifacts}', flush=True)
    try:
        run(['xcrun', 'simctl', 'boot', device], capture_output=True)
        with (artifacts / 'boot.log').open('w') as output:
            run(['xcrun', 'simctl', 'bootstatus', device, '-b'], stdout=output, stderr=subprocess.STDOUT, timeout=600)
        print('Simulator booted; building and running isolated smoke test', flush=True)
        log = artifacts / 'smoke.log'
        with log.open('w') as output:
            result = subprocess.run([args.flutter, 'test', 'integration_test/app_smoke_test.dart', '-d', device],
                cwd=project, text=True, stdout=output, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f'iOS smoke test failed; inspect {log}')
        print(f'PASS: iOS simulator smoke test. Logs: {artifacts}', flush=True)
    finally:
        # Only the newly returned simulator UUID is used. No other simulator or
        # phone is shut down, erased, deleted or selected by a generic alias.
        subprocess.run(['xcrun', 'simctl', 'shutdown', device], capture_output=True, timeout=60)
        run(['xcrun', 'simctl', 'delete', device], capture_output=True, timeout=60)
        print(f'Deleted test simulator: {device}', flush=True)


if __name__ == '__main__':
    main()
