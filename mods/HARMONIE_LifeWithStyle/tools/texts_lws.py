#!/usr/bin/env python3
"""HARMONIE - Life With Style: IG_UI.json (EN/TH). Re-runnable: rewrites our keys, copies the Hub's."""
import json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
MODS = os.path.dirname(os.path.dirname(HERE))
DST = os.path.join(os.path.dirname(HERE), "42", "media", "lua", "shared", "Translate", "%s", "IG_UI.json")
HUB_SRC = os.path.join(MODS, "HARMONIE_SVU3Sandbox", "42", "media", "lua", "shared", "Translate", "%s", "IG_UI.json")
import sys
sys.path.insert(0, HERE)
from gen_lws import SLOT_NAMES

T = {
 "IGUI_LWS_Title": ("Life With Style", "Life With Style - ตู้เสื้อผ้า"),
 "IGUI_LWS_Tab_dress": ("Dress up", "แต่งตัว"),
 "IGUI_LWS_Tab_collection": ("Collection", "คอลเลกชัน"),
 "IGUI_LWS_Tab_admin": ("Admin", "แอดมิน"),
 "IGUI_LWS_Tab_guide": ("Guide", "คู่มือ"),
 "IGUI_LWS_Tab_dress_Tip": ("Pick a slot on the left, then a piece to wear.", "เลือกช่องทางซ้าย แล้วเลือกชิ้นที่จะสวม"),
 "IGUI_LWS_Tab_collection_Tip": ("Every fashion piece you own.", "ชิ้นแฟชั่นทั้งหมดที่คุณมี"),
 "IGUI_LWS_Tab_admin_Tip": ("Admins only: give and take fashion pieces.", "เฉพาะแอดมิน: มอบและนำชิ้นแฟชั่นออก"),
 "IGUI_LWS_Tab_guide_Tip": ("How Life With Style works.", "วิธีใช้ Life With Style"),
 "IGUI_LWS_Close": ("Close", "ปิด"), "IGUI_LWS_Pin": ("Pin (keep open)", "ปักหมุด (ค้างไว้)"),
 "IGUI_LWS_Unpin": ("Unpin (fold up when the mouse leaves)", "เลิกปักหมุด (พับเก็บเมื่อเมาส์ออก)"),
 "IGUI_LWS_TextBigger": ("Bigger text", "ตัวอักษรใหญ่ขึ้น"), "IGUI_LWS_TextSmaller": ("Smaller text", "ตัวอักษรเล็กลง"),
 "IGUI_LWS_Settings": ("Settings", "ตั้งค่า"), "IGUI_LWS_Set_Title": ("Life With Style - settings", "Life With Style - ตั้งค่า"),
 "IGUI_LWS_Slots": ("Fashion slots", "ช่องแฟชั่น"),
 "IGUI_LWS_Empty": ("Empty", "ว่าง"),
 "IGUI_LWS_ShowShort": ("real clothes shown", "แสดงชุดจริง"),
 "IGUI_LWS_ShowOn": ("Real clothes: shown", "ชุดจริง: แสดง"),
 "IGUI_LWS_ShowOff": ("Real clothes: hidden", "ชุดจริง: ซ่อน"),
 "IGUI_LWS_TakeOff": ("Take off", "ถอด"),
 "IGUI_LWS_HideNote": ("While a piece is worn here, your real clothes of this slot are not drawn (they still protect and keep you warm). Nothing pokes through.",
                       "ระหว่างที่สวมชิ้นแฟชั่นในช่องนี้ ชุดจริงของช่องนี้จะไม่ถูกวาด (แต่ยังป้องกันและให้ความอบอุ่นตามปกติ) จึงไม่มีอะไรทะลุออกมา"),
 "IGUI_LWS_ShowNote": ("Your real clothes of this slot are drawn too, under the piece.", "ชุดจริงของช่องนี้จะถูกวาดด้วย อยู่ใต้ชิ้นแฟชั่น"),
 "IGUI_LWS_HidesNothing": ("This slot hides nothing: the piece is drawn over everything.", "ช่องนี้ไม่ซ่อนอะไร ชิ้นแฟชั่นจะถูกวาดทับทุกอย่าง"),
 "IGUI_LWS_NoPieces": ("You have no piece for this slot yet. Fashion pieces are given by the server's admins.", "คุณยังไม่มีชิ้นแฟชั่นสำหรับช่องนี้ ชิ้นแฟชั่นได้จากแอดมินของเซิร์ฟเวอร์"),
 "IGUI_LWS_Wearing": ("Wearing", "สวมอยู่"),
 "IGUI_LWS_ClickWear": ("Click to wear it.", "คลิกเพื่อสวม"),
 "IGUI_LWS_ClickTakeOff": ("Click to take it off.", "คลิกเพื่อถอด"),
 "IGUI_LWS_ClickGoDress": ("Click to go to its slot.", "คลิกเพื่อไปที่ช่องของชิ้นนี้"),
 "IGUI_LWS_CollectionTitle": ("My collection (%1)", "คอลเลกชันของฉัน (%1)"),
 "IGUI_LWS_All": ("All", "ทั้งหมด"),
 "IGUI_LWS_CollectionEmpty": ("Your collection is empty. Fashion pieces are given by the server's admins - they never spawn in the world.",
                              "คอลเลกชันยังว่าง ชิ้นแฟชั่นได้จากแอดมินของเซิร์ฟเวอร์เท่านั้น ไม่มีเกิดในโลก"),
 "IGUI_LWS_Owners": ("Players", "ผู้เล่น"),
 "IGUI_LWS_Refresh": ("Refresh", "รีเฟรช"),
 "IGUI_LWS_OwnerCount": ("%1 pieces", "%1 ชิ้น"),
 "IGUI_LWS_Offline": ("offline", "ออฟไลน์"),
 "IGUI_LWS_Loading": ("Loading...", "กำลังโหลด..."),
 "IGUI_LWS_OwnerPieces": ("Pieces of %1", "ชิ้นแฟชั่นของ %1"),
 "IGUI_LWS_PickOwner": ("Pick a player on the left first.", "เลือกผู้เล่นทางซ้ายก่อน"),
 "IGUI_LWS_OwnerNone": ("This player has no fashion piece yet.", "ผู้เล่นคนนี้ยังไม่มีชิ้นแฟชั่น"),
 "IGUI_LWS_ClickRevoke": ("x: take this piece back from the player.", "x: นำชิ้นนี้ออกจากผู้เล่น"),
 "IGUI_LWS_Catalog": ("Catalog (%1) - click to give", "แคตตาล็อก (%1) - คลิกเพื่อมอบให้"),
 "IGUI_LWS_ClickGive": ("Click to give it to %1.", "คลิกเพื่อมอบให้ %1"),
 "IGUI_LWS_Msg_Got": ("New fashion piece", "ได้รับชิ้นแฟชั่นใหม่"),
 "IGUI_LWS_Msg_NotAdmin": ("Only admins can do that.", "เฉพาะแอดมินเท่านั้น"),
 "IGUI_LWS_Msg_Locked": ("Fashion pieces come off only in the Life With Style window.", "ชิ้นแฟชั่นถอดได้จากหน้าต่าง Life With Style เท่านั้น"),
 "IGUI_LWS_Menu_Open": ("Life With Style (wardrobe)", "Life With Style (ตู้เสื้อผ้า)"),
 "IGUI_LWS_Debug_Admin": ("Life With Style: admin page", "Life With Style: หน้าแอดมิน"),
 "IGUI_LWS_Debug_GiveSet": ("Life With Style: give the whole test set to %1", "Life With Style: มอบชุดทดสอบทั้งหมดให้ %1"),
 "IGUI_ItemCat_Fashion": ("Fashion", "แฟชั่น"),
 "IGUI_HUB_LWS_Name": ("Life With Style", "Life With Style"),
 "IGUI_HUB_LWS_Desc": ("Your wardrobe: fashion pieces you keep forever, worn over your real clothes.", "ตู้เสื้อผ้าของคุณ: ชิ้นแฟชั่นที่อยู่กับคุณตลอดไป สวมทับชุดจริง"),
 "UI_options_HARMONIE_LWS_title": ("HARMONIE - Life With Style", "HARMONIE - Life With Style"),
 "UI_options_HARMONIE_LWS_key": ("Open the wardrobe", "เปิดตู้เสื้อผ้า"),
 "UI_options_HARMONIE_LWS_key_tooltip": ("A key that opens or closes the Life With Style window.", "ปุ่มเปิด/ปิดหน้าต่าง Life With Style"),
 # guide
 "IGUI_LWS_Guide_What_Title": ("What is it", "คืออะไร"),
 "IGUI_LWS_Guide_What_Body": ("Fashion pieces are clothes for the look only. They never spawn in the world: the server's admins give them. They belong to you - your account - not to your character: they never drop, can not be stolen, and stay when you die.",
     "ชิ้นแฟชั่นคือเสื้อผ้าเพื่อความสวยงามอย่างเดียว ไม่มีเกิดในโลก ได้จากแอดมินของเซิร์ฟเวอร์เท่านั้น ชิ้นแฟชั่นเป็นของคุณ (ผูกกับบัญชี) ไม่ใช่ของตัวละคร จึงไม่ดรอป ขโมยไม่ได้ และไม่หายเมื่อตาย"),
 "IGUI_LWS_Guide_Dress_Title": ("Dressing up", "การแต่งตัว"),
 "IGUI_LWS_Guide_Dress_Body": ("Open the Dress up tab, pick one of the 18 slots on the left and click a piece on the right to wear it. Click it again, or Take off, to take it off. Pieces weigh nothing and protect nothing - your real clothes do that.",
     "เปิดแท็บแต่งตัว เลือกหนึ่งใน 18 ช่องทางซ้าย แล้วคลิกชิ้นทางขวาเพื่อสวม คลิกซ้ำหรือกดถอดเพื่อถอด ชิ้นแฟชั่นไม่มีน้ำหนักและไม่ป้องกันอะไร ชุดจริงของคุณยังทำหน้าที่นั้นอยู่"),
 "IGUI_LWS_Guide_Show_Title": ("Real clothes", "ชุดจริง"),
 "IGUI_LWS_Guide_Show_Body": ("By default a worn piece hides your real clothes of that slot - they are still worn, keep protecting you and keep you warm, they are just not drawn, so nothing pokes through. \"Real clothes: shown\" draws them too, under the piece.",
     "ค่าเริ่มต้น ชิ้นแฟชั่นที่สวมจะซ่อนชุดจริงของช่องนั้น ชุดจริงยังสวมอยู่ ยังป้องกันและให้ความอบอุ่น แค่ไม่ถูกวาด จึงไม่มีอะไรทะลุออกมา ปุ่ม \"ชุดจริง: แสดง\" จะวาดชุดจริงด้วย อยู่ใต้ชิ้นแฟชั่น"),
 "IGUI_LWS_Guide_Death_Title": ("Death and new characters", "เมื่อตายและตัวละครใหม่"),
 "IGUI_LWS_Guide_Death_Body": ("The wardrobe is kept on the server. When you die nothing of it goes into the body; your next character is dressed again the same way as soon as it spawns.",
     "ตู้เสื้อผ้าเก็บอยู่บนเซิร์ฟเวอร์ เมื่อตายจะไม่มีชิ้นไหนติดไปกับศพ ตัวละครใหม่จะถูกแต่งตัวแบบเดิมทันทีที่เกิด"),
 "IGUI_LWS_Guide_Admin_Title": ("For admins", "สำหรับแอดมิน"),
 "IGUI_LWS_Guide_Admin_Body": ("The Admin tab lists every player (online first). Pick one, click a catalog piece to give it, or x on one of their pieces to take it back. The HARMONIE debug right-click has a shortcut and a whole test set.",
     "แท็บแอดมินแสดงผู้เล่นทุกคน (คนที่ออนไลน์อยู่ก่อน) เลือกผู้เล่น แล้วคลิกชิ้นในแคตตาล็อกเพื่อมอบให้ หรือกด x ที่ชิ้นของเขาเพื่อนำออก เมนูคลิกขวา HARMONIE debug มีทางลัดและการมอบชุดทดสอบทั้งชุด"),
 "IGUI_LWS_Guide_Soon_Title": ("Coming next", "เร็วๆ นี้"),
 "IGUI_LWS_Guide_Soon_Body": ("Trading fashion pieces between players, a Discord-linked wardrobe, and pets that wear fashion and follow you.",
     "การแลกเปลี่ยนชิ้นแฟชั่นระหว่างผู้เล่น ตู้เสื้อผ้าที่ผูกกับบัญชี Discord และสัตว์เลี้ยงที่ใส่แฟชั่นและเดินตามคุณ"),
}
for s, (en, th) in SLOT_NAMES.items():
    T["IGUI_LWS_Slot_" + s] = (en, th)

for i, lang in enumerate(("EN", "TH")):
    hub = json.load(open(HUB_SRC % lang, encoding="utf-8"))
    d = {k: v for k, v in hub.items() if k.startswith("IGUI_HUB_")}
    for k, v in T.items():
        d[k] = v[i]
    for k, v in d.items():
        if "%" in re.sub(r"%%|%\d", "", v): print("BARE %", k)
    os.makedirs(os.path.dirname(DST % lang), exist_ok=True)
    open(DST % lang, "w", encoding="utf-8").write(json.dumps(d, indent=4, ensure_ascii=False) + "\n")
    print(lang, len(d), "keys")
