-- Run from the repository root: lua5.1 tests/run.lua
-- Mock the WoW API; these tests do not exercise Wine or a real window manager.
local root = arg[1] or "."
local passed, failed = 0, 0

local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local function test(name, func)
    local ok, err = pcall(func)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function loadAddonFile(name, env, ns)
    local chunk = assert(loadfile(root .. "/" .. name))
    setfenv(chunk, env)("LinuxResolutionFixReforged", ns)
end

local function localeStrings(locale)
    local ns = {}
    local env = setmetatable({ GetLocale = function() return locale end }, { __index = _G })
    loadAddonFile("Locales.lua", env, ns)
    return ns.L
end

local function newGame(options)
    options = options or {}
    local game = {
        width = 2560, height = 1408, now = 0, frames = {}, timers = {}, messages = {},
        cvars = { gxMonitor = "0", gxMaximize = options.windowed and "0" or "1", gxWindowedResolution = "2560x1440" },
        sizes = 0, modeChanges = 0, restores = 0,
    }
    local env = setmetatable({ UIParent = {}, SlashCmdList = {} }, { __index = _G })

    local function noop() end
    function env.CreateFrame(kind)
        local frame = { scripts = {}, events = {}, enabled = true, shown = true }
        frame.SetSize, frame.SetPoint, frame.SetFrameStrata, frame.SetJustifyH = noop, noop, noop, noop
        function frame:SetText(text) self.text = text end
        function frame:Hide() self.shown = false end
        function frame:Show() self.shown = true end
        function frame:Disable() self.enabled = false end
        function frame:Enable() self.enabled = true end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:CreateFontString() return env.CreateFrame("FontString") end
        table.insert(game.frames, frame)
        if kind == "Button" then game.button = frame end
        return frame
    end

    function game:fire(event)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] then frame.scripts.OnEvent(frame, event) end
        end
    end

    function game:drain()
        -- A finite clock also detects callbacks that never settle.
        for _ = 1, 1000 do
            self.now = self.now + 0.1
            local timers = self.timers
            self.timers = {}
            for _, timer in ipairs(timers) do
                if timer.at <= self.now then timer.callback()
                else table.insert(self.timers, timer) end
            end
            local count = #self.frames
            for i = 1, count do
                local frame = self.frames[i]
                if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.1) end
            end
            local pending = #self.timers > 0
            for _, frame in ipairs(self.frames) do pending = pending or frame.scripts.OnUpdate ~= nil end
            if not pending then return end
        end
        error("timers did not settle")
    end

    function game:click() self.button.scripts.OnClick(self.button) end
    function game:hasMessage(message)
        for _, text in ipairs(self.messages) do
            if text:find(message, 1, true) then return true end
        end
        return false
    end

    env.GetLocale = function() return "enUS" end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(game.messages, text) end }
    env.GetCVar = function(name)
        if name == "gxMaximize" and options.missingMaximize then error("unknown CVar") end
        return game.cvars[name]
    end
    local function requestSize(width, height)
        game.sizes = game.sizes + 1
        if options.failSizeAt and options.failSizeAt[game.sizes] then error("size API failed") end
        game.requestWidth, game.requestHeight = width, height
    end
    env.SetCVar = function(name, value)
        if name == "gxMaximize" then
            game.modeChanges = game.modeChanges + 1
            if value == "1" then
                game.restores = game.restores + 1
                if game.restores <= (options.failRestores or 0) then error("mode API failed") end
            end
        elseif name == "gxWindowedResolution" then
            local width, height = value:match("(%d+)x(%d+)")
            requestSize(tonumber(width), tonumber(height))
        end
        game.cvars[name] = value
    end
    local function updateWindow()
        if not options.blockResize and game.requestWidth then
            game.width, game.height = game.requestWidth, game.requestHeight
        end
        game:fire("DISPLAY_SIZE_CHANGED")
    end
    if not options.noUpdate then
        if options.restartOnly then env.RestartGx = updateWindow
        else env.UpdateWindow = updateWindow end
    end
    env.GetPhysicalScreenSize = function()
        if game.failRead then error("screen API failed") end
        return game.width, game.height
    end
    if options.legacy then
        env.GetScreenResolutions = function() return "1920x1080", "2560x1440", "1280x720" end
    elseif not options.noBackend then
        env.C_VideoOptions = {
            GetDefaultGameWindowSize = function()
                if options.noTarget then return nil end
                if options.targetFollowsWindow and game.sizes > 0 then
                    return { x = game.width, y = game.height }
                end
                return { x = 2560, y = 1440 }
            end,
            SetGameWindowSize = function(width, height)
                requestSize(width, height)
                if options.noUpdate then updateWindow() end
            end,
        }
    end
    if options.noSetCVar then env.SetCVar = nil end
    if not options.fallbackTimer then
        env.C_Timer = { After = function(delay, callback)
            table.insert(game.timers, { at = game.now + delay, callback = callback })
        end }
    end
    local ns = {}
    loadAddonFile("Locales.lua", env, ns)
    loadAddonFile("LinuxResolutionFixReforged.lua", env, ns)
    game.L, game.env = ns.L, env
    game:fire("PLAYER_LOGIN")
    game:drain()
    return game
end

local function assertRestored(game)
    equal(game.cvars.gxMaximize, "1")
    equal(game.width, 2560)
    equal(game.height, 1440)
    assert(game.button.enabled)
    assert(not game.button.shown)
    assert(game:hasMessage(game.L.OK:format(2560, 1440)))
end

