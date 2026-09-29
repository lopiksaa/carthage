"""What's new in each version: shown once after an update (the "What's new" window), and the
source of the GitHub release notes, so both say the same. The release workflow prints a
version's notes with:  python -m carthage.whatsnew 0.3.1

Each change is one step in the window: a title, one or two plain sentences, and a picture (a
name from assets/icons/ui). Fixes only go in the GitHub notes, not the window. Only what a
user needs to know. Newest version first.
"""

NOTES = {
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
    return {"version": version,
            "slides": [dict(i) for i in items if i["kind"] != "fixed"],
            "fixed": [i["text"] for i in items if i["kind"] == "fixed"]}


def markdown(version):
    """The release notes for GitHub: the same changes, as a list per kind."""
    items = NOTES.get(version) or []
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
