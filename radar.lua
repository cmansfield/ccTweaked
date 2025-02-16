--[[
    radar.lua
    Version: 1.0.0
    LUA Version: 5.2
    Author: AirsoftingFox
    Last Updated: 2025-02-13
    CC: Tweaked Version: 1.89.2
    Description: Using Plethora's neural interface with the entity sensor, 
		introspection, overlay glasses modules installed, a radar will 
		appear in the upper left-hand corner and display any liviing 
		entities nearby. Player names will be displayed by default and
		you can toggle npc names on or off by changing the 
		'displayNpcNames' variable. 

	Yaw (degrees)
		South: 0
		West:  90
		North: 180
		East:  270

	Relative Cube Directions
		South: -z
		North:  z
		East:  -x
		West:   x
		Entity above player:  y
		Entity below player: -y

	Max horizontal distance: 15 blocksw
	Scan is a 32 block cube around the player
]]

local tableutils = require('tableutils')

local scannerRange = 21
local scanInterval = 0.2
local renderInterval = 0.05

local size = 0.5
local centerX = 75
local centerY = 75
local letterSize = size * 5
local displayNpcNames = true

local colors = {
	["player"] = { 191, 44, 52 },		-- Red
	["npc"]    = { 32, 106, 210 }		-- Blue
}

local modules = peripheral.find("neuralInterface")
if not modules then error("Must have a neural interface", 0) end
if not modules.hasModule("plethora:introspection") then error("The introspection scanner is missing", 0) end
if not modules.hasModule("plethora:sensor") then error("The entity scanner is missing", 0) end
if not modules.hasModule("plethora:glasses") then error("The overlay glasses are missing", 0) end

local canvas = modules.canvas()
canvas.clear()
-- canvas.addRectangle(0, 0, 150, 150, 0x80808040)

local centerDot = canvas.addDot({ centerX, centerY }, 0xFFFFFFFF, size * 4)
centerDot.setColor(table.unpack(colors['player']))
local canvasElements = {}

local playerName = modules.getMetaOwner().name
local entities = {}

local function drawCircle(radius, c)
	local h, k = centerX, centerY
	local x, y
    for d = 1, 360 do
		x = h + radius * math.cos(d)
		y = k + radius * math.sin(d)
		c.addDot({ x, y }, 0x80808040, 3)
    end
end

local function isNpc(entityMeta)
	if entityMeta and entityMeta.isAlive and not entityMeta.food then return true
	else return false end
end

local function isPlayer(entityMeta)
	if entityMeta and entityMeta.food and entityMeta.isAlive then return true
	else return false end
end

local function scan()
	while true do
		entities = tableutils.stream(modules.sense())
			.filter(function (e) return e.name ~= playerName end)
			.map(function (e)
				e.meta = modules.getMetaByID(e.id)
				e.isPlayer = isPlayer(e.meta)
				return e
			end)
			.filter(function (e) return isNpc(e.meta) or e.isPlayer end)
		sleep(scanInterval)
	end
end

local function renderWithName(entity, point)
	local name = entity.name or ''
	local color = colors[entity.isPlayer and 'player' or 'npc']
	local group = canvas.addGroup(point)
	local dot = group.addDot({ 0, 0 }, 0xFFFFFFFF, size * 4)
	dot.setColor(table.unpack(color))
	local text = group.addText({ -(#name * letterSize / 2), -6 }, name, 0xFFFFFFFF, 0.5)
	text.setColor(table.unpack(color))
	return group
end

local function render()
	local relativeX, relativeZ, normalizedX, normalizedY
	local rotatedX, rotatedY

	while true do
		local playerYaw = modules.getMetaOwner().yaw
		local angle = math.rad(-playerYaw % 360)

		for _, elem in ipairs(canvasElements) do
			if elem then elem.remove() end
		end
		canvasElements = {}

		for _, entity in ipairs(entities) do
			relativeX = entity.x
			relativeZ = entity.z

			rotatedX = math.cos(angle) * -relativeX - math.sin(angle) * -relativeZ
			rotatedY = math.sin(angle) * -relativeX + math.cos(angle) * -relativeZ

			normalizedX = centerX + (rotatedX / scannerRange) * centerX
			normalizedY = centerY + (rotatedY / scannerRange) * centerY

			if entity.isPlayer or displayNpcNames then
				table.insert(canvasElements, renderWithName(entity, { normalizedX, normalizedY }))
			else
				local dot = canvas.addDot({ normalizedX, normalizedY }, 0xFFFFFFFF, size * 4)
				dot.setColor(table.unpack(colors['npc']))
				table.insert(canvasElements, dot)
			end
		end

		sleep(renderInterval)
	end
end

local function exit()
	while true do
		os.pullEventRaw('terminate')
		canvas.clear()
	end
end

term.clear()
drawCircle(centerX * 0.95, canvas)
parallel.waitForAll(exit, scan, render)
