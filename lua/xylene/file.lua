local config = require("xylene.config")

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
    return self.depth * config.config.indent
end

---@param dir string
---@return xylene.File[]
function File.dir_to_files(dir)
    ---@type xylene.File[]
    local files = {}

    for name, filetype in vim.fs.dir(dir) do
        if not config.config.skip(name, filetype) then
            ---@type string?, string?
            local icon, icon_hl

            if package.loaded["nvim-web-devicons"] and config.config.icons.files then
                local icons = require("nvim-web-devicons")
                icon, icon_hl = icons.get_icon(name, nil, { default = true })
            end

            table.insert(
                files,
                File:_new({
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

    table.sort(files, config.config.sort_names)
    table.sort(files, function(a, b)
        return a.type < b.type
    end)

    return files
end

---@param fn fun()
function File:_with_opened_count(fn)
    self:_traverse_parent(function(parent)
        parent.opened_count = parent.opened_count - self.opened_count
    end)
    fn()
    self:_traverse_parent(function(parent)
        parent.opened_count = parent.opened_count + self.opened_count
    end)
end

---@param children xylene.File[]
function File:_set_children(children)
    self:_with_opened_count(function()
        self.children = children
        self.opened_count = #self.children

        for _, v in ipairs(self.children) do
            self.opened_count = self.opened_count + v.opened_count

            v.depth = self.depth + 1
            v.parent = self
        end
    end)
end

--- recursively diffs opened files
function File:_diff_children()
    local latest = File.dir_to_files(self.path)

    ---@type table<string, xylene.File?>
    local files_map = {}
    for _, v in ipairs(self.children) do
        files_map[v.path] = v
    end

    for i in ipairs(latest) do
        latest[i] = files_map[latest[i].path] or latest[i]
    end

    self:_set_children(latest)
end

---@param obj xylene.File
---@return xylene.File
function File:_new(obj)
    return setmetatable(obj, { __index = self })
end

---@param skipped integer
---@return integer
---returns count of skipped directories (compact)
function File:_open(skipped)
    self.opened = true

    self:_diff_children()

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

    self:_with_opened_count(function()
        self.opened_count = self._prev_opened_count
    end)

    local depth = self:_open(0)
    self._prev_opened_count = self.opened_count

    self:_with_opened_count(function()
        self.opened_count = self.opened_count - depth
    end)
end

---@param fn fun(parent: xylene.File)
function File:_traverse_parent(fn)
    local parent = self.parent
    while parent do
        fn(parent)
        parent = parent.parent
    end
end

function File:close()
    if self.type ~= "directory" then
        return
    end
    self.opened = false

    self:_with_opened_count(function()
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

function File:open_all()
    self:open()

    for _, v in ipairs(self.children) do
        v:open_all()
    end
end

function File:close_all()
    if self.type ~= "directory" then
        return
    end

    self:_set_children({})
    self:close()
end

function File:toggle_all()
    if self.opened then
        self:close_all()
    else
        self:open_all()
    end
end

---@param files? xylene.File[]
---@return xylene.File[]
function File:_flatten_opened(files)
    files = files or {}

    table.insert(files, self)

    if self.type == "directory" and not self.opened then
        return files
    end

    for _, f in ipairs(self:_get_compact_children()) do
        f:_flatten_opened(files)
    end

    return files
end

---@return xylene.File[]
function File:_get_compact_children()
    local children = self.children
    while #children == 1 and children[1].type == "directory" do
        children = children[1].children
    end
    return children
end

function File:_line()
    local str = self.name

    if self.type == "directory" then
        if self.opened then
            str = config.config.icons.dir_open .. str
        else
            str = config.config.icons.dir_close .. str
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

return File
