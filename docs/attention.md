# Needs attention

Design conflicts and open questions found while building, which need a
contributor's decision rather than a quiet fix. Each entry says what was
measured, and where.

## Landscape keyboard leaves apps 248 px of 600

Found 2026-10-17, from #11's keyboard fit and the VM.
Updated after upstream #30 superseded #11; landscape has not been guest-tested
on the rebased branch.

The 48 rule allows keyboard keys to be narrower than 48 but not shorter
(AGENTS.md). Four rows of 48 plus gaps need at least a 224–225 logical px
keyboard. Even at that minimum, a 1200x600 landscape tablet leaves
600 - 48 (status bar) - 80 (nav bar) - 224 = 248 px for apps; a taller stock
panel leaves less. In a Tablet split each app gets about half of that.
Upstream only sets the **vertical** squeekboard multiplier; its horizontal
multiplier stays at stock. For a wide-layout 800x400 logical landscape output,
the stock panel is limited to half the output height (200 px), below the
225 px target. Whether to enforce that floor in landscape is a human design
decision, not a reason to silently spend more of the already cramped app area.

Options, none chosen:
- a landscape exception to the 48 rule for keyboard key height;
- a landscape keyboard layout with fewer rows (numbers and symbols moved to
  long-press or another view);
- hiding the nav bar (and maybe the status bar) while the keyboard is up,
  which gives back up to 128 px.
