// A small accent dot that says an update is waiting (on the ≡ and on Settings).
import QtQuick
import Carthage

Rectangle {
    readonly property bool waiting: !!Backend.updater && Backend.updater.available
    visible: waiting
    width: 9
    height: 9
    radius: 4.5
    color: Backend.theme.accent.accent
    border.width: 1.5
    border.color: Backend.theme.p.dockTop
    Accessible.ignored: true
}
