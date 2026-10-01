-- Visual feedback and hints in the editor

-- Install visual hint plugins
addPackage(
    "nvim-mini/mini.cursorword",
    "nvim-mini/mini.hipatterns"
)
addPackage("lukas-reineke/indent-blankline.nvim")

-- Configure cursorword
local MiniCursorword = require("mini.cursorword")
MiniCursorword.setup({ delay = 0})
local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine" })
vim.api.nvim_set_hl(0, "MiniCursorword", { bg = cursorline.bg, bold = true})

-- Configure hipatterns
local MiniPatterns = require("mini.hipatterns")
MiniPatterns.setup({
  highlighters = {
    fixme = { pattern = 'FIXME', group = 'MiniHipatternsFixme' },
    hack  = { pattern = 'HACK',  group = 'MiniHipatternsHack'  },
    todo  = { pattern = 'TODO',  group = 'MiniHipatternsTodo'  },
    note  = { pattern = 'NOTE',  group = 'MiniHipatternsNote'  },
  }
})

-- Configure indent-blankline
-- TODO Do I actually like this? Is it distracting?
require("ibl").setup(
    ---@module "ibl"
    ---@type ibl.config
    {

    }
)

return {}
