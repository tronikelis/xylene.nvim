local utils = require("xylene.utils")

local XYLENE_FS = "xylene://"

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

---@class xylene.File
---@field path string
---@field name string
---@field type ("file"|"directory")
---@field opened boolean
---@field depth integer
---@field opened_count integer
---@field _prev_opened_count integer
---@field icon? string
---@field icon_hl? string
---@field parent? xylene.File
---@field children xylene.File[]
local File = {}

function File:indent_len()
    return self.depth * M.config.indent
end

---@param dir string
---@return xylene.File[]
function File.dir_to_files(dir)
    ---@type xylene.File[]
    local files = {}

    for name, filetype in vim.fs.dir(dir) do
        if not M.config.skip(name, filetype) then
            ---@type string?, string?
            local icon, icon_hl

            if package.loaded["nvim-web-devicons"] and M.config.icons.files then
                local icons = require("nvim-web-devicons")
                icon, icon_hl = icons.get_icon(name, nil, { default = true })
            end

            table.insert(
                files,
                File:new({
                    icon = icon,
                    icon_hl = icon_hl,

                    _prev_opened_count = 0,
                    opened_count = 0,
                    depth = 0,
                    name = name,
                    path = vim.fs.joinpath(dir, name),
                    type = filetype,
                    opened = false,
                    children = {},
                })
            )
        end
    end

    table.sort(files, M.config.sort_names)
    table.sort(files, function(a, b)
        return a.type < b.type
    end)

    return files
end

---@param fn fun()
function File:with_opened_count(fn)
    self:traverse_parent(function(parent)
        parent.opened_count = parent.opened_count - self.opened_count
    end)
    fn()
    self:traverse_parent(function(parent)
        parent.opened_count = parent.opened_count + self.opened_count
    end)
end

---@param children xylene.File[]
function File:set_children(children)
    self.children = children
    self.opened_count = #self.children

    for _, v in ipairs(self.children) do
        self.opened_count = self.opened_count + v.opened_count

        v.depth = self.depth + 1
        v.parent = self
    end
end

--- recursively diffs opened files
function File:diff_children()
    local latest = File.dir_to_files(self.path)

    ---@type table<string, xylene.File?>
    local files_map = {}
    for _, v in ipairs(self.children) do
        files_map[v.path] = v
    end

    for i in ipairs(latest) do
        latest[i] = files_map[latest[i].path] or latest[i]
    end

    self:with_opened_count(function()
        self:set_children(latest)
    end)
end

---@param obj xylene.File
---@return xylene.File
function File:new(obj)
    setmetatable(obj, { __index = self })
    return obj
end

---@param skipped integer
---@return integer
---returns count of skipped directories (compact)
function File:_open(skipped)
    self.opened = true

    self:diff_children()

    if #self.children == 1 and self.children[1].type == "directory" then
        local child = self.children[1]
        child.depth = child.depth - 1
        return child:_open(skipped + 1)
    end

    for _, v in ipairs(self.children) do
        if v.opened then
            v:open()
        end
    end

    return skipped
end

function File:open()
    if self.type ~= "directory" then
        return
    end

    self:with_opened_count(function()
        self.opened_count = self._prev_opened_count
    end)

    local depth = self:_open(0)
    self._prev_opened_count = self.opened_count

    self:with_opened_count(function()
        self.opened_count = self.opened_count - depth
    end)
end

---@param fn fun(parent: xylene.File)
function File:traverse_parent(fn)
    local parent = self.parent
    while parent do
        fn(parent)
        parent = parent.parent
    end
end

function File:close()
    if not self.opened or self.type ~= "directory" then
        return
    end
    self.opened = false

    self:with_opened_count(function()
        self.opened_count = 0
    end)
end

function File:toggle()
    if self.opened then
        self:close()
    else
        self:open()
    end
end

function File:open_recursive()
    self:open()

    for _, v in ipairs(self.children) do
        v:open_recursive()
    end
