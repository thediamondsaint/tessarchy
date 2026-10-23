import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    name: "TessaTheme"
    function test_glow_follows_palette_and_semantic_override_resets() {
        Theme.load('accent = "#7aa2f7"\nforeground = "#a9b1d6"\n[tessera]\nwheel_glow = "#72cfff"');
        verify(Qt.colorEqual(Theme.wheelGlow, "#72cfff"));
        Theme.load('mode = "light"\naccent = "#8839ef"\nforeground = "#4c4f69"\nbackground = "#eff1f5"');
        verify(Qt.colorEqual(Theme.wheelGlow, "#8839ef"));
        verify(Qt.colorEqual(Theme.inputText, "#4c4f69"));
        compare(Theme.mode, "light");
        Theme.load('mode = "dark"\naccent = "#a7c080"\nforeground = "#d3c6aa"\nbackground = "#2d353b"');
        verify(Qt.colorEqual(Theme.wheelGlow, "#a7c080"));
        verify(Qt.colorEqual(Theme.inputText, "#d3c6aa"));
        compare(Theme.mode, "dark");
    }
}
