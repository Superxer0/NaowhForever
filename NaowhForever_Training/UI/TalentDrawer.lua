-- TalentDrawer.lua: the side panel beside a talent window (build picker, next talents, glow switch) and its button.
local ns = _G.NaowhForever

local ceil, max, min = math.ceil, math.max, math.min
local concat = table.concat

local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Next = Training.Next

local PAD = 4
local ROW_H, BIG_H, PICK_H = 28, 48, 40
local GROUP_SIZE, NOTE_SIZE, NAME_SIZE, SMALL_SIZE = 11, 12, 13, 11
local GROUP_DROP, NOTE_PAD, LABEL_GAP = 7, 7, 8
local BIG_ICON, SMALL_ICON, ICON_GAP, ICON_CROP = 30, 16, 10, 0.08
local BIG_TEXT_DROP = 1
local RULE_ALPHA = 0.6
local CONTROL_LEVEL = 2
local BUTTON_GAP, SEARCH_LEVEL = 8, 2
local NO_SEARCH_X, NO_SEARCH_Y, NO_SEARCH_LEVEL = -30, -4, 20
local MAX_FRAME_LEVEL = 9000
local GLOW_KEY = "nextTalentGlow"
local PROGRESS_NOTES = { "progress", "extra", "follow" }
local TEXT_BUILD = ns.Upper(ns.L("Build"))
local TEXT_NEXT = ns.Upper(ns.L("Next Talent"))
local TEXT_THEN = ns.Upper(ns.L("Then"))
local TEXT_PROGRESS = ns.Upper(ns.L("Progress"))
local TEXT_OPTIONS = ns.Upper(ns.L("Options"))
local TEXT_PICK = ns.L("Build to Light")
local TEXT_PICK_TIP = ns.L("Lights this build's next talent without following it, so no points are spent for you.")
local TEXT_FOLLOWED = ns.L("%s (followed)")
local TEXT_NO_PICK = ns.L("No build picked")
local TEXT_GLOW = ns.L("Glow on the Next Talent")
local TEXT_GLOW_TIP = ns.L("A glow around the next talent's button that pulses while you have a point to spend.")
local TEXT_SHOW_HIDE = ns.L("Show or hide this panel.")

local shown, keyPieces = {}, {}

local function LevelAbove(frame, steps)
    return min(frame:GetFrameLevel() + steps, MAX_FRAME_LEVEL)
end

local function NewBody(scroll)
    return CreateFrame("Frame", nil, scroll)
end

local function FullOpacity()
    return 1
end

local function GlowOn()
    return S.Get(GLOW_KEY)
end

local function SetGlow(on)
    S.Set(GLOW_KEY, on)
end

