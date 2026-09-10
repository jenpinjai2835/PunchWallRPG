# Gilded Grove Merchant & Loot

An original stylized prop collection for building merchant corners, loot displays, and reward areas. This is a visual model pack. Shopping, currency, inventory, rewards, chest opening, and other interactions are not included.

**Local source delivery — Creator Store publication is pending.** All 24 FBX and 24 GLB files passed Blender roundtrip import checks, including exact authored palette colors. The native Studio geometry preview passed with 24 models and 33 MeshParts. It does not validate Studio's **File > Import** workflow, which remains blocked by UI automation. No uploaded Roblox asset IDs or persistent `.rbxm` delivery are included. The manifest's `studio_validation: PENDING` refers to that outstanding importer gate.

## Package contents

- 24 original prop models, provided as individual FBX and GLB exports.
- Editable Blender source in `source/GildedGrove_Editable.blend` and the composed scene in `source/GildedGrove_MerchantScene.blend`.
- Shared palette textures in Teal, Ember, and Amethyst. These are three appearances for the same collection, not 72 different models.
- A showcase scene and product renders. Lighting and presentation may differ in your Roblox experience.
- A free sample selection: `03_Shipping_Crate`, `09_Coin_Stack`, and `12_Crystal_Cluster`. These three models are also part of the full 24-model collection.

The final file manifest is the authority for filenames and model statistics. No Roblox asset IDs are supplied until the models have been imported and uploaded under the intended creator account.

The collection contains **25,216 triangles** across 33 exported mesh objects. Individual models range from 140 to 2,464 triangles. The three samples total 3,080 triangles. These are geometry counts, not a measured frame-rate claim.

| Folder / file | Contents |
| --- | --- |
| `fbx/`, `glb/` | One file per model in each format; the two formats contain the same 24 assets. |
| `textures/` | `Teal_Palette.png`, `Ember_Palette.png`, `Amethyst_Palette.png`. |
| `images/` | Individual model portraits and four collection/merchant/palette renders. |
| `source/` | Two editable Blender scenes and reproducible builder/validator scripts in `scripts/`. |
| `manifest.json` | Model inventory, dimensions, triangle counts, and authored pivot notes. |
| `SHA256SUMS.txt` | SHA256 hashes for every other file included in the ZIP. |

The separate sample ZIP contains only the three sample models, their three portraits, palette textures, a filtered manifest, and a sample guide. It does not contain the full collection, Blender scenes, or generator source.

## Import into Roblox Studio

1. Unzip the delivery package. Keep texture files with the exports and start with one sample in a separate test place.
2. Choose **File > Import**, then select its FBX file. GLB is the binary glTF alternative included in the pack.
3. In the import preview, inspect the model and expand any warning. Use **Import Only As Model** to retain its hierarchy and enable **Anchored** for stationary decoration. For a local trial, you may disable **Upload to Roblox**.
4. Confirm orientation and size before accepting. The source uses Z up and -Y front, with one unit intended as one stud. Roblox's Blender guide uses **World Forward: Front**, **World Up: Top**, and **Scale Unit: Stud**. Check the actual imported size against `manifest.json`; native File > Import scale and pivot behavior remain unverified for this delivery.
5. Import and compare the result with the supplied render. Check the base position, texture colors, and each separate piece before duplicating it around your map. Set collisions to suit your gameplay.

See Roblox's [Importer guide](https://create.roblox.com/docs/studio/importer), [Blender workflow](https://create.roblox.com/docs/art/blender), and [glTF import announcement](https://devforum.roblox.com/t/3d-importer-gltf-file-support-full-release/2584034/1).

## Using the models

Keep the model hierarchy when you need independently movable pieces. Chest lids have authored hinge pivots, checked in the portable export roundtrip and through reversible rotation in the local Studio geometry preview. Recheck pivots after File > Import before animating. The separated parts contain no animation or interaction script.

The color variants use a common palette layout. Preserve the UV layout when editing, and switch to the corresponding palette texture in your material. Recheck all faces after a texture change. FBX and GLB are alternative deliveries of the same asset, so import the format you need rather than both copies.

Performance depends on the number of instances, lighting, shadows, effects, and target device. This pack does not include a mobile frame-rate guarantee. Use only the props your scene needs and test the completed scene on your target devices.

