local utils = require("xylene.utils")
local File = require("xylene.file")

---@class xylene.Renderer
---@field buf integer
---@field ns_id integer
---@field wd string
---@field files xylene.File[]
local Renderer = {}

Renderer.XYLENE_FS = "xylene://"

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

    vim.api.nvim_buf_set_name(obj.buf, Renderer.XYLENE_FS .. obj.wd)

    local opts = vim.bo[buf]
    opts.filetype = "xylene"
    opts.modified = false
    opts.modifiable = false
    opts.undofile = false

    return obj
end

---@param fn fun()
function Renderer:_with_modifiable(fn)
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
function Renderer:_pre_render_file(file, line)
    local from = line - 1
    local to = file.opened_count + 1 + from
    return from, to
end

---@param file xylene.File
---@param pre_from integer
---@param pre_to integer
function Renderer:_render_file(file, pre_from, pre_to)
    local lines = {}
    local files = file:_flatten_opened()

    for _, f in ipairs(files) do
        table.insert(lines, f:_line())
    end

    self:_with_modifiable(function()
        vim.api.nvim_buf_set_lines(self.buf, pre_from, pre_to, true, lines)
        self:_apply_hl(files, pre_from)
    end)
end

---@param line integer
---@param line_needle? integer
---@param files? xylene.File[]
---@return xylene.File?
function Renderer:find_file_line(line, line_needle, files)
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
            return self:find_file_line(line, line_needle, f:_get_compact_children())
        end

        line_needle = line_needle - f.opened_count
    end
end

---@param file xylene.File
---@param line integer
---@param fn fun()
function Renderer:with_render_file(file, line, fn)
    local from, to = self:_pre_render_file(file, line)
    fn()
    self:_render_file(file, from, to)
end

---@param line integer
function Renderer:toggle_all(line)
    local file = self:find_file_line(line)
    if not file then
        return
    end

    if file.type == "file" then
        self:toggle(line)
        return
    end

    self:with_render_file(file, line, function()
        file:toggle_all()
    end)
end

---@param line integer
function Renderer:toggle(line)
    local file = self:find_file_line(line)
    if not file then
        return
    end

    if file.type == "file" then
        vim.cmd.e(file.path)
        return
    end

    self:with_render_file(file, line, function()
        file:toggle()
    end)
end

---@param flattened_files xylene.File[]
---@param offset integer
function Renderer:_apply_hl(flattened_files, offset)
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

        for _, l in ipairs(file:_flatten_opened()) do
            table.insert(lines, l:_line())
            table.insert(files, l)
        end
    end

    self:_with_modifiable(function()
        vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
        self:_apply_hl(files, 0)
    end)
end

---finds the nearest file to `filepath`
---returns [file: xylene.File?, line: integer]
---@param filepath string
---@param files xylene.File?
---@param line integer?
---@return xylene.File?, integer?
function Renderer:find_file_filepath(filepath, files, line)
    line = line or 0
    files = files or self.files

    ---@type xylene.File?
    local file = nil

    for _, v in ipairs(files) do
        line = line + 1

        if utils.string_starts_with(filepath, v.path) then
            file = v

            ---@type xylene.File[]
            local children = vim
                .iter(v:_get_compact_children())
                ---@param x xylene.File
                :filter(function(x)
                    return x.type ~= "directory" or x.opened
                end)
                :totable()

            local res = self:find_file_filepath(filepath, children, line)

            if res then
                return res, line
            end

            break
        end

        line = line + v.opened_count
    end

    return file, line
end

---returns [file: xylene.File?, line: integer]
---@param filepath string
---@param file xylene.File
---@param line integer
---@return xylene.File?, integer?
function Renderer:_open_to_filepath(filepath, file, line)
    if file.path == filepath then
        return file, line
    end

    file:open()

    for _, v in ipairs(file:_get_compact_children()) do
        line = line + 1

        if utils.string_starts_with(filepath, v.path) then
            return self:_open_to_filepath(filepath, v, line)
        end

        line = line + v.opened_count
    end

    return file, line
end

---returns [file: xylene.File?, line: integer]
---@param filepath string
---@return xylene.File?, integer?
function Renderer:open_from_filepath(filepath)
    local file, line = self:find_file_filepath(filepath)
    if not file or not line then
        return
    end

    self:with_render_file(file, line, function()
        file, line = self:_open_to_filepath(filepath, file, line)
    end)

    return file, line
end

return Renderer
