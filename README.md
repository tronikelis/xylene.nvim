# xylene.nvim

*For that one time where you need to explore your project's architecture*

Wip file tree plugin inspired by oil.nvim and carbon.nvim

![image](https://github.com/user-attachments/assets/25a06234-67c3-479b-bb95-0a7348219bea)

<!--toc:start-->
- [xylene.nvim](#xylenenvim)
  - [Philosophy](#philosophy)
  - [Features](#features)
  - [Usage](#usage)
    - [Keymaps](#keymaps)
    - [User commands](#user-commands)
    - [Recipes](#recipes)
      - [Open currently hovering dir with oil.nvim](#open-currently-hovering-dir-with-oilnvim)
      - [Search and open directory with telescope](#search-and-open-directory-with-telescope)
  - [API](#api)
    - [xylene.File](#xylenefile)
    - [xylene.Renderer](#xylenerenderer)
    - [xylene.Config](#xyleneconfig)
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
  keymaps = {
    enter = "<cr>",
  },
  indent = 4,
  sort_names = function(a, b)
    return a.name < b.name
  end,
  skip = function(name, filetype)
    return name == ".git"
  end,
  on_attach = function(renderer) end,
})
```

### Keymaps

- `<cr>` toggle dir / enter file

### User commands

- `Xylene` open a new xylene buffer with `cwd` as the root
- `Xylene!` same as `Xylene` plus recursively opens directories to make your file seen

### Recipes

#### Open currently hovering dir with oil.nvim

```lua
require("xylene").setup({
  on_attach = function(renderer)
    vim.keymap.set("n", "<c-cr>", function()
      local row = vim.api.nvim_win_get_cursor(0)[1]

      local file = renderer:find_file(row)
      if not file then
        return
      end

      require("oil").open(file.path)
    end, { buffer = renderer.buf })
  end,
})
```

#### Search and open directory with telescope

Right now a bit too much low level for my likings, I'll probably make this more concise in the future
with new apis

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
            -- remove trailing /
            path = path:sub(1, -2)

            local utils = require("xylene.utils")

            --- find the file that will be rendered
            --- in this case the root file
            local root, root_row
            for i, f in ipairs(renderer.files) do
              if utils.string_starts_with(path, f.path) then
                root_row = i
                root = f
                break
              end
            end

            local pre_from, pre_to = renderer:pre_render_file(root, root_row)

            local file, line = renderer:open_from_filepath(path)
            if not file then
              return
            end

            file:open()
            renderer:render_file(root, pre_from, pre_to)

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

### xylene.File

todo

### xylene.Renderer

todo

### xylene.Config

todo
