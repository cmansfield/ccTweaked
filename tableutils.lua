--[[
    tableutils.lua
    Version: 0.5.2
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-10
    CC: Tweaked Version: 1.89.2
    Description: A collection of table utils to help with navigating, modifying,
        or displaying lua tables. The most important thing gained by using these
        utility functions, is it greatly reduces nesting blocks. It's not complete 
        or perfect but it saves me time and nested code.
        tableutils.stream() does not actually create a stream or a generator
        function. It's more of a naming convention since I come from a java
        background, and it will embed the supplied table with many functional 
        programming functions (filter, map, anyMatch, reduce, ect..).
        Any derived table from one of these functional programming functions will
        all ready have these same functions embedded, this will allow function 
        chaining.

        local t = {1, 2, 3, 4}
        local sum = tableutils.stream(t)                            -- sum = 16
            .filter(function (v) return v % 2 == 0 end)             -- create a table with only even values
            .map(function (v) return v + 5 end)                     -- add 5 to each of the remaining values
            .reduce(function (acc, v) return acc + values end, 0)   -- add all of the values together
]]

local tableutils = {}

function tableutils.printTable(t, indentation)
    for k, v in pairs(t) do
        local i = indentation or 0
        if type(v) == 'table' then
            print(string.rep(' ', i) .. k .. ':')
            tableutils.printTable(v, i + 2)
        elseif type(v) == 'thread' then print(string.rep(' ', i) .. k .. ': ' .. tostring(v))
        elseif type(v) == 'boolean' then print(string.rep(' ', i) .. k .. ': ' .. (v and 'true' or 'false'))
        else
            print(string.rep(' ', i) .. k .. ': ' .. (type(v) == 'function' and 'function' or v))
        end
    end
end

function tableutils.printTableTop(t)
    for k, v in pairs(t) do
        local s = (type(v) == 'table' and 'table')
            or (type(v) == 'function' and 'function')
            or (type(v) == 'thread' and tostring(v))
            or (type(v) == 'boolean' and 'true' or 'false')
            or v
        print(k .. ': ' .. s)
    end
end

function tableutils.printTableKeys(t)
    for k, _ in pairs(t) do
        print(k)
    end
end

---@generic T, V
---@param limit integer
---@param modifier? fun(i: integer): T
---@return table<T>
function tableutils.range(limit, modifier)
    local t = tableutils.stream({})
    for i = 1, limit do table.insert(t, modifier and modifier(i) or i) end
    return t
end

---@param t1 table
---@param t2 table
---@return nil
function tableutils.append(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + i] = t2[i]
    end
end

---@param t table
---@return boolean
function tableutils.isEmpty(t)
    return next(t) == nil
end

---@param t table
---@return boolean
function tableutils.isDict(t)
    return t[1] == nil
end

---@param t table
---@return boolean
function tableutils.isList(t)
    return t[1] ~= nil
end

---@generic v
---@param t table<v>
---@param i integer
---@param k? integer
---@return table<v>
function tableutils.sub(t, i, k)
    if tableutils.isDict(t) then return t end
    if not k then k = #t end
    local r = {}
    for l = i, k do
        table.insert(r, t[l])
    end
    return r
end

