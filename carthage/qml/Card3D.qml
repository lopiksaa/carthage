// The closer-look cartridge as a real 3D object: rounded slab with a front, a back and a
// lit plastic edge (card3d.py builds the mesh). The front and back are the same artwork as
// the 2D cards, rendered offscreen into textures.
import QtQuick
import QtQuick3D
import Carthage

View3D {
    id: view

    property var game: ({})
    // The face is drawn into a texture; with animations off nothing else asks the 3D view to
    // redraw, so a new game (or store) kept the old face. Redraw now, and again as late art and
    // header images arrive.
    onGameChanged: { redraw.n = 0; redraw.restart(); update() }
    Timer {
        id: redraw
        property int n: 0
        interval: 150
        onTriggered: { view.update(); if (++n < 4) restart() }
    }
    property real spin: 0 // degrees around the vertical axis; 180 shows the back
    property real tiltX: 0
    property real tiltY: 0
    property real cardHeight: 400 // on-screen height of the card at rest, in pixels

    // The game's own cartridge color (Cartridge Color…), else the usual one.
    readonly property string ownColor: view.game.gameId ? (Backend.settings.gameColors[view.game.gameId] || "") : ""
    readonly property var pal: ownColor ? Backend.theme.paletteFor(edition) : Backend.theme.cp
    readonly property string edition: ownColor ? Backend.theme.editionFor(ownColor) : Backend.theme.cardEdition
    // The faces are drawn at about twice their size on screen (at most 720 px): much bigger and a
    // small card's text and edges shimmer and stair-step when the texture is shrunk.
    readonly property real faceW: Math.max(240, Math.min(720, Math.round(cardHeight / Backend.theme.ratio * Screen.devicePixelRatio * 2)))
    // The back's engraved code: the same as the front's label (Cartridge.qml), in full.
    // (A store game's front shows its price: its back still has the code, given as backLabel.)
    readonly property string backLabel: (view.game.backLabel || view.game.label
        || [view.game.sourceName || "", view.game.extId || "", view.game.code || ""].filter(x => x).join(" - "))
        .replace(/[?&#]/g, "")
    readonly property real fov: 20
    // Camera distance that makes the 878-unit-tall card exactly cardHeight pixels tall.
    readonly property real distance: (439 / Math.tan(fov * Math.PI / 360)) * (height / cardHeight)

    environment: SceneEnvironment {
        backgroundMode: SceneEnvironment.Transparent
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.VeryHigh
    }
    camera: cam

    PerspectiveCamera {
        id: cam
        fieldOfView: view.fov
        z: view.distance
        clipNear: 10
        clipFar: view.distance * 3
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(-38, -32, 0)
        brightness: 0.95
    }
    // Fill: from slightly below-right of the viewer, so its reflection doesn't sit as a
    // hotspot in the middle of the face.
    DirectionalLight {
        eulerRotation: Qt.vector3d(14, 24, 0)
        brightness: 0.55
    }

    Node {
        eulerRotation: Qt.vector3d(view.tiltX, view.spin + view.tiltY, 0)

        Model {
            geometry: CardGeometry { thickness: 46 }
            materials: [
                PrincipledMaterial {
                    baseColorMap: Texture {
                        sourceItem: Cartridge {
                            width: view.faceW
                            flat: true
                            gameId: view.game.gameId || ""
                            title: view.game.title || ""
                            source: view.game.source || ""
                            sourceName: view.game.sourceName || ""
                            sourceIcon: view.game.sourceIcon || ""
                            code: view.game.code || ""
                            extId: view.game.extId || ""
                            installed: view.game.installed !== false
                            artKey: view.game.gameId ? view.game.gameId + (view.game.installed === false && !Backend.settings.colorUninstalled ? "/off" : "") : ""
                            artUrl: view.game.artUrl || ""
                            artFallback: view.game.artFallback || ""
                            labelOverride: view.game.label || ""
                            noSlot: view.game.noSlot === true
                        }
                    }
                    roughness: 0.5
                    specularAmount: 0.18
                    cullMode: Material.NoCulling
                },
                PrincipledMaterial {
                    baseColorMap: Texture {
                        sourceItem: Image {
                            width: view.faceW
                            height: view.faceW * Backend.theme.ratio
                            source: "image://gc/back/" + view.edition + "/flat/"
                                    + view.backLabel
                                    + Backend.theme.cardTexQuery
                            sourceSize: Qt.size(width, height)
                        }
                    }
                    roughness: 0.6
                    specularAmount: 0.15
                    cullMode: Material.NoCulling
                },
                PrincipledMaterial {
                    baseColor: Qt.darker(view.pal.shellBottom, Backend.theme.dark ? 1.05 : 1.12)
                    roughness: 0.5
                    specularAmount: 0.4
                    cullMode: Material.NoCulling
                }
            ]
        }
    }
}
