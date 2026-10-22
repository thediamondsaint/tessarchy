import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../OskDismissPolicy.js" as Osk

TouchButton {
    id: control
    text: "Hide keyboard"
    implicitWidth: Osk.TARGET
    implicitHeight: Osk.TARGET
    Layout.minimumWidth: Osk.TARGET
    Layout.minimumHeight: Osk.TARGET
    focusPolicy: Qt.NoFocus
    padding: 0
    property color glyphColor: Theme.text
    onGlyphColorChanged: glyph.requestPaint()
    ToolTip.visible: hovered
    ToolTip.text: text
    ToolTip.delay: 500
    contentItem: Canvas {
        id: glyph
        onPaint: {
            const p = getContext("2d");
            p.reset();
            p.translate((width - 24) / 2, (height - 24) / 2);
            p.strokeStyle = control.glyphColor;
            p.lineWidth = 1.7;
            p.lineCap = "round";
            p.strokeRect(2, 1, 20, 12);
            for (let row = 0; row < 2; row++) {
                for (let col = 0; col < 5; col++) {
                    p.beginPath();
                    p.moveTo(5 + col * 3.5, 5 + row * 4);
                    p.lineTo(5.5 + col * 3.5, 5 + row * 4);
                    p.stroke();
                }
            }
            p.beginPath();
            p.moveTo(8, 18); p.lineTo(12, 22); p.lineTo(16, 18);
            p.stroke();
        }
    }
}
