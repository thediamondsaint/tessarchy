# Desktop taskbar vertical centring (#71)

## Confirmed scope

Centre the application icon and title vertically within each Desktop task selector.
Preserve the existing horizontal left alignment, padding, icon/title spacing,
button dimensions, selected/disabled appearance, title elision and activation.
No compositor, scaling, density, status-indicator or deployment changes.

The initial horizontal-centred implementation was a misinterpretation and is
superseded. Its passing tests did not establish a fix for the reported defect.
The original direct RowLayout has been restored before replacement testing.

## Reproduction and intended change

A direct content RowLayout receives 28 logical pixels inside a 48-pixel button
with 10-pixel top/bottom padding. When an image decodes to 36 pixels, Qt arranges
its children against that larger minimum height: the image centre becomes 28
rather than 24, and the text follows the same downward displacement. A controlled
36-pixel image reproduces this geometry with the unchanged component. This is a
layout reproduction, not proof of the device image provider's decoded size.

Use a content Item with a full-width RowLayout anchored only by vertical centre.
Keep the row at least as tall as both its implicit height and the available
content area; do not horizontally centre a short group. Keeping the existing
content-area height for small/iconless rows also preserves their pixel rounding.
This preserves icon dimensions while making top/bottom space symmetric.

## Acceptance

- Focused regression fails on the original vertical defect before implementation.
- Icon and title centres match the button centre within Qt rounding tolerance.
- Icon/title left edges match the original padding and 8-pixel gap.
- Cover normal and larger decoded images, iconless titles, multiple button widths,
  ordinary/selected/disabled states, long-title elision and activation.
- Exercise actual TaskStrip delegates within the Desktop-height row, not only
  standalone buttons.
- Inspect actual software-rendered before/after images before reporting success.
- Record current regression/lint results and public revision in PR #87.

## Coordination

PR #87 remains draft. Scope was originally published before implementation in
`50c900e`; the vertical-only correction is published before replacement coding.
Scaling #77 and native shutdown repair remain parked. No live desktop, VM or
physical-device changes are part of this correction.
