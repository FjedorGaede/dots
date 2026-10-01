addPackage(
    "nvim-mini/mini-git",
    "nvim-mini/mini.diff"
)

local MiniGit = require("mini.git")
MiniGit.setup({})

local MiniDiff = require("mini.diff")
MiniDiff.setup({
    view = {
        style = 'sign',
        signs = { add = '▐', change = '⢸', delete = '━' }
    }
})


