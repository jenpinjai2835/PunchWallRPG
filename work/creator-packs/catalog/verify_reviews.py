"""Verify all independent reviewer handoffs still match the final nine deliveries."""
import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog')
    catalog = Path(parser.parse_args().catalog).resolve()
    reviews = catalog/'reviews'
    source = Path(__file__).resolve().parent/'packs'
    rows = []
    for group in ('natural', 'fantasy', 'modern'):
        handoff_file = reviews/(group+'-final-handoff.json')
        handoff = read(handoff_file)
        assert handoff['status'] in {'PASS', 'READY_FOR_COORDINATOR_LOCAL_HANDOFF'}
        for entry in handoff['packs']:
            slug = entry['slug']
            pack = catalog/slug
            archive = read(pack/'evidence/package-validation.json')
            source_hash = entry.get('source_sha256', entry.get('source_module_sha256'))
            if group == 'fantasy':
                # This reviewer's "source" field names the editable Blend file.
                assert source_hash == sha(pack/'source'/(slug+'-editable.blend'))
                assert entry['manifest_sha256'] == sha(pack/'manifest.json')
                source_hash = read(pack/'manifest.json')['source_module_sha256']
            assert source_hash == sha(source/(slug.replace('-', '_')+'.py'))
            archive_hash = entry['zip']['sha256'] if group == 'modern' else entry['archive_sha256']
            assert archive_hash == archive['sha256'] == sha(pack/archive['archive'])
            if group == 'natural':
                images = entry['image_sha256']
            elif group == 'fantasy':
                images = {PureWindowsPath(i['file']).name: i['sha256'] for i in entry['images']}
            else:
                artifact_file = reviews/PureWindowsPath(entry['artifact_report']).name
                assert sha(artifact_file) == entry['artifact_report_sha256']
                artifact = read(artifact_file)
                assert all(image['visual_review'] == 'PASS' for image in artifact['images'].values())
                images = {name+'.png': image['sha256'] for name, image in artifact['images'].items()}
            assert len(images) == 5
            for name, digest in images.items():
                assert sha(pack/'images'/name) == digest, f'Stale reviewed image: {slug}/{name}'
            rows.append({'slug': slug, 'status': 'PASS', 'reviewerGroup': group,
                         'handoff': handoff_file.name, 'handoff_sha256': sha(handoff_file),
                         'source_sha256': source_hash, 'zip_sha256': archive_hash,
                         'reviewedImages': images})
    assert len(rows) == 9 and len({r['slug'] for r in rows}) == 9
    report = {'status': 'PASS', 'packs': rows, 'imagesInspectedAndBound': 45,
              'scope': 'Independent local artifact review handoffs; paid native publication remains separate'}
    (reviews/'review-index.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'status': 'PASS', 'packs': 9, 'reviewedImages': 45}))


if __name__ == '__main__':
    main()
