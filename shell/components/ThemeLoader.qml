import QtQuick
import Quickshell
import Quickshell.Io

// Loads a palette file plus an optional shell.toml layer into Theme.
Scope {
    id: loader
    property string palettePath: ""
    property string layerPath: ""
    function apply() { Theme.load(paletteFile.text() + "\n" + layerFile.text()); }
    FileView {
        id: paletteFile
        path: loader.palettePath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: loader.apply()
    }
    FileView {
        id: layerFile
        path: loader.layerPath
        blockLoading: true
        printErrors: false
        onLoaded: loader.apply()
    }
}
