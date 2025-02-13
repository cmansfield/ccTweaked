-- AirsoftingFox 2025 --

local config = {}

function config.save(filename, data)
    local file = fs.open('./configs/' .. filename, 'w')
    file.write(textutils.serialize(data))
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