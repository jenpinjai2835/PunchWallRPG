# Smash Wall — ตรวจความชัดเจนและความสบายตาของภาพเกม

วันที่ 6 กันยายน 2026 · Agent 1 · งานตรวจและเสนอแก้เท่านั้น

เกมมีฐานที่นำไปขัดเกลาได้ แต่ภาพที่ตรวจยังไม่รองรับการรับรองว่า “งานภาพระดับพรีเมียมพร้อมส่งมอบ” จุดสำคัญคือข้อความที่ผู้เล่นต้องอ่านกลับเล็ก ขณะที่กรอบ สี และป้ายหลายส่วนเด่นพร้อมกัน ควรแก้ลำดับสายตาและภาษาภาพก่อนเพิ่มของตกแต่ง เอฟเฟกต์ หรือระบบใหม่ การผ่านข้อสอบขนาด/ขอบเขต UI ไม่ได้ตัดสินความสวยหรือความสบายตาแทนการดูภาพจริง

## หลักฐานและขอบเขต

ตรวจ source ที่ Coordinator รวมแล้ว ณ `7a02077fb51ab5a8ac391745fb5112787ed1fd56` และเทียบถึง `6aebfed0a01263bd124f5325313d77736e8b0f94`: ไม่มี source UI/world เปลี่ยนระหว่างสอง revision นี้ การอ้างบรรทัดด้านล่างใช้ source ใน integration worktree `F:/Roblox/PuchWall-completion-20260906/work/punch-wall-rpg/src/` ไม่ใช่ source เก่าใน worktree ผู้ตรวจ

เปิดดูภาพจริงที่มีอยู่ด้วย `view_image` ที่ขนาดต้นฉบับ ไม่ใช้ HTML prototype ตัดสินเกมจริง:

| ภาพใต้ `work/docs/evidence/` | ขนาด | ใช้ยืนยันได้ / ข้อจำกัด |
| --- | --- | --- |
| `smash-new-shop-desktop-20260906.png` | 1277×780 | ภาษากรอบ รายการ และการแบ่งพื้นที่ใน Shop รุ่นก่อนหน้า; ข้อความบางส่วนและหมัดมีการปรับภายหลัง |
| `smash-new-inventory-desktop-20260906.png` | 1277×780 | ความหนาแน่นของกรอบ/ป้ายและรายละเอียดด้านข้าง; ไม่ใช่ภาพยืนยัน source ล่าสุด |
| `smash-new-shop-phone-20260906.png` | 874×402 | Shop แนวนอนแบบหนึ่งคอลัมน์ เห็นเพียงรายการเต็มแรกและส่วนหนึ่งของรายการถัดไป |
| `smash-new-inventory-phone-20260906.png` | 874×402 | Inventory แบบสองคอลัมน์ การค้นหา/หมวด/ความจุ และป้ายที่แย่งพื้นที่กับรูป |
| `smash-maximized-play-20260906.png` | 1277×780 | ภาพเล่นจริงที่ใช้ประกอบการตรวจประสิทธิภาพ แสดง HUD และบริเวณเกิดพร้อมสัตว์เลี้ยง; ไม่ผูกเป็นภาพ final artifact |
| `smash-current-play-20260906.png` | 637×654 | หน้าต่างเล่นจริงขนาดแคบ; ไม่ใช่หลักฐานว่าเป็น layout โทรศัพท์หรือการตั้งค่าหน้าจอเดียวกับภาพ maximized |
| `smash-settings-native-after-20260906.png` | 1277×780 | ตัวอย่างหน้า Settings ที่แบ่งแถวและเว้นระยะได้ชัดกว่า Inventory; ไม่ใช่หลักฐานสถานะทุกปุ่มใน source ล่าสุด |

ไม่นำ `smash-prototype-*.png`, prototype HTML, ภาพ release เก่า หรือภาพเดือนสิงหาคมมาอ้างเป็นหน้าตาปัจจุบัน ข้อความ `HERO CITY ARMORY` / `SERVER VERIFIED` ในภาพเก่าถูกแก้ใน source ปัจจุบันแล้ว จึงไม่เปิดเป็นบัคใหม่ โมเดลหมัดในภาพเก่าก็ไม่ใช้ตัดสินการปรับทรงล่าสุด

