local addonName, ns = ...
local DataTracker = ns.DataTracker

local MultiItemManager = {}
ns.MultiItemManager = MultiItemManager

local NUM_GROUP_LOOT_FRAMES = 4

local function GetGroupLootFrameForRollID(rollID)
    for i = 1, NUM_GROUP_LOOT_FRAMES do
        local glf = _G["GroupLootFrame" .. i]
        if glf and glf:IsShown() and glf.rollID == rollID then
            return glf
        end
    end
    return nil
end

local function GetAnyShownGroupLootFrame()
    for i = 1, NUM_GROUP_LOOT_FRAMES do
        local glf = _G["GroupLootFrame" .. i]
        if glf and glf:IsShown() then
            return glf
        end
    end
    return nil
end

function MultiItemManager:UpdateAnchoring()
    local tracker = ns.RollTrackerFrame and ns.RollTrackerFrame.frame
    if not tracker then return end

    local side = ns.db and ns.db.anchorSide or "RIGHT"

    if side == "FREE" and ns.db.freePosition then
        local pos = ns.db.freePosition
        tracker:ClearAllPoints()
        tracker:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 220, pos.y or 0)
        return
    end

    -- Find the GroupLootFrame matching the current rollID, or fallback to any shown GroupLootFrame / UIParent
    local session = DataTracker:GetCurrentRollSession()
    local targetGLF = (session and GetGroupLootFrameForRollID(session.rollID)) or GetAnyShownGroupLootFrame()

    tracker:ClearAllPoints()
    if targetGLF and targetGLF:IsShown() and targetGLF:GetNumPoints() > 0 then
        if side == "LEFT" then
            tracker:SetPoint("BOTTOMRIGHT", targetGLF, "BOTTOMLEFT", -12, 0)
        else
            tracker:SetPoint("BOTTOMLEFT", targetGLF, "BOTTOMRIGHT", 12, 0)
        end
    else
        -- DefaultGroupLootContainer / GroupLootFrame1 position when no real GroupLootFrame is currently visible (e.g. solo /cl test)
        if side == "LEFT" then
            tracker:SetPoint("CENTER", UIParent, "CENTER", -220, -40)
        else
            tracker:SetPoint("CENTER", UIParent, "CENTER", 220, -40)
        end
    end
end

function MultiItemManager:HookGroupLootFrames()
    for i = 1, NUM_GROUP_LOOT_FRAMES do
        local glf = _G["GroupLootFrame" .. i]
        if glf and not glf._clearLootHooked then
            glf._clearLootHooked = true

            glf:HookScript("OnShow", function(self)
                MultiItemManager:UpdateAnchoring()
            end)

            glf:HookScript("OnHide", function(self)
                MultiItemManager:UpdateAnchoring()
            end)

            glf:HookScript("OnEnter", function(self)
                if ns.db and ns.db.autoSwitchOnHover and self.rollID then
                    DataTracker:SetCurrentRollID(self.rollID, false)
                end
            end)
        end
    end
end

function MultiItemManager:Init()
    self:HookGroupLootFrames()
    self:UpdateAnchoring()
end
