"""A real 3D cartridge for the closer look: an extruded rounded rectangle.

Three subsets, so each gets its own material:
  0  front face  (z = +thickness/2), UVs map the front texture
  1  back face   (z = -thickness/2), UVs mirrored so the back reads correctly from behind
  2  side wall   smooth outward normals, so light rolls around the rounded corners

Units match the 600-wide reference canvas in theme.py.
"""

import math
import struct

from PySide6.QtCore import Property, Signal
from PySide6.QtGui import QVector3D
from PySide6.QtQml import QmlElement
from PySide6.QtQuick3D import QQuick3DGeometry

from .theme import GEOMETRY, REF_H, REF_W

QML_IMPORT_NAME = "Carthage"
QML_IMPORT_MAJOR_VERSION = 1

_STRIDE = 8 * 4  # position(3) normal(3) uv(2), float32


@QmlElement
class CardGeometry(QQuick3DGeometry):
    thicknessChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._thickness = 44.0
        self._build()

    def _get_thickness(self):
        return self._thickness

    def _set_thickness(self, value):
        if value != self._thickness:
            self._thickness = value
            self._build()
            self.thicknessChanged.emit()

    thickness = Property(float, _get_thickness, _set_thickness, notify=thicknessChanged)

    def _outline(self, segments=10):
        w, h, r = REF_W, REF_H, float(GEOMETRY["radius"])
        corners = [  # center, start angle — counter-clockwise around the card
            (w / 2 - r, h / 2 - r, 0),
            (-w / 2 + r, h / 2 - r, 90),
            (-w / 2 + r, -h / 2 + r, 180),
            (w / 2 - r, -h / 2 + r, 270),
        ]
        pts = []
        for k, (cx, cy, a0) in enumerate(corners):
            for i in range(segments + 1):
                a = math.radians(a0 + 90 * i / segments)
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a), math.cos(a), math.sin(a)))
            if k == 1:  # down the left edge
                pts += self._notch(-1)
        return pts + self._notch(1)  # up the right edge, back to the start

    @staticmethod
    def _notch(side):
        """The latch notch in one side edge (theme GEOMETRY["notch"], canvas y downward), as
        outline points. Each corner comes twice, with the normals of the walls on either
        side, so the angled walls shade flat and crisp."""
        w, h = REF_W, REF_H
        y, nh, d = GEOMETRY["notch"]
        top, bottom = h / 2 - y, h / 2 - (y + nh)
        x0, x1 = side * w / 2, side * (w / 2 - d)
        s = math.sqrt(0.5)
        # Corners top to bottom, and the outward normal of the wall below each one.
        walls = [
            ((x0, top), (side, 0.0)),
            ((x1, top - d), (side * s, -s)),
            ((x1, bottom + d), (float(side), 0.0)),
            ((x0, bottom), (side * s, s)),
        ]
        normals = [(float(side), 0.0), (side * s, -s), (float(side), 0.0), (side * s, s), (float(side), 0.0)]
        pts = []
        for i, ((x, yy), _) in enumerate(walls):
            pts.append((x, yy, *normals[i]))      # end of the wall above
            pts.append((x, yy, *normals[i + 1]))  # start of the wall below
        # The outline runs down the left edge but up the right one.
        return pts if side < 0 else pts[::-1]

    def _build(self):
        w, h = REF_W, REF_H
        z = self._thickness / 2
        pts = self._outline()
        n = len(pts)
        verts = []
        idx = []

        def vert(x, y, zz, nx, ny, nz, u, v):
            verts.append((x, y, zz, nx, ny, nz, u, v))
            return len(verts) - 1

        def uv(x, y, mirror=False):
            u = (x + w / 2) / w
            return (1 - u if mirror else u), (y + h / 2) / h

        # Front cap: a fan from the center.
        c = vert(0, 0, z, 0, 0, 1, *uv(0, 0))
        ring = [vert(x, y, z, 0, 0, 1, *uv(x, y)) for x, y, _, _ in pts]
        front_start = len(idx)
        for i in range(n):
            idx += [c, ring[i], ring[(i + 1) % n]]
        front_count = len(idx) - front_start

        # Back cap: reversed winding, mirrored texture.
        c = vert(0, 0, -z, 0, 0, -1, *uv(0, 0, True))
        ring = [vert(x, y, -z, 0, 0, -1, *uv(x, y, True)) for x, y, _, _ in pts]
        back_start = len(idx)
        for i in range(n):
            idx += [c, ring[(i + 1) % n], ring[i]]
        back_count = len(idx) - back_start

        # Side wall with smooth outward normals.
        side_start = len(idx)
        top = [vert(x, y, z, nx, ny, 0, 0, 0) for x, y, nx, ny in pts]
        bot = [vert(x, y, -z, nx, ny, 0, 0, 1) for x, y, nx, ny in pts]
        for i in range(n):
            j = (i + 1) % n
            idx += [top[i], bot[i], bot[j], top[i], bot[j], top[j]]
        side_count = len(idx) - side_start

        vdata = b"".join(struct.pack("<8f", *v) for v in verts)
        idata = struct.pack(f"<{len(idx)}I", *idx)

        self.clear()
        self.setStride(_STRIDE)
        self.setVertexData(vdata)
        self.setIndexData(idata)
        self.setPrimitiveType(QQuick3DGeometry.PrimitiveType.Triangles)
        self.addAttribute(QQuick3DGeometry.Attribute.PositionSemantic, 0, QQuick3DGeometry.Attribute.F32Type)
        self.addAttribute(QQuick3DGeometry.Attribute.NormalSemantic, 12, QQuick3DGeometry.Attribute.F32Type)
        self.addAttribute(QQuick3DGeometry.Attribute.TexCoord0Semantic, 24, QQuick3DGeometry.Attribute.F32Type)
        self.addAttribute(QQuick3DGeometry.Attribute.IndexSemantic, 0, QQuick3DGeometry.Attribute.U32Type)
        lo, hi = QVector3D(-w / 2, -h / 2, -z), QVector3D(w / 2, h / 2, z)
        self.setBounds(lo, hi)
        self.addSubset(front_start, front_count, lo, hi, "front")
        self.addSubset(back_start, back_count, lo, hi, "back")
        self.addSubset(side_start, side_count, lo, hi, "side")
        self.update()
