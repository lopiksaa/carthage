"""Minimal reader for Valve's text KeyValues format (.vdf / .acf).

    "key"  "value"
    "key"  { ...nested... }

Keys are case-insensitive in practice (Steam writes both "apps" and "Apps"), so every
key is lower-cased. Comments (//) and #include/#base directives are skipped.
"""

import re

_TOKEN = re.compile(r'"((?:[^"\\]|\\.)*)"|([{}])|(//[^\n]*)|([^\s{}"]+)')


def loads(text):
    stack = [{}]
    key = None
    for m in _TOKEN.finditer(text):
        quoted, brace, comment, bare = m.groups()
        if comment is not None:
            continue
        if brace == "{":
            child = {}
            if key is not None:
                stack[-1][key.lower()] = child
            stack.append(child)
            key = None
        elif brace == "}":
            if len(stack) > 1:
                stack.pop()
            key = None
        else:
            token = quoted if quoted is not None else bare
            if token.startswith("#"):  # #include / #base
                continue
            if key is None:
                key = token
            else:
                stack[-1][key.lower()] = token.replace('\\"', '"').replace("\\\\", "\\")
                key = None
    return stack[0]


def load(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return loads(f.read())
