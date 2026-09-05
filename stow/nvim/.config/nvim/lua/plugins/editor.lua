-- Editor enhancement plugins

-- Install mini editor plugins
addPackage(
    "nvim-mini/mini.pairs",
    "nvim-mini/mini.surround",
    "nvim-mini/mini.trailspace",
    "nvim-mini/mini.keymap",
    "nvim-mini/mini.move"
)

-- Configure mini.pairs
local MiniPairs = require("mini.pairs")
MiniPairs.setup({
    modes = { command = false },
    -- Global mappings. Each right hand side should be a pair information, a
    -- table with at least these fields (see more in |MiniPairs.map|):
    -- - <action> - one of 'open', 'close', 'closeopen'.
    -- - <pair> - two character string for pair to be used.
    -- By default pair is not inserted after `\`, quotes are not recognized by
    -- `<CR>`, `'` does not insert pair after a letter.
    -- Only parts of tables can be tweaked (others will use these defaults).
    mappings = {
        [")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
        ["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
        ["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },
        ["["] = {
            action = "open",
            pair = "[]",
            neigh_pattern = ".[%s%z%)}%]]",
            register = { cr = true },
            -- foo|bar -> press "[" -> foo[bar
            -- foobar| -> press "[" -> foobar[]
            -- |foobar -> press "[" -> [foobar
            -- | foobar -> press "[" -> [] foobar
            -- foobar | -> press "[" -> foobar []
            -- {|} -> press "[" -> {[]}
            -- (|) -> press "[" -> ([])
            -- [|] -> press "[" -> [[]]
        },
        ["{"] = {
            action = "open",
            pair = "{}",
            -- neigh_pattern = ".[%s%z%)}]",
            neigh_pattern = ".[%s%z%)}%]]",
            register = { cr = true },
            -- foo|bar -> press "{" -> foo{bar
            -- foobar| -> press "{" -> foobar{}
            -- |foobar -> press "{" -> {foobar
            -- | foobar -> press "{" -> {} foobar
            -- foobar | -> press "{" -> foobar {}
            -- (|) -> press "{" -> ({})
            -- {|} -> press "{" -> {{}}
        },
        ["("] = {
            action = "open",
            pair = "()",
            -- neigh_pattern = ".[%s%z]",
            neigh_pattern = ".[%s%z%)]",
            register = { cr = false },
            -- foo|bar -> press "(" -> foo(bar
            -- foobar| -> press "(" -> foobar()
            -- |foobar -> press "(" -> (foobar
            -- | foobar -> press "(" -> () foobar
            -- foobar | -> press "(" -> foobar ()
        },
        -- Single quote: Prevent pairing if either side is a letter
        ['"'] = {
            action = "closeopen",
            pair = '""',
            neigh_pattern = "[^%w\\][^%w]",
            register = { cr = false },
        },
        -- Single quote: Prevent pairing if either side is a letter
        ["'"] = {
            action = "closeopen",
            pair = "''",
            neigh_pattern = "[^%w\\][^%w]",
            register = { cr = false },
        },
        -- Backtick: Prevent pairing if either side is a letter
        ["`"] = {
            action = "closeopen",
            pair = "``",
            neigh_pattern = "[^%w\\][^%w]",
            register = { cr = false },
        },
    },
})

-- Configure mini.trailspace
local MiniTrailspace = require("mini.trailspace")
MiniTrailspace.setup({})

-- Configure mini.move
local MiniMove = require('mini.move')
MiniMove.setup({})

-- Configure mini.surround
local MiniSurround = require('mini.surround')
MiniSurround.setup({})

-- Configure mini.keymap
local MiniKeymap = require("mini.keymap")
MiniKeymap.setup({})

-- This is used to make accepting the completion and CR in minipairs working and also just basic new line
MiniKeymap.map_multistep('i', '<CR>', { 'pmenu_accept', 'minipairs_cr' })

-- Press ESC + ESC so that the highlighting of a serach turns off
MiniKeymap.map_combo({ 'n', 'i', 'x' ,'c' }, '<Esc>', function() vim.cmd('nohlsearch') end)

-- Make Backspace work nicely
MiniKeymap.map_multistep('i', '<BS>', { 'minipairs_bs' })

-- ## Setup Treesitter  ## --

local setup_treesitter = function()
    addPackage(
        { src = "nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate" }
    )

    local TreeSitter = require("nvim-treesitter")
    TreeSitter.setup({})

    local ensure_installed = {
        "vim",
        "vimdoc",
        "go",
        "typescript",
        "lua",
        "bash",
        "zsh",
        "python",
        "markdown",
        "json",
        "html",
        "angular",
        "css",
        "scss",
    }

    local config = require("nvim-treesitter.config")

	local already_installed = config.get_installed()
	local parsers_to_install = {}

	for _, parser in ipairs(ensure_installed) do
		if not vim.tbl_contains(already_installed, parser) then
			table.insert(parsers_to_install, parser)
		end
	end

	if #parsers_to_install > 0 then
		TreeSitter.install(parsers_to_install)
	end

	local group = vim.api.nvim_create_augroup("TreeSitterConfig", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(args)
			if vim.list_contains(TreeSitter.get_installed(), vim.treesitter.language.get_lang(args.match)) then
				vim.treesitter.start(args.buf)
			end
		end,
	})
end

setup_treesitter()

-- ## Setup nvim-ufo (folding) ## --
-- NOTE: vibe coded, might need some supervision but works ok for now

addPackage("kevinhwang91/nvim-ufo", "kevinhwang91/promise-async")

require("ufo").setup({
    provider_selector = function()
        return { "treesitter", "indent" }
    end,
    fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local suffix = ("  ··· %d lines  "):format(endLnum - lnum)
        local endLine = vim.fn.getline(endLnum):match("^%s*(.-)%s*$")
        local sufWidth = vim.fn.strdisplaywidth(suffix) + vim.fn.strdisplaywidth(endLine)
        local targetWidth = width - sufWidth
        local curWidth = 0
        local newVirtText = {}
        for _, chunk in ipairs(virtText) do
            local chunkText = chunk[1]
            local chunkWidth = vim.fn.strdisplaywidth(chunkText)
            if curWidth + chunkWidth <= targetWidth then
                table.insert(newVirtText, chunk)
            else
                table.insert(newVirtText, { truncate(chunkText, targetWidth - curWidth), chunk[2] })
                break
            end
            curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "Comment" })
        table.insert(newVirtText, { endLine, "Normal" })
        return newVirtText
    end,
})

vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
vim.keymap.set("n", "zp", require("ufo").peekFoldedLinesUnderCursor, { desc = "Peek fold" })

return {}
