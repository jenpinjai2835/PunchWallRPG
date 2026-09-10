"""Narrow RBXM transform patch; all non-target chunks copied byte-for-byte.

No Roblox/network APIs; Python standard library only. Format references:
https://dom.rojo.space/binary.html (rbx-dom implementation documentation).
Unknown properties, shared strings and compression remain opaque and preserved.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]


def string(data, offset):
    length = u32(data, offset)
    end = offset + 4 + length
    require(end <= len(data), 'String exceeds chunk')
    return data[offset + 4:end], end


def lz4_block(data, expected):
    """Decode raw LZ4 block with strict input/output bounds; no frame header."""
    result = bytearray()
    pos = 0
    while pos < len(data):
        token = data[pos]
        pos += 1
        literals = token >> 4
        if literals == 15:
            while True:
                require(pos < len(data), 'Truncated LZ4 literal length')
                extra = data[pos]
                pos += 1
                literals += extra
                if extra != 255:
                    break
        require(pos + literals <= len(data), 'Truncated LZ4 literal')
        result.extend(data[pos:pos + literals])
        pos += literals
        require(len(result) <= expected, 'LZ4 output overflow')
        if pos == len(data):
            break
        require(pos + 2 <= len(data), 'Truncated LZ4 offset')
        distance = struct.unpack_from('<H', data, pos)[0]
        pos += 2
        require(0 < distance <= len(result), 'Invalid LZ4 backreference')
        length = token & 15
        if length == 15:
            while True:
                require(pos < len(data), 'Truncated LZ4 match length')
                extra = data[pos]
                pos += 1
                length += extra
                if extra != 255:
                    break
        length += 4
        require(len(result) + length <= expected, 'LZ4 match overflow')
        for _ in range(length):
            result.append(result[-distance])
    require(len(result) == expected, 'Incorrect LZ4 output size')
    return bytes(result)


def chunks(data):
    require(data[:16] == b'<roblox!\x89\xff\r\n\x1a\n\0\0', 'Expected binary Roblox version 0')
    out = []
    pos = 32
    while pos < len(data):
        require(pos + 16 <= len(data), 'Truncated chunk header')
        name, compressed, length, reserved = struct.unpack_from('<4sIII', data, pos)
        end = pos + 16 + (compressed or length)
        require(end <= len(data), 'Truncated chunk')
        body = data[pos + 16:end]
        # Only decompress headers/property values we actually inspect. Preserve all
        # other chunks verbatim, including potentially unknown compressed formats.
        decoded = None
        if name in (b'INST', b'PROP'):
            if compressed:
                require(body[:4] != bytes.fromhex('28b52ffd'), 'ZSTD target needs supported decoder')
                decoded = lz4_block(body, length)
            else:
                decoded = body
        out.append(dict(name=name, offset=pos, raw=data[pos:end], data=decoded,
                        length=length, compressed=compressed, reserved=reserved))
        pos = end
    require(out[-1]['name'] == b'END\0' and out[-1]['raw'][16:] == b'</roblox>', 'Missing END chunk')
    return out


def prop_header(chunk):
    data = chunk['data']
    class_id = u32(data, 0)
    name, pos = string(data, 4)
    return class_id, name.decode('utf-8'), data[pos], pos + 1


def uint_array(data, count):
    require(len(data) == count * 4, 'Incorrect interleaved uint array size')
    return [int.from_bytes(bytes(data[row + column * count] for column in range(4)), 'big')
            for row in range(count)]


def float_array(data, count):
    return [struct.unpack('<f', struct.pack('<I', (v >> 1) | ((v & 1) << 31)))[0]
            for v in uint_array(data, count)]


def encode_float_array(values):
    rows = []
    for value in values:
        require(math.isfinite(value), 'Nonfinite transform')
        word = struct.unpack('<I', struct.pack('<f', value))[0]
        rows.append((((word << 1) & 0xffffffff) | (word >> 31)).to_bytes(4, 'big'))
    return bytes(row[column] for column in range(4) for row in rows)


def decode_cframes(data, count):
    rotations = []
    cursor = 0
    for _ in range(count):
        code = data[cursor]
        cursor += 1
        if code == 0:
            rotation = list(struct.unpack_from('<9f', data, cursor))
            cursor += 36
        elif code == 2:
            rotation = [1, 0, 0, 0, 1, 0, 0, 0, 1]
        elif code == 0x14:
            rotation = [-1, 0, 0, 0, 1, 0, 0, 0, -1]
        else:
            raise ValueError(f'Unneeded rotation encoding {code}; refusing to guess')
        rotations.append(rotation)
    rotation_end = cursor
    require(len(data) == cursor + 12 * count, 'Unexpected CFrame payload size')
    axes = [float_array(data[cursor + axis * count * 4:cursor + (axis + 1) * count * 4], count)
            for axis in range(3)]
    return [[axes[axis][index] for axis in range(3)] + rotations[index]
            for index in range(count)], rotation_end


def encode_cframes(values):
    # Full float matrices avoid special-case rotation rounding.
    rotations = b''.join(b'\0' + struct.pack('<9f', *value[3:]) for value in values)
    positions = b''.join(encode_float_array([value[axis] for value in values]) for axis in range(3))
    return rotations + positions


def content_uris(data, count):
    types = uint_array(data[:count * 4], count)
    require(set(types) == {1}, 'Expected every MeshContent to be a URI')
    cursor = count * 4
    require(u32(data, cursor) == count, 'MeshContent URI count mismatch')
    cursor += 4
    result = []
    for _ in range(count):
        value, cursor = string(data, cursor)
        result.append(value.decode('utf-8'))
    require(data[cursor:] == b'\0' * 8, 'Unexpected MeshContent object references')
    return result


def inventory(items):
    classes = {}
    props = {}
    for index, chunk in enumerate(items):
        if chunk['name'] == b'INST':
            class_id = u32(chunk['data'], 0)
            name, cursor = string(chunk['data'], 4)
            require(chunk['data'][cursor] == 0, 'Unexpected service class')
            classes[class_id] = (name.decode('utf-8'), u32(chunk['data'], cursor + 1))
        elif chunk['name'] == b'PROP':
            class_id, name, kind, start = prop_header(chunk)
            key = (class_id, name)
            require(key not in props, f'Duplicate property {key}')
            props[key] = (index, kind, start)
    return classes, props


def transform_error(left, right):
    return max(abs(a - b) for row_a, row_b in zip(left, right) for a, b in zip(row_a, row_b))


def run(args):
    source = Path(args.input).resolve()
    data = source.read_bytes()
    items = chunks(data)
    classes, props = inventory(items)
    report = {'input': str(source), 'inputSHA256': sha(data), 'inputBytes': len(data),
              'classes': classes, 'chunks': len(items), 'properties': []}
    for (class_id, name), (index, kind, start) in props.items():
        report['properties'].append({'class': classes[class_id][0], 'name': name,
                                     'type': hex(kind), 'chunk': index,
                                     'payloadBytes': len(items[index]['data']) - start})
    if not args.mapping:
        print(json.dumps(report, indent=2))
        return
    require(args.output and args.report, 'Patch requires --output and --report')
    output, report_path = Path(args.output).resolve(), Path(args.report).resolve()
    require(len({source, output, report_path, Path(args.mapping).resolve()}) == 4, 'Paths must be distinct')
    raw_mapping = Path(args.mapping).read_bytes()
    mapping = json.loads(raw_mapping.decode('utf-8-sig'))
    if 'text' in mapping:
        require(mapping.get('isError') is False, 'Studio mapping reports an error')
        mapping = json.loads(mapping['text'])
    require(mapping.get('status') == 'PREPARED', 'Expected PREPARED Studio mapping')
    parts = mapping['parts']
    by_mesh = {part['meshId']: part for part in parts}
    require(len(by_mesh) == len(parts) == 99, 'Need exactly 99 unique mapped mesh IDs')
    mesh_classes = [key for key, value in classes.items() if value[0] == 'MeshPart']
    require(len(mesh_classes) == 1, 'Expected one MeshPart class')
    cls = mesh_classes[0]
    count = classes[cls][1]
    require(count == 99, 'Expected 99 source MeshParts')
    if (cls, 'MeshId') in props:
        index, kind, start = props[(cls, 'MeshId')]
        require(kind == 1, 'Expected serialized MeshId string type')
        mesh_ids = []
        cursor = start
        for _ in range(count):
            value, cursor = string(items[index]['data'], cursor)
            mesh_ids.append(value.decode('utf-8'))
        require(cursor == len(items[index]['data']), 'Trailing MeshId bytes')
    else:
        index, kind, start = props[(cls, 'MeshContent')]
        require(kind == 0x22, 'Expected current MeshContent encoding')
        mesh_ids = content_uris(items[index]['data'][start:], count)
    require(len(set(mesh_ids)) == count and set(mesh_ids) == set(by_mesh), 'Source/mapping MeshIds differ')
    replacements = {}
    errors = {}
    for property_name, map_key in [('CFrame', 'cframe'), ('PivotOffset', 'pivotOffset')]:
        index, kind, start = props[(cls, property_name)]
        require(kind == 0x10, f'Unexpected {property_name} type')
        original_values, rotation_end = decode_cframes(items[index]['data'][start:], count)
        # Bit-perfect no-op round-trip is checked for actual positions and explicit matrices.
        require(encode_cframes(original_values) == items[index]['data'][start:],
                f'Original {property_name} encoding not exact full-matrix roundtrip')
        target = [by_mesh[mesh_id][map_key] for mesh_id in mesh_ids]
        require(all(len(value) == 12 for value in target), 'Need 12 CFrame components')
        encoded = encode_cframes(target)
        decoded, _ = decode_cframes(encoded, count)
        error = transform_error(decoded, target)
        require(error < 1e-6, f'{property_name} float encoding exceeds tolerance')
        # Scope is translation-only. All 99 rotation matrices must remain byte exact.
        require(encoded[:rotation_end] == items[index]['data'][start:start + rotation_end],
                f'{property_name} mapping unexpectedly changes orientation')
        body = items[index]['data'][:start] + encoded
        replacements[index] = struct.pack('<4sIII', b'PROP', 0, len(body), items[index]['reserved']) + body
        errors[property_name] = {'maxFloat32QuantizationError': error,
                                 'maxChange': transform_error(original_values, target),
                                 'rotationsByteIdentical': True, 'values': count}
    result = data[:32] + b''.join(replacements.get(index, chunk['raw']) for index, chunk in enumerate(items))
    after_items = chunks(result)
    require(len(after_items) == len(items), 'Chunk count changed')
    preserved = []
    changed = []
    for index, (before, after) in enumerate(zip(items, after_items)):
        if index in replacements:
            require(after['raw'] == replacements[index], 'Target chunk output mismatch')
            changed.append(index)
        else:
            require(before['raw'] == after['raw'], f'Non-target chunk {index} changed')
            preserved.append(index)
    require(data[:32] == result[:32], 'Header changed')
    # Re-inventory rebuilt bytes and decode final transforms, not just buffers.
    _, after_props = inventory(after_items)
    for property_name, map_key in [('CFrame', 'cframe'), ('PivotOffset', 'pivotOffset')]:
        index, kind, start = after_props[(cls, property_name)]
        values, _ = decode_cframes(after_items[index]['data'][start:], count)
        target = [by_mesh[mesh_id][map_key] for mesh_id in mesh_ids]
        require(transform_error(values, target) < 1e-6, 'Reparsed output differs from Studio mapping')
    report.update({'status': 'BINARY_PRESERVATION_PASS_NATIVE_RELOAD_REQUIRED',
                   'mappingSHA256': sha(raw_mapping), 'output': str(output),
                   'outputSHA256': sha(result), 'outputBytes': len(result),
                   'headerByteIdentical': True, 'nonTargetChunksByteIdentical': len(preserved),
                   'changedChunkIndexes': changed, 'matchedUniqueMeshIds': count,
                   'targetProperties': errors,
                   'chunkLedger': [{'index': index, 'name': chunk['name'].decode('ascii').rstrip('\0'),
                                    'beforeSHA256': sha(chunk['raw']),
                                    'afterSHA256': sha(after_items[index]['raw']),
                                    'preserved': index not in replacements}
                                   for index, chunk in enumerate(items)]})
    output.write_bytes(result)
    require(output.read_bytes() == result, 'Disk output differs')
    report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items() if key not in ('properties', 'chunkLedger')}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True)
    parser.add_argument('--mapping')
    parser.add_argument('--output')
    parser.add_argument('--report')
    run(parser.parse_args())
