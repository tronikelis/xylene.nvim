local config = require("xylene.config")
local Renderer = require("xylene.renderer")

local M = {}

local OPT_FROM_FILEPATH = "_xylene_from_filepath"

---@type table<integer, xylene.Renderer?>
local buf_renderer = {}

---@param buf integer
---@param wd string
local function attach_renderer(wd, buf)
    local renderer = Renderer:new(wd, buf)
    buf_renderer[buf] = renderer
    renderer:refresh()

    local from_filepath = vim.b[buf][OPT_FROM_FILEPATH]
    if from_filepath then
        local file, line = renderer:open_from_filepath(from_filepath)

        if file and line then
            vim.api.nvim_win_set_cursor(0, { line, file:indent_len() })
        end
    end

    config.config.on_attach(renderer)
end

---@param buf integer?
---@return xylene.Renderer?
function M.renderer(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    return buf_renderer[buf]
end

---@param c xylene.Config
function M.setup(c)
    vim.api.nvim_set_hl(0, "XyleneDir", { link = "Directory", default = true })

    config.config = vim.tbl_deep_extend("force", config.config, c)

    vim.api.nvim_create_user_command("Xylene", function(ev)
        if vim.bo.filetype == "xylene" then
            M.renderer():refresh()
            return
        end

        local from_filepath = config.config.get_current_file_dir()

        vim.cmd.e(Renderer.XYLENE_FS .. config.config.get_cwd())

        if ev.bang then
            vim.b[0][OPT_FROM_FILEPATH] = from_filepath
        end
    end, { bang = true })

    vim.api.nvim_create_autocmd("BufNew", {
        pattern = Renderer.XYLENE_FS .. "/*",
        callback = vim.schedule_wrap(function(ev)
            local path = ev.file:sub(#Renderer.XYLENE_FS + 1)
            attach_renderer(path, ev.buf)
        end),
    })
end

return M