การจับภาพ source ปัจจุบันรอบแรกของ Coordinator หยุดก่อนบันทึกภาพ เพราะ decoder คาด PNG แต่ Studio ส่ง JPEG (`smash-current-source-visual-review-20260906/manifest.json`); มี cleanup และตรวจ source ก่อน/หลังครบ แต่ยังไม่มีภาพให้ตรวจจากรอบนั้น ข้อนี้เป็นข้อจำกัดของหลักฐาน ไม่ใช่ข้อผิดพลาดหน้าตาเกม

## ข้อเสนอเรียงตามผลต่อผู้เล่น

อันดับคือความเร่งด่วนของงานภาพ ส่วนข้อบกพร่องที่ระบุ P2 เป็นสิ่งที่ควรแก้ก่อนยอมรับคุณภาพ UI รอบนี้ ไม่ได้อ้างว่าพบ P1 ด้านความปลอดภัยหรือเศรษฐกิจ

### 1. P2 — ข้อความสำคัญเล็กกว่าส่วนตกแต่ง

**พบ:** คำแนะนำเป้าหมายบน HUD มีกรอบเด่น แต่ `ObjectiveText` ยอมขนาด 7–13 และบน compact จำกัดสูงสุดเพียง 10 (`PunchWallClient.client.lua:11257`, `:13920`) ขณะที่ desktop Inventory ยอมชื่อไอเท็ม 8–12 และป้าย equipped/locked 9 (`InventoryUI.lua:4047`, `:4094`) ภาพ desktop Inventory แสดงรายการหลายช่องพร้อมชื่อเล็ก ใน source มือถือกลับมีพื้นฐาน 14/12 ที่ชัดกว่าอยู่แล้ว

**แก้:** ใช้ข้อความคำสั่งสั้นหนึ่งประโยคที่บอกการกระทำจริง เช่น `Punch the wall` แล้วแยกคำอธิบายรองเท่าที่จำเป็น กำหนดเป้าหมายข้อความหลักที่อ่านเพื่อเล่น/ซื้อ/เลือกไอเท็มอย่างน้อย 14 px หลัง scale และข้อความรองอย่างน้อย 12 px ทั้ง desktop และ mobile ปรับจำนวนคอลัมน์หรือขยายแถวก่อนลดตัวอักษร ใช้ bold กับชื่อและปุ่ม; ให้รายละเอียดเป็นน้ำหนักปกติ ไม่ใช้ตัวหนาทุกระดับ

**รับงานด้วยภาพ:** HUD ผู้เล่นใหม่และ Inventory ที่มีชื่อสั้น/ยาว ณ 80%, 100%, 120% ของ UI scale ต้องอ่านข้อความหลักได้ที่ภาพ 1:1 ไม่มีการตัดชื่อจนแยกของไม่ได้ และขนาดจริงตรงเกณฑ์; ไม่รับภาพขยายแทนการอ่านที่ขนาดเล่นจริง

### 2. P2 — กรอบและสีของเมนูยังดูเป็นคนละชุด

**พบ:** Inventory มีขอบนอก/ขอบใน cyan, เพชรมุม, header แดงพร้อมแถบ/ลวดลาย และกรอบซ้อนในทุกการ์ด (`InventoryUI.lua:598`, `:627`, `:663`, `:689`, `:736`, `:2555`) Shop ใช้ header และ tab คนละแบบ มีทั้งแถบแดง/cyan และแถบเลือกสีทอง (`PunchWallClient.client.lua:12410`, `:12428`, `:12531`) ความต่างนี้มองเห็นได้ในคู่ภาพจริง Shop/Inventory ขณะที่ Settings ใช้แถวเรียบกว่า

**แก้:** กำหนดชุดเดียวสำหรับ Shop, Inventory และเมนูประกอบ: พื้น charcoal/navy, ระยะช่อง 8/12/16 px, รัศมีมุมชุดเดียว, ขอบปกติบางและเงียบ และขอบเด่นเฉพาะรายการที่เลือก เก็บบุคลิก Hero City ไว้ที่ภาพไอเท็ม/หมัดแดง/จุดเน้น cyan โดยลดเพชรมุม ลวดลาย header และเส้นซ้อนที่ไม่ได้บอกสถานะ ใช้ปุ่มปิด รูปแบบหัวเรื่อง และ selected tab แบบเดียวกัน

**รับงานด้วยภาพ:** วางภาพ Shop, Inventory, Settings ขนาดเดียวกันเคียงกัน ต้องรู้สึกว่าเป็นเกมเดียวกัน; ในการ์ดที่ไม่เลือกไม่มีกรอบสดซ้อนหลายชั้น; เมื่อเลือกไอเท็มยังเห็นตำแหน่งที่เลือกทันทีโดยไม่ต้องอาศัยสีอย่างเดียว

