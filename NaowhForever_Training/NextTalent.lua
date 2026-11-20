-- NextTalent.lua: the next points to take from a build, and each character's own pick of build for the talent window.
local ns = _G.NaowhForever

local max, min = math.max, math.min
local concat = table.concat

local Training = ns.Training
local C = Training.C
local Style = Training.Style

local Next = {}
Training.Next = Next

local UPCOMING = 5
local EXTRA_SHOWN = 3
local QUESTION_ICON = 134400
local PICK_DATA = "trainingNextPick"
local FOLLOWED = "followed"
local MAX_LEVEL, FIRST_TALENT_LEVEL = C.MAX_LEVEL, C.FIRST_TALENT_LEVEL
local NODE_SPELL, NODE_RANKS, NODE_COLUMN = C.NODE_SPELL, C.NODE_RANKS, C.NODE_COLUMN
local TEXT_TALENT = ns.L("Talent %d")
local TEXT_RANK = ns.L("%s %d/%d")
local TEXT_SPEC_WHEN = ns.L("%s, %s")
local TEXT_NO_POINT = ns.L("no point left for it")
local TEXT_SPEND_NOW = ns.L("spend it now")
local TEXT_NOW = ns.L("now")
local TEXT_AT_LEVEL = ns.L("at level %d")
local TEXT_LVL = ns.L("lvl %d")
local TEXT_PICK_ONE = ns.L("Pick a build above: one of Naowh's, or one you saved in the planner's Builds tab.")
local TEXT_NOT_READY = ns.L("The talent tree is not ready yet.")
local TEXT_ALL_LEARNED = ns.L("Every point in this build is learned.")
local TEXT_PROGRESS = ns.L("%d of %d points in this build learned")
local TEXT_NOT_IN_BUILD = ns.L("Not in this build: %s")
local TEXT_MORE = "..."
local TEXT_FOLLOWING = ns.L("You follow %s, so its points are spent for you. Stop following it in the Builds tab "
    .. "to pick them yourself.")

local classModel = { rows = {}, count = 0 }
local ranks, timesNamed, extraNames = {}, {}, {}

Next.UPCOMING = UPCOMING
Next.FOLLOWED = FOLLOWED

local function MyClass()
    local _, _, classID = UnitClass("player")
    return classID
end

local function BuildByKey(builds, classID, key)
    for _, build in ipairs(builds) do
        if Training.BuildKey(classID, build) == key then return build end
    end
end

local function OwnPick(builds, classID)
    local pick = ns.Shared.CharacterData(PICK_DATA, false)
    if not (pick and pick.key and pick.class == classID) then return nil end
    return BuildByKey(builds, classID, pick.key)
end

local function FollowedBuild(classID)
    local build, buildClass = Training.Followed()
    if buildClass ~= classID then return nil end
    return build
end

local function ReadRanks(talents)
    wipe(ranks)
    local config = C_ClassTalents.GetActiveConfigID()
    if not config then return nil end
    local spent = 0
    for node in pairs(talents) do
        local info = C_Traits.GetNodeInfo(config, node)
        local rank = max(info.currentRank or 0, info.activeRank or 0)
        ranks[node] = rank
        spent = spent + rank
    end
    return spent
end

local function LevelFor(spent, place)
    return spent + place + FIRST_TALENT_LEVEL - 1
end

local function WhenText(level, ready, long)
    if level > MAX_LEVEL then return ns.Color(Style.WARN_RGB, TEXT_NO_POINT) end
    if ready then return ns.Color(Style.UP_RGB, long and TEXT_SPEND_NOW or TEXT_NOW) end
    local text = long and TEXT_AT_LEVEL or TEXT_LVL
    return ns.Color("muted", text:format(level))
end

local function SpellName(spellID)
    local name = C_Spell.GetSpellName(spellID)
    if name then return name, true end
    C_Spell.RequestLoadSpellData(spellID)
    return TEXT_TALENT:format(spellID), false
