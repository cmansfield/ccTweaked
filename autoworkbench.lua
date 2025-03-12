--[[
    autoworkbench.lua
    Version: 0.9.6
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-03-11
    CC: Tweaked Version: 1.89.2
    Description: I made this program after Bounsed asked me how to transfer an item from
        an autoworkbench to another, and I wasn't exactly sure. From that conversation I
        created this auto crafting bot. It will scan for any containers or workbenches
        connected to the computer with modems, detect their contents and learn recipes.

            Setup: Place any condenser / chest / black hole with any basic ingredients.
        Place any number of 'Auto Workbenches and completely fill them with the required
        ingredients for the craft you want completed. This should craft at least one of
        the item you want crafted. Place modems next to each container and workbench in
        the network, and turn on the modems. WARNING: do not place more than one modem
        next to a single container / workbench, this will break the program. With both 
        of the workbench's inputs and output filled you can now learn recipes, startup 
        the program and click the 'LEARN NEW' button. This will scan the Auto Workbenches
        for recipes you want to craft. 

            Workbench chaining: The program treats workbenches as an item 'source' that
        means you can place workbenches that craft an ingredient required for a more
        advanced craft. For example, I can place 4 '10k Coolant Cell' workbenches,
        3 '30k Coolant Cell' workbenches, and 2 '60k Coolant Cell' workbenches and then 
        store the output.

            Faster crafting: Remember, you can speed up the Auto Workbenches by 
        attachingwith flux power to them.
]]

local tableutils = require 'tableutils'
local config = require 'config'
local GUI = require 'gui'
local oop = require 'oop'

-- Add to this list if you run into something that is not destroyed when crafting
local nonConsumableItems = {
    'item.pe_evertide_amulet'
}

local currentJob = {}
local breakout = false
local indexedSources = {}
local cookbook = {recipes = {}}
local containerTypes = tableutils.stream({
    {
        name = 'autoworkbench',
        startSlot = 10,
        size = 1,
    },
    {
        name = 'black_hole_unit',
        startSlot = 1,
        size = 1,
    },
    {
        name = 'condenser_mk2',
        startSlot = 43,
        size = 42,
    },
    {
        name = 'condenser',
        startSlot = 1,
    },
    {
        name = 'chest',
        startSlot = 1,
    },
})

local function deleteCurrentJob()
    fs.delete('configs/current_job')
end

local function packageElements(...)
    breakout = false
    local tPack = table.pack(...)
    return function () parallel.waitForAll(oop.getExecutables(table.unpack(tPack))) end,
        function () while not breakout do sleep(0.1) end end
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
            for ingredient, meta in pairs(workbench.recipe.ingredients) do
                local fromObjs = indexedSources
                    .filter(function (s) return s.contains.rawName == ingredient end)
                for _, fromObj in ipairs(fromObjs) do
                    local list = peripheral.call(fromObj.name, 'list')
                    for i = fromObj.startSlot, fromObj.startSlot + fromObj.size - 1 do
                        if list[i] then
                            transferItem(fromObj.name, workbench.name, meta.slots, i, meta.quantity)
                            break
                        end
                    end
                end
            end
            sleep(1)
        end
    end
end

local function storeProduct(workbenches, outputProduct)
    local fromObjs = tableutils.stream(workbenches)
        .filter(function (s) return s.recipe.displayName == outputProduct end)
        .map(function (s) return peripheral.wrap(s.name) end)
    local toObj = tableutils.stream(indexedSources)
        .filter(function (s) return s.name:find('chest') or s.name:find('black_hole_unit') end)
        .findFirst(function (s) return s.contains.displayName == outputProduct end)
    if not toObj then
        toObj = tableutils.stream(indexedSources)
            .filter(function (s) return s.name:find('chest') or s.name:find('black_hole_unit') end)
            .findFirst(function (s) return not s.contains.rawName end)
    end

    if not toObj then
        term.redirect(term.native())
        term.clear()
        term.setCursorPos(1,3)
        print('No chest available to store ' .. outputProduct)
        print()
        deleteCurrentJob()
        os.exit()
    end

    return function ()
        while true do
            for _, from in ipairs(fromObjs) do
                local itemMeta = from.getItemMeta(10)
                local r = 0

                if itemMeta then
                    for i = 1, toObj.size do
                        r = r + from.pushItems(toObj.name, 10, itemMeta.count, i)
                        if r >= itemMeta.count then break end
                    end
                end
            end
            sleep(1)
        end
    end