local function SpellTip(strip)
    if not strip.spellID then return end
    GameTooltip:SetOwner(strip, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(strip.spellID)
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function NewStrip(view, height)
    local strip = CreateFrame("Frame", nil, view.body)
    strip:SetHeight(height)
    strip.height = height
    strip:Hide()
    local rule = ns.Solid(strip, "ARTWORK", T.line, RULE_ALPHA)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
    view.strips[#view.strips + 1] = strip
    return strip
end

local function NewGroup(view, title)
    local strip = NewStrip(view, ROW_H)
    local text = ns.Font(strip, GROUP_SIZE, nil, T.accentSoft)
    text:SetPoint("BOTTOMLEFT", PAD, GROUP_DROP)
    text:SetText(title)
    return strip
end

local function NewNote(view)
    local strip = NewStrip(view, ROW_H)
    strip.text = ns.Font(strip, NOTE_SIZE, nil, T.fg)
    strip.text:SetWidth(view.body:GetWidth() - PAD * 2)
    strip.text:SetJustifyH("LEFT")
    strip.text:SetWordWrap(true)
    strip.text:SetPoint("TOPLEFT", PAD, -NOTE_PAD)
    return strip
end

local function SetNote(strip, text)
    strip.text:SetText(text)
    strip.height = max(ROW_H, ceil(strip.text:GetStringHeight()) + NOTE_PAD * 2)
end

local function NewTalentRow(view, big)
    local strip = NewStrip(view, big and BIG_H or ROW_H)
    local iconSize = big and BIG_ICON or SMALL_ICON
    strip:EnableMouse(true)
    strip:SetScript("OnEnter", SpellTip)
    strip:SetScript("OnLeave", HideTip)
    strip.icon = strip:CreateTexture(nil, "ARTWORK")
    strip.icon:SetSize(iconSize, iconSize)
    strip.icon:SetPoint("LEFT", PAD, 0)
    strip.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    strip.name = ns.Font(strip, NAME_SIZE, nil, T.fg)
    strip.name:SetJustifyH("LEFT")
    strip.name:SetWordWrap(false)
    if big then
        local top, left = (BIG_H - BIG_ICON) / 2 + BIG_TEXT_DROP, PAD + BIG_ICON + ICON_GAP
        strip.name:SetPoint("TOPLEFT", left, -top)
        strip.name:SetPoint("TOPRIGHT", -PAD, -top)
        strip.sub = ns.Font(strip, SMALL_SIZE, nil, T.muted)
        strip.sub:SetJustifyH("LEFT")
        strip.sub:SetWordWrap(false)
        strip.sub:SetPoint("BOTTOMLEFT", left, top)
        strip.sub:SetPoint("BOTTOMRIGHT", -PAD, top)
    else
        strip.when = ns.Font(strip, SMALL_SIZE, nil, T.muted)
        strip.when:SetJustifyH("RIGHT")
        strip.when:SetPoint("RIGHT", -PAD, 0)
        strip.name:SetPoint("LEFT", strip.icon, "RIGHT", LABEL_GAP, 0)
        strip.name:SetPoint("RIGHT", strip.when, "LEFT", -LABEL_GAP, 0)
    end
    return strip
end

local function FillTalentRow(strip, row)
    strip.spellID = row.spellID
    strip.icon:SetTexture(row.icon)
    strip.name:SetText(row.name)
    if strip.sub then
        strip.sub:SetText(row.sub)
    else
        strip.when:SetText(row.when)
    end
end

local function NewPicker(view)
    local strip = NewStrip(view, PICK_H)
    view.values, view.order = {}, {}
    local function Picked()
        return view.pickKey
    end
    local dropdown = UI.BuildDropdownControl(strip, nil, LevelAbove(strip, CONTROL_LEVEL), view.values, view.order,
        Picked, Next.SetPick)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("LEFT", PAD, 0)
    dropdown:SetPoint("RIGHT", -PAD, 0)
    ns.Tooltip(dropdown, TEXT_PICK, TEXT_PICK_TIP)
    strip.dropdown = dropdown
    return strip
end

local function RefreshPicker(view, model)
    local values, order = view.values, view.order
    wipe(values)
    wipe(order)
    for _, build in ipairs(model.builds) do
        local key = Training.BuildKey(model.classID, build)
        values[key] = Next.BuildLabel(build)
        order[#order + 1] = key
    end
    local followed = model.followed
    values[Next.FOLLOWED] = followed and TEXT_FOLLOWED:format(Next.BuildLabel(followed)) or TEXT_NO_PICK
    order[#order + 1] = Next.FOLLOWED
    view.pickKey = model.pickKey
    view.parts.picker.dropdown._refreshLabel()
end

local function NewGlowRow(view)
    local strip = NewStrip(view, ROW_H)
    strip:EnableMouse(true)
    local toggle = UI.BuildToggleControl(strip, LevelAbove(strip, CONTROL_LEVEL), GlowOn, SetGlow)
    toggle:SetPoint("RIGHT", -PAD, 0)
    local label = ns.Font(strip, NAME_SIZE, nil, T.fg)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetPoint("LEFT", PAD, 0)
    label:SetPoint("RIGHT", toggle, "LEFT", -LABEL_GAP, 0)
    label:SetText(TEXT_GLOW)
    ns.Tooltip(strip, TEXT_GLOW, TEXT_GLOW_TIP)
    strip.toggle = toggle
    return strip
end

local function BuildPanel(view)
    local panel = Parts.SidePanel({}, NewBody, FullOpacity)
    panel.title:SetText(view.title)
    panel.close._onClick = function() S.Set(view.openKey, false) end
    view.panel, view.body, view.strips = panel, panel.view, {}
    local parts = {}
    view.parts = parts
    parts.buildGroup = NewGroup(view, TEXT_BUILD)
    parts.picker = NewPicker(view)
    parts.nextGroup = NewGroup(view, TEXT_NEXT)
    parts.notice = NewNote(view)
    parts.big = NewTalentRow(view, true)
    parts.thenGroup = NewGroup(view, TEXT_THEN)
    parts.small = {}
    for i = 1, Next.UPCOMING - 1 do parts.small[i] = NewTalentRow(view, false) end
    parts.progressGroup = NewGroup(view, TEXT_PROGRESS)
    parts.progress = NewNote(view)
    parts.extra = NewNote(view)
    parts.follow = NewNote(view)
    parts.optionsGroup = NewGroup(view, TEXT_OPTIONS)
    parts.glowRow = NewGlowRow(view)
end

local function Add(strip)
    shown[#shown + 1] = strip
end

local function AddNote(strip, text)
    if not text then return end
    SetNote(strip, text)
    Add(strip)
end

local function Stack(view)
    for _, strip in ipairs(view.strips) do strip:Hide() end
    local offset = 0
    for _, strip in ipairs(shown) do
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", view.body, "TOPLEFT", 0, -offset)
        strip:SetPoint("TOPRIGHT", view.body, "TOPRIGHT", 0, -offset)
        strip:SetHeight(strip.height)
        strip:Show()
        offset = offset + strip.height
    end
    view.body:SetHeight(max(offset, 1))
end

local function AddTalents(parts, model)
    Add(parts.nextGroup)
    if model.notice then
        AddNote(parts.notice, model.notice)
    elseif model.count > 0 then
        FillTalentRow(parts.big, model.rows[1])
        Add(parts.big)
    end
    local rest = model.count - 1
    if rest < 1 then return end
    Add(parts.thenGroup)
    for place = 1, rest do
        local strip = parts.small[place]
        FillTalentRow(strip, model.rows[place + 1])
        Add(strip)
    end
end

local function ToggleOpen(button)
    local key = button.view.openKey
    S.Set(key, not S.Get(key))
end

local function NewButton(view, parent)
    local button = Parts.BarButton(parent, Style.LOGO_SMALL, view.title, TEXT_SHOW_HIDE, ToggleOpen)
    button.view = view
    button:HookScript("OnLeave", function() Next.PaintButton(view) end)
    view.button = button
end

local function AddPiece(piece)
    keyPieces[#keyPieces + 1] = piece or ""
end

function Next.ModelKey(model)
    wipe(keyPieces)
    AddPiece(tostring(model.pickKey))
    AddPiece(model.builds and #model.builds)
    AddPiece(model.notice)
    AddPiece(model.progress)
    AddPiece(model.extra)
    AddPiece(model.follow)
    AddPiece(GlowOn() and "glow" or "no glow")
    for place = 1, model.count do
        local row = model.rows[place]
        AddPiece(tostring(row.icon) .. row.name .. (row.sub or "") .. (row.when or ""))
    end
    return concat(keyPieces, ";")
end

function Next.PaintDrawer(view, model)
    if not view.panel then BuildPanel(view) end
    local parts = view.parts
    wipe(shown)
    RefreshPicker(view, model)
    Add(parts.buildGroup)
    Add(parts.picker)
    AddTalents(parts, model)
    if model.progress or model.extra or model.follow then
        Add(parts.progressGroup)
        for _, key in ipairs(PROGRESS_NOTES) do AddNote(parts[key], model[key]) end
    end
    Add(parts.optionsGroup)
    parts.glowRow.toggle._refreshValue()
    Add(parts.glowRow)
    Stack(view)
end

function Next.ShowDrawer(view, window)
    if view.panel:IsShown() then return end
    Parts.ShowBeside(view.panel, window.outer)
end

function Next.HideDrawer(view, alsoButton)
    if view.panel then view.panel:Hide() end
    if alsoButton and view.button then view.button:Hide() end
end

function Next.PaintButton(view)
    local button = view.button
    if not button then return end
    local color = S.Get(view.openKey) and T.accent or T.muted
    button.icon:SetVertexColor(color.r, color.g, color.b)
end

function Next.Dock(view, window)
    if not view.button then NewButton(view, window.content) end
    local button = view.button
    button:SetParent(window.content)
    button:ClearAllPoints()
    local search = window.search
    if search then
        button:SetPoint("RIGHT", search, "LEFT", -BUTTON_GAP, 0)
        button:SetFrameLevel(LevelAbove(search, SEARCH_LEVEL))
    else
        button:SetPoint("TOPRIGHT", window.outer, "TOPRIGHT", NO_SEARCH_X, NO_SEARCH_Y)
        button:SetFrameLevel(LevelAbove(window.outer, NO_SEARCH_LEVEL))
    end
    Next.PaintButton(view)
    button:Show()
end
