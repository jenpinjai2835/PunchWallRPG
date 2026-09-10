"""Derive a local Studio preview from the actual GLB deliveries, without uploads.

This validates native rendering of the portable geometry; it does not exercise
Roblox's File > Import dialog or create persistent uploaded mesh assets.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geometry import PALETTES


def xyz(v):
    return [round(v.x, 6), round(v.z, 6), round(-v.y, 6)]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--package", required=True)
    p.add_argument("--out", required=True)
    opt = p.parse_args(sys.argv[sys.argv.index("--") + 1:])
    pack, out = Path(opt.package).resolve(), Path(opt.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((pack / "manifest.json").read_text())
    for idx, asset in enumerate(manifest["assets"]):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        source = pack / "glb" / (asset["id"] + ".glb")
        bpy.ops.import_scene.gltf(filepath=str(source))
        records = []
        for obj in sorted(bpy.context.scene.objects, key=lambda x: x.name):
            if obj.type != "MESH":
                continue
            mesh = obj.data
            vertices = [xyz(obj.matrix_world @ v.co) for v in mesh.vertices]
            uv = mesh.uv_layers.active.data
            faces = []
            mesh.calc_loop_triangles()
            for face in mesh.loop_triangles:
                coords = [uv[i].uv for i in face.loops]
                cells = {int(c.x * 4) + 4 * int(c.y * 4) for c in coords}
                assert len(cells) == 1, "Triangle crosses palette cells"
                faces.append([*[v + 1 for v in face.vertices], next(iter(cells)) + 1])
            records.append({"name": obj.name, "vertices": vertices, "faces": faces,
                            "pivot": xyz(obj.matrix_world.translation)})
        assert sum(len(m["faces"]) for m in records) == asset["triangles"]
        data = {"id": asset["id"], "index": idx, "meshes": records,
                "palette": PALETTES["Teal"], "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "expected_triangles": asset["triangles"]}
        (out / (asset["id"] + ".json")).write_text(json.dumps(data, separators=(",", ":")))
    print("STUDIO GEOMETRY COMPLETE: 24 actual GLB files")


if __name__ == "__main__":
    main()
