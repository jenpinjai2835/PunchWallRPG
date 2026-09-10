"""Package verified catalog exports and truthful native Store draft copy."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verified_members(pack, manifest):
    """Bind every prerequisite to the current payload before creating a ZIP."""
    reports = {}
    for name in ('export-roundtrip', 'native-roundtrip', 'source-reopen'):
        report = json.loads((pack/'evidence'/(name+'.json')).read_text())
        assert report['status'] == 'PASS', f'{name} has not passed'
        reports[name] = report
    assets = manifest['assets']
    assert len(assets) == 12 and len({a['id'] for a in assets}) == 12
    expected = {(a['id'], kind) for a in assets for kind in ('fbx', 'glb')}
    exports = reports['export-roundtrip']['exports']
    assert len(exports) == 24 and {(r['id'], r['format']) for r in exports} == expected
    members = []
    for result in exports:
        assert result['status'] == 'PASS' and not result['errors']
        assert all(c['pass'] for c in result['checks'].values())
        file = pack/result['format']/(result['id']+'.'+result['format'])
        assert sha(file) == result['sha256'].lower(), f'Stale export evidence: {file.name}'
        members.append(file)
    palettes = reports['export-roundtrip']['palettes']
    assert len(palettes) == 3 and {p['variant'] for p in palettes} == set(manifest['palettes'])
    for result in palettes:
        file = pack/'textures'/(result['variant']+'_Palette.png')
        assert result['status'] == 'PASS' and sha(file) == result['sha256'].lower(), 'Stale palette evidence'
        expected_rgb = [[int(code[i:i+2], 16) for i in (0, 2, 4)] for code in manifest['palettes'][result['variant']]]
        assert result['reference_rgb'] == expected_rgb
        members.append(file)
    native = pack/(manifest['slug']+'-native.glb')
    source = pack/'source'/(manifest['slug']+'-editable.blend')
    assert sha(native) == reports['native-roundtrip']['sha256'].lower(), 'Stale aggregate evidence'
    assert sha(source) == reports['source-reopen']['sha256'].lower(), 'Stale Blender source evidence'
    module = Path(__file__).resolve().parent/'packs'/(manifest['slug'].replace('-', '_')+'.py')
    assert sha(module) == manifest['source_module_sha256'], 'Source changed after build'
    members.extend([native, source])
    for name in ('collection-Classic', 'collection-Warm', 'collection-Twilight', 'icon', 'detail'):
        file = pack/'images'/(name+'.png')
        raw = file.read_bytes()
        assert raw[:8] == b'\x89PNG\r\n\x1a\n' and raw[12:16] == b'IHDR', f'Missing or invalid image: {name}'
        width, height = struct.unpack('>II', raw[16:24])
        assert (width, height) == ((1600, 1200) if name.startswith('collection') else (900, 900))
        members.append(file)
    members.extend(pack/'evidence'/(name+'.json') for name in reports)
    members.extend([pack/'manifest.json', pack/'README.md'])
    assert len(members) == 39 and len(set(members)) == 39
    return members


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack')
    opt=parser.parse_args()
    pack=Path(opt.pack).resolve()
    manifest=json.loads((pack/'manifest.json').read_text())
    title=manifest['product']
    names=[a['id'][3:].replace('_',' ') for a in manifest['assets']]
    roles = 'Separate named roles on selected props.' if any(a['mesh_count'] > 1 for a in manifest['assets']) else 'One joined mesh per prop.'
    description=(f"12 original low-poly props for {title}. Classic, Warm and Twilight palettes: "
        "12 unique base models, 36 palette variants. Visual models only; no gameplay scripts, "
        "animations or functional systems. Includes "+', '.join(names)+'. '
        "Named models with authored ground pivots. "+roles+" Lighting depends on your experience.")
    assert len(description)<=1000
    (pack/'STORE-DRAFT.md').write_text(f'# {title}\n\nIntended price: US$4.99. Publication PENDING.\n\n'
        f'{description}\n\nThe native Store listing must be verified after uploading persistent assets. '
        'The local ZIP below is a separate delivery and is not automatically included in a Creator Store purchase.\n',encoding='utf-8')
    (pack/'README.md').write_text(f'# {title}\n\n12 original base models; three palettes. '
        f'{manifest["total_triangles"]:,} triangles in one complete palette.\n\n'
        'FBX and GLB files are provided for each prop. The aggregate native GLB contains all three palettes. '
        'Editable Blender source, PNG palettes, actual renders, and validation reports are included.\n\n'
        'Source: Z up, front -Y; one unit is intended as one Roblox stud. '
        'Import through Studio 3D Importer using Studs and verify scale. Imported geometry may be unanchored; '
        'anchor static decor and configure collision for your experience. '+roles+'\n\n'
        'No code, gameplay mechanics, animation or third-party model dependencies are included. '
        'Do not treat local editable-mesh previews as persistent uploaded models.\n',encoding='utf-8')
    members=verified_members(pack, manifest)
    archive=pack/(manifest['slug']+'-source-and-exports.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for file in sorted(members):
            output.write(file,file.relative_to(pack).as_posix())
    with zipfile.ZipFile(archive) as check:
        assert check.testzip() is None
        assert len(check.namelist())==len(members)
        for file in members:
            assert hashlib.sha256(check.read(file.relative_to(pack).as_posix())).digest()==hashlib.sha256(file.read_bytes()).digest()
    report={'status':'PASS','archive':archive.name,'members':len(members),'bytes':archive.stat().st_size,
            'sha256':sha(archive),'listing':'PENDING_NATIVE_PUBLICATION',
            'payload_sha256':{file.relative_to(pack).as_posix():sha(file) for file in members}}
    (pack/'evidence/package-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))


if __name__=='__main__':
    main()
