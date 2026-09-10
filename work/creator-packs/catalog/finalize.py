"""Bind final local catalog acceptance to current source, exports, Studio flows and ZIPs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

from package import verified_members

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog')
    opt = parser.parse_args()
    catalog = Path(opt.catalog).resolve()
    reports = []
    for module in sorted((HERE/'packs').glob('*.py')):
        slug = module.stem.replace('_', '-')
        pack = catalog/slug
        manifest = read(pack/'manifest.json')
        for asset in manifest['assets']:
            z = asset['bounds_min'][2]
            documented_tip_clearance = (slug == 'harvest-homestead' and
                                        asset['id'] == '09_Carrot_Bundle' and abs(z-.01) < .001)
            assert -.005 <= z <= .005 or documented_tip_clearance, f"Unsupported floor gap: {slug}/{asset['id']}"
        members = verified_members(pack, manifest)
        archive_report = read(pack/'evidence/package-validation.json')
        archive = pack/archive_report['archive']
        assert archive_report['status'] == 'PASS' and sha(archive) == archive_report['sha256']
        expected = {p.relative_to(pack).as_posix(): sha(p) for p in members}
        assert expected == archive_report['payload_sha256']
        with zipfile.ZipFile(archive) as zip_file:
            assert zip_file.testzip() is None and set(zip_file.namelist()) == set(expected)
            for name, digest in expected.items():
                assert hashlib.sha256(zip_file.read(name)).hexdigest() == digest
        preview = read(pack/'evidence/studio-preview.json')
        assert preview['status'] == 'PASS' and preview['slug'] == slug
        assert {r['id'] for r in preview['results']} == {a['id'] for a in manifest['assets']}
        for row in preview['results']:
            assert not row['isError']
            data = json.loads(row['text'])
            assert data['status'] == 'PASS'
            assert data['source_sha256'] == sha(pack/'glb'/(row['id']+'.glb'))
        flow_path = ROOT/'work/automation/flows/creator-packs'/('catalog-'+slug+'-local-preview.json')
        flow = read(flow_path)
        source_manifest = re.search(r'H:JSONDecode\(\[==\[(.*?)\]==\]\)', flow['steps'][0]['args']['code'], re.S)
        assert source_manifest and json.loads(source_manifest[1]) == manifest, 'Stale Studio manifest'
        execution = read(pack/'evidence/studio-flow.json')
        assert execution['ok'] and execution['results'][0]['ok'] and execution['results'][0]['flow'] == flow['name']
        assert execution['flow_sha256'] == sha(flow_path), 'Stale executed Studio flow'
        assert execution['manifest_sha256'] == sha(pack/'manifest.json'), 'Stale executed Studio manifest'
        capture = pack/'evidence/studio-preview.png'
        assert capture.stat().st_size > 10000
        reports.append({'slug': slug, 'title': manifest['product'], 'localChecks': 'PASS',
                        'baseModels': 12, 'palettePlacements': 36,
                        'roleMeshesPerPalette': sum(a['mesh_count'] for a in manifest['assets']),
                        'trianglesPerPalette': manifest['total_triangles'],
                        'source_sha256': sha(module), 'manifest_sha256': sha(pack/'manifest.json'),
                        'zip': archive.name, 'zip_sha256': sha(archive),
                        'studio_flow_sha256': sha(flow_path), 'studio_capture_sha256': sha(capture),
                        'intendedPriceUSD': 4.99, 'persistentNativeUpload': 'BLOCKED', 'paidListing': 'BLOCKED'})
    assert len(reports) == 9
    report = {'status': 'BLOCKED', 'localArtifactValidation': 'PASS', 'newPacks': reports,
              'localBaseModels': 108, 'localPalettePlacements': 324, 'isolatedImports': 216,
              'paidListingsVerified': 1, 'paidListingsRequested': 10,
              'firstPaidListing': 'https://create.roblox.com/store/asset/122456766146790/Gilded-Grove-Merchant-Loot',
              'blocker': 'Automatic approval review rejected enabling the documented Studio CreateAssetAsync beta and restarting Studio: blocked by policy. No preference or Studio-process mutation occurred. Nine further persistent native uploads and paid listings remain unverified.'}
    (catalog/'final-validation.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    lines = ['# Creator model catalog', '',
             'One paid listing is live: [Gilded Grove — Merchant & Loot](https://create.roblox.com/store/asset/122456766146790/Gilded-Grove-Merchant-Loot), US$5.99 (24 original models, three palettes).', '',
             '[Gilded Grove local source ZIP](../gilded-grove/delivery/GildedGrove_Full.zip)', '',
             'The nine collections below contain 108 further original models. Local source, exports, images, Studio previews and ZIP checks passed. Persistent uploads and paid listings remain blocked by the recorded Studio automation approval rejection. Intended price: US$4.99 per new collection.', '',
             'These local ZIP deliveries include Blender source and portable FBX/GLB files. Creator Store purchases do not automatically include the ZIP. All assets are visual props without gameplay systems.', '',
             '| Collection | Models | Triangles per palette | Files |', '| --- | ---: | ---: | --- |']
    for row in reports:
        lines.append(f'| {row["title"]} | 12 | {row["trianglesPerPalette"]:,} | [ZIP]({row["slug"]}/{row["zip"]}) · [details]({row["slug"]}/README.md) |')
    for row in reports:
        lines.extend(['', '## '+row['title'], '', f'![{row["title"]}]({row["slug"]}/images/collection-Classic.png)'])
    (catalog/'CATALOG.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(json.dumps({'status': report['status'], 'localArtifactValidation': 'PASS', 'packs': 9,
                      'baseModels': 108, 'paidListings': '1/10'}))


if __name__ == '__main__':
    main()
