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

---@param highlights RFCeezHighlight[]
---@param line number
---@return RFCeezHighlight[]
local function find_highlight(highlights, line)
    local out = {}
    for _, h in ipairs(highlights) do
        if h.line == line then
            table.insert(out, h)
        end
    end
    return out
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
---@field win_id number | nil
---@field buf_id number | nil
local RFCeezHighlights = {}
RFCeezHighlights.__index = RFCeezHighlights

---@param highlights RFCeezHighlight[]
function RFCeezHighlights:new(highlights)
    return setmetatable({
        highlights = highlights,
        buf_id = nil,
        win_id = nil,
    }, self)
end

---@return RFCeezHighlight[]
function RFCeezHighlights:get_from_cursor()
    local parts = vim.fn.getpos(".")
    local line = parts[2]

    return find_highlight(self.highlights, line)
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

function RFCeezHighlights:nav_next()
    if #self.highlights == 0 then
        return
    end

    local parts = vim.fn.getpos(".")
    local line = parts[2]

    ---@type RFCeezHighlight
    local nearest = self.highlights[1]

    for i = 2, #self.highlights do
        local h = self.highlights[i]
        local diff = h.line - line
        local nearest_diff = nearest.line - line
        if diff > 0 and nearest_diff <= 0 then
            nearest = h
        end
    end

    vim.api.nvim_win_set_cursor(0, {
        nearest.line,
        0, -- i bet i could do better
    })
    vim.api.nvim_feedkeys("_", "m", true)
end

function RFCeezHighlights:show_notes()
    self:close_notes()

    if #self.highlights == 0 then
        return
    end

    local parts = vim.fn.getpos(".")
    local line = parts[2]
    local highlights = find_highlight(self.highlights, line)

    if #highlights == 0 then
        return
    end

    local lines = {}
    local requires_headers = #highlights > 1

    for i, h in ipairs(highlights) do
        if requires_headers then
            table.insert(lines, string.format("mark %d", i))
        end
        table.insert(lines, h.text)
        table.insert(lines, "")
    end

    local buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    local win_id = vim.api.nvim_open_win(buf_id, false, {
        relative="cursor", width=40, height=6, row=0, col=0
    })
    vim.api.nvim_win_set_cursor(win_id, {2, 1})

    self.buf_id = buf_id
    self.win_id = win_id
end

function RFCeezHighlights:close_notes()
    if self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    if self.buf_id and vim.api.nvim_buf_is_valid(self.buf_id) then
        vim.api.nvim_buf_delete(self.buf_id, {force = true})
    end

    self.win_id = nil
    self.buf_id = nil
end

function RFCeezHighlights:qflist()
    error("not implement yet ya filthy animal")
end

function RFCeezHighlights:rm_all()
    self.highlights = {highlights = {}}
end

function RFCeezHighlights:refresh_highlights()
    local ok = pcall(vim.fn.sign_unplace, "RFCeezHighlights", {buffer = vim.fn.bufnr("%")})
    if not ok then
        error("unable to remove any existing sign.  its likely you forgot to call rfceez#setup first")
    end

    for _, h in ipairs(self.highlights) do
        ok = pcall(vim.fn.sign_place, 0, "RFCeezHighlights", "RFCeezHighlights", vim.fn.bufnr("%"), {lnum = h.line})
        if not ok then
            error("unable to add sign.  its likely you forgot to call rfceez#setup first")
        end
    end
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
        return RFCeezHighlights:new({})
    end

    local out_data = path:read()

    if not out_data or out_data == "" then
        return RFCeezHighlights:new({})
    end

    local ok, data = pcall(vim.json.decode, out_data)
    if not ok then
        return RFCeezHighlights:new({})
    end

    return RFCeezHighlights:new(data.highlights or {})
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
