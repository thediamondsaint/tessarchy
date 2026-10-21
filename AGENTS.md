# Tessarchy development

Tessarchy is an Arch session; Tessera is its Quickshell UI. Source is in `shell/`
and `session/`, integration checks in `tests/`, assets in `assets/`, packaging in
`packaging/`, and the live-image overlay in `iso/`. Generated output belongs in
`build/`, `dist/`, and `vm/` (ignored).

Before implementing a change, inspect the existing architecture, code and supported
upstream APIs. Reuse existing components and native capabilities before adding
new backends or abstractions.

Run `./scripts/check.sh` from this directory. Test install/uninstall using a
scratch HOME, never the developer's active session. Do not modify the host's
Hyprland/Omarchy configuration or install dependencies automatically. Session
configuration targets Hyprland 0.56 Lua and Quickshell 0.3.1. Check installed
QML type metadata and `Hyprland --verify-config` when changing those APIs.

Keep touch targets >=48 logical pixels; desktop quick-launch and tray controls use 32px width
and 48px height for the owner-requested compact spacing (2026-10-18).
On-screen keyboard keys may be narrower
but must remain >=48 logical pixels tall (owner decision 2026-10-17). Preserve
keyboard focus in navigation,
and confirm close and exit, except app dismissal in Recents, which closes
immediately by swipe-up, mouse double-click or its close button (owner decision
2026-10-19). No secure locking claims. Record actual validation
separately from planned/manual checks in docs/testing.md. Do not claim an ISO
boots until it has booted in a VM. Never run image builds with host privileges
without the user's explicit build command. Keep scripts argument-safe and fail
before overwriting unrelated files. Never commit disk images or private credentials.
Owner-designated public demo credentials may be documented when explicitly requested.

Agent onboarding and the shared planning backlog: [AGENT-README.md](AGENT-README.md).
Use standard technical English and one-line comments. Keep documentation direct:
state capabilities, instructions and validation once; omit repetitive caveats,
generic warnings and speculative disclaimers. Keep current evidence in
`docs/testing.md` and session progress in the ignored `.HANDOFF.local.md`.
Keep personal names, local usernames and absolute personal paths out of tracked
files. Use project-relative paths, `$HOME` or generic placeholders.
