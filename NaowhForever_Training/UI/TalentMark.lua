-- TalentMark.lua: the glow on the next talent, a border in its button's shape that pulses while a point is free.
local ns = _G.NaowhForever

local min = math.min

local T = ns.THEME
local Next = ns.Training.Next

local RING_ALPHA, SHINE_ALPHA, OUTER_ALPHA, HALO_ALPHA = 1, 0.8, 0.5, 0.7
local OUTER_SCALE, FALLBACK_SCALE, HALO_SCALE = 1.14, 1.3, 1.6
local WAIT_ALPHA = 0.75
local PULSE_LOW, PULSE_TIME = 0.45, 0.7
local EDGE_W, EDGE_OUT = 2, 3
local LEVEL_ABOVE, MAX_FRAME_LEVEL = 10, 9000

local function Tint(texture, alpha)
    local color = T.accentSoft
    texture:SetDesaturated(true)
    texture:SetVertexColor(color.r, color.g, color.b, alpha)
end

local function AtlasOK(atlas)
    return type(atlas) == "string" and atlas ~= "" and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function NewLayer(mark, drawLayer, additive)
    local texture = mark:CreateTexture(nil, drawLayer)
    if additive then texture:SetBlendMode("ADD") end
    texture:SetPoint("CENTER")
    return texture
end

local function NewEdge(mark, pointA, xA, yA, pointB, xB, yB)
    local color = T.accentSoft
    local edge = mark:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(color.r, color.g, color.b, 1)
    edge:SetPoint(pointA, xA, yA)
    edge:SetPoint(pointB, xB, yB)
    edge:Hide()
    mark.edges[#mark.edges + 1] = edge
    return edge
end

local function Edges(mark)
    mark.edges = {}
    NewEdge(mark, "TOPLEFT", -EDGE_OUT, EDGE_OUT, "TOPRIGHT", EDGE_OUT, EDGE_OUT):SetHeight(EDGE_W)
    NewEdge(mark, "BOTTOMLEFT", -EDGE_OUT, -EDGE_OUT, "BOTTOMRIGHT", EDGE_OUT, -EDGE_OUT):SetHeight(EDGE_W)
    NewEdge(mark, "TOPLEFT", -EDGE_OUT, EDGE_OUT, "BOTTOMLEFT", -EDGE_OUT, -EDGE_OUT):SetWidth(EDGE_W)
    NewEdge(mark, "TOPRIGHT", EDGE_OUT, EDGE_OUT, "BOTTOMRIGHT", EDGE_OUT, -EDGE_OUT):SetWidth(EDGE_W)
end

local function Pulse(mark)
    local pulse = mark:CreateAnimationGroup()
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_LOW)
    fade:SetDuration(PULSE_TIME)
    pulse:SetLooping("BOUNCE")
    return pulse
end

local function ShapeAtlas(button)
    local border = button.StateBorder
    local atlas = border and border:GetAtlas()
    if not AtlasOK(atlas) and type(button.artSet) == "table" then
        atlas = button.artSet.selectable or button.artSet.normal
    end
    if AtlasOK(atlas) then return atlas end
end

local function HaloAtlas(button)
    local atlas = type(button.artSet) == "table" and button.artSet.glow
    if not AtlasOK(atlas) and button.Glow then atlas = button.Glow:GetAtlas() end
    if AtlasOK(atlas) then return atlas end
end

local function ArtSize(button, art, scale)
    local width, height = 0, 0
    if art then width, height = art:GetSize() end
    if width and width > 0 then return width, height end
    return button:GetWidth() * scale, button:GetHeight() * scale
end

local function ShapeArt(mark, button)
    local atlas = ShapeAtlas(button)
    if atlas then
        if mark.atlas ~= atlas then
            mark.atlas = atlas
            mark.ring:SetAtlas(atlas)
            mark.shine:SetAtlas(atlas)
            mark.outer:SetAtlas(atlas)
            Tint(mark.ring, RING_ALPHA)
            Tint(mark.shine, SHINE_ALPHA)
            Tint(mark.outer, OUTER_ALPHA)
        end
        local width, height = ArtSize(button, button.StateBorder, FALLBACK_SCALE)
        mark.ring:SetSize(width, height)
        mark.shine:SetSize(width, height)
        mark.outer:SetSize(width * OUTER_SCALE, height * OUTER_SCALE)
    end
    local shaped = atlas ~= nil
    mark.ring:SetShown(shaped)
    mark.shine:SetShown(shaped)
    mark.outer:SetShown(shaped)
    for _, edge in ipairs(mark.edges) do edge:SetShown(not shaped) end
end

local function HaloArt(mark, button)
    local atlas = HaloAtlas(button)
    mark.hasHalo = atlas ~= nil
    if not atlas then return end
    if mark.haloAtlas ~= atlas then
        mark.haloAtlas = atlas
        mark.halo:SetAtlas(atlas)
        Tint(mark.halo, HALO_ALPHA)
    end
    mark.halo:SetSize(ArtSize(button, button.Glow, HALO_SCALE))
end

function Next.NewMark()
    local mark = CreateFrame("Frame")
    mark:Hide()
    mark.halo = NewLayer(mark, "BACKGROUND", true)
    mark.ring = NewLayer(mark, "ARTWORK", false)
    mark.shine = NewLayer(mark, "OVERLAY", true)
    mark.outer = NewLayer(mark, "OVERLAY", true)
    Edges(mark)
    mark.pulse = Pulse(mark)
    return mark
end

function Next.PlaceMark(mark, button, ready)
    if not button then
        mark.pulse:Stop()
        mark:Hide()
        return
    end
    if mark.button ~= button then
        mark:SetParent(button)
        mark:ClearAllPoints()
        mark:SetAllPoints(button)
        mark.button = button
    end
    mark:SetFrameLevel(min(button:GetFrameLevel() + LEVEL_ABOVE, MAX_FRAME_LEVEL))
    ShapeArt(mark, button)
    HaloArt(mark, button)
    mark.halo:SetShown(ready and mark.hasHalo)
    if ready then
        if not mark.pulse:IsPlaying() then
            mark:SetAlpha(1)
            mark.pulse:Play()
        end
    else
        mark.pulse:Stop()
        mark:SetAlpha(WAIT_ALPHA)
    end
    mark:Show()
end

function Next.ButtonFor(mark, window, node)
    local current = mark.button
    if current and current:IsVisible() and Next.NodeOf(current) == node then return current end
    return Next.FindButton(window, node)
end
