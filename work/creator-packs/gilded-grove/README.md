# Gilded Grove Merchant & Loot

An original stylized prop collection for building merchant corners, loot displays, and reward areas. This is a visual model pack. Shopping, currency, inventory, rewards, chest opening, and other interactions are not included.

**Draft delivery guide — Studio import validation is pending.** The final manifest and verification report must confirm dimensions, triangle counts, texture loading, and pivots before this guide is used for a public release.

## Package contents

- 24 original prop models, provided as individual FBX and GLB exports.
- Editable Blender source.
- Shared palette textures in Teal, Ember, and Amethyst. These are three appearances for the same collection, not 72 different models.
- A showcase scene and product renders. Lighting and presentation may differ in your Roblox experience.
- A free sample selection: `03ShippingCrate`, `09CoinStack`, and `12CrystalCluster`. These three models are also part of the full 24-model collection.

The final file manifest is the authority for filenames and model statistics. No Roblox asset IDs are supplied until the models have been imported and uploaded under the intended creator account.

## Import into Roblox Studio

1. Unzip the delivery package. Keep texture files with the exports and start with one sample in a separate test place.
2. Choose **File > Import**, then select its FBX file. GLB is the binary glTF alternative included in the pack.
3. In the import preview, inspect the model and expand any warning. Use **Import Only As Model** to retain its hierarchy and enable **Anchored** for stationary decoration. For a local trial, you may disable **Upload to Roblox**.
4. Confirm orientation and size before accepting. Roblox's Blender guide uses **World Forward: Front**, **World Up: Top**, and **Scale Unit: Stud**. The final pack verification must confirm that these settings match its exports.
5. Import and compare the result with the supplied render. Check the base position, texture colors, and each separate piece before duplicating it around your map. Set collisions to suit your gameplay.

See Roblox's [Importer guide](https://create.roblox.com/docs/studio/importer), [Blender workflow](https://create.roblox.com/docs/art/blender), and [glTF import announcement](https://devforum.roblox.com/t/3d-importer-gltf-file-support-full-release/2584034/1).

## Using the models

Keep the model hierarchy when you need independently movable pieces. A separated lid or sign is only geometry; it has no opening animation or interaction script. Check its actual origin before animating it. Do not assume a hinge pivot has been verified until the final manifest says so.

The color variants use a common palette layout. Preserve the UV layout when editing, and switch to the corresponding palette texture in your material. Recheck all faces after a texture change. FBX and GLB are alternative deliveries of the same asset, so import the format you need rather than both copies.

Performance depends on the number of instances, lighting, shadows, effects, and target device. This pack does not include a mobile frame-rate guarantee. Use only the props your scene needs and test the completed scene on your target devices.

If you see an import issue, retain the model filename, format, Blender/Studio version, import settings, and exact warning. These details make a size, texture, or pivot problem reproducible.

## คู่มือภาษาไทย

แพ็กนี้เป็นโมเดลตกแต่งต้นฉบับสำหรับมุมร้านค้า จุดแสดงของรางวัล และฉากเก็บสมบัติ มี 24 โมเดล พร้อมไฟล์ Blender, FBX, GLB และสี Teal / Ember / Amethyst โดยสามชุดสีเป็นการเปลี่ยนสีของโมเดลเดิม ไม่ได้นับเพิ่มเป็น 72 โมเดล

**คู่มือฉบับร่าง:** ยังต้องตรวจการนำเข้าใน Studio และบันทึกขนาด จำนวนสามเหลี่ยม พื้นผิว และจุดหมุนของไฟล์จริงก่อนเผยแพร่ขาย

1. แตกไฟล์ให้ครบและเก็บโฟลเดอร์พื้นผิวไว้ด้วย เริ่มลองโมเดลตัวอย่างหนึ่งชิ้นในฉากทดสอบแยก
2. ใน Studio เลือก **File > Import** แล้วเลือกไฟล์ FBX ของโมเดลนั้น
3. ตรวจภาพตัวอย่างและข้อความเตือน ใช้ **Import Only As Model** เพื่อเก็บโครงสร้าง และ **Anchored** สำหรับของตกแต่งที่อยู่กับที่ หากลองแบบเฉพาะเครื่อง สามารถปิด **Upload to Roblox** ได้
4. ตรวจแกนหน้า แกนบน และขนาดเทียบกับผลตรวจของแพ็กก่อนกดนำเข้า จากนั้นเทียบสี รูปทรง และตำแหน่งฐานกับภาพตัวอย่าง
5. ตั้งค่าการชนให้เหมาะกับฉาก แล้วลองเล่นก่อนวางซ้ำจำนวนมาก

โมเดลตัวอย่างฟรีคือ `03ShippingCrate`, `09CoinStack` และ `12CrystalCluster` ซึ่งรวมอยู่ใน 24 โมเดลของแพ็กเต็มแล้ว

แพ็กไม่มีระบบซื้อขาย เงิน inventory การแจกของรางวัล สคริปต์เปิดหีบ หรือ animation ให้ใช้ชิ้นส่วนแยกเป็นฐานสำหรับพัฒนาพฤติกรรมเอง และตรวจจุดหมุนก่อนทำ animation ภาพโชว์เป็นงานจัดแสงเพื่อแสดงสินค้า ภาพในเกมอาจต่างออกไปตามแสงและการตั้งค่าของคุณ

## Release status

This document is prepared for the local product build. It is not evidence of a live Creator Store listing or seller approval. Public distribution and account onboarding have not been performed as part of this documentation task.
