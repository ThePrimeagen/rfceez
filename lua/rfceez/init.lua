local Path = require("plenary.path")
local Highlights = require("rfceez.highlights")

local M = {}

---@class RFCInfo
---@field reader RFCHighlightReader
---@field highlights RFCeezHighlights

---@type table<string, RFCInfo>
local readers = {}

local augroup = vim.api.nvim_create_augroup
local RFCeezGroup = augroup("RFCeezGroup", {})
local autocmd = vim.api.nvim_create_autocmd

local function get_current_name()
    return Path:new(vim.api.nvim_buf_get_name(0)):normalize()
end

local function get_current_reader()
    local name = get_current_name()
    if readers[name] == nil then
        local reader = Highlights.RFCHighlightReader:new(name)
        readers[name] = {
            reader = reader,
            highlights = reader:read()
        }
    end
    return readers[name]
end

-- There is some repetitive code here bobby

function M.setup()
    -- This could be configured
    vim.fn.sign_define("RFCeezHighlights", {text = '⚑', texthl = 'RFCeezHighlight'})
    vim.cmd [[highlight RFCeezHighlight guifg=#C0FFEE]]
    local reader = get_current_reader()
    reader.highlights:refresh_highlights()

    autocmd({"BufEnter"}, {
        group = RFCeezGroup,
        pattern = "*",
        callback = function()
            local r = get_current_reader()
            r.highlights:refresh_highlights()
        end
    })

    autocmd({"BufLeave"}, {
        group = RFCeezGroup,
        pattern = "*",
        callback = function()
        end
    })

end

local function refresh_and_save()
    local reader = get_current_reader()
    reader.reader:write(reader.highlights)
    reader.highlights:refresh_highlights()
end

function M.add()
    local text = vim.fn.input({prompt = "Note > "})
    local reader = get_current_reader()
    reader.highlights:add_from_cursor(text)
    refresh_and_save()
end

function M.rm()
    get_current_reader().highlights:rm_from_cursor()
    refresh_and_save()
end

function M.rm_all()
    get_current_reader().highlights:rm_all()
    refresh_and_save()
end

function M.add_from_cursor(text)
    local reader = get_current_reader()
    reader.highlights:add_from_cursor(text)
    refresh_and_save()
end

function M.nav_next()
    get_current_reader().highlights:nav_next()
end

function M.show_notes()
    get_current_reader().highlights:show_notes()
end

function M.show_next()
    M.nav_next()
    M.show_notes()
end

return M
