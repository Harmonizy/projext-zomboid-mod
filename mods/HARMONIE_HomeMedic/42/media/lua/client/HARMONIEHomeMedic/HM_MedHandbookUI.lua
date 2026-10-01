--[[
    HARMONIE - Home Medic : the medication handbook (client)

    Request 2026-10-01: a handbook of every medicine, laid out like the
    disease handbook (list + details, search box, filter chips), with the
    item's own picture, split into medicines that really CURE an illness of
    the disease handbook and those that only ease the symptoms.

    Built on EHR_MedicalJournalUI (same frame, search and filters); the
    data comes from EHR.Medication.Database through HM_Handbook.meds():
    treats, tier, symptomReduction, dosing schedule, cure time, side effects.
    The medical window shows it embedded in its "meds" tab.
]]--

require "ExtensiveHealth/EHR_MedicalJournalUI"
require "HARMONIEHomeMedic/HM_Text"
require "HARMONIEHomeMedic/HM_Handbook"

HM_MedHandbookUI = EHR_MedicalJournalUI:derive("HM_MedHandbookUI")
local M = HM_MedHandbookUI
local H = HM_Handbook

local function L(key, fallback, ...) return HM_Text("UI_HomeMedic_Med_" .. key, fallback, ...) end
local function fh(f) return getTextManager():getFontHeight(f or UIFont.Small) end
local function tw(t, f) return getTextManager():MeasureStringX(f or UIFont.Small, t or "") end
local function fit(t, w, f)
    return HM_Surgery and HM_Surgery.fitText(t, w, function(x) return tw(x, f) end) or t
end
local function pct(v) return tostring(math.floor((tonumber(v) or 0) * 100 + 0.5)) .. "%" end
local function hoursText(h)
    h = tonumber(h) or 0
    if h >= 48 and h % 24 == 0 then return L("Days", "%1 days", math.floor(h / 24)) end
    return L("Hours", "%1 h", (h == math.floor(h)) and tostring(math.floor(h)) or string.format("%.1f", h))
end

local C = { -- same palette as the disease handbook (HM_Theme blue)
    text = { r = 0.9, g = 0.93, b = 0.97 }, textDim = { r = 0.6, g = 0.67, b = 0.74 },
    accent = { r = 0.32, g = 0.7, b = 1.0 }, green = { r = 0.18, g = 0.92, b = 0.32 },
    blue = { r = 0.35, g = 0.75, b = 1.0 }, border = { r = 0.22, g = 0.5, b = 0.85 },
    borderDim = { r = 0.11, g = 0.24, b = 0.42 }, panel = { r = 0.04, g = 0.062, b = 0.09 },
    sel = { r = 0.05, g = 0.16, b = 0.32 }, yellow = { r = 1.0, g = 0.78, b = 0.12 }, red = { r = 0.95, g = 0.3, b = 0.25 },
}

function M:new(x, y, w, h, player, embedded)
    local o = EHR_MedicalJournalUI.new(self, x, y, w, h, player, embedded)
    o.iconCache = {}
    return o
end

