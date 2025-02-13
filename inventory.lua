--[[
    CoPool.lua
    Version: 0.7.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-10
    CC: Tweaked Version: 1.89.2
    Description: This will find and catalog any container attached to
        wired modems. The container name supplied in 'transferType' 
        will label any container with that name as a transfer container.
        Usually a chest that sits right next to the computer. When 
        requesting items from the indexed inventory, those items will
        be placed into the transfer container. Any items in the 
        transfer container when 'store' is called will move those item
        into inventory. This is the main driver for the InventoryManager.lua 
        script
]]

local tableutils = require 'tableutils'
local config = require 'config'
local CoPool = require 'copool'

local Inventory = {}

---@param transferType? string              The name of the container the player should interact with
---@param indexCompleteCallback? function   A function to be called when indexing and saving the index is complete
---@retun Inventory
---@nodiscard
function Inventory:new(transferType, indexCompleteCallback)
    local init = {
        transferType = transferType or 'ironchest_diamond',
        indexCompleteCallback = indexCompleteCallback,
        pool = CoPool:new(1, 'prioritize_new'),
        transferContainerNames = {},
        transferIndex = {},
        jobIds = {},
        index = {},
        inv = {}
    }
    setmetatable(init, self)
    self.__index = self

    init:_loadIndex()
    init:_indexTransferContainers()

    return init
end

function Inventory:runner()
    return self.pool:runner()
end

function Inventory:_saveIndex(logOnComplete)
    if logOnComplete == nil then logOnComplete = true end
    config.save('inventory_config', self.index)
    if logOnComplete and self.indexCompleteCallback then self.indexCompleteCallback() end
end

function Inventory:_loadIndex()
    if self.index and #self.index > 0 then return end
    self.index = config.load('inventory_config')
    if not self.index then self:_index() end
end

---@return string
function Inventory:_getTransferTypePattern()
    return 'minecraft:' .. self.transferType .. '.*'
end

-- This doesn't work because chests wrapped on the side of a computer
-- cannot transfer items to chests on a wired network
---@deprecated
function Inventory:_getTransferContainerSides()
    return tableutils.stream(redstone.getSides())
        .filter(function (s) return peripheral.getType(s) end)
        .filter(function (s) return string.find(peripheral.getType(s), '^minecraft:.*chest.*') end)
end

---@deprecated
function Inventory:_getTransferContainers()
    return tableutils.stream(peripheral.getNames())
        .filter(function (name) return string.match(name, self:_getTransferTypePattern()) end)
        .map(function (s)
                local p = peripheral.wrap(s)
                local meta = p.getMetadata()
                return {name = meta.name, slotCount = p.size(), peripheral = p}
            end
        )
end

function Inventory:_getTransferNames()
    local sides = tableutils.stream(redstone.getSides())
    return tableutils.stream(peripheral.getNames())
        .filter(function (name) return string.match(name, self:_getTransferTypePattern()) end)
        .filter(function (n) return not sides.anyMatch(function (s) return n == s end) end)
end

function Inventory:_getStorageNames()
    local sides = tableutils.stream(redstone.getSides())
    return tableutils.stream(peripheral.getNames())
        .filter(function (name) return not string.match(name, self:_getTransferTypePattern()) end)
        .filter(function (n) return not sides.anyMatch(function (s) return n == s end) end)
end

function Inventory:_indexContainers(containers, out)
    for cName, cInv in pairs(containers) do
        for slot, item in pairs(cInv) do
            if out[item.name] then
                if out[item.name][cName] then
                    local found = out[item.name][cName]
                    table.insert(found.slots, {slot = slot, count = item.count})
                    found.count = found.count + item.count
                else
                    out[item.name][cName] = {
                        slots = {{slot = slot, count = item.count}},
                        count = item.count
                    }
                end
            else
                out[item.name] = {
                    [cName] = {
                        slots = {{slot = slot, count = item.count}},
                        count = item.count
                    }
                }
            end
        end
    end
end

function Inventory:_indexTransferContainers()
    self.transferIndex = tableutils.stream({})
    self.transferContainerNames = self:_getTransferNames()
    local transfers = self.transferContainerNames
        .map(function (name) return {name = name, inventory = peripheral.call(name, 'list')} end)
        .reduce(function (acc, v)
                acc[v.name] = v.inventory
                return acc
            end,
        {})

    self:_indexContainers(transfers, self.transferIndex)
end

function Inventory:_index(context)
    self.index = tableutils.stream({})
    local storage = self:_getStorageNames()
        .map(function (name) return {name = name, inventory = peripheral.call(name, 'list')} end)
        .reduce(function (acc, v)
                acc[v.name] = v.inventory
                return acc
            end,
        {})

    -- If thread job, see if we should terminate the indexing action before completion
    if context and context.shouldTerminate() then
        return
    end

    self:_indexContainers(storage, self.index)

    -- If thread job, see if we should terminate the indexing action before completion
    if context and context.shouldTerminate() then
        return
    end

    self:_saveIndex()
end

function Inventory:_parseName(name)
    name = string.gsub(name, '_', ' ')
    local startIndex, endIndex = string.find(name, ':(.*)$')
    if not startIndex then return name end
    return string.sub(name, startIndex + 1, endIndex)
