"""Reader for Steam's binary app database, appcache/appinfo.vdf (format v28 and v29).

Gives the name and type (Game / Tool / Application / DLC …) of every app the Steam
client has metadata for — which lets Carthage filter out Proton & runtimes precisely
and list games that aren't installed, without any API key.

Layout (v29, magic 0x07564429):
    header: magic u32, universe u32, string_table_offset i64
    repeated: appid u32 (0 ends), size u32, info_state u32, last_updated u32,
              access_token u64, sha1[20], change_number u32, binary_sha1[20],
              then a binary KeyValues blob whose keys are u32 indices into the
              string table (v28: keys are null-terminated strings instead)
    string table: count u32, then count null-terminated UTF-8 strings
"""

import struct

MAGIC_V28 = 0x07564428
MAGIC_V29 = 0x07564429


def _read_cstr(buf, pos):
    end = buf.index(b"\0", pos)
    return buf[pos:end].decode("utf-8", "replace"), end + 1


def _parse_kv(buf, pos, strings):
    """Parse a binary KeyValues map starting at pos. Returns (dict, new_pos)."""
    out = {}
    while True:
        t = buf[pos]
        pos += 1
        if t == 0x08:  # end of map
            return out, pos
        if strings is not None:
            (ki,) = struct.unpack_from("<I", buf, pos)
            pos += 4
            key = strings[ki]
        else:
            key, pos = _read_cstr(buf, pos)
        if t == 0x00:
            val, pos = _parse_kv(buf, pos, strings)
        elif t == 0x01:
            val, pos = _read_cstr(buf, pos)
        elif t in (0x02, 0x04, 0x06):  # int32, color, pointer
            (val,) = struct.unpack_from("<i", buf, pos)
            pos += 4
        elif t == 0x03:  # float32
            (val,) = struct.unpack_from("<f", buf, pos)
            pos += 4
        elif t in (0x07, 0x0A):  # uint64, int64
            (val,) = struct.unpack_from("<Q", buf, pos)
            pos += 8
        elif t == 0x05:  # wide string (rare)
            end = pos
            while buf[end : end + 2] != b"\0\0":
                end += 2
            val = buf[pos:end].decode("utf-16-le", "replace")
            pos = end + 2
        else:
            raise ValueError(f"unknown KV type {t:#x} at {pos - 1}")
        out[key] = val


def read_appinfo(path):
    """{appid: {"name": str, "type": str}} for every app in appinfo.vdf."""
    buf = open(path, "rb").read()
    magic, _universe = struct.unpack_from("<II", buf, 0)
    if magic == MAGIC_V29:
        (table_off,) = struct.unpack_from("<q", buf, 8)
        (count,) = struct.unpack_from("<I", buf, table_off)
        strings, p = [], table_off + 4
        for _ in range(count):
            s, p = _read_cstr(buf, p)
            strings.append(s)
        pos = 16
    elif magic == MAGIC_V28:
        strings, pos = None, 8
    else:
        raise ValueError(f"unsupported appinfo.vdf format {magic:#x}")

    apps = {}
    while pos + 8 <= len(buf):
        appid, size = struct.unpack_from("<II", buf, pos)
        if appid == 0:
            break
        data_start = pos + 8 + 60
        next_pos = pos + 8 + size
        try:
            kv, _ = _parse_kv(buf, data_start, strings)
            common = kv.get("appinfo", {}).get("common", {})
            if common:
                assoc = common.get("associations") or {}
                people = {"developer": [], "publisher": []}
                if isinstance(assoc, dict):
                    for a in assoc.values():
                        if isinstance(a, dict) and a.get("type") in people and a.get("name"):
                            # All-digit names are stored as ints (publisher "3909": Papers, Please).
                            people[a["type"]].append(str(a["name"]))
                apps[appid] = {
                    "name": str(common.get("name", "")),
                    "type": str(common.get("type", "")).lower(),
                    "developer": ", ".join(people["developer"]),
                    "publisher": ", ".join(people["publisher"]),
                    "released": int(common.get("steam_release_date") or common.get("original_release_date") or 0),
                }
        except (ValueError, IndexError, TypeError, AttributeError, struct.error):
            pass  # one bad entry shouldn't hide the rest
        pos = next_pos
    return apps
