-- Linux Resolution Fix Reforged — fork of LinuxResolutionFix by maqisha (MIT License).
local addonName, ns = ...
local L = ns.L

local LOGIN_CHECK_DELAY = 1.5
local WINDOW_TRANSITION_DELAY = 1
local PREFIX = "|cff33ff99Linux Resolution Fix Reforged|r: "

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- C_Timer is missing on some older clients: fall back to an OnUpdate timer.
local function After(delay, func)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, func)
        return
    end
    local timer = CreateFrame("Frame")
    local elapsed = 0
    timer:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            func()
        end
    end)
end

local function Round(value)
    return math.floor(value + 0.5)
end

---------------------------------------------------------------------------
-- Backends: each one knows how to read the target size and apply it.
-- The first one whose functions exist on this client is used.
---------------------------------------------------------------------------

-- Modern clients (Retail, and Classic clients built on a recent engine).
local modernBackend = {
    IsAvailable = function()
        return C_VideoOptions ~= nil
            and C_VideoOptions.GetDefaultGameWindowSize ~= nil
            and C_VideoOptions.SetGameWindowSize ~= nil
    end,
    GetTarget = function()
        local monitor = tonumber(GetCVar("gxMonitor")) or 0
        local size = C_VideoOptions.GetDefaultGameWindowSize(monitor)
        if not size then return nil end
        return Round(size.x), Round(size.y)
    end,
    Apply = function(width, height)
        C_VideoOptions.SetGameWindowSize(width, height)
        if UpdateWindow then
            UpdateWindow()
        elseif RestartGx then
            RestartGx()
        end
    end,
}

-- Older clients: resolution list + gxWindowedResolution CVar.
-- Best effort: the target is the largest resolution the client reports.
local legacyBackend = {
    IsAvailable = function()
        if not GetScreenResolutions or not SetCVar then return false end
        local ok, value = pcall(GetCVar, "gxWindowedResolution")
        return ok and value ~= nil
    end,
    GetTarget = function()
        local bestWidth, bestHeight = nil, nil
        for _, text in ipairs({ GetScreenResolutions() }) do
            local w, h = string.match(text, "(%d+)%s*x%s*(%d+)")
            w, h = tonumber(w), tonumber(h)
            if w and h and (not bestWidth or w * h > bestWidth * bestHeight) then
                bestWidth, bestHeight = w, h
            end
        end
        return bestWidth, bestHeight
    end,
    Apply = function(width, height)
        SetCVar("gxWindowedResolution", width .. "x" .. height)
        if UpdateWindow then
            UpdateWindow()
        elseif RestartGx then
            RestartGx()
        end
    end,
}

local backend
if GetPhysicalScreenSize then
    if modernBackend.IsAvailable() then
        backend = modernBackend
    elseif legacyBackend.IsAvailable() then
        backend = legacyBackend
    end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local button = CreateFrame("Button", addonName .. "Button", UIParent, "UIPanelButtonTemplate")
button:SetSize(200, 32)
button:SetPoint("TOP", UIParent, "TOP", 0, -120)
button:SetFrameStrata("DIALOG")
button:SetText(L.FIX_BUTTON)
button:Hide()

local resolutionText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resolutionText:SetPoint("TOP", button, "BOTTOM", 0, -4)
resolutionText:SetJustifyH("CENTER")

local function GetCurrent()
    local width, height = GetPhysicalScreenSize()
    return Round(width), Round(height)
end

local applying = false

-- Returns true when the resolution is correct.
local function CheckResolution(targetWidth, targetHeight)
    -- Ignore resize events from the temporary windowed stage.
    if applying then return false end
    if not backend then return true end

    local width, height = GetCurrent()
    if not targetWidth then targetWidth, targetHeight = backend.GetTarget() end
    if not targetWidth then
        button:Hide()
        return true
    end

    local isCorrect = width == targetWidth and height == targetHeight
    if isCorrect then
        button:Hide()
    else
        button:Show()
    end

    resolutionText:SetText(L.DETECTED:format(width, height) .. "\n" ..
        L.TARGET:format(targetWidth, targetHeight))
    return isCorrect, width, height
end

local function ApplyResolution()
    if applying or not backend then return end
    -- Capture the native size before temporarily resizing the window.
    local width, height = backend.GetTarget()
    if not width then return end

    -- Some older clients do not expose this CVar; keep the resize-only fallback.
    local hasMaximize, maximize = pcall(GetCVar, "gxMaximize")
    local updateWindow = UpdateWindow or RestartGx
    local resetFullscreen = hasMaximize and maximize == "1" and SetCVar and updateWindow
    applying = true
    button:Disable()
    button:SetText(L.APPLYING)

    local function Finish()
        applying = false
        button:Enable()
        button:SetText(L.FIX_BUTTON)
        -- Compare with the captured target, even if the API now reports a different default.
        local ok, correct, actualWidth, actualHeight = pcall(CheckResolution, width, height)
        if not ok then
            Print(L.APPLY_ERROR:format(tostring(correct)))
        elseif correct and actualWidth then
            Print(L.OK:format(actualWidth, actualHeight))
        elseif actualWidth then
            Print(L.FAILED:format(actualWidth, actualHeight, width, height))
        end
    end

    local function RestoreFullscreen()
        if resetFullscreen then SetCVar("gxMaximize", "1") end
        backend.Apply(width, height)
    end

    local function RestoreAndCheck()
        local ok, err = pcall(RestoreFullscreen)
        if not ok then
            Print(L.APPLY_ERROR:format(tostring(err)))
            -- Retry mode and size independently: a failed mode change must not
            -- prevent restoring the original target size. Recovery is best effort.
            if resetFullscreen then
                pcall(SetCVar, "gxMaximize", "1")
                local restoredSize = pcall(backend.Apply, width, height)
                if not restoredSize then pcall(updateWindow) end
            end
        end
        After(WINDOW_TRANSITION_DELAY, Finish)
    end

    if resetFullscreen then
        -- Reproduce the working manual windowed -> fullscreen transition.
        -- Give the window manager a distinct windowed size before restoring fullscreen.
        local ok, err = pcall(function()
            SetCVar("gxMaximize", "0")
            backend.Apply(Round(width * 0.8), Round(height * 0.8))
        end)
        if not ok then Print(L.APPLY_ERROR:format(tostring(err))) end
        After(WINDOW_TRANSITION_DELAY, RestoreAndCheck)
    else
        RestoreAndCheck()
    end
end

button:SetScript("OnClick", ApplyResolution)

---------------------------------------------------------------------------
-- Events and slash command
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if not backend then
            Print(L.NO_API)
            return
        end
        self:RegisterEvent("DISPLAY_SIZE_CHANGED")
        After(LOGIN_CHECK_DELAY, CheckResolution)
    else
        After(0.5, CheckResolution)
    end
end)

SLASH_LINUXRESOLUTIONFIXREFORGED1 = "/lrf"
SlashCmdList.LINUXRESOLUTIONFIXREFORGED = function()
    if not backend then
        Print(L.NO_API)
        return
    end
    local isCorrect, width, height = CheckResolution()
    if isCorrect and width then
        Print(L.OK:format(width, height))
    end
end
