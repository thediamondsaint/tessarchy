pragma ComponentBehavior: Bound
import QtQuick
import "../SwitcherPolicy.js" as SwitcherPolicy
import Quickshell.Wayland
import Quickshell.Widgets

// Live app previews with an overlapping stack and app headers in phone mode.
FocusScope {
    id: control
    property var windows: []
    property var activeWindow: null
    property color accentColor: Theme.accent
    property bool reducedMotion: false
    property bool fillApp: false
    property bool phoneMode: false
    property bool tabletMode: false
    property var splitFirst: null
    onVisibleChanged: if (!visible) splitFirst = null
    property var iconForWindow: window => ""
    property var nameForWindow: window => window.title || "Untitled window"
    property string emptyHint: "No open apps"
    property var pendingTarget: null
    property var selection: null
    property var activateTarget: target => target.activate()
    readonly property int currentIndex: cards.currentIndex
    /// Screen the apps are running on; keeps card previews at the real aspect
    /// so nothing is letterboxed inside a taller card.
    property var screenSize: Qt.size(400, 800)
    readonly property real aspect: screenSize.height > 0 ? screenSize.width / screenSize.height : 0.5
    /// Every card keeps the same footprint so the stack looks even.
    readonly property real cardWidth: phoneMode ? Math.min(width * 0.78, Math.max(1, height - 100) * aspect) : Math.min(Math.max(180, width - 72), 320)
    readonly property real cardHeight: Math.min(height - (phoneMode ? 56 : 0), cardWidth / Math.max(0.2, aspect))
    signal activated
    signal dismissed
    signal closeRequested(var target)
    signal splitRequested(var first, var second)

    onWindowsChanged: {
        if (windows.indexOf(splitFirst) < 0) splitFirst = null;
        if (windows.indexOf(selection) < 0) selectActive();
        else cards.currentIndex = windows.indexOf(selection);
        Qt.callLater(() => { cards.currentIndex = control.windows.indexOf(control.selection); });
    }

    function selectActive() {
        const active = windows.indexOf(activeWindow);
        cards.currentIndex = Math.max(0, active >= 0 ? active : SwitcherPolicy.activeIndex(windows));
        selection = windows[cards.currentIndex] || null;
    }
    function step(direction) {
        cards.currentIndex = SwitcherPolicy.advance(windows.indexOf(selection), direction, windows.length);
        selection = windows[cards.currentIndex] || null;
    }
    function activateCurrent() {
        const window = selection && windows.indexOf(selection) >= 0 ? selection : windows[cards.currentIndex];
        if (window && window.wayland) {
            pendingTarget = window.wayland;
            activated();
            // Let the compositor release the switcher's keyboard grab first.
            activateTimer.restart();
        }
        else if (!cards.count) dismissed();
    }
    Timer {
        id: activateTimer
        interval: 100
        onTriggered: {
            const target = control.pendingTarget;
            control.pendingTarget = null;
            if (target) {
                control.activateTarget(target);
                if (control.fillApp && !control.phoneMode) target.maximized = true;
            }
        }
    }
    Connections {
        target: control.pendingTarget
        function onClosed() { control.pendingTarget = null; }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            step(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
            activateCurrent();
            event.accepted = true;
        }
    }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onEscapePressed: dismissed()

    ListView {
        id: cards
        objectName: "appSwitcherCards"
        anchors.fill: parent
        anchors.bottomMargin: control.tabletMode ? 64 : 0
        // Keep the requested app stable while the sheet resizes underneath it.
        onWidthChanged: Qt.callLater(() => { if (control.selection && !moving) currentIndex = control.windows.indexOf(control.selection); })
        property bool browsing: false
        onDraggingChanged: if (dragging) browsing = true
        onMovementEnded: {
            if (browsing) control.selection = control.windows[currentIndex] || null;
            browsing = false;
        }
        orientation: ListView.Horizontal
        model: control.windows
        spacing: control.phoneMode ? -control.cardWidth * 0.76 : 10
        cacheBuffer: control.phoneMode ? control.cardWidth * 3 : 0
        contentWidth: count ? (count - 1) * (control.cardWidth + spacing) + control.cardWidth : 0
        clip: true
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - control.cardWidth) / 2
        preferredHighlightEnd: preferredHighlightBegin
        highlightMoveDuration: control.reducedMotion ? 0 : 180
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property var handle: modelData.wayland
            readonly property real position: (x - cards.contentX - cards.preferredHighlightBegin) / Math.max(1, width + cards.spacing)
            readonly property real distance: Math.abs(position)
            transform: Translate {
                x: control.phoneMode && card.position < 0
                    ? card.distance * (card.width + cards.spacing) - control.cardWidth * (card.distance <= 1 ? card.distance * 0.12 : 0.12 + (card.distance - 1) * 0.06)
                    : 0
            }
            z: control.phoneMode ? 100 - distance : 0
            // Dismissal state lives on the delegate so the fly-off animation
            // outlives the model entry it belongs to.
            property bool closing: false
            function activateCard() {
                if (!control.visible || closing || control.windows.indexOf(modelData) < 0) return;
                cards.currentIndex = index;
                control.selection = modelData;
                if (control.splitFirst && control.splitFirst !== modelData) {
                    control.splitRequested(control.splitFirst, modelData);
                    control.splitFirst = null;
                } else if (!control.splitFirst) control.activateCurrent();
            }
            function closeCard() {
                if (closing || !handle || control.windows.indexOf(modelData) < 0) return;
                singleClick.stop();
                closing = true;
                y = -height;
                control.closeRequested(handle);
            }
            Timer {
                id: singleClick
                interval: Application.styleHints.mouseDoubleClickInterval
                onTriggered: card.activateCard()
            }
            readonly property real sourceAspect: (preview.sourceSize.height > 0)
                ? preview.sourceSize.width / preview.sourceSize.height : control.aspect
            readonly property real cardHeight: control.phoneMode ? control.cardHeight : Math.min(cards.height,
                control.cardWidth / Math.max(0.2, sourceAspect))
            width: control.cardWidth
            height: cards.height
            scale: control.phoneMode ? 1 - Math.min(2, distance) * 0.035 : ListView.isCurrentItem ? 1 : 0.93
            opacity: closing ? 0 : control.phoneMode ? (distance > 2.5 ? 0 : 1 - Math.min(2, distance) * 0.12) : ListView.isCurrentItem ? 1 : 0.7
            transformOrigin: control.phoneMode ? Item.Left : Item.Center
            Behavior on scale { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
            Behavior on opacity { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
            Behavior on y {
                enabled: !dismissDrag.active
                NumberAnimation { duration: control.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic }
            }

            Connections {
                target: cards
                function onDraggingChanged() { if (cards.dragging) singleClick.stop(); }
            }
            onVisibleChanged: {
                singleClick.stop();
                if (visible) { closing = false; y = 0; }
            }
            Row {
                visible: control.phoneMode && card.x <= cards.contentX + cards.preferredHighlightBegin + card.width * 0.5
                anchors.left: screen.left
                anchors.bottom: screen.top
                anchors.bottomMargin: 10
                width: screen.width
                spacing: 8
                Image {
                    width: 28
                    height: 28
                    source: control.iconForWindow(card.modelData) || "../artwork/tessarchy-mark.svg"
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    objectName: "appSwitcherName" + card.index
                    visible: card.distance < 0.55
                    width: Math.max(0, screen.width - 36)
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.nameForWindow(card.modelData)
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            ClippingRectangle {
                id: screen
                width: control.cardWidth
                height: card.cardHeight
                anchors.verticalCenter: parent.verticalCenter
                x: control.phoneMode ? 0 : (card.width - width) / 2
                radius: control.phoneMode ? 36 : 24
                color: Theme.darkerBackground
                ScreencopyView {
                    id: preview
                    anchors.fill: parent
                    captureSource: control.visible && !card.closing ? card.handle : null
                    live: control.visible
                    paintCursor: false
                }
                // Unavailable previews fall back to the window title on the same
                // card, with no extra frame around it.
                Column {
                    visible: !preview.hasContent
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 12
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "../artwork/tessarchy-mark.svg"
                        width: 44
                        height: 44
                    }
                    Text {
                        width: parent.width
                        text: card.modelData.title || "Untitled window"
                        textFormat: Text.PlainText
                        color: Theme.text
                        wrapMode: Text.WrapAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                    }
                }
            }

            // Mouse exits: a small close target in the card's top-right corner.
            // Swipe-up still works for touch.
            Rectangle {
                id: closeButton
                width: 48
                height: 48
                radius: Theme.radius("card", 24, height)
                visible: !control.phoneMode
                z: 2
                anchors.top: screen.top
                anchors.right: screen.right
                anchors.topMargin: 8
                anchors.rightMargin: 8
                color: closeArea.pressed ? Qt.alpha(Theme.text, 0.90) : closeArea.containsMouse ? Qt.alpha(Theme.surface, 0.76) : Qt.alpha(Theme.background, 0.55)
                border.width: 1
                border.color: closeArea.containsMouse ? Theme.accent : Theme.muted
                Text {
                    anchors.centerIn: parent
                    text: "\u00d7"
                    color: closeArea.containsMouse ? Theme.darkerBackground : Theme.text
                    font.pixelSize: 16
                    font.bold: true
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.name: "Close " + (card.modelData.title || "window")
                    Accessible.role: Accessible.Button
                    onClicked: {
                        card.closeCard();
                    }
                }
            }

            MouseArea {
                anchors.fill: screen
                // Mouse activation waits for the double-click interval; touch taps activate immediately.
                onClicked: mouse => {
                    if (mouse.source === Qt.MouseEventNotSynthesized) singleClick.restart();
                    else card.activateCard();
                }
                onDoubleClicked: mouse => {
                    if (mouse.source === Qt.MouseEventNotSynthesized) card.closeCard();
                }
                Accessible.name: "Switch to " + (card.modelData.title || "Untitled window")
                Accessible.role: Accessible.Button
            }

            DragHandler {
                id: dismissDrag
                parent: screen
                target: null
                xAxis.enabled: false
                yAxis.maximum: 0
                dragThreshold: 8
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                // Distance travelled upward; read on release to decide.
                property real travel: 0
                onActiveChanged: {
                    if (active) {
                        singleClick.stop();
                        travel = 0;
                        return;
                    }
                    if (card.closing) return;
                    if (travel > 72) {
                        card.closeCard();
                    } else {
                        card.y = 0;
                    }
                }
                onActiveTranslationChanged: {
                    if (!active || card.closing) return;
                    travel = -activeTranslation.y;
                    card.y = Math.min(0, activeTranslation.y);
                }
            }
        }
        Text {
            visible: cards.count === 0
            anchors.centerIn: parent
            width: parent.width - 48
            text: control.emptyHint
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
    Row {
        visible: control.tabletMode && control.windows.length >= 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 12
        TouchButton {
            id: splitButton
            text: control.splitFirst ? "Cancel split" : "Split apps"
            implicitWidth: 56
            enabled: !!(control.windows[cards.currentIndex] && control.windows[cards.currentIndex].wayland)
            accentColor: control.accentColor
            contentItem: Icon {
                symbol: "split"
                color: splitButton.enabled ? Theme.text : Theme.muted
                anchors.centerIn: parent
            }
            onClicked: control.splitFirst = control.splitFirst ? null : control.windows[cards.currentIndex]
        }
        Text {
            visible: !!control.splitFirst
            width: Math.min(260, Math.max(80, control.width - 96))
            anchors.verticalCenter: parent.verticalCenter
            text: "Tap another app to split"
            elide: Text.ElideRight
            color: Theme.text
        }
    }
}