### 3. P2 — สี rarity ปะปนกับสีประจำโมเดล

**พบ:** `itemAccent` และ ViewModel ใช้สี `definition.accent`; Inventory นำสีเดียวกันไปทำป้าย rarity (`InventoryUI.lua:2907`, `:3107`; `InventoryViewModel.lua:309`) ทำให้ Common สองหมัดเป็นสีทองกับครีม และ Rare Iron / Epic Thunder เป็น cyan ใกล้กัน (`GameConfig.lua:244`) ตรงกับภาพจริงเก่า การ์ดแต่ละชิ้นจึงมีสีมาก แต่สีไม่ได้ช่วยอ่านความหายากอย่างสม่ำเสมอ

**แก้:** แยกสี rarity badge จากสีประจำโมเดล ใช้ `PolishConfig.RarityColors` ที่มีอยู่แล้ว (`shared/PolishConfig.lua:136`) เป็น mapping เดียวข้าม Shop/Inventory พร้อมคำว่า Common/Rare/Epic ฯลฯ ที่อ่านได้ ระบุ fallback สำหรับ rarity ที่ยังไม่มีใน mapping โดยไม่แก้ rarity/ราคา/ตัวคูณจริง เก็บสีหมัด วัสดุ แกนเรืองแสง และ asset identity เดิมไว้ สี selected ต้องคงที่ ไม่เปลี่ยนตาม rarity ให้ทองยังสื่อราคา/รางวัลชัดเจน

**รับงานด้วยภาพ:** เทียบ Common ทั้งสองชิ้นและ Rare/Epic ที่มีสีโมเดลคล้ายกัน ทั้งรายการและ detail ต้องใช้ป้าย rarity ตรงกันทุกหน้า โดยทรง/สีของโมเดลไม่ได้เปลี่ยนเพื่อให้ตรงป้าย

### 4. P2 — สถานะ “ใส่อยู่” หน้าตาคล้ายปุ่มที่ยังกดได้

**พบ:** ใน Shop `EQUIPPED` เป็นปุ่มสีเขียวขนาดใหญ่และถูกปิด action แต่สี/รูปทรงใกล้ `EQUIP` มาก (`PunchWallClient.client.lua:13053`) ภาพมือถือทำให้สิ่งที่เด่นที่สุดในรายการแรกเป็นสถานะที่ไม่ต้องทำอะไรต่อ ขณะที่ Inventory มีข้อมูล rarity/category/state ซ้ำทั้งแถบบนและแถวล่างใน detail (`InventoryUI.lua:1491`, `:3106`, `:3961`)

**แก้:** ทำ equipped เป็นป้ายสถานะเงียบพร้อมเครื่องหมายถูก; ปุ่มจริงใช้รูปแบบที่อ่านว่า “ทำต่อได้” ชัดเจน Buy/Equip/Use มีหนึ่งการกระทำหลักต่อรายการ ส่วน unavailable/depth locked แสดงเงื่อนไขสั้นและรูปแบบ disabled เดียวกัน ไม่ทำให้รายการที่ซื้อไม่ได้ดูพร้อมซื้อ ลด metadata ที่ซ้ำใน detail เพื่อคืนพื้นที่ให้ภาพ ผลของไอเท็ม และการกระทำจริง

**รับงานด้วยภาพ:** แสดงอย่างน้อย owned/equipped, ซื้อได้, depth locked, ราคา unavailable และ pet action หลายปุ่ม ผู้ตรวจแยกสถานะกับปุ่มได้โดยไม่ต้องลองกด ทั้งยังแสดงราคา/สกุลเงินจริง เงื่อนไข และกติกาลบ/ล็อกครบ; ต้องทดสอบ authority/input เดิมซ้ำหลังทำจริง

### 5. P2 งานภาพ — HUD กับของรอบฉากแย่งความสนใจจากการต่อย

