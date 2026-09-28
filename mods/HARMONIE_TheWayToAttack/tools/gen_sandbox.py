#!/usr/bin/env python3
"""Generates HARMONIE_TheWayToAttack's sandbox options from ONE table.

Writes (under ../42/media/):
  sandbox-options.txt                         the options, grouped in pages
  lua/shared/HARMONIE_TWA_ConfigDefaults.lua  TWAConfig.DEFAULTS (same values)
  lua/shared/Translate/EN|TH/Sandbox.json     names + tooltips (rewritten)

Run: python3 gen_sandbox.py   (from anywhere). Round 9 request 2026-09-28:
"ทำ sandbox แบบละเอียด ทุกค่าตัวเลข และ true false ที่อยู่ในม็อดต้องสามารถปรับได้
ทุกอัน จัดหมวดหมู่ให้เรียบร้อย ใช้ง่าย". Add a row here, run it, then read the
value in code with TWAConfig.get("Key").
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "42", "media")
MOD = "HARMONIE_TheWayToAttack"

# page id -> (EN title, TH title). Order = order of the tabs.
PAGES = [
    ("HARMONIE_TheWayToAttack", "TWA 1. General crafting", "TWA 1. การคราฟทั่วไป"),
    ("HARMONIE_TWA_Quality", "TWA 2. Quality & grade", "TWA 2. คุณภาพและเกรด"),
    ("HARMONIE_TWA_Minigame", "TWA 3. Minigames (all)", "TWA 3. มินิเกม (ทั้งหมด)"),
    ("HARMONIE_TWA_Hammer", "TWA 4. Hammering & forging", "TWA 4. ตอก ตี และตีเหล็ก"),
    ("HARMONIE_TWA_Stroke", "TWA 5. Sharpen, saw, weld", "TWA 5. ลับ เลื่อย เชื่อม"),
    ("HARMONIE_TWA_Wrap", "TWA 6. Wrap, screw, grind", "TWA 6. พัน ขันน็อต ลับหินหมุน"),
    ("HARMONIE_TWA_Heat", "TWA 7. Heat, quench, bend", "TWA 7. เป่าลม จุ่มน้ำ หักกิ่ง"),
    ("HARMONIE_TWA_Other", "TWA 8. Coat, pour, sew, drill, carve", "TWA 8. เคลือบ เท เย็บ เจาะ กรีด"),
]

# key, type, default, min, max, page, EN name, TH name, EN tip, TH tip
B, I, D = "boolean", "integer", "double"
OPTS = [
 # ---- General
 ("EnableMinigame", B, True, None, None, "HARMONIE_TheWayToAttack", "Procedure minigames", "มินิเกมกรรมวิธี",
  "Play a minigame for every crafting procedure and score it Miss/Bad/Good/Excellent. When off, every procedure runs as a plain progress bar and always scores Excellent.",
  "เล่นมินิเกมทุกครั้งที่ทำกรรมวิธี และให้คะแนน พลาด/แย่/ดี/เยี่ยม ถ้าปิด กรรมวิธีจะเป็นแถบเวลาธรรมดาและได้ เยี่ยม เสมอ"),
 ("MinigameSounds", B, True, None, None, "HARMONIE_TheWayToAttack", "Minigame sounds", "เสียงในมินิเกม",
  "Play the procedure's working sound while you work in a minigame (hammer blows, the whetstone, the saw, the torch...).",
  "เล่นเสียงประกอบระหว่างเล่นมินิเกม (ตอกค้อน ลับหิน เลื่อย เป่าไฟเชื่อม ฯลฯ)"),
 ("CraftButtonSeconds", D, 3.0, 0.1, 60.0, "HARMONIE_TheWayToAttack", "Start/Cancel/Incomplete/Finish time (seconds)", "เวลาปุ่ม เริ่มทำ/ยกเลิก/ไม่สมบูรณ์/เสร็จสิ้น (วินาที)",
  "How long the Start, Cancel, Incomplete and Finish actions take, in real seconds.",
  "ระยะเวลาของการกด เริ่มทำ ยกเลิก ไม่สมบูรณ์ และเสร็จสิ้น เป็นวินาทีจริง"),
 ("ProcedureSeconds", D, 3.0, 0.1, 60.0, "HARMONIE_TheWayToAttack", "Procedure time (seconds)", "เวลาทำกรรมวิธี (วินาที)",
  "How long the time bar after a procedure's minigame takes, in real seconds (every procedure).",
  "ระยะเวลาของแถบเวลาหลังเล่นมินิเกมของกรรมวิธี เป็นวินาทีจริง (ทุกกรรมวิธี)"),
 ("NearbyRadius", I, 1, 0, 3, "HARMONIE_TheWayToAttack", "Use items nearby (tiles)", "ใช้ของที่อยู่รอบตัว (ช่อง)",
  "Tools, materials and base items are also found in containers and on the floor this many tiles around you. 0 = only what you carry.",
  "เครื่องมือ วัตถุดิบ และวัตถุดิบตั้งต้น หาได้จากกล่องและบนพื้นรอบตัวในระยะกี่ช่อง 0 = ใช้ได้เฉพาะของที่พกติดตัว"),
 ("ProcedureXPMultiplier", D, 1.0, 0.0, 10.0, "HARMONIE_TheWayToAttack", "Procedure XP multiplier", "ตัวคูณ XP จากกรรมวิธี",
  "Multiplies the skill XP a finished procedure gives (base: 5 x the procedure's skill level). 0 = no XP.",
  "คูณ XP ที่ได้จากกรรมวิธีที่ทำสำเร็จ (ฐาน: 5 x เลเวลสกิลที่กรรมวิธีต้องการ) 0 = ไม่ได้ XP"),
 ("RequireLight", B, True, None, None, "HARMONIE_TheWayToAttack", "Procedures need light", "ทำกรรมวิธีต้องมีแสง",
  "A procedure can't be done where it is too dark to read.", "ทำกรรมวิธีไม่ได้ถ้ามืดจนอ่านหนังสือไม่ได้"),
 ("RequireForge", B, True, None, None, "HARMONIE_TheWayToAttack", "Forging needs a forge", "การตีเหล็กต้องมีเตา",
  "Forging procedures need a forge of the right level nearby. Off: they can be done anywhere.",
  "กรรมวิธีตีเหล็กต้องมีเตาระดับที่ถึงอยู่ใกล้ๆ ถ้าปิด ทำได้ทุกที่"),
 ("ForgeSearchRadius", I, 3, 1, 10, "HARMONIE_TheWayToAttack", "Forge search distance (tiles)", "ระยะค้นหาเตา (ช่อง)",
  "How many tiles around you a forge is looked for.", "ค้นหาเตารอบตัวกี่ช่อง"),
 ("MissUsesMaterials", B, True, None, None, "HARMONIE_TheWayToAttack", "A Miss still uses materials", "พลาดแล้วยังเสียวัตถุดิบ",
  "A procedure scored Miss still uses up its materials (it is not counted as done either way).",
  "กรรมวิธีที่ได้ พลาด ยังเสียวัตถุดิบ (และไม่นับว่าทำแล้วอยู่ดี)"),
 ("IncompleteZeroDamage", B, True, None, None, "HARMONIE_TheWayToAttack", "Unfinished items do 0 damage", "ไอเท็มที่ยังไม่เสร็จดาเมจเป็น 0",
  "An item left Incomplete (or with the window closed) has its damage set to 0 until the craft is finished.",
  "ไอเท็มที่กดไม่สมบูรณ์ (หรือปิดหน้าต่าง) จะมีดาเมจเป็น 0 จนกว่าจะทำเสร็จ"),
 ("ActionSounds", B, True, None, None, "HARMONIE_TheWayToAttack", "Crafting action sounds", "เสียงระหว่างแถบเวลาคราฟ",
  "Working sounds while a procedure's time bar or Start/Cancel/Incomplete/Finish runs.",
  "เสียงประกอบระหว่างแถบเวลาของกรรมวิธี และปุ่ม เริ่มทำ/ยกเลิก/ไม่สมบูรณ์/เสร็จสิ้น"),
 ("GradeReveal", B, True, None, None, "HARMONIE_TheWayToAttack", "Grade reveal show after Finish", "ฉากเปิดเกรดหลังกดเสร็จสิ้น",
  "After Finish, a short show: the hammer on the anvil until the rolled grade appears (for the Gemstone recipe: the stone cracking open while the roll spins).",
  "หลังกดเสร็จสิ้น มีฉากค้อนตีบนทั่งจนเกรดที่สุ่มได้ปรากฏ (สูตรหินมณี: ฉากหินแตกออกพร้อมวงล้อสุ่มไอเท็ม)"),
 ("AllowWeaponDebug", B, True, None, None, "HARMONIE_TheWayToAttack", "Weapon stat debug editor (admins / -debug)", "ตัวแก้ stats อาวุธสำหรับดีบัก (แอดมิน / -debug)",
  "Admins, and anyone running with -debug, can right-click a weapon to edit every stat it has. Off: the menu never appears.",
  "แอดมิน และผู้ที่เปิดเกมด้วย -debug คลิกขวาอาวุธเพื่อแก้ stats ได้ทุกค่า ถ้าปิด เมนูนี้จะไม่แสดงเลย"),
 # ---- Quality & grade
 ("BadBelow", D, 2.0, 0.0, 3.0, "HARMONIE_TWA_Quality", "Overall Bad below", "คุณภาพรวม แย่ ถ้าต่ำกว่า",
  "The procedures' average score (Bad=1, Good=2, Excellent=3) below this is an overall Bad.",
  "ค่าเฉลี่ยคะแนนกรรมวิธี (แย่=1 ดี=2 เยี่ยม=3) ที่ต่ำกว่าค่านี้ = คุณภาพรวม แย่"),
 ("GoodBelow", D, 2.5, 0.0, 3.0, "HARMONIE_TWA_Quality", "Overall Good below", "คุณภาพรวม ดี ถ้าต่ำกว่า",
  "An average below this (and not Bad) is Good; at or above it, Excellent.",
  "ค่าเฉลี่ยที่ต่ำกว่าค่านี้ (และไม่แย่) = ดี ถ้าถึงค่านี้ = เยี่ยม"),
 ("GradeChance1", I, 1, 0, 100, "HARMONIE_TWA_Quality", "Grade chance: 1st (best) of the pool", "โอกาสเกรด: อันดับ 1 (ดีสุด) ของกลุ่ม",
  "Pools: Excellent S/A/B/C/D, Good A/B/C/D/E, Bad B/C/D/E/F. Chance weight of the pool's 1st grade.",
  "กลุ่มเกรด: เยี่ยม S/A/B/C/D, ดี A/B/C/D/E, แย่ B/C/D/E/F น้ำหนักโอกาสของเกรดอันดับ 1 ในกลุ่ม"),
 ("GradeChance2", I, 9, 0, 100, "HARMONIE_TWA_Quality", "Grade chance: 2nd", "โอกาสเกรด: อันดับ 2",
  "Chance weight of the pool's 2nd grade.", "น้ำหนักโอกาสของเกรดอันดับ 2 ในกลุ่ม"),
 ("GradeChance3", I, 20, 0, 100, "HARMONIE_TWA_Quality", "Grade chance: 3rd", "โอกาสเกรด: อันดับ 3",
  "Chance weight of the pool's 3rd grade.", "น้ำหนักโอกาสของเกรดอันดับ 3 ในกลุ่ม"),
 ("GradeChance4", I, 30, 0, 100, "HARMONIE_TWA_Quality", "Grade chance: 4th", "โอกาสเกรด: อันดับ 4",
  "Chance weight of the pool's 4th grade.", "น้ำหนักโอกาสของเกรดอันดับ 4 ในกลุ่ม"),
 ("GradeChance5", I, 40, 0, 100, "HARMONIE_TWA_Quality", "Grade chance: 5th (worst)", "โอกาสเกรด: อันดับ 5 (แย่สุด)",
  "Chance weight of the pool's 5th grade. The five weights need not add up to 100.",
  "น้ำหนักโอกาสของเกรดอันดับ 5 ในกลุ่ม ทั้ง 5 ค่าไม่จำเป็นต้องรวมได้ 100"),
 ("MaterialNeedsGood", B, True, None, None, "HARMONIE_TWA_Quality", "Materials need Good or better to finish", "วัตถุดิบต้องได้ ดี ขึ้นไปจึงเสร็จได้",
  "Material recipes can only be finished at an overall quality of Good or Excellent.",
  "สูตรวัตถุดิบกดเสร็จสิ้นได้เมื่อคุณภาพรวม ดี หรือ เยี่ยม เท่านั้น"),
 ("GemGoodChance", I, 25, 0, 100, "HARMONIE_TWA_Quality", "Gemstone: chance of a gem (percent)", "หินมณี: โอกาสได้อัญมณี (เปอร์เซ็นต์)",
  "Finishing the Gemstone recipe rolls what the stone held: this percent gives a gem (every gem equal, the diamond the rarest); the rest gives clay, scrap metal, limestone, charcoal, coke or dung.",
  "เมื่อทำสูตรหินมณีเสร็จจะสุ่มสิ่งที่อยู่ในหิน: ค่านี้คือเปอร์เซ็นต์ที่ได้อัญมณี (ทุกชนิดเท่ากัน เพชรน้อยที่สุด) ที่เหลือได้ ดินเหนียว เศษโลหะ หินปูน ถ่านไม้ ถ่านโค้ก หรือมูลสัตว์"),
 ("GemDiamondShare", I, 4, 0, 100, "HARMONIE_TWA_Quality", "Gemstone: diamond's share of the gem chance (percent)", "หินมณี: ส่วนของเพชรในโอกาสอัญมณี (เปอร์เซ็นต์)",
  "Of the gem chance above, the diamond gets this percent; the other gems share the rest equally. Default 4 = 1 percent of all rolls.",
  "จากโอกาสอัญมณีข้างบน เพชรได้ส่วนนี้ ที่เหลือแบ่งให้อัญมณีอื่นเท่าๆกัน ค่าเริ่มต้น 4 = 1 เปอร์เซ็นต์ของการสุ่มทั้งหมด"),
 ("MinigameExcellentAt", D, 0.85, 0.0, 1.0, "HARMONIE_TWA_Quality", "Minigame: Excellent from", "มินิเกม: เยี่ยม ตั้งแต่",
  "The quality meter left at the end (0-1) from which a minigame scores Excellent.",
  "เกจคุณภาพที่เหลือตอนจบ (0-1) ตั้งแต่ค่านี้ได้ เยี่ยม"),
 ("MinigameGoodAt", D, 0.6, 0.0, 1.0, "HARMONIE_TWA_Quality", "Minigame: Good from", "มินิเกม: ดี ตั้งแต่",
  "From this (and below Excellent) a minigame scores Good; below it, Bad.",
  "ตั้งแต่ค่านี้ (และต่ำกว่าเยี่ยม) ได้ ดี ต่ำกว่านี้ได้ แย่"),
 # ---- Minigames (all)
 ("QualityDrain", D, 2.0, 0.1, 10.0, "HARMONIE_TWA_Minigame", "Quality loss per mistake", "ความแรงของการเสียคุณภาพ",
  "Multiplies how much quality every mistake costs in every minigame.", "คูณคุณภาพที่เสียต่อความผิดพลาดในทุกมินิเกม"),
 ("QualityZeroIsMiss", B, True, None, None, "HARMONIE_TWA_Minigame", "Empty quality ends as Miss", "คุณภาพหมด = พลาดทันที",
  "When the quality meter hits 0 the minigame ends at once as a Miss.", "เมื่อเกจคุณภาพเหลือ 0 จบมินิเกมเป็น พลาด ทันที"),
 ("ZoneSize", D, 1.0, 0.25, 4.0, "HARMONIE_TWA_Minigame", "Zone size multiplier", "ตัวคูณขนาดโซน",
  "Makes every zone, band and allowance in every minigame bigger (>1) or smaller (<1).",
  "ทำให้โซนและระยะที่ยอมให้ในทุกมินิเกมใหญ่ขึ้น (>1) หรือเล็กลง (<1)"),
 ("GameSpeed", D, 1.0, 0.25, 4.0, "HARMONIE_TWA_Minigame", "Minigame speed multiplier", "ตัวคูณความเร็วมินิเกม",
  "Makes the moving parts of every minigame faster (>1) or slower (<1).", "ทำให้สิ่งที่เคลื่อนที่ในทุกมินิเกมเร็วขึ้น (>1) หรือช้าลง (<1)"),
 ("TimeLimit", D, 1.0, 0.25, 5.0, "HARMONIE_TWA_Minigame", "Time limit multiplier", "ตัวคูณเวลาจำกัด",
  "Multiplies every minigame's time limit.", "คูณเวลาจำกัดของทุกมินิเกม"),
 ("HandLagMs", I, 35, 0, 300, "HARMONIE_TWA_Minigame", "Hand lag (ms)", "ความหน่วงของมือ (มิลลิวินาที)",
  "How far the tool trails the mouse. 0 = none.", "เครื่องมือตามเมาส์ช้ากว่ากี่มิลลิวินาที 0 = ไม่หน่วง"),
 ("Tremor", B, True, None, None, "HARMONIE_TWA_Minigame", "Pain/panic/drunk shake the hand", "เจ็บ/ตื่นกลัว/เมา ทำให้มือสั่น",
  "Pain, panic and drunkenness make the tool shake.", "ความเจ็บปวด ความตื่นกลัว และความเมา ทำให้เครื่องมือสั่น"),
 ("SkillZonePerLevel", D, 0.06, 0.0, 0.5, "HARMONIE_TWA_Minigame", "Zone bonus per skill level above need", "โบนัสโซนต่อเลเวลสกิลที่เกิน",
  "Each skill level above what the procedure needs widens the zones by this much (0.06 = 6 percent).",
  "ทุกเลเวลสกิลที่เกินกว่าที่กรรมวิธีต้องการ ขยายโซนเท่านี้ (0.06 = 6 เปอร์เซ็นต์)"),
 ("SkillZoneMax", D, 1.6, 1.0, 5.0, "HARMONIE_TWA_Minigame", "Zone bonus cap", "เพดานโบนัสโซน",
  "The skill zone bonus never goes above this multiplier.", "โบนัสโซนจากสกิลไม่เกินตัวคูณนี้"),
 ("SpeedPerNeededLevel", D, 0.04, 0.0, 0.5, "HARMONIE_TWA_Minigame", "Speed-up per needed level", "ความเร็วเพิ่มต่อเลเวลที่ต้องการ",
  "Harder procedures (higher needed level) run this much faster per level.", "กรรมวิธีที่ต้องการเลเวลสูง เร็วขึ้นเท่านี้ต่อเลเวล"),
 # ---- Hammering
 ("StrikeRingSize", I, 140, 40, 300, "HARMONIE_TWA_Hammer", "Hammer ring start size", "ขนาดวงเริ่มของการตี",
  "Radius (px) the timing ring starts at.", "รัศมี (พิกเซล) ที่วงจังหวะเริ่มหด"),
 ("StrikeRingMs", I, 900, 200, 5000, "HARMONIE_TWA_Hammer", "Hammer ring close time (ms)", "เวลาที่วงหดจนสุด (มิลลิวินาที)",
  "How long the ring takes to close. Lower = faster.", "วงหดจนถึงจุดใช้เวลากี่มิลลิวินาที น้อย = เร็ว"),
 ("StrikeWindowMs", I, 115, 10, 500, "HARMONIE_TWA_Hammer", "Hammer timing window (ms)", "ช่วงจังหวะที่นับว่าตรง (มิลลิวินาที)",
  "How early/late a blow may land and still count (perfect is 45 percent of it).", "ตีเร็ว/ช้าได้กี่มิลลิวินาทีแล้วยังนับ (เป๊ะ = 45 เปอร์เซ็นต์ของค่านี้)"),
 ("StrikeMarkSize", I, 22, 5, 80, "HARMONIE_TWA_Hammer", "Lit mark size", "ขนาดจุดสว่าง",
  "Radius (px) of the lit mark the hammer must land on.", "รัศมี (พิกเซล) ของจุดสว่างที่ต้องวางค้อน"),
 ("SmashOneBlow", B, True, None, None, "HARMONIE_TWA_Hammer", "Smashing takes one blow", "ทุบครั้งเดียวจบ",
  "Smashing (a bottle) is done in one timed blow.", "การทุบ (ขวด) จบในการตีครั้งเดียว"),
 ("ForgeCool1", I, 14000, 1000, 120000, "HARMONIE_TWA_Hammer", "Forge level 1 cooling (ms)", "เหล็กเย็นลง ตีเหล็กระดับ 1 (มิลลิวินาที)",
  "Hot-to-cold time on the first forging procedure (Forge Shape). Lower = cools faster.",
  "เวลาที่เหล็กร้อนจนเย็นในกรรมวิธีขึ้นรูประดับ 1 น้อย = เย็นเร็ว"),
 ("ForgeCool2", I, 10500, 1000, 120000, "HARMONIE_TWA_Hammer", "Forge level 2 cooling (ms)", "เหล็กเย็นลง ระดับ 2 (มิลลิวินาที)",
  "Hot-to-cold time for Forge Fold.", "เวลาเหล็กเย็นสำหรับการพับเหล็ก"),
 ("ForgeCool3", I, 8000, 1000, 120000, "HARMONIE_TWA_Hammer", "Forge level 3 cooling (ms)", "เหล็กเย็นลง ระดับ 3 (มิลลิวินาที)",
  "Hot-to-cold time for Forge Complex.", "เวลาเหล็กเย็นสำหรับการตีขึ้นรูปซับซ้อน"),
 ("ForgeCool4", I, 6000, 1000, 120000, "HARMONIE_TWA_Hammer", "Forge level 4 cooling (ms)", "เหล็กเย็นลง ระดับ 4 (มิลลิวินาที)",
  "Hot-to-cold time for Forge Vacuum.", "เวลาเหล็กเย็นสำหรับการตีในสุญญากาศ"),
 ("ForgeReheatMs", I, 1800, 200, 20000, "HARMONIE_TWA_Hammer", "Reheat time on the coals (ms)", "เวลาอุ่นบนถ่าน (มิลลิวินาที)",
  "How long holding on the coals takes to bring the bar from cold to full heat.", "กดค้างบนถ่านนานเท่านี้ เหล็กจากเย็นจะร้อนเต็ม"),
 # ---- Stroke
 ("SharpenStrokes", I, 10, 1, 40, "HARMONIE_TWA_Stroke", "Sharpening flicks", "จำนวนครั้งการลับ",
  "How many counted flicks sharpening needs.", "การลับต้องสะบัดที่นับได้กี่ครั้ง"),
 ("PolishStrokes", I, 10, 1, 40, "HARMONIE_TWA_Stroke", "Polishing flicks", "จำนวนครั้งการขัด",
  "How many counted flicks polishing needs.", "การขัดต้องสะบัดที่นับได้กี่ครั้ง"),
 ("FlickMinSpeed", D, 0.8, 0.05, 5.0, "HARMONIE_TWA_Stroke", "Flick minimum speed", "ความเร็วขั้นต่ำของการสะบัด",
  "Average speed (px/ms) a sharpening/polishing flick needs to count. Slower costs quality.",
  "ความเร็วเฉลี่ย (พิกเซล/มิลลิวินาที) ที่การสะบัดลับ/ขัดต้องถึงจึงนับ ช้ากว่านี้เสียคุณภาพ"),
 ("SharpenZone", D, 12.0, 2.0, 60.0, "HARMONIE_TWA_Stroke", "Sharpening zone (px)", "โซนการลับ (พิกเซล)",
  "Half-width of the sharpening zone.", "ความกว้างครึ่งหนึ่งของโซนการลับ"),
 ("PolishZone", D, 14.0, 2.0, 60.0, "HARMONIE_TWA_Stroke", "Polishing zone (px)", "โซนการขัด (พิกเซล)",
  "Half-width of the polishing zone.", "ความกว้างครึ่งหนึ่งของโซนการขัด"),
 ("SawStrokes", I, 20, 1, 60, "HARMONIE_TWA_Stroke", "Saw strokes", "จำนวนครั้งการเลื่อย",
  "Back-and-forth strokes sawing needs.", "จำนวนครั้งที่ต้องเลื่อยไป-กลับ"),
 ("SawZone", D, 21.0, 2.0, 80.0, "HARMONIE_TWA_Stroke", "Saw zone (px)", "โซนการเลื่อย (พิกเซล)",
  "Half-width of the sawing zone.", "ความกว้างครึ่งหนึ่งของโซนการเลื่อย"),
 ("WeldZone", D, 8.0, 2.0, 60.0, "HARMONIE_TWA_Stroke", "Weld zone (px)", "โซนการเชื่อม (พิกเซล)",
  "Half-width of the weld zone.", "ความกว้างครึ่งหนึ่งของโซนการเชื่อม"),
 ("WeldZigzag", B, True, None, None, "HARMONIE_TWA_Stroke", "Weld along a zig-zag", "เชื่อมแบบฟันปลา",
  "The weld follows a zig-zag weave. Off: a straight seam.", "การเชื่อมเดินตามแนวฟันปลา ถ้าปิดเป็นเส้นตรง"),
 ("WeldMaxSpeed", D, 0.22, 0.02, 3.0, "HARMONIE_TWA_Stroke", "Weld maximum speed", "ความเร็วสูงสุดของการเชื่อม",
  "Faster than this (px/ms) leaves gaps and costs quality.", "เร็วกว่านี้ (พิกเซล/มิลลิวินาที) เนื้อเชื่อมเป็นรูและเสียคุณภาพ"),
 ("WeldBurnSpeed", D, 0.025, 0.0, 1.0, "HARMONIE_TWA_Stroke", "Weld burn-through speed", "ความเร็วที่เริ่มไหม้",
  "Slower than this (px/ms) burns through and costs quality. 0 = never burns.", "ช้ากว่านี้ (พิกเซล/มิลลิวินาที) จะไหม้และเสียคุณภาพ 0 = ไม่ไหม้"),
 # ---- Wrap
 ("WrapZone", D, 10.0, 2.0, 60.0, "HARMONIE_TWA_Wrap", "Wrapping zone (px)", "โซนการพัน (พิกเซล)",
  "Half-width of the circle zone for wrapping, screwing and drilling.", "ความกว้างครึ่งหนึ่งของโซนวงกลมสำหรับพัน ขันน็อต เจาะ"),
 ("ClothZoneMultiplier", D, 2.0, 0.25, 5.0, "HARMONIE_TWA_Wrap", "Cloth wrap zone multiplier", "ตัวคูณโซนพันผ้า",
  "Extra multiplier on the zone for cloth wraps.", "ตัวคูณโซนเพิ่มสำหรับการพันผ้า"),
 ("TapeZoneMultiplier", D, 2.0, 0.25, 5.0, "HARMONIE_TWA_Wrap", "Binding wrap zone multiplier", "ตัวคูณโซนพันยึด",
  "Extra multiplier on the zone for binding (tape) wraps.", "ตัวคูณโซนเพิ่มสำหรับการพันยึด"),
 ("ScrewTurns", D, 3.0, 1.0, 10.0, "HARMONIE_TWA_Wrap", "Screw turns to snug", "จำนวนรอบขันจนแน่น",
  "How many turns tighten a screw/bolt.", "ขันกี่รอบจึงแน่นพอดี"),
 ("ScrewStripAt", D, 0.5, 0.05, 3.0, "HARMONIE_TWA_Wrap", "Screw strips after (turns)", "เกลียวหวานเมื่อเกิน (รอบ)",
  "Turning this far past snug strips the thread.", "ขันเกินจุดแน่นเท่านี้เกลียวจะหวาน"),
 ("ScrewSnugSlack", D, 0.05, 0.0, 0.5, "HARMONIE_TWA_Wrap", "Snug allowance (turns)", "ระยะยอมให้ก่อนแน่น (รอบ)",
  "Letting go this close under snug still counts.", "ปล่อยก่อนแน่นไม่เกินเท่านี้ยังนับว่าแน่น"),
 ("GrindMinSpeed", D, 0.55, 0.05, 5.0, "HARMONIE_TWA_Wrap", "Grindstone minimum crank speed", "ความเร็วหมุนต่ำสุดของหินลับ",
  "Turns per second the grindstone needs to bite.", "รอบต่อวินาทีที่หินลับต้องถึงจึงกินเนื้อ"),
 ("GrindMaxSpeed", D, 1.25, 0.1, 10.0, "HARMONIE_TWA_Wrap", "Grindstone maximum crank speed", "ความเร็วหมุนสูงสุดของหินลับ",
  "Faster than this costs quality.", "หมุนเร็วกว่านี้เสียคุณภาพ"),
 # ---- Heat
 ("HeatZone", D, 0.035, 0.005, 0.3, "HARMONIE_TWA_Heat", "Heat band half-width", "ครึ่งความกว้างแถบความร้อน",
  "Half-width of the temperature band for fire, melting, annealing and bending (gauge 0-1.2).",
  "ครึ่งความกว้างของแถบอุณหภูมิ สำหรับก่อไฟ หลอม อบ และหักกิ่ง (เกจ 0-1.2)"),
 ("CoolZone", D, 0.025, 0.005, 0.3, "HARMONIE_TWA_Heat", "Quench band half-width", "ครึ่งความกว้างแถบการจุ่มน้ำ",
  "Half-width of the band for quenching/cooling.", "ครึ่งความกว้างของแถบสำหรับการจุ่มน้ำ/ทำให้เย็น"),
 ("CoolDrain", D, 1.5, 0.1, 10.0, "HARMONIE_TWA_Heat", "Quench quality-loss multiplier", "ตัวคูณการเสียคุณภาพตอนจุ่มน้ำ",
  "Extra multiplier on quality loss while quenching.", "ตัวคูณการเสียคุณภาพเพิ่มระหว่างจุ่มน้ำ"),
 ("HeatHoldMs", I, 4000, 500, 60000, "HARMONIE_TWA_Heat", "Heat hold time (ms)", "เวลาที่ต้องคุมในแถบ (มิลลิวินาที)",
  "How long the needle must be held in the band (plus 300 ms per needed skill level).",
  "ต้องคุมเข็มในแถบนานเท่านี้ (บวก 300 มิลลิวินาทีต่อเลเวลที่ต้องการ)"),
 ("BendHoldMs", I, 1500, 200, 30000, "HARMONIE_TWA_Heat", "Branch bend hold time (ms)", "เวลาดัดกิ่ง (มิลลิวินาที)",
  "How long a branch must be held bent before it snaps cleanly.", "ต้องดัดกิ่งค้างไว้นานเท่านี้จึงหักสวย"),
 ("HeatOutsideCosts", B, True, None, None, "HARMONIE_TWA_Heat", "Leaving the band costs quality", "หลุดแถบแล้วเสียคุณภาพ",
  "Once the band has been reached, every moment outside it costs quality (also the grindstone).",
  "เมื่อเข้าแถบได้แล้ว ทุกช่วงที่อยู่นอกแถบเสียคุณภาพ (รวมหินลับหมุน)"),
 ("ZoneDrift", B, True, None, None, "HARMONIE_TWA_Minigame", "Zones move", "โซนเคลื่อนที่",
  "The target band drifts slowly back and forth while you work (heat, quench, bend, grindstone, sewing tension, carving depth, pour line).",
  "แถบเป้าหมายเลื่อนไปมาช้าๆ ระหว่างทำ (ความร้อน จุ่มน้ำ หักกิ่ง หินลับหมุน ความตึงด้าย ความลึกการกรีด เส้นเท)"),
 ("CoatCoverage", D, 0.9, 0.3, 1.0, "HARMONIE_TWA_Other", "Coating coverage needed", "พื้นที่เคลือบที่ต้องการ",
  "Fraction of the surface a coat must cover (0.9 = 90 percent).", "สัดส่วนพื้นผิวที่ต้องเคลือบให้ทั่ว (0.9 = 90 เปอร์เซ็นต์)"),
 ("PourZone", D, 0.015, 0.003, 0.2, "HARMONIE_TWA_Other", "Pour fill band half-width", "ครึ่งความกว้างแถบการเท",
  "How close to the fill line the pour must stop.", "ต้องเทให้หยุดใกล้เส้นแค่ไหน"),
 ("SutureStitches", I, 3, 1, 12, "HARMONIE_TWA_Other", "Stitches (base)", "จำนวนฝีเข็ม (ฐาน)",
  "Stitches sewing needs, plus one per two needed skill levels.", "จำนวนฝีเข็ม บวกหนึ่งทุก 2 เลเวลที่ต้องการ"),
 ("SutureZone", D, 12.0, 2.0, 60.0, "HARMONIE_TWA_Other", "Sewing zone (px)", "โซนการเย็บ (พิกเซล)",
  "Half-width of the needle's path zone.", "ความกว้างครึ่งหนึ่งของโซนเส้นทางเข็ม"),
 ("ExtractGuide", D, 4.0, 1.0, 40.0, "HARMONIE_TWA_Other", "Drill guide (px)", "แนวบังคับสว่าน (พิกเซล)",
  "How far the drill bit may lean before it snags.", "สว่านเอียงได้เท่านี้ก่อนจะติด"),
 ("ExtractMaxHoles", I, 3, 1, 6, "HARMONIE_TWA_Other", "Drill holes (max)", "จำนวนรูเจาะสูงสุด",
  "The most holes a drill core can ask for.", "จำนวนรูสูงสุดที่การเจาะแกนต้องทำ"),
 ("IncisionZone", D, 8.0, 2.0, 60.0, "HARMONIE_TWA_Other", "Carving/engraving zone (px)", "โซนการกรีด/สลัก (พิกเซล)",
  "Half-width of the cutting line zone.", "ความกว้างครึ่งหนึ่งของโซนแนวกรีด"),
 ("EngraveWideDepth", B, True, None, None, "HARMONIE_TWA_Other", "Engraving: very wide depth band", "สลักลาย: แถบความลึกกว้างมาก",
  "Engraving's depth band covers 90 percent of the gauge. Off: the same narrow band as carving.",
  "แถบความลึกของการสลักลายกว้าง 90 เปอร์เซ็นต์ของเกจ ถ้าปิดใช้แถบแคบเหมือนการกรีด"),
]

def fmt(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, float): return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else "%.1f" % v
    return str(v)

keys = set()
out = ["VERSION = 1,", ""]
for k, t, d, lo, hi, page, *_ in OPTS:
    assert k not in keys, k; keys.add(k)
    assert page in [p[0] for p in PAGES], page
    out.append("option %s.%s" % (MOD, k))
    out.append("{")
    out.append("    type = %s," % t)
    if t != B:
        out.append("    min = %s," % fmt(lo)); out.append("    max = %s," % fmt(hi))
    out.append("    default = %s," % fmt(d))
    out.append("    page = %s," % page)
    out.append("    translation = HARMONIE_TWA_%s," % k)
    out.append("}")
    out.append("")
open(os.path.join(MEDIA, "sandbox-options.txt"), "w").write("\n".join(out))

lua = ["-- GENERATED by mods/HARMONIE_TheWayToAttack/tools/gen_sandbox.py -- do not edit;",
       "-- change the table there and run it. Defaults for every sandbox option,",
       "-- read through TWAConfig.get() (HARMONIE_TWA_Config.lua).",
       "TWAConfig = TWAConfig or {}", "TWAConfig.DEFAULTS = {"]
for k, t, d, *_ in OPTS:
    lua.append("    %s = %s," % (k, fmt(d)))
lua.append("}")
open(os.path.join(MEDIA, "lua", "shared", "HARMONIE_TWA_ConfigDefaults.lua"), "w").write("\n".join(lua) + "\n")

for lang, ni, ti in (("EN", 6, 8), ("TH", 7, 9)):
    d = {}
    for pid, en, th in PAGES:
        d["Sandbox_" + pid] = en if lang == "EN" else th
    for o in OPTS:
        d["Sandbox_HARMONIE_TWA_" + o[0]] = o[ni]
        d["Sandbox_HARMONIE_TWA_" + o[0] + "_tooltip"] = o[ti]
    for v in d.values(): assert "%" not in v, v
    p = os.path.join(MEDIA, "lua", "shared", "Translate", lang, "Sandbox.json")
    open(p, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, indent=4) + "\n")
print("options:", len(OPTS))