-- ------------------------------------------------------------- texts
function M:titleText() return L("Title", "MEDICATION HANDBOOK") end
function M:indexTitle() return L("Index", "MEDICINES") end
function M:progressText()
    local cure = 0
    for _, e in ipairs(self.allEntries or {}) do if e.curative then cure = cure + 1 end end
    return L("Count", "%1 medicines - %2 cure", #(self.allEntries or {}), cure)
end

-- ------------------------------------------------------------- entries
local function diseaseName(id)
    local c = HM_Diagnosis and HM_Diagnosis.Client
    if c and c.diseaseName then
        local ok, n = pcall(c.diseaseName, id)
        if ok and n then return n end
    end
    return id
end

function M:getCatalogEntries()
    local out = {}
    for _, m in ipairs(H.meds()) do
        out[#out + 1] = { id = m.id, med = m.med, displayName = m.name, realName = m.name, known = true,
            curative = m.curative, tier = m.tier, treats = m.treats }
    end
    return out
end

function M:getFilters()
    return {
        { id = "all", label = L("Filter_all", "All") },
        { id = "cure", label = L("Filter_cure", "Cures") },
        { id = "ease", label = L("Filter_ease", "Eases symptoms") },
    }
end

function M:entryMatches(entry, filter)
    if filter == "cure" then return entry.curative end
    if filter == "ease" then return not entry.curative end
    return true
end

-- search: name, kind, the illnesses it treats and the symptoms it eases
function M:searchText(entry)
    local parts = { entry.displayName or "", entry.curative and L("Kind_cure", "Cures") or L("Kind_ease", "Eases symptoms") }
    for _, t in ipairs(entry.treats or {}) do parts[#parts + 1] = diseaseName(t) end
    for k in pairs(type(entry.med.symptomReduction) == "table" and entry.med.symptomReduction or {}) do
        parts[#parts + 1] = L("Relief_" .. tostring(k), tostring(k))
    end
    return string.lower(table.concat(parts, " "))
end

-- ------------------------------------------------------------- icons
function M:itemIcon(fullType, med)
    if self.iconCache[fullType] ~= nil then return self.iconCache[fullType] or nil end
    local tex = nil
    local names = {}
    local sm = getScriptManager and getScriptManager()
    if sm then
        local ok, it = pcall(function() return sm:FindItem(fullType) end)
        if ok and it and it.getIcon then
            local okI, icon = pcall(function() return it:getIcon() end)
            if okI and icon and icon ~= "" then names[#names + 1] = icon end
        end
    end
    if med and med.icon then names[#names + 1] = med.icon end
    for _, n in ipairs(names) do
        for _, path in ipairs({ "Item_" .. n, "media/textures/Item_" .. n .. ".png" }) do
            local ok, t = pcall(getTexture, path)
            if ok and t then tex = t; break end
        end
        if tex then break end
    end
    self.iconCache[fullType] = tex or false
    return tex
end

-- list row (ISScrollingListBox doDrawItem: self = the list)
function M.drawListItem(list, y, item, alt)
    local ui = list.parentUI
    local e = item and item.item
    if not ui or not e then return y + list.itemheight end
    local selected = list.selected == item.index or (list.items and list.items[list.selected] == item)
    local w = list:getWidth()
    local bg = selected and C.sel or C.panel
    list:drawRect(4, y + 4, w - 12, list.itemheight - 8, selected and 0.82 or (alt and 0.38 or 0.24), bg.r, bg.g, bg.b)
    list:drawRectBorder(4, y + 4, w - 12, list.itemheight - 8, 1, selected and C.border.r or C.borderDim.r,
        selected and C.border.g or C.borderDim.g, selected and C.border.b or C.borderDim.b)
    local icon = ui:itemIcon(e.id, e.med)
    if icon then
        list:drawTextureScaled(icon, 16, y + 14, 48, 48, 1, 1, 1, 1)
    else
        list:drawRectBorder(16, y + 14, 48, 48, 0.6, C.borderDim.r, C.borderDim.g, C.borderDim.b)
    end
    list:drawText(fit(e.displayName, w - 100, UIFont.Medium), 76, y + 14, C.text.r, C.text.g, C.text.b, 1, UIFont.Medium)
    local kind = e.curative and L("Kind_cure", "Cures") or L("Kind_ease", "Eases symptoms")
    local kc = e.curative and C.green or C.blue
    list:drawText(kind, 76, y + 42, kc.r, kc.g, kc.b, 1, UIFont.Small)
    local tier = L("Tier_" .. tostring(e.tier), "Tier " .. tostring(e.tier))
    list:drawText(tier, w - tw(tier) - 18, y + 42, C.textDim.r, C.textDim.g, C.textDim.b, 1, UIFont.Small)
    return y + list.itemheight
end

-- ------------------------------------------------------------- details
local function tooltipText(fullType, med)
    local sm = getScriptManager and getScriptManager()
    if sm then
        local ok, it = pcall(function() return sm:FindItem(fullType) end)
        if ok and it and it.getTooltip then
            local okT, key = pcall(function() return it:getTooltip() end)
            if okT and key and key ~= "" then
                local t = getText(key)
                if t and t ~= key then return (t:gsub("<LINE>", "\n"):gsub("<BR>", "\n")) end
            end
        end
    end
    return med and med.usageMessage or nil
end

local FLAGS = { "requiresIVKit", "requiresSyringe", "isTopical", "requiresActiveWound", "preventionOnly",
    "overdoseRisk", "countsForPainkillerAddiction", "sleepAid", "isEmergency" }

function M:drawDiseaseDetails(entry, x, y, w, h)
    local med = entry.med or {}
    local iconSize = 86
    local icon = self:itemIcon(entry.id, med)
    if icon then
        self:drawTextureScaled(icon, x, y, iconSize, iconSize, 1, 1, 1, 1)
    else
        self:drawRectBorder(x, y, iconSize, iconSize, 1, C.border.r, C.border.g, C.border.b)
    end
    local tx = x + iconSize + 18
    local tWidth = x + w - tx
    local ty = y + 4
    self:drawText(fit(entry.displayName, tWidth, UIFont.Large), tx, ty, C.text.r, C.text.g, C.text.b, 1, UIFont.Large)
    ty = ty + fh(UIFont.Large) + 2
    local kind = entry.curative and L("KindLong_cure", "CURES - treats the illness itself") or L("KindLong_ease", "EASES SYMPTOMS - supportive only")
    local kc = entry.curative and C.green or C.blue
    self:drawText(fit(kind, tWidth, UIFont.Medium), tx, ty, kc.r, kc.g, kc.b, 1, UIFont.Medium)
    ty = ty + fh(UIFont.Medium) + 2
    self:drawText(fit(L("Tier_" .. tostring(entry.tier), "Tier " .. tostring(entry.tier)), tWidth, UIFont.Medium), tx, ty, C.textDim.r, C.textDim.g, C.textDim.b, 1, UIFont.Medium)
    ty = ty + fh(UIFont.Medium)
    y = math.max(y + iconSize, ty) + 18
    self:drawRect(x, y, w, 1, 0.76, C.border.r, C.border.g, C.border.b)
    y = y + 16

    local desc = tooltipText(entry.id, med)
    if desc and desc ~= "" then y = self:drawInfoSection(L("Description", "Description"), desc, x, y, w) end

    -- what it treats
    local names = {}
    for _, t in ipairs(entry.treats or {}) do names[#names + 1] = diseaseName(t) end
    if #names > 0 then
        local head = entry.curative and L("Treats_cure", "Cures (with a full course)") or L("Treats_ease", "Used for (eases, does not cure)")
        local body = table.concat(names, ", ")
        local cure = tonumber(med.cureTimeHours)
        if entry.curative and cure then body = body .. "\n" .. L("CureTime", "Cure time: %1", hoursText(cure)) end
        if med.treatmentTimeText then body = body .. "\n" .. L("Course", "Course: %1", tostring(med.treatmentTimeText)) end
        y = self:drawInfoSection(head, body, x, y, w)
    end

    -- symptoms it eases
    local relief = {}
    local keys = {}
    for k, v in pairs(type(med.symptomReduction) == "table" and med.symptomReduction or {}) do
        if type(v) == "number" and v > 0 and v <= 1 then keys[#keys + 1] = k end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local key = "UI_HomeMedic_Med_Relief_" .. k
        local label = HM_Text(key, "")
        if label == "" or label == key then
            label = (EHR and EHR.Disease and EHR.Disease.Diseases and EHR.Disease.Diseases[k]) and diseaseName(k) or k
        end
        relief[#relief + 1] = label .. " -" .. pct(med.symptomReduction[k])
    end
    if #relief > 0 then y = self:drawInfoSection(L("Relief", "Eases"), table.concat(relief, ", "), x, y, w) end

    -- dosing
    local sched = EHR and EHR.Medication and EHR.Medication.DosingSchedules and EHR.Medication.DosingSchedules[entry.id]
    local lines = {}
    if sched then
        if sched.dosesRequired and sched.dosesRequired > 1 then
            lines[#lines + 1] = L("Doses", "%1 doses, one every %2", sched.dosesRequired, hoursText(sched.doseInterval or 6))
        else
            lines[#lines + 1] = L("OneDose", "One dose; again after %1", hoursText(sched.doseInterval or 6))
        end
    end
    local active = med.effectDurationHours or (sched and sched.activeHours)
    if active then lines[#lines + 1] = L("Lasts", "Works for %1", hoursText(active)) end
    if med.adminType then lines[#lines + 1] = L("Admin", "Given as: %1", L("Admin_" .. tostring(med.adminType), tostring(med.adminType))) end
    for _, f in ipairs(FLAGS) do
        if med[f] then lines[#lines + 1] = L("Flag_" .. f, f) end
    end
    if #lines > 0 then y = self:drawInfoSection(L("Use", "How to use"), table.concat(lines, "\n"), x, y, w) end

    -- side effects
    local sides = {}
    local SE = EHR and EHR.Medication and EHR.Medication.SideEffects or {}
    for _, id in ipairs(type(med.sideEffects) == "table" and med.sideEffects or {}) do
        local def = SE[id]
        sides[#sides + 1] = L("Side_" .. tostring(id), def and def.displayName or tostring(id))
    end
    if #sides > 0 then y = self:drawInfoSection(L("SideEffects", "Side effects"), table.concat(sides, ", "), x, y, w) end
    return y
end
