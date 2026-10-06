// A live miniature of the library for Settings → Appearance: the ground, the header, the
// library bar's keys, three of your own cartridges in their wells and the dock — built from the
// same parts and theme values as the app, so every colour or Look change shows here at once.
//   LookPreview { width: parent.width }
import QtQuick
import Carthage

Item {
    id: preview

    readonly property bool glassy: Backend.theme.glassy
    readonly property var g: Backend.theme.glass
    readonly property var pal: Backend.theme.p
    // Drawn at the app's design width, then scaled to fit.
    readonly property real designW: 1180
    readonly property real designH: 470
    readonly property real k: width / designW
    height: Math.round(designH * k)

    Accessible.role: Accessible.Graphic
    Accessible.name: "Preview of the library with these colors"

    function role(row, r) {
        const m = Backend.games
        return row < m.rowCount() ? m.data(m.index(row, 0), Qt.UserRole + r) : undefined
    }

    Rectangle {  // the frame (rounded like a window)
        anchors.fill: parent
        radius: Ui.radiusMedium
        color: "transparent"
        border.width: 1
        border.color: preview.pal.panelBorder
        z: 10
    }
    Item {
        anchors.fill: parent
        anchors.margins: 1
        clip: true
        Item {
            id: stage
            width: preview.designW
            height: preview.designH
            scale: preview.k
            transformOrigin: Item.TopLeft

            // The ground.
            Backdrop { anchors.fill: parent; visible: preview.glassy }
            Rectangle { anchors.fill: parent; visible: !preview.glassy; color: preview.pal.tray }
            Image {
                anchors.fill: parent
                visible: !preview.glassy
                source: visible ? "image://gc/grain/" + Backend.theme.edition + Backend.theme.texQuery : ""
                fillMode: Image.Tile
                opacity: 0.2
                smooth: false
            }

            // The header.
            Item {
                width: parent.width
                height: 58
                GlassSurface { anchors.fill: parent; visible: preview.glassy; radius: 0; sheen: "transparent"; edges: false; shadowY: 12; shadowBlur: 30; shadowSpread: -14 }
                Rectangle { visible: preview.glassy; width: parent.width; height: 1; color: preview.g.edge }
                Plastic { anchors.fill: parent; visible: !preview.glassy }
                Text {
                    x: 32
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CARTHAGE"
                    color: preview.pal.dockText
                    font.family: Ui.fontLabels
                    font.weight: Font.Black
                    font.pixelSize: 18
                    font.letterSpacing: 4
                }
                Rectangle {  // the search field
                    anchors.centerIn: parent
                    width: 360
                    height: 36
                    radius: 18
                    color: preview.glassy ? preview.g.field : Qt.darker(preview.pal.dockBottom, Backend.theme.dark ? 1.35 : 1.06)
                    border.width: 1
                    border.color: preview.glassy ? preview.g.ring : Qt.rgba(0, 0, 0, 0.3)
                    Text {
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search your games and the stores"
                        color: preview.pal.dockTextDim
                        font.family: Ui.fontText
                        font.pixelSize: Ui.textBody
                    }
                }
            }

            // The library bar.
            Text {
                x: 50
                y: 76
                text: "ALL GAMES"
                color: preview.glassy ? preview.g.title : preview.pal.trayTextDim
                font.family: Ui.fontLabels
                font.weight: Font.Black
                font.pixelSize: Ui.textLead
                font.letterSpacing: 2
            }
            Row {
                x: preview.designW - 50 - width
                y: 66
                spacing: 8
                Repeater {
                    model: [["Show  All", 92], ["Sort  Recently Played", 180], ["", 36], ["+", 36]]
                    Item {
                        required property var modelData
                        width: modelData[1]
                        height: 36
                        GlassSurface { anchors.fill: parent; visible: preview.glassy; radius: Ui.radiusMedium }
                        Rectangle {
                            visible: !preview.glassy
                            anchors.fill: parent
                            anchors.bottomMargin: 4
                            radius: Ui.radiusMedium
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: preview.pal.dockTop }
                                GradientStop { position: 1.0; color: preview.pal.dockBottom }
                            }
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, Backend.theme.dark ? 0.5 : 0.2)
                        }
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: preview.glassy ? 0 : -2
                            text: modelData[0]
                            color: preview.pal.dockText
                            font.family: Ui.fontButtons
                            font.weight: Font.Bold
                            font.pixelSize: modelData[0] === "+" ? 22 : Ui.textBody
                        }
                    }
                }
            }

            // Three of your cartridges, in their wells.
            Row {
                x: 50
                y: 135
                spacing: 70
                Repeater {
                    model: 3
                    Item {
                        required property int index
                        readonly property real cardW: 187
                        readonly property real pad: cardW * 0.035
                        width: cardW + 2 * pad
                        height: cardW * Backend.theme.ratio + 2 * pad
                        Image {
                            visible: !preview.glassy
                            anchors.fill: parent
                            source: visible ? "image://gc/recess/" + Backend.theme.edition : ""
                            sourceSize: Qt.size(width, height)
                        }
                        Image {
                            readonly property real m: 0.22 * parent.width
                            visible: preview.glassy
                            x: -m
                            y: -m
                            width: parent.width + 2 * m
                            height: parent.height + 2 * m
                            source: visible ? "image://gc/glasswell/" + Backend.theme.edition : ""
                            sourceSize: Qt.size(width, height)
                        }
                        Cartridge {
                            x: parent.pad
                            y: parent.pad
                            width: parent.cardW
                            gameId: preview.role(index, 1) || ""
                            title: preview.role(index, 2) || "Your Game"
                            source: preview.role(index, 3) || "steam"
                            sourceName: preview.role(index, 4) || "Steam"
                            sourceIcon: preview.role(index, 5) || ""
                            code: preview.role(index, 6) || ""
                            extId: preview.role(index, 7) || ""
                            installed: preview.role(index, 8) !== false
                        }
                    }
                }
            }

            // The dock (at rest).
            Item {
                x: (preview.designW - 396) / 2
                y: preview.designH - 18 - 64
                width: 396
                height: 64
                GlassSurface { anchors.fill: parent; visible: preview.glassy; radius: 22; tint: preview.g.tint; shadow: false }
                Plastic { anchors.fill: parent; visible: !preview.glassy; radius: 22 }
                Text {
                    x: 48
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ready"
                    color: preview.glassy ? preview.g.text : preview.pal.dockText
                    font.family: Ui.fontText
                    font.weight: Font.Medium
                    font.pixelSize: 14
                }
                Rectangle {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: "transparent"
                    border.width: 1.6
                    border.color: preview.glassy ? preview.g.text2 : preview.pal.dockTextDim
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 66
                    height: 34
                    radius: 9
                    color: preview.glassy ? preview.g.readout : "#151619"
                    Text {
                        anchors.centerIn: parent
                        text: "15:34"
                        color: preview.glassy && !Backend.theme.dark ? preview.g.text : "#F4F5F7"
                        font.family: Ui.fontText
                        font.weight: Font.DemiBold
                        font.pixelSize: 15
                    }
                }
            }
        }
    }
}
