ใส่ไฟล์เพลงของพี่เองที่นี่ (ไฟล์ .ogg ไม่รวมมาให้เพราะเป็นเพลงลิขสิทธิ์)
================================================================================

วางไฟล์ .ogg ให้ตรงชื่อทุกตัวอักษร (case-sensitive):

  JoJo_SonoChiNoSadame.ogg        -- Sono Chi no Sadame (Phantom Blood/Battle Tendency OP)
  JoJo_BloodyStream.ogg           -- Bloody Stream (Stardust Crusaders OP1)
  JoJo_StandProud.ogg             -- Stand Proud (Stardust Crusaders OP2)
  JoJo_CrazyNoisyBizarreTown.ogg  -- Crazy Noisy Bizarre Town (Diamond is Unbreakable OP1)
  JoJo_Chase.ogg                  -- Chase (Diamond is Unbreakable OP2)
  JoJo_FightingGold.ogg           -- Fighting Gold (Golden Wind OP1)
  JoJo_TraitorsRequiem.ogg        -- Traitor's Requiem (Golden Wind OP2)
  JoJo_GreatDays.ogg              -- Great Days (Golden Wind OP3)
  JoJo_StoneOcean.ogg             -- STONE OCEAN (Stone Ocean OP1)

หลังวางไฟล์ครบแล้ว ยังต้องทำอีก 1 ขั้นตอน:
--------------------------------------------------------------------------------
แก้ length=90 (ค่า placeholder ที่ใส่ไว้ชั่วคราวในไฟล์
../../lua/client/TimedActions/AddMoreTracks_HARMONIE_JoJo.lua)
ให้ตรงกับความยาวจริงเป็นวินาทีของไฟล์ .ogg แต่ละไฟล์ที่พี่ใส่ ไม่งั้นเพลงจะตัดก่อนจบ หรือมี
ช่วงเงียบค้างจนจบ length ที่ตั้งไว้

เช็คความยาวไฟล์เสียงได้จาก properties ของไฟล์ใน Windows Explorer (คลิกขวา -> Properties ->
Details -> Length) หรือโปรแกรมเล่นเพลงทั่วไป

ทำไมไม่มีไฟล์เพลงมาให้: เพลง JoJo's Bizarre Adventure เป็นเพลงประกอบอนิเมะที่มีลิขสิทธิ์
(Yugo Kanno / Coda และค่ายเพลงญี่ปุ่นที่เกี่ยวข้อง) Claude ไม่สามารถหา/ดาวน์โหลดไฟล์เสียง
ลิขสิทธิ์มาฝังใน mod ให้ได้ ต้องเป็นไฟล์ที่พี่มีสิทธิ์ใช้เองเท่านั้น (ริพจากที่ซื้อไว้ ฯลฯ)
ถ้าตั้งใจจะเอา mod นี้ขึ้น Steam Workshop สาธารณะ ควรพิจารณาเรื่องลิขสิทธิ์ให้รอบคอบก่อนด้วย
