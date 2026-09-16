ไฟล์เพลงที่ใช้ในม็อดนี้ (ไฟล์ .ogg ไม่รวมมาให้เพราะเป็นเพลงมีลิขสิทธิ์)
================================================================================

เก็บไฟล์เพลงทั้งหมดไว้แบบแฟลตในโฟลเดอร์นี้เลย ไม่แยกโฟลเดอร์ย่อยต่อแฟรนไชส์แล้ว:

  JoJo_SonoChiNoSadame.ogg      -- Sono Chi no Sadame (Phantom Blood/Battle Tendency OP) -- 92s
  JoJo_BloodyStream.ogg         -- Bloody Stream (Stardust Crusaders OP1) -- 90s
  JoJo_FightingGold.ogg         -- Fighting Gold (Golden Wind OP1) -- 253s
  JoJo_GiornosTheme.ogg         -- Giorno's Theme (Golden Wind OP2) -- 296s
  HeMan_HEYYEYAAEYAAAEYAEYAA.ogg -- HEYYEYAAEYAAAEYAEYAA -- 127s
  Bothnia_SomedayIllWait.ogg    -- Bothnia - Someday I'll Wait -- 193s
  VioletteWautier_WannaBeYours.ogg -- Violette Wautier - Wanna Be Yours -- 230s
  HSR_WhattheRippleSees.ogg     -- Honkai: Star Rail - What the Ripple Sees -- 259s

มีไฟล์ครบทั้ง 8 แล้ว