test("fullscreen correction completes despite resize events, slash commands and duplicate clicks", function()
    local game = newGame()
    assert(game.button.shown)
    game:click()
    assert(not game.button.enabled)
    equal(game.cvars.gxMaximize, "0")
    assert(game.width < 2560 and game.height < 1440)
    local calls = game.sizes
    game:click()
    game:fire("DISPLAY_SIZE_CHANGED")
    game.env.SlashCmdList.LINUXRESOLUTIONFIXREFORGED()
    equal(game.sizes, calls)
    equal(game.button.text, game.L.APPLYING)
    game:drain()
    assertRestored(game)
end)

test("windowed mode stays windowed", function()
    local game = newGame({ windowed = true })
    game:click()
    game:drain()
    equal(game.modeChanges, 0)
    equal(game.cvars.gxMaximize, "0")
    equal(game.height, 1440)
    assert(game:hasMessage(game.L.OK:format(2560, 1440)))
end)

for _, case in ipairs({
    { "legacy + UpdateWindow", { legacy = true } },
    { "legacy + RestartGx", { legacy = true, restartOnly = true } },
    { "modern + RestartGx", { restartOnly = true } },
    { "OnUpdate timer", { fallbackTimer = true } },
    { "no window update API", { noUpdate = true } },
    { "no SetCVar", { noSetCVar = true } },
}) do
    test("supported API fallback: " .. case[1], function()
        local game = newGame(case[2])
        game:click()
        game:drain()
        assertRestored(game)
    end)
end

test("an unavailable gxMaximize CVar falls back to resizing", function()
    local game = newGame({ missingMaximize = true })
    game:click()
    game:drain()
    equal(game.modeChanges, 0)
    assertRestored(game)
end)

test("unchanged size is reported and the button allows retrying", function()
    local options = { blockResize = true }
    local game = newGame(options)
    game:click()
    game:drain()
    assert(game.button.enabled and game.button.shown)
    assert(game:hasMessage(game.L.FAILED:format(2560, 1408, 2560, 1440)))
    options.blockResize = false
    game:click()
    game:drain()
    assertRestored(game)
end)

test("final verification uses the original target if target reporting changes", function()
    local game = newGame({ blockResize = true, targetFollowsWindow = true })
    game:click()
    game:drain()
    assert(not game:hasMessage(game.L.OK:format(2560, 1408)))
    assert(game:hasMessage(game.L.FAILED:format(2560, 1408, 2560, 1440)))
end)

test("restoration uses the original target after the temporary resize", function()
    local game = newGame({ targetFollowsWindow = true })
    game:click()
    game:drain()
    assertRestored(game)
end)

test("rechecking an already correct resolution does not change the display", function()
    local game = newGame()
    game.height = 1440
    game.env.SlashCmdList.LINUXRESOLUTIONFIXREFORGED()
    assert(not game.button.shown)
    equal(game.sizes, 0)
    equal(game.modeChanges, 0)
end)

for _, failure in ipairs({
    { failSizeAt = { [1] = true } },
    { failSizeAt = { [2] = true } },
    { failRestores = 1 },
}) do
    test("recoverable API error: " .. (failure.failRestores and "mode restore" or
        (failure.failSizeAt[1] and "temporary resize" or "target resize")), function()
        local game = newGame(failure)
        game:click()
        game:drain()
        assertRestored(game)
        assert(#game.messages >= 2, "the API error must be reported as well")
    end)
end

test("persistent API failure releases the button without claiming success", function()
    local game = newGame({ failSizeAt = { [2] = true, [3] = true } })
    game:click()
    game:drain()
    equal(game.cvars.gxMaximize, "1")
    assert(game.button.enabled and game.button.shown)
    assert(not game:hasMessage(game.L.OK:format(2560, 1440)))
end)

test("an error while reading the final size is reported and releases the button", function()
    local game = newGame()
    game:click()
    game.failRead = true
    -- Prevent separate resize events from reading the deliberately failing API.
    for _, frame in ipairs(game.frames) do frame.events.DISPLAY_SIZE_CHANGED = nil end
    game:drain()
    assert(game.button.enabled)
    assert(game:hasMessage("screen API failed"))
end)

for _, options in ipairs({ { noBackend = true }, { noTarget = true } }) do
    test("unavailable resolution information: " .. next(options), function()
        local game = newGame(options)
        game:click()
        game:drain()
        equal(game.sizes, 0)
        assert(not game.button.shown)
    end)
end

local english = localeStrings("enUS")
local function placeholders(text)
    local found = {}
    for placeholder in text:gmatch("%%[ds]") do table.insert(found, placeholder) end
    return table.concat(found, ",")
end

for _, locale in ipairs({ "frFR", "deDE", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    test("complete translations and matching placeholders: " .. locale, function()
        local strings = localeStrings(locale)
        for key, value in pairs(english) do
            assert(type(strings[key]) == "string" and #strings[key] > 0, key)
            assert(strings[key] ~= value, "English fallback for " .. key)
            equal(placeholders(strings[key]), placeholders(value))
            local args = {}
            for token in value:gmatch("%%[ds]") do table.insert(args, token == "%d" and 1440 or "test error") end
            assert(pcall(string.format, strings[key], unpack(args)), key)
        end
        for key in pairs(strings) do assert(english[key], "unexpected translation key: " .. key) end
    end)
end

test("English and unknown locales use the default strings", function()
    for _, locale in ipairs({ "enGB", "unknown" }) do
        local strings = localeStrings(locale)
        for key, value in pairs(english) do equal(strings[key], value) end
    end
end)

test("Spanish locales share the complete translation", function()
    local spain, mexico = localeStrings("esES"), localeStrings("esMX")
    for key, value in pairs(spain) do equal(mexico[key], value) end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
