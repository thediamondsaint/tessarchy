#!/usr/bin/env python3
"""Read-only, privacy-filtered identity for one Tessera runtime."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess


def run_command(args, timeout=3):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                                errors='replace')
    except subprocess.TimeoutExpired:
        return {'status': 'timeout'}
    except OSError:
        return {'status': 'unavailable'}
    if result.returncode:
        return {'status': 'failed'}
    return {'status': 'ok', 'stdout': result.stdout}


def command_status(result):
    value = result.get('status')
    return value if value in ('ok', 'failed', 'timeout', 'unavailable') else 'unavailable'


def json_reply(result, kind):
    if command_status(result) != 'ok':
        return None
    try:
        value = json.loads(result.get('stdout', ''))
    except (ValueError, TypeError):
        return None
    return value if isinstance(value, kind) else None


def process_start(process):
    return int((process / 'stat').read_text().rpartition(')')[2].split()[19])


def selected_source(process):
    if (process / 'comm').read_text().strip() not in ('qs', 'quickshell'):
        raise ValueError('not Quickshell')
    argv = (process / 'cmdline').read_bytes().decode(errors='replace').split('\0')
    candidates = []
    for index, value in enumerate(argv):
        if value in ('-p', '--path'):
            if index + 1 >= len(argv) or not argv[index + 1] or argv[index + 1].startswith('-'):
                raise ValueError('missing path')
            candidates.append(argv[index + 1])
        elif value.startswith('--path='):
            candidates.append(value.partition('=')[2])
    if len(candidates) != 1 or not candidates[0]:
        raise ValueError('ambiguous or absent path')
    config = Path(candidates[0])
    if not config.is_absolute():
        config = (process / 'cwd').resolve(strict=True) / config
    if config.is_dir():
        config = config / 'shell.qml'
    config = config.resolve(strict=True)
    root = config.parent.parent
    if (config.name != 'shell.qml' or config.parent.name != 'shell'
            or not (root / 'session/hyprland.lua').is_file()):
        raise ValueError('not a Tessera source layout')
    return root


def source_identity(root, run):
    hashes = {}
    excluded = 0
    extensions = {'.qml', '.js', '.svg', '.png', '.jpg', '.webp', '.ttf', '.otf'}
    paths = [p for p in (root / 'shell').rglob('*')
             if p.suffix in extensions or p.name == 'qmldir']
    paths += [root / 'session' / name for name in (
        'hyprland.lua', 'window-controls.lua', 'tessera-shell', 'start-tessarchy',
        'tessarchy-session-services', 'tessarchy-osk', 'tessarchy-theme', 'tessarchy-run')]
    for path in sorted(paths):
        if not path.is_file():
            continue
        try:
            if not path.resolve().is_relative_to(root):
                excluded += 1
                continue
            hashes[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError:
            excluded += 1
    result = {'kind': 'system' if root == Path('/usr/share/tessarchy') else 'custom',
              'files_sha256': hashes, 'excluded_files': excluded,
              'loaded_bytes_verified': False}
    # git -C also searches parent directories. An enclosing unrelated checkout
    # is not this selected source tree's Git identity.
    toplevel = run(['git', '--no-optional-locks', '-C', str(root), 'rev-parse', '--show-toplevel'])
    top_path = toplevel.get('stdout', '').strip()
    try:
        own_root = command_status(toplevel) == 'ok' and bool(top_path) and Path(top_path).resolve() == root
    except (OSError, RuntimeError):
        own_root = False
    if not own_root:
        return result
    revision = run(['git', '--no-optional-locks', '-C', str(root), 'rev-parse', 'HEAD'])
    text = revision.get('stdout', '').strip()
    if command_status(revision) == 'ok' and re.fullmatch(r'[0-9a-f]{40,64}', text):
        result['git_head'] = text
        dirty = run(['git', '--no-optional-locks', '-C', str(root), 'status', '--porcelain', '--untracked-files=no'])
        if command_status(dirty) == 'ok':
            result['git_tracked_changes'] = bool(dirty.get('stdout', ''))
    return result


def versions(run):
    qs = run(['qs', '--version'])
    quickshell = {'status': command_status(qs)}
    if quickshell['status'] == 'ok':
        match = re.search(r'\b(\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.]+)?)\b', qs.get('stdout', ''))
        if match:
            quickshell['version'] = match.group(1)
        else:
            quickshell['status'] = 'invalid'
    hl = run(['hyprctl', '-j', 'version'])
    compositor = {'status': command_status(hl)}
    reply = json_reply(hl, dict)
    if compositor['status'] == 'ok':
        compositor['status'] = 'ok' if reply is not None else 'invalid'
        for field, pattern in [('commit', r'[0-9a-f]{6,64}'),
                               ('tag', r'v?\d+\.\d+\.\d+[A-Za-z0-9_.+-]*')]:
            value = (reply or {}).get(field)
            if isinstance(value, str) and re.fullmatch(pattern, value):
                compositor[field] = value
    return {'quickshell': quickshell, 'hyprland': compositor,
            'query_context': 'invoking session; Quickshell CLI version is not proof of the running binary version'}


def monitor_geometry(run):
    response = run(['hyprctl', '-j', 'monitors'])
    result = {'status': command_status(response), 'items': [],
              'query_context': 'invoking session; use the target session environment'}
    reply = json_reply(response, list)
    if result['status'] == 'ok' and reply is None:
        result['status'] = 'invalid'
    for index, item in enumerate(reply or []):
        if not isinstance(item, dict):
            continue
        filtered: dict[str, int | float] = {'index': index}
        for key in ('width', 'height', 'x', 'y', 'scale', 'transform'):
            number = item.get(key)
            if isinstance(number, (int, float)) and not isinstance(number, bool) and math.isfinite(number):
                filtered[key] = number
        result['items'].append(filtered)
    return result


def collect_report(pid=None, *, proc_root=None, run=None):
    run = run or run_command
    proc_root = Path(proc_root or '/proc')
    response = run(['systemctl', '--user', 'show', 'tessera-shell.service',
                    '-p', 'MainPID', '-p', 'ActiveState', '-p', 'SubState', '-p', 'NRestarts'])
    properties = {}
    if command_status(response) == 'ok':
        properties = dict(line.split('=', 1) for line in response.get('stdout', '').splitlines() if '=' in line)
    service: dict[str, str | int | bool] = {'status': command_status(response)}
    for key in ('MainPID', 'NRestarts'):
        value = properties.get(key, '')
        if value.isdecimal():
            service[key] = int(value)
    for key in ('ActiveState', 'SubState'):
        value = properties.get(key, '')
        if value in ('active', 'inactive', 'failed', 'activating', 'deactivating',
                     'running', 'dead', 'exited', 'start', 'stop', 'auto-restart'):
            service[key] = value
    method = 'explicit' if pid is not None else 'service'
    pid = pid if pid is not None else service.get('MainPID', 0)
    report = {'schema': 1, 'date_utc': datetime.now(timezone.utc).isoformat(),
              'selection': {'method': method, 'status': 'unavailable'},
              'service': service, 'versions': versions(run), 'monitors': monitor_geometry(run)}
    if type(pid) is not int or pid <= 0:
        return report
    process = proc_root / str(pid)
    try:
        before = process_start(process)
        root = selected_source(process)
        source = source_identity(root, run)
        stable = process_start(process) == before
    except (OSError, ValueError, IndexError):
        return report
    report['selection'].update(pid=pid, status='identified' if stable else 'changed')
    report['process'] = {'start_ticks': before, 'identity_stable': stable}
    report['source'] = source
    service['selected_pid_matches'] = service.get('MainPID') == pid
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, help='Select one running Tessera Quickshell PID; default: service MainPID')
    args = parser.parse_args()
    report = collect_report(args.pid)
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0 if report['selection']['status'] == 'identified' else 1


if __name__ == '__main__':
    raise SystemExit(main())