**พบ:** ภาพ maximized มี stat cards, objective, Honor, Daily Breaker, rank track, เมนูสองฝั่ง, ปุ่มล่าง และแท่น neon ในเฟรมเดียวกัน หลายชิ้นใช้กรอบสด/ตัวหนาเหมือนกัน แผ่น `MATERIAL TIER` กว้างแต่ข้อความตรงกลางเล็ก ขณะที่กรอบทางเข้าและแท่นร้านเด่นมาก Source ยืนยันองค์ประกอบ desktop ที่ `PunchWallClient.client.lua:14055` และ neon ทางเข้าที่ `ForestVisualBuilder.lua:484`, `:518` / แท่น boost ที่ `PunchWallBootstrap.server.lua:6731` อย่างไรก็ตามภาพใหม่ระยะใกล้ wall/boss ยังจำเป็นก่อนสรุปการทับกันของ HUD ล่าสุด

**แก้:** ให้ลำดับชัดว่า “ตัวละคร/กำแพงที่กำลังตี → HP/เป้าหมายถัดไป → ทรัพยากร → เมนูเสริม” ลดความหนา/ความอิ่มสีของ utility/stat frames และไม่ใส่ประกายหรือ badge ถาวรที่ไม่มีสิ่งให้ทำจริง รักษาปุ่ม touch ใหญ่พอ; สำหรับ keyboard-only ค่อยประเมินการลดความเด่นของรูป joystick/jump ด้วยเส้นทาง input ที่ถูกต้อง การลด neon/รายละเอียดฉากยังเป็นข้อเสนอรอตรวจภาพ wide HUD ปัจจุบัน ห้ามเริ่มปรับจากภาพเก่าเพียงอย่างเดียว หากภาพใหม่ยืนยันปัญหา ให้แก้เฉพาะ accent ที่ซ้ำและป้ายที่อ่านไม่ได้ โดยรักษา landmark/asset identity

**รับงานด้วยภาพ:** จับ spawn, ใกล้กำแพงก่อนตี/หลังแตก และ boss จริงทั้ง desktop/mobile ทุกภาพต้องเห็นเป้าหมาย ตัวละคร และผลการต่อยเป็นกลุ่มเด่น; ป้ายร้าน/utility ไม่กลบ action/HP และไม่มี HUD ทับมือ/ปุ่ม ไม่มีข้อเสนอให้ลด saturation ทั้งเกมหรืออ้างว่าค่า Bloom ปัจจุบันผิดจากภาพเดียว (`Bloom.Intensity` ปัจจุบันเพียง 0.08)

### 6. งานภาพต่อเนื่อง — คืนพื้นที่ให้สินค้าและรักษาภาษา art เดียวกัน

**พบ:** ภาพโทรศัพท์มี header + tabs/categories + toolbar/footer หลายแถบ จึงเหลือรายการที่เห็นเต็มค่อนข้างน้อย ปัจจุบัน compact Inventory มีแถว 92 px, หนึ่ง/สองคอลัมน์และ drawer จริงแล้ว (`InventoryUI.lua:3659`, `:4030`) ควรรักษาความอ่านง่ายนี้ ไม่ย้อนกลับไปบีบหลายคอลัมน์ ภาพ desktop เก่าแสดง native fist preview ห้าชิ้นกับภาพโปสเตอร์ของ tier ถัดไป; source ยังคงเส้นทาง native/catalog กับ static art แยกกัน (`PunchWallClient.client.lua:12864`)

**แก้:** จัด header/filter ให้เป็นแถบเงียบที่กระชับ ลดข้อความ passive ที่ซ้ำ เช่น category/state/capacity ที่ไม่จำเป็นต้องแยกกรอบ โดยยังมี search และ rarity ที่พบง่าย รักษาความจำการค้นหา/scroll/selection/ปุ่มใน drawer ในด้าน art ให้ขนาดภาพที่มองเห็น ระยะขอบ ทิศทางแสง และพื้นรองสอดคล้องกันระหว่าง native preview กับภาพเดิม ไม่ลบหรือแทน Creator Store asset โดยไม่ตรวจ identity

**รับงานด้วยภาพ:** เห็นการเปรียบเทียบอย่างน้อยสองรายการเต็มบน landscape ที่มีพื้นที่พอ โดยไม่ลด 14/12 px หรือ 44 px touch floor; หากจอเตี้ยเกินให้แสดงแถวถัดไปและ scroll affordance ชัดเจนแทนย่อทั้งหมด ถ่าย grid ปกติ + search no results + รายการชื่อยาว + drawer pet ที่มีหลาย action + รายการหลัง scroll; ทั้ง first five และ tier ถัดไปต้องมี silhouette และขอบภาพครบ ไม่ใช้ภาพหมัดเก่าตัดสินทรงล่าสุด

