--[[
    ScrollableList.lua
    Version: 0.8.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-10
    CC: Tweaked Version: 1.89.2
    Description:
    TODO:
        Add monitor support
        Complete readOnly functionality
]]

---@classScrollableList
local ScrollableList = {}

---@param out any
---@param data table<string>
---@param header? string
---@param backTxt? string
---@param onSelect? fun(d: string, s: integer): ...
---@return Textbox
function ScrollableList:new(out, data, header, backTxt, onSelect)
    out = out or term
    local xSize, ySize = out.getSize()
    local init = {
        onSelect = onSelect,
        lastIndex = #data,
        backTxt = backTxt,
        header = header,
        highlighted = 1,
        firstIndex = 1,
        xSize = xSize,
        ySize = ySize,
        data = data,
        out = out,
        s = {}
    }
    setmetatable(init, self)
    self.__index = self
    return init
end

function ScrollableList:_formatHeader(h)
    local formatted = h
    local maxSize = self.xSize - 20
    if #h > maxSize then
        formatted = string.sub(h, 1, maxSize) .. '...'
    end
    local xPos = ((self.xSize - #formatted) / 2) + 1
    if #h > maxSize then
        xPos = xPos + 1
    end
    return {
        header = formatted,
        x = xPos,
    }
end

function ScrollableList:_displayLine(str, yPos, isHighlighted)
    if isHighlighted then
        self.out.setCursorPos(1, yPos)
        self.out.write('>')
    end
    self.out.setCursorPos(3, yPos)
    local formatted = str
    if #str > self.xSize then
        formatted = string.sub(str, 1, self.xSize - 6) .. '...'
    end
    self.out.write(formatted)
end

function ScrollableList:_displayHeader(h, highlighted)
    if (highlighted == 0) then
        self.out.setCursorPos(1, 1)
        self.out.write('>')
    end
    self.out.setCursorPos(3, 1)
    if self.backTxt then self.out.write(self.backTxt)
    else self.out.write('back') end
    if h then
        self.out.setCursorPos(h.x, 1)
        self.out.write(h.header)
    end
    self.out.setCursorPos(1, 2)
    self.out.write(string.rep('-', self.xSize))
end

function ScrollableList:_displayList(h, first, last, highlighted)
    self.out.clear()
    self:_displayHeader(h, highlighted)

    local yPos = 3
    for i = first, last do
        self:_displayLine(self.data[i], yPos, i == highlighted)
        yPos = yPos + 1
    end
end

function ScrollableList:_selected(str)
    self.out.clear()
    self:_displayHeader(nil, 0)
    self.out.setCursorPos(1, 4)
    write(str)
    local key
    while (key ~= keys.enter) do
        _, key = os.pullEvent('key')
    end
end

function ScrollableList:_onSelect(selection)
    if self.onSelect then
        local result = {self.onSelect(self.data[selection], selection)}
        if result[1] == 'back' then
            table.remove(result, 1)
            return result
        end
    else self:_selected(self.data[selection]) end
end

function ScrollableList:_reset()
    self.lastIndex = #self.data
    local isOverflow = self.lastIndex > (self.ySize - 2)

    if isOverflow then
        self.lastIndex = self.ySize - 2
    end

    if #self.data == 0 then self.highlighted = 0 else self.highlighted = 1 end
end

function ScrollableList:_update(updated)
    self.data = updated
    self:_reset()
end

function ScrollableList:display()
    local pause = false
    self:_reset()

    local formattedHeader = nil
    if self.header then
        formattedHeader = self:_formatHeader(self.header)
        self.out.setCursorPos(formattedHeader.x, 1)
        self.out.write(formattedHeader.header)
    end

    local e, eData, _, ey
    while true do
        if not pause then
            self:_displayList(formattedHeader, self.firstIndex, self.lastIndex, self.highlighted)
        end

        e, eData, _, ey = os.pullEvent()
        if e == 'unpause_input' then
            pause = false
        elseif not pause then
            if e == 'update_list' then
                self:_update(eData)
            elseif e == 'pause_input' then
                pause = true
            elseif e == 'mouse_click' and eData == 1 then
                if ey == 1 then
                    self.out.clear()
                    self.out.setCursorPos(1, 1)
                    return
                elseif ey ~= 2 and ey - 2 <= (self.lastIndex - self.firstIndex + 1) then
                    self:_onSelect(self.firstIndex + ey - 3)
                end
            elseif e == 'mouse_scroll' then
                if eData == -1 and self.highlighted > 0 then             -- Scroll up
                    self.highlighted = self.highlighted - 1
                    if self.highlighted < self.firstIndex and self.highlighted ~= 0 then
                        self.firstIndex = self.firstIndex - 1
                        self.lastIndex = self.lastIndex - 1
                    end
                elseif eData == 1 and self.highlighted < #self.data then      -- Scroll down
                    self.highlighted = self.highlighted + 1
                    if self.lastIndex < self.highlighted then
                        self.firstIndex = self.firstIndex + 1
                        self.lastIndex = self.lastIndex + 1
                    end
                end
            elseif e == 'key' then
                if eData == keys.up and self.highlighted > 0 then
                    self.highlighted = self.highlighted - 1
                    if self.highlighted < self.firstIndex and self.highlighted ~= 0 then
                        self.firstIndex = self.firstIndex - 1
                        self.lastIndex = self.lastIndex - 1
                    end
                elseif eData == keys.down and self.highlighted < #self.data then
                    self.highlighted = self.highlighted + 1
                    if self.lastIndex < self.highlighted then
                        self.firstIndex = self.firstIndex + 1
                        self.lastIndex = self.lastIndex + 1
                    end
                elseif eData == keys.enter then
                    if self.highlighted == 0 then
                        self.out.clear()
                        self.out.setCursorPos(1, 1)
                        return
                    else
                        self:_onSelect(self.highlighted)
                    end
                end
            end
        end

    end
end

return ScrollableList