เพลงแต่ละเพลงลงทะเบียนไว้ในหลายเครื่องดนตรีตามลักษณะดนตรีจริง ไม่ได้ผูกกับเครื่องดนตรีเดียว
(ดูรายละเอียดที่ ../lua/client/TimedActions/AddMoreTracks_HARMONIE.lua -- ไฟล์เดียวรวมทุกเพลง
ไม่แยกไฟล์ตามแฟรนไชส์แล้ว):

  Sono Chi no Sadame -> กีตาร์ไฟฟ้า, แซกโซโฟน, ทรัมเป็ต (brass + กีตาร์ไฟฟ้าหนักๆ)
  Bloody Stream      -> เบสไฟฟ้า, แซกโซโฟน, ทรัมเป็ต (เบสไลน์ดิสโก้ + brass)
  Fighting Gold      -> กีตาร์ไฟฟ้า, เบสไฟฟ้า, คีย์ทาร์ (ร็อกผสมออร์เคสตรา -- คีย์ทาร์แทนเสียง
                         ออร์เคสตรา/คีย์บอร์ด เพราะเปียโนไม่อยู่ในระบบ addon ที่ Lifestyle รองรับ)
  Giorno's Theme     -> แซกโซโฟน, คีย์ทาร์ (สแกต/แซกโซโฟน ไปสู่ piano breakdown -- คีย์ทาร์
                         แทนเปียโนด้วยเหตุผลเดียวกัน)
  HEYYEYAAEYAAAEYAEYAA -> ฮาโมนิกา, คีย์ทาร์ (แทนคีย์บอร์ด), ขลุ่ย
  Bothnia - Someday I'll Wait -> กีตาร์โปร่ง (acoustic) เท่านั้น -- ขอ ukulele ไว้ด้วยถ้ามี แต่
                         Lifestyle ไม่มีโมดูล PlayUkuleleTracks ในระบบ addon นี้ (ไม่ใช่ 1 ใน 10
                         เครื่องดนตรีที่รองรับ) เลยใช้กีตาร์โปร่งแทน
  Violette Wautier - Wanna Be Yours -> คีย์ทาร์ (แทนเปียโน ด้วยเหตุผลเดียวกับ Fighting
                         Gold/Giorno's Theme -- เปียโนไม่อยู่ในระบบ addon นี้)
  Honkai: Star Rail - What the Ripple Sees -> ไวโอลิน (เครื่องดนตรีที่ 10 ที่เพิ่งยืนยันว่า
                         Lifestyle รองรับ)

หลังเพิ่ม/แก้ไฟล์เพลงใหม่แล้วเข้าเกมไปเปิดเมนูเครื่องดนตรี แล้วไม่เห็นเพลงใหม่ในรายการเลย (ไม่ใช่
แค่เพลง addon ของเรา แต่เพลง vanilla ของ Lifestyle เองก็ไม่ขึ้นด้วย) หรือเห็นแต่กดเล่นแล้วเงียบไม่มี
เสียงออกเลย -- มี 2 สาเหตุที่เคยเจอจริง ต้องแยกให้ออก:
--------------------------------------------------------------------------------
(1) *** ยังไม่ได้กด "Debug - Learn All" (แก้คำอธิบายผิดเดิม 2026-09-17) ***
Lifestyle: Hobbies **ไม่ auto-learn เพลงให้เองตอนเปิดเมนูครั้งแรก** อย่างที่เคยเข้าใจผิดไว้ --
เช็คโค้ดจริงแล้วพบว่ารายชื่อเพลงที่เล่นได้ (player:getModData().<Instrument>LearnedTracks เช่น
GuitarELearnedTracks) จะว่างเปล่าตลอดจนกว่าจะ (ก) กดปุ่ม "Debug - Learn All" ในเมนูเครื่องดนตรี
เอง (มีไอคอนแมลงอยู่ใกล้ด้านบนเมนู, ใน singleplayer เห็นปุ่มนี้เสมอเพราะเป็น admin โดยปริยาย) หรือ
(ข) เล่น "Practice" แล้วมีโอกาสสุ่มเรียนรู้ทีละเพลง -- เซฟใหม่เอี่ยมที่ไม่เคยกด Debug - Learn All
เลยจะไม่มีเพลงโชว์สักเพลงเดียว ไม่ใช่บั๊กของ addon นี้

วิธีแก้: ถือเครื่องดนตรี เปิดเมนู กด **"Debug - Learn All"** หนึ่งครั้ง แล้วเปิดเมนูใหม่อีกรอบ --
จะเห็นเพลงทั้ง vanilla และ addon ครบ ถ้าเคยกด Debug - Learn All ไปแล้วก่อนหน้านี้ (มีเพลงเก่าค้าง
ที่ field ยังไม่ sync กับไฟล์ .lua ปัจจุบัน เช่น length เปลี่ยนไปแล้วแต่ค่าเก่ายังค้าง) ให้เคลียร์
ก่อนด้วย debug console (เปลี่ยนชื่อฟิลด์ตามเครื่องดนตรี):

  getPlayer():getModData().GuitarELearnedTracks = {}

แล้วกด "Debug - Learn All" ใหม่อีกรอบ (แค่เคลียร์เฉยๆ ไม่กด Debug - Learn All ต่อ เพลงจะไม่กลับมา
เองเลย)

(2) *** เกมโหลดม็อดจากคนละโฟลเดอร์กับที่แก้ (ยืนยันแล้ว 2026-09-16) ***
ถ้าม็อดนี้เคย publish ขึ้น Steam Workshop แล้ว เกมอาจโหลดจาก Workshop/HARMONIE_LifestyleAudioTune/
Contents/mods/... (staging สำหรับอัปโหลด) แทนที่จะโหลดจาก mods/ ตรงนี้ที่แก้ไฟล์อยู่ -- ทำให้แก้
โค้ด/เพิ่มไฟล์เสียงที่นี่แล้ว "ดูเหมือนไม่มีผล" เลย

วิธีเช็ค/แก้: รัน mods/check_workshop_sync.sh (read-only, เช็คทุก mod) แล้วรัน
mods/sync_to_workshop.sh HARMONIE_LifestyleAudioTune 42 ถ้าเจอ DRIFT ก่อนไปสงสัยสาเหตุ (1) เสมอ
-- ไฟล์เสียง .ogg ไม่ถูก git track จึงไม่ sync อัตโนมัติ ต้องรันสคริปต์นี้ (หรือก็อปมือ) ทุกครั้ง
ที่เพิ่ม/เปลี่ยนไฟล์เสียง

รายละเอียดเพิ่มเติมดูได้ที่ mods/workflow.txt หัวข้อ 1 และ 6.1

ทำไมไม่มีไฟล์เพลงมาให้ (สำหรับใครที่ยังไม่มีไฟล์): เพลงพวกนี้เป็นเพลงมีลิขสิทธิ์ (JoJo's Bizarre
Adventure -- Yugo Kanno / Coda และค่ายเพลงญี่ปุ่นที่เกี่ยวข้อง / HEYYEYAAEYAAAEYAEYAA -- ค่ายเพลง
ที่เกี่ยวข้อง) Claude ไม่สามารถหา/ดาวน์โหลดไฟล์เสียงลิขสิทธิ์มาฝังใน mod ให้ได้ ต้องเป็นไฟล์ที่พี่มี
สิทธิ์ใช้เองเท่านั้น ถ้าตั้งใจจะเอา mod นี้ขึ้น Steam Workshop สาธารณะ ควรพิจารณาเรื่องลิขสิทธิ์ให้
รอบคอบก่อนด้วย
