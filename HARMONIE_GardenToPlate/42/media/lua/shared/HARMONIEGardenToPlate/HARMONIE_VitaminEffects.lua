--[[
    HARMONIE - From Garden to Plate
    Applies the per-day penalty for each vitamin currently afflicted (see
    the hysteresis note in HARMONIE_VitaminConfig.lua). Called once per
    in-game day (via HARMONIE_VitaminChecker.lua's 10-second responsive
    check, guarded by lastEffectDay so it still only actually fires once
    per day) for every vitamin where
    HARMONIE_GTP.VitData.IsAfflicted(character, vit) is true.

    Every vitamin's penalty is the SAME flat Config.effects[vit].amount
    every time it fires -- applied once immediately on the day it becomes
    Critical, then again every subsequent day it stays Critical, with no
    ramp-up curve and no cap. Staying Critical a long time keeps making it
    worse, deliberately and indefinitely.

    A (Vision Impaired) pushes CharacterStat.PANIC up to trigger vanilla's
    own native panic-driven tunnel vision / narrowed screen effect -- no
    custom rendering, just leaning on an existing vanilla visual cue.

    ApplyCritical is a no-op while HARMONIE_GTP.VitData.IsEffectsSuppressed
    is true (Base.PillsVitamins, taken via HARMONIE_PillsHook.lua, blocks
    this penalty for 24 in-game hours). That only silences the SYMPTOM --
    Reserve and the affliction flag itself are untouched, so it comes right
    back once the suppression window ends if the underlying deficiency was
    never actually fixed by eating.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.VitEffects = {}
local VitEffects = HARMONIE_GTP.VitEffects

local function reduceHealingOnWounds(character, amount)
    local bodyParts = character:getBodyDamage():getBodyParts()
    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        if bodyPart:getHealth() < 100 then
            bodyPart:setHealth(math.max(0, bodyPart:getHealth() - amount))
        end
    end
end

-- effect handlers keyed by vitamin letter; each receives (character, effectCfg)
local Handlers = {
    A = function(character, cfg)
        character:getStats():add(CharacterStat.PANIC, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    B = function(character, cfg)
        character:getStats():remove(CharacterStat.ENDURANCE, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    C = function(character, cfg)
        character:getStats():add(CharacterStat.SICKNESS, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    D = function(character, cfg)
        character:getStats():add(CharacterStat.PAIN, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    E = function(character, cfg)
        character:getStats():add(CharacterStat.STRESS, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,

    K = function(character, cfg)
        reduceHealingOnWounds(character, cfg.amount * HARMONIE_GTP.Config.effectMultiplier)
    end,
}

function VitEffects.ApplyCritical(character, vit)
    if not HARMONIE_GTP.Config.effectsEnabled then return end
    if HARMONIE_GTP.VitData.IsEffectsSuppressed(character) then return end
    local cfg = HARMONIE_GTP.Config.effects[vit]
    local handler = Handlers[vit]
    if cfg and handler then
        handler(character, cfg)
    end
end
