"""Build, render and independently reimport one original catalog collection.

Run with Blender --background --factory-startup --threads 2 --python build.py --
  --module packs/mossvale_camp.py --out outputs/creator-packs/catalog/mossvale-camp
Native Roblox upload and paid listing remain separate acceptance gates.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'gilded-grove/src'
sys.path.insert(0, str(SOURCE))
import geometry
import build as base
import presentation
import validate_exports as validation


def write(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False)+'\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(path):
    spec = importlib.util.spec_from_file_location('catalog_pack', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def studio_xyz(vector):
    return [round(vector.x, 6), round(vector.z, 6), round(-vector.y, 6)]


def studio_geometry(out, manifest, colors):
    for index, asset in enumerate(manifest['assets']):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        source = out/'glb'/(asset['id']+'.glb')
        bpy.ops.import_scene.gltf(filepath=str(source))
        records = []
        for obj in sorted(bpy.context.scene.objects, key=lambda item: item.name):
            if obj.type != 'MESH':
                continue
            mesh = obj.data
            mesh.calc_loop_triangles()
            uv = mesh.uv_layers.active.data
            faces = []
            for face in mesh.loop_triangles:
                cells = {int(uv[i].uv.x*4)+4*int(uv[i].uv.y*4) for i in face.loops}
                assert len(cells) == 1
                faces.append([*[v+1 for v in face.vertices], cells.pop()+1])
            records.append({'name':obj.name,
                'vertices':[studio_xyz(obj.matrix_world@v.co) for v in mesh.vertices],
                'faces':faces, 'pivot':studio_xyz(obj.matrix_world.translation)})
        assert sum(len(m['faces']) for m in records) == asset['triangles']
        write(out/'studio-geometry'/(asset['id']+'.json'), {
            'id':asset['id'], 'index':index, 'meshes':records,
            'palette':colors, 'source_sha256':sha(source),
            'expected_triangles':asset['triangles']})


def render_collection(assets, out, meta):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    step = max(8, max(max(geometry.bounds(a.objects)[1][i]-geometry.bounds(a.objects)[0][i]
                            for i in (0,1)) for a in assets)+1.5)
    roots = {}
    pedestal = base.simple_mat('Catalog display base', 'D4CEC0')
    labels = base.simple_mat('Catalog label', '283B46')
    # Short props go in front so taller props cannot cover rear-row captions.
    display_assets = sorted(assets, key=lambda a: geometry.bounds(a.objects)[1][2])
    for index, asset in enumerate(display_assets):
        location = ((index%4-1.5)*step, (index//4-1)*step, 0)
        root = bpy.data.objects.new('Editable_'+asset.name, None)
        bpy.context.collection.objects.link(root)
        for obj in asset.objects:
            obj.parent = root
        root.location = location
        roots[asset.name] = root
        base.stage_cube('Display_'+asset.name, (step-.4,step-.4,.2),
                        (location[0],location[1],-.12), pedestal, .08)
        label = asset.name[:2]+' '+asset.name[3:].replace('_',' ')
        base.card_label(label,(location[0],location[1]-step/2+.4,.01),
                        min(.27,(step-.8)/max(1,len(label))/.65), labels)
    floor = base.stage_cube('Catalog floor',(300,300,.2),(0,0,-.35),
                            base.simple_mat('Catalog backdrop','253E49'),0)
    cam = base.camera_setup(scene)
    cam.location = (22,-55,65)
    base.aim(cam,(0,0,1))
    if scene.world is None:
        scene.world = bpy.data.worlds.new('Catalog World')
    base.lights_setup(scene)
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    displayed = [o for o in scene.objects if o.type in {'MESH','FONT'} and o!=floor]
    presentation.frame_objects(scene,cam,displayed,1.14)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/(meta['slug']+'-editable.blend')))
    for palette, colors in meta['palettes'].items():
        for key, code in zip(geometry.COLOR_KEYS,colors):
            mat = bpy.data.materials.get('GG_'+key)
            if mat:
                mat.diffuse_color = geometry.rgba(code)
                mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = geometry.rgba(code)
        base.render(scene,out/'images'/('collection-'+palette+'.png'),1600,1200)
    # Portraits are actual geometry renders with camera-space bounds fitting.
    for key,code in zip(geometry.COLOR_KEYS,meta['palettes']['Classic']):
        mat = bpy.data.materials.get('GG_'+key)
        if mat:
            mat.diffuse_color = geometry.rgba(code)
            mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = geometry.rgba(code)
    for index in (0,1):
        asset = assets[index]
        root = roots[asset.name]
        for obj in scene.objects:
            if obj.type in {'MESH','FONT'}:
                obj.hide_render = obj not in asset.objects and obj!=floor
        original = root.location.copy()
        root.location = (0,0,0)
        floor.location.z = -.12
        bpy.context.view_layer.update()
        lo,hi = map(Vector,geometry.bounds(asset.objects))
        center = (lo+hi)/2
        span = max(hi-lo)*2
        cam.location = center+Vector((span,-span*1.5,span))
        base.aim(cam,center)
        scene.render.resolution_x = scene.render.resolution_y = 900
        presentation.frame_objects(scene,cam,asset.objects,1.18)
        base.render(scene,out/'images'/('icon.png' if index==0 else 'detail.png'),900,900)
        root.location = original


def aggregate(out, manifest, meta):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    def empty(name, parent=None, location=(0,0,0)):
        obj=bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(obj)
        obj.parent=parent
        obj.location=location
        return obj
    root_name = meta['slug'].replace('-','_')+'_AuthoredOrigin'
    root = empty(root_name)
    step = max(8,max(max(a['size'][:2]) for a in manifest['assets'])+1.5)
    bank_width = step*4+4
    expected = {}
    for bank, palette in enumerate(meta['palettes']):
        image=bpy.data.images.load(str(out/'textures'/(palette+'_Palette.png')),check_existing=False)
        image.name=palette+'_Palette'
        image.pack()
        material=base.atlas_material(image)
        material.name=meta['slug']+'_'+palette
        group=empty(palette,root,((bank-1)*bank_width,0,0))
        for index,asset in enumerate(manifest['assets']):
            before=set(bpy.context.scene.objects)
            bpy.ops.import_scene.gltf(filepath=str(out/'glb'/(asset['id']+'.glb')))
            imported=set(bpy.context.scene.objects)-before
            prop=next(o for o in imported if o.parent is None)
            prop.name=palette+'__'+asset['id']
            prop.parent=group
            prop.location=((index%4-1.5)*step,(index//4-1)*step,0)
            for obj in imported:
                if obj.type=='MESH':
                    role=obj.name.split('__',1)[1]
                    obj.name=palette+'__'+asset['id']+'__'+role
                    obj.data.materials.clear()
                    obj.data.materials.append(material)
            expected[prop.name]={'asset':asset,'location':list(prop.location),'palette':palette}
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=root
    target=out/(meta['slug']+'-native.glb')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
                             export_extras=True,export_animations=False,export_yup=True)
    assert target.stat().st_size < 20_000_000
    with tempfile.TemporaryDirectory(prefix='catalog-native-') as temp:
        isolated=Path(temp)/target.name
        shutil.copyfile(target,isolated)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(isolated))
        bpy.context.view_layer.update()
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        assert len(meshes)==sum(a['mesh_count'] for a in manifest['assets'])*3
        assert sum(len(o.data.polygons) for o in meshes)==manifest['total_triangles']*3
        assert all(o.type in {'EMPTY','MESH'} for o in bpy.context.scene.objects)
        for name,entry in expected.items():
            prop=bpy.data.objects[name]
            assert (prop.location-Vector(entry['location'])).length<1e-4
            points=[prop.matrix_world.inverted()@obj.matrix_world@v.co
                    for obj in prop.children for v in obj.data.vertices]
            lo=[min(v[i] for v in points) for i in range(3)]
            hi=[max(v[i] for v in points) for i in range(3)]
            assert max(abs(lo[i]-entry['asset']['bounds_min'][i]) for i in range(3))<1e-4
            assert max(abs(hi[i]-entry['asset']['bounds_max'][i]) for i in range(3))<1e-4
        write(out/'evidence/native-roundtrip.json',{'status':'PASS','placements':36,
            'meshParts':len(meshes),'triangles':manifest['total_triangles']*3,
            'sha256':sha(target),'authoredRoot':root_name,
            'layoutStep':step,'bankWidth':bank_width,
            'scope':'Isolated Blender GLB reload; native Roblox publication remains separate'})


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--module',required=True)
    parser.add_argument('--out',required=True)
    opt=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    module_path=Path(opt.module).resolve()
    module=load_module(module_path)
    meta=module.META
    assert list(meta['palettes'])==['Classic','Warm','Twilight']
    assert all(len(v)==16 for v in meta['palettes'].values())
    out=Path(opt.out).resolve()
    for folder in ('glb','fbx','textures','source','images','evidence','studio-geometry'):
        (out/folder).mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    geometry.PALETTES['Teal']=meta['palettes']['Classic']
    base.PALETTES=meta['palettes']
    images=base.palette_images(out)
    atlas=base.atlas_material(images['Classic'])
    assets=sorted(module.build(),key=lambda a:a.name)
    assert len(assets)==12 and len({a.name for a in assets})==12
    bpy.context.view_layer.update()
    records=[base.export_asset(a,out,atlas) for a in assets]
    assert sum(a['mesh_count'] for a in records)<=16
    assert sum(a['triangles'] for a in records)<35000
    assert all(a['bounds_min'][2]>=-.005 and all(m['triangles']<8000 for m in a['meshes']) for a in records)
    for asset in records:
        z = asset['bounds_min'][2]
        documented_tip_clearance = (meta['slug'] == 'harvest-homestead' and
                                    asset['id'] == '09_Carrot_Bundle' and abs(z-.01) < .001)
        assert z <= .005 or documented_tip_clearance, f"Unsupported floor gap: {asset['id']} ({z})"
    manifest={'product':meta['title'],'slug':meta['slug'],'version':'1.0.0',
        'asset_count':12,'palette_variants':list(meta['palettes']),'palettes':meta['palettes'],
        'samples':meta['samples'],'assets':records,'runtime_scripts':0,
        'source_axes':{'up':'+Z','front':'-Y','unit':'one intended stud'},
        'total_triangles':sum(a['triangles'] for a in records),'source_module_sha256':sha(module_path),
        'native_publication':'PENDING','intendedPriceUSD':4.99}
    write(out/'manifest.json',manifest)
    render_collection(assets,out,meta)
    # Check every delivered file independently, including embedded palette RGB.
    report={'status':'WORKING','palettes':[],'exports':[]}
    for variant,colors in meta['palettes'].items():
        result,snapshot=validation.audit_palette(out/'textures'/(variant+'_Palette.png'),colors,variant)
        report['palettes'].append(result)
        if variant=='Classic':classic=snapshot
    with tempfile.TemporaryDirectory(prefix='catalog-roundtrip-') as temp:
        for asset in records:
            for kind in ('fbx','glb'):
                report['exports'].append(validation.validate_one(asset,kind,out,Path(temp),classic))
                write(out/'evidence/export-roundtrip.json',report)
    assert all(r['status']=='PASS' for r in report['palettes']+report['exports'])
    report['status']='PASS'
    write(out/'evidence/export-roundtrip.json',report)
    studio_geometry(out,manifest,meta['palettes']['Classic'])
    aggregate(out,manifest,meta)
    bpy.ops.wm.open_mainfile(filepath=str(out/'source'/(meta['slug']+'-editable.blend')))
    assert len([o for o in bpy.context.scene.objects if o.name.startswith('Editable_')]) == 12
    for key,code in zip(geometry.COLOR_KEYS,meta['palettes']['Classic']):
        mat=bpy.data.materials.get('GG_'+key)
        if mat:
            expected=geometry.rgba(code)
            actual=mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
            assert max(abs(a-b) for a,b in zip(actual,expected))<1e-5
    write(out/'evidence/source-reopen.json',{'status':'PASS','editableRoots':12,
        'classicMaterialColors':'PASS','file':meta['slug']+'-editable.blend',
        'sha256':sha(out/'source'/(meta['slug']+'-editable.blend'))})
    print('CATALOG_COMPLETE '+json.dumps({'slug':meta['slug'],'models':12,'imports':24,'triangles':manifest['total_triangles']}),flush=True)


if __name__=='__main__':
    main()
