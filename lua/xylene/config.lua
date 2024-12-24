local M = {
    ---@class xylene.Config
    ---@field indent integer
    ---@field keymaps xylene.Config.Keymaps
    ---@field icons xylene.Config.Icons
    ---@field sort_names fun(a: xylene.File, b: xylene.File): boolean
    ---@field on_attach fun(renderer: xylene.Renderer)
    ---@field skip fun(name: string, filetype: string): boolean
    ---@field get_cwd fun(): string
    config = {
        ---@class xylene.Config.Icons
        ---@field files boolean
        ---@field dir_open string
        ---@field dir_close string
        icons = {
            files = true,
            dir_open = "  ",
            dir_close = "  ",
        },
        ---@class xylene.Config.Keymaps
        ---@field enter string
        ---@field enter_recursive string
        keymaps = {
            enter = "<cr>",
            enter_recursive = "!",
        },
        indent = 4,
        sort_names = function(a, b)
            return a.name < b.name
        end,
        skip = function(name, filetype)
            return false
        end,
        on_attach = function(renderer) end,
        get_cwd = function()
            return vim.fn.getcwd()
        end,
    },
}

return M
