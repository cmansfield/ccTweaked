--[[
    unicode.lua
    Version: 0.4.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-18
    CC: Tweaked Version: 1.89.2
    Description: This is a collection of unicode utils to help add or remove unicode
        characters from lua strings. Since unicode characters can take up several 
        bytes of data, we have to analyse the first unicode byte to see how many
        following bytes belong to that single character.

        local test = 'hell😃o'   -- U+1F603
        local test2 = '\xF0\x9F\x98\x83'
        print(removeUnicode(test1))
        print(removeUnicode(test2))
]]

---@param bit integer
---@return integer
local function bitToInt(bit)
    return 2 ^ (bit - 1)
end

---@param int integer
---@param bit integer
---@return boolean
local function isBitEnabled(int, bit)
    local i = bitToInt(bit)
    return int % (i + i) >= i
end

---@param int integer
---@param bit integer
---@return integer
local function setBit(int, bit)
  return isBitEnabled(int, bit) and int or int + bitToInt(bit)
end

---@param int integer
---@param bit integer
---@return integer
local function clearBit(int, bit)
  return isBitEnabled(int, bit) and int - bitToInt(bit) or int
end

local unicode = {}

---@param firstByte integer
---@return integer
function unicode.getUnicodeByteCount(firstByte)
    local c = 0
    for i = 8, 1, -1 do
        if not isBitEnabled(firstByte, i) then return c end
        c = c + 1
    end
    return c
end

---@param str string
---@return fun(): string | nil
function unicode.striter(str)
    local i = 0
    local n = #str
    return function ()
        i = i + 1
        return i <= n and str:sub(i,i) or nil
    end
end

---@param str string
---@return string
function unicode.removeUnicode(str)
    local iter = unicode.striter(str)
    local c, ret = nil, ''

    repeat
        c = iter()
        if not c then return ret end
        if string.byte(c) >= 127 then
            for i = 2, unicode.getUnicodeByteCount(string.byte(c)) do iter() end
        else
            ret = ret .. c
        end
    until not c

    return ret
end

return unicode