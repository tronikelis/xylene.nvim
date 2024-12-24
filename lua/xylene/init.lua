local config = require("xylene.config")
local Renderer = require("xylene.renderer")

local M = {}

---@param buf integer?
---@param wd string?
local function xylene(wd, buf)
    wd = wd or config.config.get_cwd()
    buf = buf or vim.api.nvim_create_buf(false, false)

    local renderer = Renderer:new(wd, buf)
    renderer:refresh()
    config.config.on_attach(renderer)

    vim.keymap.set("n", "<cr>", function()
        renderer:enter(vim.api.nvim_win_get_cursor(0)[1])
    end, { buffer = buf })

    vim.api.nvim_set_current_buf(buf)

    return renderer
end

---@param c xylene.Config
function M.setup(c)
    vim.api.nvim_set_hl(0, "XyleneDir", { link = "Directory", default = true })

    config.config = vim.tbl_deep_extend("force", config.config, c)

    vim.api.nvim_create_user_command("Xylene", function(ev)
        local filepath = vim.fn.expand("%:p:h")

        local renderer = xylene()

        if ev.bang then
            local file, line = renderer:open_from_filepath(filepath)
            vim.print({ file = file, line = line })
        end
    end, { bang = true })

    vim.api.nvim_create_autocmd("BufNew", {
        pattern = Renderer.XYLENE_FS .. "/*",
        callback = function(ev)
            local path = ev.file:sub(#Renderer.XYLENE_FS + 1)
            xylene(path, ev.buf)
        end,
    })
end

return M
