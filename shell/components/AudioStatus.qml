import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: audio
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool backendAvailable: Pipewire.ready
    PwObjectTracker {
        objects: audio.sink ? [audio.sink] : []
    }
}
