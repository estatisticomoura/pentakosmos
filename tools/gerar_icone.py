#!/usr/bin/env python3
"""Gera o icone do jogo: dodecaedro negro com arestas douradas.

Saidas (em assets/icon/):
  icon.png (1024), icon_192.png, foreground_432.png, background_432.png,
  monochrome_432.png e icon.ico. Uso: python3 tools/gerar_icone.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
SS = 4  # superamostragem


def dodecahedron():
    p = (1 + 5 ** 0.5) / 2
    v = []
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (-1, 1):
                v.append((x, y, z))
    for a in (-1, 1):
        for b in (-1, 1):
            v += [(0, a / p, b * p), (a / p, b * p, 0), (a * p, 0, b / p)]
    v = np.array(v, float)
    v /= np.linalg.norm(v[0])
    # faces: planos do fecho convexo (cada pentagono vira 3 triangulos coplanares)
    from scipy.spatial import ConvexHull
    hull = ConvexHull(v)
    groups = {}
    for eq, simp in zip(hull.equations, hull.simplices):
        key = tuple(np.round(eq[:3], 4))
        groups.setdefault(key, set()).update(simp.tolist())
    faces = []
    for key, idx in groups.items():
        n = np.array(key)
        idx = list(idx)
        c = v[idx].mean(axis=0)
        u = v[idx[0]] - c
        u /= np.linalg.norm(u)
        w = np.cross(n, u)
        ang = [math.atan2((v[i] - c) @ w, (v[i] - c) @ u) for i in idx]
        faces.append((n, [idx[k] for k in np.argsort(ang)]))
    assert len(faces) == 12 and all(len(f[1]) == 5 for f in faces)
    return v, faces


def rot(ax, ay, az):
    cx, sx, cy, sy, cz, sz = math.cos(ax), math.sin(ax), math.cos(ay), math.sin(ay), math.cos(az), math.sin(az)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rz @ ry @ rx


GOLD_HI = np.array([255, 236, 170])
GOLD = np.array([226, 182, 86])
GOLD_LO = np.array([150, 104, 34])


def solid(size, scale, mono=False):
    """Imagem RGBA (size x size) com o dodecaedro centrado; scale = raio relativo."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    v, faces = dodecahedron()
    R = rot(math.radians(-24), math.radians(20), math.radians(8))
    pv = v @ R.T
    r = S * scale
    mid = (pv.max(axis=0) + pv.min(axis=0)) / 2
    pts = [(S / 2 + (p[0] - mid[0]) * r, S / 2 - (p[1] - mid[1]) * r) for p in pv]
    light = np.array([-0.45, 0.65, 0.62])
    light /= np.linalg.norm(light)
    view = np.array([0, 0, 1.0])
    draw = ImageDraw.Draw(img)
    vis = []
    for n, idx in faces:
        nn = R @ n
        if nn[2] > 0.02:
            vis.append((nn, idx))
    vis.sort(key=lambda f: f[0][2])
    for nn, idx in vis:
        diff = max(0.0, nn @ light)
        h = light + view
        h /= np.linalg.norm(h)
        spec = max(0.0, nn @ h) ** 40
        base = 9 + 26 * diff + 40 * spec
        col = (int(base * 0.92), int(base * 0.93), int(base * 1.05), 255)
        if mono:
            col = (255, 255, 255, 255)
        draw.polygon([pts[i] for i in idx], fill=col)
    # arestas: um pouco mais claras onde a luz bate
    edges = set()
    for nn, idx in vis:
        for k in range(5):
            a, b = idx[k], idx[(k + 1) % 5]
            edges.add((min(a, b), max(a, b)))
    wid = max(2, int(S * 0.013))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for a, b in edges:
        mid = (pv[a] + pv[b]) / 2
        t = float(np.clip(0.5 + 0.6 * (mid @ light), 0, 1))
        col = GOLD_LO + (GOLD_HI - GOLD_LO) * t
        cc = (0, 0, 0, 0) if mono else tuple(int(x) for x in col) + (255,)
        if not mono:
            gd.line([pts[a], pts[b]], fill=(255, 200, 110, 120), width=wid * 3)
        draw.line([pts[a], pts[b]], fill=cc, width=wid)
        for p in (pts[a], pts[b]):
            draw.ellipse([p[0] - wid / 2, p[1] - wid / 2, p[0] + wid / 2, p[1] + wid / 2], fill=cc)
    if not mono:
        glow = glow.filter(ImageFilter.GaussianBlur(S * 0.012))
        img = Image.alpha_composite(glow, img)
    return img.resize((size, size), Image.LANCZOS)


def background(size, rounded=False):
    S = size * SS
    y, x = np.mgrid[0:S, 0:S] / S
    d = np.sqrt((x - 0.45) ** 2 + (y - 0.38) ** 2)
    t = np.clip(d / 0.8, 0, 1)
    top = np.array([38, 42, 56])
    bot = np.array([6, 7, 11])
    rgb = top[None, None] * (1 - t[..., None]) + bot[None, None] * t[..., None]
    a = np.full((S, S), 255, np.uint8)
    img = Image.fromarray(np.dstack([rgb.astype(np.uint8), a]), "RGBA")
    if rounded:
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=255)
        img.putalpha(mask)
        # fio dourado na borda
        ImageDraw.Draw(img).rounded_rectangle([S * 0.02, S * 0.02, S * 0.98, S * 0.98], radius=int(S * 0.2),
                                              outline=(200, 160, 80, 150), width=max(2, int(S * 0.008)))
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    full = Image.alpha_composite(background(1024, True), solid(1024, 0.40))
    full.save(os.path.join(OUT, "icon.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    full.save(os.path.join(OUT, "icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # icone adaptativo do Android: a area segura e o circulo central de 66%
    solid(432, 0.29).save(os.path.join(OUT, "foreground_432.png"))
    background(432).save(os.path.join(OUT, "background_432.png"))
    solid(432, 0.29, mono=True).save(os.path.join(OUT, "monochrome_432.png"))


if __name__ == "__main__":
    main()
