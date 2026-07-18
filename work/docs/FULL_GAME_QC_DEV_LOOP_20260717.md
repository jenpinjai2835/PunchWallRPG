# Smash Wall Full Game QC and Dev Loop - 2026-07-17

## Scope

รอบนี้ทดสอบจาก Studio runtime จริงบน branch `production` โดยใช้ทั้ง recorded
automation, Studio test harness และการตรวจจาก player camera ไม่ได้ตัดสินจาก
source code หรือ static instance เพียงอย่างเดียว

ระบบที่ครอบคลุม:

- onboarding, waypoint และ objective
- desktop/mobile HUD และ safe area
- menu, fist shop, boosts, music และ jump
- training, offline training และ movement lock
- punch forward/up/down, cooldown, lunge, collision และ destruction
- structural physics, rubble, camera follow และ long tunnel
- wall pet drop, fusion และ premium pets
- Spin, Rebirth, Titan boss, rank, world reset และ world transition
- inventory persistence, Studio-only test harness และ 200-punch stress

## Baseline Result

- Recorded flows: 30
- Passed: 25
- Failed: 5
- Runtime console errors: 0 ใน flow ที่ผ่าน
- Stress test: 200 punches ผ่าน

Baseline failures:

| Flow | Classification | Finding |
| --- | --- | --- |
| `onboarding-waypoint` | Game defect | Spawn yaw เป็น `0` และหันหนี Power Bag; dot product ไปยังจุดฝึกเป็น `-0.724` |
| `punch-action-timing` | Test race | Gameplay มี Windup/Contact/Recovery ครบ แต่ test เริ่มเก็บ phase หลัง invoke จึงพลาดช่วง Windup ได้ |
| `punchwall-hybrid-physics-lunge` | Stale test | กำแพงใหม่สูง 6 แถว ทำให้สอง support พังแล้วมี 10 blocks หลุด ไม่ใช่ 4 blocks ตาม test เก่า |
| `camera-long-tunnel-regression` | Game + test defect | ตัวละครอยู่บนจอ แต่แนวกล้องถูกบังเกือบทั้งหมด; test วัด zoom จาก `Camera.Focus` ที่ยัง settle ไม่เสร็จ |
| `world-wall-reset` | Test race | Feedback ถูกส่งจริง แต่ 0.25 วินาทีไม่พอหลัง reset 5,400 blocks |

## Defect Backlog

### P0 - Camera

- [ ] `CAM-01` หลัง teleport ไป Training ตัวละครอยู่ที่ `(-42, 3, 31)` แต่กล้อง
  ค้างที่ spawn ห่างประมาณ 56 studs และ `PunchCameraGeometryClamped=true`
  ไม่ยอม recover
- [ ] `CAM-02` ในอุโมงค์ลึก camera-to-character visibility เหลือเพียง 2.4%
  ในการทดสอบ 18 punches เพราะ opaque structural rubble/ceiling บังตัวละคร
- [ ] `CAM-03` Camera geometry guard เขียนทับ `CameraType.Scriptable` ทำให้
  cutscene, QC camera และ Studio test control ตั้งมุมกล้องไม่ได้
- [ ] `CAM-04` การแก้ต้องไม่ซูมเข้าฝืนค่าผู้เล่น ไม่ทำวัตถุโปร่ง และยังคง delayed
  smooth follow ตามข้อกำหนดเดิม

### P1 - Onboarding and Navigation

- [ ] `ONB-01` Spawn หันเข้าหากำแพง World 1 ทั้งที่ objective แรกคือ Training
- [ ] `ONB-02` มุมแรกถูกกำแพงสีเทาครอบทั้งจอ ทำให้ผู้เล่นใหม่ไม่เห็น Power Camp
  หรือทิศทางที่จะเริ่มเล่น
- [ ] `ONB-03` ยืนยันหลังแก้ว่า waypoint ยังชี้ Power Bag, objective แสดงระยะ
  และ context action ไม่ขึ้นก่อนเข้า range

### P1 - Automation Reliability

- [ ] `TEST-01` เก็บ punch phase ด้วย attribute-change signal ก่อนกด Punch
  เพื่อไม่พลาด Windup เมื่อ invoke ใช้เวลานาน
- [ ] `TEST-02` ปรับ structural expectations ให้สัมพันธ์กับ wall rows ปัจจุบัน
  และยังตรวจ server ownership/settled rubble ครบ
- [ ] `TEST-03` รอ WorldReset feedback แบบ polling มี timeout แทน fixed 0.25s
- [ ] `TEST-04` วัด camera zoom จาก camera-to-character orbit distanceหลัง settle
  ไม่ใช้ `CFrame` ถึง `Focus` เพียงอย่างเดียว

### P2 - Visual and UX Follow-up

- [ ] `VIS-01` แคป spawn, training, armory, premium pets, depth entrance,
  deep tunnel, shop, spin และ mobile HUD หลัง camera fix
- [ ] `VIS-02` ตรวจ icon crop, text overflow, modal safe area, NPC silhouette,
  pet/fist alignment, wall material repetition และ scene readability
- [ ] `VIS-03` ตรวจ motion จาก player view: punch, training dummy, coin collect,
  pet follow, rubble collapse และ camera catch-up

## Acceptance Gate

- P0/P1 backlog ปิดครบ
- failing baseline flows กลับมา `ok: true`
- `run-video-qc-regression.ps1 -Profile Full` ผ่าน
- critical feature matrix และ fresh production RBXLX ผ่าน console-clean validation
- Studio กลับ Edit mode, temporary validation files ถูกลบ และ git worktree สะอาด
