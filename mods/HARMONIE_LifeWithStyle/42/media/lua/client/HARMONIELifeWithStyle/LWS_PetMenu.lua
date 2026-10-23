--[[
    HARMONIE - Life With Style : the pet's right-click menu (client)

    Owner, 2026-10-23 (in-game test of 0.6.0): "Animal info" threw in
    ISAnimalUI (no avatar definition for our animals), "Pet" made the
    character stroke the air, "Pick up" put the pet in the inventory, and
    "Kill" must not exist. "ปิดการคลิกขวานี้ของ vanilla ไปเลย หรือแทนที่ ...
    ลูบ / ให้อาหาร / คำสั่ง: ตามมา อยู่ตรงนี้ มานี่ ส่งเสียงร้อง / เก็บ".

      * vanilla's animal menu (AnimalContextMenu.doMenu), the interact key
        on an animal (ContextualActionHandlers.AnimalsInteraction), picking
        up and the animal info window are switched off for OUR pets only --
        every other animal keeps them (the way Companion Dogs does it);
      * our menu instead, on the pet (OnClickedAnimalForContext) and
        anywhere for the owner's own pet out (LWS_Window.lua):
          Pet          -- anyone may; our own timed action with the raccoon
                          petting pose the dog / cat skeleton is rigged to
          Feed         -- the food you carry, and what a pet eats
          Orders       -- Follow / Stay, Come here, Speak
          Put away     -- back into the wardrobe
]]--

require "TimedActions/ISBaseTimedAction"
require "HARMONIELifeWithStyle/LWS_Core"
require "HARMONIELifeWithStyle/LWS_Client"

LWS.PetMenu = LWS.PetMenu or {}
local PM = LWS.PetMenu
local C = LWS.Client
local T = LWS.T
local log = function(...) LWS.log("PetMenu", ...) end

local function mp() return (isClient and isClient()) or (isServer and isServer()) end

-- my own pet out (the one the wardrobe says), or nil
function PM.isMine(animal)
    local pet = C.pet or {}
    if not pet.out or not animal or not LWS.isPetAnimal(animal) then return false end
    if not mp() then return true end   -- single player: the only pet there is
    local ok, id = pcall(function() return animal:getOnlineID() end)
    return ok and pet.id ~= nil and id == pet.id
end

-- the animal of my pet out, near me (for the petting action from the menu anywhere)
function PM.myAnimal()
    local pet = C.pet or {}
    if not pet.out then return nil end
    if mp() and pet.id and getAnimal then return getAnimal(pet.id) end
    local cell = getCell and getCell()
    local list = cell and cell:getAnimals()
    for i = 0, (list and list:size() or 0) - 1 do
        local a = list:get(i)
        if a and LWS.isPetAnimal(a) then return a end
    end
    return nil
end

-- ------------------------------------------------------------- petting
ISLWSPetAnimal = ISBaseTimedAction:derive("ISLWSPetAnimal")

function ISLWSPetAnimal:isValid()
    local ok, v = pcall(function() return self.animal:isExistInTheWorld() end)
    return ok and v == true
end

function ISLWSPetAnimal:waitToStart()
    pcall(function() self.character:faceThisObject(self.animal) end)
    return self.character:shouldBeTurning()
end

function ISLWSPetAnimal:update()
    pcall(function() self.character:faceThisObject(self.animal) end)
end

