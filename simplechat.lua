--[[
    SimpleChat.lua
    Version: 0.9.1
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-16
    CC: Tweaked Version: 1.89.2
    Description: Using Plethora's neural interface with the chat recorder module,
        this ccTweaked program will create a canvas window in the upper right-hand
        corner of the player's screen and display the player chat without server
        messages or noise, without any text formatting, players' actual names, 
        and only player messages. Great if you want to casually converse without
        all of the noise. 
    TODO:
        Allow the user to scroll in the Neural connector to scroll the chat history
]]

local tableutils = require 'tableutils'
local unicode = require 'unicode'
local config = require 'config'

local yOffset = 2
local padding = 6
local maxRowCharCount = 60
local maxHistoryCount = 100
local maxMessagesDisplayed = 13

local colors = {
	["others"] = { 255, 255, 255 },		-- white
	["self"]   = { 252, 198, 194 }		-- red
}

local modules = peripheral.find("neuralInterface")
if not modules.hasModule("plethora:chat") then error("The chat recorder is missing", 0) end
if not modules.hasModule("plethora:introspection") then error("The introspection scanner is missing", 0) end
if not modules.hasModule("plethora:sensor") then error("The entity scanner is missing", 0) end
if not modules.hasModule("plethora:glasses") then error("The overlay glasses are missing", 0) end

local playerName = modules.getMetaOwner().name
local chat = tableutils.stream({})
local canvas = modules.canvas()
canvas.clear()

-- Create a all of the text elements we will need in the canvas window
local canvasTxtElems = tableutils.range(maxMessagesDisplayed,
    function(i)
        local text = canvas.addText({ 4, (i - 1) * padding + yOffset }, '', 0xFFFFFFFF, 0.6)
        text.setShadow(true)
        return text
    end)
-- Sort those elements so the bottom text element is first in the list
table.sort(canvasTxtElems, function (a, b) return table.pack(a.getPosition())[2] > table.pack(b.getPosition())[2] end)

local function saveHistory()
    config.save('chat_history', tableutils.sub(chat, math.max(#chat - maxHistoryCount, 1)))
end

local function removeMcChatFormatting(out)
    local iter = unicode.striter(out)
    local c = iter()
    local ret = ''
    while c do
        if string.byte(c) == 167 then iter()
        else ret = ret .. c end
        c = iter()
    end
    return ret
end

local function splitMessage(out)
    local split = {}
    local tTxt, lastSpace
    while #out ~= 0 do
        tTxt = out:sub(1, math.min(maxRowCharCount, #out))
        if #tTxt == #out then out = ''
        else
            lastSpace = tTxt:match(".*%s()")
            if lastSpace then tTxt = tTxt:sub(1, lastSpace - 1) end
            out = '    ' .. out:sub(math.min(#tTxt + 1, #out))
        end
        table.insert(split, tTxt)
    end
    return split
end

local function displayMessages()
    local cI, entry = next(chat)
    local dI, rowText = next(canvasTxtElems)

    while entry and rowText do
        local out = entry.player .. ' > ' .. entry.message
        out = removeMcChatFormatting(out)
        out = unicode.removeUnicode(out)
        local split = splitMessage(out)
        split = tableutils.reverse(split)
        for _, message in ipairs(split) do
            rowText.setText(message)
            rowText.setColor(table.unpack(colors[entry.player == playerName and 'self' or 'others']))
            dI, rowText = next(canvasTxtElems, dI)
            if not rowText then return end
        end
        cI, entry = next(chat, cI)
    end
end

local function setup()
    local history = config.load('chat_history')
    canvas.addRectangle(0, 0, 200, 80, 0x80808060)
    if not history or not #history then return tableutils.stream({}) end

    chat = tableutils.stream(history)
    displayMessages()
end

local function listen()
    while true do
        local _, player, message = os.pullEvent("chat_message")
        if player and message then
            local entry = {player = player, message = message}
            table.insert(chat, 1, entry)
            saveHistory()
            displayMessages()
        end
    end
end

local function capture()
 modules.capture("^!testing%.$")
 while true do
  local _, message, pattern, player, uuid = os.pullEvent("chat_capture")
  if message then print(message) end
 end
end

local function exit()
	while true do
		os.pullEventRaw('terminate')
		canvas.clear()
	end
end

term.clear()
term.setCursorPos(1, 1)
setup()
parallel.waitForAll(exit, listen)
