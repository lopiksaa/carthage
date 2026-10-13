"""What's new in each version: shown once after an update (the "What's new" window), and the
source of the GitHub release notes, so both say the same. The release workflow prints a
version's notes with:  python -m carthage.whatsnew 0.3.1

Each change is one step in the window: a title, one or two plain sentences, and a picture (a
name from assets/icons/ui). Fixes only go in the GitHub notes, not the window. Only what a
user needs to know. Newest version first.
"""

NOTES = {
    # A version's notes can also be Markdown as written: "## Section" headings with "- " items
    # (the GitHub release as is; the window shows one step per section).
    "0.4.1": """## Look
- Glass is the new default look, with frosted panels, menus, sidebar and dock. Plastic is still available in Appearance.
- Animated backgrounds: Holographic, Mesh, Underwater, Contours and Still.
- Colour presets, a blur slider, and an Advanced section to tune every colour.
- Dark and Light modes no longer change with the colour you pick.

## Library
- A sidebar. Yep. A sidebar.
- Custom lists: create your own and add any game with “Add to List…”.
- Back to top on every page, and middle-click autoscroll.
- Option to show uninstalled games in colour.
- Steam Family library support.

## Dock
- The dock floats.

## Game pages
- A backdrop with the game’s official art, can also just be a blur on what's behind (Appearance → Game View).

## Store & search
- Store sections open to show all their games.
- A Wishlist page with the best price across Steam and Epic.
- Improved search.

## Fixes
- Carthage no longer opens multiple windows at launch.
- Fixed play time for non-Steam games.

## Other
- Copy Diagnostics in Settings → System.
- Misc bugs and performance fixes.
""",
    "0.4.0-beta.1": [
        {"kind": "fixed", "text": "Pre-release of a big redesign, so expect rough edges. It doesn't reach anyone automatically: download it from this page to try it."},
        {"kind": "fixed", "text": "A new look: glass panels, a sidebar, a new dock, and a live preview in Settings → Appearance."},
        {"kind": "fixed", "text": "Your own lists, a Steam wishlist page with the best price across Steam and Epic, and Steam Family games."},
        {"kind": "fixed", "text": "A first-run tour, Copy Diagnostics for bug reports, and only one Carthage open at a time."},
        {"kind": "fixed", "text": "Windows: games with their own launcher, and Steam games started by a publisher's launcher, are tracked properly."},
    ],
    "0.3.8": [
        {"kind": "new", "icon": "bookmark", "title": "Play Next",
         "text": "Bookmark games to play soon from their page, store games too: they wait greyed out with a shopping bag and their price. Play Next sits above the library."},
        {"kind": "new", "icon": "tag", "title": "Genres and filters",
         "text": "Filter the library by genre (from Steam's tags, for other launchers' games too) and the store by store and genre."},
        {"kind": "new", "icon": "color-picker", "title": "A color for one game",
         "text": "Right-click a cartridge › Cartridge Color… gives that game its own color."},
        {"kind": "new", "icon": "starred", "title": "Achievements and folding shelves",
         "text": "Steam games show your achievements on their page (with a Steam key). Favorites wrap into rows, and Favorites and Play Next fold shut from their title."},
    ],
    "0.3.7": [
        {"kind": "new", "icon": "color-picker", "title": "Fonts, colors and textures",
         "text": "Settings → Appearance has font choices, eight new hardware colors, five plastic textures and a new color picker."},
        {"kind": "new", "icon": "view-grid", "title": "Store layout",
         "text": "Store shelves can show games in one row that scrolls sideways or everything vertically (Settings → Store). Pushed On Sale on top; categories are at the bottom."},
        {"kind": "new", "icon": "dialog-messages", "title": "Send Feedback",
         "text": "Settings → System → Send Feedback opens a short feedback form."},
    ],
    "0.3.6": [
        {"kind": "fixed", "text": "Hardware colors show in Settings → Look & Feel again, if you had tried the Hi-Fi look."},
    ],
    "0.3.5": [
        {"kind": "fixed", "text": "Carthage does much less work in the background, especially on Windows."},
        {"kind": "fixed", "text": "Simpler setup: only the optional Steam key is asked for."},
        {"kind": "fixed", "text": "Removed python-gobject from the requirements (only needed if you run Carthage from source)."},
        {"kind": "fixed", "text": "The Linux download now carries its own certificate list, so connections work on more distros."},
    ],
    "0.3.4": [
        {"kind": "fixed", "text": "Fixed API keys, the store, updates and starting games on some Linux systems."},
    ],
    "0.3.3": [
        {"kind": "fixed", "text": "Fixed Carthage not starting on some Linux systems."},
    ],
    "0.3.2": [
        {"kind": "fixed", "text": "Polished What's new and the setup wizard."},
    ],
    "0.3.1": [
        {"kind": "new", "icon": "internet-services", "title": "Steam and Epic stores",
         "text": "Browse both in the same style as your library, with a shelf of free games. Buying happens in each store."},
        {"kind": "new", "icon": "dice", "title": "Roll the dice",
         "text": "Can't decide what to play? The dice in the library bar picks a game for you."},
        {"kind": "new", "icon": "download", "title": "Updates itself",
         "text": "New versions download in the background and install when Carthage restarts."},
    ],
}

KINDS = [("new", "New"), ("changed", "Changed"), ("fixed", "Fixed")]


def notes_for(version):
    """{"version", "slides": [{kind, icon, title, text}], "fixed": [text]} for one version."""
    items = NOTES.get(version)
    if not items:
        return None
    if isinstance(items, str):  # Markdown: one step per section, its items as lines
        slides = []
        for part in items.split("## ")[1:]:
            title, _, body = part.partition("\n")
            lines = [ln[2:].strip() for ln in body.splitlines() if ln.startswith("- ")]
            slides.append({"kind": "new", "icon": "starred", "title": title.strip(),
                           "text": "\n".join("• " + ln for ln in lines)})
        return {"version": version, "slides": slides, "fixed": []}
    return {"version": version,
            "slides": [dict(i) for i in items if i["kind"] != "fixed"],
            "fixed": [i["text"] for i in items if i["kind"] == "fixed"]}


def markdown(version):
    """The release notes for GitHub: the same changes, as a list per kind."""
    items = NOTES.get(version) or []
    if isinstance(items, str):
        return items.strip() + "\n"
    out = []
    several = len({i["kind"] for i in items}) > 1
    for kind, heading in KINDS:
        lines = [i for i in items if i["kind"] == kind]
        if lines:
            if several:
                out.append(f"## {heading}")
            out += [f"- **{i['title']}.** {i['text']}" if i.get("title") else f"- {i['text']}" for i in lines]
            out.append("")
    return "\n".join(out).strip() + "\n"


if __name__ == "__main__":
    import sys

    print(markdown(sys.argv[1]), end="")
