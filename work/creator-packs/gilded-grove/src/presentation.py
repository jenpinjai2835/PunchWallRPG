"""Render the actual delivered geometry as a storefront vignette and collection."""
import argparse
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from geometry import PALETTES,COLOR_KEYS,rgba
from build import aim,render,stage_cube,simple_mat


def refresh_palettes(pack):
    for variant in PALETTES:
        im=bpy.data.images.get("GildedGrove_"+variant)
        target=str(pack/"textures"/(variant+"_Palette.png"))
        if not im:
            im=bpy.data.images.load(target,check_existing=False)
            im.name="GildedGrove_"+variant
        elif im.packed_file:
            im.unpack(method="REMOVE")
        im.filepath=target
        im.reload()
        im.colorspace_settings.name="sRGB"
        im.use_fake_user=True
        im.pack()


def frame_objects(scene,cam,objects,margin=1.1):
    bpy.context.view_layer.update()
    points=[cam.matrix_world.inverted() @ (o.matrix_world @ Vector(c))
            for o in objects for c in o.bound_box]
    xmin,xmax=min(p.x for p in points),max(p.x for p in points)
    ymin,ymax=min(p.y for p in points),max(p.y for p in points)
    cam.location+=cam.matrix_world.to_quaternion() @ Vector(((xmin+xmax)/2,(ymin+ymax)/2,0))
    aspect=scene.render.resolution_x/scene.render.resolution_y
    cam.data.ortho_scale=max(xmax-xmin,(ymax-ymin)*aspect)*margin


def overlay(cam,name,text,x,y,size,color):
    curve=bpy.data.curves.new(name,"FONT");curve.body=text;curve.size=size
    curve.space_character=1.15
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
    obj.rotation_euler=cam.rotation_euler
    bpy.context.view_layer.update()
    obj.location=cam.matrix_world @ Vector((x,y,-3))
    m=bpy.data.materials.new(name+"Material");m.use_nodes=True
    nodes=m.node_tree.nodes;nodes.clear()
    output=nodes.new("ShaderNodeOutputMaterial");em=nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value=rgba(color)
    m.node_tree.links.new(em.outputs[0],output.inputs["Surface"])
    curve.materials.append(m)
    obj.visible_shadow=False
    return obj


def main():
    p=argparse.ArgumentParser();p.add_argument("--package",required=True)
    p.add_argument("--refresh-textures-only",action="store_true")
    p.add_argument("--hero-only",action="store_true")
    args=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    pack=Path(args.package).resolve()
    if args.refresh_textures_only:
        for name in ("GildedGrove_Editable.blend","GildedGrove_MerchantScene.blend"):
            path=pack/"source"/name
            bpy.ops.wm.open_mainfile(filepath=str(path))
            refresh_palettes(pack)
            bpy.ops.wm.save_as_mainfile(filepath=str(path))
        print("SOURCE PALETTES REFRESHED")
        return
    bpy.ops.wm.open_mainfile(filepath=str(pack/"source"/"GildedGrove_Editable.blend"))
    refresh_palettes(pack)
    scene=bpy.context.scene;cam=scene.camera
    scene.cycles.samples=32
    scene.render.resolution_x=1800;scene.render.resolution_y=1440
    all_display=[o for o in scene.objects if o.type in {"MESH","FONT"} and o.name!="Showcase floor"]
    frame_objects(scene,cam,all_display,1.13)
    bpy.ops.wm.save_as_mainfile(filepath=str(pack/"source"/"GildedGrove_Editable.blend"))
    if not args.hero_only:
        render(scene,pack/"images"/"01_Collection.png",1800,1440)

    # A deliberately assembled merchant corner using only assets sold in the pack.
    placements={
        "17_Merchant_Stall":((0,1,0),0),
        "01_Wayfarer_Chest":((-2.6,-1.6,0),-.12),
        "02_Royal_Chest":((.7,1,1.82),0),
        "03_Shipping_Crate":((2.4,-1.6,0),.12),
        "05_Merchant_Barrel":((4.2,.45,0),0),
        "08_Treasure_Cart":((-5.2,.2,0),-.4),
        "09_Coin_Stack":((-.8,-2.9,0),0),
        "10_Coin_Pouch":((-.2,-2.6,0),0),
        "12_Crystal_Cluster":((1.3,-3,0),-.1),
        "19_Reward_Pedestal":((4.2,-2,0),0),
        "21_Lantern_Post":((-6.1,2.6,0),0),
        "23_Market_Fence":((4.2,3.7,0),0),
        "07_Display_Tray":((-.95,.85,1.82),0),
        "14_Alchemy_Bottle":((-.8,.85,2.01),0),
    }
    for o in scene.objects:
        if o.type in {"MESH","FONT"}:o.hide_render=True
    for root in [o for o in scene.objects if o.name.startswith("Editable_")]:
        asset=root.name.removeprefix("Editable_")
        if asset in placements:
            pos,angle=placements[asset];root.location=pos;root.rotation_euler.z=angle
            for child in root.children:child.hide_render=False
    floor=scene.objects.get("Showcase floor");floor.hide_render=False;floor.location.z=-.46
    platform=stage_cube("Hero platform",(14,10,.32),(-.25,.5,-.18),simple_mat("Hero sand","526966"),.2)
    cam.location=(13,-22,16);aim(cam,(-.3,.3,1.3));cam.data.ortho_scale=21
    scene.render.resolution_x=1920;scene.render.resolution_y=1200
    bpy.context.view_layer.update()
    labels=[overlay(cam,"Brand","GILDED GROVE",-9.45,5.62,.58,"F8E4AF"),
            overlay(cam,"Subtitle","MERCHANT & LOOT COLLECTION",-9.39,5.14,.22,"C9D9D2"),
            overlay(cam,"Count","24 ORIGINAL MODELS   /   3 PALETTES",-9.39,-5.66,.27,"F8E4AF"),
            overlay(cam,"RenderNote","BLENDER RENDER",6.64,-5.65,.17,"C9D9D2")]
    render(scene,pack/"images"/"00_Cover_Teal.png",1920,1200)
    bpy.ops.wm.save_as_mainfile(filepath=str(pack/"source"/"GildedGrove_MerchantScene.blend"))
    for palette in ("Ember","Amethyst"):
        for key,code in zip(COLOR_KEYS,PALETTES[palette]):
            mat=bpy.data.materials.get("GG_"+key)
            if mat:
                mat.diffuse_color=rgba(code)
                mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=rgba(code)
        render(scene,pack/"images"/("02_Palette_"+palette+".png"),1920,1200)
    print("PRESENTATION COMPLETE",flush=True)


if __name__=="__main__":main()
