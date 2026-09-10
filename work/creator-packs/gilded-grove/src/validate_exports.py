"""Re-import every manifest FBX/GLB in Blender, independently of the builder.

Usage: blender --background --factory-startup --python validate_exports.py --
         --package /path/to/gilded-grove --report /path/to/report.json

Exports are copied to isolated folders without companion textures and imported
into fresh scenes. This is a Blender portability check, not a Roblox Studio test.
The package is read-only; temporary FBX texture extraction stays beside copies.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import time

import bpy
from mathutils import Vector


TOLERANCE = 1e-4
PIXEL_TOLERANCE = 1e-5


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def fresh_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def image_snapshot(image):
    # Reading pixels forces Blender to actually decode the image payload.
    values = list(image.pixels[:])
    return {"width": image.size[0], "height": image.size[1],
            "channels": image.channels, "pixels": values}


def palette_snapshot(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    snapshot = image_snapshot(image)
    if snapshot["width"] != 64 or snapshot["height"] != 64:
        raise ValueError("Source palette must be the authored 64 by 64 PNG")
    if not snapshot["pixels"] or any(not math.isfinite(v) for v in snapshot["pixels"]):
        raise ValueError("Source palette did not decode finite pixels")
    centers = []
    for row in range(4):
        for col in range(4):
            idx = ((row * 16 + 8) * 64 + col * 16 + 8) * 4
            centers.append(snapshot["pixels"][idx:idx + 3])
    snapshot["swatch_centers"] = centers
    bpy.data.images.remove(image)
    return snapshot


def glb_audit(path):
    blob = path.read_bytes()
    magic, version, declared = struct.unpack_from("<4sII", blob, 0)
    if magic != b"glTF" or version != 2 or declared != len(blob):
        raise ValueError("Invalid GLB v2 header or total length")
    chunks, offset = [], 12
    while offset < len(blob):
        size, kind = struct.unpack_from("<II", blob, offset)
        start = offset + 8
        if start + size > len(blob):
            raise ValueError("GLB chunk extends beyond the payload")
        chunks.append((kind, blob[start:start + size]))
        offset = start + size
    if not chunks or chunks[0][0] != 0x4E4F534A:
        raise ValueError("GLB does not begin with its JSON chunk")
    document = json.loads(chunks[0][1])
    uris = [entry["uri"] for section in ("buffers", "images")
            for entry in document.get(section, []) if "uri" in entry]
    external = [u for u in uris if not u.startswith("data:")]
    images = document.get("images", [])
    if external:
        raise ValueError("GLB contains external buffer/image dependencies")
    if not images or any("bufferView" not in i and not i.get("uri", "").startswith("data:")
                         for i in images):
        raise ValueError("GLB image is not embedded")
    return {"version": version, "external_uri_count": len(external),
            "embedded_image_count": len(images), "chunk_count": len(chunks)}


def linked_texture_nodes(material):
    """Only count image nodes actually feeding the shader's base color."""
    found = []
    visited = set()

    def upstream(socket):
        for link in socket.links:
            node = link.from_node
            if node.as_pointer() in visited:
                continue
            visited.add(node.as_pointer())
            if node.type == "TEX_IMAGE" and node.image:
                found.append(node)
            for input_socket in node.inputs:
                upstream(input_socket)

    if material and material.use_nodes:
        for node in material.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                upstream(node.inputs["Base Color"])
    return found


def texture_uv_layer(texture, mesh):
    """Resolve the UV set actually sampled by an imported texture node."""
    default = next((layer.name for layer in mesh.uv_layers if layer.active_render),
                   mesh.uv_layers.active.name if mesh.uv_layers.active else None)
    socket = texture.inputs.get("Vector")
    if socket is None or not socket.links:
        return default
    visited = set()
    while socket.links:
        link = socket.links[0]
        node = link.from_node
        if node.as_pointer() in visited:
            return None
        visited.add(node.as_pointer())
        if node.type == "UVMAP":
            return node.uv_map or default
        if node.type == "TEX_COORD":
            return default if link.from_socket.name == "UV" else None
        if node.type == "MAPPING":
            for name, expected in (("Location", (0, 0, 0)), ("Rotation", (0, 0, 0)),
                                   ("Scale", (1, 1, 1))):
                if any(abs(a - b) > TOLERANCE for a, b in zip(node.inputs[name].default_value, expected)):
                    return None
            socket = node.inputs["Vector"]
            continue
        return None
    return default


