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
    self.panel already exists, then add one more tab the exact same way
    vanilla adds its own (self.panel:addView(title, view)).

    Width: use self.panel:getWidth() as a starting size, NOT
    self.characterView:getWidth() -- confirmed by reading vanilla's own
    createChildren that self.characterView (the Skills tab) is initially
    created at only `tabTotalWidth` (just wide enough for the 5 tab labels,
    ~300px), and only grows wider later, during ISCharacterInfo:render()'s
    own documented "BIG CHEAT" (self:setWidthAndParentWidth(...) in
    ISCharacterInfo.lua) -- which hasn't run yet at the point our wrapped
    createChildren executes. Reading its width here previously captured that
    too-narrow starting value, producing a cramped panel with heavily
    word-wrapped Thai text (real user report, screenshot of the "Vitamins"
    tab looking squeezed). HARMONIE_VitaminPanel.lua now does the same
    self:setWidthAndParentWidth() growth trick itself, every prerender frame
    while visible, exactly like vanilla's Skills tab does -- so the starting
    width here only matters for the very first frame.
]]--

require "HARMONIEGardenToPlate/HARMONIE_VitaminPanel"

local originalCreateChildren = ISCharacterInfoWindow.createChildren

ISCharacterInfoWindow.createChildren = function(self, ...)
    originalCreateChildren(self, ...)

    if not self.panel then return end

    local width = self.panel:getWidth()
    local height = self.height - 8

    self.vitaminView = HARMONIE_VitaminPanel:new(0, 8, width, height, self.playerNum)
    self.vitaminView:initialise()
    self.panel:addView(getText("IGUI_HARMONIE_VitaminTabTitle"), self.vitaminView)
end
