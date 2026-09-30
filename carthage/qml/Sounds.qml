// Every sound has a visual twin; nothing plays while the window is hidden or sounds are off.
import QtQuick
import Carthage
import QtMultimedia

Item {
    id: sounds

    component Fx: SoundEffect {
        property string name
        property real level: 1
        source: Backend.soundUrl(name)
        volume: Backend.settings.soundVolume * level
    }
    Fx { id: clickIn; name: "click_in" }
    Fx { id: halfClick; name: "half_click" }
    Fx { id: release; name: "release" }
    Fx { id: hover; name: "hover"; level: 0.8 }
    Fx { id: pick; name: "pick" }
    Fx { id: place; name: "place" }
    Fx { id: key; name: "key" }
    Fx { id: roll; name: "roll" }

    // Sweeping the pointer across a row would otherwise fire a tick per card.
    property double lastHover: 0
    readonly property int hoverGap: 90

    function play(name) {
        if (!Backend.settings.soundsEnabled) return
        const w = Window.window
        if (!w || w.visibility === Window.Minimized || w.visibility === Window.Hidden) return
        if (name === "hover") {
            const now = Date.now()
            if (now - lastHover < hoverGap) return
            lastHover = now
        }
        const fx = { "click_in": clickIn, "half_click": halfClick, "release": release, "hover": hover,
                     "pick": pick, "place": place, "key": key, "roll": roll }[name]
        if (fx) fx.play()
    }
}
