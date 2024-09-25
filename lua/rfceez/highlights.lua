local Path = require("plenary.path")
local data_path = string.format("%s/rfceez", vim.fn.stdpath("data"))
local ensured_data_path = false
local function ensure_data_path()
    if ensured_data_path then
        return
    end

    local path = Path:new(data_path)
    if not path:exists() then
        path:mkdir()
    end
    ensured_data_path = true
end

--- @param path string
local hash = function(path)
    return vim.fn.sha256(path)
end

--- @param path string
local function fullpath(path)
    local h = hash(path)
    return string.format("%s/%s.json", data_path, h)
end

---@class RFCeezHighlight
---@field line number
---@field text string
local RFCeezHighlight = {}
RFCeezHighlight.__index = RFCeezHighlight

---@param row number
---@return RFCeezHighlight
function RFCeezHighlight:new(row)
    return setmetatable({
        row = row,
    }, self)
end

---@class RFCeezHighlightsRaw
---@field highlights RFCeezHighlight[]

---@class RFCeezHighlights
---@field highlights RFCeezHighlight[]
local RFCeezHighlights = {}
RFCeezHighlights.__index = RFCeezHighlights

---@param highlights RFCeezHighlight[]
function RFCeezHighlights:new(highlights)
    return setmetatable({
        highlights = highlights,
    }, self)
end

---@return RFCeezHighlight[]
function RFCeezHighlights:get_from_cursor()
    local parts = vim.fn.getpos(".")
    local line = parts[2]

    local found = {}
    for i = #self.highlights, 1, -1 do
        local h = self.highlights[i]
        if h.line == line then
            table.insert(found, h)
        end
    end

    return found
end

--- @param text string
function RFCeezHighlights:add_from_cursor(text)
    local parts = vim.fn.getpos(".")
    local line = parts[2]

    table.insert(self.highlights, {
        line = line,
        text = text,
    })

    --- i should probably not sort every time... duh....
    table.sort(
        self.highlights,
        --- @param a RFCeezHighlight
        ---@param b RFCeezHighlight
        function(a, b)
            return a.line < b.line
        end)
end

function RFCeezHighlights:rm_from_cursor()
    local parts = vim.fn.getpos(".")
    local line = parts[2]

    for i = #self.highlights, 1, -1 do
        local h = self.highlights[i]
        if h.line == line then
            table.remove(self.highlights, i)
        end
    end
end

function RFCeezHighlights:rm_all()
    self.highlights = {highlights = {}}
end

--- Sorry tj.  i didn't have a good name and this is terrible, but its for you
--- i stream btw, twitch.tv/ThePrimeagen
---@class RFCHighlightReader
---@field path string
local RFCHighlightReader = {}
RFCHighlightReader.__index = RFCHighlightReader

---@param path string
---@return RFCHighlightReader
function RFCHighlightReader:new(path)
    return setmetatable({
        path = path
    }, self)
end

--- @return RFCeezHighlights
function RFCHighlightReader:read()
    ensure_data_path()

    local provided_path = fullpath(self.path)
    local path = Path:new(provided_path)
    local exists = path:exists()

    if not exists then
        return {
            highlights = {},
        }
    end

    local out_data = path:read()

    if not out_data or out_data == "" then
        return {
            highlights = {},
        }
    end

    local ok, data = pcall(vim.json.decode, out_data)
    if not ok then
        return {
            highlights = {},
        }
    end

    return data
end

--- @param highlights RFCeezHighlights
function RFCHighlightReader:write(highlights)
    local ok, encoded = pcall(vim.json.encode, highlights)

    if not ok then
        error("invalid data provided.  could not json encode: " .. encoded)
    end

    local path = fullpath(self.path)
    Path:new(path):write(encoded, "w")
end

return {
    RFCHighlightReader = RFCHighlightReader,
    RFCeezHighlight = RFCeezHighlight,
    RFCeezHighlights = RFCeezHighlights,

    ---@param new_hash fun(string): string
    set_hashing_function = function(new_hash)
        hash = new_hash
    end,

    ---@param new_data_path string
    set_data_path = function(new_data_path)
        ensured_data_path = false
        data_path = new_data_path
    end,
}
