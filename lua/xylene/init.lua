local config = require("xylene.config")
local Renderer = require("xylene.renderer")

local M = {}

local OPT_FROM_FILEPATH = "_xylene_from_filepath"

_G.__xylene_renderer_buf_map = _G.__xylene_renderer_buf_map or {}
---@type table<integer, xylene.Renderer?>
local renderer_buf_map = _G.__xylene_renderer_buf_map

---@param renderer xylene.Renderer
---@param filepath string
local function open_from_filepath(renderer, filepath)
    local file, line = renderer:open_from_filepath(filepath)

    if file and line then
        vim.api.nvim_win_set_cursor(0, { line, file:indent_len() })
    end
end

---@param buf integer
---@param wd string
local function attach_renderer(wd, buf)
    local renderer = Renderer:new(wd, buf)
    renderer:refresh()

    renderer_buf_map[buf] = renderer
    vim.api.nvim_create_autocmd("BufDelete", {
        once = true,
        buffer = buf,
        callback = function()
            renderer_buf_map[buf] = nil
        end,
    })

    local from_filepath = vim.b[buf][OPT_FROM_FILEPATH]
    if from_filepath then
        open_from_filepath(renderer, from_filepath)
    end

    config.config.on_attach(renderer)
end

---@return xylene.Renderer?
local function get_renderer()
    return renderer_buf_map[vim.api.nvim_get_current_buf()]
end

---@param c xylene.Config
function M.setup(c)
    vim.api.nvim_set_hl(0, "XyleneDir", { link = "Directory", default = true })

    local augroup = vim.api.nvim_create_augroup("xylene.nvim/setup", {})

    config.config = vim.tbl_deep_extend("force", config.config, c)

    vim.api.nvim_create_user_command("Xylene", function(ev)
        if vim.bo.filetype == "xylene" then
            assert(get_renderer()):refresh()
            return
        end

        local from_filepath = config.config.get_current_file_dir()

        vim.cmd.e(Renderer.XYLENE_FS .. config.config.get_cwd())

        if ev.bang then
            local renderer = get_renderer()
            if renderer then
                open_from_filepath(renderer, from_filepath)
            end
            vim.b[0][OPT_FROM_FILEPATH] = from_filepath
        end
    end, { bang = true })

    vim.api.nvim_create_autocmd("BufNew", {
        group = augroup,
        pattern = Renderer.XYLENE_FS .. "/*",
        callback = vim.schedule_wrap(function(ev)
            local path = ev.file:sub(#Renderer.XYLENE_FS + 1)
            attach_renderer(path, ev.buf)
        end),
    })
end

return M
