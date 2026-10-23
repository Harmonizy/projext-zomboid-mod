--[[
    HARMONIE - Home Medic : the stitch minigame for EVERY stitch (client)

    Request 2026-09-30 ("ให้มินิเกมไปแสดงตอนเย็บแผลในหน้าต่าง vanilla ด้วย
    เพราะก่อนหน้านี้การเย็บใน vanilla ที่ไม่ใช่ในหน้าต่าง ehr มันสามารถทำได้
    โดยไม่ต้องเล่นมินิเกมเย็บ").

    EHR swaps in its minigame by replacing ISStitch:new -- so a stitch whose
    action is made any other way (the vanilla health window's own path, a
    context menu, another mod) went straight to a plain vanilla stitch.

    This catches the action where every path meets: when it is QUEUED
    (ISTimedActionQueue.add / addAfter). A vanilla ISStitch that stitches
    (doIt == true) and has not already been through the minigame is swapped
    for EHR's own EHR_StitchMinigameAction, which opens the minigame when its
    turn in the queue comes and, on success, queues the real ISStitch
    carrying the minigame's quality (EHR.StitchMinigame.CreateVanillaAction
    marks it _ehrStitchMinigameQuality, so it passes through here). Removing
    stitches (doIt == false) is left alone, as EHR does. EHR's own rules
    decide (EHR.StitchMinigame.ShouldIntercept: sandbox switch, range,
    item still there).
]]--

HARMONIE_HomeMedic_StitchHook = HARMONIE_HomeMedic_StitchHook or {}
local H = HARMONIE_HomeMedic_StitchHook

function H.swap(action)
    if type(action) ~= "table" or action.Type ~= "ISStitch" then return action end
    if action.doIt ~= true or action._ehrStitchMinigameQuality then return action end
    local SM = EHR and EHR.StitchMinigame
    if not SM or not SM.ShouldIntercept or not EHR_StitchMinigameAction then return action end
    if not SM.ShouldIntercept(action.character, action.otherPlayer, action.item, action.bodyPart, true) then
        return action
    end
    HMLog("Stitch", "vanilla stitch swapped for the stitching minigame (%s)", HMLogName(action.otherPlayer))
    return EHR_StitchMinigameAction:new(action.character, action.otherPlayer, action.item, action.bodyPart)
end

function H.install()
    if H.installed then return end
    if not ISTimedActionQueue or not ISTimedActionQueue.add then HMLog("Stitch", "ISTimedActionQueue.add missing -- stitch hook NOT installed"); return end
    H.installed = true
    HMLog("Stitch", "stitch hook installed")
    local add = ISTimedActionQueue.add
    ISTimedActionQueue.add = function(action, ...)
        return add(H.swap(action), ...)
    end
    if ISTimedActionQueue.addAfter then
        local addAfter = ISTimedActionQueue.addAfter
        ISTimedActionQueue.addAfter = function(previous, action, ...)
            return addAfter(previous, H.swap(action), ...)
        end
    end
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(H.install) end
