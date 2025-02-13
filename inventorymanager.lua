-- AirsoftingFox 2025 --


-- TODO
--  If we detect the index is out of sync then kick off an index job
--  Fix the bug where the scrollablelist shrinks
--  Fix the naming for non-vanilla items
--   Wool is counted as one, regardless of its color
--   CC Networking cable will not store (probably related to above)


-- Imports --

local ScrollableList = require 'scrollable'
local tableutils = require 'tableutils'
local Inventory = require 'inventory'
local Textbox = require 'textbox'

-- Declared --

local transferRefreshRate = 2
local padding = 20

term.clear()
local x, y = term.getSize()
local winSize = math.floor(0.7 * y)
local aXPos = math.floor(0.65 * x)

local listWindow = window.create(term.current(), 1, 1, x, winSize - 1)
local searchWindow = window.create(term.current(), 1, winSize, x, y - winSize - 1)
local logWindow = window.create(term.current(), 1, y, x, 1)
local amountPromptWindow = window.create(listWindow, aXPos, 5, x, 15)

local inv = Inventory:new(nil, function () os.queueEvent('finished_index') end)
local invTables = tableutils.stream(inv:getAll())
local invNames

-- Supporting functions --

local function resetData()
    invTables = tableutils.stream(inv:getAll())
    invNames = invTables
        .map(function (i) return i.display .. string.rep(' ', padding - math.min(#i.display, padding)) .. i.count end)
    os.queueEvent('clear_text')
    os.queueEvent('update_list', invNames)
end

local function searchCallback(text)
    text = string.lower(text)
    local data = invNames
        .filter(function (d) return string.find(string.lower(d), text, 1, true) end)
    os.queueEvent('update_list', data)
end

-- Log window --

local function log(msg)
    logWindow.clear()
    logWindow.setCursorPos(2, 1)
    if logWindow.isColor() then logWindow.setTextColor(colors.gray) end
    logWindow.write(msg)
    if logWindow.isColor() then logWindow.setTextColor(colors.white) end
end

local function logConsumer()
    while true do
        local _, msg = os.pullEvent('log_message')
        if msg then log(msg) end
    end
end

-- Enter amount window prompt --

local amountInX, amountInY = 7, 3

local function backspace(text)
    text = string.sub(text, 1, #text - 1)
    amountPromptWindow.setCursorPos(amountInX + #text, amountInY)
    amountPromptWindow.write(' ')
    amountPromptWindow.setCursorPos(amountInX + #text, amountInY)
    return text
end

local function onInput(char, text)
    if amountInX + #text > x - aXPos then return text end
    amountPromptWindow.setCursorPos(amountInX + #text, amountInY)
    amountPromptWindow.write(char)
    text = text .. char
    return text
end

local function amountPromptReset()
    amountPromptWindow.setCursorPos(1, 1)
    amountPromptWindow.write('Enter an amount')
    amountPromptWindow.setCursorPos(amountInX, amountInY)
    if logWindow.isColor() then logWindow.setTextColor(colors.gray) end
    amountPromptWindow.write(0)
    if logWindow.isColor() then logWindow.setTextColor(colors.white) end
    amountPromptWindow.setCursorPos(amountInX, amountInY)
end

local function onListSelect(selection, index)
    local text = ''
    os.queueEvent('pause_input')
    amountPromptWindow.setCursorBlink(true)
    local e, d

    repeat
        e, d = os.pullEvent()
        if e == 'pause_input' then
            amountPromptReset()
        elseif e == 'char' and #text < 5 and string.find(d, '^[0-9]$') then
            text = onInput(d, text)
        elseif e == 'key' and d == keys.backspace then
            text = backspace(text)
        end
    until e == 'key' and d == keys.enter

    if #text > 0 then
        local _, _, capture = string.find(selection, '^(.-)%s*[0-9]+$')
        local item = invTables.find(function (i) return i.display == capture end)
        local count = math.min(tonumber(text) or 0, item.count)

        os.queueEvent('pause_transfer')
        inv:retrieve(item.name, count)

        resetData()
        os.queueEvent('log_message', 'INFO: Withdrawing ' .. count .. ' ' .. item.display)
    else
        os.queueEvent('log_message', 'WARN: No amount entered')
    end

    amountPromptWindow.setCursorBlink(false)
    amountPromptWindow.clear()
    os.queueEvent('unpause_input')
end

-- Transfer chest listener --

local function transerListener()
    local hasPulled = false
    local id = os.startTimer(transferRefreshRate)
    while true do
        local e, d = os.pullEvent()
        if e == 'timer' and id == d then
            if hasPulled then
                if inv:isTranferChestEmpty() then
                    hasPulled = false
                end
            else
                if not inv:isTranferChestEmpty() then
                    os.queueEvent('log_message', 'INFO: Storing new inventory')
                    inv:store()
                    os.queueEvent('clear_text')
                    os.queueEvent('log_message', 'INFO: Indexing inventory')
                end
            end
            id = os.startTimer(transferRefreshRate)
        elseif e == 'pause_transfer' then
            hasPulled = true
            id = os.startTimer(transferRefreshRate)
        end
    end
end

-- Index update listener --

local function updateListener()
    while true do
        os.pullEvent('finished_index')
        resetData()
        os.queueEvent('log_message', 'INFO: Indexing inventory complete')
    end
end


-- Main --

resetData()

local list = ScrollableList:new(listWindow, invNames, 'Global Inventory', 'Exit', onListSelect)
local txtB = Textbox:new(searchWindow, 'search inventory', searchCallback)

os.queueEvent('log_message', 'INFO: Click or press enter on a selection')
-- list.display     For displaying the scrollable list
-- txtB.display     For the textbox search field at the bottom of the screen
-- logConsumer      For the log listener that displays log messages at the bottom of the screen
-- transferListener Checks for inventory changes in the transfer containers, and then transfers items (Might move to inventory runner)
-- updateListener   Just listens for any index job that completes their indexing
-- inv:runner       This passes up the Co(routine)Pool's runner that manage the queue of jobs
parallel.waitForAny(function () list:display() end, function () txtB:display() end, logConsumer, transerListener, updateListener, function () inv:runner() end)

term.clear()