#!/usr/bin/env python3
"""Render a 1024px app icon: an eyedropper on a blue tile. Standard library only."""

import math
import struct
import sys
import zlib


def write_png(path, width, height, rgba):
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba[y * stride : (y + 1) * stride])
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def clamp01(value):
    return 0.0 if value < 0 else 1.0 if value > 1 else value


def smooth(edge):
    edge = clamp01(edge)
    return edge * edge * (3 - 2 * edge)


def rounded_box(x, y, cx, cy, half_w, half_h, radius):
    qx = abs(x - cx) - (half_w - radius)
    qy = abs(y - cy) - (half_h - radius)
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - radius


def blend(dst, src, alpha):
    inv = 1.0 - alpha
    return (
        src[0] * alpha + dst[0] * inv,
        src[1] * alpha + dst[1] * inv,
        src[2] * alpha + dst[2] * inv,
        src[3] * alpha + dst[3] * inv,
    )


def cover(distance):
    return smooth(0.5 - distance)


def capsule(x, y, x0, y0, x1, y1, radius):
    dx = x1 - x0
    dy = y1 - y0
    length = math.hypot(dx, dy) or 1.0
    t = ((x - x0) * dx + (y - y0) * dy) / (length * length)
    t = 0.0 if t < 0 else 1.0 if t > 1 else t
    px = x0 + dx * t
    py = y0 + dy * t
    return math.hypot(x - px, y - py) - radius


def render(size):
    pixels = bytearray(size * size * 4)
    for y in range(size):
        py = y + 0.5
        for x in range(size):
            px = x + 0.5
            tile = rounded_box(px, py, size / 2, size / 2, size * 0.46, size * 0.46, size * 0.22)
            t = py / size
            bg = (
                18 + (10 - 18) * t,
                92 + (48 - 92) * t,
                214 + (120 - 214) * t,
                255.0,
            )
            color = (0.0, 0.0, 0.0, 0.0)
            color = blend(color, bg, cover(tile))

            # Dropper barrel, from lower-left bulb to upper-right tip.
            barrel = capsule(px, py, size * 0.36, size * 0.66, size * 0.68, size * 0.30, size * 0.045)
            color = blend(color, (255, 255, 255, 255), cover(barrel))
            tip = capsule(px, py, size * 0.68, size * 0.30, size * 0.76, size * 0.21, size * 0.018)
            color = blend(color, (255, 255, 255, 255), cover(tip))

            bulb = math.hypot(px - size * 0.33, py - size * 0.70) - size * 0.09
            color = blend(color, (255, 196, 87, 255), cover(bulb))
            glass = math.hypot(px - size * 0.30, py - size * 0.67) - size * 0.035
            color = blend(color, (255, 244, 214, 255), cover(glass))

            offset = (y * size + x) * 4
            pixels[offset] = int(clamp01(color[0] / 255.0) * 255)
            pixels[offset + 1] = int(clamp01(color[1] / 255.0) * 255)
            pixels[offset + 2] = int(clamp01(color[2] / 255.0) * 255)
            pixels[offset + 3] = int(clamp01(color[3] / 255.0) * 255)
    return pixels


def main():
    if len(sys.argv) != 2:
        print("usage: render_icon.py OUTPUT.png", file=sys.stderr)
        return 2
    size = 1024
    write_png(sys.argv[1], size, size, render(size))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
