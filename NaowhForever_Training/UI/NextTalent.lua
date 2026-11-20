-- NextTalent.lua: turns the next-talent glow and side panel on and off, and redraws them while a talent window is open.
local ns = _G.NaowhForever

local Training = ns.Training
local S = Training.Settings
local Next = Training.Next

local WINDOW_ADDONS = { "Blizzard_PlayerSpells", "EllesmereUIForeverEssentials" }
local EVENTS = {
    "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_NODE_ENTRY_UPDATED",
    "TRAIT_TREE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE",
}
local SPELL_EVENT = "SPELL_DATA_LOAD_RESULT"
local MAX_LOOKS = 10
local GLOW_KEY = "nextTalentGlow"
local DRAWER_KEY = "nextTalentDrawer"
local TEXT_TITLE = ns.L("Next Talent")

local view = { title = TEXT_TITLE, openKey = DRAWER_KEY }

local events
local installed, queued = false, false
local listening, listeningForSpells, ellesmereHooked = false, false, false
local looks = 0
local hooked = {}
local Refresh

local function On()
    return Training.On() and S.Get("nextTalent") and not ns.GamepadStandDown()
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, Refresh)
end

local function Schedule()
    if not (installed and On()) then return end
    looks = 0
    Queue()
end

local function Listen(windowOpen, nameLoading)
    if windowOpen ~= listening then
        listening = windowOpen
        if windowOpen then
            for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        else
            events:UnregisterAllEvents()
            listeningForSpells = false
        end
    end
    local wantSpells = windowOpen and nameLoading
    if wantSpells == listeningForSpells then return end
    listeningForSpells = wantSpells
    if wantSpells then
        events:RegisterEvent(SPELL_EVENT)
    else
        events:UnregisterEvent(SPELL_EVENT)
    end
end

local function Hook(page)
    if hooked[page] then return end
    hooked[page] = true
    page:HookScript("OnShow", Schedule)
    page:HookScript("OnHide", Schedule)
end

local function OnEllesmereEscape(frame)
    if frame and frame == EUI_ClassicTalents then Hook(frame) end
end

local function HookEllesmere()
    if ellesmereHooked or not (EllesmereUI and EllesmereUI.RegisterEscapeClose) then return end
    ellesmereHooked = true
    hooksecurefunc(EllesmereUI, "RegisterEscapeClose", OnEllesmereEscape)
end

local function OnWindowAddOnLoaded()
    Next.EachTalentPage(Hook)
    HookEllesmere()
    Schedule()
end

local function ClearView()
    Next.HideDrawer(view, false)
    Next.PlaceMark(view.mark, nil)
    view.open = false
end

local function UpdateDrawer(window, model)
    Next.PaintButton(view)
    if not S.Get(DRAWER_KEY) then return Next.HideDrawer(view, false) end
    local key = Next.ModelKey(model)
    if key ~= view.lastKey then
        view.lastKey = key
        Next.PaintDrawer(view, model)
    end
    Next.ShowDrawer(view, window)
end

local function UpdateMark(window, model)
    local nextTalent = model.count > 0 and model.rows[1]
    if not (nextTalent and S.Get(GLOW_KEY)) then return Next.PlaceMark(view.mark, nil) end
    local button = Next.ButtonFor(view.mark, window, nextTalent.node)
    Next.PlaceMark(view.mark, button, nextTalent.ready)
    view.missing = button == nil
end

local function UpdateView()
    view.missing, view.loading = false, false
    local window = Next.ClassWindow()
    if not window then return ClearView() end
    view.open = true
    Hook(window.content)
    if view.docked ~= window.content then
        view.docked, view.lastKey = window.content, nil
        Next.HideDrawer(view, false)
        Next.Dock(view, window)
    end
    local model = Next.ClassModel()
    view.loading = model.retry
    UpdateDrawer(window, model)
    UpdateMark(window, model)
end

function Refresh()
    queued = false
    if not (installed and On()) then return end
    UpdateView()
    Listen(view.open, view.loading)
    if view.missing and looks < MAX_LOOKS then
        looks = looks + 1
        Queue()
    end
end

local function Quiet()
    if events then events:UnregisterAllEvents() end
    listening, listeningForSpells = false, false
    Next.HideDrawer(view, true)
    if view.mark then Next.PlaceMark(view.mark, nil) end
    view.open, view.docked, view.lastKey = false, nil, nil
end

local function Install()
    installed = true
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", Schedule)
    view.mark = Next.NewMark()
    for _, name in ipairs(WINDOW_ADDONS) do EventUtil.ContinueOnAddOnLoaded(name, OnWindowAddOnLoaded) end
end

local function Apply()
    if not On() then return Quiet() end
    if not installed then Install() end
    Schedule()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "nextTalent" then return Apply() end
    if key == GLOW_KEY or key == DRAWER_KEY then Schedule() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Next.Redraw = Schedule
Training.OnChange(Schedule)
S.OnChange(OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
