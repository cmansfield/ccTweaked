--[[
    gui.lua
    Version: 0.7.5
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-03-08
    CC: Tweaked Version: 1.89.2
    Description:
]]

---@diagnostic disable: param-type-mismatch
---@diagnostic disable: inject-field

local tableutils = require 'tableutils'
local oop = require 'oop'

---This will split any length of text based on the max char length 
---provided, it will split on words and will not break words up accross
---multiple rows.
---@param text string
---@param max integer
---@return table<string>
local function split(text, max)
    local s = {}
    local tTxt, lastSpace
    while #text ~= 0 do
        tTxt = text:sub(1, math.min(max, #text))
        if #tTxt == #text then text = ''
        else
            lastSpace = tTxt:match(".*%s()")
            if lastSpace then tTxt = tTxt:sub(1, lastSpace - 1) end
            text = text:sub(math.min(#tTxt + 1, #text))
        end
        table.insert(s, tTxt)
    end
    return s
end

---@class Bounds
---@field [1] number startX - upper left x point
---@field [2] number startY - upper left y point
---@field [3] number endX   - lower right x point
---@field [4] number endY   - lower right y ponit
local Bounds = { 1, 1, 51, 19 }

---Check is the x, y point is within the bounds supplied
---@param x integer
---@param y integer
---@param bounds table<Bounds>
---@return boolean
local function withinBounds(x, y, bounds)
    return x >= bounds[1] and x <= bounds[3] and y >= bounds[2] and y <= bounds[4]
end

---Converts the supplied localBounds to a globalBounds value
---Required for mouse clicks, the x, y coordinates are always in the global space
---@param localBounds Bounds    The bounds normalized for a sub window
---@param globalBounds Bounds   The bounds at the global scale
---@return Bounds
local function convertLocalBoundsToGlobal(localBounds, globalBounds)
    local x = localBounds[1] + globalBounds[1] - 1
    local y = localBounds[2] + globalBounds[2] - 1
    local xEnd = localBounds[3] + globalBounds[1] - 1
    local yEnd = localBounds[4] + globalBounds[2] - 1
    return {x, y, xEnd, yEnd}
end


--[[
    The bounds of each element is it's global position in the out field. That means
    regardless of how nested elements are, they always know where exactly they are on 
    the screen. The bounds are {startX, startY, endX, endY}
]]
---@class Element               The base class for all 'DOM' like elements
---@field id string             The element's unique identifier
---@field out any               The output buffer for displaying content, can be term, a monitor, window, ect...
---@field bounds Bounds         The global bounds of the element
local Element = oop.class{default = {
    id = '',
    out = term.native(),
    bounds = {1, 1, 51, 19}
}}


--[[
    local GUI = require 'gui'
    local oop = require 'oop'

    local x, y = term.getSize()
    local bounds = {20, 8, x - 5, y - 5}
    local win = window.create(term.current(), table.unpack(bounds))

    local box = GUI.Box:new{
        id = 'custom_box',
        out = win,
        bounds = bounds,
        width =  bounds[3] - bounds[1],
        height = bounds[4] - bounds[2],
        backgroundColor = colors.purple
    }

    box:render()
]]

---@class Box
---@field private default table     The default values for this class, if a value isn't passed into new then these values are used
---@field x integer                 The start of the box. x point of the upper left corner
---@field y integer                 The start of the box. y point of the upper left corner
---@field width integer             The width of the box
---@field height integer            The height of the box
---@field backgroundColor? string
---@see Element.default for other Box fields
local Box = oop.class{extends = {Element}, default = {
    x = 1,
    y = 1,
    width = 0,
    height = 0,
    backgroundColor = colors.gray,
}}
function Box:render()
    if not self.backgroundColor then return end
    term.redirect(self.out)
    local orig = self.out.getBackgroundColor()
    self.out.setBackgroundColor(self.backgroundColor)
    for y = self.y, self.y + self.height - 1 do
        self.out.setCursorPos(self.x, y)
        self.out.write((' '):rep(self.width))
    end
    self.out.setBackgroundColor(orig)
end

function Box:withinBounds(x, y)
    return x >= self.x and x < self.x + self.width and y >= self.y and y < self.y + self.height
end


--[[
    local GUI = require 'gui'
    local oop = require 'oop'

    local x, y = term.getSize()
    local bounds = {20, 8, x - 5, y - 5}
    local win = window.create(term.current(), table.unpack(bounds))

    local box = GUI.Text:new{
        text = 'Sample Text',
        id = 'custom_txt',
        out = win,
        bounds = bounds,
        width =  bounds[3] - bounds[1],
        height = bounds[4] - bounds[2],
        backgroundColor = colors.blue
    }

    box:render()
]]

local leftAlign = 'left'
local centerAlign = 'center'

---@class Text
---@field private default table     The default values for this class, if a value isn't passed into new then these values are used
---@field textColor string          The color the displayed text
---@field align string      
---@field text string               The text value to be displayed
---@see Box.default for other Text fields
local Text = oop.class{extends = {Box}, default = {
    textColor = colors.white,
    align = centerAlign,
    text = '',
}}

---@param y integer
function Text:printText(y)
    if self.align == centerAlign then
        self.out.setCursorPos(self.x, y)
        self.out.write((' '):rep(self.width))
        self.out.setCursorPos(math.ceil(self.width / 2 - (#self.text / 2) + self.x), y)
        local l, m = self.out.getCursorPos()
        self.textStart = {x = l, y = m}
        self.out.write(self.text)
    else
        self.out.setCursorPos(self.x + 1, y)
        local l, m = self.out.getCursorPos()
        self.textStart = {x = l, y = m}
        self.out.write(self.text)
    end
end

---@override fun(): nil     -- Overriding the Box:render method
function Text:render()
    Box.render(self)        -- Call the parent method
    local y = self.y + math.floor(self.height / 2)
    local _, bY = self.out.getSize()
    if y <= 0 or y > bY then return end
    local orig = self.out.getBackgroundColor()
    if self.backgroundColor then self.out.setBackgroundColor(self.backgroundColor) end
    self.out.setTextColor(self.textColor)
    self:printText(y)
    self.out.setBackgroundColor(orig)
end

function Text:clear()
    self.text = ''
    self:render()
end

---@param text string
function Text:setText(text)
    self.text = text
    self:render()
end


---@class Button
---@see Text.default for other Text fields
local Button = oop.class{extends = {Text, oop.Runnable}}
function Button:onClick()
    -- no-op
end

---@override fun(): nil     -- Overriding the Runnable:initialize method
function Button:initialize()
    self:render()
end

---@override fun(): table   -- Overriding the Runnable:yieldAction method
function Button:yieldAction()
    return table.pack(os.pullEvent('mouse_click'))
end

---@override fun(e: string, eData: integer, x: integer, y: integer): nil     -- Overriding the Runnable:run method
function Button:run(e, eData, x, y)
    if (e == 'mouse_click') and withinBounds(x, y, self.bounds) then
        self:onClick()
    end
end


--[=====[
    local GUI = require 'gui'
    local oop = require 'oop'

    local x, y = term.getSize()
    local bounds = {20, 6, x - 5, y - 3}
    local win = window.create(term.current(), table.unpack(bounds))

    local group = GUI.Group:new{
        id = 'custom_group',
        bounds = bounds,
        out = win,
    }

    local width, height = bounds[3] - bounds[1], bounds[4] - bounds[2]
    group:addElement(GUI.Box:new{
        backgroundColor = colors.gray,
        width = width,
        height = height,
    })

    group:addElement(GUI.Text:new{
        text = 'Sample Text',
        backgroundColor = colors.orange,
        width =  15,
        height = 4,
    })

    group:addElement(GUI.Box:new{
        backgroundColor = colors.red,
        width =  10,
        height = 4,
        x = width - 10,
        y = height - 4,
    })

    if group:isStatic() then
        group:render()
    else
        parallel.waitForAll(oop.getExecutables(group))
    end
]=====]

---@class Group
---@field protected elements Element[]
---@see Element.default for other Group fields
local Group = oop.class{extends = {Element, oop.Runnable}, default = {
    elements = {},
}}

---@override fun(): nil     -- Overriding the Box:render method
function Group:render()
    term.redirect(self.out)
    self.out.clear()
    self.out.setCursorPos(1, 1)
    for _, elem in ipairs(self.elements) do if elem.render then elem:render() end end
end

---@override fun(): nil     -- Overriding the Runnable:initialize method
function Group:initialize()
    self:render()
end

---@param element Element?
function Group:addElement(element)
    if element then
        element.out = self.out
        table.insert(self.elements, element)
    end
end

---@return (fun(): nil)[]
function Group:getSubElementExecutors()
    return tableutils.stream(self.elements)
        .filter(function (elem) return elem.executor end)
        .map(function (elem) return elem:executor() end)
        .filter(function (funcs) return funcs and #funcs end)
        .reduce(function (acc, f) tableutils.append(acc, f) return acc end, {})
end

---@return boolean
function Group:isStatic()
    return #self:getSubElementExecutors() == 0
end

---@override fun(): nil     -- Overriding the Runnable:executor method
function Group:executor()
    self:initialize()
    return self:getSubElementExecutors()
end

---@param id string
function Group:findById(id)
    if self.id == id then return self end
    for _, elem in ipairs(self.elements) do
        if elem.id == id then return elem end
        if elem.findById then
            local found = elem:findById(id)
            if found then return found end
        end
    end
end


---@class InteractiveGroup          This will group elements together and allow the user to interact with them
---@field scrollEnabled boolean     Allow scrolling of the elements if they exceed the window size
---@field clickEnabled boolean      Allow clicking on the elements
---@see Group.default for other InteractiveGroup fields
local InteractiveGroup = oop.class{extends = {Group, oop.Runnable}, default = {
    mouseDragEnabled = true,
    scrollEnabled = true,
    clickEnabled = true,
}}

---@override fun(): table<fun(): nil>     -- Overriding the Group:executor method
function InteractiveGroup:executor()
    return oop.Runnable.executor(self)
end

---@param eData integer
function InteractiveGroup:mouseScroll(eData)
    if not self.elements or not #self.elements then return end
    local x, y = self.out.getSize()
    if eData == 1 and self.elements[#self.elements].y < math.floor(y / 2) then return
    elseif eData == -1 and self.elements[1].y > 1 then return end

    term.redirect(self.out)
    self.out.clear()
    for _, elem in ipairs(self.elements) do
        elem.y = elem.y - eData
        elem:render()
    end
end

function InteractiveGroup:mouseSelect(x, y)
    local nX = x - self.bounds[1] + 1      -- We need to offset based on the window's boundry
    local nY = y - self.bounds[2] + 1
    local elem = tableutils.stream(self.elements)
        .filter(function (elem) return elem.onClick end)
        .findFirst(function (elem) return elem:withinBounds(nX, nY) end)
    if elem then elem:onClick() end
end

-- If a mouse drag event fires multiple times before we've dragged off an element
-- This will help prevent toggling it multiple times
local previous = { x = -1, y = -1 }

---@param e string          The fired event
---@param eData integer     The event's data
---@param x integer         The x coordinate of the event
---@param y integer         The y coordinate of the event
---@override fun(e: string, eData: any, x: integer, y: integer): nil   -- Overriding the Runnable:run method
function InteractiveGroup:run(e, eData, x, y)
    if (e == 'mouse_click') and withinBounds(x, y, self.bounds) then
        self:mouseSelect(x, y)
    elseif e == 'mouse_scroll' and withinBounds(x, y, self.bounds) then
        self:mouseScroll(eData)
    elseif e == 'mouse_drag' and previous.y ~= y and withinBounds(x, y, self.bounds) then
        self:mouseSelect(x, y)
        previous.x, previous.y = x, y
    end
end

---@override fun(): table   -- Overriding the Runnable:yieldAction method
function InteractiveGroup:yieldAction()
    local eData, funcs = {}, {}
    if self.clickEnabled then table.insert(funcs, function () eData = table.pack(os.pullEvent('mouse_click')) end) end
    if self.scrollEnabled then table.insert(funcs, function () eData = table.pack(os.pullEvent('mouse_scroll')) end) end
    if self.mouseDragEnabled then table.insert(funcs, function () eData = table.pack(os.pullEvent('mouse_drag')) end) end
    if #funcs then parallel.waitForAny(table.unpack(funcs))
    else parallel.waitForAny(function () sleep(100) end) end
    return eData
end


---@class TextField
---@field onTextChange? fun(text: string): nil
---@field placeholder? string
---@field textColor string
---@field focusEnabled boolean
---@field editEnabled boolean
---@field isFocused boolean
---@field text string
---@see Group.default for other TextField fields
---@see Box.default for other TextField fields
local TextField = oop.class{extends = {Group, Box, oop.Runnable}, default = {
    onTextChange = function (text) --[[ no-op ]] end,
    placeholder = 'placeholder text',
    textColor = colors.black,
    focusEnabled = true,
    editEnabled = true,
    isFocused = false,
    text = '',
}}

---@override fun(): nil     -- Overriding the Group:render method
function TextField:render()
    term.redirect(self.out)
    -- self.out.clear()
    Box.render(self)
    self.out.setCursorPos(1, 1)
    for _, elem in ipairs(self.elements) do elem:render() end
end

---@override fun(): nil     -- Overriding the Group:executor method
function TextField:executor()
    return oop.Runnable.executor(self)
end

---@override fun(): nil     -- Overriding the Group:initialize method
function TextField:initialize()
    self.placeholder = self.placeholder:sub(1, math.min(#self.placeholder, self.width - 1))
    self:addElement(Text:new{
        backgroundColor = self.backgroundColor,
        align = self.align or 'left',
        textColor = self.textColor,
        text = self.placeholder,
        bounds = self.bounds,
        height = self.height,
        width = self.width,
        x = self.x,
        y = self.y,
    })
    self:render()
    self:setCursorBlink()
end

---@param e string          The fired event
---@param eData integer     The event's data
---@param x integer         The x coordinate of the event
---@param y integer         The y coordinate of the event
---@override fun(e: string, eData: any, x: integer, y: integer): nil   -- Overriding the Runnable:run method
function TextField:run(e, eData, x, y)
    if (e == 'mouse_click') then
        local inBounds = withinBounds(x, y, self.bounds)
        if inBounds and not self.isFocused then
            self.isFocused = true
            self:setCursorBlink()
        elseif not inBounds and self.isFocused then
            self.out.setCursorBlink(false)
            self.isFocused = false
        end
    elseif e == 'char' and self.isFocused then
        self:onInput(eData)
    elseif e == 'key' and self.isFocused and eData == keys.backspace then
        self:backspace()
    end
end

---@override fun(): table   -- Overriding the Runnable:yieldAction method
function TextField:yieldAction()
    local eData, funcs = {}, {}
    if self.focusEnabled then table.insert(funcs, function () eData = table.pack(os.pullEvent('mouse_click')) end) end
    if self.editEnabled then table.insert(funcs, function () eData = table.pack(os.pullEvent('char')) end) end
    if self.editEnabled then table.insert(funcs, function () eData = table.pack(os.pullEvent('key')) end) end
    if #funcs then parallel.waitForAny(table.unpack(funcs))
    else parallel.waitForAny(function () sleep(100) end) end
    return eData
end

function TextField:setCursorBlink()
    if not self.isFocused then return end
    local x, y = self.elements[1].textStart.x, self.elements[1].textStart.y
    self.out.setCursorPos(x + #self.text, y)
    self.out.setCursorBlink(self.isFocused)
end

---@param char string
function TextField:onInput(char)
    term.redirect(self.out)
    local orig = self.out.getBackgroundColor()

    if #self.text == 0 then self:clearPlaceholder() end
    local x, y = self.elements[1].textStart.x, self.elements[1].textStart.y
    if x + #self.text > self.width - 1 then return end

    self.out.setCursorPos(x + #self.text, y)
    self.out.setBackgroundColor(self.backgroundColor)
    self.out.write(char)
    self.out.setBackgroundColor(orig)
    self.text = self.text .. char
    self.elements[1].text = self.text

    if self.onTextChange then self.onTextChange(self.text) end
end

function TextField:clearPlaceholder()
    if not self.placeholder then return end
    self.elements[1]:setText('')
end

function TextField:backspace()
    self.text = string.sub(self.text, 1, #self.text - 1)
    if #self.text == 0 then
        self:displayPlaceholder()
        if self.onTextChange then self.onTextChange(self.text) end
        return
    else
        local x, y = self.elements[1].textStart.x, self.elements[1].textStart.y
        local orig = self.out.getBackgroundColor()
        self.out.setBackgroundColor(self.backgroundColor)
        self.out.setCursorPos(x + #self.text, y)
        self.out.write(' ')
        self.out.setCursorPos(x + #self.text, y)
        self.out.setBackgroundColor(orig)
    end
    if self.onTextChange then self.onTextChange(self.text) end
end

function TextField:displayPlaceholder()
    if not self.placeholder then return end
    local x, y = self.elements[1].textStart.x, self.elements[1].textStart.y
    self.elements[1]:setText(self.placeholder)
    self.out.setCursorPos(x, y)
end


---@class ButtonStyle
---@field x integer
---@field y integer
---@field width integer
---@field height integer
---@field textColor string
---@field selectColor string
---@field backgroundColor string
local ButtonStyle = {
    x = 2,
    y = 2,
    width = 15,
    height = 3,
    textColor = colors.white,
    selectColor = colors.green,
    backgroundColor = Box.default.backgroundColor,
}


--[=====[
    local GUI = require 'gui'
    local oop = require 'oop'

    local x, y = term.getSize()
    local bounds = {30, 1, x, y}
    local win = window.create(term.current(), table.unpack(bounds))

    local select = GUI.MultiSelect:new{
        out = win,
        bounds = bounds,
        backgroundColor = colors.pink,
        btnStyle = {height = 1, selectColor = colors.red},
        list = {'Selection 1', 'Selection 2', 'Selection 3'},
    }

    parallel.waitForAll(oop.getExecutables(select))
]=====]

---@class MultiSelect                                           Displays a list of interactable elements
---@field list string[]                                         The list of values to display
---@field protected selected integer[]                          The list of values that have been selected
---@field btnStyle ButtonStyle                                  The style of each of the displayed values
---@field onSelection fun(index: integer, elem: Element): nil   The callback when an element is selected
---@see Box.default for other MultiSelect fields
---@see InteractiveGroup.default for other MultiSelect fields
local MultiSelect = oop.class{extends = {InteractiveGroup, Box}, default = {
    list = {},
    selected = {},
    btnStyle = tableutils.copy(ButtonStyle),
    onSelection = function (index, elem) --[[no-op]] end,
    onSubmit = function () --[[no-op]] end,
}}

---@override fun(): nil     -- Overriding the Group:render method
function MultiSelect:render()
    term.redirect(self.out)
    self.out.clear()
    Box.render(self)
    self.out.setCursorPos(1, 1)
    for _, elem in ipairs(self.elements) do elem:render() end
end

function MultiSelect:setBoundry()
    self.x, self.y = 1, 1
    self.width = self.bounds[3] - self.bounds[1] + 1
    self.height = self.bounds[4] - self.bounds[2] + 1
end

---@override fun(eData: integer): nil     -- Overriding the InteractiveGroup:mouseScroll method
function MultiSelect:mouseScroll(eData)
    if not self.elements or not #self.elements then return end
    local x, y = self.out.getSize()
    if eData == 1 and self.elements[#self.elements].y < math.floor(y / 2) then return
    elseif eData == -1 and self.elements[1].y > 1 then return end

    term.redirect(self.out)
    self.out.clear()
    Box.render(self)
    for _, elem in ipairs(self.elements) do
        elem.y = elem.y - eData
        elem:render()
    end
end

---On list item selection without calling the callback method that leaves the MultiSelect element
---@param index integer     The index of the list item selected
---@return Element          The element at that index
function MultiSelect:onSelectNoCallback(index)
    local foundIndex = tableutils.findi(self.selected, function (v) return v == index end)
    local elem = self.elements[index]

    if foundIndex then
        table.remove(self.selected, foundIndex)
        elem.backgroundColor = self.btnStyle.backgroundColor
    else
        table.insert(self.selected, index)
        elem.backgroundColor = self.btnStyle.selectColor
    end
    elem:render()
    return elem
end

---The onSelect method that includes the callback that leaves this element
---@param index integer     The index of the list item selected
function MultiSelect:onSelect(index)
    local elem = self:onSelectNoCallback(index)
    self.onSelection(index, elem)
end

---@override fun(): nil     -- Overriding the Group:initialize method
function MultiSelect:initialize()
    local u = tableutils.copy(MultiSelect.default.btnStyle)
    tableutils.union(u, self.btnStyle)
    -- Make sure the buttons are wide enough for the text
    local longest = tableutils
        .reduce(self.list, function (acc, l) return math.max(acc, #l) end, 2)
    u.width = math.max(longest + 2, u.width)
    Button.default = u
    self.btnStyle = u
    self:setBoundry()

    local btnX = math.ceil(math.ceil((self.width + 1) / 2) - self.btnStyle.width / 2)
    tableutils.stream(self.list)
        .mapi(function (i, l)
                self:addElement(
                    Button:new{
                        text = l,
                        onClick = function() self:onSelect(i) end,
                        y = (u.height + 1) * (i - 1) + u.y,
                        x = btnX
                    }
                )
            end
        )

    -- Check to see if we have enough elements to allow scrolling
    local tHeight = #self.list * (u.height + 1)
    if self.bounds[4] - self.bounds[2] >= tHeight then self.scrollEnabled = false end

    self:render()
end

function MultiSelect:setList(list)
    self.elements = {}
    self.selected = {}
    self.list = list
    self:initialize()
end


--[[
    local GUI = require 'gui'
    local oop = require 'oop'

    local x, y = term.getSize()
    local bounds = {30, 1, x, y}
    local win = window.create(term.current(), table.unpack(bounds))

    local select = GUI.MultiSelectWithControls:new{
        out = win,
        bounds = bounds,
        backgroundColor = colors.pink,
        header = 'Multi-select header',
        btnStyle = {height = 1, selectColor = colors.red},
        list = {'Selection 1', 'Selection 2', 'Selection 3', 'Selection 4', 'Selection 5', 'Selection 6', 'Selection 7', 'Selection 8', 'Selection 9', 'Selection 10', 'Selection 11', 'Selection 12'},
    }

    bounds = {1, 1, 29, y}
    win = window.create(term.current(), table.unpack(bounds))
    local select2 = GUI.MultiSelectWithControls:new{
        out = win,
        bounds = bounds,
        backgroundColor = colors.pink,
        header = 'Multi-select header',
        btnStyle = {height = 1, selectColor = colors.red},
        list = {'Selection 1', 'Selection 2', 'Selection 3', 'Selection 4', 'Selection 5', 'Selection 6', 'Selection 7', 'Selection 8', 'Selection 9', 'Selection 10', 'Selection 11', 'Selection 12'},
    }

    parallel.waitForAll(oop.getExecutables(select, select2))
]]

local btnTextNone = '[ none ]'
local btnTextAll =  '[  all ]'

---@class MultiSelectWithControls       A MultiSelect with a header and additional controls to control the list
---@field placeholder string            The text to be displayed in the search box
---@field header string                 The text to be displayed at the top of the element
---@field primaryColor string
---@field secondaryColor string
---@field tertiaryColor string
---@field includeSelectAll boolean
---@field onSelection fun(i: integer, v: string): nil
---@field protected filtered string[]   The list of elements to be displayed
---@see Group.default for other MultiSelectWithControls fields
local MultiSelectWithControls = oop.class{extends = {Group}, default = {
    placeholder = 'Click to search',
    header = 'header placeholder',
    primaryColor = colors.gray,
    secondaryColor = colors.organge,
    tertiaryColor = colors.lightGray,
    includeSelectAll = true,
    onSelection = function (i, v) --[[ no-op ]] end,
    filtered = {},
}}

---@override fun(): nil     -- Overriding the Group:render method
function MultiSelectWithControls:render()
    Group.render(self)
    self:setCursor()
end

function MultiSelectWithControls:setCursor()
    local elem = self:findById('search')
    if elem then elem:setCursorBlink() end
end

function MultiSelectWithControls:setBoundry()
    self.x, self.y = 1, 1
    self.width = self.bounds[3] - self.bounds[1] + 1
    self.height = self.bounds[4] - self.bounds[2] + 1
end

---@override fun(elem: Element): nil     -- Overriding the Group:addElement method
function MultiSelectWithControls:addElement(element)
    if element then
        table.insert(self.elements, element)
    end
end

---@param btn Button
function MultiSelectWithControls:selectAllToggle(btn)
    local isAll = btn.text == btnTextAll
    btn.text = isAll and btnTextNone or btnTextAll
    local multi = tableutils.stream(self.elements)
        .findFirst(function (elem) return elem.list and #elem.list end)
    local currentSelection = tableutils.stream(tableutils.copy(multi.selected))
    local toToggle = currentSelection

    if isAll then
        toToggle = tableutils.stream(multi.elements)
            .mapi(function (i, _) if currentSelection.findFirst(function (s) return s == i end) then return nil else return i end end)
            .filter(function (i) return i end)
    end
    toToggle.forEach(function (i) MultiSelect.onSelectNoCallback(multi, i) end)
    self:render()
end

---This is a callback that gets called when the MultiSelect element has one of its buttons selected.
---This is important because it allows us to control other elements at the parent level, such as
---updating the select "[ all ]" button.
---@param index integer
---@param button Button
function MultiSelectWithControls:onRowSelect(index, button)
    local multi = tableutils.stream(self.elements)
        .findFirst(function (elem) return elem.list and #elem.list end)
    local selected = tableutils.stream(multi.selected)
        .findi(function (i) return index == i end)
    if self.controlbutton then
        if not selected then
            self.controlbutton:setText(btnTextAll)
            self.controlbutton:render()
        elseif #multi.elements == #multi.selected then
            self.controlbutton:setText(btnTextNone)
            self.controlbutton:render()
        end
    end

    if self.onSelection then self.onSelection(index, button.text) end
end

---@param text string
function MultiSelectWithControls:onSearch(text)
    local lower = text:lower()
    local multi = tableutils.stream(self.elements)
        .findFirst(function (elem) return elem.list and #elem.list end)
    self.filtered = #text == 0 and self.list or
        tableutils.stream(self.list)
            .filter(function (i) return string.find(i:lower(), lower) end)
    multi:setList(self.filtered)
    self:setCursor()
end

---@override fun(): nil     -- Overriding the Group:initialize method
function MultiSelectWithControls:initialize()
    self.filtered = tableutils.copy(self.list)
    self:setBoundry()
    local _, y = self.out.getSize()

    local bounds = {1, 1, self.width, 3}
    local win = window.create(self.out, table.unpack(bounds))
    local header = Text:new{
        backgroundColor = self.secondaryColor,
        textColor = self.primaryColor,
        text = self.header,
        width = self.width,
        height = 3,
        out = win,
        x = 1,
        y = 1,
    }
    self:addElement(header)

    bounds = {1, 4, self.width, 6}
    win = window.create(self.out, table.unpack(bounds))
    local controlGroup = Group:new{
        bounds = convertLocalBoundsToGlobal(bounds, self.bounds),
        out = win,
    }
    controlGroup:addElement(Box:new{
        bounds = convertLocalBoundsToGlobal(bounds, self.bounds),
        backgroundColor = self.btnStyle.backgroundColor,
        width = self.width,
        height = 2,
    })
    controlGroup:addElement(TextField:new{
        onTextChange = function (text) self:onSearch(text) end,
        placeholder = self.placeholder,
        textColor = self.secondaryColor,
        backgroundColor = self.primaryColor,
        bounds = convertLocalBoundsToGlobal({
            bounds[1], bounds[2], self.width - #btnTextAll - 2, bounds[4] - 1,
        }, self.bounds),
        width = self.includeSelectAll and (self.width - #btnTextAll - 1) or self.width,
        id = 'search',
        height = 2,
    })
    if self.includeSelectAll then
        local btnX = self.width - #btnTextAll
        self.controlbutton = Button:new{
            backgroundColor = self.btnStyle.selectColor,
            textColor = self.primaryColor,
            width = #btnTextAll,
            text = btnTextAll,
            height = 1,
            x = btnX,
            y = 2,
            bounds = convertLocalBoundsToGlobal({
                btnX, 5, btnX + #btnTextAll - 1, 5,
            }, self.bounds),
            onClick = function (btn) self:selectAllToggle(btn) end
        }
        controlGroup:addElement(self.controlbutton)
    end
    self:addElement(controlGroup)

    self.btnStyle.textColor = self.primaryColor
    self.btnStyle.backgroundColor = self.secondaryColor
    bounds = {1, 6, self.width, y}
    win = window.create(self.out, table.unpack(bounds))
    local select = MultiSelect:new{
        bounds = convertLocalBoundsToGlobal(bounds, self.bounds),
        onSelection = function (i, b) self:onRowSelect(i, b) end,
        backgroundColor = self.tertiaryColor,
        btnStyle = self.btnStyle,
        list = self.list,
        out = win,
    }
    self:addElement(select)

    self:render()
end


---@class Confirmation
---@field text string
---@field header string
---@field primaryColor string
---@field secondaryColor string
---@field confirmBtnText string
---@field onConfirm fun(): nil
---@see Group.default for other Confirmation fields
local Confirmation = oop.class{extends = {Group}, default = {
    text = 'text placeholder',
    header = 'header placeholder',
    primaryColor = colors.gray,
    secondaryColor = colors.orange,
    confirmBtnText = 'OK',
    onConfirm = function () --[[ no-op ]] end,
}}

function Confirmation:createButtons()
    local width = self.bounds[3] - self.bounds[1] + 1
    local btnWidth = 15
    local bX = math.floor((width / 2) - (btnWidth / 2))
    self:addElement(Button:new{
        bounds = {bX, 12, bX + btnWidth - 1, 14},
        backgroundColor = self.secondaryColor,
        textColor = self.primaryColor,
        text = self.confirmBtnText,
        onClick = self.onConfirm,
        width = btnWidth,
        x = bX,
        height = 3,
        y = 12,
    })
end

function Confirmation:initialize()
    local width, height = self.bounds[3] - self.bounds[1] + 1, self.bounds[4] - self.bounds[2] + 1
    self:addElement(Box:new{
        backgroundColor = self.primaryColor,
        height = height,
        width = width,
    })
    self:addElement(Text:new{
        text = self.header,
        backgroundColor = self.secondaryColor,
        textColor = self.primaryColor,
        width =  width,
        height = 3,
    })
    self:addElement(Box:new{
        backgroundColor = self.primaryColor,
        width =  width,
        height = height - 3,
        x = 1,
        y = 4,
    })

    local maxCharCount = math.floor(width - (width * 0.2))
    local rows = split(self.text, maxCharCount)
    for i, rowText in ipairs(rows) do
        self:addElement(Text:new{
            backgroundColor = self.primaryColor,
            textColor = self.secondaryColor,
            text = rowText,
            width =  width,
            height = 1,
            x = 1,
            y = 5 + i
        })
    end

    self:createButtons()
    self:render()
end


--[[
    local GUI = require 'gui'
    local oop = require 'oop'

    term.clear()
    term.setCursorPos(1, 1)
    local x, y = term.getSize()
    local bounds = {1, 1, x, y}
    local win = window.create(term.current(), table.unpack(bounds))

    local selection = GUI.Selection:new{
        text = 'Should I learn a new recipe or use one I\'ve learned before?',
        header = 'Setting up crafter',
        onConfirm = onClick('success'),
        onCancel = onClick('cancelled'),
        selectionBtnText = 'USE EXISTING',
        cancelationBtnText = 'LEARN NEW',
        bounds = bounds,
        out = win,
    }

    parallel.waitForAll(oop.getExecutables(selection))
]]

---@class Selection
---@field confirmBtnText string
---@field cancelationBtnText string
---@field onCancel fun(): nil
---@see Confirmation.default for other Selection fields
local Selection = oop.class{extends = {Confirmation}, default = {
    confirmBtnText = 'CONFIRM',
    cancelationBtnText = 'CANCEL',
    onCancel = function () --[[ no-op ]] end,
}}

function Selection:createButtons()
    local width = self.bounds[3] - self.bounds[1] + 1
    local btnWidth = 15
    local spacer = math.ceil(width * 0.15)
    local padding = math.ceil((width - (2 * btnWidth + spacer)) / 2)
    self:addElement(Button:new{
        bounds = {padding, 12, padding + btnWidth - 1, 14},
        backgroundColor = self.secondaryColor,
        text = self.cancelationBtnText,
        textColor = self.primaryColor,
        onClick = self.onCancel,
        width = btnWidth,
        x = padding,
        height = 3,
        y = 12,
    })
    local xB = width - padding - btnWidth + 2
    self:addElement(Button:new{
        bounds = {xB, 12, xB + btnWidth - 1, 14},
        backgroundColor = self.secondaryColor,
        text = self.confirmBtnText,
        textColor = self.primaryColor,
        onClick = self.onConfirm,
        width = btnWidth,
        height = 3,
        x = xB,
        y = 12,
    })
end


return {
    split = split,
    Box = Box,
    Text = Text,
    Group = Group,
    Button = Button,
    TextField = TextField,
    Selection = Selection,
    MultiSelect = MultiSelect,
    Confirmation = Confirmation,
    InteractiveGroup = InteractiveGroup,
    MultiSelectWithControls = MultiSelectWithControls,
}