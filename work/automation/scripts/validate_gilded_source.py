"""Read-only independent final .blend and packed palette verification."""
import argparse
import sys
import ast
import bpy
import hashlib
import json
import struct
import zlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--package', required=True)
parser.add_argument('--source', required=True)
parser.add_argument('--report', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
PACK = Path(args.package).resolve()
SOURCE = Path(args.source).resolve()
REPORT = Path(args.report).resolve()

node = next(n for n in ast.parse(SOURCE.read_text()).body
            if isinstance(n, ast.Assign)
            and any(isinstance(t, ast.Name) and t.id == "PALETTES" for t in n.targets))
palettes = ast.literal_eval(node.value)


def verify_png(raw, colors):
    assert raw[:8] == b"\x89PNG\r\n\x1a\n"
    pos, compressed, header = 8, bytearray(), None
    while pos < len(raw):
        length = struct.unpack(">I", raw[pos:pos + 4])[0]
        kind = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + length]
        crc = struct.unpack(">I", raw[pos + 8 + length:pos + 12 + length])[0]
        assert zlib.crc32(kind + data) & 0xffffffff == crc
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", data)
        if kind == b"IDAT":
            compressed.extend(data)
        pos += 12 + length
    assert header == (64, 64, 8, 2, 0, 0, 0), header
    pixels = zlib.decompress(compressed)
    assert len(pixels) == 64 * 193
    for y in range(64):
        row = pixels[y * 193:(y + 1) * 193]
        assert row[0] == 0
        for x in range(64):
            expected = bytes.fromhex(colors[((63 - y) // 16) * 4 + x // 16])
            assert row[1 + x * 3:4 + x * 3] == expected, (x, y)


reports = []
for filename in ("GildedGrove_Editable.blend", "GildedGrove_MerchantScene.blend"):
    path = PACK / "source" / filename
    bpy.ops.wm.open_mainfile(filepath=str(path))
    roots = [o for o in bpy.data.objects if o.name.startswith("Editable_")]
    assert len(roots) == 24, len(roots)
    records = []
    dg = bpy.context.evaluated_depsgraph_get()
    for root in sorted(roots, key=lambda o: o.name):
        triangles, parts = 0, 0
        for obj in root.children_recursive:
            if obj.type != "MESH":
                continue
            evaluated = obj.evaluated_get(dg)
            mesh = evaluated.to_mesh()
            mesh.calc_loop_triangles()
            triangles += len(mesh.loop_triangles)
            parts += 1
            evaluated.to_mesh_clear()
        records.append({"asset": root.name[9:], "parts": parts, "triangles": triangles})
    total = sum(r["triangles"] for r in records)
    assert total == 25216, total
    checks = []
    for variant, colors in palettes.items():
        image = bpy.data.images["GildedGrove_" + variant]
        assert image.packed_file, variant
        assert image.use_fake_user, variant
        assert image.colorspace_settings.name == "sRGB", variant
        raw = bytes(image.packed_file.data)
        assert raw == (PACK / "textures" / (variant + "_Palette.png")).read_bytes(), variant
        verify_png(raw, colors)
        checks.append({"palette": variant, "status": "PASS", "packed": True,
                       "fake_user": True, "colorspace": "sRGB", "authored_RGB_pixels": 4096,
                       "png_sha256": hashlib.sha256(raw).hexdigest()})
    reports.append({"file": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "status": "PASS", "asset_roots": 24, "triangles_excluding_stage": total,
                    "assets": records, "packed_palette_checks": checks})
result = {"status": "PASS", "blender_version": bpy.app.version_string,
          "method": "Reopen both delivered .blend files without saving; evaluate only mesh descendants of Editable_* roots; independently decode all packed PNG bytes, check chunk CRCs and all 4096 RGB pixels per palette against literal authored constants.",
          "files": reports}
REPORT.write_text(json.dumps(result, indent=2), encoding="utf-8")
print("FINAL_SOURCE_REVIEW=" + json.dumps(result))