---@param t table
---@return table
function tableutils.reverse(t)
    if tableutils.isDict(t) then return t end
    local r, k = {}, 1
    for i = #t, 1, -1 do
        r[k] = t[i]
        k = k + 1
    end
    return r
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local result = tableUtils.stream(list)
        .allMatch(function (v) return v <= 3 end)

    local result = tableUtils.stream(dict)
        .allMatch(function (_, age) return age < 30 end)
]=====]
---@generic T
---@param t table<integer,T>|table<T>
---@param func (fun(i: integer, v: T): boolean)|(fun(v: T): boolean)
---@return boolean
function tableutils.allMatch(t, func)
    local all = true
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        if isDict then
            all = func(k, v) and all
        else
            all = func(v) and all
        end

        if not all then return false end
    end
    return true
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local result = tableUtils.stream(list)
        .anyMatch(function (v) return v == 2 end)

    local result = tableUtils.stream(dict)
        .anyMatch(function (_, age) return age > 25 end)
]=====]
---@generic T
---@param t table<integer,any>|table<T>
---@param func (fun(i: integer, v: T): boolean)|(fun(v: T): boolean)
---@return boolean
function tableutils.anyMatch(t, func)
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        if isDict then
            if func(k, v) then return true end
        else
            if func(v) then return true end
        end
    end
    return false
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local firstOdd = tableUtils.stream(list)
        .findFirst(function (v) return v % 2 ~= 0 end)

    local result = tableUtils.stream(dict)
        .findFirst(function (name, age) return name == 'John' end)
]=====]
---@generic T
---@param t table<integer,T>|table<T>
---@param func (fun(i: integer, v: T): T)|(fun(v: T): T)
---@return T
function tableutils.findFirst(t, func)
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        if isDict then
            if func(k, v) then return v end
        else
            if func(v) then return v end
        end
    end
    return nil
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local evens = tableUtils.stream(list)
        .filter(function (v) return v % 2 == 0 end)

    local result = tableUtils.stream(dict)
        .filter(function (_, age) return age <= 25 end)
]=====]
---@generic T
---@param t table<integer,T>|table<T>
---@param func (fun(i: integer, v: T): T)|(fun(v: T): T)
---@return table<integer,T>|table<T>
function tableutils.filter(t, func)
    local filtered = {}
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        if isDict then
            if func(k, v) then filtered[k] = v end
        else
            if func(v) then table.insert(filtered, v) end
        end
    end
    return filtered
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local result = tableUtils.stream(list)
        .map(function (i) return i + 5 end)

    local names = tableUtils.stream(dict)
        .map(function (name, age) return name end)
]=====]
---@generic T
---@param t table<integer,T>|table<T>
---@param func (fun(i: integer, v: T): T)|(fun(v: T): T)
---@return table<any,any>|table<any>
function tableutils.map(t, func)
    local mapped = {}
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        table.insert(mapped, isDict and func(k, v) or func(v))
    end
    return mapped
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local sum = tableUtils.stream(list)
        .reduce(function (acc, v) return acc + v end, 10)

    local result = tableUtils.stream(dict)
        .reduce(function (acc, name, age)
                table.insert(acc.names, name)
                acc.totalAge = acc.totalAge + age
                return acc
            end,
            {names = {}, totalAge = 0}
        )
]=====]
---@generic T, K
---@param t table<integer,T>|table<T>
---@param func (fun(acc: K, i: integer, v: T): K)|(fun(acc: K, v: T): K)
---@return any
function tableutils.reduce(t, func, acc)
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        acc = isDict and func(acc, k, v) or func(acc, v)
    end
    return acc
end

--[=====[
    local list = {1, 2, 3, 4}
    local dict = {John = 23, Jane = 27}

    local result = tableUtils.stream(list)
        .find(function (v) return v == 3 end)

    local result = tableUtils.stream(dict)
        .find(function (name, age) return name == 'Jane' end)
]=====]
---@generic T
---@param t table<integer,T>|table<T>
---@param func (fun(i: integer, v: T): T)|(fun(v: T): T)
---@return T?
function tableutils.find(t, func)
    local isDict = tableutils.isDict(t)
    for k, v in pairs(t) do
        if isDict then
            if func(k, v) then return v end
        else
            if func(v) then return v end
        end
    end
end

function tableutils.stream(t)
    t = t or {}
    setmetatable(t, {
        __index = {
            find =      function (obj) return tableutils.find(t, obj) end,
            map =       function (func) return tableutils.stream(tableutils.map(t, func)) end,
            filter =    function (func) return tableutils.stream(tableutils.filter(t, func)) end,
            findFirst = function (func) return tableutils.findFirst(t, func) end,
            allMatch =  function (func) return tableutils.allMatch(t, func) end,
            anyMatch =  function (func) return tableutils.anyMatch(t, func) end,
            reduce =    function (func, acc) return tableutils.reduce(t, func, acc) end
        }
    })
    return t
end

return tableutils