end

function Inventory:_move(to, from, quantity, toMeta, fromMeta)
    if quantity <= 0 then return 0, toMeta end

    toMeta = toMeta or {slots = {}}
    local activeSlot = tableutils.stream(fromMeta.slots)
        .find(function (s) return s.count > 0 end)
    local itemMeta = peripheral.call(from, 'getItemMeta', activeSlot.slot)
    local maxCount = itemMeta.maxCount
    local priorityToSlots = tableutils.stream(toMeta.slots)
        .filter(function (s) return s.count < maxCount end)
    local tIndex, tSlot = next(priorityToSlots)
    local fIndex, fSlot = next(fromMeta.slots)
    if not fSlot then return quantity, toMeta end

    while tSlot and fSlot do
        local d = math.min(maxCount - tSlot.count, quantity, fSlot.count)
        if d > 0 then
            peripheral.call(to, 'pullItems', from, fSlot.slot, d, tSlot.slot)
            quantity = quantity - d
            tSlot.count = tSlot.count + d
            fSlot.count = fSlot.count - d
            if quantity <= 0 then return 0, toMeta end
        end
        if fSlot.count <= 0 then fIndex, fSlot = next(fromMeta.slots, fIndex) end
        if tSlot.count >= maxCount then tIndex, tSlot = next(priorityToSlots, tIndex) end
    end

    if not fSlot then return quantity, toMeta end
    local toSize = peripheral.call(to, 'size')
    local toList = peripheral.call(to, 'list')

    local availableSlots = tableutils.range(toSize)
        .filter(function (slot) return toList[slot] == nil end)
        .map(function (slot) return {slot = slot, count = 0} end)
    tIndex, tSlot = next(availableSlots)

    while tSlot and fSlot do
        local d = math.min(maxCount - tSlot.count, quantity, fSlot.count)
        if d > 0 then
            peripheral.call(to, 'pullItems', from, fSlot.slot, d, tSlot.slot)
            quantity = quantity - d
            tSlot.count = tSlot.count + d
            fSlot.count = fSlot.count - d
            if quantity <= 0 then return 0, toMeta end
        end
        if fSlot.count <= 0 then fIndex, fSlot = next(fromMeta.slots, fIndex) end
        if tSlot.count >= maxCount then tIndex, tSlot = next(availableSlots, tIndex) end
    end

    tableutils.append(toMeta.slots, availableSlots)

    return quantity, toMeta
end

function Inventory:_updateIndex(indexToUpdate, itemName)
    local filtered = {}
    local containers = indexToUpdate[itemName]
    for containerName, container in pairs(containers) do
        local filteredSlots = tableutils.stream(container.slots)
            .filter(function (s) return s.count > 0 end)
        container.count = filteredSlots
            .reduce(function (acc, s) return acc + s.count end, 0)
        if container.count > 0 and #filteredSlots > 0 then
            container.slots = filteredSlots
            filtered[containerName] = container
        end
    end

    indexToUpdate[itemName] = not tableutils.isEmpty(filtered) and filtered or nil
end

function Inventory:getAll()
    local items = {}

    for k, v in pairs(self.index) do
        local count = tableutils.stream(v).reduce(function (acc, _, c) return acc + c.count end, 0)
        table.insert(items, {name = k, display = self:_parseName(k), count = count})
    end

    table.sort(items, function (a, b) return a.name < b.name end)
    return items
end

function Inventory:store()
    if #self.jobIds > 0 then return end

    self:_indexTransferContainers()

    for item, iTable in pairs(self.transferIndex) do
        for from, fromMeta in pairs(iTable) do
            local tContainers = tableutils.stream(self.index[item.name] or {})
            for to, toMeta in pairs(tContainers) do
                local a, _ = self:_move(to, from, fromMeta.count, toMeta, fromMeta)
                fromMeta.count = a
            end
            if fromMeta.count <= 0 then break end

            tContainers = self:_getStorageNames()
                .filter(function (c) return not tContainers.anyMatch(function (n, _) return n == c end) end)
            for _, to in ipairs(tContainers) do
                local a, _ = self:_move(to, from, fromMeta.count, nil, fromMeta)
                fromMeta.count = a
                if a <= 0 then break end
            end
        end
    end

    self.transferIndex = tableutils.stream({})
    self.pool:add(function (context) self:_index(context) end)
end

function Inventory:isTranferChestEmpty()
    return not self.transferContainerNames
        .anyMatch(function (name) return not tableutils.isEmpty(peripheral.call(name, 'list')) end)
end

function Inventory:retrieve(item, quantity)
    self:_indexTransferContainers()
    local tContainers = tableutils.stream(self.transferIndex[item] or {})
    local storageContainers = self.index[item]

    for _, to in pairs(self.transferContainerNames) do
        local toMeta = tContainers
            .find(function (name, _) return name == to end)

        for from, fromMeta in pairs(storageContainers) do
            quantity, toMeta = self:_move(to, from, quantity, toMeta, fromMeta)
            tContainers[to] = toMeta
        end
    end

    self.transferIndex[item] = tContainers
    self:_updateIndex(self.transferIndex, item)
    self:_updateIndex(self.index, item)
    self.pool:add(function () self:_saveIndex(false) end)
end

return Inventory