end

---@param files? xylene.File[]
---@return xylene.File[]
function File:flatten_opened(files)
    files = files or {}

    table.insert(files, self)

    if self.type == "directory" and not self.opened then
        return files
    end

    for _, f in ipairs(self:get_compact_children()) do
        f:flatten_opened(files)
    end

    return files
end

---@return xylene.File[]
function File:get_compact_children()
    local children = self.children
    while #children == 1 and children[1].type == "directory" do
        children = children[1].children
    end
    return children
end

function File:line()
    local str = self.name

    if self.type == "directory" then
        if self.opened then
            str = M.config.icons.dir_open .. str
        else
            str = M.config.icons.dir_close .. str
        end

        str = str .. "/"
    end

    local children = self.children
    while #children == 1 and children[1].type == "directory" do
        str = str .. children[1].name .. "/"
        children = children[1].children
    end

    if self.icon and self.type ~= "directory" then
        str = self.icon .. " " .. str
    end

    for _ = 0, self:indent_len() - 1 do
        str = " " .. str
    end

    return str
end

---@class xylene.Renderer
---@field buf integer
---@field ns_id integer
---@field wd string
---@field files xylene.File[]
local Renderer = {}

---@param dir string
---@param buf integer
---@return xylene.Renderer
function Renderer:new(dir, buf)
    ---@type xylene.Renderer
    local obj = {
        wd = dir,
        files = File.dir_to_files(dir),
        buf = buf,
        ns_id = vim.api.nvim_create_namespace(""),
    }
    setmetatable(obj, { __index = self })

    vim.keymap.set("n", M.config.keymaps.enter, function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        obj:enter(row)
    end, { buffer = buf })
    vim.keymap.set("n", M.config.keymaps.enter_recursive, function()
        obj:enter_recursive(vim.api.nvim_win_get_cursor(0)[1])
    end, { buffer = buf })

    vim.api.nvim_buf_set_name(obj.buf, XYLENE_FS .. obj.wd)

    local opts = vim.bo[buf]
    opts.filetype = "xylene"
    opts.modified = false
    opts.modifiable = false
    opts.undofile = false

    return obj
end

---@param fn fun()
function Renderer:with_modifiable(fn)
    local opts = vim.bo[self.buf]

    opts.modifiable = true
    fn()
    opts.modifiable = false
    opts.modified = false
end

---comment returns pre from, to
---@param file xylene.File
---@param line integer
---@return integer, integer
function Renderer:pre_render_file(file, line)
    local from = line - 1
    local to = file.opened_count + 1 + from
    return from, to
end

---@param file xylene.File
---@param pre_from integer
---@param pre_to integer
function Renderer:render_file(file, pre_from, pre_to)
    local lines = {}
    local files = file:flatten_opened()

    for _, f in ipairs(files) do
        table.insert(lines, f:line())
    end

    self:with_modifiable(function()
        vim.api.nvim_buf_set_lines(self.buf, pre_from, pre_to, true, lines)
        self:apply_hl(files, pre_from)
    end)
end

---@param line integer
---@param line_needle? integer
---@param files? xylene.File[]
---@return xylene.File?
function Renderer:find_file(line, line_needle, files)
    files = files or self.files
    line_needle = line_needle or line

    --- this could be a perf bottleneck
    --- as worst case scenario it loops through the whole root files

    for _, f in ipairs(files) do
        if line_needle == 1 then
            return f
        end

        line_needle = line_needle - 1

        if line_needle <= f.opened_count then
            return self:find_file(line, line_needle, f:get_compact_children())
        end

        line_needle = line_needle - f.opened_count
    end
end

---@param file xylene.File
---@param line integer
---@param fn fun()
function Renderer:with_render_file(file, line, fn)
    local from, to = self:pre_render_file(file, line)
    fn()
    self:render_file(file, from, to)
end

