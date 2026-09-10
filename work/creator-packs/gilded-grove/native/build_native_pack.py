"""Assemble the verified Gilded Grove exports into one native-upload GLB.

blender --background --factory-startup --python build_native_pack.py -- 
    --source outputs/creator-packs/gilded-grove --out outputs/creator-packs/gilded-grove-native

No new geometry is authored by this assembler. Stages, lights and runtime scripts
are excluded from the GLB.
Temporary camera, floor and labels are added only after aggregate export and QA.
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

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "work/creator-packs/gilded-grove/src"))
from validate_exports import audit_palette, palette_reference, linked_texture_nodes, texture_uv_layer

VARIANTS = ("Teal", "Ember", "Amethyst")
ARTIFACT_NAME = "GildedGrove_24Models_3Palettes.glb"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def empty(name, parent=None, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    return obj


def palette_material(path, variant):
    image = bpy.data.images.load(str(path), check_existing=False)
    image.name = "GildedGrove_" + variant
    image.colorspace_settings.name = "sRGB"
    image.pack()
    material = bpy.data.materials.new("GildedGrove_Palette_" + variant)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Roughness"].default_value = .55
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def parse_glb(path):
    data = path.read_bytes()
    assert struct.unpack_from("<4sII", data) == (b"glTF", 2, len(data))
    chunks = {}
    offset = 12
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunks[kind] = data[offset + 8:offset + 8 + length]
        offset += length + 8
    return json.loads(chunks[0x4E4F534A]), chunks[0x004E4942]


def assemble(source, output, manifest):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = empty("GildedGrove_MerchantLoot_24Models_3Palettes")
    root["unique_base_models"] = 24
    root["palette_variants"] = 3
    root["variant_placements"] = 72
    root["runtime_scripts"] = 0
    expected = []
    palettes = {}
    for bank, variant in enumerate(VARIANTS):
        palettes[variant] = palette_material(source / "textures" / (variant + "_Palette.png"), variant)
        group = empty(f"{bank + 1:02}_{variant}", root, ((bank - 1) * 36, 0, 0))
        for index, asset in enumerate(manifest["assets"]):
            before = set(bpy.context.scene.objects)
            bpy.ops.import_scene.gltf(filepath=str(source / "glb" / (asset["id"] + ".glb")))
            imported = set(bpy.context.scene.objects) - before
            prop = next(obj for obj in imported if obj.type == "EMPTY" and obj.parent is None)
            meshes = [obj for obj in imported if obj.type == "MESH"]
            assert len(meshes) == asset["mesh_count"]
            layout = ((index % 4 - 1.5) * 8, (index // 4 - 2.5) * 8, 0)
            prop.name = variant + "__" + asset["id"]
            prop.parent = group
            prop.location = layout
            prop["base_model_id"] = asset["id"]
            prop["palette_variant"] = variant
            for obj in meshes:
                role = obj.name.split("__", 1)[1]
                obj.name = variant + "__" + asset["id"] + "__" + role
                obj["role"] = role
                obj.data.materials.clear()
                obj.data.materials.append(palettes[variant])
                for polygon in obj.data.polygons:
                    polygon.material_index = 0
            expected.append({"variant": variant, "id": asset["id"], "group": group.name,
                             "prop": prop.name, "layout": list(layout),
                             "bank_location": list(group.location), "source": asset})
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                             export_extras=True, export_animations=False, export_yup=True)
    return expected


def validate(source, artifact, manifest, expected):
    document, binary = parse_glb(artifact)
    checks = []

    def check(name, value, details=None):
        checks.append({"name": name, "pass": bool(value), "details": details})

    check("GLB under 20 MB", artifact.stat().st_size < 20_000_000, artifact.stat().st_size)
    check("No external buffers or images", all("uri" not in item for section in ("buffers", "images") for item in document.get(section, [])))
    embedded = {}
    for image in document["images"]:
        view = document["bufferViews"][image["bufferView"]]
        raw = binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        embedded[image["name"]] = hashlib.sha256(raw).hexdigest().upper()
    check("Exactly three embedded palettes", len(embedded) == 3, embedded)
    for variant in VARIANTS:
        check(variant + " embedded PNG bytes match verified source",
              embedded.get(variant + "_Palette") == sha(source / "textures" / (variant + "_Palette.png")))
    check("No exported animations, cameras or lights", not document.get("animations") and not document.get("cameras")
          and "KHR_lights_punctual" not in document.get("extensions", {}))
    with tempfile.TemporaryDirectory(prefix="gilded-native-isolated-") as temporary:
        isolated = Path(temporary) / artifact.name
        shutil.copyfile(artifact, isolated)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(isolated))
        bpy.context.view_layer.update()
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        root_objects = [obj for obj in bpy.context.scene.objects if obj.parent is None]
        check("Single named package root", len(root_objects) == 1 and root_objects[0].name == "GildedGrove_MerchantLoot_24Models_3Palettes")
        check("99 role meshes", len(meshes) == 99, len(meshes))
        triangles = sum(len(obj.data.polygons) for obj in meshes)
        check("75,648 aggregate triangles", triangles == 3 * manifest["total_triangles"] == 75648, triangles)
        check("Only empty hierarchy and mesh nodes", all(obj.type in {"EMPTY", "MESH"} for obj in bpy.context.scene.objects))
        check("Hierarchy contains 1 root, 3 palettes and 72 props", len(bpy.context.scene.objects) == 175, len(bpy.context.scene.objects))
        palette_references = palette_reference(ROOT / "work/creator-packs/gilded-grove/src/geometry.py")
        source_pixels = {}
        for variant in VARIANTS:
            palette_check, snapshot = audit_palette(source / "textures" / (variant + "_Palette.png"), palette_references[variant], variant)
            check(variant + " intended RGB palette", palette_check["status"] == "PASS", palette_check)
            source_pixels[variant] = snapshot["pixels"]
        for entry in expected:
            label = entry["variant"] + " " + entry["id"]
            prop = bpy.data.objects.get(entry["prop"])
            check(label + " hierarchy", prop is not None and prop.parent.name == entry["group"]
                  and len(prop.children) == entry["source"]["mesh_count"])
            if prop is None:
                continue
            check(label + " grid position", max(abs(prop.location[i] - entry["layout"][i]) for i in range(3)) < 1e-4)
            check(label + " bank position", max(abs(prop.parent.location[i] - entry["bank_location"][i]) for i in range(3)) < 1e-4)
            points = []
            for child in prop.children:
                role = child.name.split("__", 2)[2]
                reference = next(m for m in entry["source"]["meshes"] if m["name"].endswith("__" + role))
                check(label + " " + role + " pivot", max(abs(child.location[i] - reference["pivot"][i]) for i in range(3)) < 1e-4)
                check(label + " " + role + " triangles", len(child.data.polygons) == reference["triangles"])
                check(label + " " + role + " finite positive geometry", all(math.isfinite(c) for v in child.data.vertices for c in v.co)
                      and all(p.area > 1e-10 for p in child.data.polygons))
                points.extend(prop.matrix_world.inverted() @ child.matrix_world @ vertex.co for vertex in child.data.vertices)
                uv = child.data.uv_layers.active
                atlas_valid = len(child.data.uv_layers) == 1
                if uv:
                    for face in child.data.polygons:
                        coords = [uv.data[i].uv for i in face.loop_indices]
                        cells = {(int(p.x * 4), int(p.y * 4)) for p in coords}
                        if len(cells) != 1:
                            atlas_valid = False
                            break
                        cell = next(iter(cells))
                        if any(cell[i] not in range(4) or abs(p[i] - (cell[i] + .5) / 4) > .021 for p in coords for i in range(2)):
                            atlas_valid = False
                            break
                else:
                    atlas_valid = False
                check(label + " " + role + " single correct atlas UV", atlas_valid)
                textures = linked_texture_nodes(child.data.materials[0])
                check(label + " " + role + " shader uses intended palette", len(textures) == 1 and textures[0].image.name == entry["variant"] + "_Palette"
                      and texture_uv_layer(textures[0], child.data) == uv.name)
                if textures:
                    actual = list(textures[0].image.pixels[:])
                    original = source_pixels[entry["variant"]]
                    check(label + " " + role + " decoded palette pixels", len(actual) == len(original)
                          and max(abs(a-b) for a,b in zip(actual,original)) < 1e-5)
            actual_min = [min(p[i] for p in points) for i in range(3)]
            actual_max = [max(p[i] for p in points) for i in range(3)]
            check(label + " source dimensions preserved", max(abs(actual_min[i] - entry["source"]["bounds_min"][i]) for i in range(3)) < 1e-4
                  and max(abs(actual_max[i] - entry["source"]["bounds_max"][i]) for i in range(3)) < 1e-4)
        report = {"status": "PASS" if all(c["pass"] for c in checks) else "FAIL", "blender": bpy.app.version_string,
                  "artifact": artifact.name, "sha256": sha(artifact), "bytes": artifact.stat().st_size,
                  "source_manifest_sha256": sha(source / "manifest.json"),
                  "source_glb_sha256": {a["id"]: sha(source / "glb" / (a["id"] + ".glb")) for a in manifest["assets"]},
                  "unique_base_models": 24, "palette_variants": 3, "variant_placements": 72,
                  "mesh_count": len(meshes), "triangles": triangles, "checks": checks,
                  "limitations": "Blender roundtrip evidence only. Native Roblox upload and fresh Studio load remain separate gates."}
    return report


def contact_sheet(path):
    # The scene now contains the actual isolated aggregate reimport.
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 2200
    scene.render.resolution_y = 1350
    scene.render.resolution_percentage = 100
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Contact_Sheet_World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.50,.56,.60,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .6
    floor = bpy.data.materials.new("Contact_Sheet_Backdrop")
    floor.diffuse_color = (.075,.095,.105,1)
    bpy.ops.mesh.primitive_plane_add(size=250, location=(0,0,-.10))
    bpy.context.object.data.materials.append(floor)
    for bank, variant in enumerate(VARIANTS):
        curve = bpy.data.curves.new(variant + "_Label", "FONT")
        curve.body = variant.upper() + " / 24 MODELS"
        curve.align_x = "CENTER"
        curve.size = 1.05
        label = bpy.data.objects.new(variant + "_Label", curve)
        bpy.context.collection.objects.link(label)
        label.location = ((bank-1)*36,-25,.02)
    for name,loc,energy,size in (("Key",(-30,-35,65),22000,50),("Fill",(40,0,55),16000,45),("Rim",(0,45,40),12000,35)):
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0,0,0))-light.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add(location=(0,-105,128))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0,0,1))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 113
    scene.camera = camera
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=str(ROOT / "outputs/creator-packs/gilded-grove"))
    parser.add_argument("--out", default=str(ROOT / "outputs/creator-packs/gilded-grove-native"))
    parser.add_argument("--no-render", action="store_true")
    parser.add_argument("--render-only", action="store_true", help="Render the existing aggregate without rewriting it")
    parser.add_argument("--validate-only", action="store_true", help="Reimport and check the existing aggregate without rewriting it")
    opt = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    source, output = Path(opt.source).resolve(), Path(opt.out).resolve()
    output.mkdir(parents=True, exist_ok=True)
    if opt.render_only:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(output / ARTIFACT_NAME))
        contact_sheet(output / "contact-sheet.png")
        return
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    assert len(manifest["assets"]) == 24 and sum(a["mesh_count"] for a in manifest["assets"]) == 33
    artifact = output / ARTIFACT_NAME
    if opt.validate_only:
        expected = [{"variant": variant, "id": asset["id"], "group": f"{bank+1:02}_{variant}",
                     "prop": variant + "__" + asset["id"],
                     "layout": [(index % 4 - 1.5) * 8, (index // 4 - 2.5) * 8, 0],
                     "bank_location": [(bank - 1) * 36, 0, 0], "source": asset}
                    for bank, variant in enumerate(VARIANTS) for index, asset in enumerate(manifest["assets"])]
    else:
        expected = assemble(source, artifact, manifest)
    report = validate(source, artifact, manifest, expected)
    (output / "validation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    summary = {k: report[k] for k in ("status","bytes","mesh_count","triangles","sha256")}
    summary["checks"] = len(report["checks"])
    print("NATIVE_AGGREGATE_QA " + json.dumps(summary), flush=True)
    if report["status"] != "PASS":
        print(json.dumps([c for c in report["checks"] if not c["pass"]],indent=2),flush=True)
        raise SystemExit(1)
    if not opt.no_render:
        contact_sheet(output / "contact-sheet.png")


if __name__ == "__main__":
    main()
