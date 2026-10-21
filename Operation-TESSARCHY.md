# Operation TESSARCHY

## Goal
Continue developing Tessarchy into a polished, touch-first Linux experience for phones and tablets, with a matching desktop interface.

## Design direction already chosen
- Use phone UI design 3, “Quiet Edge.”
- Shallow, edge-to-edge glass status bar with clean, consistent minimal icons.
- Compact floating glass bottom navigation; smaller visual controls with generous touch targets (at least 48 logical pixels).
- Preserve the navy/mint glacier wallpaper identity and Tessarchy cube logo. Wallpaper colorways and tablet/desktop concept boards are available as references.

## Ideas and development tasks

### 1. Customizable swipe operations
- Let users assign actions to swipe gestures.
- Explore swipes for Back, Home, Recents, switching applications, and opening system controls.
- Make gesture settings discoverable and preserve visible navigation as an option.

### 2. Application switching
- Design a polished swipe-based app switcher, inspired by the interaction quality of iPhone multitasking.
- Explore a matching Alt+Tab interface for keyboard users.
- Keep touch and keyboard switching visually consistent.

### 3. More installed programs
- Propose a useful default application set, then integrate approved choices.
- Prioritize applications that work well on narrow touchscreens.

### 4. Phone and messaging
- Add a phone/dialer and messaging application.
- Investigate existing Linux applications and modem integration before building replacements.
- Separate app UI from actual calls, SMS, mobile data, audio routing, and carrier compatibility. Do not claim these work without device testing.

### 5. ARM and Snapdragon support
- Investigate ARM64 support alongside the existing x86_64 development path.
- Evaluate exact OnePlus 7 and OnePlus 8 models first. If unsuitable, evaluate OnePlus 6 and 6T.
- Verify current device-specific Linux support, bootloader unlocking, display, touch, accelerated graphics, Wi-Fi, charging, suspend, audio, and cellular functionality.
- Select hardware based on verified compatibility, rather than processor name or generation alone.
- Preserve as much Tessa QML/interface code as possible. Identify packaging, dependency, kernel, firmware and boot-image work separately.

### 6. WebUSB phone flasher
- Investigate a browser-based installer that can flash a supported phone and install Tessarchy.
- Determine feasibility for each exact model, browser, host platform and flashing protocol.
- Plan device detection, compatibility checks, prerequisites, verified image downloads/checksums, progress, error handling and recovery instructions.
- Explain destructive steps and require explicit confirmation before erasing or flashing. Do not assume WebUSB can unlock every bootloader or perform every recovery operation.
- Begin with one verified phone model and a proven install/recovery procedure before expanding support.

### 7. OpenRouter for lower-cost development work
- Investigate using OpenRouter for bounded, repetitive development tasks to reduce usage of the primary coding assistant.
- Check current models, prices, context limits, privacy/data policies, and available tooling before recommending a setup.
- Explore tasks such as documentation drafts, code explanations, small isolated edits, and test scaffolding.
- Keep architecture, review, integration and validation under the main coding workflow.
- Use budget caps and usage tracking; keep API keys out of source control and client-side code.
- Do not assume OpenRouter automatically reduces Codex token usage or integrates directly with the Codex client. Verify the actual integration route and total cost.

## What Codex should do first
1. Read the repository’s AGENTS.md and current implementation; reconcile this brief with the actual code.
2. Compare the UI reference boards with the current session and propose a small implementation sequence.
3. Verify phone compatibility and recommend one exact model before any hardware purchase or flashing.
4. Investigate OpenRouter integration and estimated costs before using paid API calls.
5. Implement in reviewable steps, run the repository’s required checks, and record what is implemented, tested, or still planned.

These are requested ideas and investigation tasks, not claims that the features or hardware support already exist.
