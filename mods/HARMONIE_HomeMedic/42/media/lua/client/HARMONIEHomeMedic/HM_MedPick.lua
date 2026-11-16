--[[
    HARMONIE - How to Survive : diagnose -> medicine, no searching

    Owner, 2026-11-16: "Harmonie วินิจฉัย ให้ ไปต่อที่ใช้ยาเลย ไม่ต้องหายาเอง".
    After a diagnosis (the result window) and on a diagnosed illness's row
    (tab 1) a "Use medicine" button opens this small window over the medical
    window. It lists every medicine that treats that illness (the medicine
    database's `treats`) found on you, in your bags and in the boxes of your
    room (HM_Reach = the hub's HARMONIE_Reach), carried ones first, with
    whether you can take it now (EHR.Medication.CanUseMedication -- too early,
    overdose risk...). "Use" queues EHR's own medication action
    (EHR.MedicationAction.QueueUseMedication); an item in a box is brought
    first (HM_Reach.bring: walk + vanilla transfer). Nothing about doses,
    effects or the server changes -- it is the same use as the right-click.

    Someone else's window (a doctor treating a patient): EHR's own
    "Administer Medication" window with the patient's consent opens instead
    (EHR.MPMedication.Open, it lists the doctor's medicines within reach).
]]--

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "HARMONIEHomeMedic/HM_Text"

HM_MedPick = HM_MedPick or {}
local M = HM_MedPick
HM_MedPickUI = ISPanel:derive("HM_MedPickUI")
local UI = HM_MedPickUI

local FONT, FONT_M = UIFont.Small, UIFont.Medium
local function fh(f) return getTextManager():getFontHeight(f or FONT) end
local function tw(t, f) return getTextManager():MeasureStringX(f or FONT, t or "") end
local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_MedPick_" .. key, fallback, ...) end
local function log(fmt, ...) if HMLog then HMLog("MedPick", fmt, ...) end end
local function nameOfItem(it) return HMLogType and HMLogType(it) or "?" end

local function normalize(id)
    local D = HM_Diagnosis
    if D and D.normalize then return D.normalize(id) end
    return id
end

local function diseaseName(id)
    local c = HM_Diagnosis and HM_Diagnosis.Client
    if c and c.diseaseName then return c.diseaseName(id) end
    return tostring(id)
end

local function treats(md, id)
    for _, t in ipairs(type(md.treats) == "table" and md.treats or {}) do
        if normalize(t) == id then return true end
    end
    return false
end

-- every medicine within reach that treats `id`, one entry per item type:
-- { type, md, name, items = {...}, carried = n, total = n }
function M.candidates(player, id)
    id = normalize(id)
    local DB = EHR and EHR.Medication and EHR.Medication.Database
    local R = HM_Reach
    if not (DB and R and R.each and player) then return {} end
    local byType, list = {}, {}
    R.each(player, function(item)
        local ok, ft = pcall(function() return item:getFullType() end)
        local md = ok and ft and DB[ft] or nil
        if md and not md.useVanillaActionOnly and treats(md, id) then
            local e = byType[ft]
            if not e then
                local name = EHR.Medication.GetDisplayName and EHR.Medication.GetDisplayName(ft, md) or ft
                e = { type = ft, md = md, name = tostring(name), items = {}, carried = 0, total = 0 }
                byType[ft] = e
                list[#list + 1] = e
            end
            local carried = R.isCarried and R.isCarried(player, item) or false
            -- carried items first, so "Use" takes the one in your pocket
            if carried then table.insert(e.items, e.carried + 1, item); e.carried = e.carried + 1
            else e.items[#e.items + 1] = item end
            e.total = e.total + 1
        end
        return nil
    end)
    table.sort(list, function(a, b)
        if (a.carried > 0) ~= (b.carried > 0) then return a.carried > 0 end
        return a.name < b.name
    end)
    return list
end

-- can the player take this one now? -> ok, reason text
function M.canUse(player, item)
    local Med = EHR and EHR.Medication
    if not (Med and Med.CanUseMedication) then return true, nil end
    local ok, can, reason, reasonKey = pcall(Med.CanUseMedication, player, item)
    if not ok then return true, nil end
    if can then return true, nil end
    local txt = Med.GetCanUseReasonText and Med.GetCanUseReasonText(reason, reasonKey) or tostring(reason or "")
    return false, txt
end

function M.use(player, entry)
    local item = entry and entry.items and entry.items[1]
    if not (player and item and EHR and EHR.MedicationAction) then return false end
    local R = HM_Reach
    if R and R.isCarried and not R.isCarried(player, item) and R.bring then
        -- a box in the room: walk there, take it, then use it
        R.bring(player, item)
        ISTimedActionQueue.add(EHRMedicationAction:new(player, item, entry.md))
        log("%s uses %s from a box in the room (brought first)", HMLogName and HMLogName(player) or "?", nameOfItem(item))
    else
        EHR.MedicationAction.QueueUseMedication(player, item, entry.md)
        log("%s uses %s (carried)", HMLogName and HMLogName(player) or "?", nameOfItem(item))
    end
    return true
end

-- panel = the medical window, id = the illness
function M.open(panel, id)
    if not panel then return end
    id = normalize(id)
    if panel.isRemoteHealthPanel then
        -- a patient: EHR's administer window (consent, the doctor's medicines)
        log("someone else's window: opening Administer Medication for %s", tostring(id))
        if panel.onOpenMedicationAdminister then panel:onOpenMedicationAdminister() end
        return
    end
    if panel.hmMedPick then panel.hmMedPick:close() end
    local W, H = math.min(520, panel.width - 20), math.min(380, panel.height - 40)
    local o = ISPanel.new(UI, math.floor((panel.width - W) / 2), math.floor((panel.height - H) / 2), W, H)
    o.panel, o.id, o.player = panel, id, panel.player
    o.backgroundColor = { r = 0.012, g = 0.05, b = 0.068, a = 0.97 }
    o.borderColor = { r = 0.3, g = 0.84, b = 1.0, a = 1 }
    o.moveWithMouse = false
    o:initialise()
    o:instantiate()
    panel:addChild(o)
    panel.hmMedPick = o
    o:refresh()
    log("medicine for %s: %d kind(s) within reach", tostring(id), #(o.list or {}))
    return o
end

function UI:refresh()
    self.list = M.candidates(self.player, self.id)
    -- whether each can be taken now, once per refresh (not every frame)
    for _, e in ipairs(self.list) do e.can, e.why = M.canUse(self.player, e.items[1]) end
    self.refreshedAt = getTimestampMs and getTimestampMs() or 0
end

function UI:close()
    if self.panel and self.panel.hmMedPick == self then self.panel.hmMedPick = nil end
    self:setVisible(false)
    if self.panel then self.panel:removeChild(self) end
end

local function button(self, key, label, x, y, w, h, enabled, hot)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = enabled and mx >= x and mx <= x + w and my >= y and my <= y + h
    local a = enabled and (over and 1 or 0.85) or 0.3
    if hot then self:drawRect(x, y, w, h, a, 0.05, 0.32, 0.18) else self:drawRect(x, y, w, h, a, 0.03, 0.24, 0.34) end
    self:drawRectBorder(x, y, w, h, enabled and 1 or 0.4, 0.3, 0.84, 1.0)
    self:drawText(label, x + math.floor((w - tw(label)) / 2), y + math.floor((h - fh()) / 2), 0.92, 0.95, 0.98, enabled and 1 or 0.5, FONT)
    if enabled then self.hits[#self.hits + 1] = { x = x, y = y, w = w, h = h, key = key } end
end

function UI:prerender()
    ISPanel.prerender(self)
    -- the medicines move (used, taken by someone): look again every 2 s
    local now = getTimestampMs and getTimestampMs() or 0
    if now - (self.refreshedAt or 0) > 2000 then self:refresh() end
    self.hits = {}
    local w = self.width
    self:drawRect(0, 0, w, 34, 0.95, 0.03, 0.052, 0.08)
    self:drawRect(10, 33, w - 20, 1, 0.8, 0.22, 0.72, 0.95)
    local title = L("Title", "MEDICINE FOR %1", diseaseName(self.id))
    self:drawText(title, 12, math.floor((34 - fh(FONT_M)) / 2), 0.3, 0.84, 1.0, 1, FONT_M)
    local bh = fh() + 10
    local y = 44
    local list = self.list or {}
    if #list == 0 then
        local msg = L("None", "No medicine that treats this illness is on you, in your bags or in the boxes of this room.")
        for _, l in ipairs(HM_Surgery and HM_Surgery.wrap(msg, w - 40, FONT) or { msg }) do
            self:drawText(l, 20, y, 0.85, 0.75, 0.45, 1, FONT); y = y + fh() + 2
        end
        y = y + 8
        local hint = L("NoneHint", "The Medication Handbook says which medicines treat it.")
        for _, l in ipairs(HM_Surgery and HM_Surgery.wrap(hint, w - 40, FONT) or { hint }) do
            self:drawText(l, 20, y, 0.6, 0.67, 0.74, 1, FONT); y = y + fh() + 2
        end
    else
        local hint = L("Hint", "Found on you, in your bags and in the boxes of this room. Use = the same as the right-click; a box item is fetched first.")
        for _, l in ipairs(HM_Surgery and HM_Surgery.wrap(hint, w - 40, FONT) or { hint }) do
            self:drawText(l, 20, y, 0.6, 0.67, 0.74, 1, FONT); y = y + fh() + 2
        end
        y = y + 6
        local bottom = self.height - bh - 24
        for i, e in ipairs(list) do
            if y + bh + fh() + 6 > bottom then break end
            local rowH = bh + fh() + 8
            self:drawRect(14, y, w - 28, rowH, 0.5, 0.04, 0.10, 0.14)
            self:drawRectBorder(14, y, w - 28, rowH, 0.6, 0.11, 0.24, 0.42)
            local where = e.carried > 0 and L("Carried", "on you: %1", e.carried) or L("InBox", "in a box in this room")
            if e.carried > 0 and e.total > e.carried then where = where .. " / " .. L("AlsoBox", "%1 more in boxes", e.total - e.carried) end
            local canUse, why = e.can ~= false, e.why
            local bw = math.max(90, tw(L("Use", "Use")) + 30)
            local name = HM_Surgery and HM_Surgery.fitText(e.name, w - 60 - bw, function(s) return tw(s, FONT) end) or e.name
            self:drawText(name, 22, y + 5, 0.92, 0.95, 0.98, 1, FONT)
            local sub = canUse and where or (why or "")
            sub = HM_Surgery and HM_Surgery.fitText(sub, w - 60 - bw, function(s) return tw(s, FONT) end) or sub
            self:drawText(sub, 22, y + 7 + fh(), canUse and 0.6 or 0.95, canUse and 0.67 or 0.55, canUse and 0.74 or 0.4, 1, FONT)
            button(self, "use:" .. i, L("Use", "Use"), w - 22 - bw, y + math.floor((rowH - bh) / 2), bw, bh, canUse, true)
            y = y + rowH + 6
        end
    end
    -- bottom row: Medication Handbook / Close
    local cw = math.max(100, tw(L("Close", "Close")) + 30)
    local hw = math.max(150, tw(L("Handbook", "Medication Handbook")) + 30)
    local by = self.height - bh - 12
    button(self, "handbook", L("Handbook", "Medication Handbook"), w - 14 - cw - 8 - hw, by, hw, bh, true)
    button(self, "close", L("Close", "Close"), w - 14 - cw, by, cw, bh, true)
end

function UI:onMouseDown(x, y)
    for _, h in ipairs(self.hits or {}) do
        if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then
            pcall(function() getSoundManager():playUISound("UISelectListItem") end)
            if h.key == "close" then self:close()
            elseif h.key == "handbook" then
                local panel = self.panel
                self:close()
                if panel and panel.setActiveTab then panel:setActiveTab("meds") end
            else
                local i = tonumber(h.key:match("^use:(%d+)$"))
                local e = i and self.list and self.list[i]
                if e and M.use(self.player, e) then self:close() end
            end
            return true
        end
    end
    return true
end
function UI:onMouseUp(x, y) return true end
function UI:onMouseWheel(del) return true end

return M
