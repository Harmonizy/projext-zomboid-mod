-- MFS B42.20 Redux - RC6
-- Re-apply saved weapon-part offsets after a reload.
--
-- PROBLEM
-- Per-part offsets edited in the inspection GUI are stored in
--   weapon:getModData().GunPos[<part full type>] = { x, y, z }
-- and that modData IS persisted by the game. But the value that actually
-- positions the part on the rendered weapon lives in the WEAPON MODEL SCRIPT's
-- `attachment <PartType>` offset, which is reloaded from the .txt files at
-- startup. Only three places ever wrote to it, and all are user-triggered:
--     risky_inspect_button.lua   (on part select)
--     risky_inspect_slider.lua   (on slider drag)
--     WeaponWithBoltAnim.lua
-- So after a restart the saved numbers still exist and the sliders show them,
-- but nothing pushes them back into the model until the player opens the wrench
-- and clicks the part again.
--
-- HOW ATTACHED PARTS ARE FOUND  (this was the bug in the first two attempts)
-- An earlier version read weapon:getModData().weaponpart. That table is almost
-- always NIL: AWCWF_AdditionalParts.lua patches the get/set accessors that would
-- populate it, but its patcher begins with `if true then return end`, so the
-- patching never happens. Console diagnostics confirmed "weaponpart modData is
-- nil" on every tested weapon.
-- The inspection GUI does not use it either - it calls the vanilla
-- weapon:getWeaponPart(<PartType>). This file now does the same.
--
-- IMPORTANT DESIGN NOTE - why this is keyed to the HELD weapon
-- ModelScript:getAttachmentById() returns an object owned by the weapon MODEL,
-- not by the item instance. Every weapon sharing a model shares one attachment
-- object. Two guns of the same type with different offsets therefore cannot both
-- be correct at once. Applying for the held weapon only is deliberate.
--
-- MULTIPLAYER LIMITATION - NOT SOLVED HERE
-- The same shared-object constraint means a remote player's weapon cannot be
-- rendered with its own offsets while the local player holds the same model.
-- That needs per-instance part rendering, a much larger change.

MFSPartOffsetPersistence = MFSPartOffsetPersistence or {}
local Persist = MFSPartOffsetPersistence

-- Diagnostic logging. OFF for release.
-- Set to true to print one console line per distinct outcome, plus an APPLIED
-- line listing every slot and the exact offset written. This is how the
-- `weaponpart modData is nil` root cause was found; keep it available.
Persist.DEBUG = false

-- Positionable slots. Deliberately excludes Skin, Clip and Hide_Beam: those are
-- not user-positioned parts (magazine placement is baked into the mesh).
local PART_SLOTS = {"Scope", "L_Scope", "R_Scope", "Canon", "Stock", "Grip", "Laser", "Light",
                    "Stool", "Sling", "RecoilPad", "Misc", "Barrel", "Barrel_Shroud"}

local lastSignature = nil
local lastPartSignature = nil
local lastReason = nil

-- MFS Patch 5 - FRAME STORM FIX.
--
-- The build 2 multiplayer log showed this module calling
-- resetEquippedHandsModels() on ~20 CONSECUTIVE frames (f:83113 through
-- f:83130) with the attached part list unchanged, and 91 times over one short
-- session.
--
-- Cause: signatureFor() includes the SAVED X/Y/Z of every part. Dragging a
-- slider in the inspection GUI rewrites those values every frame, so the
-- signature differs every frame, so a full equipped-model rebuild was forced
-- every frame. Correct output, absurd cost.
--
-- Fix: separate the two kinds of change.
--   PART SET changed (attach/detach) -> rebuild immediately. Rare, and the
--                                       user must see it at once.
--   OFFSETS ONLY changed (slider drag) -> write the offsets every time, but
--                                       rate-limit the REBUILD. A drag is a
--                                       continuous gesture; refreshing at
--                                       ~12 Hz is visually identical.
-- A pending flush guarantees the final position of a drag is always applied
-- even if its last frame lands inside the throttle window.
Persist.REFRESH_INTERVAL_MS = 80
local lastRefreshMs = 0
local pendingRefresh = false