end

local function packageVarargJobs(t, job, ...)
    if not job then return end
    table.insert(t, job)
    packageVarargJobs(t, ...)
end

local function packageJobs(workbenches, outputProduct, ...)
    local a = tableutils.stream(workbenches).map(function (wb) return run(wb) end)
    table.insert(a, storeProduct(workbenches, outputProduct))
    packageVarargJobs(a, ...)
    return table.unpack(a)
end

local function isContainer(name)
    return containerTypes.anyMatch(function (c) return name:find(c.name) end)
end

local function contains(name, type)
    local list = peripheral.call(name, 'list')
    if not list or not #list then return end
    for i = type.startSlot, type.startSlot + type.size - 1 do
        local meta = peripheral.call(name, 'getItemMeta', i)
        if meta then
            return {
                displayName = meta.displayName,
                rawName = meta.rawName,
            }
        end
    end
end

local function createSource(name)
    local type = containerTypes.findFirst(function (t) return name:find(t.name) end)
    type.size = type.size or peripheral.call(name, 'size')

    return {
        contains = contains(name, type) or {},
        startSlot = type.startSlot,
        size = type.size,
        name = name,
    }
end

local function loadConfigs()
    cookbook = tableutils.stream(config.load('cookbook') or cookbook)
    cookbook.recipes = tableutils.stream(cookbook.recipes)
    indexedSources = tableutils.stream(config.load('sources') or indexedSources)
    currentJob = config.load('current_job' or currentJob)
end

---@param header string
---@param text string
---@param includeHomeButton? boolean
local function displayLoadingScreen(header, text, includeHomeButton)
    term.redirect(term.native())
    term.clear()
    term.setCursorPos(1, 1)
    local x, y = term.getSize()
    local bounds = {1, 1, x, y}
    local width, height = x, y

    local group = GUI.Group:new{
        out = term.current(),
        bounds = bounds,
    }
    group:addElement(GUI.Box:new{
        backgroundColor = colors.gray,
        height = height,
        width = width,
    })
    if includeHomeButton then
        group:addElement(GUI.Button:new{
            onClick = function () breakout = true end,
            backgroundColor = colors.gray,
            textColor = colors.orange,
            bounds = {2, 2, 8, 2},
            text = '< home ',
            height = 1,
            width = 7,
            x = 2,
            y = 2,
        })
    end
    group:addElement(GUI.Text:new{
        text = header,
        backgroundColor = colors.orange,
        textColor = colors.gray,
        width =  width,
        height = 3,
    })
    group:addElement(GUI.Box:new{
        backgroundColor = colors.gray,
        width =  width,
        height = height - 3,
        x = 1,
        y = 4,
    })

    local maxCharCount = math.floor(width - (width * 0.2))
    local rows = GUI.split(text, maxCharCount)
    for i, rowText in ipairs(rows) do
        group:addElement(GUI.Text:new{
            backgroundColor = colors.gray,
            textColor = colors.orange,
            text = rowText,
            width =  width,
            height = 1,
            x = 1,
            y = 5 + i
        })
    end

    group:render()

    return group
end

local function displayConfirmation(header, text)
    term.redirect(term.native())
    term.clear()
    term.setCursorPos(1, 1)
    local x, y = term.getSize()
    local bounds = {1, 1, x, y}

    local selection = GUI.Confirmation:new{
        onConfirm = function () breakout = true end,
        out = term.current(),
        header = header,
        bounds = bounds,
        text = text,
    }

    parallel.waitForAny(packageElements(selection))
end

local function startJobs(workbenches, outputProduct)
    local displayElement = displayLoadingScreen('Actively Crafting...', 'Currently making ' .. outputProduct, true)
    parallel.waitForAny(packageJobs(workbenches, outputProduct, packageElements(displayElement)))
    deleteCurrentJob()
end

local function refreshIndex()
    local workbenches = indexedSources
        .filter(function (s) return s.contains and s.contains.rawName and s.name:find('autoworkbench') end)
        .reduce(function (acc, s) acc[s.name] = s; return acc end, tableutils.stream{})
    indexedSources = tableutils.stream(peripheral.getNames())
        .filter(isContainer)
        .map(createSource)
        .map(function (s) return workbenches[s.name] or s end)
    config.save('sources', indexedSources)