end

local function SpellIcon(spellID)
    return C_Spell.GetSpellTexture(spellID) or QUESTION_ICON
end

local function ClearModel(model)
    model.notice, model.progress, model.extra, model.follow = nil, nil, nil, nil
    model.pickKey, model.builds, model.retry = nil, nil, false
    model.count = 0
end

local function AddRow(model)
    local place = model.count + 1
    model.count = place
    local row = model.rows[place]
    if not row then
        row = {}
        model.rows[place] = row
    end
    return row, place
end

local function AddClassRow(model, tree, node, rank, spent)
    local row, place = AddRow(model)
    local talent = tree.talents[node]
    local spellID = talent[NODE_SPELL]
    local name, loaded = SpellName(spellID)
    local level = LevelFor(spent, place)
    local ready = level <= min(UnitLevel("player"), MAX_LEVEL)
    row.node, row.spellID, row.icon = node, spellID, SpellIcon(spellID)
    row.name = TEXT_RANK:format(name, rank, talent[NODE_RANKS])
    row.sub = TEXT_SPEC_WHEN:format(tree.specs[talent[NODE_COLUMN]], WhenText(level, ready, true))
    row.when = WhenText(level, ready, false)
    row.ready = ready
    if not loaded then model.retry = true end
end

local function ExtraText(tree)
    wipe(extraNames)
    for node, rank in pairs(ranks) do
        local over = rank - (timesNamed[node] or 0)
        if over > 0 then
            if #extraNames == EXTRA_SHOWN then
                extraNames[#extraNames + 1] = TEXT_MORE
                break
            end
            local name = SpellName(tree.talents[node][NODE_SPELL])
            extraNames[#extraNames + 1] = name .. " +" .. over
        end
    end
    if #extraNames == 0 then return nil end
    return TEXT_NOT_IN_BUILD:format(ns.Color(Style.WARN_RGB, concat(extraNames, ", ")))
end

local function ReadBuild(model, tree, build)
    local spent = ReadRanks(tree.talents)
    if not spent then return false end
    wipe(timesNamed)
    local done = 0
    for _, node in ipairs(build.points) do
        local wanted = (timesNamed[node] or 0) + 1
        timesNamed[node] = wanted
        if (ranks[node] or 0) >= wanted then
            done = done + 1
        elseif model.count < UPCOMING then
            AddClassRow(model, tree, node, wanted, spent)
        end
    end
    model.progress = TEXT_PROGRESS:format(done, #build.points)
    model.extra = ExtraText(tree)
    return true
end

function Next.BuildLabel(build)
    local name = build.name
    if build.spec and not name:find(build.spec, 1, true) then name = name .. " (" .. build.spec .. ")" end
    return name
end

function Next.SetPick(key)
    local pick = ns.Shared.CharacterData(PICK_DATA, true)
    if not pick then return end
    if key == FOLLOWED then
        pick.class, pick.key = nil, nil
    else
        pick.class, pick.key = MyClass(), key
    end
    Next.Redraw()
end

function Next.ClassModel()
    local model = classModel
    ClearModel(model)
    local classID = MyClass()
    local builds = Training.Builds(classID)
    local own = OwnPick(builds, classID)
    local followed = FollowedBuild(classID)
    local tree = ns.TrainingBuilds[classID]
    model.classID, model.builds = classID, builds
    model.pickKey = own and Training.BuildKey(classID, own) or FOLLOWED
    model.followed = followed
    if followed then model.follow = ns.Color(Style.WARN_RGB, TEXT_FOLLOWING:format(followed.name)) end
    local build = own or followed
    if not build then
        model.notice = TEXT_PICK_ONE
    elseif not (tree and ReadBuild(model, tree, build)) then
        model.notice = TEXT_NOT_READY
    elseif model.count == 0 then
        model.notice = ns.Color(Style.UP_RGB, TEXT_ALL_LEARNED)
    end
    return model
end
