EHRCharacterTraits = EHRCharacterTraits or {}
EHRCharacterProfessions = EHRCharacterProfessions or {}

EHRCharacterTraits.patientzero = CharacterTrait.register("ExtensiveHealth:patientzero")
EHRCharacterTraits.scalpelmaster = CharacterTrait.register("ExtensiveHealth:scalpelmaster")

EHRCharacterProfessions.ehrdoctor = CharacterProfession.register("ExtensiveHealth:ehrdoctor")
EHRCharacterProfessions.ehrsurgeon = CharacterProfession.register("ExtensiveHealth:ehrsurgeon")

-- The Only Cure (merged by tools/merge_toc.py) >>>
_TOCRegistries = {}

_TOCRegistries.traits = {
    Amputee_Hand = CharacterTrait.register("toc:amputee_hand"),
    Amputee_ForeArm = CharacterTrait.register("toc:amputee_forearm"),
    Amputee_UpperArm = CharacterTrait.register("toc:amputee_upperarm"),
}

_TOCRegistries.bodylocations = {
    TOC_Arm_L = ItemBodyLocation.register("toc:Arm_L"),
    TOC_Arm_R = ItemBodyLocation.register("toc:Arm_R"),
    TOC_ArmProst_L = ItemBodyLocation.register("toc:ArmProst_L"),
    TOC_ArmProst_R = ItemBodyLocation.register("toc:ArmProst_R"),
    TOC_ArmAccessory_L = ItemBodyLocation.register("toc:ArmAccessory_L"),
    TOC_ArmAccessory_R = ItemBodyLocation.register("toc:ArmAccessory_R"),
}
-- <<< The Only Cure