function ISLWSPetAnimal:start()
    -- the vanilla petting animation needs the pose of the animal's skeleton:
    -- ours are rigged to the raccoon one (Companion Dogs' finding)
    pcall(function()
        self:setOverrideHandModels(nil, nil)
        self.character:setVariable("AnimalSizeX", 0.01)
        self.character:setVariable("AnimalSizeY", 0.5)
        self.character:setVariable("animal", "raccoonboar")
        self.character:setVariable("petanimal", true)
        self.character:faceThisObject(self.animal)
    end)
    local id
    pcall(function() id = self.animal:getOnlineID() end)
    C.send("PetPet", { id = id })
    log("petting %s", tostring(id))
end

local function stopPose(self)
    pcall(function() self.character:setVariable("petanimal", false) end)
end
function ISLWSPetAnimal:stop() stopPose(self); ISBaseTimedAction.stop(self) end
function ISLWSPetAnimal:perform() stopPose(self); ISBaseTimedAction.perform(self) end
-- no complete(): a timed action with one is synced to the server as a net
-- action, which a dedicated server (no client Lua) rejects -- Companion Dogs' note

function ISLWSPetAnimal:new(character, animal)
    local o = ISBaseTimedAction.new(self, character)
    o.animal = animal
    o.maxTime = character:isTimedActionInstant() and 1 or 220
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function PM.pet(player, animal)
    if not player or not animal then return end
    local sq = animal:getSquare()
    if not sq then return end
    if luautils.walkAdj(player, sq) then
        ISTimedActionQueue.add(ISLWSPetAnimal:new(player, animal))
    end
end

-- ------------------------------------------------------------- the menu
local function tip(text)
    local t = ISWorldObjectContextMenu and ISWorldObjectContextMenu.addToolTip and ISWorldObjectContextMenu.addToolTip()
    if not t then t = ISToolTip:new(); t:initialise() end
    t.description = text
    return t
end

-- context: the menu; player; animal: the pet clicked (nil = from anywhere, my pet)
function PM.build(context, player, animal)
    if context.lwsPetMenu then return end   -- once per menu (the pet and the ground both fire)
    local mine = animal == nil or PM.isMine(animal)
    local pet = C.pet or {}
    if mine and not pet.out then return end
    animal = animal or PM.myAnimal()
    context.lwsPetMenu = true
    local name = mine and pet.piece and LWS.pieceName(pet.piece) or T("IGUI_LWS_PetSomeone")
    local opt = context:addOption(T("IGUI_LWS_Menu_Pet", name), player, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(opt, sub)
    -- pet (anyone)
    local po = sub:addOption(T("IGUI_LWS_PetStroke"), player, function(p) PM.pet(p, animal) end)
    if not animal then po.notAvailable = true; po.toolTip = tip(T("IGUI_LWS_PetTooFar")) end
    if not mine then return end
    -- feed
    if pet.feeding ~= false then
        local fo = sub:addOption(T("IGUI_LWS_PetFeed"), player, nil)
        local fsub = ISContextMenu:getNew(sub)
        sub:addSubMenu(fo, fsub)
        local info = fsub:addOption(T("IGUI_LWS_PetFoodWhat"), nil, nil)
        info.notAvailable = true
        info.toolTip = tip(T("IGUI_LWS_PetFoodInfo"))
        local foods = C.petFoods()
        if #foods == 0 then
            local o = fsub:addOption(T("IGUI_LWS_Msg_PetNoFood"), nil, nil)
            o.notAvailable = true
        end
        for i = 1, math.min(10, #foods) do
            local f = foods[i]
            fsub:addOption(f.name .. " (" .. f.n .. ")  +" .. math.floor(f.value * 100 + 0.5) .. "%", player, function() C.petFeed(f.type) end)
        end
    end
    -- orders
    if pet.commands ~= false then
        local co = sub:addOption(T("IGUI_LWS_PetOrders"), player, nil)
        local csub = ISContextMenu:getNew(sub)
        sub:addSubMenu(co, csub)
        local f = csub:addOption(T("IGUI_LWS_PetFollow"), player, function() C.petMode("follow") end)
        local s = csub:addOption(T("IGUI_LWS_PetStay"), player, function() C.petMode("stay") end)
        if pet.mode == "stay" then s.notAvailable = true else f.notAvailable = true end
        csub:addOption(T("IGUI_LWS_PetCome"), player, function() C.petCome() end)
        csub:addOption(T("IGUI_LWS_PetSpeak"), player, function() C.petSpeak() end)
    end
    -- put away
    sub:addOption(T("IGUI_LWS_PetPutAway"), player, function()
        log("menu: put the pet away")
        C.takeOff("pet")
    end)
    sub:addOption(T("IGUI_LWS_OpenPet"), player, function(p)
        if LWSWindow and LWSWindow.open then
            LWSWindow.open(p, "dress")
            if LWSWindow.window then LWSWindow.window.slot = "pet"; LWSWindow.window.dressFilter = "slot" end
        end
    end)
end

-- right-click on animals: ours get our menu
local function onClickedAnimals(playerNum, context, animals)
    local player = getSpecificPlayer(playerNum)
    if not player or type(animals) ~= "table" then return end
    for _, a in ipairs(animals) do
        if LWS.isPetAnimal(a) then
            local ok, err = pcall(PM.build, context, player, a)
            if not ok then LWS.logOnce("petmenuerr", "PetMenu", "pet menu FAILED: %s", tostring(err)) end
            return
        end
    end
end

-- ------------------------------------------------------------- vanilla, off for our pets
function PM.installHooks()
    local n = 0
    if AnimalContextMenu and AnimalContextMenu.doMenu and not AnimalContextMenu.lwsWrapped then
        AnimalContextMenu.lwsWrapped = true
        local orig = AnimalContextMenu.doMenu
        AnimalContextMenu.doMenu = function(player, context, animal, test)
            if LWS.isPetAnimal(animal) then return end
            return orig(player, context, animal, test)
        end
        n = n + 1
    end
    if AnimalContextMenu and AnimalContextMenu.onPickupAnimal and not AnimalContextMenu.lwsPickupWrapped then
        AnimalContextMenu.lwsPickupWrapped = true
        local orig = AnimalContextMenu.onPickupAnimal
        AnimalContextMenu.onPickupAnimal = function(animal, chr, ...)
            if LWS.isPetAnimal(animal) then log("blocked picking up a pet"); return end
            return orig(animal, chr, ...)
        end
        n = n + 1
    end
    if AnimalContextMenu and AnimalContextMenu.onAnimalInfo and not AnimalContextMenu.lwsInfoWrapped then
        AnimalContextMenu.lwsInfoWrapped = true
        local orig = AnimalContextMenu.onAnimalInfo
        AnimalContextMenu.onAnimalInfo = function(animal, ...)
            if LWS.isPetAnimal(animal) then log("blocked the vanilla animal info of a pet"); return end
            return orig(animal, ...)
        end
        n = n + 1
    end
    if ContextualActionHandlers and ContextualActionHandlers.AnimalsInteraction and not ContextualActionHandlers.lwsWrapped then
        ContextualActionHandlers.lwsWrapped = true
        local orig = ContextualActionHandlers.AnimalsInteraction
        ContextualActionHandlers.AnimalsInteraction = function(action, playerObj, animal, ...)
            if LWS.isPetAnimal(animal) then return end
            return orig(action, playerObj, animal, ...)
        end
        n = n + 1
    end
    log("vanilla animal actions switched off for pets: %d hooks%s", n, n < 4 and " (some vanilla functions not found)" or "")
end

if Events and not PM.registered then
    PM.registered = true
    if Events.OnClickedAnimalForContext then
        Events.OnClickedAnimalForContext.Add((HARMONIE_Ours or function(f) return f end)(onClickedAnimals, "LWS"))
    else
        log("no OnClickedAnimalForContext event -- the pet menu is only on the ground right-click")
    end
    if Events.OnGameStart then Events.OnGameStart.Add(PM.installHooks) end
end

return PM