## เกณฑ์หลักฐานก่อนยอมรับรอบงานภาพ

ข้อเสนอข้างต้นยังไม่ใช่ implementation และยังไม่มีผู้ตรวจยอมรับภาพใหม่ ใช้ capture manifest ผูก exact source, สถานะจริง, viewport ของ Camera, safe HUD size/insets, UI scale, input mode และกราฟิกเดียวกันเมื่อเทียบก่อน/หลัง ไม่ใช้ nominal device size แทนขนาดที่วัดได้ และไม่ใช้ภาพที่เปิด/ย่อหน้าต่างต่างกันสรุปการเปลี่ยนคุณภาพ

| ชุดภาพจริงที่ต้องมี | สถานะที่ต้องตรวจ |
| --- | --- |
| Desktop เต็มหน้าต่าง และ desktop แคบประมาณ 637×654 | HUD ผู้เล่นใหม่, HUD ติดกำแพง/บอส, Shop Fists/Premium/ราคาไม่พร้อม, Inventory grid/detail, Settings |
| Phone landscape ประมาณ 874×402 และ safe area ที่วัดจริง | ภาพชุดเดียวกัน, expanded Inventory drawer, search/filter, scroll กลางรายการ, ปุ่มครบขณะ UI scale 80/100/120% |
| เกมจริงต่อเนื่องช่วงสั้น | หันกล้อง เข้าเมนู กลับเล่น ต่อย/กำแพงแตก/รับรางวัล; ดูการกระพริบ เลื่อน layout บังตัวละคร และป้ายซ้อนที่ภาพนิ่งพิสูจน์ไม่ได้ |

รับงานแยกสองด้าน: (ก) ข้อสอบขอบเขต/ข้อความ/input/authority เดิมผ่าน และ (ข) ผู้ตรวจดูภาพจริง 1:1 เทียบก่อน/หลังแล้วยืนยันลำดับสายตา ความสอดคล้อง ความอ่านง่าย และความสบายตา ไม่มีคะแนน geometry ใดแทนข้อ (ข) ได้ ภาพ Studio บนเครื่องนี้ยังไม่พิสูจน์หน้าจอ/ความลื่นของโทรศัพท์จริงหรือผลลัพธ์จากผู้เล่นทั่วโลก

Checklist: ตรวจ source ปัจจุบันและภาพจริงที่มีอยู่แล้ว; จัดข้อเสนอและเกณฑ์ภาพครบ; ตรวจความตรงกันของข้อเสนอ/source และส่งเอกสารเพื่อยอมรับงานตรวจ ภาพใหม่ของ Coordinator และการยอมรับความสวยจริงยังเป็น gate แยกที่เปิดอยู่ ไม่มีการแก้ source, flow, tool, asset, เศรษฐกิจ หรือเรียก Studio/HQ จากงานตรวจนี้


## งาน Inventory ที่ได้รับอนุมัติและลงมือทำต่อจากการตรวจ

สถานะนี้แยกจากข้อเสนอเดิมด้านบน: Coordinator อนุมัติให้ Agent 1 แก้เฉพาะ `InventoryUI.lua`, flow/contract ของ Inventory และเอกสารนี้ งาน Shop/HUD/ฉากหลังเต็มจอเป็นของ Coordinator ส่วนการเปิด Studio, รวม source, ภาพหลังแก้ และ regression รวมยังเป็น gate ของ Coordinator

Source หลักที่ส่งให้รวมเป็น commit `1290a1b074ef7ea1fdb37858afc3a4eddf8475b2` (source อย่างเดียว, หยุดแก้ไฟล์หลังส่งมอบครั้งแรก) ค่า SHA256 ของ Inventory ที่ normalize เป็น LF: `c195e4185085cc58125c0ff68fa4c72dc0bd182d0fc3bc39c3a7b7c979062ff8` ไม่มีการแก้ main client, config, โมเดล/texture ต้นทาง, authority หรือเศรษฐกิจในงานนี้

### ภาพจริงที่ใช้ปรับงาน