end

local function refreshAction(displayName)
    breakout = false
    displayLoadingScreen('Indexing Containers', 'Checking all containers on the network and updating sources')
    refreshIndex()
    breakout = true
end

---@return boolean
local function canCraft(displayName, skipConfirm)
    local recipe = cookbook.recipes
        .find(function (r) return r.displayName == displayName end)
    local notFound = tableutils.stream(recipe.ingredients)
        .filter(function (n, _)
                return not indexedSources.anyMatch(function (s) return s.contains.rawName == n end)
                    and not tableutils.find(nonConsumableItems, function (i) return i == n end)
            end)
        .map(function (ing) return ing.displayName end)
        .reduce(function (acc, name) if not acc then return name else return acc .. ', ' .. name end end, nil)

    if notFound then
        displayConfirmation('Unable to Craft', 'Cannot find all of the ingredients needed for this recipe. Missing: ' .. notFound)
    elseif not skipConfirm then
        displayConfirmation('Eligible to Craft', 'All of the ingredients can be found or be crafted')
    end

    return not notFound
end

local function cleanupTable(t)
    local out = {}
    for _, value in pairs(t) do
       table.insert(out, value)
    end
    return out
end

local function beginCrafting(displayName)
    if not canCraft(displayName, true) then return end
    local autoCraftOnStart = false
    breakout = false

    local subBreakout = false
    term.redirect(term.native())
    local x, y = term.getSize()
    local selection = GUI.Selection:new{
        text = 'Would you like to automatically start crafting this item when the computer starts up?',
        header = 'Automated Crafting',
        onConfirm = function () subBreakout = true; autoCraftOnStart = true end,
        onCancel = function () subBreakout = true end,
        confirmBtnText = 'YES',
        cancelationBtnText = 'NO',
        bounds = {1, 1, x, y},
        out = term.native(),
    }
    parallel.waitForAny(
        function () parallel.waitForAll(oop.getExecutables(selection)) end,
        function () while not subBreakout do sleep(0.1) end end
    )

    displayLoadingScreen('Preparing Job', 'Processing request to craft ' .. displayName)

    refreshIndex()

    local allWorkbenches = indexedSources
        .filter(function (s) return s.name:find('autoworkbench') end)
        .map(function (s) return { name = s.name, output = s.contains.rawName } end)
        .map(function (wb) wb.recipe = tableutils.copy(cookbook.recipes.find(function (r) return r.rawName == wb.output end)); return wb end)
    local distinct = allWorkbenches.reduce(function (acc, wb) acc[wb.output] = wb; return acc end, tableutils.stream{})
        .map(function (_, wb) return wb end)
    local root = distinct.findFirst(function (wb) return wb.recipe.displayName == displayName end)
    local workbenches = allWorkbenches.filter(function (wb) return wb.recipe.displayName == displayName end)
    local process = tableutils.stream{}
    table.insert(process, root)

    repeat
        local wb = process[1]
        table.remove(process, 1)
        local requiredIngredients = tableutils.stream(wb.recipe.ingredients)
            .map(function (n, _) return n end)
        local dependentWbs = allWorkbenches
            .filter(function (w) return requiredIngredients.anyMatch(function (ri) return w.output == ri end) end)
        tableutils.append(workbenches, dependentWbs)
        local toProcess = distinct
            .filter(function (w) return requiredIngredients.anyMatch(function (ri) return w.output == ri end) end)
        tableutils.append(process, toProcess)
    until #process == 0

    workbenches = cleanupTable(workbenches)
    if autoCraftOnStart then
        config.save('current_job', {
            crafting = {
                rawName = root.recipe.rawName,
                displayName = displayName,
            },
            activeWorkbenches = workbenches
         })
    end

    startJobs(workbenches, displayName)

    breakout = true
end

local function deleteRecipe(displayName)
    local i = cookbook.recipes
        .findi(function (r) return r.displayName == displayName end)
    table.remove(cookbook.recipes, i)
    config.save('cookbook', cookbook)
end

local recipeActions = tableutils.stream{
    ['Begin Crafting'] = beginCrafting,
    ['Delete Recipe'] = deleteRecipe,
    ['Can Craft'] = canCraft,
    ['Refresh'] = refreshAction,
}

