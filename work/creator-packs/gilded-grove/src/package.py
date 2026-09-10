"""Package only allowlisted buyer assets, then verify ZIP contents and checksums.

python package.py --package BUILT_OUTPUT --source SOURCE_PRODUCT --out ZIP_DIR
SOURCE_PRODUCT contains README.md and src/. No Blender or third-party modules
are needed. Packaging verifies file delivery, not Roblox import compatibility.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
import zipfile


ASSET_IDS = (
    "01_Wayfarer_Chest", "02_Royal_Chest", "03_Shipping_Crate", "04_Open_Crate",
    "05_Merchant_Barrel", "06_Coin_Coffer", "07_Display_Tray", "08_Treasure_Cart",
    "09_Coin_Stack", "10_Coin_Pouch", "11_Cut_Gem", "12_Crystal_Cluster",
    "13_Ore_Node", "14_Alchemy_Bottle", "15_Reward_Medallion", "16_Upgrade_Hammer",
    "17_Merchant_Stall", "18_Upgrade_Station", "19_Reward_Pedestal",
    "20_Hanging_Shop_Sign", "21_Lantern_Post", "22_Display_Shelf",
    "23_Market_Fence", "24_Portal_Arch",
)
SAMPLE_IDS = ("03_Shipping_Crate", "09_Coin_Stack", "12_Crystal_Cluster")
PALETTES = ("Teal", "Ember", "Amethyst")
SCRIPTS = (
    "geometry.py", "containers.py", "pickups.py", "stalls.py", "build.py",
    "presentation.py", "validate_exports.py",
)
SCENES = ("GildedGrove_Editable.blend", "GildedGrove_MerchantScene.blend")
COLLECTION_IMAGES = (
    "00_Cover_Teal.png", "01_Collection.png", "02_Palette_Ember.png",
    "02_Palette_Amethyst.png",
)
LEDGER = "SHA256SUMS.txt"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_file(root: Path, relative: str) -> bytes:
    """Read one exact input and reject symlinks that escape the selected root."""
    name = PurePosixPath(relative)
    if name.is_absolute() or ".." in name.parts:
        raise ValueError(f"Unsafe input path: {relative}")
    path = (root / relative).resolve(strict=True)
    if not path.is_relative_to(root) or not path.is_file():
        raise ValueError(f"Input is not a file inside its root: {relative}")
    data = path.read_bytes()
    if not data:
        raise ValueError(f"Empty required file: {relative}")
    return data


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def asset_payload(package: Path, ids: tuple[str, ...]) -> dict[str, bytes]:
    paths = [f"{ext}/{name}.{ext}" for name in ids for ext in ("fbx", "glb")]
    paths += [f"images/{name}.png" for name in ids]
    paths += [f"textures/{name}_Palette.png" for name in PALETTES]
    return {name: read_file(package, name) for name in paths}


def sample_guide() -> bytes:
    return """# Gilded Grove — three-model sample

Included: 03_Shipping_Crate, 09_Coin_Stack, and 12_Crystal_Cluster.
Each model has one FBX, one GLB, and one portrait. The two formats contain the
same geometry. Teal, Ember, and Amethyst are palette variants, not extra models.
This sample contains no other models, full-pack renders, Blender scenes, or
generator source. It contains no shop, economy, animation, or gameplay scripts.

Unzip all files, then open a separate Roblox Studio test place. Choose File >
Import and start with one FBX. Check warnings, orientation, size, and textures.
For stationary decoration, enable Anchored. Keep Import Only As Model enabled
when retaining separate parts. You may disable Upload to Roblox for a local
trial. Source coordinates are Z up, -Y front; one unit is intended as one stud.
Compare dimensions with manifest.json. Native File > Import compatibility has
not been verified; a Studio geometry preview is a separate check. No uploaded
Roblox asset IDs or .rbxm files are included. All six sample export files have
passed Blender roundtrip import checks. Performance depends on your scene.

See https://create.roblox.com/docs/studio/importer for current import controls.
SHA256SUMS.txt records the checksum of every other file in this ZIP.

## ภาษาไทย

