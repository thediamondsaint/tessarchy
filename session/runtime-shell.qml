import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: runtime

    readonly property string runtimeHome: Quickshell.env("TESSARCHY_RUNTIME_HOME") || ""
    property var generationRoot: null
    property string generationId: activeGeneration.text().trim()

    function localFileUrl(path) {
        return "file://" + path.split("/").map(segment => encodeURIComponent(segment)).join("/")
    }

    function loadGeneration() {
        if (!runtimeHome.startsWith("/") || !/^[0-9a-f]{64}$/.test(generationId)) {
            console.error("Tessarchy runtime generation marker is invalid")
            return
        }
        const source = localFileUrl(runtimeHome + "/generations/" + generationId + "/shell/shell.qml")
        const component = Qt.createComponent(source)
        if (component.status !== Component.Ready) {
            console.error("Tessarchy runtime generation failed to load: " + component.errorString())
            Quickshell.execDetached(["tessarchy-runtime", "ack", "failure", component.errorString()])
            return
        }
        generationRoot = component.createObject(runtime)
        if (generationRoot === null) {
            console.error("Tessarchy runtime generation could not be created")
            Quickshell.execDetached(["tessarchy-runtime", "ack", "failure", "ShellRoot creation failed"])
        }
    }

    FileView {
        id: activeGeneration
        path: runtime.runtimeHome + "/active-generation"
        blockLoading: true
    }

    IpcHandler {
        target: "runtime"
        function reload(): void { Quickshell.reload(false) }
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            const status = runtime.generationRoot === null ? "failure" : "success"
            const detail = runtime.generationRoot === null ? "runtime generation is not loaded" : runtime.generationId
            Quickshell.execDetached(["tessarchy-runtime", "ack", status, detail])
        }
        function onReloadFailed(errorString) {
            Quickshell.execDetached(["tessarchy-runtime", "ack", "failure", errorString])
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false
        loadGeneration()
    }
}
