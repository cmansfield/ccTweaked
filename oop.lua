--[[
    oop.lua
    Version: 0.4.4
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-21
    CC: Tweaked Version: 1.89.2
    Description: This library is used to bring object oriented programming to LUA tables
        You can define classes with default values and behavior, instanciate a class with 
        overriding values, and create sub-classes that inherit all of the values and 
        functions of their parent classes. Multiple parent classes can be defined for a 
        sub-class.
]]


--[=====[ Sample usage
    local oop = require 'oop'

    local Teacher = {default = {subject = 'Algebra'}}
    function Teacher:new(subject)
        Teacher.__index = Teacher
        local obj = { subject = subject or Teacher.default.subject }
        setmetatable(obj, Teacher)
        return obj
    end

    function Teacher:getSubject()
        return self.subject
    end

    local Student = oop.class{}
    --[[ Same as the single line above
        local Student = {}
        function Student:new(class)
            Student.__index = Student
            local obj = { class = class or '' }
            setmetatable(obj, Student)
            return obj
        end
    ]]

    function Student:getClass()
        return self.class
    end

    local TeacherAssistant = oop.class{default = {subject = 'Math'}, extends = { Teacher, Student }}
    local ta = TeacherAssistant:new{subject = 'History', class = 'Art'}
    print(ta:getSubject())  -- History
    print(ta:getClass())    -- Art

    ta = TeacherAssistant:new{class = 'English'}
    print(ta:getSubject())  -- Math
    print(ta:getClass())    -- English

    TeacherAssistant = oop.class{extends = { Teacher, Student }}
    ta = TeacherAssistant:new{class = 'English'}
    print(ta:getSubject())  -- Algebra
    print(ta:getClass())    -- English
]=====]


--[=====[ Multi-inheritance example
    local oop = require 'oop'

    local A = oop.class{default = {value = 'A'}}
    function A:getValue()
        return self.value .. '1'
    end
    local B = oop.class{extends = {A}, default = {value = 'B'}}
    function B:getValue()
        return self.value .. '2'
    end
    local C = oop.class{extends = {A}, default = {value = 'C'}}
    function C:getValue()
        return self.value .. '3'
    end
    local D = oop.class{extends = {B, C}, default = {value = 'D'}}

    local instance = D:new{}
    print(instance:getValue())  -- D2
    -- It injects its default value and then searches for the 'getValue' method.
    -- it cannot find it in the D metetable so it then goes up its inheritance 
    -- tree, it then finds the method in the B class and uses that. Since the
    -- table of 'instance' is passed in as 'self', when it runs B:getValue it 
    -- returns 'D2'. It picks the method in the B class before checking C, 
    -- becausue that's the inheritance order. 
]=====]

local tableutils = require 'tableutils'

---@param t table
---@return table
local function copy(t)
    local nt = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then nt[k] = copy(v) else nt[k] = v end
    end
    return nt
end

---@param t1 table<any>
---@param t2 table<any>
local function union(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == 'table' then t1[k] = copy(v)
        else t1[k] = v end
    end
end

---@class InheritanceTable
---@field extends table<table>
---@field __index table<table>
---@field new fun(self: table, init?: table): table<any>
local InheritanceTable

---@class oop
---@field class fun(t: table<any>): table<any>
local oop = {}

---@param t table<any>
---@return table<any>
function oop.class(t)
    t.extends = t.extends or {}
    t.default = t.default or {}
    function t:new(init)
        local obj = {}
        t.__index = t
        setmetatable(t, {
          __index =
            function (_, k)
                for _, clazz in ipairs(t.extends) do
                    if rawget(clazz, k) then return rawget(clazz, k) end
                end
                for _, clazz in ipairs(t.extends) do
                    if getmetatable(clazz).__index(_, k) then
                        return getmetatable(clazz).__index(_, k)
                    end
                end
            end
        })

        for _, clazz in ipairs(t.extends) do
          union(obj, clazz:new())
        end
         -- Passed in values should override the parent class' values
        union(obj, t.default)
        union(obj, init or {})
        setmetatable(obj, t)
        return obj
    end
    return t
end


--[=====[
    local runnable = oop.Runnable:new{}
    parallel.waitForAll(getExecutables(runnable))
]=====]

---@class Runnable
---@field initialize fun(self: Runnable): nil
---@field yieldAction fun(self: Runnable): table?
---@field run fun(self: Runnable, ...?: any): nil
---@field executor fun(self: Runnable): fun(): nil
local Runnable = oop.class{}

function Runnable:initialize()
    -- setup
end

---@return table?
function Runnable:yieldAction()
    sleep(0)
end

local count = 0
---@param ...? any
---@diagnostic disable-next-line: redundant-parameter
function Runnable:run(...)
    print('Runnable is running ... ' .. count)
    count = count + 1
end

---@return table<fun(): nil>
function Runnable:executor()
    local f = function ()
        local yRet = {}
        self:initialize()
        while true do
            ---@diagnostic disable-next-line: redundant-parameter
            self:run(table.unpack(yRet))
            yRet = self:yieldAction() or {}
        end
    end
    return {f}
end

oop.Runnable = Runnable
oop.getExecutables = function (...)
    local elems = table.pack(...)
    elems.n = nil       -- Packed '...' come with a field 'n'
    local jobs = tableutils.stream(elems)
        .map(function (elem) return elem:executor() end)
        .reduce(function (acc, ex) tableutils.append(acc, ex) return acc end, {})
    return table.unpack(tableutils.stream(jobs).filter(function (j) return j end))
end

return oop