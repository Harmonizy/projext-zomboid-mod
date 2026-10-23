--[[
    HARMONIE - Home Medic : mod-wide switches (shared)

    MINIGAMES_ENABLED -- the stitching minigame is parked for now (request
    2026-09-30: "ปิดมินิเกมที่มีไปก่อน เดี๋ยวค่อยคิดทีหลังว่าใช้ตอนไหน").
    While false every stitch is the normal timed action, whatever the
    sandbox option "Stitch minigame" says; set it back to true to bring the
    minigame (and the vanilla-window hook, HARMONIE_StitchQueueHook.lua)
    back exactly as before.
]]--

HARMONIE_HomeMedic_Config = HARMONIE_HomeMedic_Config or {}
HARMONIE_HomeMedic_Config.MINIGAMES_ENABLED = false
