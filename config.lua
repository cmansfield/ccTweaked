-- AirsoftingFox 2025 --

local config = {}

---@param filename string
---@param data table | string
---@param isString? boolean
function config.save(filename, data, isString)
    local file = fs.open('./configs/' .. filename, 'w')
    file.write(isString and data or textutils.serialize(data))
    file.close()
end

function config.append(filename, data)
    local file = fs.open('./configs/' .. filename, 'a')
    file.write(textutils.serialize(data))
    file.write('\n')
    file.close()
end

function config.load(filename)
    local path = './configs/' .. filename
    if not fs.exists(path) then return end
    local file = fs.open(path, 'r')
    local c = textutils.unserialize(file.readAll())
    file.close()
    return c
end

return config