If you see an import issue, retain the model filename, format, Blender/Studio version, import settings, and exact warning. These details make a size, texture, or pivot problem reproducible.

## Rebuild from source

Use Blender 4.5.9 LTS or a compatible version. From the unzipped full package:

```text
blender --background --factory-startup --python source/scripts/build.py -- --out rebuilt
blender --background --factory-startup --python source/scripts/presentation.py -- --package rebuilt
blender --background --factory-startup --python source/scripts/validate_exports.py -- --package rebuilt --report rebuilt/export-check.json
```

All geometry is authored locally with the included scripts. The source scenes contain packed palette textures. The importer uploads and any gameplay integration are separate steps.

## คู่มือภาษาไทย

แพ็กนี้เป็นโมเดลตกแต่งต้นฉบับสำหรับมุมร้านค้า จุดแสดงของรางวัล และฉากเก็บสมบัติ มี 24 โมเดล พร้อมไฟล์ Blender, FBX, GLB และสี Teal / Ember / Amethyst โดยสามชุดสีเป็นการเปลี่ยนสีของโมเดลเดิม ไม่ได้นับเพิ่มเป็น 72 โมเดล

**สถานะไฟล์:** นำเข้า FBX และ GLB กลับใน Blender ผ่านครบ 48 ไฟล์แล้ว ส่วนภาพตัวอย่างผ่าน geometry ใน Studio เป็นการตรวจแยก ไม่ใช่ผลทดสอบเมนู File > Import ซึ่งยังติดข้อจำกัด ไม่มี asset ID ที่อัปโหลด หรือไฟล์ `.rbxm` สำหรับวางใช้โดยตรง และยังไม่ได้เผยแพร่ขายใน Creator Store

ตรวจสีทั้งสามชุดตรงกับค่าที่ออกแบบไว้ และตรวจฉากตัวอย่าง Studio ผ่านครบ 24 โมเดล / 33 MeshPart รวม 25,216 สามเหลี่ยม ตัวเลขนี้เป็นขนาด geometry ของแพ็ก ไม่ใช่ผลวัด FPS บนมือถือ

1. แตกไฟล์ให้ครบและเก็บโฟลเดอร์พื้นผิวไว้ด้วย เริ่มลองโมเดลตัวอย่างหนึ่งชิ้นในฉากทดสอบแยก
2. ใน Studio เลือก **File > Import** แล้วเลือกไฟล์ FBX ของโมเดลนั้น
3. ตรวจภาพตัวอย่างและข้อความเตือน ใช้ **Import Only As Model** เพื่อเก็บโครงสร้าง และ **Anchored** สำหรับของตกแต่งที่อยู่กับที่ หากลองแบบเฉพาะเครื่อง สามารถปิด **Upload to Roblox** ได้
4. ตรวจแกนหน้า แกนบน และขนาดเทียบกับผลตรวจของแพ็กก่อนกดนำเข้า จากนั้นเทียบสี รูปทรง และตำแหน่งฐานกับภาพตัวอย่าง
5. ตั้งค่าการชนให้เหมาะกับฉาก แล้วลองเล่นก่อนวางซ้ำจำนวนมาก

โมเดลตัวอย่างฟรีคือ `03_Shipping_Crate`, `09_Coin_Stack` และ `12_Crystal_Cluster` ซึ่งรวมอยู่ใน 24 โมเดลของแพ็กเต็มแล้ว ZIP ตัวอย่างมีเฉพาะสามโมเดล ภาพของทั้งสามชิ้น พื้นผิว palette และคู่มือตัวอย่าง ไม่มีไฟล์โมเดลที่เหลือหรือ source ของแพ็กเต็ม

แพ็กไม่มีระบบซื้อขาย เงิน inventory การแจกของรางวัล สคริปต์เปิดหีบ หรือ animation ให้ใช้ชิ้นส่วนแยกเป็นฐานสำหรับพัฒนาพฤติกรรมเอง และตรวจจุดหมุนก่อนทำ animation ภาพโชว์เป็นงานจัดแสงเพื่อแสดงสินค้า ภาพในเกมอาจต่างออกไปตามแสงและการตั้งค่าของคุณ

## Release status

This document is prepared for the local product build. It is not evidence of a live Creator Store listing or seller approval. Public distribution and account onboarding have not been performed as part of this documentation task.