---@return boolean return false if we're returning back to the list of recipes
local function displayRecipe(displayName)
    -- Header
    term.redirect(term.native())
    term.clear()
    term.setCursorPos(1, 1)
    local x, y = term.getSize()
    local bounds = {1, 1, x, y}
    local win = window.create(term.current(), table.unpack(bounds))

    local group = GUI.Group:new{
        bounds = bounds,
        out = win,
    }
    bounds = {1, 1, x, 2}
    win = window.create(term.current(), table.unpack(bounds))
    local header = GUI.Group:new{
        bounds = bounds,
        out = win,
    }
    header:addElement(GUI.Text:new{
        backgroundColor = colors.orange,
        textColor = colors.gray,
        text = displayName,
        bounds = bounds,
        height = 2,
        width = x,
    })
    header:addElement(GUI.Button:new{
        onClick = function () breakout = true end,
        backgroundColor = colors.gray,
        textColor = colors.orange,
        bounds = {2, 2, 8, 2},
        text = '< back ',
        height = 1,
        width = 7,
        x = 2,
        y = 2,
    })
    group:addElement(header)

    -- Info about the recipe
    local matchingSources = indexedSources.filter(function (s) return s.contains.displayName == displayName end)
    local containerCount = #(matchingSources.filter(function (s) return not s.name:find('autoworkbench') end))
    local workbenchesCount = #(matchingSources.filter(function (s) return s.name:find('autoworkbench') end))

    bounds = {1, 3, 33, y}
    win = window.create(term.current(), table.unpack(bounds))
    local width = 33 + 1
    local info = GUI.Group:new{
        bounds = bounds,
        out = win,
    }
    info:addElement(GUI.Box:new{
        backgroundColor = colors.lightGray,
        height = bounds[4] - bounds[2] + 1,
        width = width,
        bounds = bounds,
    })
    info:addElement(GUI.Text:new{
        text = 'Sources:',
        backgroundColor = colors.lightGray,
        textColor = colors.gray,
        align = 'left',
        width = width,
        height = 1,
        x = 1,
        y = 2,
    })
    info:addElement(GUI.Text:new{
        text = ' ' .. containerCount .. ' container' .. (containerCount > 1 and 's' or ''),
        backgroundColor = colors.lightGray,
        textColor = colors.gray,
        align = 'left',
        width = width,
        height = 1,
        x = 1,
        y = 3,
    })
    info:addElement(GUI.Text:new{
        text = ' ' .. workbenchesCount .. ' workbench' .. (workbenchesCount > 1 and 'es' or ''),
        backgroundColor = colors.lightGray,
        textColor = colors.gray,
        align = 'left',
        width = width,
        height = 1,
        x = 1,
        y = 4,
    })
    local recipe = cookbook.recipes.find(function (r) return r.displayName == displayName end)
    info:addElement(GUI.Text:new{
        text = 'Ingredients:',
        backgroundColor = colors.lightGray,
        textColor = colors.gray,
        align = 'left',
        width = width,
        height = 1,
        x = 1,
        y = 6,
    })
    local i = 1
    for _, ing in pairs(recipe.ingredients) do
        info:addElement(GUI.Text:new{
            text = ' ' .. ing.displayName .. ' (' .. (ing.quantity * #ing.slots) .. ')',
            backgroundColor = colors.lightGray,
            textColor = colors.gray,
            align = 'left',
            width = width,
            height = 1,
            x = 1,
            y = 6 + i,
        })
        i = i + 1
    end
    table.insert(group.elements, info)

    -- Right side - listing actions
    bounds = {34, 3, x, y}
    win = window.create(term.current(), table.unpack(bounds))
    table.insert(group.elements, GUI.MultiSelect:new{
        onSelection = function (_, elem) breakout = true; recipeActions[elem.text](displayName) end,
        list = recipeActions.map(function (n, _) return n end),
        btnStyle = {
            backgroundColor = colors.orange,
            selectColor = colors.orange,
            textColor = colors.gray,
            height = 1,
        },
        backgroundColor = colors.gray,
        width = bounds[3] - bounds[1],
        height = bounds[4] - bounds[2],
        mouseDragEnabled = false,
        scrollEnabled = false,
        bounds = bounds,
        out = win,
    })

    parallel.waitForAny(packageElements(group))

    return false
end

local function displayRecipes()
    local selection = ''
    repeat
        term.redirect(term.native())
        term.clear()
        term.setCursorPos(1, 1)
        local x, y = term.getSize()
        local bounds = {1, 1, x, y}

        local list = tableutils.stream(cookbook.recipes)
            .map(function (r) return r.displayName end)

        local select = GUI.MultiSelectWithControls:new{
            onSelection = function (_, v) selection = v breakout = true end,
            btnStyle = {height = 1, selectColor = colors.orange},
            tertiaryColor = colors.lightGray,
            secondaryColor = colors.orange,
            primaryColor = colors.gray,
            header = 'List of Recipes',
            includeSelectAll = false,
            out = term.native(),
            bounds = bounds,
            list = list,
        }

        parallel.waitForAny(packageElements(select))
    until displayRecipe(selection)
end

local function createRecipe(_, workbench)
    local list = workbench.list()
    local output = workbench.getItemMeta(10)
    local ingredients = {}
    for i = 1, 9 do
        if list[i] then
            local itemMeta = workbench.getItemMeta(i)
            if not ingredients[itemMeta.rawName] then
                ingredients[itemMeta.rawName] = {
                    slots = {},
                    quantity = itemMeta.maxCount,
                    displayName = itemMeta.displayName,
                }
            end
            table.insert(ingredients[itemMeta.rawName].slots, i)
        end
    end
    return {
        displayName = output.displayName,
        rawName = output.rawName,
        ingredients = ingredients
    }
end

local function learn()
    local peripheralNames = tableutils.stream(peripheral.getNames())

    displayConfirmation('Learning New Recipies', 'Every inventory slot needs to be filled in workbenches or those slots won\'t be added to the recipe. WARNING: do not attach more than one modem to a single workbench or container')

    displayLoadingScreen('Learning New Recipes', 'Searching for workbenches, this could take a few minutes depending on the number of workbenches and containers')

    local newRecipes = peripheralNames
        .filter(function(name) return name:find('autoworkbench') end)
        .map(function(name) return peripheral.wrap(name) end)
        .filter(function(wb) return wb.getItemMeta(10) end)     -- Remove any workbench without a crafted item
        .reduce(function (acc, wb) acc[wb.getItemMeta(10).rawName] = wb return acc end, tableutils.stream{}) -- Remove dups
        .filter(function (raw, _) return not cookbook.recipes.anyMatch(function (r) return r.rawName == raw end) end)
        .map(createRecipe)

    newRecipes.forEach(function (r) table.insert(cookbook.recipes, r) end)
    table.sort(cookbook.recipes, function (a, b) return a.displayName < b.displayName end)
    config.save('cookbook', cookbook)

    refreshIndex()

    local displayList = newRecipes
        .map(function (r) return r.displayName end)
        .reduce(function (acc, n) if not acc then return n else return acc .. ', ' .. n end end, nil)

    local txt = 'No new recipes found'
    if #newRecipes > 0 then txt = 'Learned ' .. #newRecipes .. ' new recipe' .. (#newRecipes > 1 and 's' or '') .. '!' end
    displayConfirmation(txt, displayList or '')
    displayRecipes()
end

local function initialize()
    term.redirect(term.native())
    term.clear()
    term.setCursorPos(1, 1)
    local action
    local x, y = term.getSize()
    local bounds = {1, 1, x, y}
    local win = window.create(term.current(), table.unpack(bounds))

    local function onClick(a)
        return function ()
            breakout = true
            action = a
        end
    end

    local selection = GUI.Selection:new{
        text = 'Use an existing recipe or learn a new one?',
        header = 'Setting up crafter',
        onConfirm = onClick('existing'),
        onCancel = onClick('learn'),
        confirmBtnText = 'USE EXISTING',
        cancelationBtnText = 'LEARN NEW',
        bounds = bounds,
        out = win,
    }

    parallel.waitForAny(packageElements(selection))

    if action == 'existing' then
        displayRecipes()
    elseif action == 'learn' then
        learn()
    else
        term.clear()
        term.setCursorPos(1, 1)
        print('default ' .. action)
        os.exit()
    end
end

loadConfigs()

if currentJob and currentJob.crafting and currentJob.crafting.displayName then
    startJobs(currentJob.activeWorkbenches, currentJob.crafting.displayName)
end

repeat
    initialize()
until false     -- Replace this checking for a populated config
