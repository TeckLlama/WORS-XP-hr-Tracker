local XPTracker = CreateFrame("Frame")
XPTracker:RegisterEvent("CHAT_MSG_SYSTEM")
XPTracker:RegisterEvent("CHAT_MSG_SAY")
XPTracker:RegisterEvent("CHAT_MSG_WHISPER")
XPTracker:RegisterEvent("CHAT_MSG_YELL")
XPTracker:RegisterEvent("CHAT_MSG_CHANNEL")
XPTracker:RegisterEvent("CHAT_MSG_PARTY")
XPTracker:RegisterEvent("CHAT_MSG_GUILD")
XPTracker:RegisterEvent("CHAT_MSG_RAID")
XPTracker:RegisterEvent("CHAT_MSG_LOOT")
XPTracker:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
XPTracker:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
XPTracker:RegisterEvent("PLAYER_ENTERING_WORLD")

local startTime = 0
local sessionSkillXP = {}
local maxSkills = 3
local lineSpacing = 10 -- Space between lines of text
local margin = 20 -- Margin between text and window edges
local updateInterval = 5 -- Time in seconds to update XP/hour
local lastUpdate = 0
local xpPerHourData = {}
local skillIcons = {}

-- Create UI panel
local panel = CreateFrame("Frame", "XPTrackerPanel", UIParent)
panel:SetSize(240, 100) -- Increased size for better display
panel:SetPoint("CENTER", 200, 200)
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
panel:SetBackdropColor(0, 0, 0, 1)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

-- Title for the panel
local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
panelTitle:SetPoint("TOP", 0, -20)
panelTitle:SetText("XP/Hour Tracker")

-- Create text for dynamic skill XP display
local skillXPText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
skillXPText:SetPoint("TOPLEFT", margin, -40) -- Reduced space between title and tracking text
skillXPText:SetText("") -- Initially empty

-- Dynamic table to track and display skill XP
local dynamicSkillXPTexts = {}

-- Update function
local function UpdateTrackingData()
    local currentTime = time()
    local elapsed = (currentTime - startTime) / 3600  -- time in hours

    -- Clear previous skill texts
    for _, text in pairs(dynamicSkillXPTexts) do
        text:Hide()
    end

    -- Create a sorted list of skills by most recent XP gain
    local sortedSkills = {}
    for skill, data in pairs(sessionSkillXP) do
        table.insert(sortedSkills, { skill = skill, data = data })
    end
    table.sort(sortedSkills, function(a, b)
        return a.data.lastXPTime > b.data.lastXPTime
    end)

    -- Update only the most recent skills
    local previousText = skillXPText
    local numberOfSkills = 0
    for i = 1, math.min(maxSkills, #sortedSkills) do
        local skill, data = sortedSkills[i].skill, sortedSkills[i].data
        if not dynamicSkillXPTexts[skill] then
            dynamicSkillXPTexts[skill] = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        end
        dynamicSkillXPTexts[skill]:SetPoint("TOPLEFT", previousText, "BOTTOMLEFT", 0, -lineSpacing)

        -- Format XP/hour as integer and handle zero values
        local xpPerHour = xpPerHourData[skill] or 0
        xpPerHour = xpPerHour > 0 and math.floor(xpPerHour + 0.5) or 0 -- Round to nearest integer
        local totalXP = data.totalXP
        local skillIcon = skillIcons[skill] or ""

        dynamicSkillXPTexts[skill]:SetText(format("|T%s:16|t    %s: %d XP/hr (%d)", skillIcon, skill, xpPerHour, totalXP))
        dynamicSkillXPTexts[skill]:Show()
        previousText = dynamicSkillXPTexts[skill]
        numberOfSkills = numberOfSkills + 1
    end

    -- Adjust panel height based on content
    local contentHeight = 40 + (numberOfSkills * lineSpacing) -- Adjust for title and margin
    local panelHeight = math.max(contentHeight, 150)  -- Ensure minimum height
    panel:SetHeight(panelHeight)
end

-- Periodic update function
local function PeriodicUpdate()
    local currentTime = time()
    if (currentTime - lastUpdate) >= updateInterval then
        -- Update XP/hour for each skill
        for skill, data in pairs(sessionSkillXP) do
            local elapsed = (currentTime - data.lastXPTime) / 3600  -- time in hours
            if elapsed > 0 then
                xpPerHourData[skill] = data.gainedXP / elapsed
            end
        end
        UpdateTrackingData()
        lastUpdate = currentTime
    end
end

-- Reset session data
local function ResetSession()
    startTime = time()
    sessionSkillXP = {}
    xpPerHourData = {} -- Clear XP/hr data
    skillIcons = {}
    skillXPText:SetText("") -- Remove placeholder text
    print("Session reset. Start time: ", startTime)
end

-- Event handler
XPTracker:SetScript("OnEvent", function(self, event, ...)
    local message = ...
    --print("Event: ", event, " Message: ", message)

    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize on login
        ResetSession()
        panel:Show()  -- Show the UI panel when entering the world
    else
        -- Track skill XP gains via chat messages
        if message and string.find(message, "experience increased by") then
            --print("Found 'experience increased by' in the message.")
            -- Extract skill name, icon, and XP amount
            local icon, skill, xpGained = string.match(message, "|T(.-)|t ([%a%s]+) experience increased by (%d+)")
            if skill and xpGained then
                -- Remove leading 't' if present
                skill = string.gsub(skill, "^t", "")
                -- Initialize skill data if not present
                if not sessionSkillXP[skill] then
                    sessionSkillXP[skill] = { gainedXP = 0, totalXP = 0, lastXPTime = time() }
                end
                sessionSkillXP[skill].gainedXP = sessionSkillXP[skill].gainedXP + tonumber(xpGained)
                sessionSkillXP[skill].totalXP = sessionSkillXP[skill].totalXP + tonumber(xpGained)
                sessionSkillXP[skill].lastXPTime = time() -- Update last XP time

                -- Store the icon
                skillIcons[skill] = icon

                -- Immediate update for XP display
                UpdateTrackingData()
            else
                --print("Failed to extract skill and XP.")
            end
        end
    end
end)

-- Update XP/hour periodically
XPTracker:SetScript("OnUpdate", function(self, elapsed)
    PeriodicUpdate()
end)

-- Slash command to toggle UI panel visibility
SLASH_XPTRACKER1 = "/xptracker"
SlashCmdList["XPTRACKER"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end
