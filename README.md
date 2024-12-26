# xylene.nvim

*For that one time where you need to explore your project's architecture*

Semi WIP file tree plugin inspired by oil.nvim and carbon.nvim

![image](https://github.com/user-attachments/assets/25a06234-67c3-479b-bb95-0a7348219bea)

<!--toc:start-->
- [xylene.nvim](#xylenenvim)
  - [Philosophy](#philosophy)
  - [Features](#features)
  - [Usage](#usage)
    - [Quick start](#quick-start)
    - [User commands](#user-commands)
    - [Recipes](#recipes)
      - [Open currently hovering dir with oil.nvim](#open-currently-hovering-dir-with-oilnvim)
      - [Search and open directory with telescope](#search-and-open-directory-with-telescope)
  - [API](#api)
<!--toc:end-->

## Philosophy

- Minimalism
- Designed to be used with other FS plugins, I recommend [oil.nvim](https://github.com/stevearc/oil.nvim)
- Fast, navigating should feel instant


## Features

I want to preface that this file tree right now does not have plans to support file operations
such as move/copy/rename ... etc

- [x] Navigating like a buffer
- [x] Subsequent empty directories are flattened into one line
- [x] Incremental rerendering of tree
- [x] `Xylene!` opens xylene with the current file already opened
- [x] Icons
- [x] Execute any code with files / directories (for example open currently hovering directory in oil.nvim)
- [x] Refresh files
- [ ] Symlink support
- [ ] Detect external file changes

## Usage

While it's still missing some features listed above, I would be happy if you want to
try it out

Install with your favorite package manager and call the setup function

Default options are listed below

```lua
require("xylene").setup({
  icons = {
    files = true,
    dir_open = "  ",
    dir_close = "  ",
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
  get_current_file_dir = function()
    return vim.fn.expand("%:p")
  end,
})
```

### Quick start

Here setting up simple keymaps

- `<cr>` toggle current file
- `!` toggle current file recursive

```lua
require("xylene").setup({
  on_attach = function(renderer)
    vim.keymap.set("n", "<cr>", function()
      renderer:toggle(vim.api.nvim_win_get_cursor(0)[1])
    end, { buffer = renderer.buf })

    vim.keymap.set("n", "!", function()
      renderer:toggle_all(vim.api.nvim_win_get_cursor(0)[1])
    end, { buffer = renderer.buf })
  end
})
```

### User commands

- `Xylene` open a new/previous xylene buffer with `cwd` as the root & refresh the files
- `Xylene!` same as `Xylene` plus recursively opens directories to make your file seen

### Recipes

#### Open currently hovering dir with oil.nvim

<details>
  <summary>video</summary>




https://github.com/user-attachments/assets/a66e005a-ce18-49ec-af07-8aeafe0873a6



</details>

```lua
require("xylene").setup({
  on_attach = function(renderer)
    vim.keymap.set("n", "<c-cr>", function()
      local row = vim.api.nvim_win_get_cursor(0)[1]

      local file = renderer:find_file_line(row)
      if not file then
        return
      end

      require("oil").open(file.path)
    end, { buffer = renderer.buf })
  end,
})
```

#### Search and open directory with telescope

<details>
  <summary>video</summary>



https://github.com/user-attachments/assets/d96fbe8f-625a-4105-bf0a-022e307e8acd



</details>


```lua
require("xylene").setup({
  on_attach = function(renderer)
    vim.keymap.set("n", "<c-f>", function()
      local builtin = require("telescope.builtin")
      local action_state = require("telescope.actions.state")
      local actions = require("telescope.actions")

      builtin.find_files({
        find_command = { "fd", "-t", "d" },
        attach_mappings = function(_, map)
          map("i", "<cr>", function(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            local path = vim.fs.joinpath(entry.cwd, entry[1])
            if path:sub(#path, #path) == "/" then
              -- remove trailing /
              path = path:sub(1, -2)
            end

            local file, line = renderer:open_from_filepath(path)

            vim.api.nvim_win_set_cursor(0, { line, file:indent_len() })
          end)

          return true
        end,
      })
    end, { buffer = renderer.buf })
  end
})
```


## API

Main

```lua
local xylene = require("xylene")

xylene.setup()
-- get renderer from buffer
local renderer = xylene.renderer(buf)
```

Renderer

```lua
local renderer = require("xylene.renderer")

local buf = renderer.buf
local wd = renderer.wd

-- opens the file at `filepath` and returns the found file, line it's on
local file, line = renderer:open_from_filepath(filepath)

-- toggles the directory at `line`
renderer:toggle(line)
renderer:toggle_all(line) -- recursive variant

-- expensive!, refreshes all opened directories / files
renderer:refresh()

-- renders the `file` passed in
renderer:with_render_file(file, line, function()
  -- change `file` here, e.g. `file:toggle()`
end)

-- finds the file at `line`
local file = renderer:find_file_line(line)
-- finds the closest opened file from `filepath`
local file, line = renderer:find_file_filepath(filepath)
```

File

```lua
local file = require("xylene.file")

file:open()
file:open_all()
file:close()
file:close_all()

file:toggle()
file:toggle_all()

file:indent_len()
```
