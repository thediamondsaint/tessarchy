# Updating an installed Tessarchy

An installed Tessarchy updates in place. You do not download another ISO or run
the installer again — the shell, the session config, the greeter and the
bootsplash are pacman packages served from the project's own repository, and
updating pulls only what changed. A full repository is about 10 MB; an ISO is
2 GB.

```
tessarchy-update                  # what is installed, what the last check found
tessarchy-update --check          # ask the repository (no privileges needed)
sudo tessarchy-update --apply     # install (full system upgrade)
sudo tessarchy-update --apply --packages-only   # faster, Tessarchy packages only
sudo tessarchy-update --offline /path/to/folder # .pkg.tar.zst from a USB stick
tessarchy-runtime activate       # apply new shell and compositor code in place
```

Exit codes make it scriptable: `0` up to date, `10` an update is available,
`1` the check itself failed.

## How an update happens

1. **The repository** is built by `scripts/build-packages.sh` and published
   beside the project site at `/pkgs/x86_64/`: the packages, a pacman database
   and a small `repo-info.json`.
2. **A check** fetches only `repo-info.json` (a few hundred bytes) and compares
   it with `pacman -Q`. That is why checking needs no privileges: it changes
   nothing.
3. **An install** hands the work to pacman, which knows the versions, the file
   ownership and the dependencies. `--apply` defaults to a full upgrade
   (`pacman -Syu`) because the Tessarchy packages depend on the base system, and
   updating only them on an old base is a partial upgrade.
4. **The running shell stays on its retained generation.** Pacman updates its
   package-owned candidates while the current Quickshell and Hyprland sessions
   use complete user-owned copies. After `--apply` or `--offline` finishes, run
   `tessarchy-runtime activate` from that same user session. It verifies the
   paired shell/session manifests, stages an immutable generation, reloads the
   compositor and Quickshell in process, checks both acknowledgments, and
   restores the previous generation if either reload fails. Open applications
   and the shell/compositor process identities remain in place.

### First adoption

The first package transaction that installs generation-aware launchers must
start after a voluntary logout. The old session still watches package-owned
paths and cannot be retargeted after it has started. Log back in once after the
transaction; the launcher creates a protected generation and stable regular
bootstrap paths. Later package transactions can run with the shell and
compositor active, followed by `tessarchy-runtime activate`.

The generation copies include the full packaged `shell/`, `session/`, and
`themes/` trees. Their manifests must agree and match every installed payload
file. Retained generations are not pruned, so loaded QML, compositor helpers,
themes and wallpaper references remain available. A locally edited package
payload or retained generation is preserved and causes activation to stop.
Development installs selected through `TESSARCHY_DATA_DIR` continue to use
their selected source directly.

Two timers do the checking for you and never install anything on their own:

- `tessarchy-update-check.timer` (system, daily) runs `tessarchy-update
  --check --quiet` and writes `/var/lib/tessarchy/update-state.json`.
- `tessarchy-update-notify.timer` (per user, from `/etc/skel`) tells the person
  at the machine, on their own desktop, that an update is waiting.

## Where the packages live

```
packaging/tessera-shell/        the shell and its QML
packaging/tessarchy-session/    Hyprland session, helpers, desktop entry
packaging/tessarchy-greeter/    the PIN sign-in
packaging/tessarchy-bootsplash/ the boot clip and Plymouth theme
packaging/tessarchy-tablet/     Intel/AMD tablet profile
packaging/tessarchy-update/     this tool, its timers and the repository config
```

`scripts/package.sh` builds them from a source archive of the repository;
`scripts/build-packages.sh` adds the database and `repo-info.json`. Adding a
package means adding a directory under `packaging/` — no list to edit.

## A first key, a fresh install

The medium carries its own packages (`/usr/share/tessarchy/pkgs`). The installer
hands them to pacman, so a machine is package-managed from its first boot and
`tessarchy-update` can tell exactly what is installed. If a machine was set up
from an older medium that had no packages, one command adopts the repository:

```
sudo tessarchy-update --enable-repo
sudo tessarchy-update --apply
```

## Pointing elsewhere

The repository is plain static files, so a mirror, a USB stick or a laptop on the
same network works as a source:

```
tessarchy-update --check --repo http://192.168.1.10:8000/pkgs/x86_64
TESSARCHY_UPDATE_REPO=http://192.168.1.10:8000/pkgs/x86_64 tessarchy-update
```

`--repo` and the environment variable name the directory that holds
`repo-info.json`. The file `pacman` reads is `/etc/pacman.d/tessarchy.conf`;
`--enable-repo` writes it and appends the `Include` line to `/etc/pacman.conf`.

## Known gaps

- **A full system upgrade still asks for a password.** The medium grants its
  own user exactly one thing without a password —
  `/usr/bin/tessarchy-update --apply --packages-only` — because an installed
  Tessarchy has a single user with no password to type, and without that grant
  it could never install an update at all. `--apply` (the whole base system) and
  `--enable-repo` (changing where updates come from) both still require one.
  See `iso/airootfs/etc/sudoers.d/tessarchy-update`.
- **The repository is not signed.** `SigLevel = Optional TrustAll` means the
  packages are trusted because they arrive over HTTPS from the project's own
  site. Signing the database with a project key is the next step; until then a
  changed `Server` deserves the same suspicion as a changed mirror.
- **No rollback.** pacman keeps the previous packages in its cache
  (`/var/cache/pacman/pkg`) and the runtime keeps previous complete generations;
  activation automatically restores the previous generation if a live reload
  fails. Rolling back package files remains a separate pacman operation.
- **No shell button yet.** `tessarchy-update --check --json` and
  `/var/lib/tessarchy/update-state.json` are already there for the shell to
  read; the UI is not wired up.

## Building an image for your own mirror

`stage-iso.sh` takes the repository URL from
`iso/airootfs/etc/pacman.d/tessarchy.conf`, and can point elsewhere without
editing it:

```
TESSARCHY_REPO_URL=http://mirror.test/pkgs ./scripts/stage-iso.sh
```

Every machine installed from that medium then updates from that mirror.
`--repo` / `TESSARCHY_UPDATE_REPO` override the *check* anywhere, but an
*install* uses what the machine is configured for — `--apply` refuses a source
the machine is not set up for and tells you to run `--enable-repo` first.