---@param row integer
function Renderer:enter_recursive(row)
    local file = self:find_file(row)
    if not file then
        return
    end

    if file.type == "file" then
        self:enter(row)
        return
    end

    self:with_render_file(file, row, function()
        file:open_recursive()
    end)
end

---@param row integer
function Renderer:enter(row)
    local file = self:find_file(row)
    if not file then
        return
    end

    if file.type == "file" then
        vim.cmd.e(file.path)
        return
    end

    self:with_render_file(file, row, function()
        file:toggle()
    end)
end

---@param flattened_files xylene.File[]
---@param offset integer
function Renderer:apply_hl(flattened_files, offset)
    for i, f in ipairs(flattened_files) do
        local line = offset + i - 1

        if f.type == "directory" then
            vim.api.nvim_buf_add_highlight(self.buf, self.ns_id, "XyleneDir", line, 0, -1)
        else
            if f.icon and f.icon_hl then
                local start = f:indent_len()
                vim.api.nvim_buf_add_highlight(self.buf, self.ns_id, f.icon_hl, line, start, start + 1)
            end
        end
    end
end

function Renderer:refresh()
    ---@type string[]
    local lines = {}
    ---@type xylene.File[]
    local files = {}

    for _, file in ipairs(self.files) do
        if file.opened then
            file:open() -- force refresh the file
        end

        for _, l in ipairs(file:flatten_opened()) do
            table.insert(lines, l:line())
            table.insert(files, l)
        end
    end

    self:with_modifiable(function()
        vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
        self:apply_hl(files, 0)
    end)
end

---returns [file: xylene.File?, row: integer]
---@param filepath string
---@param files? xylene.File[]
---@param line? integer
---@return xylene.File?, integer
function Renderer:open_from_filepath(filepath, files, line)
    files = files or self.files
    line = line or 0

    for _, f in ipairs(files) do
        line = line + 1

        if f.path == filepath then
            return f, line
        end

        if utils.string_starts_with(filepath, f.path) then
            f:open()
            return self:open_from_filepath(filepath, f:get_compact_children(), line)
        end

        line = line + f.opened_count
    end

    return nil, 0
end

---@type table<string, xylene.Renderer?>
local wd_renderers = {}

---@param wd string
---@param buf integer?
---@return xylene.Renderer
local function upsert_renderer(wd, buf)
    if wd:sub(-1, -1) == "/" then -- rm trailing /
        wd = wd:sub(1, -2)
    end

    local current = wd_renderers[wd]
    if current and vim.api.nvim_buf_is_valid(current.buf) then
        return current
    else
        wd_renderers[wd] = nil
    end

    local renderer = Renderer:new(wd, buf or vim.api.nvim_create_buf(false, false))
    M.config.on_attach(renderer)
    wd_renderers[wd] = renderer

    return renderer
end

function M.setup(config)
    config = config or {}
    M.config = vim.tbl_deep_extend("force", M.config, config)

    vim.api.nvim_set_hl(0, "XyleneDir", { link = "Directory" })

    vim.api.nvim_create_user_command("Xylene", function(args)
        local renderer = upsert_renderer(M.config.get_cwd())
        if vim.bo.filetype == "xylene" then
            renderer:refresh()
            return
        end

        local filepath = vim.fn.expand("%:p")
        vim.api.nvim_set_current_buf(renderer.buf)

        if args.bang then
            local file, line = renderer:open_from_filepath(filepath)

            renderer:refresh()

            if not file then
                return
            end

            vim.api.nvim_win_set_cursor(0, { line, file:indent_len() })
        else
            renderer:refresh()
        end
    end, {
        bang = true,
    })

    vim.api.nvim_create_autocmd("BufNew", {
        pattern = XYLENE_FS .. "/*",
        callback = function(ev)
            local path = ev.file:sub(#XYLENE_FS + 1)
            upsert_renderer(path, ev.buf):refresh()
        end,
    })
end

return M
