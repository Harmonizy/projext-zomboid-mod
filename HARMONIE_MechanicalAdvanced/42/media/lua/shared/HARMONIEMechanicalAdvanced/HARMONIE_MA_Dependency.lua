require "ATA2TuningTable"

if ATA2TuningTable == nil or ATA2Tuning_AddNewCars == nil then
    error("HARMONIE - Mechanical Advanced requires tsarslib (Tsar's Common Library) to be enabled, and could not find its Tuning2 API. Check that tsarslib is subscribed and enabled before this mod.")
end
