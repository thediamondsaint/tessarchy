# Runtime/source identity report (T04)

## Scope published before implementation

Branch `feat/runtime-identity-report`, from current upstream main. Independent
of screenshot/OSK drafts. No equivalent runtime-identity helper found among the
current open PRs or existing scripts.

Add an opt-in, read-only developer script and capture checklist. Identify one
running Quickshell process by explicit PID or the existing Tessera service's
MainPID; derive its source from that process's actual `--path`/`-p` argument.
Do not infer the running source from launcher defaults, a checkout or a package
version. Unresolvable/ambiguous selection is unavailable, not a guessed root.

Record source kind, disk source hashes and optional Git identity; selected
process/service state; bounded version queries; numeric monitor geometry and
scale/transform. Distinguish installed disk bytes from loaded QML state: the
report cannot prove which bytes a prior reload committed.

Exclude client titles/content, environment dumps, credentials, network endpoints,
monitor serials/descriptions, absolute source/home paths and raw command errors
from the JSON report. Use only fixed read-only command arguments, bounded calls
and ordinary source reads. No source/config writes, reload/restart, input,
notifications, capture, package changes, update-policy work or native builds.
This is a developer checklist/tool, not an installed session dependency.

## Verification

CPU tests with controlled process/source trees and command replies: explicit
selection, service selection, source arguments, missing/dead/ambiguous state,
version/query failure, timeouts, geometry filtering, source hashing and privacy.
Exercise `--help` and a real read-only Tessera process report when available;
keep fixture and actual-device observations separate. Run available repository
checks. Publish commands/evidence and keep draft pending unexercised cases.

## Usage and capture checklist

Run this from the target session/user, not another user's SSH context:

```sh
mkdir -p build
python3 scripts/runtime-identity.py > build/runtime-identity.json
# If started manually: set PID to the running Tessera PID reported by qs list.
python3 scripts/runtime-identity.py --pid "$PID" > build/runtime-identity.json
```

1. Confirm `selection.status` is `identified` and `process.identity_stable` is
   true. No PID/service or multiple source arguments fail unavailable, without
   guessing the caller's checkout. Exit 1 means the report lacks a stable source.
2. Confirm the source kind and disk hashes identify the intended source. Relative
   `--path` arguments use the selected process's cwd. A named `--config` alone is
   unavailable. Outside-root symlinks and non-source files are not hashed.
3. Version/socket queries use the **invoking session**. `--pid` selects source;
   it does not switch compositor sockets or select that process's executable.
   The Quickshell CLI version is not proof of the running binary's version.
4. Take the normal capture and retain this JSON beside it. The report does not
   capture pixels, reload anything or prove what an earlier QML reload loaded.
   Its reads are not an atomic snapshot: repeat after source/mode changes.
5. Review before sharing. The JSON omits absolute source paths and environment,
   client/title, monitor name/serial/description and command error text. It does
   retain relative source filenames, hashes, versions, numeric geometry, service
   state, PID/start identity and optional Git commit/tracked-change state.

Each command query has a three-second timeout. Git optional index-refresh locks
are disabled. The script is developer-only; it is not installed or run at login.

## Implementation and actual verification

The initial stub failed the 16-case RED run (1 assertion failure, 13 errors).
The implemented helper passes 24 focused cases, including an actual subprocess
failure/timeout and CLI-help execution. Controlled replies are tests, not device
measurements.

An in-memory invocation against the **existing running VM** identified one real
Tessera process and its actual custom source layout, hashed 126 runtime files,
confirmed stable PID/start identity and queried Quickshell 0.3.2 / Hyprland
v0.56.2. The real compositor returned 1280×800, scale 1, transform 0. Only read-only
queries/source reads ran: no source deployment, capture, input, reload, restart,
package changes or VM lifecycle changes. Sanitized report and exact helper hash
are recorded in `docs/evidence/runtime-identity-cpu.json`.

The configured ASUS connection did not resolve during the attempted read-only
check. That check produced no device report and no device changes; the VM result
is not ASUS validation. The final `bash scripts/check.sh` passed: 236 Python
tests run (one GI-dependent skip), 76 Qt results, four website tests and the
available syntax/config checks. Fish syntax and shellcheck were unavailable.

AI-assisted contribution.

## Peer-review follow-up: Git root identity

Read-only review found that `git -C source` can inherit a parent repository.
A real isolated Git fixture reproduced this (24 focused cases run, one RED).
The helper now requires `git rev-parse --show-toplevel` to resolve to the selected
source root before including HEAD/tracked-change metadata. A source directory
nested under an unrelated checkout no longer borrows that checkout's identity;
an actual selected-root repository still reports its real metadata. Git commands
retain `--no-optional-locks`, and the test uses isolated HOME/system/global Git
configuration. This is agent review, followed by lead reproduction and fix.

Final focused result:24 cases pass. Repository checks:238 Python run with one GI
skip,76 Qt results and four website passes; available syntax/config/QML pass,
optional fish/shellcheck absent. The corrected helper was re-exercised read-only
on the existing VM: real source identified,126 source files hashed, process
identity stable. No source/service/input/capture/VM lifecycle changes. Updated
actual report and helper hash are in the evidence artifact.
