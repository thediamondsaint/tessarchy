#!/usr/bin/env python3
"""Capture a disposable, diskless QEMU ISO boot; screenshots need human review."""
import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('iso', type=Path)
    parser.add_argument('output', type=Path, help='new directory; existing paths are refused')
    parser.add_argument('--firmware', choices=('bios', 'uefi'), default='bios')
    parser.add_argument('--accel', choices=('tcg', 'kvm'), default='tcg')
    parser.add_argument('--seconds', type=int, default=120)
    parser.add_argument('--sample-interval', type=int, default=0, help='capture early startup every N seconds (2–30)')
    parser.add_argument('--capture-launcher', action='store_true', help='click Home after the final capture for manual launcher review')
    parser.add_argument('--no-auto-enter', action='store_true', help='leave installer and confirmation screens untouched')
    args = parser.parse_args()
    if args.sample_interval and not 2 <= args.sample_interval <= 30:
        parser.error('Sample interval must be 2–30 seconds')
    iso = args.iso.resolve(strict=True)
    if not iso.is_file() or not 30 <= args.seconds <= 600:
        parser.error('ISO must be a file and capture duration must be 30–600 seconds')
    if not shutil.which('qemu-system-x86_64'):
        parser.error('qemu-system-x86_64 is required; install it explicitly')
    from PIL import Image
    firmware = None
    if args.firmware == 'uefi':
        for code, variables in [
            ('/usr/share/OVMF/OVMF_CODE_4M.fd', '/usr/share/OVMF/OVMF_VARS_4M.fd'),
            ('/usr/share/edk2/x64/OVMF_CODE.4m.fd', '/usr/share/edk2/x64/OVMF_VARS.4m.fd')]:
            if Path(code).is_file() and Path(variables).is_file():
                firmware = (code, variables)
                break
        if firmware is None:
            parser.error('OVMF firmware is required for UEFI; install it explicitly')
    output = args.output.resolve()
    if ',' in str(output) or ',' in str(iso):
        parser.error('QEMU paths must not contain commas')
    output.mkdir(parents=True, exist_ok=False)
    qmp = output / 'qmp.sock'
    if len(str(qmp).encode()) >= 104:
        parser.error('output path is too long for the QMP Unix socket')
    command = [
        'qemu-system-x86_64', '-name', 'Tessarchy ISO boot capture',
        '-machine', 'q35', '-accel', args.accel, '-cpu', 'host' if args.accel == 'kvm' else 'max',
        '-m', '2048', '-smp', '2', '-device', 'virtio-vga',
        '-device', 'qemu-xhci', '-device', 'usb-tablet', '-display', 'none',
        '-qmp', 'unix:' + str(qmp) + ',server=on,wait=off',
        '-serial', 'file:' + str(output / 'serial.log'),
        '-cdrom', str(iso), '-boot', 'order=d', '-nic', 'none', '-no-reboot']
    if firmware:
        variables = output / 'OVMF_VARS.fd'
        shutil.copy2(firmware[1], variables)
        command += ['-drive', 'if=pflash,format=raw,readonly=on,file=' + firmware[0],
                    '-drive', 'if=pflash,format=raw,file=' + str(variables)]
    (output / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
    with (output / 'qemu.log').open('wb') as log:
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log, stderr=log)
        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError('QEMU exited during startup; see qemu.log')
                if qmp.exists():
                    break
                time.sleep(0.1)
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                connection.settimeout(20)
                connection.connect(str(qmp))
                stream = connection.makefile('rwb')
                json.loads(stream.readline())

                def execute(name, arguments=None):
                    request = {'execute': name}
                    if arguments is not None:
                        request['arguments'] = arguments
                    stream.write((json.dumps(request) + '\n').encode())
                    stream.flush()
                    while True:
                        line = stream.readline()
                        if not line:
                            raise RuntimeError('QMP connection closed')
                        response = json.loads(line)
                        if 'error' in response:
                            raise RuntimeError(response['error'])
                        if 'return' in response:
                            return response['return']

                execute('qmp_capabilities')
                start = time.monotonic()
                time.sleep(3)
                if not args.no_auto_enter:
                    execute('human-monitor-command', {'command-line': 'sendkey ret'})
                samples = [10, 30, 60, args.seconds]
                if args.sample_interval:
                    samples += list(range(args.sample_interval, min(90, args.seconds) + 1, args.sample_interval))
                for second in sorted(set(samples)):
                    if second > args.seconds:
                        continue
                    time.sleep(max(0, second - (time.monotonic() - start)))
                    # Wake a blanked panel so idle timeouts cannot hide the shell.
                    if not args.no_auto_enter:
                        execute('human-monitor-command', {'command-line': 'sendkey ret'})
                    time.sleep(1)
                    name = 'final' if second == args.seconds else str(second)
                    ppm = output / (name + '.ppm')
                    execute('screendump', {'filename': str(ppm)})
                    with Image.open(ppm) as capture:
                        capture.save(output / (name + '.png'))
                    ppm.unlink()
                    print(f'{args.firmware}: captured {second}s', flush=True)
                if args.capture_launcher:
                    with Image.open(output / 'final.png') as capture:
                        width, height = capture.size
                    phone = min(width, height) < 600
                    desktop = not phone and width >= 1100 and height >= 650
                    count = 6 if phone or desktop else 7
                    dock = min(width - 32, 376 if phone else 448)
                    padding = 12 if phone else 16
                    capacity = max(1, (dock - padding * 2 + 4) // 52)
                    columns = count if capacity >= count else min(3, capacity)
                    button = (dock - padding * 2 - (columns - 1) * 4) / columns
                    column = (count - 2) % columns
                    x = 34 if desktop else width / 2 - dock / 2 + padding + column * (button + 4) + button / 2
                    events = [{'type': 'abs', 'data': {'axis': 'x', 'value': round(x * 32767 / width)}},
                              {'type': 'abs', 'data': {'axis': 'y', 'value': round((height - 42) * 32767 / height)}},
                              {'type': 'btn', 'data': {'button': 'left', 'down': True}}]
                    execute('input-send-event', {'events': events})
                    time.sleep(.1)
                    execute('input-send-event', {'events': [{'type': 'btn', 'data': {'button': 'left', 'down': False}}]})
                    time.sleep(2)
                    ppm = output / 'launcher.ppm'
                    execute('screendump', {'filename': str(ppm)})
                    with Image.open(ppm) as capture:
                        capture.save(output / 'launcher.png')
                    ppm.unlink()
                (output / 'status.json').write_text(json.dumps(execute('query-status'), indent=2) + '\n')
                execute('quit')
        finally:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            qmp.unlink(missing_ok=True)
    print('Capture complete; inspect screenshots before claiming boot success.', flush=True)


if __name__ == '__main__':
    main()