def validate_one(asset, kind, package, scratch, source_palette):
    export = package / kind / (asset["id"] + "." + kind)
    result = {"id": asset["id"], "format": kind, "status": "FAIL", "checks": {},
              "errors": [], "source_file": str(export), "tolerance": TOLERANCE}
    errors = result["errors"]

    def check(name, success, details=None):
        result["checks"][name] = {"pass": bool(success), "details": details}
        if not success:
            errors.append(name)

    try:
        result["sha256"] = sha256(export)
        result["bytes"] = export.stat().st_size
        if kind == "glb":
            result["glb"] = glb_audit(export)
            check("GLB has only embedded dependencies", True)
        destination = scratch / (asset["id"] + "_" + kind)
        destination.mkdir()
        imported_path = destination / export.name
        shutil.copyfile(export, imported_path)
        if sha256(imported_path) != result["sha256"]:
            raise ValueError("Export changed while being copied; rerun against a stable build")
        fresh_scene()
        if kind == "fbx":
            bpy.ops.import_scene.fbx(filepath=str(imported_path), use_image_search=False)
        else:
            bpy.ops.import_scene.gltf(filepath=str(imported_path))
        bpy.context.view_layer.update()
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        check("mesh count", len(meshes) == asset["mesh_count"],
              {"actual": len(meshes), "expected": asset["mesh_count"]})
        actual_names = sorted(o.name for o in meshes)
        expected_names = sorted(m["name"] for m in asset["meshes"])
        check("mesh names and role identity", actual_names == expected_names,
              {"actual": actual_names, "expected": expected_names})
        triangles = 0
        points = []
        pivot_results = []
        uv_results = []
        image_objects = {}
        for obj in meshes:
            mesh = obj.data
            mesh.calc_loop_triangles()
            triangles += len(mesh.loop_triangles)
            check(obj.name + " finite vertices",
                  all(math.isfinite(c) for v in mesh.vertices for c in v.co))
            check(obj.name + " finite world transform",
                  all(math.isfinite(c) for row in obj.matrix_world for c in row))
            check(obj.name + " nonzero triangles",
                  all(p.area > 1e-10 for p in mesh.polygons))
            points.extend(obj.matrix_world @ v.co for v in mesh.vertices)
            reference = next((m for m in asset["meshes"] if m["name"] == obj.name), None)
            if reference:
                pivot = list(obj.matrix_world.translation)
                difference = max(abs(pivot[i] - reference["pivot"][i]) for i in range(3))
                pivot_results.append({"mesh": obj.name, "actual": pivot,
                                      "expected": reference["pivot"], "max_error": difference})
                check(obj.name + " role pivot", difference <= TOLERANCE)
                check(obj.name + " triangle count", len(mesh.loop_triangles) == reference["triangles"])
            uv = mesh.uv_layers.active
            check(obj.name + " single unambiguous UV layer", len(mesh.uv_layers) == 1,
                  [layer.name for layer in mesh.uv_layers])
            valid_uv = bool(uv) and len(uv.data) == len(mesh.loops)
            if valid_uv:
                valid_uv = all(math.isfinite(c) and 0 <= c <= 1
                               for entry in uv.data for c in entry.uv)
            check(obj.name + " finite atlas UVs", valid_uv)
            uv_range = ([min(entry.uv[i] for entry in uv.data) for i in range(2)],
                        [max(entry.uv[i] for entry in uv.data) for i in range(2)]) if uv and uv.data else None
            # Every triangle must stay wholly inside one of the 16 palette
            # swatches. A valid 0..1 primitive UV unwrap is not a palette unwrap.
            atlas_faces = 0
            if valid_uv:
                for polygon in mesh.polygons:
                    coords = [uv.data[i].uv for i in polygon.loop_indices]
                    cells = {(min(int(p.x * 4), 3), min(int(p.y * 4), 3)) for p in coords}
                    if len(cells) != 1:
                        continue
                    cell = next(iter(cells))
                    if all(abs(p[i] - (cell[i] + 0.5) / 4) <= 0.021 for p in coords for i in range(2)):
                        atlas_faces += 1
            check(obj.name + " every face addresses one palette swatch",
                  atlas_faces == len(mesh.polygons),
                  {"correct_faces": atlas_faces, "total_faces": len(mesh.polygons)})
            uv_results.append({"mesh": obj.name, "uv_layers": len(mesh.uv_layers),
                               "layer_name": uv.name if uv else None,
                               "loop_count": len(mesh.loops), "valid": valid_uv,
                               "range": uv_range, "palette_faces": atlas_faces})
            used_materials = {polygon.material_index for polygon in mesh.polygons}
            for slot in used_materials:
                mat = mesh.materials[slot] if slot < len(mesh.materials) else None
                textures = linked_texture_nodes(mat)
                check(obj.name + f" material {slot} base color texture", bool(textures))
                for texture in textures:
                    shader_uv = texture_uv_layer(texture, mesh)
                    check(obj.name + f" material {slot} shader samples atlas UV",
                          bool(uv) and shader_uv == uv.name,
                          {"shader_uv": shader_uv, "validated_uv": uv.name if uv else None})
                    image_objects[texture.image.as_pointer()] = texture.image
        check("total triangle count", triangles == asset["triangles"],
              {"actual": triangles, "expected": asset["triangles"]})
        if points:
            actual_min = [min(p[i] for p in points) for i in range(3)]
            actual_max = [max(p[i] for p in points) for i in range(3)]
            actual_size = [actual_max[i] - actual_min[i] for i in range(3)]
            error = max(abs(actual_min[i] - asset["bounds_min"][i]) for i in range(3))
            error = max(error, max(abs(actual_max[i] - asset["bounds_max"][i]) for i in range(3)))
            check("world bounds and dimensions", error <= TOLERANCE,
                  {"min": actual_min, "max": actual_max, "size": actual_size,
                   "expected_size": asset["size"], "max_error": error})
        else:
            check("world bounds and dimensions", False, "No meshes imported")
        texture_results = []
        check("at least one texture decoded", bool(image_objects))
        for image in image_objects.values():
            snapshot = image_snapshot(image)
            equal_shape = (snapshot["width"], snapshot["height"], len(snapshot["pixels"])) == (
                source_palette["width"], source_palette["height"], len(source_palette["pixels"]))
            pixel_error = max((abs(a - b) for a, b in zip(snapshot["pixels"], source_palette["pixels"])),
                              default=float("inf")) if equal_shape else float("inf")
            check(image.name + " matches source palette pixels", equal_shape and pixel_error <= PIXEL_TOLERANCE,
                  {"width": snapshot["width"], "height": snapshot["height"],
                   "max_pixel_error": pixel_error if math.isfinite(pixel_error) else None})
            path = Path(bpy.path.abspath(image.filepath)).resolve() if image.filepath else None
            embedded = bool(image.packed_file) or bool(path and path.is_relative_to(destination.resolve()))
            check(image.name + " portable embedded texture", embedded,
                  {"packed": bool(image.packed_file), "loaded_from_isolated_folder":
                   bool(path and path.is_relative_to(destination.resolve()))})
            texture_results.append({"image": image.name, "decoded": snapshot["width"] > 0,
                                    "pixel_match": pixel_error <= PIXEL_TOLERANCE,
                                    "portable": embedded})
        result.update(triangles=triangles, mesh_count=len(meshes),
                      role_pivots=pivot_results, uv=uv_results, textures=texture_results,
                      coordinate_system="Blender importers restored source Z-up coordinates")
    except Exception as exc:
        errors.append(type(exc).__name__ + ": " + str(exc))
    result["status"] = "PASS" if not errors else "FAIL"
    print("EXPORT_VALIDATION " + json.dumps({"id": asset["id"], "format": kind,
                                             "status": result["status"], "errors": errors}), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--report", required=True)
    opt = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    package = Path(opt.package).resolve()
    report_path = Path(opt.report).resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    started = time.time()
    manifest_path = package / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if len(manifest["assets"]) != manifest["asset_count"]:
        raise ValueError("Manifest asset count does not match entries")
    fresh_scene()
    palette_path = package / "textures" / "Teal_Palette.png"
    palette = palette_snapshot(palette_path)
    report = {"validator": "Gilded Grove Blender FBX and GLB round-trip validation",
              "blender": bpy.app.version_string, "scope": "Blender exports only; no Roblox Studio pass asserted",
              "package": str(package), "manifest_sha256": sha256(manifest_path),
              "source_palette_sha256": sha256(palette_path),
              "source_palette_swatch_centers": palette["swatch_centers"],
              "expected_imports": 2 * len(manifest["assets"]), "results": []}
    with tempfile.TemporaryDirectory(prefix="gilded-grove-export-check-") as temporary:
        scratch = Path(temporary)
        for asset in manifest["assets"]:
            for kind in ("fbx", "glb"):
                report["results"].append(validate_one(asset, kind, package, scratch, palette))
                # Persist after every actual import so interrupted checks remain visible.
                report_path.write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
        fresh_scene()
    report["passed"] = sum(r["status"] == "PASS" for r in report["results"])
    report["failed"] = len(report["results"]) - report["passed"]
    report["status"] = "PASS" if report["passed"] == report["expected_imports"] else "FAIL"
    report["elapsed_seconds"] = round(time.time() - started, 3)
    report_path.write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    print("EXPORT_VALIDATION_SUMMARY " + json.dumps({k: report[k] for k in
          ("status", "passed", "failed", "expected_imports", "elapsed_seconds")}), flush=True)
    if report["status"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