อ่านภาพ `work/docs/evidence/smash-current-source-visual-review-r2-20260906/desktop-inventory-fists.jpg` และ `desktop-inventory-pets.jpg` จาก integration tree ของ Coordinator: ขนาดภาพจริง 1277×780, manifest/source attestation ทั้งเก้าสคริปต์ก่อนและหลังผ่านตามรายงาน Coordinator ภาพยืนยันว่าหัวแดง/เพชรฟ้าและหลายชั้นกรอบแย่งรายการ พร้อมชื่อเล็กใน grid เดิม และ Forest Pup แสดงด้านหลังเป็นก้อนสีเทา ขณะที่ Miner Cat มีหน้าให้เห็น ภาพทั้งสองเป็น **ก่อน source commit นี้** จึงใช้ยืนยันสภาพเดิมและเลือกจุดแก้ ไม่ใช่หลักฐานภาพหลังแก้

ภาพ phone ของ capture รอบนี้ยังไม่ผ่าน actual viewport gate จึงไม่เรียกภาพ desktop ว่า mobile proof และไม่ใช้ `desktop-fresh-hud.jpg` อ้างว่าเป็นผู้เล่นใหม่ไม่มีสัตว์เลี้ยง: บัญชีทดสอบมีสิทธิ์ pass จริงที่ reconciliation เติมสัตว์พรีเมียมได้

### พฤติกรรมที่เปลี่ยน

- กรอบนอก navy RGB 18/26/38, ภายใน 14/20/29 และเส้น muted 61/88/101: กรอบนอกเส้นเดียว 1 px, หัวเรียบ, ซ่อนเพชร/ราง/ลายหัว/กรอบซ้อนที่ตกแต่งไว้ สีฟ้าใช้บอกการเลือก รายการที่สวมอยู่เป็นป้ายสถานะสีเขียวเข้มตัวขาว ปุ่มใช้งาน/อันตรายยังแยกความหมายและรักษา contrast เดิม
- Desktop ใช้รายการแนวนอนสูงจริง 104 px, mobile คง 92 px; ความกว้างรายการอย่างน้อย 280 px, จำนวนหนึ่งหรือสองคอลัมน์ตามพื้นที่ ชื่อไม่ย่อด้วย `TextScaled` และมีขนาดที่ render อย่างน้อย 14 px; rarity/สถานะอย่างน้อย 12 px ปรับตาม UI scale 80/100/120% พื้นที่เชิง layout ต่ำกว่า 900 จะใช้ compact ก่อนทำให้สาม pane เบียดกัน ปุ่ม touch ยังคงอย่างน้อย 44 px
- Rarity chip และ marker ใช้ `PolishConfig.RarityColors` เดียวกัน เช่น Common/Rare/Epic ไม่ดึงสีจากโมเดลอีก สีและ geometry ของหมัด/สัตว์ยังคงเดิม; Premium ใช้ fallback เดิมสี 255/211/50 เพราะ shared mapping ยังไม่มี Premium
- Search, rarity, scroll, selection, card pool, action callbacks และ master/model preview cache ใช้ lifecycle เดิม ไม่เพิ่ม frame loop งานฟิตภาพ Pup ทำเฉพาะครั้งสร้าง clone นั้น ทั้ง art frame ของ card/detail เป็นสี่เหลี่ยมจัตุรัสตาม layout ปัจจุบัน จึงไม่ต้องมี resize signal ใหม่
- Backdrop ภายในโมดูลยังเป็นตัวรับ input โปร่งใสที่ถูกต้องตาม modal host; การ dim ฉากเต็มจอให้เหมือน Shop เป็นการแก้ main client ที่ Coordinator เป็นเจ้าของ ไม่วาง overlay เพิ่มผิดขอบเขต host

### แก้ทิศภาพ Forest Pup โดยรักษาทรัพย์สินต้นฉบับ

A2 ตรวจ XML ของ imported template: Forest Pup มี Decal `AnimatedFace/CanInvert`, Face=Front, URI `rbxassetid://2759037468`, normal โลกประมาณ (-0.976674259, 0, +0.214735135) กล้องเดิมวางด้วยเวกเตอร์โลก (+0.48d,+0.2d,-d) และ signed distance จากระนาบหน้าที่คำนวณจาก XML เท่ากับ **-2.525480094** ซึ่งอยู่ด้านหลังแน่นอน Miner Cat มี decal บนหน้าตรงข้ามสองฝั่ง จึงไม่ใช้กฎ “decal แรก” เปลี่ยนทุกสัตว์