local function nowMs()
    local ok, v = pcall(function() return getTimestampMs() end)
    if ok and v then
        return v
    end
    return 0
end

local function dbg(reason, extra)
    if not Persist.DEBUG then
        return
    end
    if reason == lastReason then
        return
    end
    lastReason = reason
    print("[MFSPartOffset] " .. tostring(reason) .. (extra and (" | " .. tostring(extra)) or ""))
end

-- slot -> attached part full type, using the same vanilla call the GUI uses.
local function attachedParts(weapon)
    local out = {}
    local count = 0
    for _, slot in ipairs(PART_SLOTS) do
        local ok, part = pcall(function()
            return weapon:getWeaponPart(slot)
        end)
        if ok and part then
            local ok2, full = pcall(function()
                return part:getFullType()
            end)
            if ok2 and full then
                out[slot] = full
                count = count + 1
            end
        end
    end
    return out, count
end

-- Part set only - deliberately excludes offsets, so a slider drag does NOT
-- register as a part change.
local function partSignatureFor(weapon, parts)
    local keys = {}
    for slot, fullType in pairs(parts) do
        keys[#keys + 1] = slot .. ":" .. fullType
    end
    table.sort(keys)
    return tostring(weapon:getWeaponSprite()) .. "|" .. table.concat(keys, ";")
end

local function signatureFor(weapon, parts)
    local gunPos = weapon:getModData().GunPos
    local keys = {}
    for slot, fullType in pairs(parts) do
        local saved = gunPos and gunPos[fullType]
        keys[#keys + 1] = slot .. ":" .. fullType .. ":" ..
                              (saved and (tostring(saved.x) .. "/" .. tostring(saved.y) .. "/" ..
                                  tostring(saved.z)) or "-")
    end
    table.sort(keys)
    return tostring(weapon:getWeaponSprite()) .. "|" .. table.concat(keys, ";")
end

function Persist.apply(playerObj)
    local player = playerObj or getPlayer()
    if not player then
        return
    end

    local weapon = player:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") then
        lastSignature = nil
        dbg("no HandWeapon in primary hand")
        return
    end

    local gunPos = weapon:getModData().GunPos
    if not gunPos then
        lastSignature = nil
        dbg("GunPos modData is nil", weapon:getFullType())
        return
    end

    local parts, partCount = attachedParts(weapon)
    if partCount == 0 then
        lastSignature = nil
        dbg("no attached parts found via getWeaponPart", weapon:getFullType())
        return
    end

    -- Flush a rebuild deferred by the throttle, even when nothing changed this
    -- frame, so the end of a slider drag is never left unapplied.
    if pendingRefresh and (nowMs() - lastRefreshMs) >= Persist.REFRESH_INTERVAL_MS then
        pendingRefresh = false
        lastRefreshMs = nowMs()
        if MFS_RefreshWeaponAttachmentState then
            MFS_RefreshWeaponAttachmentState(player, weapon)
        elseif player:getPrimaryHandItem() == weapon then
            player:resetEquippedHandsModels()
        end
    end

    local sig = signatureFor(weapon, parts)
    if sig == lastSignature then
        return
    end
    lastSignature = sig

    local partSig = partSignatureFor(weapon, parts)
    local partsChanged = (partSig ~= lastPartSignature)
    lastPartSignature = partSig

    -- Same lookup the inspection GUI uses (risky_inspect_button.lua).
    local spriteKey = "Base." .. tostring(weapon:getWeaponSprite())
    local model = ScriptManager.instance:getModelScript(spriteKey)
    if not model then
        dbg("model script NOT FOUND", spriteKey)
        return
    end

    -- The inspection scene rotates handgun models 180 degrees about Y, so Z is
    -- inverted between scene space and model-attachment space. Must match
    -- risky_inspect_slider.lua and risky_inspect_button.lua.
    local zSign = 1
    if weapon:getSwingAnim() == "Handgun" then
        zSign = -1
    end

    local applied = 0
    local report = {}
    for slot, fullType in pairs(parts) do
        local saved = gunPos[fullType]
        if saved and saved.x and saved.y and saved.z then
            local attachment = model:getAttachmentById(slot)
            local created = false
            if not attachment then
                attachment = ModelAttachment.new(slot)
                model:addAttachment(attachment)
                created = true
            end
            if attachment then
                attachment:getOffset():set(saved.x, saved.y, zSign * saved.z)
                applied = applied + 1
                report[#report + 1] = slot .. "=" .. tostring(saved.x) .. "," ..
                                          tostring(saved.y) .. "," .. tostring(zSign * saved.z) ..
                                          (created and " (CREATED)" or "")
            end
        else
            report[#report + 1] = slot .. "=<no saved offset>"
        end
    end

    if Persist.DEBUG then
        lastReason = nil -- real event, always print
        dbg("APPLIED " .. applied .. "/" .. partCount .. " on " .. spriteKey,
            table.concat(report, "  "))
    end

    -- Writing the offset is not enough: the engine draws these parts from a
    -- CACHED equipped-hands model instance, and an offset change with an
    -- unchanged part list does not invalidate it. Dropping and re-picking up the
    -- weapon worked precisely because that rebuilds the instance.
    -- AWCWF_Attach.Apply_Effect is the WRONG call here - it refreshes the AWCWF
    -- attached-item renderer, not the engine weapon-part renderer.
    -- MFS Patch 5: the offsets above are written EVERY time. Only the expensive
    -- model rebuild is rate-limited, and only when the part set did not change.
    if applied > 0 then
        local due = partsChanged or (nowMs() - lastRefreshMs) >= Persist.REFRESH_INTERVAL_MS
        if not due then
            pendingRefresh = true
        else
            pendingRefresh = false
            lastRefreshMs = nowMs()
            if MFS_RefreshWeaponAttachmentState then
                MFS_RefreshWeaponAttachmentState(player, weapon)
            elseif player:getPrimaryHandItem() == weapon then
                player:resetEquippedHandsModels()
            end
        end
    end
end

local function onPlayerUpdate(playerObj)
    if playerObj and getPlayer() and playerObj ~= getPlayer() then
        return
    end
    Persist.apply(playerObj)
end

local function invalidate(playerObj)
    lastSignature = nil
    lastPartSignature = nil
    Persist.apply(playerObj)
end

-- Load-time restore.
-- OnGameStart fires once the world is loaded, but the player, the equipped item
-- and the model instance are not all reliably ready on that tick, so a single
-- call can silently no-op. Retry briefly, then stop.
local pendingTicks = 0

local function loadTimeRestore()
    if pendingTicks <= 0 then
        Events.OnTick.Remove(loadTimeRestore)
        return
    end
    pendingTicks = pendingTicks - 1

    local player = getPlayer()
    if not player then
        return
    end
    local weapon = player:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") then
        return
    end

    lastSignature = nil
    lastPartSignature = nil
    Persist.apply(player)
    pendingTicks = 0
    Events.OnTick.Remove(loadTimeRestore)
end

local function armLoadTimeRestore()
    lastSignature = nil
    lastPartSignature = nil
    pendingTicks = 120
    Events.OnTick.Remove(loadTimeRestore)
    Events.OnTick.Add(loadTimeRestore)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnEquipPrimary.Add(invalidate)
Events.OnGameStart.Add(armLoadTimeRestore)
Events.OnCreatePlayer.Add(armLoadTimeRestore)

if Persist.DEBUG then
    print("[MFSPartOffset] module loaded")
end
