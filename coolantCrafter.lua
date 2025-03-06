
local tableutils = require 'tableutils'
local config = require 'config'

local containerNames = tableutils.stream({
    'chest',
    'storage',
    'condenser',
})

local coolantRecipe = {
    ['item.itemIngotTin'] = {
        slots = { 1 },
        quantity = 64,
    },
}

local thirtyRecipe = {
    ['item.itemIngotTin'] = {
        slots = { 1 },
        quantity = 64,
    },
    ['item.reactorCoolantSimple'] = {
        slots = { 2, 3, 4, 5, 6, 7, 8, 9 },
        quantity = 1,
    }
}

local sixtyRecipe = {
    ['item.itemIngotTin'] = {
        slots = { 1 },
        quantity = 64,
    },
    ['item.reactorCoolantTriple'] = {
        slots = { 2, 3, 4, 5, 6, 7, 8 },
        quantity = 1,
    },
    ['item.itemPartDCP'] = {
        slots = { 9 },
        quantity = 64,
    }
}

local requiredWorkbenches = {
    ['60k Coolant Cell'] = sixtyRecipe,
    ['30k Coolant Cell'] = thirtyRecipe,
    ['10k Coolant Cell'] = coolantRecipe,
}

local function getOutput(name)
    local itemMeta = peripheral.call(name, 'getItemMeta', 10)
    if not itemMeta then return end
    return itemMeta.displayName, itemMeta.rawName
end

local function contains(name)
    local list = peripheral.call(name, 'list')
    if not list or not #list then return end
    for i, _ in pairs(list) do
        local meta = peripheral.call(name, 'getItemMeta', i)
        if meta and meta.rawName then return meta.rawName end
    end
end

local function isContainerFilter(name)
    return containerNames.anyMatch(function (c) return name:find(c) end)
end

local peripheralNames = tableutils.stream(peripheral.getNames())
local function loadWorkbenches()
    local workbenchConfig = config.load('coolant_config')
    if workbenchConfig then return tableutils.stream(workbenchConfig) end
    return peripheralNames
        .filter(function(name) return name:find('autoworkbench') end)
        .map(function(name)
                local display, output = getOutput(name)
                return {name = name, output = output, display = display}
            end
        ).map(function(wb) wb.recipe = requiredWorkbenches[wb.display] return wb end)
end

local function loadContainers()
    local containerConfig = config.load('containers')
    if containerConfig then return tableutils.stream(containerConfig) end
    return peripheralNames
        .filter(isContainerFilter)
        .map(function(name)
                return {name = name, size = peripheral.call(name, 'size'), contains = contains(name)}
            end
        )
end

local workbenches = loadWorkbenches()
local containers = loadContainers()

local sources = tableutils.copy(containers)
local wbSources = workbenches
    .map(function (wb) return {name = wb.name, size = 1, contains = wb.output, slot = 10} end)

for _, value in pairs(wbSources) do
    table.insert(sources, value)
end

local function transferItem(from, to, slots, fSlot, quantity)
    local tIndex, tSlot = next(slots)
    local r = 0
    repeat
        r = peripheral.call(from, 'pushItems', to, fSlot, quantity, tSlot)
        tIndex, tSlot = next(slots, tIndex)
    until not tIndex or r > 0
    return r
end

local function run(workbench)
    return function ()
        while true do
            for ingredient, meta in pairs(workbench.recipe) do
                local fromObj = tableutils.stream(sources)
                    .findFirst(function (s) return s.contains == ingredient end)
                if fromObj.slot then
                    transferItem(fromObj.name, workbench.name, meta.slots, fromObj.slot, meta.quantity)
                else
                    local list = peripheral.call(fromObj.name, 'list')
                    for fSlot, _ in pairs(list) do
                        transferItem(fromObj.name, workbench.name, meta.slots, fSlot, meta.quantity)
                        break
                    end
                end
            end
            sleep(1)
        end
    end
end

local function storeProduct()
    local fromObj = tableutils.stream(workbenches)
        .findFirst(function (s) return s.output == 'item.reactorCoolantSix' end)
    local toObj = tableutils.stream(sources)
        .filter(function (s) return containerNames.anyMatch(function (c) return s.name:find(c) end) end)
        .findFirst(function (s) return s.contains == 'item.reactorCoolantSix' end)
    if not toObj then
        toObj = tableutils.stream(sources)
            .filter(function (s) return containerNames.anyMatch(function (c) return s.name:find(c) end) end)
            .findFirst(function (s) return not s.contains end)
    end
    local from = peripheral.wrap(fromObj.name)

    return function ()
        while true do
            local list = peripheral.call(toObj.name, 'list')
            local tSlot = 1
            for i = 1, toObj.size do
                if not list[i] then
                    tSlot = i
                    break
                end
            end
            from.pushItems(toObj.name, 10, 1, tSlot)
            sleep(1)
        end
    end
end

local requiredRecipes = tableutils.stream(requiredWorkbenches)
    .reduce(function (acc, _, recipe) tableutils.union(acc, recipe) return acc end, tableutils.stream({}))
    .map(function (name, _) return name end)
sources = tableutils.stream(sources)
local notFound = requiredRecipes
    .filter(function (rr) return not sources.anyMatch(function (s) return s.contains == rr end) end)

if #workbenches < #requiredWorkbenches or #notFound > 0 then
    tableutils.stream(requiredWorkbenches)
        .map(function (k, _) return k end)
        .filter(function (d)
                return not tableutils.stream(workbenches)
                    .anyMatch(function (wb) return wb.display == d end)
            end
        ).forEach(function (d) print('Could not find a workbench that makes ' .. d) end)
    notFound.forEach(function (rr) print('Could not find a container for ' .. rr) end)
    os.exit()
end

term.clear()
term.setCursorPos(1, 1)

config.save('coolant_config', workbenches)
config.save('containers', containers)

local function packageJobs()
    local a = workbenches.map(function (wb) return run(wb) end)
    table.insert(a, storeProduct())
    return table.unpack(a)
end

parallel.waitForAny(packageJobs())