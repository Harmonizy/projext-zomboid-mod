ไฟล์เพลงที่ใช้ในม็อดนี้ (ไฟล์ .ogg ไม่รวมมาให้เพราะเป็นเพลงมีลิขสิทธิ์)
================================================================================

เก็บไฟล์เพลงทั้งหมดไว้แบบแฟลตในโฟลเดอร์นี้เลย ไม่แยกโฟลเดอร์ย่อยต่อแฟรนไชส์แล้ว:

  JoJo_SonoChiNoSadame.ogg      -- Sono Chi no Sadame (Phantom Blood/Battle Tendency OP) -- 92s
  JoJo_BloodyStream.ogg         -- Bloody Stream (Stardust Crusaders OP1) -- 89s
  JoJo_FightingGold.ogg         -- Fighting Gold (Golden Wind OP1) -- 253s
  JoJo_GiornosTheme.ogg         -- Giorno's Theme (Golden Wind OP2) -- 296s
  HeMan_HEYYEYAAEYAAAEYAEYAA.ogg -- HEYYEYAAEYAAAEYAEYAA -- 127s
  Bothnia_SomedayIllWait.ogg    -- Bothnia - Someday I'll Wait -- 193s
  VioletteWautier_WannaBeYours.ogg -- Violette Wautier - Wanna Be Yours -- 230s

มีไฟล์ครบทั้ง 7 แล้ว

เพลงแต่ละเพลงลงทะเบียนไว้ในหลายเครื่องดนตรีตามลักษณะดนตรีจริง ไม่ได้ผูกกับเครื่องดนตรีเดียว
(ดูรายละเอียดที่ ../lua/client/TimedActions/AddMoreTracks_HARMONIE_JoJo.lua,
AddMoreTracks_HARMONIE_HeMan.lua และ AddMoreTracks_HARMONIE_Misc.lua):

  Sono Chi no Sadame -> กีตาร์ไฟฟ้า, แซกโซโฟน, ทรัมเป็ต (brass + กีตาร์ไฟฟ้าหนักๆ)
  Bloody Stream      -> เบสไฟฟ้า, แซกโซโฟน, ทรัมเป็ต (เบสไลน์ดิสโก้ + brass)
  Fighting Gold      -> กีตาร์ไฟฟ้า, เบสไฟฟ้า, คีย์ทาร์ (ร็อกผสมออร์เคสตรา -- คีย์ทาร์แทนเสียง
                         ออร์เคสตรา/คีย์บอร์ด เพราะเปียโน/ไวโอลินไม่อยู่ในระบบ addon ที่ Lifestyle
                         รองรับ)
  Giorno's Theme     -> แซกโซโฟน, คีย์ทาร์ (สแกต/แซกโซโฟน ไปสู่ piano breakdown -- คีย์ทาร์
                         แทนเปียโนด้วยเหตุผลเดียวกัน)
  HEYYEYAAEYAAAEYAEYAA -> ฮาโมนิกา, คีย์ทาร์ (แทนคีย์บอร์ด), ขลุ่ย
  Bothnia - Someday I'll Wait -> กีตาร์โปร่ง (acoustic) เท่านั้น -- ขอ ukulele ไว้ด้วยถ้ามี แต่
                         Lifestyle ไม่มีโมดูล PlayUkuleleTracks ในระบบ addon นี้ (ไม่ใช่ 1 ใน 9
                         เครื่องดนตรีที่รองรับ) เลยใช้กีตาร์โปร่งแทน
  Violette Wautier - Wanna Be Yours -> คีย์ทาร์ (แทนเปียโน ด้วยเหตุผลเดียวกับ Fighting
                         Gold/Giorno's Theme -- เปียโนไม่อยู่ในระบบ addon นี้)

หลังเพิ่ม/แก้ไฟล์เพลงใหม่แล้วเข้าเกมไปเปิดเมนูเครื่องดนตรี แล้วไม่เห็นเพลงใหม่ในรายการ หรือเห็น
แต่กดเล่นแล้วเงียบไม่มีเสียงออกเลย (กด play เหมือนเริ่มเล่นได้ปกติ แต่ไม่มีเสียง) -- มี 2 สาเหตุ
ที่เคยเจอจริง ต้องแยกให้ออก:
--------------------------------------------------------------------------------
(1) *** cache รายชื่อเพลงที่เรียนรู้แล้วค้าง (ยืนยันแล้ว 2026-09-15) ***
เมนูเครื่องดนตรีของ Lifestyle: Hobbies จะ "จำ" รายชื่อเพลงที่เรียนรู้แล้วเก็บไว้ในข้อมูลของ
ตัวละคร (character mod data) แค่ครั้งแรกที่เปิดเมนูเครื่องดนตรีนั้นเท่านั้น หลังจากนั้นจะไม่โหลด
รายชื่อ/ค่าเพลงใหม่จากตารางอีกเลย ต่อให้ restart เกมหรือแก้โค้ดแล้วก็ตาม (แม้แค่แก้ length ของ
เพลงที่เคยเรียนไปแล้วก็เจอปัญหานี้ได้ ไม่ใช่แค่เพลงใหม่เอี่ยม)

วิธีแก้: เปิด debug console แล้วรัน (เปลี่ยนชื่อฟิลด์ตามเครื่องดนตรีที่เพิ่มเพลงลงไป เช่น
GuitarELearnedTracks/GuitarEBLearnedTracks/SaxophoneLearnedTracks/TrumpetLearnedTracks/
KeytarLearnedTracks/HarmonicaLearnedTracks/FluteLearnedTracks):

  getPlayer():getModData().GuitarELearnedTracks = {}

แล้วเปิดเมนูเครื่องดนตรีนั้นใหม่ -- ต้องทำซ้ำทุกครั้งที่เพิ่ม/แก้เพลงในตารางอีกในอนาคต

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
