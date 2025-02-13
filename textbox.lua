--[[
    Textbox.lua
    Version: 0.7.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-10
    CC: Tweaked Version: 1.89.2
    Description: A simple textbox with a '*' boarder around the text prompt.
        The callback supplied will be called anytime the text is updated.
        Pass in a sub-window into the 'out' param to adjust the size and 
        placement of the textbox.

        local x, y = self.out.getSize()
        window.create(term.current(), 1, 1, x, math.floor(y / 2))
]]

---@class Textbox
---@field txtX integer
---@field txtY integer
---@field x integer
---@field y integer
---@field text string
---@field placeholder? string
---@field callback? fun(text: string): nil
local Textbox = {}

---@param out? any
---@param placeholder? string
---@param callback? fun(text: string): nil
---@return Textbox
function Textbox:new(out, placeholder, callback)
    out = out or term
    local x, y = out.getSize()
    local init = {
        txtY = math.floor(y / 2) + 1,
        placeholder = placeholder,
        callback = callback,
        out = out,
        text = '',
        txtX = 6,
        x = x,
        y = y,
        s = {}
    }
    setmetatable(init, self)
    self.__index = self
    return init
end

---@private
function Textbox:_border()
    local char = '*'
    local bStr = string.rep(char, self.x)
    for i = 1, self.y do
        self.out.setCursorPos(1, i)
        if i == 1 or i == self.y then self.out.write(bStr)
        else
            self.out.write(char)
            self.out.setCursorPos(self.x, i)
            self.out.write(char)
        end
    end
end

---@private
function Textbox:_clearPlaceholder()
    if not self.placeholder then return end
    self.out.setCursorPos(self.txtX, self.txtY)
    self.out.write(string.rep(' ', #self.placeholder))
end

---@private
function Textbox:_displayPlaceholder()
    if not self.placeholder then return end

    self.out.setCursorPos(self.txtX, self.txtY)
    if self.out.isColor() then self.out.setTextColor(colors.gray) end
    self.out.write(self.placeholder)
    if self.out.isColor() then self.out.setTextColor(colors.white) end
end

---@private
function Textbox:_backspace()
    self.text = string.sub(self.text, 1, #self.text - 1)
    if #self.text == 0 then self:_displayPlaceholder()
    else
        self.out.setCursorPos(self.txtX + #self.text, self.txtY)
        self.out.write(' ')
    end
    if self.callback then self.callback(self.text) end
end

---@private
---@param char string
function Textbox:_onInput(char)
    if #self.text == 0 then self:_clearPlaceholder() end
    if self.txtX + #self.text > self.x - 5 then return end
    self.out.setCursorPos(self.txtX + #self.text, self.txtY)
    self.out.write(char)
    self.text = self.text .. char
    if self.callback then self.callback(self.text) end
end

---@private
function Textbox:_cursor()
    self.out.setCursorPos(self.txtX - 2, self.txtY)
    self.out.write('>')
    self:_displayPlaceholder()
end

function Textbox:display ()
    local pause = false
    self.out.clear()
    self:_border()
    self:_cursor()

    while true do
        local e, d = os.pullEvent()
        if e == 'unpause_input' then
            pause = false
        elseif e == 'clear_text' then
            while #self.text > 0 do
                self:_backspace()
            end
        elseif not pause then
            if e == 'pause_input' then
                pause = true
            elseif e == 'char' then
                self:_onInput(d)
            elseif e == 'key' and d == keys.backspace then
                self:_backspace()
            end
        end
    end
end

return Textbox
