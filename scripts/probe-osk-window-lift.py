"""Software-only #80 regression/control run; never compositor/device acceptance."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/osk-window-lift'
OUT.mkdir(parents=True, exist_ok=True)
os.environ.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QPA_PLATFORMTHEME='')


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(module, name, excluded=(), included=None):
    cases = unittest.defaultTestLoader.loadTestsFromModule(module)

    def flatten(suite):
        for item in suite:
            if isinstance(item, unittest.TestSuite):
                yield from flatten(item)
            else:
                method = item.id().rsplit('.', 1)[-1]
                if method not in excluded and (included is None or method in included):
                    yield item

    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(unittest.TestSuite(flatten(cases)))
    (OUT / (name + '.log')).write_text(stream.getvalue())
    summary = dict(tests=result.testsRun, failures=len(result.failures), errors=len(result.errors), skips=len(result.skipped))
    print(name, summary, flush=True)
    return result, summary


module = load('test_osk_window_lift', ROOT / 'tests/test_osk_window_lift.py')
baseline = OUT / 'baseline'
# Preserve the real baseline's Lua dependencies, not just its entry point.
paths = subprocess.check_output([
    'git', '-C', str(ROOT), 'ls-tree', '-r', '--name-only', 'c29e635', 'session'
], text=True).splitlines()
for path in paths:
    if path.endswith('.lua'):
        target = baseline / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'show', 'c29e635:' + path]))
setattr(module, 'ROOT', baseline)
controls, controls_summary = run(module, 'baseline-controls', included={
    'test_desktop_is_unchanged', 'test_accepted_resize_does_not_lift',
})
assert controls.testsRun == 2 and controls.wasSuccessful(), 'Baseline must load and pass positive controls'
red, red_summary = run(module, 'red')
assert red.failures and not red.errors, 'Control must fail behavioral assertions, not Python setup'
for _, failure in red.failures:
    assert not any(text in failure for text in ('cannot open', 'attempt to index', 'attempt to call')), failure
setattr(module, 'ROOT', ROOT)
green, green_summary = run(module, 'green')
assert green.wasSuccessful()
workflow = load('test_workflows', ROOT / 'tests/test_workflows.py')
excluded = ['test_portal_asks_shell_and_falls_back_to_gtk_in_desktop']
regression, regression_summary = run(workflow, 'workflows', excluded)
subprocess.run(['luac', '-p', str(ROOT / 'session/hyprland.lua')], check=True)
report = dict(baseline='c29e635', baseline_controls=controls_summary,
              red=red_summary, green=green_summary, workflows=regression_summary,
              excluded_native_build_test=excluded, lua_syntax='passed',
              compositor_or_device_acceptance=False,
              source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in (
                  'session/hyprland.lua', 'tests/test_osk_window_lift.py')},
              provenance='AI-assisted implementation and software-only verification')
(OUT / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
assert regression.wasSuccessful(), 'See workflows.log'
