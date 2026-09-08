--[[
    HARMONIE - From Garden to Plate
    Applies each vitamin's deficiency penalty while currently afflicted
    (see the hysteresis note in HARMONIE_VitaminConfig.lua).

    SIMPLIFIED DESIGN (final, per explicit request): each vitamin grants/
    revokes exactly ONE real, already-compiled vanilla CharacterTrait --
    nothing else. No custom proxy mechanics (no CharacterStat floor/
    ceiling, no body-part Stiffness, no BleedingTime/nosebleed, no hand-
    written stopOnWalk hook) -- those were all tried in earlier versions
    of this mod and explicitly removed for being harder to control/tune
    than they were worth. A brand-new, mod-registered custom trait
    (Vitamin A Deficiency, etc, via registries.lua) was ALSO tried and
    then explicitly rolled back in favor of this simpler, lower-risk
    approach: reusing real, already-compiled vanilla traits means every
    bit of Java-side behavior (vision blur, cut chance, panic attacks,
    fumbling, slower healing, etc) comes for free from the base game --
    nothing here has to re-implement or approximate it, and there is no
    new registration path (registries.lua / character_trait_definition)
    to get wrong.

    The six traits, one per vitamin, all confirmed to genuinely exist as
    compiled CharacterTrait enum values via decompiling
    CharacterTrait.class:
      A -> SHORT_SIGHTED   (vision blur, confirmed via
                             IsoGameCharacter.class's updateVisionEffects())
      B -> DISORGANIZED    (reduced bag/world-container capacity; also
                             skips auto-returning leftover crafting items
                             to their container -- ISCraftingUI.lua)
      C -> THIN_SKINNED    (more easily cut/scratched -- Java-only)
      D -> ASTHMATIC       (internal id only -- the actual in-game trait
                             name, confirmed via vanilla's own UI_trait_
                             Asthmatic translation key, is "Short of
                             Breath". Its real effect, confirmed via
                             decompiling CharacterTraits.class's own
                             AsthmaticEnduranceLossModifier = 1.2f
                             constant, is 1.2x faster ENDURANCE loss --
                             NOT random panic-driven asthma attacks cured
                             by an Inhaler, which was this file's own
                             earlier, incorrect assumption about what the
                             trait does. Java-only, no separate Lua hook.)
      E -> ALL_THUMBS      (forces stopOnWalk during crafting --
                             ISHandcraftAction.lua's own check -- plus
                             fumbled drops/inventory transfers elsewhere)
      K -> SLOW_HEALER     (wounds take longer to heal -- Java-only)

    Granting/revoking uses character:getCharacterTraits():add()/remove(),
    the same real, vanilla-used mechanism XpUpdate.lua uses to swap
    WEAK/FEEBLE/STOUT/STRONG live as Strength changes -- already proven
    safe for continuous runtime use, including in multiplayer (that same
    vanilla live-swap logic runs identically for every player, local or
    remote).

    CRITICAL SAFETY LOGIC -- all six of these are real, normally player-
    selectable NEGATIVE traits at character creation (a player may have
    genuinely chosen "Short Sighted" for the trait points, same as any
    other survivor). This mod must NEVER strip a trait the character
    actually chose. See MaintainRealTrait's own comment below for the
    exact traitGranted-based logic that guarantees this.

    A also needs one extra step beyond a plain add()/remove(): granting
    Short Sighted does NOT immediately apply its vision blur on its own
    -- see MaintainRealTrait's comment for why, and the explicit
    character:updateVisionEffects() call that fixes it.

    All of this is a no-op while the vitamin has at least 1 WHOLE banked
    pause day (HARMONIE_GTP.VitData.GetPauseDays >= 1 -- a leftover
    fraction below 1 doesn't shield anything yet, just keeps accumulating,
    see VitData.ApplyDailyTick) -- gained from eating well, or from taking
    this mod's own crafted Multivitamin pill (see HARMONIE_PillsHook.lua),
    which grants a full day's worth of REAL Reserve for every vitamin at
    once (mechanically identical to eating a perfectly balanced day of
    food), banking roughly 1 pause day per vitamin as a side effect of
    that Reserve gain. Recovery (Reserve climbing back to
    Sufficient) reverses everything automatically -- the trait is removed
    the moment the vitamin is no longer afflicted, via the exact same
    MaintainRealTrait check that granted it (see HARMONIE_VitaminChecker
    .lua's LogEffectStateChange for a permanent console.txt confirmation
    of exactly when this happens, both on grant and on revoke).

    Dialogue is entirely separate -- handled by MaybeSaySymptomReminder
    below, checked every 6 GAME hours, picking ONE random currently-
    afflicted vitamin to comment on each time, so a character with several
    vitamins critical at once never says several symptom lines back to
    back. Each vitamin's lines connect a real-world deficiency symptom to
    its trait's actual effect, in the character's own first-person voice
    (never clinical/textbook-sounding for an ordinary survivor without
    medical training):
      A -- blurry/night vision (Short Sighted's real blur)
      B -- numb, fumbling hands, which is ALSO why their gear ends up
           disorganized/jumbled (the character's own read on WHY their
           bag is a mess, tying numbness to Disorganized's real effect)
      C -- aching joints and easy bruising/bleeding gums (classic real
           scurvy symptoms), framed as the reason their skin bruises and
           cuts so easily (Thin-Skinned's real effect)
      D -- getting out of breath quickly / tiring fast (Short of
           Breath's real faster-endurance-loss effect)
      E -- clumsy, fumbling hands (All Thumbs' real effect)
      K -- cuts and scrapes that won't close up, explained by the
           character as their blood not clotting right (a plausible
           first-person read connecting Slow Healer's real slow-healing
           effect to Vitamin K's actual real-world clotting symptom)
    Never naming the vitamin for an ordinary survivor, since they have no
    lab to tell them that's the cause -- only the Doctor-level lines do.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminConfig"
require "HARMONIEGardenToPlate/HARMONIE_VitaminData"

HARMONIE_GTP = HARMONIE_GTP or {}
HARMONIE_GTP.VitEffects = {}
local VitEffects = HARMONIE_GTP.VitEffects

--[[
    Flavor lines the character says to themselves the day a vitamin's
    penalty actually applies. Two different pools depending on whether
    the character actually has the medical knowledge to know what's
    wrong:

      - Below Doctor level (assessmentRequiredFirstAid + 1): worded as a
        real-world symptom the character just NOTICES (blurry eyes, a
        messy bag, bruised skin...), never naming the vitamin, since an
        ordinary survivor has no lab to tell them that's the cause. One
        of the variants in each list leans a little wry/darkly funny --
        not every line needs to be grim.
      - Above that Doctor level (the same threshold that unlocks reading
        the Nutrition Assessment window, see HARMONIE_VitaminConfig.lua's
        assessmentRequiredFirstAid): the character has enough medical
        training to actually recognize and name the deficiency, so these
        lines say so directly.

    Each list has a few variants so it doesn't feel like the same canned
    line every time; sayRandomSymptom below picks one at random each
    time.
]]--
local SymptomLineKeys = {
    A = {"IGUI_HARMONIE_Symptom_A_1", "IGUI_HARMONIE_Symptom_A_2", "IGUI_HARMONIE_Symptom_A_Funny"},
    B = {"IGUI_HARMONIE_Symptom_B_1", "IGUI_HARMONIE_Symptom_B_2", "IGUI_HARMONIE_Symptom_B_Funny"},
    C = {"IGUI_HARMONIE_Symptom_C_1", "IGUI_HARMONIE_Symptom_C_2", "IGUI_HARMONIE_Symptom_C_Funny"},
    D = {"IGUI_HARMONIE_Symptom_D_1", "IGUI_HARMONIE_Symptom_D_2", "IGUI_HARMONIE_Symptom_D_Funny"},
    E = {"IGUI_HARMONIE_Symptom_E_1", "IGUI_HARMONIE_Symptom_E_2", "IGUI_HARMONIE_Symptom_E_Funny"},
    K = {"IGUI_HARMONIE_Symptom_K_1", "IGUI_HARMONIE_Symptom_K_2", "IGUI_HARMONIE_Symptom_K_Funny"},
}

local DoctorSymptomLineKeys = {
    A = {"IGUI_HARMONIE_DoctorSymptom_A_1", "IGUI_HARMONIE_DoctorSymptom_A_2"},
    B = {"IGUI_HARMONIE_DoctorSymptom_B_1", "IGUI_HARMONIE_DoctorSymptom_B_2"},
    C = {"IGUI_HARMONIE_DoctorSymptom_C_1", "IGUI_HARMONIE_DoctorSymptom_C_2"},
    D = {"IGUI_HARMONIE_DoctorSymptom_D_1", "IGUI_HARMONIE_DoctorSymptom_D_2"},
    E = {"IGUI_HARMONIE_DoctorSymptom_E_1", "IGUI_HARMONIE_DoctorSymptom_E_2"},
    K = {"IGUI_HARMONIE_DoctorSymptom_K_1", "IGUI_HARMONIE_DoctorSymptom_K_2"},
}

local function sayRandomSymptom(character, vit)
    if not character.Say then return end
    local isDoctor = character:getPerkLevel(Perks.Doctor) > HARMONIE_GTP.Config.assessmentRequiredFirstAid
    local pool = isDoctor and DoctorSymptomLineKeys or SymptomLineKeys
    local keys = pool[vit]
    if not keys then return end
    character:Say(getText(keys[ZombRand(#keys) + 1]))
end

--[[
    The relief-side counterpart to the symptom lines above -- said once
    when a vitamin's Reserve climbs back up to Sufficient after having
    been afflicted (see VitData.RefreshAffliction's return value and
    HARMONIE_VitaminChecker.lua, which calls this at most once per check
    even if several vitamins recover in the same 10-second tick, so
    eating one big varied meal doesn't make the character say three
    different "feeling better" lines back to back).
]]--
local RECOVERY_CHANCE_PERCENT = 80
local RecoveryLineKeys = {
    "IGUI_HARMONIE_Recovered_1",
    "IGUI_HARMONIE_Recovered_2",
    "IGUI_HARMONIE_Recovered_3",
    "IGUI_HARMONIE_Recovered_Funny",
}

function VitEffects.SayRecovered(character)
    if not character or not character.Say then return end
    if ZombRand(100) >= RECOVERY_CHANCE_PERCENT then return end
    character:Say(getText(RecoveryLineKeys[ZombRand(#RecoveryLineKeys) + 1]))
end

-- The real vanilla CharacterTrait each vitamin is themed after -- all six
-- are genuine, pre-compiled, normally player-selectable negative traits
-- (confirmed via decompiling CharacterTrait.class), NOT new traits this
-- mod registers itself.
local RealTraitEffects = {
    A = CharacterTrait.SHORT_SIGHTED,
    B = CharacterTrait.DISORGANIZED,
    C = CharacterTrait.THIN_SKINNED,
    D = CharacterTrait.ASTHMATIC,
    E = CharacterTrait.ALL_THUMBS,
    K = CharacterTrait.SLOW_HEALER,
}

--[[
    Checked every 10 seconds by HARMONIE_VitaminChecker.lua for every
    vitamin -- genuinely grants/revokes the real trait from RealTraitEffects
    above using character:getCharacterTraits():add()/remove().

    CRITICAL SAFETY LOGIC -- these six traits are all real, normally
    player-selectable NEGATIVE traits at character creation (a player may
    have genuinely chosen "Short Sighted" for the trait points, same as
    any other survivor). This function must NEVER strip a trait the
    character actually chose. The fix: VitData.IsTraitGrantedByUs/
    SetTraitGrantedByUs (HARMONIE_VitaminData.lua) tracks, per vitamin,
    whether THIS mod is the one currently holding the trait:
      - Becoming afflicted: only ADD the trait if the character doesn't
        already have it (character:hasTrait() is false) -- and only THEN
        mark traitGranted true. If the character already has it (their
        own real choice, or we granted it on a previous tick), nothing
        needs adding.
      - Recovering: only REMOVE the trait if traitGranted is true (i.e.
        this mod actually added it at some point). If it was never
        marked granted -- because the character already had it naturally
        when they first became afflicted -- it is left alone FOREVER,
        exactly like a real deficiency would never make a doctor revoke
        an unrelated pre-existing condition.
    Pause-day-shielded counts as "not afflicted" for this purpose, same
    as every other Maintain* function -- a banked pause day quiets this
    too, consistent with it being framed as symptom relief.

    traits:add()/remove() ONLY flips the boolean in CharacterTraits' own
    internal map (confirmed via decompiling CharacterTraits.class -- its
    set() method is a plain map write, nothing else) -- it does NOT
    retroactively recompute anything that was derived from the trait at
    some earlier point. Vitamin A (Short Sighted) is exactly this case:
    IsoGameCharacter.class's blurFactorTarget (the actual vision-blur
    value) is only ever recalculated inside updateVisionEffects(), which
    itself is only ever CALLED from OnClothingUpdated() -- i.e. vanilla
    only rechecks hasTrait(SHORT_SIGHTED) when the player changes what
    they're wearing (glasses on/off, etc), never continuously. Confirmed
    as the exact cause of an earlier reported bug: granting the trait
    mid-game left blurFactorTarget stuck at its old value until a save
    reload's own initialization happened to call this once -- so the
    effect "did nothing" until relogging. Calling it explicitly here,
    right after any actual trait change, makes the blur (or its removal)
    apply immediately instead. Harmless to call for non-Short-Sighted
    vitamins too -- it only ever reads current hasTrait(SHORT_SIGHTED)/
    isWearingGlasses() state and writes blurFactorTarget, so it's a
    costless no-op unless A is the one that just changed.
]]--
function VitEffects.MaintainRealTrait(character, vit)
    if not HARMONIE_GTP.Config.effectsEnabled then return end

    local trait = RealTraitEffects[vit]
    if not trait then return end

    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, vit)
            and HARMONIE_GTP.VitData.GetPauseDays(character, vit) < 1

    local traits = character:getCharacterTraits()
    local hasTrait = character:hasTrait(trait)
    local changed = false

    if afflicted then
        if not hasTrait then
            traits:add(trait)
            HARMONIE_GTP.VitData.SetTraitGrantedByUs(character, vit, true)
            changed = true
        end
    else
        if hasTrait and HARMONIE_GTP.VitData.IsTraitGrantedByUs(character, vit) then
            traits:remove(trait)
            HARMONIE_GTP.VitData.SetTraitGrantedByUs(character, vit, false)
            changed = true
        end
    end

    if changed then
        character:updateVisionEffects()
    end
end

-- Human-readable summary of what actually applies for each vitamin --
-- used only by LogEffectStateChange below, purely for the console
-- message text.
local EffectDescription = {
    A = "real trait Short Sighted (vision blur)",
    B = "real trait Disorganized (reduced bag capacity, no auto-return of leftover crafting items)",
    C = "real trait Thin-Skinned (more easily cut/scratched)",
    D = "real trait Short of Breath / internal id Asthmatic (1.2x faster ENDURANCE loss)",
    E = "real trait All Thumbs (forces stopOnWalk during crafting, fumbles drops/transfers)",
    K = "real trait Slow Healer (wounds take longer to heal)",
}

--[[
    Permanent (not a temporary debug print, same philosophy as
    HARMONIE_GTP.LogMissingProfile in HARMONIE_FoodVitaminDatabase.lua)
    console.txt confirmation of exactly when a vitamin's Critical-band
    trait genuinely starts/stops being enforced -- added so it's possible
    to verify "did it actually kick in" straight from console.txt instead
    of having to dig through the Traits list in-game.

    Fires exactly ONCE per transition, not every 10-second tick -- an
    in-memory (deliberately NOT ModData; this is a log aid only and has
    no reason to survive a restart) weak-keyed table remembers the last
    known state per character+vitamin and only prints when it actually
    changes.

    The condition checked here -- afflicted AND less than 1 whole banked
    pause day -- is the exact same condition MaintainRealTrait gates on,
    so "active" here always means the trait for that vitamin is genuinely
    being granted starting this tick -- not merely that Reserve is under
    the Critical threshold, which alone doesn't guarantee the trait is
    live (e.g. while a banked pause day is still shielding it).
]]--
local lastEffectActive = setmetatable({}, { __mode = "k" })

function VitEffects.LogEffectStateChange(character, vit)
    local afflicted = HARMONIE_GTP.VitData.IsAfflicted(character, vit)
            and HARMONIE_GTP.VitData.GetPauseDays(character, vit) < 1

    lastEffectActive[character] = lastEffectActive[character] or {}
    local was = lastEffectActive[character][vit]
    if was == afflicted then return end
    lastEffectActive[character][vit] = afflicted

    local ok, name = pcall(function() return character:getDisplayName() end)
    name = (ok and name) or "?"

    if afflicted then
        print(string.format("[HARMONIE] %s: Vitamin %s hit Critical -- trait GRANTED (%s).",
            name, vit, EffectDescription[vit] or "?"))
    else
        print(string.format("[HARMONIE] %s: Vitamin %s no longer Critical (or now pause-day-shielded) -- trait REMOVED if we granted it (%s).",
            name, vit, EffectDescription[vit] or "?"))
    end
end

--[[
    Checked every 6 GAME hours (see HARMONIE_VitaminChecker.lua's
    getSixHourBlockIndex) -- completely decoupled from the trait
    maintenance above, since firing dialogue on the same schedule as the
    trait grant itself is what used to cause several symptom lines to
    fire back to back the moment more than one vitamin crossed into
    Critical at once. Instead: gather every vitamin CURRENTLY
    afflicted and not pause-day-shielded, pick exactly ONE at random, and
    say only that one's line -- so a character with three vitamins
    critical at once still only ever says one thing per 6-hour block, and
    which one comes up is random rather than always the same vitamin
    first.
]]--
function VitEffects.MaybeSaySymptomReminder(character, block)
    if not character or not character.Say then return end
    if HARMONIE_GTP.VitData.GetLastSymptomBlock(character) == block then return end

    local candidates = {}
    for _, vit in ipairs(HARMONIE_GTP.Vitamins) do
        if HARMONIE_GTP.VitData.IsAfflicted(character, vit)
                and HARMONIE_GTP.VitData.GetPauseDays(character, vit) < 1 then
            table.insert(candidates, vit)
        end
    end
    if #candidates == 0 then return end

    HARMONIE_GTP.VitData.SetLastSymptomBlock(character, block)
    sayRandomSymptom(character, candidates[ZombRand(#candidates) + 1])
end
