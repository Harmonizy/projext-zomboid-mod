windows = nil
lastX = 100
lastY = 100

attachmentInfo = {{
    type = "Canon",
    x = 90,
    y = 180
}, {
    type = "Barrel",
    x = 90,
    y = (180 + 337) / 2
}, {
    type = "Laser",
    x = 90,
    y = 337
}, {
    type = "Light",
    x = 212,
    y = 466 + 144
}, {
    type = "Stool",
    x = 212,
    y = 416 + 144
}, {
    type = "Grip",
    x = 342 + 100,
    y = 416 + 144
}, {
    type = "Skin",
    x = 608 + 300,
    y = 280 + 200 - 40
}, {
    type = "Misc",
    x = 342 + 100,
    y = 466 + 144
}, {
    type = "Scope",
    x = 342 + 100,
    y = 100
}, {
    type = "R_Scope",
    x = 472 + 200,
    y = 100
}, {
    type = "L_Scope",
    x = 212,
    y = 100
}, {
    type = "Sling",
    x = 608 + 300,
    y = 180
}, {
    type = "Stock",
    x = 608 + 300,
    y = 230 + 100
}, {
    type = "RecoilPad",
    x = 608 + 300,
    y = 280 + 200
}, {
    type = "Barrel_Shroud",
    x = 608 + 300,
    y = 100
}};
attachmentButtonsInfo = {{
    type = "Canon",
    x = 40,
    y = 180
}, {
    type = "Barrel",
    x = 40,
    y = (180 + 337) / 2
}, {
    x = 40,
    y = 330,
    method = "getLaser",
    type = "Laser"
}, {
    x = 162,
    y = 416 + 144,
    method = "getStool",
    type = "Stool"
}, {
    x = 162,
    y = 466 + 144,
    method = "getLight",
    type = "Light"
}, {
    x = 292 + 100,
    y = 416 + 144,
    method = "getGrip",
    type = "Grip"
}, {
    x = 558 + 300,
    y = 280 + 200 - 40,
    method = "getSkin",
    type = "Skin"
}, {
    x = 292 + 100,
    y = 466 + 144,
    method = "getMisc",
    type = "Misc"
}, {
    x = 292 + 100,
    y = 100,
    method = "getScope",
    type = "Scope"
}, {
    x = 422 + 200,
    y = 100,
    method = "getR_Scope",
    type = "R_Scope"
}, {
    x = 162,
    y = 100,
    method = "getL_Scope",
    type = "L_Scope"
}, {
    x = 558 + 300,
    y = 180,
    method = "getSling",
    type = "Sling"
}, {
    x = 558 + 300,
    y = 230 + 100,
    method = "getStock",
    type = "Stock"
}, {
    x = 558 + 300,
    y = 280 + 200,
    method = "getRecoilPad",
    type = "RecoilPad"
}, {
    x = 558 + 300,
    y = 100,
    method = "getBarrel_Shroud",
    type = "Barrel_Shroud"
}};

function getWeaponAttackType(MainGun, table)
    if MainGun:getModData()["AttackType"] == nil then
        MainGun:getModData()["AttackType"] = table[1]
    end
    return MainGun:getModData()["AttackType"]
end

function SetWeaponAttackType(MainGun, selectType)
    if string.find(selectType, "bolt") then
        ChangeAmmo(getPlayer(), MainGun, selectType)
        -- ChangeAmmo mutates the weapon on the client only; sync the resulting
        -- HandWeapon fields to the server so the new ammo type persists in MP.
        syncHandWeaponFields(getPlayer(), MainGun)
        return
    end
    if string.find(selectType, "AR") then
        ISTimedActionQueue.add(TakeTimeAction:new(getPlayer(), selectType, MainGun))
        return
    end
    MainGun:getModData()["AttackType"] = selectType
    syncHandWeaponFields(getPlayer(), MainGun)
end

function HasWeaponAttackType(MainGun)
    if MainGun:getModData()["AttackType"] == nil then
        return false
    end
    return MainGun:getModData()["AttackType"]
end

