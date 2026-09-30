// The design scale: text sizes, radii and gaps. Hardware geometry is in theme.py.

pragma Singleton
import QtQuick
import Carthage

QtObject {
    // Open menus (CMenu counts them); input behind is blocked while any is open.
    property int openMenus: 0

    // Interface fonts, one per kind of text, chosen in Settings → Appearance (all bundled).
    // The codes and labels printed on cartridges keep their own fonts.
    readonly property var labelFonts: ["Nunito", "Chakra Petch", "Michroma", "Bai Jamjuree", "Sora",
        "Red Hat Display", "Instrument Sans", "Orbitron", "Audiowide", "Jura", "Righteous"]
    readonly property var calmFonts: ["Manrope", "Figtree", "Onest", "Plus Jakarta Sans", "Lexend",
        "Hanken Grotesk", "Albert Sans", "Urbanist"]
    readonly property var titleFonts: labelFonts.concat(calmFonts)
    readonly property var buttonFonts: titleFonts
    // Only fonts that stay easy to read at small sizes.
    readonly property var textFonts: ["Nunito", "Sora", "Red Hat Display", "Instrument Sans",
        "Bai Jamjuree", "Chakra Petch"].concat(calmFonts)

    function _pick(choices, saved, fallback) { return choices.indexOf(saved) >= 0 ? saved : fallback }
    readonly property string fontLabels: _pick(labelFonts, Backend.settings.fontLabels, "Orbitron")     // logo, LIBRARY / STORE, engraved titles
    readonly property string fontTitles: _pick(titleFonts, Backend.settings.fontTitles, "Red Hat Display") // game names
    readonly property string fontButtons: _pick(buttonFonts, Backend.settings.fontButtons, "Chakra Petch")
    readonly property string fontText: _pick(textFonts, Backend.settings.fontText, "Red Hat Display")     // everything else

    readonly property int textCaption: 12   // hints, counts, small labels
    readonly property int textBody: 14      // body text, buttons, menu items
    readonly property int textLead: 16      // emphasized body, prices in lists
    readonly property int textTitle: 20     // dialog and section titles
    readonly property int textDisplay: 34   // the big game title in the closer look / store page

    readonly property int radiusTiny: 4     // checkboxes (a round box would read as a radio button)
    readonly property int radiusSmall: 8    // thumbnails, menu items, chips inside panels
    readonly property int radiusMedium: 12  // buttons, fields, menus
    readonly property int radiusLarge: 18   // dialogs, panels, banners

    readonly property int gapXS: 4
    readonly property int gapS: 8
    readonly property int gapM: 12
    readonly property int gapL: 16
    readonly property int gapXL: 24
    readonly property int gapXXL: 32

    // Wide enough for Play's secondary buttons to sit on one row.
    readonly property int detailsWidth: 460

    readonly property int spacingSmall: 4
    readonly property int spacingLarge: 8
    readonly property int gridUnit: 18
    readonly property color focusColor: "#3daee9"

    readonly property int controlHeight: 36
    readonly property int controlHeightLarge: 48

    readonly property color onScrim: "#ffffff"
    readonly property color onScrimDim: Qt.rgba(1, 1, 1, 0.78)
    readonly property color onScrimFaint: Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrimControl: Qt.rgba(1, 1, 1, 0.14)
    readonly property color scrimControlHover: Qt.rgba(1, 1, 1, 0.24)

    // Each company links to its games on Steam. Names can be a comma-separated list.
    function escapeHtml(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    // "A, B, Ltd." → ["A", "B, Ltd."]: lists are joined with commas, and a comma before a
    // legal suffix belongs to the name.
    function splitCompanies(names) {
        const out = []
        for (const part of String(names || "").split(",").map(n => n.trim()).filter(n => n)) {
            if (out.length && /^(ltd|inc|llc|llp|co|corp|gmbh|s\.?a|s\.?l|pty|limited|ab|oy|srl|s\.?r\.?l|kk|plc|lp)\.?$/i.test(part))
                out[out.length - 1] += ", " + part
            else out.push(part)
        }
        return out
    }
    function companyLinks(names, kind) {
        return splitCompanies(names)
            .map(n => "<a href=\"https://store.steampowered.com/search/?" + kind + "=" + encodeURIComponent(n) + "\">"
                      + escapeHtml(n) + "</a>").join(", ")
    }
    function creditsLine(developer, publisher, year) {
        // A publisher that's also one of the developers isn't repeated (Celeste: "Maddy Makes
        // Games Inc., Extremely OK Games · Maddy Makes Games Inc.").
        const devs = splitCompanies(developer).map(s => s.toLowerCase())
        const pubs = splitCompanies(publisher).filter(s => !devs.includes(s.toLowerCase()))
        return [companyLinks(developer, "developer"),
                pubs.length ? pubs.map(n => companyLinks(n, "publisher")).join(", ") : "",
                year ? escapeHtml(year) : ""].filter(x => x).join("&nbsp;&nbsp;·&nbsp;&nbsp;")
    }
}
