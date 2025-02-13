--[[
    modules.lua
    Version: 1.0.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-11
    CC: Tweaked Version: 1.89.2
    Description: This will locate any requested dependencies and return
        their tables in the order they are listed. This will seach each
        directory within root and add it to the required path. You can
        pass a table as a list of dependencies which will only search 
        for the dependency on the current computer, or you can pass a
        a table with a key (dependency name) value (pastebin code) pairs
        and it will download the dependency if it cannot be found.

        local tableutils, CoPool = modules.loadDependencies({'tableutils', 'CoPool'})
        local oreScanner = modules.loadDependencies({['orescanner.lua'] = '0ikFU65E'})
]]

local modules = {}

---@param str string
---@return string
---@private
function modules._fsName(str)
    local suffixIndex = string.find(str, '.lua')
    if suffixIndex then str = string.sub(str, 1, suffixIndex - 1) end
    return str
end

---@param fname string
---@param dir? string
---@return string?
---@private
function modules._fsFind(fname, dir)
    dir = dir or '.'
    for _, f in pairs(fs.list(dir)) do
        local path = dir..'/'..f
        if fs.isDir(path) then
            path = modules._fsFind(fname, path)
            if path then return path end
        elseif modules._fsName(f) == fname then
            return path
        end
    end
end

---@param fname string
---@param dir? string
---@return string?
---@private
function modules._fsFindDir(fname, dir)
    dir = dir or '.'
    for _, f in pairs(fs.list(dir)) do
        local path = dir..'/'..f
        if fs.isDir(path) then
            path = modules._fsFindDir(fname, path)
            if path then return path end
        elseif modules._fsName(f) == fname then
            return dir
        end
    end
end

---@private
function modules._makeModulesDir()
    if fs.exists('./modules') then return end
    fs.makeDir('./modules')
end

---@param dependency? string
---@param ...? any
---@return ...
function modules.loadDependency(dependency, ...)
    if not dependency then return {} end
    local name = modules._fsName(dependency)
    local path = modules._fsFindDir(name)
    if not path then error('Unable to load dependency "'.. name .. '"', 2) end
    local pathPattern = ';' .. path .. '/?.lua' .. ';' .. path .. '/?'
    local exists = string.find(package.path, pathPattern, 1, true)
    if not exists then package.path = package.path .. pathPattern end
    return require(name) or {}, modules.loadDependency(...)
end

---@param dependencies table<string>|table<string,string>
---@return ...
function modules.loadDependencies(dependencies)
    if dependencies[1] ~= nil then return modules.loadDependency(table.unpack(dependencies)) end
    modules._makeModulesDir()

    local found = {}
    for dependency, pbCode in pairs(dependencies) do
        local name = modules._fsName(dependency)
        local path = modules._fsFindDir(name)
        if not path then
            shell.setDir('./modules')
            shell.execute('pastebin', 'get', pbCode, name)
            shell.setDir('.')
            path = 'modules'
         end

        local pathPattern = ';' .. path .. '/?.lua' .. ';' .. path .. '/?'
        local exists = string.find(package.path, pathPattern, 1, true)
        if not exists then package.path = package.path .. pathPattern end
        table.insert(found, require(name) or {})
    end
    return table.unpack(found)
end

return modules