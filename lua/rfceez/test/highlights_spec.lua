local Highlights = require("rfceez.highlights")
local eq = assert.are.same

--- @type string[]
local made_files = {}

Highlights.set_data_path("/tmp")
Highlights.set_hashing_function(function(key)
    return "rfceez"
end)

local function clear()
    vim.loop.fs_unlink("/tmp/rfceez.json")
end

describe("highlights", function()

    before_each(function()
        clear()
    end)

    it("read empty file", function()

        local reader = Highlights.RFCHighlightReader:new("baz.md")
        local contents = reader:read()

        eq({
            highlights = {}
        }, contents)

    end)

    it("write to empty file", function()

        local reader = Highlights.RFCHighlightReader:new("baz.md")
        local expected = {
            highlights = {
                { line = 1, text = "hello world" }
            }
        }
        reader:write(expected)
        local contents = reader:read()

        eq(expected, contents)

    end)

    it("create a highlight from my cursor position", function()

        local highlights = Highlights.RFCeezHighlights:new({})

        local bufnr = vim.fn.bufnr("/tmp/harpoon-test", true)
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, {
            "foo",
            "bar",
            "baz",
            "qux",
        })
        vim.api.nvim_win_set_cursor(0, { 3, 1 })

        highlights:add_from_cursor("hello world")

        eq({
            { line = 3, text = "hello world" },
        }, highlights:get_from_cursor())
    end)

end)