ตัวอย่างนี้มีเฉพาะ Shipping Crate, Coin Stack และ Crystal Cluster รวม 3 โมเดล
แต่ละชิ้นมี FBX, GLB และภาพตัวอย่าง พร้อมพื้นผิว 3 ชุดสีซึ่งไม่นับเป็นโมเดลเพิ่ม
ไม่มี source ของแพ็กเต็ม ระบบร้านค้า เงิน animation หรือสคริปต์เกม
แตกไฟล์ให้ครบ แล้วลอง File > Import ในฉากทดสอบแยก ตรวจคำเตือน ขนาด สี
ตำแหน่ง และการชนก่อนใช้จริง ไฟล์ผ่านการนำเข้ากลับใน Blender แล้ว แต่ยังไม่ผ่าน
การตรวจเมนู File > Import ใน Studio และไม่มี asset ID หรือไฟล์ .rbxm ให้
""".encode("utf-8")


def collect(package: Path, source: Path) -> dict[str, dict[str, bytes]]:
    manifest_data = read_file(package, "manifest.json")
    manifest = json.loads(manifest_data)
    assets = manifest.get("assets", [])
    actual_ids = [asset.get("id") for asset in assets]
    if len(actual_ids) != len(ASSET_IDS) or set(actual_ids) != set(ASSET_IDS):
        raise ValueError("Manifest must contain exactly the 24 allowlisted asset IDs")
    if manifest.get("asset_count") != 24:
        raise ValueError("Manifest asset_count must be 24")
    if set(manifest.get("samples", [])) != set(SAMPLE_IDS):
        raise ValueError("Manifest sample IDs do not match the three selected models")
    if manifest.get("palette_variants") != list(PALETTES):
        raise ValueError("Manifest palette list must be Teal, Ember, Amethyst")

    full = asset_payload(package, ASSET_IDS)
    full["manifest.json"] = manifest_data
    full["README.md"] = read_file(source, "README.md")
    for filename in SCENES:
        full[f"source/{filename}"] = read_file(package, f"source/{filename}")
    for filename in COLLECTION_IMAGES:
        full[f"images/{filename}"] = read_file(package, f"images/{filename}")
    for filename in SCRIPTS:
        full[f"source/scripts/{filename}"] = read_file(source, f"src/{filename}")

    samples = asset_payload(package, SAMPLE_IDS)
    sample_assets = [asset for asset in assets if asset["id"] in SAMPLE_IDS]
    # A new manifest avoids leaking full-pack statistics or unrelated metadata.
    sample_manifest = {
        "product": "Gilded Grove - Merchant & Loot (three-model sample)",
        "version": manifest.get("version"),
        "asset_count": 3,
        "blender_version": manifest.get("blender_version"),
        "source_axes": manifest.get("source_axes"),
        "palette_variants": list(PALETTES),
        "samples": list(SAMPLE_IDS),
        "runtime_scripts": 0,
        "external_mesh_dependencies": 0,
        "total_triangles": sum(asset["triangles"] for asset in sample_assets),
        "assets": sample_assets,
        "delivery_scope": "Three model exports only; no full-pack source or scenes",
        "roblox_file_import_verified": False,
    }
    samples["manifest.json"] = json_bytes(sample_manifest)
    samples["README.md"] = sample_guide()
    assert_counts(full, 24, 28, 2, len(SCRIPTS))
    assert_counts(samples, 3, 3, 0, 0)
    return {"GildedGrove_Full.zip": full, "GildedGrove_Samples.zip": samples}


def assert_counts(payload: dict[str, bytes], assets: int, images: int,
                  blends: int, scripts: int) -> None:
    expected = {"fbx/": assets, "glb/": assets, "images/": images, "textures/": 3}
    for prefix, count in expected.items():
        if sum(name.startswith(prefix) for name in payload) != count:
            raise ValueError(f"Wrong number of {prefix} files")
    if sum(name.endswith(".blend") for name in payload) != blends:
        raise ValueError("Wrong number of editable scenes")
    if sum(name.endswith(".py") for name in payload) != scripts:
        raise ValueError("Wrong number of source scripts")
    total = assets * 2 + images + 3 + blends + scripts + 2
    if len(payload) != total:
        raise ValueError("Unexpected files in explicit payload")


def add_ledger(payload: dict[str, bytes]) -> dict[str, bytes]:
    if LEDGER in payload:
        raise ValueError("Checksum ledger must be generated, never copied")
    result = dict(payload)
    result[LEDGER] = "".join(
        f"{digest(data)}  {name}\n" for name, data in sorted(payload.items())
    ).encode("utf-8")
    return result


def verify_zip(path: Path, expected: dict[str, bytes]) -> dict[str, object]:
    with zipfile.ZipFile(path, "r") as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(expected):
            raise ValueError("Archive file names/count do not match the allowlist")
        bad = archive.testzip()
        if bad is not None:
            raise ValueError(f"CRC verification failed: {bad}")
        for name, data in expected.items():
            if archive.read(name) != data:
                raise ValueError(f"Archive bytes differ from source: {name}")
        lines = archive.read(LEDGER).decode("utf-8").splitlines()
        recorded = dict(line.split("  ", 1)[::-1] for line in lines)
        if len(recorded) != len(lines) or set(recorded) != set(expected) - {LEDGER}:
            raise ValueError("Checksum ledger does not cover the exact payload")
        for name, sha256 in recorded.items():
            if digest(archive.read(name)) != sha256:
                raise ValueError(f"Checksum mismatch: {name}")
    return {
        "file_count": len(expected), "payload_files": len(expected) - 1,
        "uncompressed_bytes": sum(len(data) for data in expected.values()),
        "crc": "PASS", "exact_bytes": "PASS", "sha256_ledger": "PASS",
    }


def write_zip(path: Path, payload: dict[str, bytes]) -> dict[str, object]:
    content = add_ledger(payload)
    with tempfile.NamedTemporaryFile(dir=path.parent, suffix=".zip.tmp", delete=False) as temp:
        temporary = Path(temp.name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=6) as archive:
            for name, data in sorted(content.items()):
                entry = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o644 << 16
                archive.writestr(entry, data)
        result = verify_zip(temporary, content)
        temporary.replace(path)
        result.update({"archive": path.name, "bytes": path.stat().st_size,
                       "sha256": digest(path.read_bytes())})
        return result
    finally:
        if temporary.exists():
            temporary.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path, help="Built product output")
    parser.add_argument("--source", required=True, type=Path, help="Product README and src/")
    parser.add_argument("--out", required=True, type=Path, help="Destination for two ZIPs")
    args = parser.parse_args()
    package, source = args.package.resolve(strict=True), args.source.resolve(strict=True)
    bundles = collect(package, source)  # Validate all inputs before writing an archive.
    destination = args.out.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    reports = [write_zip(destination / name, payload) for name, payload in bundles.items()]
    report = {"product": "Gilded Grove - Merchant & Loot", "status": "PASS",
              "verification_scope": "ZIP allowlists, counts, CRC, bytes, SHA256 only",
              "archives": reports}
    (destination / "package-verification.json").write_bytes(json_bytes(report))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