แก้เฉพาะ petName `Forest Pup`: หาพื้นผิว Front ที่ยังมองเห็นของ `AnimatedFace`, ใช้ `CFrame.LookVector` ของชิ้นนั้นโดยตรงพร้อม offset ข้าง/บนเล็กน้อย จากนั้นใช้ทั้งแปดมุม `GetBoundingBox` หาระยะกล้องที่พอดีกับ FOV/aspect โดยเว้นขอบ 1.12 เท่า ไม่หมุน/ย้าย/ย่อโมเดล ไม่เพิ่ม texture ไม่เปลี่ยน Cat หรือกล้องหมัด ถ้าไม่มีพื้นผิวที่กำหนดจะใช้ framing เดิม

Fixture จากขอบเขตสี่ BaseParts ใน basis ของ PrimaryPart ที่ A2 คำนวณจาก XML (ไม่ใช่ผล Studio GetBoundingBox ที่จับสด) ให้ signed distance หลังแก้ **+3.489113722** และแปดมุมอยู่ในกรอบตามเกณฑ์ การทดสอบยังครอบคลุม bounding box สังเคราะห์ขนาดใหญ่กว่า, aspect .55/1/1.8 และ FOV 25/34/60 ข้อสรุปนี้พิสูจน์ทิศ/คณิตศาสตร์ของกล้อง ไม่พิสูจน์ว่า Roblox โหลด URI สำเร็จหรือผู้ตรวจชอบภาพหลังแก้ ต้องดูภาพเกมจริงของ Coordinator ต่อ

### ตรวจที่ผ่านก่อนส่งมอบ

รันจาก `F:/Roblox/PuchWall-post-full-oracles-20260906`:

| คำสั่ง / gate | ผล |
| --- | --- |
| `node work/automation/scripts/inventory-visual-responsive-contract.mjs --self-test --readability-baseline ef2ce60` | 2,953 assertions ของ `ApplyResponsive` จริง + 20 ของ helper rarity/text จริง + 11 structural checks; 9 compiling weakening mutations ถูกปฏิเสธ; source เดิม fail-before ที่ desktop readability |
| `node work/automation/scripts/inventory-model-preview-contract.mjs --self-test --preview-baseline ef2ce60` | 159 assertions ของ source/lifecycle/geometry และ helper flow จริง; 8 compiling mutations ถูกปฏิเสธ; ฟังก์ชันกล้อง pet เดิม fail-before ที่ด้านหน้าของ Pup |
| `node work/automation/scripts/inventory-card-render-contract.mjs` | 17 checks; โมเดล lifecycle เดิมเลือก 10,000 ครั้งยังไม่เพิ่ม pool/connections |
| `node work/automation/scripts/inventory-visual-fidelity-contract.mjs` | 20 checks; enabled action palette minimum contrast 5.445 ≥ 4.5 |
| `node work/automation/scripts/inventory-runtime-cache-contract.mjs` | 16 checks |
| official Luau 0.737 `luau-compile.exe -O0/-O1/-O2 InventoryUI.lua` | source ทั้งสามระดับผ่าน |
| compile code ทุก chunk ของ `inventory-premium-readability.json` และ `inventory-visual-responsive.json` | 10 chunks ผ่าน |
| `git diff --check` | ผ่าน |

ไม่ลดเกณฑ์ functional bounds เดิมเพื่อให้ style ใหม่ผ่าน: contract เปลี่ยนเพียงความคาดหวังกรอบสีทอง/grid ตัวเล็กที่ถูกยกเลิก และเพิ่ม actual source cases กรณี desktop 900 px ที่ UI scale 120% การทดสอบผลด้วย mock ไม่ได้ render ฟอนต์ Roblox จึงมี flow วัด `TextFits`, `TextBounds`, AbsoluteSize และขอบ parent จริงประกอบ

Flow ใหม่ `inventory-premium-readability.json` ต้องเพิ่มใน registry ของ Coordinator: seed เฉพาะ ready EphemeralStudio ที่ไม่ writable และไม่มี live DataStore opt-in, เปิด Inventory, ตรวจ 80/100/120% ใน viewport ปัจจุบัน, สี rarity จริง, ข้อความ/row/touch bounds, card และ preview instance เดิม, search no-results, scroll/selection retention, ปุ่ม pet ครบ และ Pup card/detail ที่มี URI จริง, signed front dot > .05, แปดมุมอยู่ใน inset จากนั้นคืน UI scale/ปิดเมนู/หยุด Play ไม่มี extra gesture หรือการเปลี่ยน server economics

### Gate ที่ยังเปิดหลังส่ง source

