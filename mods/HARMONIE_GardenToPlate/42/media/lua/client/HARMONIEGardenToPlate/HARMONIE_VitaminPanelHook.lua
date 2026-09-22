--[[
    HARMONIE - From Garden to Plate
    Adds a "Vitamins" tab to the vanilla character info window (the panel
    opened from the main game UI, not the "N" hotkey window -- see
    HARMONIE_VitaminPanel.lua's header for the distinction), so the vitamin
    system is actually discoverable instead of hidden behind a hotkey almost
    nobody knows about.

    Call-through wrap on ISCharacterInfoWindow:createChildren (media/lua/
    client/XpSystem/ISUI/ISCharacterInfoWindow.lua), same safe cross-mod
    hooking pattern documented in mods/workflow.txt section 4 -- global
    function, not a local, so it's wrappable: call the original first so
    every vanilla tab (Info/Skills/Health/Protection/Clothing) is built and
    self.panel/self.characterView already exist, then add one more tab the
    exact same way vanilla adds its own (self.panel:addView(title, view)).

    Reuses self.characterView's already-computed width/height instead of
    recomputing tabTotalWidth itself -- that value is a local inside vanilla's
    own createChildren (the "nasty way ... there's no way to get the total
    length of all the tabs before they've been added" it comments on itself),
    not something this wrap can reach directly, but self.characterView is a
    real field already sized to that exact width by the time our wrapped
    call runs.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminPanel"

local originalCreateChildren = ISCharacterInfoWindow.createChildren

ISCharacterInfoWindow.createChildren = function(self, ...)
    originalCreateChildren(self, ...)

    if not self.characterView then return end

    local width = self.characterView:getWidth()
    local height = self.characterView:getHeight()

    self.vitaminView = HARMONIE_VitaminPanel:new(0, 8, width, height, self.playerNum)
    self.vitaminView:initialise()
    self.panel:addView(getText("IGUI_HARMONIE_VitaminTabTitle"), self.vitaminView)
end
