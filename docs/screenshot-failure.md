# Screenshot failure reporting (T03)

## Scope published before implementation

Branch: `fix/screenshot-failure-notification`, based on current upstream main.
No dependency on the touchpad investigation, native fitting, OSK or other drafts.
No equivalent screenshot-failure PR was open at scope time.

The existing screenshot helper removes partial captures and returns the capture
command's failure, but failure is only visible on stderr. Print and pull-down
launches need an optional desktop failure notification as well.

Implement a bounded change to `session/tessera-screenshot`:

- Keep unique private filenames, success output and existing optional success
  notification; reject unexpected arguments before attempting a capture.
- On dependency, destination preparation or capture failure, retain the original
  nonzero status and stderr, remove only the attempt's partial file, and emit one
  optional `Screenshot failed` notification with a fixed stage-specific reason.
- Notification absence/failure must not replace the capture result, print a
  saved path on failure, remove existing files or lose a successful capture.
- Do not include raw stderr or destination paths in failure notification bodies.

## Verification plan

RED-first subprocess tests with scratch HOME/config and controlled executable
fixtures; exercise actual helper control flow, file ownership/permissions and
notification arguments. Check missing dependency, mkdir/mktemp/capture failures,
success, optional/failing notification service and usage rejection. Preserve the
existing workflow cases. Run Bash syntax and the repository check script where
available. Fixtures are not compositor capture or desktop-notification delivery.
No host/device capture, input injection, service restart, package installation,
VM/GPU/native build, preference change or physical-sensor testing is in scope.

Live Print/pull-down framing and actual notification display remain separate T03
acceptance work, not claims established by helper subprocess tests.

## Status

Implemented optional, fixed stage-specific failure notifications for missing
grim, destination preparation, private-file creation and capture failure. EXIT
cleanup preserves the original status/stderr and removes only the attempt's
partial file. Success handling disables failure cleanup before notification or
stdout output, so a broken notification or pipe cannot discard a saved capture.
Usage rejection remains notification-free.

Actual verification:

- Original helper:16 focused cases run, eight failed on absent failure notices;
  the other eight preservation controls passed.
- Implemented helper:16/16 focused subprocess cases pass in scratch HOME with
  controlled commands (no desktop captured or notification displayed).
- `bash scripts/check.sh`:230 Python cases run, one skip (GObject metadata not
  installed);76 Qt software results and four website cases pass. Bash/Lua syntax,
  isolated native config parsing, QML lint and the remaining available checks
  completed. QML metadata warnings remain; fish and shellcheck unavailable.
- Bash syntax and `git diff --check` pass. Tests cover original exit status and
  stderr, partial-file cleanup, unrelated-file survival, literal paths, unique
  private0600 files, missing/broken notifications and broken stdout after success.

Reproduce from repository root:

```sh
python3 -m unittest discover -s tests -p test_screenshot_failure.py -v
bash scripts/check.sh
```

[Machine-readable helper checkpoint](evidence/screenshot-failure-cpu.json).
No actual compositor capture, Print/pull-down interaction or desktop notification
display tested: T03 end-to-end acceptance remains open. PR stays draft.

AI-assisted contribution.