Coordinator ต้องรัน flow ใหม่นี้บน desktop และ phone ที่ยืนยันขนาด Camera/safe HUD จริง รวม regression เดิมของ Inventory/model/actions และชุดรวมที่เหมาะกับงานภาพ จับหลังแก้ในสถานะเดิมทั้ง Fists/Pets/detail/search และเทียบกับภาพก่อนแบบ 1:1 ผู้ตรวจต้องเห็นหน้า Pup เดิมจริง พื้นที่รายการอ่านได้ กรอบสงบ และ actions ชัดเจน การผ่าน geometry/test ไม่เท่ากับผ่านความสวยหรือเล่นลื่นบนโทรศัพท์จริง

Checklist งานย่อย: ตรวจ source/ภาพก่อนและสาเหตุ Pup แล้ว; implementation ในขอบเขตพร้อม extracted checks/compile ผ่านแล้ว; source immutable ส่งมอบและคืน ownership แล้ว; test/doc ส่งเพื่อรวมเป็นลำดับถัดไป ภาพหลังแก้และ runtime รวมยัง **PENDING Coordinator** ไม่มีการเปิด Studio จากงานนี้


### Follow-up ที่ตรวจพบก่อนปิด test/doc handoff

หลังส่ง source หลักพบ `Empty.TextSize` ของ desktop ยังเป็น 12 ที่ไม่ชดเชย scale ทำให้ข้อความ no-results เหลือ 9.6 px เมื่อเลือก 80% Coordinator โอน ownership กลับมาเฉพาะหนึ่ง assignment นี้: แก้เป็น `self.Empty.TextSize = secondaryTextSize` เท่านั้น ค่า SHA256 ของ source สุดท้ายแบบ LF คือ `64de2702cd527ee6be13889fe1b8df7750325cac4db2031c6738e3f70c027f33` เพิ่ม 60 exact layout assertions และ mutation คืนค่าบรรทัดเก่า รวมเป็น 2,953/9 ตามตาราง พร้อม flow วัด no-results TextFits/TextBounds/ขอบ parent จริง

รัน `node work/automation/scripts/inventory-visual-responsive-contract.mjs --readability-baseline 1290a1b` เพิ่มด้วย ผล fail-before ตรง `no-results secondary floor`; source หลังแก้และ compile O0/O1/O2 ผ่าน ทุก chunk ของ flow ทั้งสองผ่าน ไม่มีการเปลี่ยนขนาด container หรือยกเว้นข้อความที่ถูกตัด

ได้รับภาพจริงหลัง source หลักจาก Coordinator ที่ `work/docs/evidence/smash-premium-source-visual-review-20260906/desktop-inventory-fists.jpg` และ `desktop-inventory-pets.jpg` แล้ว (1277×780; ก่อน Empty follow-up) ผู้ตรวจเห็นว่าหัว/กรอบ navy และแถวตัวอักษรใหม่จัดสายตาได้สงบขึ้นจริง และเห็นหน้า OWO ของ Forest Pup ทั้ง card/detail จึงไม่ใช่ภาพ texture ว่างเหมือนเดิม แต่ **ยังไม่รับคุณภาพรูปทรงสัตว์**: แทบทั้ง silhouette เป็นบล็อกเทาหน้าแบน ไม่มีหู/ปาก/ลำตัวที่อ่านเป็นลูกสุนัข Source `GameConfig.Pets` จับชื่อ Forest Pup กับ packModel `Dowodle`; `StyleNormalCatalogPet` เพียง tint และไม่มี silhouette เสริมสำหรับ Pup จึงมี P2 ด้านคุณภาพ art ตามคำขอผู้ใช้ค้างอยู่ โดยไม่ได้พบหลักฐานว่ากล้องใหม่ลบ/เปลี่ยน geometry

ภาพนี้ยังไม่แยกได้ว่ารายละเอียด body mesh เดิมถูกบัง/โหลดไม่ขึ้นหรือเป็น art เดิม ต้องเทียบ Dowodle ต้นฉบับที่ framing เดียวกันกับ geometry/สถานะโหลดจริงก่อนเลือกแก้ pose หรืองาน model ส่วนภาพประวัติ `pet-pack-candidates-1.jpg` ถูก loading UI บัง จึงไม่ใช่หลักฐานต้นฉบับที่ใช้ตัดสินได้ Coordinator รับเรื่องนี้ไปจัด scope ต่อแล้ว; รอบนี้ยังไม่มีการปรับ silhouette/texture นอกขอบเขต Inventory
