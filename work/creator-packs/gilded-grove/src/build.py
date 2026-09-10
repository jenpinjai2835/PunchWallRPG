"""Build original assets, portable exports, an editable showroom and real renders.

blender --background --factory-startup --python src/build.py -- --out OUTPUT
No web assets, add-ons or external textures are used.
"""
import argparse
import json
import math
import struct
import sys
import zlib
from pathlib import Path
import bpy
from mathutils import Vector

SRC = Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
from geometry import COLOR_KEYS, PALETTES, bounds, rgba, material
import pickups


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--only", default="")
    p.add_argument("--no-render", action="store_true")
    p.add_argument("--exports-only", action="store_true")
    p.add_argument("--resolution", type=int, default=1600)
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def palette_images(out):
    images = {}
    for variant, colors in PALETTES.items():
        # Encode authored sRGB bytes explicitly. Generated Blender image save()
        # writes its buffer directly; feeding linear shader colors darkens PNGs.
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        raw = bytearray()
        for y in range(64):
            raw.append(0)  # PNG filter: none. PNG rows run top to bottom.
            for x in range(64):
                raw.extend(bytes.fromhex(colors[((63-y)//16)*4+x//16]))
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB",64,64,8,2,0,0,0))
        png += chunk(b"sRGB", b"\x00") + chunk(b"IDAT",zlib.compress(raw)) + chunk(b"IEND",b"")
        target = out / "textures" / (variant + "_Palette.png")
        target.write_bytes(png)
        im = bpy.data.images.load(str(target), check_existing=False)
        im.name = "GildedGrove_" + variant
        im.colorspace_settings.name = "sRGB"
        im.use_fake_user = True
        im.pack()
        images[variant] = im
    return images


def atlas_material(image):
    m = bpy.data.materials.new("GildedGrove_Palette")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .55
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def duplicate_for_export(a, atlas):
    root = bpy.data.objects.new(a.name, None)
    bpy.context.collection.objects.link(root)
    root["description"] = a.description
    groups = {}
    for original in a.objects:
        obj = original.copy()
        obj.data = original.data.copy()
        bpy.context.collection.objects.link(obj)
        obj.matrix_world = original.matrix_world.copy()
        # Primitive operators create UVMap. Keeping it makes FBX/glTF use the
        # primitive UVs instead of our palette and changes the delivered colors.
        for layer in list(obj.data.uv_layers):
            obj.data.uv_layers.remove(layer)
        uv = obj.data.uv_layers.new(name="PaletteUV")
        uv.active_render = True
        for face in obj.data.polygons:
            key = obj.data.materials[face.material_index].name.removeprefix("GG_")
            cell = COLOR_KEYS.index(key)
            # A tiny non-zero triangle patch within a flat swatch. No visible seams.
            for j, loop in enumerate(face.loop_indices):
                offsets = ((-.02,-.02),(.02,-.02),(.02,.02),(-.02,.02))
                dx,dy = offsets[j % 4]
                uv.data[loop].uv = ((cell%4+.5)/4+dx,(cell//4+.5)/4+dy)
            face.material_index = 0
        obj.data.materials.clear()
        obj.data.materials.append(atlas)
        groups.setdefault(original["gg_role"], []).append(obj)
    joined=[]
    for role, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = a.name + "__" + role
        bpy.context.scene.cursor.location = a.pivots.get(role, (0,0,0))
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        tri = obj.modifiers.new("Portable triangles", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=tri.name)
        obj.parent = root
        obj["role"] = role
        joined.append(obj)
    return root, joined


def inspect_meshes(name, objects):
    lo, hi = bounds(objects)
    meshes=[]
    for o in objects:
        o.data.calc_loop_triangles()
        if len(o.data.loop_triangles)>10000:
            raise RuntimeError(f"Mesh exceeds 10000 triangles: {o.name}")
        if any(not math.isfinite(v) for vert in o.data.vertices for v in vert.co):
            raise RuntimeError(f"Nonfinite vertex in {name}")
        if not o.data.uv_layers:
            raise RuntimeError(f"UV missing: {name}")
        tiny = sum(p.area < 1e-10 for p in o.data.polygons)
        if tiny:
            raise RuntimeError(f"Degenerate triangles: {name} {tiny}")
        meshes.append({"name":o.name,"vertices":len(o.data.vertices),
                       "triangles":len(o.data.loop_triangles),"pivot":list(o.location)})
    return {"bounds_min":lo,"bounds_max":hi,"size":[hi[i]-lo[i] for i in range(3)],
            "triangles":sum(m["triangles"] for m in meshes),"mesh_count":len(meshes),"meshes":meshes}


def export_asset(a, out, atlas):
    root, meshes = duplicate_for_export(a,atlas)
    metrics = inspect_meshes(a.name, meshes)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [root]+meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(out/"glb"/(a.name+".glb")),export_format="GLB",
        use_selection=True,export_extras=True,export_animations=False,export_yup=True)
    bpy.ops.export_scene.fbx(filepath=str(out/"fbx"/(a.name+".fbx")),use_selection=True,
        object_types={"MESH","EMPTY"},global_scale=1.0,apply_unit_scale=False,
        axis_forward="-Z",axis_up="Y",bake_anim=False,path_mode="COPY",embed_textures=True)
    for obj in meshes+[root]:
        bpy.data.objects.remove(obj,do_unlink=True)
    return {"id":a.name,"category":a.category,"description":a.description,
            "notes":a.notes,"role_pivots":a.pivots,**metrics}


def simple_mat(name, color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=rgba(color)
    m.use_nodes=True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=rgba(color)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.72
    return m


def stage_cube(name, size, location, mat, bevel=.08):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object
    obj.name=name
    obj.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    if bevel:
        b=obj.modifiers.new("Soft plinth", "BEVEL"); b.width=bevel;b.segments=2
    return obj


def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


def camera_setup(scene):
    bpy.ops.object.camera_add(location=(30,-48,42))
    cam=bpy.context.object
    cam.name="Showcase_Camera"
    cam.data.type="ORTHO"
    cam.data.ortho_scale=53
    aim(cam,(0,0,0))
    scene.camera=cam
    return cam


def lights_setup(scene):
    scene.world.color=(.18,.18,.18)
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.2,.25,.3,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.5
    for name,loc,power,size,color in [("Key",(-12,-18,30),4500,18,(1,.85,.67)),
                                      ("Fill",(20,-4,18),2500,14,(.68,.84,1)),
                                      ("Rim",(0,18,22),5000,12,(.65,1,.95))]:
        bpy.ops.object.light_add(type="AREA",location=loc)
        obj=bpy.context.object;obj.name=name
        obj.data.energy=power;obj.data.shape="DISK";obj.data.size=size;obj.data.color=color
        aim(obj,(0,0,0))


def render(scene, path, width, height):
    scene.render.resolution_x=width;scene.render.resolution_y=height
    scene.render.resolution_percentage=100
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)


def card_label(text, location, size, mat):
    curve=bpy.data.curves.new("Label","FONT")
    curve.body=text;curve.size=size;curve.align_x="CENTER";curve.extrude=0
    obj=bpy.data.objects.new("DisplayLabel_"+text,curve)
    bpy.context.collection.objects.link(obj)
    obj.location=location
    # Text lies flat in XY, matching the display plinth tops.
    obj.data.materials.append(mat)
    return obj


def layout_showroom(assets):
    roots=[]
    ped_mat=simple_mat("Showcase pedestal","E1D7C2")
    floor_mat=simple_mat("Showcase background","233740")
    label_mat=simple_mat("Showcase labels","42565A")
    for idx,a in enumerate(assets):
        col=idx%6;row=idx//6
        pos=((col-2.5)*8,(row-1.5)*8,0)
        root=bpy.data.objects.new("Editable_"+a.name,None)
        bpy.context.collection.objects.link(root)
        for o in a.objects:
            o.parent=root
        root.location=pos
        roots.append(root)
        stage_cube("Display_"+a.name,(7.35,7.35,.28),(pos[0],pos[1],-.16),ped_mat,.12)
        label=a.name.split("_",1)[1].replace("_"," ")
        card_label(a.name[:2]+"  "+label,(pos[0],pos[1]-3.08,.012),.27,label_mat)
    floor=stage_cube("Showcase floor",(200,200,.25),(0,0,-.5),floor_mat,0)
    return roots,floor


def main():
    opt=args(); out=Path(opt.out).resolve()
    for sub in ("glb","fbx","textures","source","images","evidence"):
        (out/sub).mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene
    scene.unit_settings.system="NONE"
    scene.render.engine="CYCLES"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.threads_mode="FIXED";scene.render.threads=6
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX"
    images=palette_images(out); atlas=atlas_material(images["Teal"])
    assets=[]
    if not opt.only or opt.only=="containers":
        import containers
        assets+=containers.build()
    if not opt.only or opt.only=="pickups":
        assets+=pickups.build()
    if not opt.only or opt.only=="stalls":
        import stalls
        assets+=stalls.build()
    assets.sort(key=lambda a:a.name)
    bpy.context.view_layer.update()
    records=[]
    for a in assets:
        print("EXPORT "+a.name,flush=True)
        records.append(export_asset(a,out,atlas))
    manifest={"product":"Gilded Grove - Merchant & Loot","version":"0.1.0",
        "asset_count":len(records),"blender_version":bpy.app.version_string,
        "source_axes":{"up":"+Z","front":"-Y","unit":"one intended stud; select Studs in Studio"},
        "palette_variants":list(PALETTES),"samples":["03_Shipping_Crate","09_Coin_Stack","12_Crystal_Cluster"],
        "runtime_scripts":0,"external_mesh_dependencies":0,
        "total_triangles":sum(a["triangles"] for a in records),"assets":records,
        "studio_validation":"PENDING","notes":"24 unique base models; palette swaps are not additional models. No gameplay systems included."}
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    if opt.exports_only:
        print("EXPORTS COMPLETE "+str(out),flush=True)
        return
    roots,floor=layout_showroom(assets)
    cam=camera_setup(scene); lights_setup(scene)
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"source"/"GildedGrove_Editable.blend"))
    if not opt.no_render:
        if opt.only:
            cam.location=(20,-34,30);cam.data.ortho_scale=46;aim(cam,(0,-8,0))
        render(scene,out/"images"/"01_Collection.png",opt.resolution,int(opt.resolution*.8))
        # Actual model portraits, framed using each object's true bounds.
        floor.location.z=-.125
        for i,(a,root) in enumerate(zip(assets,roots)):
            for o in scene.objects:
                if o.type in {"MESH","FONT"}:
                    o.hide_render=o not in a.objects and o!=floor
            original=root.location.copy();root.location=(0,0,0)
            lo,hi=bounds(a.objects);size=Vector(hi)-Vector(lo)
            center=(Vector(hi)+Vector(lo))/2
            span=max(size.x,size.y,size.z)*1.4
            cam.location=center+Vector((span,-span*1.5,span*.9));aim(cam,center)
            cam.data.ortho_scale=max(size.z*1.45,size.x*1.55,size.y*1.8,2)
            render(scene,out/"images"/(a.name+".png"),700,700)
            root.location=original
        for o in scene.objects:o.hide_render=False
    print("BUILD COMPLETE "+str(out),flush=True)


if __name__=="__main__":
    main()
