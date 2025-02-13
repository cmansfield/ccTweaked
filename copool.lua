--[[
    CoPool.lua
    Version: 1.0.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-10
    CC: Tweaked Version: 1.89.2
    Description: Similar to parallel api but you can define a thead pool
        size and behavior. Thead jobs can be queued up and will be
        executed in FIFO (First In First Out) order unless the CoPool's
        behavior is set to 'prioritize_new', then newer jobs will be 
        given priority and old jobs either be deleted or asked to 
        terminate. Great for disk operations where you want the latest
        version of a file saved to disk and don't care of the previous 
        jobs complete.
]]

--[=====[
    -- This is the normal usecase that is FIFO and will
    -- run the coroutine's to completion before starting 
    -- a new coroutine
    local function test ()
        local id = tostring(coroutine.running())
        print('started ' .. id)
        os.sleep(5)
        print('ending ' .. id)
    end

    local pool = CoPool:new(2)

    -- Queue up jobs before starting the runner
    pool:add(test)
    pool:add(test)
    pool:add(test)
    pool:add(test)
    pool:add(test)
    pool:add(test)

    -- Queue up jobs after starting the runner
    local function runner ()
        while true do
            os.sleep(2)
            if not pool:add(test) then print('Unable to add job') end
        end
    end

    parallel.waitForAll(function () pool:runner() end, runner)
]=====]

--[=====[
    -- This is the prioritizes new jobs. This will allow currently running
    -- coroutines to check if they should terminate and then exit the
    -- function early if requested. It needs to be done this way because
    -- coroutines with many different yeilding operations will silently 
    -- consume the request to terminate. This way they can check when it 
    -- makes sense.
    local function test (context)
        local id = tostring(coroutine.running())
        print('started ' .. id)
        os.sleep(5)
        if context.shouldTerminate() then
            print('terminating thread '.. id)
            return
        end
        print('ending ' .. id)
    end

    -- Queue up jobs before starting the runner
    local pool = CoPool:new(2, 'prioritize_new')
    pool:add(test)
    pool:add(test)
    pool:add(test)
    pool:add(test)
    pool:add(test)
    pool:add(test)

    -- Queue up jobs after starting the runner
    local function runner ()
        for i = 1, 5, 1 do
            os.sleep(2)
            if not pool:add(test) then print('Unable to add job') end
        end
    end

    parallel.waitForAll(function () pool:runner() end, runner)
]=====]

local tableutils = require 'tableutils'

local maxQueuedJobs = 10

---@class JobStatus
---@field ACTIVE string
---@field PENDING string
---@field TERMINATE string
local JobStatus = {
    ACTIVE = 'active',
    PENDING = 'pending',
    TERMINATE = 'terminate'
}

---@class JobStatus
---@field TERMINATE_OLD_ON_NEW string
---@field RUN_AVAILABLE string
local PoolBehavior = {
    TERMINATE_OLD_ON_NEW = 'prioritize_new',
    RUN_AVAILABLE = 'normal'
}

---@class Context
---@field shouldTerminate fun(): boolean
local Context = {}

---@class Job
---@field func fun(context?: Context): nil
---@field id string
---@field co thread
---@field status string
local Job = {}

---@class CoroutinePool
---@field behavior string
---@field poolSize integer
---@field jobQueue table<Job>
---@field active boolean
local CoroutinePool = {}

---@param count? integer        The size of the coroutine pool
---@param behavior? string      The behavior of the coroutine pool
---@return CoroutinePool
function CoroutinePool:new(count, behavior)
    local init = {
        behavior = behavior or PoolBehavior.RUN_AVAILABLE,
        jobQueue = tableutils.stream({}),
        poolSize = count or 1,
        active = false
    }
    setmetatable(init, self)
    self.__index = self
    return init
end

--- Modified from parallel
---@private
function CoroutinePool:_runUntilLimit()
    local eventData, tFilters = {n = 0}, {}
    local r, ok, param
    local activeJobs = self.jobQueue.filter(function (j) return j.co end)

    while true do
        for _, job in ipairs(activeJobs) do
            r = job.co
            if tFilters[r] == nil or tFilters[r] == eventData[1] or eventData[1] == 'terminate' then
                ok, param = coroutine.resume(r, table.unpack(eventData, 1, eventData.n))
                if not ok then error(param, 0)
                else tFilters[r] = param end
            end
            if coroutine.status(r) == 'dead' then
                self.jobQueue = self.jobQueue.filter(function (j) return j.id ~= job.id end)
                return
            end
        end
        for _, job in ipairs(activeJobs) do
            r = job.co
            if r and coroutine.status(r) == 'dead' then
                self.jobQueue = self.jobQueue.filter(function (j) return j.id ~= job.id end)
                return
            end
        end
        eventData = table.pack(os.pullEventRaw())
    end
end

---@param job Job
---@return fun(): boolean
function CoroutinePool:_shouldJobTerminate(job)
    return function()
        return job.status == JobStatus.TERMINATE
    end
end

---@param job Job
---@return Context
---@private
function CoroutinePool:_createJobContext(job)
    return { shouldTerminate = self:_shouldJobTerminate(job) }
end

---@param job Job
---@private
function CoroutinePool:_createJob(job)
    if job.status ~= JobStatus.PENDING then return end
    job.co = coroutine.create(function () job.func(self:_createJobContext(job)) end)
    job.id = tostring(job.co)
    job.status = JobStatus.ACTIVE
end

---@private
function CoroutinePool:_startNextJob()
    for i, job in ipairs(self.jobQueue) do
        if i > self.poolSize then return end
        self:_createJob(job)
    end
end

---@private
function CoroutinePool:_clearJob ()
    self.jobQueue = self.jobQueue
        .filter(function (job) return job.status ~= JobStatus.DEAD end)
end

---@private
function CoroutinePool:_managePool()
    if #self.jobQueue.filter(function (job) return job.co end) == 0 then
        while true do coroutine.yield() end
    end
    self:_runUntilLimit()
end

function CoroutinePool:runner()
    local i
    self.active = true
    self.jobQueue = self.jobQueue
        .filter(function (job) return job.status ~= JobStatus.TERMINATE end)

    for l = 1, math.min(self.poolSize, #self.jobQueue) do
        self:_createJob(self.jobQueue[l])
    end

    while true do
        i = parallel.waitForAny(
            function () os.pullEvent('add_to_pool') end,
            function () self:_managePool() end)
        if i == 1 then self:_startNextJob()
        elseif i == 2 then
            self:_startNextJob()
        end
    end
end

---@param func fun(...): nil
---@return boolean
function CoroutinePool:add(func)
    if #self.jobQueue >= maxQueuedJobs then return false end
    table.insert(self.jobQueue, { func = function (context) return func(context) end, id = '', co = nil, status = JobStatus.PENDING })
    if self.active then os.queueEvent('add_to_pool') end
    if self.behavior == PoolBehavior.TERMINATE_OLD_ON_NEW then
        for i = 1, #self.jobQueue - self.poolSize do
            self.jobQueue[i].status = JobStatus.TERMINATE
        end
        if self.active then os.queueEvent('update_jobs') end
    end
    return true
end

return CoroutinePool, PoolBehavior