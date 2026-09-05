-- Navigation and file management plugins

-- Install navigation plugins
addPackage("kwkarlwang/bufjump.nvim")
addPackage("folke/flash.nvim")
addPackage("rmagatti/auto-session")

-- Install mini navigation plugins
addPackage(
    "nvim-mini/mini.files",
    "nvim-mini/mini.pick",
    "nvim-mini/mini.clue",
    "nvim-mini/mini.extra"
)

-- Install & Setup Snacks
addPackage( "folke/snacks.nvim")

local Snacks = require("snacks")
Snacks.setup(
    ---@class snacks.Config
    {
        ---@class snacks.picker.Config
        picker = {
            enabled = true,
            ui_select = true,
        },
        input = {
            enabled = true
        },
    }
)

-- Configure bufjump
require("bufjump").setup({
    forward_key = "<M-i>",
    backward_key = "<M-o>",
    on_success = nil
})

-- Configure mini.files
local MiniFiles = require("mini.files")
MiniFiles.setup({
    mappings = {
        go_in_plus  = '<CR>',
        close = "<Esc>",
    },
})

-- Configure mini.clue
local MiniClue = require("mini.clue")
MiniClue.setup({
    window = { delay = 650 },
    triggers = {
        -- Leader triggers
        { mode = 'n', keys = '<Leader>' },
        { mode = 'x', keys = '<Leader>' },

        -- `[` and `]` keys
        { mode = 'n', keys = '[' },
        { mode = 'n', keys = ']' },

        -- Built-in completion
        { mode = 'i', keys = '<C-x>' },

        -- `g` key
        { mode = 'n', keys = 'g' },
        { mode = 'x', keys = 'g' },

        -- Marks
        { mode = 'n', keys = "'" },
        { mode = 'n', keys = '`' },
        { mode = 'x', keys = "'" },
        { mode = 'x', keys = '`' },

        -- Registers
        { mode = 'n', keys = '"' },
        { mode = 'x', keys = '"' },
        { mode = 'i', keys = '<C-r>' },
        { mode = 'c', keys = '<C-r>' },

        -- Window commands
        { mode = 'n', keys = '<C-w>' },

        -- `z` key
        { mode = 'n', keys = 'z' },
        { mode = 'x', keys = 'z' },
    },

    clues = {
        -- Enhance this by adding descriptions for <Leader> mapping groups
        MiniClue.gen_clues.square_brackets(),
        MiniClue.gen_clues.builtin_completion(),
        MiniClue.gen_clues.g(),
        MiniClue.gen_clues.marks(),
        MiniClue.gen_clues.registers(),
        MiniClue.gen_clues.windows(),
        MiniClue.gen_clues.z(),
    },
})

-- Configure mini.pick
-- local MiniPick = require("mini.pick")
-- MiniPick.setup({})

--
-- Configure auto-session
require("auto-session").setup({})

-- Overwrite vim.ui.select so that mini.pick is used instead of the default things
-- vim.ui.select = function(items, o, on_choice)
--   local start_opts = { window = { config = { width = vim.o.columns } } }
--   return MiniPick.ui_select(items, o, on_choice, start_opts)
-- end

return {}
