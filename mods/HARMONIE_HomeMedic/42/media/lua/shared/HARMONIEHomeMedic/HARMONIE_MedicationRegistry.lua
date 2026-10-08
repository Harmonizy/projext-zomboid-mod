--[[
    HARMONIE - Home Medic (inspired by EHR) - Medication Registry

    Registers this addon's 4 new items into EHR's own data-driven medication
    system (EHR.Medication.Database / EHR.Medication.DosingSchedules) instead
    of touching any EHR file directly. EHR_MedicationHook.lua looks items up
    by full type in EHR.Medication.Database, so simply adding entries here is
    enough to make these items fully usable as treatments.
]]--

require "ExtensiveHealth/EHR_Medication"

if not EHR or not EHR.Medication or not EHR.Medication.Database then
    if HMLog then HMLog("Meds", "EHR.Medication.Database not found, skipping registration") else print("HARMONIEHomeMedic: EHR.Medication.Database not found, skipping registration") end
    return
end

EHR.Medication.Database["HARMONIEHomeMedic.GingerBugTonic"] = {
    tier = 2,
    treats = {"gastroenteritis"},
    displayName = "Fermented Ginger-Bug Tonic",
    usageMessage = "You drink the ginger-bug tonic. Your stomach starts to settle.",
    cureTimeHours = 36,
}

EHR.Medication.Database["HARMONIEHomeMedic.GraveAshGarlicPoultice"] = {
    tier = 2,
    treats = {"corpse_sickness"},
    displayName = "Grave Ash & Garlic Poultice",
    usageMessage = "You apply the poultice. The nausea and weakness start to fade.",
    cureTimeHours = 24,
}

EHR.Medication.Database["HARMONIEHomeMedic.WarmingSpicedBitters"] = {
    tier = 1,
    treats = {"hypothermia"},
    displayName = "Warming Spiced Bitters",
    usageMessage = "You drink the spiced bitters. Warmth spreads through you, but you still need real shelter and a fire.",
}

EHR.Medication.Database["HARMONIEHomeMedic.WillowBarkAntitoxinBooster"] = {
    tier = 2,
    treats = {"tetanus"},
    displayName = "Willow Bark & Herb Antitoxin Booster",
    usageMessage = "You take the herbal booster alongside your antitoxin. It may help your body fight off the lockjaw.",
    cureTimeHours = 72,
}

if EHR.Medication.DosingSchedules then
    EHR.Medication.DosingSchedules["HARMONIEHomeMedic.GingerBugTonic"] = { doseInterval = 6, dosesRequired = 6 }
    EHR.Medication.DosingSchedules["HARMONIEHomeMedic.GraveAshGarlicPoultice"] = { doseInterval = 0, dosesRequired = 1 }
    EHR.Medication.DosingSchedules["HARMONIEHomeMedic.WarmingSpicedBitters"] = { doseInterval = 2, dosesRequired = 1, activeHours = 2 }
    EHR.Medication.DosingSchedules["HARMONIEHomeMedic.WillowBarkAntitoxinBooster"] = { doseInterval = 24, dosesRequired = 3 }
end

if HMLog then HMLog("Meds", "registered 4 items with EHR.Medication.Database") else print("HARMONIEHomeMedic: registered 4 items with EHR.Medication.Database") end
