import QtQuick
import Carthage
import QtQuick.Controls as QQC2

QQC2.MenuSeparator {
    topPadding: 5
    bottomPadding: 5
    contentItem: Rectangle {
        implicitHeight: 1
        color: Backend.theme.p.panelBorder
    }
}
