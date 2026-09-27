"""What's new in each version: shown once after an update (the "What's new" window), and the
source of the GitHub release notes (tools/release_notes.py prints them), so both say the same.

Each change is one step in the window: a title, one or two plain sentences, and a picture (a
name from assets/icons/ui). Fixes only go in the GitHub notes, not the window. Only what a
user needs to know. Newest version first.
"""

NOTES = {
    "0.3.1": [
        {"kind": "changed", "icon": "lock", "title": "Keys are optional",
         "text": "Carthage works without any keys. Add them whenever you like, in Menu → Accounts & Keys, for cartridge art and your whole Steam library."},
        {"kind": "new", "icon": "code-context", "title": "Carthage is open source",
         "text": "Its code is on GitHub under the GPL, free to read, change and share. The link is in Menu → System."},
        {"kind": "new", "icon": "internet-services", "title": "Discord Rich Presence",
         "text": "Discord can show Choosing a Game or Browsing Store. Turn it on in Menu → System. Nothing about your games is shared."},
        {"kind": "new", "icon": "help-about", "title": "What's new, like this",
         "text": "After each update, Carthage shows what changed. Once, then it stays out of your way."},
        {"kind": "changed", "icon": "carthage", "title": "The cartridge icon is back",
         "text": "Carthage's icon is the cartridge again, in your menu and taskbar."},
        {"kind": "fixed", "text": "Store pages no longer repeat a company that's both developer and publisher."},
    ],
    "0.3.0": [
        {"kind": "new", "icon": "download", "title": "Carthage updates itself",
         "text": "New versions download in the background and install when Carthage restarts."},
        {"kind": "new", "icon": "internet-services", "title": "Steam and Epic, one store",
         "text": "Search covers both stores. When a game is on both, roll the mouse wheel over its cartridge to switch between them."},
        {"kind": "new", "icon": "starred", "title": "Free for a Limited Time",
         "text": "Steam and Epic giveaways get their own shelf, with the date they end."},
        {"kind": "new", "icon": "link", "title": "Prices from other stores",
         "text": "GOG, Microsoft Store, EA and Battle.net, if you want them: Menu → Store → Other stores (needs an IsThereAnyDeal key)."},
        {"kind": "new", "icon": "view-grid", "title": "Show and sort by launcher",
         "text": "See only one launcher's games, or group the tray by launcher."},
        {"kind": "fixed", "text": "A game's art could stay on the cartridge after opening another game in the store."},
    ],
}

KINDS = [("new", "New"), ("changed", "Changed"), ("fixed", "Fixed")]


def notes_for(version):
    """{"version", "slides": [{kind, icon, title, text}], "fixed": [text]} for one version."""
    items = NOTES.get(version)
    if not items:
        return None
    return {"version": version,
            "slides": [dict(i) for i in items if i["kind"] != "fixed"],
            "fixed": [i["text"] for i in items if i["kind"] == "fixed"]}


def markdown(version):
    """The release notes for GitHub: the same changes, as a list per kind."""
    items = NOTES.get(version) or []
    out = []
    for kind, heading in KINDS:
        lines = [i for i in items if i["kind"] == kind]
        if lines:
            out.append(f"## {heading}")
            out += [f"- **{i['title']}.** {i['text']}" if i.get("title") else f"- {i['text']}" for i in lines]
            out.append("")
    return "\n".join(out).strip() + "\n"
