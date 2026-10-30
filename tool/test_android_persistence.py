"""Run four real-storage phases on a new disposable Android AVD, never a phone.

Requires an installed API 35 Google Play arm64 image. The existing AVD's config,
userdata and snapshots are neither copied nor modified. No adb clear/uninstall
or preferences reset is used. Temporary AVD files are removed after shutdown;
small log files remain in the printed artifacts directory.
"""
import argparse
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import uuid


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--android-sdk', default=os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or str(Path.home() / 'Library/Android/sdk'))
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Pass --flutter /absolute/path/to/flutter')
    sdk = Path(args.android_sdk).resolve()
    image = sdk / 'system-images/android-35/google_apis_playstore/arm64-v8a'
    if not (image / 'system.img').is_file():
        parser.error(f'Required system image missing: {image}')
    adb = str(sdk / 'platform-tools/adb')
    emulator = str(sdk / 'emulator/emulator')
    project = Path(__file__).resolve().parents[1]
    artifacts = Path(tempfile.mkdtemp(prefix='pocket-plan-persistence-logs-'))
    print(f'Artifacts: {artifacts}', flush=True)
    # Only claim an unused pair of emulator ports. Never select a connected phone.
    for port in range(5580, 5680, 2):
        try:
            with socket.socket() as first, socket.socket() as second:
                first.bind(('127.0.0.1', port))
                second.bind(('127.0.0.1', port + 1))
            break
        except OSError:
            continue
    else:
        raise RuntimeError('No unused emulator port pair')
    serial = f'emulator-{port}'
    token = uuid.uuid4().hex
    name = f'PocketPlanPersistence_{token}'
    with tempfile.TemporaryDirectory(prefix='pocket-plan-fresh-avd-') as temporary:
        root = Path(temporary)
        avd_home = root / 'avd'
        avd = avd_home / f'{name}.avd'
        avd.mkdir(parents=True)
        (avd_home / f'{name}.ini').write_text(f'avd.ini.encoding=UTF-8\npath={avd}\ntarget=android-35\n')
        (avd / 'config.ini').write_text('\n'.join([
            f'AvdId={name}', f'avd.ini.displayname={name}', 'avd.ini.encoding=UTF-8',
            f'image.sysdir.1={image}/', 'abi.type=arm64-v8a', 'hw.cpu.arch=arm64',
            'tag.id=google_apis_playstore', 'target=android-35', 'PlayStore.enabled=true',
            'hw.cpu.ncore=2', 'hw.ramSize=2048', 'hw.lcd.width=1080',
            'hw.lcd.height=2400', 'hw.lcd.density=420', 'hw.keyboard=yes',
            'hw.gpu.enabled=yes', 'hw.gpu.mode=auto', 'hw.sdCard=no',
            'disk.dataPartition.size=2G', 'fastboot.forceColdBoot=yes', '',
        ]))
        env = dict(os.environ, ANDROID_AVD_HOME=str(avd_home))
        with (artifacts / 'emulator.log').open('w') as output:
            process = subprocess.Popen([emulator, '-avd', name, '-port', str(port),
                '-no-window', '-no-audio', '-no-snapshot', '-no-boot-anim'],
                env=env, stdout=output, stderr=subprocess.STDOUT)
            owned = False
            try:
                deadline = time.monotonic() + 240
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError(f'Emulator exited; inspect {artifacts / "emulator.log"}')
                    boot = subprocess.run([adb, '-s', serial, 'shell', 'getprop', 'sys.boot_completed'],
                        capture_output=True, text=True, timeout=10)
                    if boot.stdout.strip() == '1':
                        break
                    time.sleep(2)
                else:
                    raise RuntimeError('Emulator boot timed out')
                actual = run([adb, '-s', serial, 'emu', 'avd', 'name'], capture_output=True).stdout.splitlines()[0]
                if actual != name:
                    raise RuntimeError('Refuse to use an emulator not created by this runner')
                owned = True
                package = 'com.example.my_first_app'
                for phase in ['seed', 'edit', 'delete', 'verify']:
                    print(f'Running {phase} on {serial} ({name})', flush=True)
                    # A force-stop ends the OS process, not just the Flutter widget.
                    run([adb, '-s', serial, 'shell', 'am', 'force-stop', package], capture_output=True)
                    pid = subprocess.run([adb, '-s', serial, 'shell', 'pidof', package], capture_output=True, text=True)
                    if pid.stdout.strip():
                        raise RuntimeError('Application process did not stop')
                    command = [args.flutter, 'test', 'integration_test/android_persistence_test.dart',
                        '-d', serial, '--no-uninstall',
                        '--dart-define=POCKET_PLAN_DISPOSABLE_TEST=true',
                        f'--dart-define=POCKET_PLAN_TEST_TOKEN={token}',
                        f'--dart-define=POCKET_PLAN_TEST_PHASE={phase}']
                    log = artifacts / f'{phase}.log'
                    with log.open('w') as stream:
                        result = subprocess.run(command, cwd=project, stdout=stream, stderr=subprocess.STDOUT)
                    contents = log.read_text()
                    if result.returncode or f'POCKET_PLAN_PERSISTENCE_OK:{phase}' not in contents:
                        raise RuntimeError(f'Phase {phase} failed; inspect {log}')
                    print(f'PASS: {phase}', flush=True)
                print('PASS: 4 phases across stopped/relaunched Android app processes', flush=True)
            finally:
                if owned:
                    subprocess.run([adb, '-s', serial, 'emu', 'kill'], capture_output=True, timeout=15)
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
    print(f'Fresh AVD removed. Test logs retained at {artifacts}', flush=True)


if __name__ == '__main__':
    main()
