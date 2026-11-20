-- TalentWindows.lua: finds the open talent window (Blizzard's or EllesmereUI's) and a talent's button.
local ns = _G.NaowhForever

local Next = ns.Training.Next

local SCAN_DEPTH = 6

local classWindow = {}

local function NodeOf(button)
    if button.GetNodeID then return button:GetNodeID() end
    return button.nodeID
end

local function Scan(frame, node, depth)
    if depth > SCAN_DEPTH then return nil end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() then
            if NodeOf(child) == node then return child end
            local found = Scan(child, node, depth + 1)
            if found then return found end
        end
    end
end

local function FindInButtonList(page, node)
    for first, second in page:EnumerateAllTalentButtons() do
        if type(first) == "table" and NodeOf(first) == node then return first end
        if type(second) == "table" and NodeOf(second) == node then return second end
    end
end

local function BlizzardFind(page, node)
    local button = page.GetTalentButtonByNodeID and page:GetTalentButtonByNodeID(node)
    if button then return button end
    button = page.EnumerateAllTalentButtons and FindInButtonList(page, node)
    if button then return button end
    return Scan(page, node, 0)
end

local function FillWindow(window, outer, content, search, scan)
    window.outer, window.content, window.search, window.scan = outer, content, search, scan
    return window
end

function Next.NodeOf(button)
    return NodeOf(button)
end

function Next.ClassWindow()
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents and talents:IsVisible() then
        return FillWindow(classWindow, PlayerSpellsFrame, talents, talents.SearchBox, false)
    end
    local ellesmere = EUI_ClassicTalents
    if ellesmere and ellesmere:IsVisible() then
        return FillWindow(classWindow, ellesmere, ellesmere, nil, true)
    end
end

function Next.FindButton(window, node)
    if window.scan then return Scan(window.content, node, 0) end
    return BlizzardFind(window.content, node)
end

function Next.EachTalentPage(fn)
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents then fn(talents) end
    if EUI_ClassicTalents then fn(EUI_ClassicTalents) end
end
